//
//  BaseCurrencyScreen.swift
//  submemo
//
//  設定 →「表示する通貨」。合計をどの通貨で出すかを選ぶ。
//  各サブスクを登録するときの通貨（Currency）とは別で、こちらは表示だけに効く。
//

import SwiftUI

struct BaseCurrencyScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "base_title")

                Text("base_note".loc)
                    .font(SM.f(11.5)).lineSpacing(9).foregroundStyle(SM.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24).padding(.top, 20)

                VStack(spacing: 2) {
                    ForEach(DisplayCurrency.allCases) { c in
                        row(c)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18)

                if store.baseCurrency != .JPY { warning }

                Button { store.go(.fx) } label: {
                    Text("base_open_fx".loc)
                        .font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .smStroke(SM.border, radius: 14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .scrollBottomPadding()
    }

    private func row(_ c: DisplayCurrency) -> some View {
        let on = store.baseCurrency == c
        return Button { store.setBaseCurrency(c) } label: {
            HStack(spacing: 13) {
                Text(verbatim: c.symbol)
                    .font(SM.n(16, .semibold))
                    .foregroundStyle(on ? SM.indigoFg : SM.sub)
                    .frame(width: 44, height: 38)
                    .background(on ? SM.indigoTint : SM.card,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(c.nameKey.loc)
                        .font(SM.f(14, .medium))
                        .foregroundStyle(on ? SM.fg : SM.sub)
                    Text(verbatim: c.rawValue + Sep.mid + note(c))
                        .font(SM.n(11, .regular)).foregroundStyle(SM.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(verbatim: on ? "✓" : "")
                    .font(SM.n(15, .semibold)).foregroundStyle(SM.indigo)
                    .frame(width: 16)
            }
            .padding(.horizontal, 8).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 「そのまま表示します」か「1 USD = ¥154.0」。
    /// 自動で取れない通貨は、そのことを書いておく（黙って既定値を出さない）。
    private func note(_ c: DisplayCurrency) -> String {
        guard c != .JPY else { return TR("base_note_jpy") }
        let rate = TRF("base_rate_format", c.rawValue,
                       String(format: "%.\(c == .KRW ? 2 : 1)f", store.rate(for: c)))
        return c.isAutoFetchable ? rate : rate + Sep.mid + TR("base_manual_only")
    }

    private var warning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("base_warn_title".loc)
                .font(SM.f(12, .bold)).foregroundStyle(SM.amber)
            Text(verbatim: TRF("base_warn_body_format", store.yenOnlyCount))
                .font(SM.f(11.5)).lineSpacing(9).foregroundStyle(SM.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(SM.amberTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .smStroke(SM.amberLine, radius: 14)
        .padding(.horizontal, 20).padding(.top, 20)
    }
}
