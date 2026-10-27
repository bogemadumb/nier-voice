import SwiftUI
import ServiceManagement

enum PolishStyle: String, CaseIterable, Identifiable {
    case off, clean, business, chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Как сказано"
        case .clean: return "Прибрать"
        case .business: return "Деловой"
        case .chat: return "Разговорный"
        }
    }

    var explanation: String {
        switch self {
        case .off: return "Текст уходит ровно таким, каким его услышала модель."
        case .clean: return "Убрать «эканье» и повторы, расставить знаки. Слова и порядок не менять."
        case .business: return "Прибрать и подтянуть до делового письма: полные предложения, без просторечий."
        case .chat: return "Прибрать, но оставить живую речь — как пишут в мессенджере."
        }
    }
}

enum CapsuleAnchor: String, CaseIterable, Identifiable {
    case bottom, cursor
    var id: String { rawValue }
    var title: String { self == .bottom ? "Внизу экрана" : "У курсора" }
}

struct HotkeyChoice: Identifiable, Equatable {
    let id: Int
    let title: String
    static let all: [HotkeyChoice] = [
        .init(id: 61, title: "Правая ⌥"),
        .init(id: 54, title: "Правая ⌘"),
        .init(id: 62, title: "Правый ⌃"),
        .init(id: 60, title: "Правая ⇧")
    ]
    static func title(for code: Int) -> String {
        all.first { $0.id == code }?.title ?? "Правая ⌥"
    }
}

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var engine: EngineKind { didSet { defaults.set(engine.rawValue, forKey: "engine") } }
    @Published var language: String { didSet { defaults.set(language, forKey: "language") } }
    @Published var hotkeyCode: Int { didSet { defaults.set(hotkeyCode, forKey: "hotkeyCode") } }
    @Published var holdToTalk: Bool { didSet { defaults.set(holdToTalk, forKey: "holdToTalk") } }
    @Published var stopOnSilence: Bool { didSet { defaults.set(stopOnSilence, forKey: "stopOnSilence") } }
    @Published var silenceSeconds: Double { didSet { defaults.set(silenceSeconds, forKey: "silenceSeconds") } }
    @Published var polish: PolishStyle { didSet { defaults.set(polish.rawValue, forKey: "polish") } }
    @Published var polishModel: String { didSet { defaults.set(polishModel, forKey: "polishModel") } }
    @Published var keyterms: String { didSet { defaults.set(keyterms, forKey: "keyterms") } }
    @Published var anchor: CapsuleAnchor { didSet { defaults.set(anchor.rawValue, forKey: "anchor") } }
    @Published var keepHistory: Bool { didSet { defaults.set(keepHistory, forKey: "keepHistory") } }
    @Published var soundFeedback: Bool { didSet { defaults.set(soundFeedback, forKey: "soundFeedback") } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    var keytermList: [String] {
        keyterms
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private init() {
        defaults.register(defaults: [
            "engine": EngineKind.deepgram.rawValue,
            "language": "multi",
            "hotkeyCode": 61,
            "holdToTalk": true,
            "stopOnSilence": true,
            "silenceSeconds": 1.5,
            "polish": PolishStyle.clean.rawValue,
            "polishModel": "openai/gpt-oss-120b",
            "keyterms": "Deepgram, Groq, Telegram, Claude, Kubernetes, PostgreSQL",
            "anchor": CapsuleAnchor.bottom.rawValue,
            "keepHistory": true,
            "soundFeedback": false
        ])

        engine = EngineKind(rawValue: defaults.string(forKey: "engine") ?? "") ?? .deepgram
        language = defaults.string(forKey: "language") ?? "multi"
        hotkeyCode = defaults.integer(forKey: "hotkeyCode")
        holdToTalk = defaults.bool(forKey: "holdToTalk")
        stopOnSilence = defaults.bool(forKey: "stopOnSilence")
        silenceSeconds = defaults.double(forKey: "silenceSeconds")
        polish = PolishStyle(rawValue: defaults.string(forKey: "polish") ?? "") ?? .clean
        polishModel = defaults.string(forKey: "polishModel") ?? "openai/gpt-oss-120b"
        keyterms = defaults.string(forKey: "keyterms") ?? ""
        anchor = CapsuleAnchor(rawValue: defaults.string(forKey: "anchor") ?? "") ?? .bottom
        keepHistory = defaults.bool(forKey: "keepHistory")
        soundFeedback = defaults.bool(forKey: "soundFeedback")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
