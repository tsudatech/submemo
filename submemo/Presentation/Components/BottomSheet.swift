//
//  BottomSheet.swift
//  submemo
//
//  下から出るシートの共通の土台（カテゴリ編集・支払い方法編集・CSV書き出し）。
//
//  以前は画面全体に敷いた ZStack の上に自前で組み、キーボードの高さを
//  keyboardWillChangeFrame で拾って自前のアニメーションで押し上げていた。
//  ただ、そのアニメーションの時間とカーブはキーボード側のものと一致しないため、
//  出てくるタイミングがどうしても少しずれる。
//
//  いまは SwiftUI 標準のシート（presentationDetents）に載せている。
//  キーボードに合わせて持ち上げるのは UIKit 側の presentation controller の
//  仕事になるので、タイミングもカーブも完全に一致する（tasks と同じ作り）。
//
//  detent は高さ指定なので、中身の高さを測って渡している。測り終わるまでは
//  estimatedHeight を使うため、呼び出し側はおおよその高さを添える。
//

import SwiftUI

struct BottomSheet<Content: View>: View {
    /// 中身を測り終えるまで使う高さ。だいたいで良い。
    var estimatedHeight: CGFloat = 360
    @ViewBuilder var content: Content

    @State private var measured: CGFloat?

    private struct HeightKey: PreferenceKey {
        static var defaultValue: CGFloat { 0 }
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 20)
                .padding(.top, 22)
                // 下端の余白は標準シートがセーフエリアぶんを別に確保するので、ここでは控えめに。
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(key: HeightKey.self, value: inner.size.height)
                    }
                )
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(HeightKey.self) { height in
            if height > 0 { measured = height }
        }
        .presentationDetents([.height(measured ?? estimatedHeight)])
        .presentationBackground(SM.card)
        .presentationCornerRadius(26)
        .presentationDragIndicator(.hidden)
    }
}
