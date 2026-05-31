//
//  ShortcutFormatting.swift
//  Clip Board Pro
//

import AppKit
import Carbon

enum ShortcutFormatting {

    static func displayString(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []

        if modifiers & Int(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & Int(optionKey) != 0 { parts.append("⌥") }
        if modifiers & Int(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & Int(controlKey) != 0 { parts.append("⌃") }

        parts.append(keyCodeDisplayName(for: keyCode))
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    private static func keyCodeDisplayName(for keyCode: Int) -> String {
        if let named = ansiKeyNames[keyCode] {
            return named
        }
        return "Key \(keyCode)"
    }

    private static let ansiKeyNames: [Int: String] = [
        Int(kVK_ANSI_A): "A", Int(kVK_ANSI_B): "B", Int(kVK_ANSI_C): "C",
        Int(kVK_ANSI_D): "D", Int(kVK_ANSI_E): "E", Int(kVK_ANSI_F): "F",
        Int(kVK_ANSI_G): "G", Int(kVK_ANSI_H): "H", Int(kVK_ANSI_I): "I",
        Int(kVK_ANSI_J): "J", Int(kVK_ANSI_K): "K", Int(kVK_ANSI_L): "L",
        Int(kVK_ANSI_M): "M", Int(kVK_ANSI_N): "N", Int(kVK_ANSI_O): "O",
        Int(kVK_ANSI_P): "P", Int(kVK_ANSI_Q): "Q", Int(kVK_ANSI_R): "R",
        Int(kVK_ANSI_S): "S", Int(kVK_ANSI_T): "T", Int(kVK_ANSI_U): "U",
        Int(kVK_ANSI_V): "V", Int(kVK_ANSI_W): "W", Int(kVK_ANSI_X): "X",
        Int(kVK_ANSI_Y): "Y", Int(kVK_ANSI_Z): "Z",
        Int(kVK_ANSI_0): "0", Int(kVK_ANSI_1): "1", Int(kVK_ANSI_2): "2",
        Int(kVK_ANSI_3): "3", Int(kVK_ANSI_4): "4", Int(kVK_ANSI_5): "5",
        Int(kVK_ANSI_6): "6", Int(kVK_ANSI_7): "7", Int(kVK_ANSI_8): "8",
        Int(kVK_ANSI_9): "9",
        Int(kVK_Space): "Space",
        Int(kVK_Return): "Return",
        Int(kVK_Tab): "Tab",
        Int(kVK_Escape): "Esc",
    ]
}
