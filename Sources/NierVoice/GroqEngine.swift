import Foundation

/// Запасной движок: у Groq нет потока, поэтому копим звук и перераспознаём его целиком
/// раз в несколько секунд. Текст приходит кусками с задержкой около секунды, но лимит
/// бесплатный и возобновляется каждые сутки.
final class GroqEngine: NSObject, TranscriptionEngine {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let model = "whisper-large-v3-turbo"
    private let interval: TimeInterval = 4
    private let queue = DispatchQueue(label: "niervoice.groq")

    private var pcm = Data()
    private var timer: Timer?
    private var inFlight = false
    private var stopped = false
    private var language = "ru"
    private var terms: [String] = []

    func start() {
        stopped = false
        pcm = Data()
        MainActor.assumeIsolated {
            let chosen = Settings.shared.language
            language = chosen == "multi" ? "ru" : chosen
            terms = Settings.shared.keytermList
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.transcribe(final: false)
        }
    }

    func send(_ data: Data) {
        queue.async { self.pcm.append(data) }
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        transcribe(final: true)
    }

    func cancel() {
        stopped = true
        timer?.invalidate()
        timer = nil
        queue.async { self.pcm = Data() }
    }

    private func transcribe(final: Bool) {
        guard !stopped, !inFlight || final else { return }
        guard let key = Secrets.read(Secrets.groqService) else {
            DispatchQueue.main.async { self.onError?("нет ключа Groq в связке ключей") }
            return
        }

        queue.async {
            let audio = self.pcm
            guard audio.count > 16000 else { return }     // меньше полсекунды — нечего слать
            let wav = Self.wav(from: audio)
            self.inFlight = true

            let boundary = "niervoice-\(UUID().uuidString)"
            var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            func field(_ name: String, _ value: String) {
                body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
            }
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(wav)
            body.append("\r\n".data(using: .utf8)!)
            field("model", self.model)
            field("language", self.language)
            field("response_format", "json")
            if !self.terms.isEmpty { field("prompt", self.terms.joined(separator: ", ")) }
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            URLSession.shared.dataTask(with: request) { data, _, error in
                self.inFlight = false
                if let error {
                    DispatchQueue.main.async { self.onError?(error.localizedDescription) }
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty
                else { return }

                DispatchQueue.main.async {
                    if final { self.onFinal?(text) } else { self.onPartial?(text) }
                }
            }.resume()
        }
    }

    /// PCM 16 кГц моно → wav с заголовком.
    private static func wav(from pcm: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bits: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bits / 8)
        let blockAlign = channels * (bits / 8)

        var header = Data()
        func ascii(_ s: String) { header.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }

        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(channels); u32(sampleRate); u32(byteRate); u16(blockAlign); u16(bits)
        ascii("data"); u32(UInt32(pcm.count))

        return header + pcm
    }
}
