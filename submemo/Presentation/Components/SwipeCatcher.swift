//
//  SwipeCatcher.swift
//  submemo
//
//  一覧行の「左スワイプで編集・削除」用のジェスチャ。
//
//  SwiftUI の DragGesture は縦方向の指の動きでも認識されるため、行に付けると
//  ScrollView のスクロールを奪ってしまう。ここでは UIPanGestureRecognizer を
//  使い、開始判定（gestureRecognizerShouldBegin）で「横向きが優勢なときだけ
//  始める」ようにして、縦スクロールはそのまま ScrollView に通す。
//  タップも同じビューで受けて、行の開閉／詳細への遷移を出し分ける。
//

import SwiftUI
import UIKit

struct SwipeCatcher: UIViewRepresentable {
    /// ドラッグ中。引数は今回のジェスチャ開始点からの移動量。
    var onChange: (CGFloat) -> Void
    /// 指を離した。引数は最終的な移動量。
    var onEnd: (CGFloat) -> Void
    /// タップされた。
    var onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onEnd: onEnd, onTap: onTap)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGFloat) -> Void
        var onEnd: (CGFloat) -> Void
        var onTap: () -> Void

        init(onChange: @escaping (CGFloat) -> Void,
             onEnd: @escaping (CGFloat) -> Void,
             onTap: @escaping () -> Void) {
            self.onChange = onChange
            self.onEnd = onEnd
            self.onTap = onTap
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            let dx = g.translation(in: g.view).x
            switch g.state {
            case .changed:
                onChange(dx)
            case .ended, .cancelled, .failed:
                onEnd(dx)
            default:
                break
            }
        }

        @objc func handleTap() { onTap() }

        /// 横向きが明確に優勢なときだけパンを開始する。それ以外は認識せず、
        /// 触れた指はそのまま ScrollView のスクロールに使われる。
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.5
        }
    }
}
