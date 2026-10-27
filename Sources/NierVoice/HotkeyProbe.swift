import SwiftUI

/// Живой индикатор в настройках: видно, ловит ли приложение нажатия
/// и та ли это клавиша, которая выбрана.
@MainActor
final class HotkeyProbe: ObservableObject {
    static let shared = HotkeyProbe()

    @Published var lastCode: Int?
    @Published var isPressed = false
    @Published var tapAlive = false

    private var reset: Timer?

    func report(code: Int, pressed: Bool) {
        lastCode = code
        isPressed = pressed
        reset?.invalidate()
        guard !pressed else { return }
        // подсветку держим секунду после отпускания, чтобы её успели заметить
        reset = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.lastCode = self?.lastCode }
        }
    }

    var caught: String {
        guard let lastCode else { return "нажми клавишу — проверим" }
        let name = HotkeyChoice.all.first { $0.id == lastCode }?.title ?? "клавиша \(lastCode)"
        return isPressed ? "держишь \(name)" : "поймана \(name)"
    }
}
