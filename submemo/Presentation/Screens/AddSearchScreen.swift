//
//  AddScreens.swift
//  submemo
//
//  登録のステップ1。候補から選ぶ／手で追加する。
//  選んだあとの入力フォームは SubscriptionFormScreen（追加・編集で共用）。
//

import SwiftUI

struct AddSearchScreen: View {
    @EnvironmentObject private var store: AppStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScreenNavBar(titleKey: "add_title")

            TextField("", text: $store.query, prompt: Text("add_search_placeholder".loc).foregroundStyle(SM.dim))
                .font(SM.f(15))
                .foregroundStyle(SM.fg)
                .focused($focused)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .smCard(radius: 14)
                .smStroke(SM.border, radius: 14)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 14)

            if let existing = store.duplicateNotice {
                duplicateCard(existing)
            }

            Text((store.query.trimmingCharacters(in: .whitespaces).isEmpty
                  ? "add_suggest_popular" : "add_suggest_results").loc)
                .font(SM.f(11.5, .medium))
                .foregroundStyle(SM.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.suggestions) { seed in
                        Button { store.pick(seed) } label: {
                            HStack(spacing: 13) {
                                InitialTile(text: seed.initial, color: store.category(seed.categoryID).color,
                                            size: 40, radius: 12, fontSize: 16)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: seed.name)
                                        .font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                                    Text(verbatim: store.category(seed.categoryID).name)
                                        .font(SM.f(11)).foregroundStyle(SM.sub)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(verbatim: seed.priceLabel)
                                    .font(SM.n(12.5, .regular)).foregroundStyle(SM.sub)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button { store.pickManual(name: store.query) } label: {
                        Text("add_manual_cta".loc)
                            .font(SM.f(13, .medium))
                            .foregroundStyle(SM.sub)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(SM.border3, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
            }
            .scrollBottomPadding()
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// すでに同じ名前で登録があるときの案内（design 3c）。
    /// 家族で別々に契約している場合があるので、追加は禁止せず選ばせる。
    private func duplicateCard(_ existing: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: TRF("dup_title_format", existing.name))
                .font(SM.f(12.5, .bold))
                .foregroundStyle(SM.amber)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 11) {
                InitialTile(text: existing.initial,
                            color: store.category(existing.categoryID).color,
                            size: 34, radius: 11, fontSize: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: existing.name).font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                    Text(verbatim: TRF("per_month_amount_format", Money.text(store.monthly(existing)))
                         + Sep.mid
                         + TRF("catlist_next_format", DateText.short(existing.nextRenewal)))
                        .font(SM.n(11, .regular)).foregroundStyle(SM.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                Button {
                    store.dismissDuplicateNotice()
                    store.open(existing)
                } label: {
                    Text("dup_open".loc)
                        .font(SM.f(12, .bold))
                        .foregroundStyle(SM.onAmber)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(SM.amber, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { store.addAnyway() } label: {
                    Text("dup_add_anyway".loc)
                        .font(SM.f(12, .medium))
                        .foregroundStyle(SM.fg)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .smStroke(SM.border2, radius: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(SM.amberTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .smStroke(Color(hex: 0xF5A623, alpha: 0.35), radius: 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
}
