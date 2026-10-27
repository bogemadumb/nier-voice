import SwiftUI
import AppKit

/// Одна палитра на капсулу и на настройки, чтобы приложение выглядело цельным.
enum Theme {
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    static let accent = dynamic(
        light: NSColor(srgbRed: 0.055, green: 0.549, blue: 0.486, alpha: 1),
        dark: NSColor(srgbRed: 0.388, green: 0.851, blue: 0.776, alpha: 1)
    )
    static let accentSoft = dynamic(
        light: NSColor(srgbRed: 0.055, green: 0.549, blue: 0.486, alpha: 0.12),
        dark: NSColor(srgbRed: 0.388, green: 0.851, blue: 0.776, alpha: 0.16)
    )
    static let warm = dynamic(
        light: NSColor(srgbRed: 0.718, green: 0.439, blue: 0.165, alpha: 1),
        dark: NSColor(srgbRed: 0.898, green: 0.651, blue: 0.388, alpha: 1)
    )
    static let ground = dynamic(
        light: NSColor(srgbRed: 0.953, green: 0.965, blue: 0.961, alpha: 1),
        dark: NSColor(srgbRed: 0.031, green: 0.051, blue: 0.067, alpha: 1)
    )
    static let sidebar = dynamic(
        light: NSColor(srgbRed: 0.918, green: 0.933, blue: 0.929, alpha: 1),
        dark: NSColor(srgbRed: 0.047, green: 0.075, blue: 0.094, alpha: 1)
    )
    static let card = dynamic(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.071, green: 0.106, blue: 0.129, alpha: 1)
    )
    static let hairline = dynamic(
        light: NSColor(srgbRed: 0.827, green: 0.855, blue: 0.851, alpha: 1),
        dark: NSColor(srgbRed: 0.157, green: 0.212, blue: 0.243, alpha: 1)
    )
    static let text = dynamic(
        light: NSColor(srgbRed: 0.075, green: 0.106, blue: 0.122, alpha: 1),
        dark: NSColor(srgbRed: 0.894, green: 0.922, blue: 0.918, alpha: 1)
    )
    static let dim = dynamic(
        light: NSColor(srgbRed: 0.361, green: 0.420, blue: 0.443, alpha: 1),
        dark: NSColor(srgbRed: 0.553, green: 0.627, blue: 0.651, alpha: 1)
    )
    static let good = dynamic(
        light: NSColor(srgbRed: 0.106, green: 0.545, blue: 0.361, alpha: 1),
        dark: NSColor(srgbRed: 0.376, green: 0.788, blue: 0.596, alpha: 1)
    )
    static let bad = dynamic(
        light: NSColor(srgbRed: 0.702, green: 0.243, blue: 0.216, alpha: 1),
        dark: NSColor(srgbRed: 0.898, green: 0.435, blue: 0.400, alpha: 1)
    )
}

/// Карточка с настройками: заголовок секции и строки внутри.
struct SettingsCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Theme.dim)
                    .padding(.leading, 2)
            }
            VStack(spacing: 0) { content }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
    }
}

/// Строка настройки: слева название и пояснение, справа контрол.
struct SettingsRow<Control: View>: View {
    var title: String
    var note: String? = nil
    var isFirst: Bool = false
    @ViewBuilder var control: Control

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if let note {
                        Text(note)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                control
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// Точка состояния: выдано или нет.
struct StatusDot: View {
    var ok: Bool
    var body: some View {
        Circle()
            .fill(ok ? Theme.good : Theme.bad)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke((ok ? Theme.good : Theme.bad).opacity(0.28), lineWidth: 4))
    }
}
