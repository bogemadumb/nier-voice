import SwiftUI

struct CapsuleView: View {
    @ObservedObject var state: CapsuleState

    private let corner: CGFloat = 26

    var body: some View {
        capsule
            .background(halo)
        .opacity(state.phase == .idle ? 0 : 1)
        .scaleEffect(state.phase == .idle ? 0.88 : 1, anchor: .bottom)
        .offset(y: state.phase == .sending ? -26 : (state.phase == .idle ? 16 : 0))
        .animation(.spring(response: 0.44, dampingFraction: 0.74), value: state.phase)
    }

    // живой ореол: повторяет силуэт капсулы и разгорается от громкости — сердце направления C
    private var halo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.accent)
                .blur(radius: 22)
                .opacity(0.10 + state.level * 0.34)
                .scaleEffect(x: 1.01 + state.level * 0.015, y: 1.06 + state.level * 0.10)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.accent)
                .blur(radius: 44)
                .opacity(0.06 + state.level * 0.26)
                .scaleEffect(x: 1.03 + state.level * 0.03, y: 1.16 + state.level * 0.18)
        }
        .opacity(state.phase == .idle ? 0 : 1)
        .animation(.easeOut(duration: 0.11), value: state.level)
        .allowsHitTesting(false)
    }

    private var capsule: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 14) {
                Waveform(level: state.level, color: Theme.accent)
                    .frame(width: 64, height: 30)
                    .padding(.top, 2)
                readout
            }
            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 11)
        .frame(width: 520, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Theme.accent.opacity(state.phase == .polishing ? 0.85 : 0.0), lineWidth: 1.4)
                .animation(.easeInOut(duration: 0.25), value: state.phase)
        )
        .shadow(color: .black.opacity(0.42), radius: 26, y: 14)
    }

    @ViewBuilder
    private var readout: some View {
        if state.words.isEmpty {
            Text("Слушаю…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(minHeight: 30, alignment: .topLeading)
        } else {
            FlowLayout(spacing: 6, lineSpacing: 3) {
                ForEach(state.words) { word in
                    Text(word.text)
                        .font(.system(size: 16.5, weight: .regular))
                        .opacity(word.isFinal ? 1 : 0.38)
                        .blur(radius: word.isFinal ? 0 : 0.4)
                        .offset(y: word.isFinal ? 0 : 1.5)
                        .animation(.easeOut(duration: 0.34), value: word.isFinal)
                }
            }
            .frame(minHeight: 30, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Text(status)
            Spacer()
            Text("ESC ОТМЕНА · ОТПУСТИТЬ ВСТАВИТЬ")
        }
        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
        .tracking(0.9)
        .foregroundStyle(.tertiary)
    }

    private var status: String {
        switch state.phase {
        case .idle: return ""
        case .listening: return "ЧЕРНОВИК УТОЧНЯЕТСЯ"
        case .polishing: return "ПОЛИРУЮ ТЕКСТ"
        case .sending: return "ВСТАВЛЯЮ"
        }
    }
}
