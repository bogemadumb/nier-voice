import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = CapsuleState()
    private let settings = Settings.shared
    private let history = History.shared
    private let audio = AudioCapture()
    private let settingsWindow = SettingsWindow()

    private var engine: TranscriptionEngine?
    private var panel: CapsulePanel!
    private var hotkey: HoldHotkey!
    private var escMonitor: Any?
    private var retryTimer: Timer?
    private var quietSince: Date?
    private var startedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Начать диктовку", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = CapsulePanel(state: state)
        buildStatusItem()

        audio.onLevel = { [weak self] value in
            guard let self, self.state.phase == .listening else { return }
            self.state.level = value
            self.trackSilence(value)
        }
        audio.onPCM = { [weak self] data in
            self?.engine?.send(data)
        }

        hotkey = HoldHotkey(
            keyCode: settings.hotkeyCode,
            onDown: { [weak self] in self?.keyDown() },
            onUp: { [weak self] in self?.keyUp() }
        )

        hotkey.onAnyModifier = { code, pressed in
            HotkeyProbe.shared.report(code: code, pressed: pressed)
        }

        settings.$hotkeyCode
            .sink { [weak self] code in self?.hotkey.setKey(code) }
            .store(in: &cancellables)

        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.openSettings() }
        }
        if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.runPreview() }
            return
        }
        // сквозная проверка без клавиши: старт сразу, дальше как обычно
        if CommandLine.arguments.contains("--dictate") {
            Permissions.requestMicrophone { _ in }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.beginDictation() }
        }

        Permissions.requestMicrophone { [weak self] _ in self?.refreshStatus() }
        armHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        audio.stop()
        engine?.cancel()
        hotkey?.stop()
    }

    // MARK: - клавиша

    private func keyDown() {
        if settings.holdToTalk {
            beginDictation()
        } else {
            state.phase == .listening ? endDictation() : beginDictation()
        }
    }

    private func keyUp() {
        guard settings.holdToTalk else { return }
        endDictation()
    }

    // MARK: - диктовка

    private func makeEngine() -> TranscriptionEngine {
        let engine: TranscriptionEngine = settings.engine == .deepgram ? DeepgramEngine() : GroqEngine()
        engine.onPartial = { [weak self] text in
            guard let self, self.state.phase == .listening else { return }
            self.state.applyPartial(text)
        }
        engine.onFinal = { [weak self] text in
            self?.state.applyFinal(text)
        }
        engine.onError = { [weak self] message in
            guard let self else { return }
            self.state.error = message
            self.statusLine.title = "ошибка: \(message)"
        }
        return engine
    }

    private func beginDictation() {
        guard state.phase == .idle else { return }
        quietSince = nil
        startedAt = Date()
        state.engine = settings.engine
        state.beginListening()
        panel.show()

        let engine = makeEngine()
        self.engine = engine
        engine.start()
        audio.start()
        installEscMonitor()
        if settings.soundFeedback { NSSound(named: "Tink")?.play() }
    }

    private func endDictation() {
        guard state.phase == .listening else { return }
        audio.stop()
        state.phase = .polishing
        engine?.finish()

        // хвост расшифровки приходит уже после закрытия потока
        let wait: TimeInterval = settings.engine == .deepgram ? 1.5 : 2.4
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self, self.state.phase == .polishing else { return }
            self.state.settleDraft()
            let raw = self.state.plainText
            guard !raw.isEmpty else { self.finish(); return }

            Polisher.polish(
                raw,
                style: self.settings.polish,
                model: self.settings.polishModel,
                terms: self.settings.keytermList
            ) { [weak self] text in
                guard let self, self.state.phase == .polishing else { return }
                self.deliver(text)
            }
        }
    }

    private func deliver(_ text: String) {
        state.phase = .sending
        let seconds = startedAt.map { Date().timeIntervalSince($0) } ?? 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self else { return }
            TextInserter.insert(text)
            if self.settings.soundFeedback { NSSound(named: "Pop")?.play() }
            if self.settings.keepHistory {
                self.history.add(Dictation(text: text, seconds: seconds, engine: self.settings.engine.rawValue))
            }
            self.finish()
        }
    }

    private func cancelDictation() {
        audio.stop()
        engine?.cancel()
        finish()
    }

    private func finish() {
        state.idle()
        quietSince = nil
        startedAt = nil
        removeEscMonitor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self, self.state.phase == .idle else { return }
            self.panel.hide()
            self.engine = nil
        }
    }

    /// Замолчал — заканчиваем сами, дожимать клавишу не нужно.
    private func trackSilence(_ level: Double) {
        guard settings.stopOnSilence, !state.plainText.isEmpty else { quietSince = nil; return }
        if level < 0.06 {
            if let since = quietSince {
                if Date().timeIntervalSince(since) > settings.silenceSeconds { endDictation() }
            } else {
                quietSince = Date()
            }
        } else {
            quietSince = nil
        }
    }

    private func installEscMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }   // esc
            DispatchQueue.main.async { self?.cancelDictation() }
        }
    }

    private func removeEscMonitor() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
    }

    // MARK: - хоткей и разрешения

    private func armHotkey() {
        Diag.log("AXIsProcessTrusted: \(Permissions.accessibilityGranted), микрофон: \(Permissions.microphoneGranted)")
        if hotkey.start() {
            HotkeyProbe.shared.tapAlive = true
            retryTimer?.invalidate()
            retryTimer = nil
        } else {
            HotkeyProbe.shared.tapAlive = false
            Permissions.promptAccessibility()
            if retryTimer == nil {
                retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.armHotkey() }
                }
            }
        }
        refreshStatus()
    }

    private func refreshStatus() {
        let mic = Permissions.microphoneGranted ? "микрофон" : "нет микрофона"
        let ax = Permissions.accessibilityGranted ? "доступ" : "нет доступа"
        let key = Secrets.read(Secrets.deepgramService) == nil ? "нет ключа" : "ключ"
        statusLine.title = "\(mic) · \(ax) · \(key)"
    }

    // MARK: - меню-бар

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Nier Voice")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        let hint = NSMenuItem(title: "Держи \(HotkeyChoice.title(for: settings.hotkeyCode)) — говори", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        toggleItem.target = self
        toggleItem.action = #selector(toggleFromMenu)
        menu.addItem(toggleItem)
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(withTitle: "Настройки…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Показать капсулу", action: #selector(preview), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выход", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu

        refreshStatus()
    }

    @objc private func toggleFromMenu() {
        state.phase == .listening ? endDictation() : beginDictation()
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        settingsWindow.show()
        refreshStatus()
    }

    @objc private func preview() { runPreview() }

    @objc private func quit() { NSApp.terminate(nil) }

    // подписи в меню обновляем в момент открытия — они зависят от настроек и состояния
    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.title = state.phase == .listening ? "Остановить и вставить" : "Начать диктовку"
        if let hint = menu.items.first {
            hint.title = settings.holdToTalk
                ? "Держи \(HotkeyChoice.title(for: settings.hotkeyCode)) — говори"
                : "Нажми \(HotkeyChoice.title(for: settings.hotkeyCode)) — начать и закончить"
        }
        refreshStatus()
    }

    /// Показ капсулы без микрофона и без сети — чтобы смотреть дизайн.
    private func runPreview() {
        guard state.phase == .idle else { return }
        state.beginListening()
        panel.show()

        let script = ["Слушай,", "набросай", "план", "на", "завтра:", "сначала",
                      "закупки,", "потом", "созвон", "с", "Юлей", "по", "контенту."]
        var tick = 0.0
        for index in script.indices {
            tick += 0.22
            let at = tick
            DispatchQueue.main.asyncAfter(deadline: .now() + at) { [weak self] in
                guard let self, self.state.phase == .listening else { return }
                self.state.applyPartial(script[0...index].joined(separator: " "))
                if index % 5 == 4 {
                    self.state.applyFinal(script[0...index].joined(separator: " "))
                }
            }
        }

        var t = 0.0
        let pulse = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, self.state.phase == .listening else { timer.invalidate(); return }
                t += 1.0 / 30.0
                self.state.level = 0.3 + abs(sin(t * 2.1)) * 0.5 + sin(t * 7.3) * 0.1
            }
        }
        RunLoop.main.add(pulse, forMode: .common)

        DispatchQueue.main.asyncAfter(deadline: .now() + tick + 1.1) { [weak self] in
            guard let self, self.state.phase == .listening else { return }
            self.state.settleDraft()
            self.state.phase = .polishing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.phase = .sending
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.finish() }
            }
        }
    }
}
