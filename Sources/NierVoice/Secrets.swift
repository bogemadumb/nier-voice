import Foundation

/// Ключи лежат в файле с правами 600 в Application Support приложения.
/// Связка ключей не годится: при ad-hoc подписи каждая пересборка меняет
/// идентичность приложения, и macOS спрашивает пароль заново.
enum Secrets {
    static let deepgramService = "deepgram"
    static let groqService = "groq"

    private static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NierVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("keys.json")
    }()

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    static func read(_ service: String) -> String? {
        let value = load()[service]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    @discardableResult
    static func write(_ value: String, to service: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var keys = load()
        keys[service] = trimmed
        guard let data = try? JSONEncoder().encode(keys) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            return false
        }
    }

    /// Показывает ключ огрызком: xxxxxx…yyyy — чтобы в настройках было видно, что он на месте.
    static func masked(_ service: String) -> String? {
        guard let key = read(service) else { return nil }
        guard key.count > 12 else { return String(repeating: "•", count: key.count) }
        return String(key.prefix(6)) + "…" + String(key.suffix(4))
    }
}
