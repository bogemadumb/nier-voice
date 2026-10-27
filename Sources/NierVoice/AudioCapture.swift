import AVFoundation

/// Микрофон: даёт громкость для волны и куски PCM 16 кГц для потока распознавания.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var running = false
    private var smoothed: Double = 0

    private let target = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    var onLevel: ((Double) -> Void)?
    var onPCM: ((Data) -> Void)?

    func start() {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        converter = AVAudioConverter(from: format, to: target)

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.consume(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        smoothed = 0
        converter = nil
        let report = onLevel
        DispatchQueue.main.async { report?(0) }
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        reportLevel(buffer)
        guard let converter, let data = convert(buffer, with: converter) else { return }
        onPCM?(data)
    }

    private func reportLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        let rms = Double(sqrt(sum / Float(count)))

        // из линейного RMS в шкалу, где обычная речь занимает верхнюю половину
        let db = 20 * log10(max(rms, 1e-7))
        let normalized = min(1, max(0, (db + 52) / 40))
        smoothed += (normalized - smoothed) * (normalized > smoothed ? 0.45 : 0.14)

        let value = smoothed
        let report = onLevel
        DispatchQueue.main.async { report?(value) }
    }

    private func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> Data? {
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 256
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let channel = out.int16ChannelData else { return nil }

        return Data(bytes: channel[0], count: Int(out.frameLength) * MemoryLayout<Int16>.size)
    }
}
