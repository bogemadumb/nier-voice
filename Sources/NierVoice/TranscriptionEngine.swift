import Foundation

/// Один интерфейс на все движки распознавания: Deepgram сейчас, Groq — когда кончатся кредиты.
protocol TranscriptionEngine: AnyObject {
    var onPartial: ((String) -> Void)? { get set }
    var onFinal: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    /// Открыть поток. Вызывается в момент нажатия клавиши диктовки.
    func start()
    /// Кусок звука: 16 кГц, моно, linear16.
    func send(_ pcm: Data)
    /// Закрыть поток и дождаться хвоста расшифровки.
    func finish()
    /// Бросить всё без результата (Esc).
    func cancel()
}

enum EngineKind: String {
    case deepgram
    case groq
}
