import Foundation

/// Живой поток в Deepgram: слова приходят черновыми и подтверждаются на ходу.
final class DeepgramEngine: NSObject, TranscriptionEngine {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var keepAlive: Timer?
    private var closing = false

    private var language = "multi"
    private var keyterms: [String] = []

    private var url: URL {
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            .init(name: "model", value: "nova-3"),
            .init(name: "language", value: language),      // multi — русский с английскими терминами внутри фразы
            .init(name: "encoding", value: "linear16"),
            .init(name: "sample_rate", value: "16000"),
            .init(name: "channels", value: "1"),
            .init(name: "interim_results", value: "true"),
            .init(name: "smart_format", value: "true"),
            .init(name: "punctuate", value: "true"),
            .init(name: "endpointing", value: "300")
        ]
        // свои термины подсказкой: имена и названия перестают ломаться
        for term in keyterms.prefix(40) {
            components.queryItems?.append(.init(name: "keyterm", value: term))
        }
        return components.url!
    }

    func start() {
        guard let key = Secrets.read(Secrets.deepgramService) else {
            onError?("нет ключа Deepgram в связке ключей")
            return
        }
        closing = false
        MainActor.assumeIsolated {
            language = Settings.shared.language
            keyterms = Settings.shared.keytermList
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        self.session = session
        let socket = session.webSocketTask(with: request)
        self.socket = socket
        socket.resume()
        receive()

        keepAlive = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.sendJSON(["type": "KeepAlive"])
        }
    }

    func send(_ pcm: Data) {
        socket?.send(.data(pcm)) { [weak self] error in
            if let error { self?.report(error) }
        }
    }

    func finish() {
        closing = true
        keepAlive?.invalidate()
        keepAlive = nil
        sendJSON(["type": "CloseStream"])
        // хвост расшифровки приходит уже после CloseStream — рвать соединение сразу нельзя
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.teardown() }
    }

    func cancel() {
        closing = true
        keepAlive?.invalidate()
        keepAlive = nil
        teardown()
    }

    private func teardown() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        socket?.send(.string(text)) { _ in }
    }

    private func receive() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.report(error)
            case .success(let message):
                switch message {
                case .string(let text): self.handle(text)
                case .data(let data): self.handle(String(decoding: data, as: UTF8.self))
                @unknown default: break
                }
                self.receive()
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        guard (json["type"] as? String) == "Results",
              let channel = json["channel"] as? [String: Any],
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String
        else { return }

        let isFinal = (json["is_final"] as? Bool) ?? false
        guard !transcript.isEmpty else { return }

        DispatchQueue.main.async {
            if isFinal { self.onFinal?(transcript) } else { self.onPartial?(transcript) }
        }
    }

    private func report(_ error: Error) {
        guard !closing else { return }
        let message = (error as NSError).localizedDescription
        DispatchQueue.main.async { self.onError?(message) }
    }
}
