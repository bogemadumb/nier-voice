import SwiftUI
import AppKit

enum SettingsSection: String, CaseIterable, Identifiable {
    case dictation, control, text, history, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: return "Диктовка"
        case .control: return "Управление"
        case .text: return "Текст"
        case .history: return "История"
        case .system: return "Система"
        }
    }

    var subtitle: String {
        switch self {
        case .dictation: return "Кто слушает и на каком языке"
        case .control: return "Чем запускать и когда останавливать"
        case .text: return "Что происходит со словами перед вставкой"
        case .history: return "Последние диктовки на этом Маке"
        case .system: return "Разрешения, автозапуск, версия"
        }
    }

    var symbol: String {
        switch self {
        case .dictation: return "waveform"
        case .control: return "keyboard"
        case .text: return "text.quote"
        case .history: return "clock.arrow.circlepath"
        case .system: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var history = History.shared
    @ObservedObject var probe = HotkeyProbe.shared
    @State private var section: SettingsSection = .dictation
    @State private var micGranted = Permissions.microphoneGranted
    @State private var axGranted = Permissions.accessibilityGranted

    // разрешения выдаются в системных настройках, поэтому статус перечитываем сами
    private let pulse = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.hairline).frame(width: 1)
            content
        }
        .frame(minWidth: 880, minHeight: 620)
        .background(Theme.ground)
        .onReceive(pulse) { _ in
            micGranted = Permissions.microphoneGranted
            axGranted = Permissions.accessibilityGranted
        }
    }

    // MARK: - навигация

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MiniWave()
                    .frame(width: 26, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nier Voice")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("голосовой ввод")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.dim)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 26)
            .padding(.bottom, 22)

            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 12.5, weight: .medium))
                                .frame(width: 18)
                            Text(item.title)
                                .font(.system(size: 13))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(section == item ? Theme.text : Theme.dim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(section == item ? Theme.accentSoft : .clear)
                        )
                        .overlay(alignment: .leading) {
                            if section == item {
                                Capsule().fill(Theme.accent).frame(width: 3, height: 16).offset(x: -6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            Spacer()

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    StatusDot(ok: micGranted)
                    Text("микрофон").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
                HStack(spacing: 7) {
                    StatusDot(ok: axGranted)
                    Text("универсальный доступ").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 216)
        .background(Theme.sidebar)
    }

    // MARK: - содержимое

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(section.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.top, 6)

                switch section {
                case .dictation: dictation
                case .control: control
                case .text: textSection
                case .history: historySection
                case .system: system
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - разделы

    private var dictation: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "движок") {
                SettingsRow(title: "Кто распознаёт", note: engineNote, isFirst: true) {
                    Picker("", selection: $settings.engine) {
                        Text("Deepgram").tag(EngineKind.deepgram)
                        Text("Groq").tag(EngineKind.groq)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                SettingsRow(title: "Язык", note: "«Как получится» ловит русский с английскими терминами внутри фразы.") {
                    Picker("", selection: $settings.language) {
                        Text("Как получится").tag("multi")
                        Text("Русский").tag("ru")
                        Text("English").tag("en")
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }

            KeysCard()
        }
    }

    private var engineNote: String {
        settings.engine == .deepgram
            ? "Слова приходят по ходу речи. Тратит кредиты Deepgram."
            : "Текст приходит кусками с задержкой около секунды. Лимит бесплатный, обновляется каждые сутки."
    }

    private var control: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "клавиша") {
                SettingsRow(title: "Клавиша диктовки", note: "fn не предлагается: она переключает раскладку.", isFirst: true) {
                    Picker("", selection: $settings.hotkeyCode) {
                        ForEach(HotkeyChoice.all) { choice in
                            Text(choice.title).tag(choice.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                SettingsRow(title: "Как работает", note: settings.holdToTalk
                            ? "Держишь — говоришь, отпустил — вставилось."
                            : "Нажал — пошла запись, нажал ещё раз — вставилось.") {
                    Picker("", selection: $settings.holdToTalk) {
                        Text("Удержание").tag(true)
                        Text("Переключатель").tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                SettingsRow(title: "Проверка", note: probe.tapAlive
                            ? "Нажми выбранную клавишу — здесь видно, ловит ли её приложение."
                            : "Клавиши не ловятся: нет Универсального доступа.") {
                    HStack(spacing: 10) {
                        StatusDot(ok: probe.isPressed || probe.lastCode == settings.hotkeyCode)
                        Text(probe.caught)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                            .frame(width: 190, alignment: .trailing)
                    }
                }
            }

            SettingsCard(title: "остановка") {
                SettingsRow(title: "Замолчал — закончили", note: "Диктовка завершается сама, дожимать клавишу не нужно.", isFirst: true) {
                    Toggle("", isOn: $settings.stopOnSilence).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
                }
                if settings.stopOnSilence {
                    SettingsRow(title: "Пауза до остановки") {
                        HStack(spacing: 10) {
                            Slider(value: $settings.silenceSeconds, in: 0.6...4, step: 0.1).frame(width: 150)
                            Text(String(format: "%.1f с", settings.silenceSeconds))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }

            SettingsCard(title: "капсула") {
                SettingsRow(title: "Где появляется", isFirst: true) {
                    Picker("", selection: $settings.anchor) {
                        ForEach(CapsuleAnchor.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                SettingsRow(title: "Звук на старте и вставке", note: "Тихий щелчок, если хочется слышать границы записи.") {
                    Toggle("", isOn: $settings.soundFeedback).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
                }
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "обработка перед вставкой") {
                SettingsRow(title: "Что делать с текстом", note: settings.polish.explanation, isFirst: true) {
                    Picker("", selection: $settings.polish) {
                        ForEach(PolishStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                if settings.polish != .off {
                    SettingsRow(title: "Модель", note: "Бесплатная модель Groq. Не успела за 4 секунды — вставляется как есть.") {
                        Picker("", selection: $settings.polishModel) {
                            Text("gpt-oss 120b").tag("openai/gpt-oss-120b")
                            Text("gpt-oss 20b").tag("openai/gpt-oss-20b")
                            Text("qwen 3.8 27b").tag("qwen/qwen3.8-27b")
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                }
            }

            SettingsCard(title: "свои слова") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Имена, термины и названия через запятую — модель перестанет их ломать.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.dim)
                    TextEditor(text: $settings.keyterms)
                        .font(.system(size: 12.5))
                        .scrollContentBackground(.hidden)
                        .background(Theme.ground)
                        .frame(height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                    Text("Например: Kubernetes, PostgreSQL, Deepgram, имена коллег")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim.opacity(0.75))
                }
                .padding(16)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "хранение") {
                SettingsRow(title: "Запоминать диктовки", note: "Хранится только на этом Маке, последние 60 штук.", isFirst: true) {
                    Toggle("", isOn: $settings.keepHistory).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
                }
                SettingsRow(title: "Очистить историю") {
                    Button("Очистить") { history.clear() }
                        .buttonStyle(.bordered)
                        .disabled(history.items.isEmpty)
                }
            }

            if history.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.dim.opacity(0.6))
                    Text("Пока пусто. Продиктуй что-нибудь.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.dim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 42)
            } else {
                VStack(spacing: 8) {
                    ForEach(history.items) { item in
                        HistoryRow(item: item)
                    }
                }
            }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "разрешения") {
                SettingsRow(title: "Микрофон", note: "Без него не с чего распознавать.", isFirst: true) {
                    HStack(spacing: 10) {
                        StatusDot(ok: micGranted)
                        Button("Запросить") { Permissions.requestMicrophone { _ in } }
                            .buttonStyle(.bordered)
                            .disabled(micGranted)
                    }
                }
                SettingsRow(title: "Универсальный доступ", note: "Нужен, чтобы ловить клавишу и вставлять текст в чужие окна.") {
                    HStack(spacing: 10) {
                        StatusDot(ok: axGranted)
                        Button("Открыть") { Permissions.promptAccessibility() }
                            .buttonStyle(.bordered)
                    }
                }
                if !axGranted {
                    SettingsRow(title: "Стоит красным, хотя галка стоит?",
                                note: "После обновления приложения macOS считает его новым. Сними галку «Nier Voice» в списке и поставь заново — этого достаточно.") {
                        EmptyView()
                    }
                }
            }

            SettingsCard(title: "запуск") {
                SettingsRow(title: "Запускать при входе в систему", isFirst: true) {
                    Toggle("", isOn: $settings.launchAtLogin).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
                }
            }

            SettingsCard(title: "о программе") {
                SettingsRow(title: "Nier Voice", note: "Версия \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · собрано на Swift и SwiftUI", isFirst: true) {
                    EmptyView()
                }
                SettingsRow(title: "Выйти из приложения") {
                    Button("Выход") { NSApp.terminate(nil) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - части

private struct KeysCard: View {
    @State private var deepgram = ""
    @State private var groq = ""
    @State private var savedDeepgram = Secrets.masked(Secrets.deepgramService)
    @State private var savedGroq = Secrets.masked(Secrets.groqService)

    var body: some View {
        SettingsCard(title: "ключи") {
            SettingsRow(title: "Ключ Deepgram", note: savedDeepgram.map { "сейчас: \($0)" } ?? "не задан", isFirst: true) {
                HStack(spacing: 8) {
                    SecureField("вставить новый", text: $deepgram)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button("Сохранить") {
                        if Secrets.write(deepgram, to: Secrets.deepgramService) {
                            deepgram = ""
                            savedDeepgram = Secrets.masked(Secrets.deepgramService)
                        }
                    }
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .disabled(deepgram.isEmpty)
                }
            }
            SettingsRow(title: "Ключ Groq", note: savedGroq.map { "сейчас: \($0)" } ?? "не задан") {
                HStack(spacing: 8) {
                    SecureField("вставить новый", text: $groq)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button("Сохранить") {
                        if Secrets.write(groq, to: Secrets.groqService) {
                            groq = ""
                            savedGroq = Secrets.masked(Secrets.groqService)
                        }
                    }
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .disabled(groq.isEmpty)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let item: Dictation
    @State private var copied = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(Self.formatter.string(from: item.date))
                    Text("·")
                    Text(item.engine)
                    Text("·")
                    Text(String(format: "%.0f с", item.seconds))
                }
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 8)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copied ? Theme.good : Theme.dim)
            }
            .buttonStyle(.plain)
            .help("Скопировать")
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

/// Маленькая волна в шапке боковой колонки — тот же мотив, что в капсуле.
private struct MiniWave: View {
    var body: some View {
        Canvas { context, size in
            let bars = 5
            let gap: CGFloat = 3
            let width = (size.width - gap * CGFloat(bars - 1)) / CGFloat(bars)
            let heights: [CGFloat] = [0.35, 0.7, 1.0, 0.62, 0.28]
            for i in 0..<bars {
                let h = size.height * heights[i]
                let rect = CGRect(x: CGFloat(i) * (width + gap), y: (size.height - h) / 2, width: width, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(Theme.accent))
            }
        }
    }
}
