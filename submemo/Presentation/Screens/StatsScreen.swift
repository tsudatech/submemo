//
//  StatsScreen.swift
//  submemo
//
//  集計と見直し。年額換算・カテゴリ内訳・未使用のまとめ・支払い方法別・高い順。
//

import SwiftUI

struct StatsScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isEmpty {
                // design 4c：見出しだけ残し、集計の数字は一切出さない。
                VStack(spacing: 0) {
                    title
                    EmptyState(
                        illustration: { EmptyBarsGlyph() },
                        titleKey: "empty_stats_title",
                        bodyKey: "empty_stats_body",
                        ctaKey: "empty_add_cta",
                        action: { store.startAdd() },
                        ctaCoachTarget: .statsEmptyCta
                    )
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        title
                        hero
                        categoryBreakdown
                        if !store.unusedItems.isEmpty { unusedSection }
                        paySection
                        ranking
                    }
                }
                .scrollBottomPadding()
            }
        }
        .onAppear { store.startCoachIfNeeded(for: .stats) }
    }

    private var title: some View { ScreenTitleBar("stats_title") }

    // MARK: - ヒーロー

    private var hero: some View {
        let h = store.statsHero
        return VStack(alignment: .leading, spacing: 0) {
            // タップで単位が変わることが分かるよう、見出しに矢印を添えている。
            HStack(spacing: 6) {
                Text(verbatim: h.label)
                    .font(SM.f(12, .medium)).tracking(0.7)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(SM.sub)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "¥").font(SM.f(26, .medium))
                Text(verbatim: Yen.num(h.value)).font(SM.n(50, .semibold)).kerning(-1)
            }
            .foregroundStyle(SM.fg)
            .padding(.top, 8)
            .lineLimit(1).minimumScaleFactor(0.5)

            HStack(spacing: 18) {
                Text(verbatim: h.subA)
                Text(verbatim: "/").foregroundStyle(SM.sub.opacity(0.35))
                Text(verbatim: h.subB)
            }
            .font(SM.n(12.5, .regular))
            .foregroundStyle(SM.sub)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .contentShape(Rectangle())
        .onTapGesture { store.cycleStatsMetric() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("a11y_stats_hero_hint".loc)
    }

    // MARK: - カテゴリ内訳

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(store.catStats) { s in
                            Rectangle().fill(s.color)
                                .frame(width: max(2, geo.size.width * s.ratio - 2))
                        }
                    }
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(spacing: 0) {
                ForEach(store.catStats) { s in
                    VStack(spacing: 0) {
                        // タップでそのカテゴリの内訳一覧へ。
                        Button { store.openCategory(s.id) } label: {
                            HStack(spacing: 11) {
                                RoundedRectangle(cornerRadius: 3).fill(s.color).frame(width: 9, height: 9)
                                Text(verbatim: s.name).font(SM.f(13)).foregroundStyle(SM.fg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(verbatim: "\(Int((s.ratio * 100).rounded()))%")
                                    .font(SM.n(12, .regular)).foregroundStyle(SM.sub)
                                Text(verbatim: Yen.text(s.yen))
                                    .font(SM.n(13, .medium)).foregroundStyle(SM.fg)
                                    .frame(width: 78, alignment: .trailing)
                                ChevronRight()
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(SM.line).frame(height: 1)
                    }
                }
            }
            .padding(.top, 18)
        }
        .coachAnchor(.statsCats)
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    // MARK: - 使っていない印

    private var unusedSection: some View {
        let items = store.unusedItems
        let yearly = items.reduce(0) { $0 + store.monthly($1) } * 12
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("stats_unused_title".loc)
                    .font(SM.f(12, .medium)).tracking(0.7).foregroundStyle(SM.amber)
                Spacer()
                Text(verbatim: TRF("stats_unused_meta_format", items.count, Yen.text(yearly)))
                    .font(SM.n(11, .regular)).foregroundStyle(SM.sub)
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(items) { sub in
                    Button { store.open(sub) } label: {
                        HStack(spacing: 12) {
                            InitialTile(text: sub.initial, color: store.category(sub.categoryID).color,
                                        size: 34, radius: 11, fontSize: 14)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: sub.name).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                                Text(verbatim: store.unusedNote(sub)).font(SM.f(11)).foregroundStyle(SM.sub)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: TRF("cancel_save_format", Yen.text(store.monthly(sub) * 12)))
                                .font(SM.n(12.5, .medium)).foregroundStyle(SM.amber)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(SM.amberTint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(SM.line).frame(height: 1)
                }

                Button { store.startCancel(one: nil) } label: {
                    Text("stats_cancel_all".loc)
                        .font(SM.f(12.5, .bold))
                        .foregroundStyle(SM.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0x2FBF71, alpha: 0.09))
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .smStroke(SM.amberLine, radius: 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    // MARK: - 支払い方法別

    private var paySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("stats_by_pay".loc)
                .font(SM.f(12, .medium)).tracking(0.7).foregroundStyle(SM.sub)
                .padding(.bottom, 14)

            VStack(spacing: 12) {
                ForEach(store.payStats) { p in
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(p.method.color).frame(width: 30, height: 20)
                        Text(verbatim: p.method.name).font(SM.f(12.5)).foregroundStyle(SM.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: "\(Int((p.ratio * 100).rounded()))%")
                            .font(SM.n(11.5, .regular)).foregroundStyle(SM.sub)
                        Text(verbatim: TRF("per_month_amount_format", Yen.text(p.yen)))
                            .font(SM.n(12.5, .medium)).foregroundStyle(SM.fg)
                            .frame(width: 96, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    // MARK: - 高い順

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("stats_ranking".loc)
                .font(SM.f(12, .medium)).tracking(0.7).foregroundStyle(SM.sub)
                .padding(.bottom, 14)

            VStack(spacing: 14) {
                ForEach(store.ranking) { sub in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: sub.name).font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: TRF("stats_per_day_format", Yen.text(store.monthly(sub) * 12 / 365)))
                                .font(SM.n(11.5, .regular)).foregroundStyle(SM.sub)
                            Text(verbatim: TRF("per_year_amount_format", Yen.text(store.monthly(sub) * 12)))
                                .font(SM.n(13, .medium)).foregroundStyle(SM.fg)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(SM.line2)
                                Capsule().fill(store.category(sub.categoryID).color)
                                    .frame(width: geo.size.width * (store.monthly(sub) / store.rankingMax))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }
}
