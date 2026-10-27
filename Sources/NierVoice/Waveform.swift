import SwiftUI

struct Waveform: View {
    var level: Double
    var color: Color
    var bars: Int = 11

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let gap: CGFloat = 3
                let width = (size.width - gap * CGFloat(bars - 1)) / CGFloat(bars)
                let middle = Double(bars - 1) / 2

                for i in 0..<bars {
                    let distance = abs(Double(i) - middle) / middle
                    let envelope = 1 - distance * 0.72
                    let jitter = 0.55 + abs(sin(t * 5.4 + Double(i) * 1.1)) * 0.45
                    let height = max(3, level * envelope * jitter * size.height * 0.92)
                    let x = CGFloat(i) * (width + gap)
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: width, height: height)
                    let shape = Path(roundedRect: rect, cornerRadius: width / 2)
                    context.fill(shape, with: .color(color.opacity(0.35 + level * 0.6 * envelope)))
                }
            }
        }
    }
}
