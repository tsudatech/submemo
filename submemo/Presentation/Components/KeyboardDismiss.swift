//
//  KeyboardDismiss.swift
//  submemo
//
//  キーボードの外側をタップしたら閉じる挙動。キーウィンドウへタップジェスチャを
//  1度だけ仕込む方式で、画面ごとに書かなくてもアプリ全体（シートの中も含む）に効く。
//
//  ・cancelsTouchesInView = false なので、既存のタップ操作を横取りしない。
//  ・入力欄そのものや、ボタン等（UIControl）の上のタップは無視する。
//    ここを見ないと、入力欄をタップした瞬間に閉じてしまう。
//  （shoplist / habits の KeyboardDismiss を流用）
//

import SwiftUI
import UIKit

private final class TapToDismissKeyboard: NSObject, UIGestureRecognizerDelegate {
    static let shared = TapToDismissKeyboard()
    private var installed = false

    func installIfNeeded() {
        guard !installed else { return }
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installed = true
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextView || current is UITextField || current is UIControl { return false }
            view = current.superview
        }
        return true
    }
}

private struct KeyboardDismissOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear { TapToDismissKeyboard.shared.installIfNeeded() }
    }
}

extension View {
    /// キーボードの外側タップで閉じる挙動を有効化する。ルートに1度だけ付ければよい。
    func dismissKeyboardOnTapOutside() -> some View {
        modifier(KeyboardDismissOnTap())
    }
}
