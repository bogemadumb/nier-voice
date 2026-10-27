import SwiftUI

@MainActor
final class CapsuleState: ObservableObject {
    enum Phase { case idle, listening, polishing, sending }

    /// id — позиция слова в потоке: слово не пересоздаётся, когда черновик становится финалом,
    /// поэтому переход анимируется, а не мигает.
    struct Word: Identifiable, Equatable {
        let id: Int
        var text: String
        var isFinal: Bool
    }

    @Published var phase: Phase = .idle
    @Published var level: Double = 0
    @Published var engine: EngineKind = .deepgram
    @Published var error: String?

    @Published private(set) var settled: [String] = []   // подтверждённые сегменты
    @Published private(set) var draft: String = ""       // сегмент, который модель ещё уточняет

    var words: [Word] {
        var result: [Word] = []
        for segment in settled {
            for token in segment.split(separator: " ") {
                result.append(Word(id: result.count, text: String(token), isFinal: true))
            }
        }
        for token in draft.split(separator: " ") {
            result.append(Word(id: result.count, text: String(token), isFinal: false))
        }
        return result
    }

    var plainText: String {
        (settled + (draft.isEmpty ? [] : [draft]))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    func beginListening() {
        settled = []
        draft = ""
        error = nil
        level = 0
        phase = .listening
    }

    func applyPartial(_ text: String) {
        draft = text
    }

    func applyFinal(_ text: String) {
        draft = ""
        guard !text.isEmpty else { return }
        settled.append(text)
    }

    func settleDraft() {
        guard !draft.isEmpty else { return }
        settled.append(draft)
        draft = ""
    }

    func idle() {
        phase = .idle
        level = 0
    }
}
