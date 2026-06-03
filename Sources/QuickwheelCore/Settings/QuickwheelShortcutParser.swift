import Carbon.HIToolbox
import Foundation

struct ParsedQuickwheelShortcut: Equatable {
    let keyCode: Int
    let modifiers: ShortcutModifiers
}

enum QuickwheelShortcutParser {
    static func parse(_ shortcut: String) -> ParsedQuickwheelShortcut? {
        let normalizedShortcut = shortcut
            .replacingOccurrences(of: "⌘", with: "+cmd+")
            .replacingOccurrences(of: "⇧", with: "+shift+")
            .replacingOccurrences(of: "⌥", with: "+option+")
            .replacingOccurrences(of: "⌃", with: "+control+")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        let parts = normalizedShortcut
            .split(separator: "+")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let keyAlias = parts.last else {
            return nil
        }

        let modifierAliases = Array(parts.dropLast())
        guard modifierAliases.allSatisfy(ShortcutModifiers.isModifierAlias) else {
            return nil
        }

        let modifiers = ShortcutModifiers.fromAliases(modifierAliases)

        guard let keyCode = keyCode(for: keyAlias) else {
            return nil
        }

        return ParsedQuickwheelShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    static func normalizedDisplayName(keyCode: Int, modifiers: ShortcutModifiers) -> String {
        let keyName = keyName(for: keyCode) ?? "keyCode:\(keyCode)"
        let modifierName = modifiers.shortDisplayName

        guard !modifierName.isEmpty else {
            return keyName
        }

        return "\(modifierName)+\(keyName)"
    }

    private static func keyCode(for alias: String) -> Int? {
        if alias.hasPrefix("keycode:") {
            return Int(alias.replacingOccurrences(of: "keycode:", with: ""))
        }

        return keyCodeByAlias[alias]
    }

    private static func keyName(for keyCode: Int) -> String? {
        keyNameByCode[keyCode]
    }

    private static let keyCodeByAlias: [String: Int] = [
        "a": kVK_ANSI_A,
        "b": kVK_ANSI_B,
        "c": kVK_ANSI_C,
        "d": kVK_ANSI_D,
        "e": kVK_ANSI_E,
        "f": kVK_ANSI_F,
        "g": kVK_ANSI_G,
        "h": kVK_ANSI_H,
        "i": kVK_ANSI_I,
        "j": kVK_ANSI_J,
        "k": kVK_ANSI_K,
        "l": kVK_ANSI_L,
        "m": kVK_ANSI_M,
        "n": kVK_ANSI_N,
        "o": kVK_ANSI_O,
        "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q,
        "r": kVK_ANSI_R,
        "s": kVK_ANSI_S,
        "t": kVK_ANSI_T,
        "u": kVK_ANSI_U,
        "v": kVK_ANSI_V,
        "w": kVK_ANSI_W,
        "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0,
        "1": kVK_ANSI_1,
        "2": kVK_ANSI_2,
        "3": kVK_ANSI_3,
        "4": kVK_ANSI_4,
        "5": kVK_ANSI_5,
        "6": kVK_ANSI_6,
        "7": kVK_ANSI_7,
        "8": kVK_ANSI_8,
        "9": kVK_ANSI_9,
        "`": kVK_ANSI_Grave,
        "grave": kVK_ANSI_Grave,
        "minus": kVK_ANSI_Minus,
        "=": kVK_ANSI_Equal,
        "equal": kVK_ANSI_Equal,
        "[": kVK_ANSI_LeftBracket,
        "leftbracket": kVK_ANSI_LeftBracket,
        "]": kVK_ANSI_RightBracket,
        "rightbracket": kVK_ANSI_RightBracket,
        "\\": kVK_ANSI_Backslash,
        "backslash": kVK_ANSI_Backslash,
        ";": kVK_ANSI_Semicolon,
        "semicolon": kVK_ANSI_Semicolon,
        "'": kVK_ANSI_Quote,
        "quote": kVK_ANSI_Quote,
        ",": kVK_ANSI_Comma,
        "comma": kVK_ANSI_Comma,
        ".": kVK_ANSI_Period,
        "period": kVK_ANSI_Period,
        "/": kVK_ANSI_Slash,
        "slash": kVK_ANSI_Slash,
        "space": kVK_Space,
        "tab": kVK_Tab,
        "return": kVK_Return,
        "enter": kVK_Return,
        "escape": kVK_Escape,
        "esc": kVK_Escape,
        "delete": kVK_Delete,
        "backspace": kVK_Delete,
        "forwarddelete": kVK_ForwardDelete,
        "home": kVK_Home,
        "end": kVK_End,
        "pageup": kVK_PageUp,
        "pagedown": kVK_PageDown,
        "left": kVK_LeftArrow,
        "leftarrow": kVK_LeftArrow,
        "right": kVK_RightArrow,
        "rightarrow": kVK_RightArrow,
        "up": kVK_UpArrow,
        "uparrow": kVK_UpArrow,
        "down": kVK_DownArrow,
        "downarrow": kVK_DownArrow,
        "f1": kVK_F1,
        "f2": kVK_F2,
        "f3": kVK_F3,
        "f4": kVK_F4,
        "f5": kVK_F5,
        "f6": kVK_F6,
        "f7": kVK_F7,
        "f8": kVK_F8,
        "f9": kVK_F9,
        "f10": kVK_F10,
        "f11": kVK_F11,
        "f12": kVK_F12,
        "f13": kVK_F13,
        "f14": kVK_F14,
        "f15": kVK_F15,
        "f16": kVK_F16,
        "f17": kVK_F17,
        "f18": kVK_F18,
        "f19": kVK_F19,
        "f20": kVK_F20
    ]

    private static let keyNameByCode: [Int: String] = [
        kVK_ANSI_A: "a",
        kVK_ANSI_B: "b",
        kVK_ANSI_C: "c",
        kVK_ANSI_D: "d",
        kVK_ANSI_E: "e",
        kVK_ANSI_F: "f",
        kVK_ANSI_G: "g",
        kVK_ANSI_H: "h",
        kVK_ANSI_I: "i",
        kVK_ANSI_J: "j",
        kVK_ANSI_K: "k",
        kVK_ANSI_L: "l",
        kVK_ANSI_M: "m",
        kVK_ANSI_N: "n",
        kVK_ANSI_O: "o",
        kVK_ANSI_P: "p",
        kVK_ANSI_Q: "q",
        kVK_ANSI_R: "r",
        kVK_ANSI_S: "s",
        kVK_ANSI_T: "t",
        kVK_ANSI_U: "u",
        kVK_ANSI_V: "v",
        kVK_ANSI_W: "w",
        kVK_ANSI_X: "x",
        kVK_ANSI_Y: "y",
        kVK_ANSI_Z: "z",
        kVK_ANSI_0: "0",
        kVK_ANSI_1: "1",
        kVK_ANSI_2: "2",
        kVK_ANSI_3: "3",
        kVK_ANSI_4: "4",
        kVK_ANSI_5: "5",
        kVK_ANSI_6: "6",
        kVK_ANSI_7: "7",
        kVK_ANSI_8: "8",
        kVK_ANSI_9: "9",
        kVK_Space: "space",
        kVK_Tab: "tab",
        kVK_Return: "return",
        kVK_Escape: "escape",
        kVK_Delete: "delete",
        kVK_LeftArrow: "left",
        kVK_RightArrow: "right",
        kVK_UpArrow: "up",
        kVK_DownArrow: "down",
        kVK_F1: "f1",
        kVK_F2: "f2",
        kVK_F3: "f3",
        kVK_F4: "f4",
        kVK_F5: "f5",
        kVK_F6: "f6",
        kVK_F7: "f7",
        kVK_F8: "f8",
        kVK_F9: "f9",
        kVK_F10: "f10",
        kVK_F11: "f11",
        kVK_F12: "f12",
        kVK_F13: "f13",
        kVK_F14: "f14",
        kVK_F15: "f15",
        kVK_F16: "f16",
        kVK_F17: "f17",
        kVK_F18: "f18",
        kVK_F19: "f19",
        kVK_F20: "f20"
    ]
}

private extension ShortcutModifiers {
    var shortDisplayName: String {
        var parts: [String] = []

        if contains(.control) {
            parts.append("ctrl")
        }

        if contains(.option) {
            parts.append("opt")
        }

        if contains(.shift) {
            parts.append("shift")
        }

        if contains(.command) {
            parts.append("cmd")
        }

        return parts.joined(separator: "+")
    }
}
