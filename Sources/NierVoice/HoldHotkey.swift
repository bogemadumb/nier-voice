import AppKit

enum Diag {
    static let on = CommandLine.arguments.contains("--diag")
    static func log(_ message: String) {
        guard on else { return }
        FileHandle.standardError.write(("[diag] " + message + "\n").data(using: .utf8)!)
    }
}

/// Ловит модификатор-клавишу глобально. fn намеренно не поддерживается:
/// на этом Маке она переключает раскладку.
final class HoldHotkey {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isDown = false
    private var keyCode: Int64

    private let onDown: () -> Void
    private let onUp: () -> Void

    /// любое пойманное нажатие модификатора — для индикатора в настройках
    var onAnyModifier: ((Int, Bool) -> Void)?

    init(keyCode: Int, onDown: @escaping () -> Void, onUp: @escaping () -> Void) {
        self.keyCode = Int64(keyCode)
        self.onDown = onDown
        self.onUp = onUp
    }

    func setKey(_ code: Int) {
        keyCode = Int64(code)
        isDown = false
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let hotkey = Unmanaged<HoldHotkey>.fromOpaque(refcon).takeUnretainedValue()
            hotkey.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Diag.log("tapCreate вернул nil — нет прав Универсального доступа")
            return false
        }

        Diag.log("tap создан, слушаю keyCode \(keyCode)")
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        tap = nil
        source = nil
        isDown = false
    }

    private func flag(for code: Int64) -> CGEventFlags {
        switch code {
        case 54, 55: return .maskCommand
        case 60, 56: return .maskShift
        case 62, 59: return .maskControl
        default: return .maskAlternate
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // система отключает тап при перегрузке — поднимаем обратно
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        Diag.log("flagsChanged: keyCode \(code), flags \(event.flags.rawValue)")

        let anyPressed = event.flags.contains(flag(for: code))
        if let report = onAnyModifier {
            DispatchQueue.main.async { report(Int(code), anyPressed) }
        }

        guard code == keyCode else { return }

        let pressed = event.flags.contains(flag(for: keyCode))
        Diag.log("моя клавиша, нажата: \(pressed)")
        guard pressed != isDown else { return }
        isDown = pressed

        let action = pressed ? onDown : onUp
        DispatchQueue.main.async(execute: action)
    }
}
