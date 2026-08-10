//
//  HomeScreen.swift
//  submemo
//
//  ホーム。月切替・ヒーロー数値・トライアル警告・一覧（左スワイプで編集/削除）・
//  未使用のまとめ解約導線、そして空状態。
//

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isEmpty {
                // design 4a：ヘッダーは残したまま、合計 ¥0 は出さない。
                VStack(spacing: 0) {
                    header
                    EmptyHomeState()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        heroBlock
                        if let trial = store.trialItem { TrialBanner(trial: trial) }
                        listHeader
                        list
                        Text("home_swipe_hint".loc)
                            .font(SM.f(10.5))
                            .foregroundStyle(SM.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 10)
                        if !store.unusedItems.isEmpty { unusedCTA }
                    }
                }
                .scrollBottomPadding()
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .onAppear { store.startCoachIfNeeded(for: .home) }
    }

    // MARK: - ヘッダー

    private var header: some View {
        ScreenTitleBar(titleKey: "brand_name", tracking: 0.3) {
            ThemeToggleButton()

            Button {
                store.startAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(SM.indigo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y_add".loc)
        }
    }

    // MARK: - ヒーロー

    private var heroBlock: some View {
        let hero = store.hero
        return VStack(alignment: .leading, spacing: 0) {
            // タップで単位が変わることが分かるよう、見出しに矢印を添えている。
            HStack(spacing: 6) {
                Text(verbatim: hero.label)
                    .font(SM.f(12, .medium))
                    .tracking(0.7)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(SM.sub)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "¥").font(SM.f(30, .medium)).foregroundStyle(SM.fg)
                CountUpNumber(value: hero.value, animates: hero.animates)
            }
            .padding(.top, 8)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 18) {
                Text(verbatim: hero.subA)
                Text(verbatim: "/").foregroundStyle(SM.sub.opacity(0.35))
                Text(verbatim: hero.subB)
            }
            .font(SM.n(12.5, .regular))
            .foregroundStyle(SM.sub)
            .padding(.top, 14)

            if let note = store.billedNote {
                Text(verbatim: note)
                    .font(SM.f(11))
                    .lineSpacing(5)
                    .foregroundStyle(SM.dim)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // ガイドで囲む範囲は、余白を入れる前のここ。
        .coachAnchor(.homeHero)
        .padding(.horizontal, 20)
        // 集計のヒーローと同じ位置から始める。
        .padding(.top, 28)
        .padding(.bottom, 26)
        .contentShape(Rectangle())
        .onTapGesture { store.cycleHeroMetric() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("a11y_home_hero_hint".loc)
    }

    // MARK: - 一覧

    private var listHeader: some View {
        HStack {
            Text(verbatim: TRF("home_active_count_format", store.all.count))
                .font(SM.f(12, .medium))
                .foregroundStyle(SM.sub)
            Spacer()
            Button {
                store.sortHigh.toggle()
            } label: {
                HStack(spacing: 5) {
                    Text((store.sortHigh ? "sort_high" : "sort_soon").loc)
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 10, weight: .semibold))
                }
                .font(SM.f(12, .medium))
                .foregroundStyle(SM.sub)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 10)
    }

    private var list: some View {
        VStack(spacing: 2) {
            ForEach(store.sortedItems) { sub in
                SubSwipeRow(sub: sub)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var unusedCTA: some View {
        Button {
            store.startCancel(one: nil)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: TRF("home_unused_label_format", store.unusedItems.count))
                        .font(SM.f(11.5))
                        .foregroundStyle(SM.sub)
                    Text(verbatim: TRF("home_unused_save_format",
                                       Yen.text(store.unusedItems.reduce(0) { $0 + store.monthly($1) } * 12)))
                        .font(SM.n(19, .bold))
                        .foregroundStyle(SM.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ChevronRight(color: SM.green)
            }
            .padding(16)
            .background(SM.greenTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .smStroke(SM.greenLine, radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

// MARK: - トライアル警告バナー

private struct TrialBanner: View {
    @EnvironmentObject private var store: AppStore
    let trial: Subscription

    var body: some View {
        Button {
            store.open(trial)
        } label: {
            HStack(spacing: 12) {
                Circle().fill(SM.alert).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: TRF("home_trial_title_format", trial.daysLeft()))
                        .font(SM.f(12.5, .bold))
                        .foregroundStyle(SM.red)
                    Text(verbatim: TRF("home_trial_line_format", trial.name,
                                       DateText.short(trial.nextRenewal), Yen.text(store.monthly(trial))))
                        .font(SM.f(11.5))
                        .foregroundStyle(SM.sub)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ChevronRight()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .smStroke(Color(hex: 0xFF5C5C, alpha: 0.28), radius: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - 一覧行（左スワイプで編集・削除）

struct SubSwipeRow: View {
    @EnvironmentObject private var store: AppStore
    let sub: Subscription

    @State private var dx: CGFloat = 0
    @State private var start: CGFloat = 0

    private let actionWidth: CGFloat = 152

    var body: some View {
        ZStack(alignment: .trailing) {
            // スワイプで引き出したときだけ見えるアクション。閉じているあいだは
            // 行の角丸から覗かないよう描画しない。
            if dx < 0 {
                HStack(spacing: 2) {
                    Button {
                        store.startEdit(sub)
                    } label: {
                        Text("row_edit".loc)
                            .font(SM.f(12.5, .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(SM.editGray)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.16)) { store.delete(sub) }
                    } label: {
                        Text("row_delete".loc)
                            .font(SM.f(12.5, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(SM.alert)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: actionWidth)
            }

            rowContent
                .background(SM.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .offset(x: dx)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onChange(of: store.openSwipeID) { _, newValue in
            if newValue != sub.id, dx != 0 {
                withAnimation(.easeOut(duration: 0.16)) { dx = 0 }
                start = 0
            }
        }
    }

    private func drag(_ translation: CGFloat) {
        dx = min(0, max(-actionWidth, start + translation))
    }

    private func dragEnded(_ translation: CGFloat) {
        let open = min(0, max(-actionWidth, start + translation)) < -70
        withAnimation(.easeOut(duration: 0.16)) { dx = open ? -actionWidth : 0 }
        start = open ? -actionWidth : 0
        store.openSwipeID = open ? sub.id : nil
    }

    private func tapped() {
        if dx < 0 {
            withAnimation(.easeOut(duration: 0.16)) { dx = 0 }
            start = 0
            store.openSwipeID = nil
        } else {
            store.open(sub)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 13) {
            InitialTile(text: sub.initial, color: store.category(sub.categoryID).color)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(verbatim: sub.name)
                        .font(SM.f(14.5, .medium))
                        .foregroundStyle(SM.fg)
                        .lineLimit(1)
                    if let flag {
                        Text(flag.text.loc)
                            .font(SM.f(9.5, .medium))
                            .foregroundStyle(flag.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(flag.color, lineWidth: 1))
                    }
                }
                Text(verbatim: store.meta(for: sub))
                    .font(SM.f(11.5))
                    .foregroundStyle(SM.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: Yen.text(store.monthly(sub)))
                    .font(SM.n(14.5, .medium))
                    .foregroundStyle(SM.fg)
                Text(verbatim: nextLabel)
                    .font(SM.n(11, .regular))
                    .foregroundStyle(nextColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        // タップと「横向きのときだけ効く」スワイプをまとめて受ける。
        .overlay { SwipeCatcher(onChange: drag, onEnd: dragEnded, onTap: tapped) }
    }

    private var flag: (text: String, color: Color)? {
        if sub.isTrial { return ("flag_trial", SM.alert) }
        if sub.isUnused { return ("flag_unused", SM.sub) }
        return nil
    }

    private var nextLabel: String {
        if sub.isTrial { return TRF("row_trial_end_format", DateText.short(sub.nextRenewal)) }
        if sub.daysLeft() <= 3 { return TRF("row_days_left_format", sub.daysLeft()) }
        return DateText.short(sub.nextRenewal)
    }

    private var nextColor: Color {
        if sub.isTrial { return SM.alert }
        if sub.daysLeft() <= 3 { return SM.amber }
        return SM.sub
    }
}

// MARK: - 空状態

private struct EmptyHomeState: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        EmptyState(
            illustration: { EmptyYenTile() },
            titleKey: "empty_title",
            bodyKey: "empty_body",
            ctaKey: "empty_cta",
            action: { store.startAdd() },
            ctaCoachTarget: .homeEmptyCta
        )
    }
}
