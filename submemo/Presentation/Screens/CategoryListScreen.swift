//
//  CategoryListScreen.swift
//  submemo
//
//  集計のカテゴリ内訳をタップして開く、そのカテゴリに属するサブスクの一覧。
//  集計の下層なのでタブバーは出したまま（点灯は「集計」）。
//

import SwiftUI

struct CategoryListScreen: View {
    @EnvironmentObject private var store: AppStore

    private var category: SubCategory { store.catListCategory }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(rawTitle: category.name)

                summary
                statCards
                items
                if store.catListItems.isEmpty { emptyNote }
                addButton
            }
        }
        .scrollBottomPadding()
    }

    // MARK: - 見出し

    private var summary: some View {
        HStack(spacing: 14) {
            InitialTile(text: category.initial, color: category.color,
                        size: 52, radius: 16, fontSize: 21)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "¥").font(SM.f(18, .medium))
                    Text(verbatim: Yen.num(store.catListMonthly))
                        .font(SM.n(34, .semibold)).kerning(-0.7)
                    Text("detail_per_month".loc)
                        .font(SM.f(12)).foregroundStyle(SM.sub)
                        .padding(.leading, 6)
                }
                .foregroundStyle(SM.fg)
                .lineLimit(1).minimumScaleFactor(0.6)

                Text(verbatim: TRF("hero_sub_year", Yen.text(store.catListMonthly * 12))
                     + Sep.mid
                     + TRF("hero_sub_day", Yen.text(store.catListMonthly * 12 / 365)))
                    .font(SM.n(11.5, .regular))
                    .foregroundStyle(SM.sub)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard("catlist_share", "\(Int((store.catListShare * 100).rounded()))%", mono: true)
            statCard("catlist_count", TRF("settings_count_format", store.catListItems.count), mono: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func statCard(_ key: String, _ value: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key.loc).font(SM.f(10.5)).foregroundStyle(SM.sub)
            Text(verbatim: value)
                .font(mono ? SM.n(16, .medium) : SM.f(16, .medium))
                .foregroundStyle(SM.fg)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .smCard(radius: 14)
    }

    // MARK: - 一覧

    private var items: some View {
        VStack(spacing: 16) {
            ForEach(store.catListItems) { sub in
                Button { store.open(sub) } label: {
                    VStack(spacing: 9) {
                        row(sub)
                        // カテゴリ内での金額の比率。
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(SM.line2)
                                Capsule().fill(category.color)
                                    .frame(width: geo.size.width * store.catListBar(sub))
                            }
                        }
                        .frame(height: 5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    private func row(_ sub: Subscription) -> some View {
        HStack(spacing: 13) {
            InitialTile(text: sub.initial, color: category.color,
                        size: 40, radius: 13, fontSize: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(verbatim: sub.name)
                        .font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                        .lineLimit(1)
                    if let flag = flag(for: sub) {
                        Text(flag.text.loc)
                            .font(SM.f(9.5, .medium))
                            .foregroundStyle(flag.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(flag.color, lineWidth: 1))
                    }
                }
                Text(verbatim: store.rawLabel(sub) + Sep.mid + store.payment(sub.paymentMethodID).label)
                    .font(SM.f(11)).foregroundStyle(SM.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: Yen.text(store.monthly(sub)))
                    .font(SM.n(14.5, .medium)).foregroundStyle(SM.fg)
                Text(verbatim: nextLabel(sub))
                    .font(SM.n(11, .regular)).foregroundStyle(nextColor(sub))
            }
        }
    }

    /// 「無料」「未使用」の印。ここでは未使用も色つきで出す。
    private func flag(for sub: Subscription) -> (text: String, color: Color)? {
        if sub.isTrial { return ("flag_trial", SM.alert) }
        if sub.isUnused { return ("flag_unused", SM.amber) }
        return nil
    }

    private func nextLabel(_ sub: Subscription) -> String {
        sub.isTrial
            ? TRF("catlist_trial_format", DateText.short(sub.nextRenewal))
            : TRF("catlist_next_format", DateText.short(sub.nextRenewal))
    }

    private func nextColor(_ sub: Subscription) -> Color {
        if sub.isTrial { return SM.alert }
        return sub.isUnused ? SM.amber : SM.sub
    }

    // MARK: - 空状態・追加

    private var emptyNote: some View {
        Text("catlist_empty".loc)
            .font(SM.f(12.5)).lineSpacing(11)
            .multilineTextAlignment(.center)
            .foregroundStyle(SM.sub)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
    }

    private var addButton: some View {
        Button { store.startAdd(categoryID: category.id) } label: {
            Text(verbatim: TRF("catlist_add_format", category.name))
                .font(SM.f(13, .medium))
                .foregroundStyle(SM.sub)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SM.border3, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }
}
