import AppKit

/// Кладёт готовый текст туда, где стоит курсор, и возвращает буфер обмена как было.
enum TextInserter {
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data] in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { copy[type] = data }
            }
            return copy
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        pressCommandV()

        // буфер возвращаем не сразу: вставка успевает прочитать его
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            restore(saved, to: pasteboard)
        }
    }

    private static func pressCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let v: CGKeyCode = 9

        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func restore(_ saved: [[NSPasteboard.PasteboardType: Data]]?, to pasteboard: NSPasteboard) {
        guard let saved, !saved.isEmpty else { return }
        pasteboard.clearContents()
        let items = saved.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
