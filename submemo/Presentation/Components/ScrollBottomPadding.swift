//
//  ScrollBottomPadding.swift
//  submemo
//
//  ScrollView のコンテンツ末尾に共通の余白を追加する ViewModifier。
//  最後の要素が下部タブバーやホームインジケータに貼りつかないようにするために使う。
//  （shoplist / tasks の ScrollBottomPadding に準拠）
//
//  使い方:
//    ScrollView { ... }
//      .scrollBottomPadding()
//
//  余白の値は ScrollBottomPadding.value を編集する。個別のビューで上書きしない。
//

import SwiftUI

struct ScrollBottomPadding: ViewModifier {
    /// 末尾の共通余白。タブバー自体は safeAreaInset で避けているので、
    /// ここは「読み終わりのゆとり」ぶんだけ持たせる。
    static let value: CGFloat = 96

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, Self.value, for: .scrollContent)
    }
}

extension View {
    func scrollBottomPadding() -> some View {
        modifier(ScrollBottomPadding())
    }
}
