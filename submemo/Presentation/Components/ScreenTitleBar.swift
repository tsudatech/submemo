//
//  ScreenTitleBar.swift
//  submemo
//
//  タブ画面（ホーム・集計・通知・設定）の見出し行。
//
//  ホームだけ右側にボタンが並ぶため、素直に組むとボタンの高さに引きずられて
//  見出しの位置が他の画面より下がる。ボタンの有無に関わらず行の高さを固定して、
//  4画面で見出しの位置が揃うようにしている。
//

import SwiftUI

struct ScreenTitleBar<Accessory: View>: View {
    let titleKey: String
    var tracking: CGFloat = 0
    @ViewBuilder var accessory: Accessory

    /// 右側のボタン（32pt）が収まる高さ。
    static var rowHeight: CGFloat { 32 }

    var body: some View {
        HStack(spacing: 8) {
            Text(titleKey.loc)
                .font(SM.f(15, .bold))
                .tracking(tracking)
                .foregroundStyle(SM.fg)
            Spacer(minLength: 8)
            accessory
        }
        .frame(height: Self.rowHeight)
        .padding(.horizontal, 20)
        .padding(.top, 2)
    }
}

extension ScreenTitleBar where Accessory == EmptyView {
    init(_ titleKey: String, tracking: CGFloat = 0) {
        self.init(titleKey: titleKey, tracking: tracking, accessory: { EmptyView() })
    }
}
