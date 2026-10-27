import Foundation

struct Dictation: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let text: String
    let seconds: Double
    let engine: String

    init(text: String, seconds: Double, engine: String) {
        self.id = UUID()
        self.date = Date()
        self.text = text
        self.seconds = seconds
        self.engine = engine
    }
}

@MainActor
final class History: ObservableObject {
    static let shared = History()
    private static let limit = 60

    @Published private(set) var items: [Dictation] = []

    private let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NierVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }()

    private init() { load() }

    func add(_ item: Dictation) {
        items.insert(item, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Dictation].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
