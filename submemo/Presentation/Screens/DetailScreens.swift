//
//  DetailScreens.swift
//  submemo
//
//  サブスクの詳細と、解約シミュレーション。
//

import SwiftUI

// MARK: - 詳細

struct DetailScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        // 選択中の1件が消えている（削除された）ときはホームへ戻す。
        if let sub = store.selected {
            content(sub)
        } else {
            Color.clear.onAppear { store.goTab(.home) }
        }
    }

    private func content(_ sub: Subscription) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ScreenNavBar(titleKey: "nav_detail") {
                    Button { store.startEdit(sub) } label: {
                        Text("row_edit".loc).font(SM.f(14, .medium)).foregroundStyle(SM.indigo)
                    }
                    .buttonStyle(.plain)
                }

                if store.fromNotif { fromNotifBanner(sub) }

                header(sub)
                statCards(sub)
                infoCard(sub)
                actions(sub)
            }
        }
        .scrollBottomPadding()
    }

    private func fromNotifBanner(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("detail_from_notif_title".loc)
                .font(SM.f(12, .bold))
                .foregroundStyle(SM.red)
            Text(verbatim: TRF("detail_from_notif_body_format", sub.daysLeft()))
                .font(SM.f(11.5))
                .lineSpacing(7)
                .foregroundStyle(SM.sub)
                .fixedSize(horizontal: false, vertical: true)
            Button { store.back() } label: {
                Text(verbatim: TRF("detail_snooze_format", TR(store.nset.snooze.labelKey)))
                    .font(SM.f(12.5, .medium))
                    .foregroundStyle(SM.fg)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .smStroke(SM.border2, radius: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .smStroke(SM.redLine, radius: 14)
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func header(_ sub: Subscription) -> some View {
        VStack(spacing: 16) {
            InitialTile(text: sub.initial, color: store.category(sub.categoryID).color,
                        size: 72, radius: 22, fontSize: 30)
            Text(verbatim: sub.name).font(SM.f(18, .medium)).foregroundStyle(SM.fg)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: "¥").font(SM.f(20, .medium))
                Text(verbatim: Yen.num(store.monthly(sub))).font(SM.n(44, .semibold))
                Text((sub.cycle == .year ? "detail_per_month_yearly" : "detail_per_month").loc)
                    .font(SM.f(14))
                    .foregroundStyle(SM.sub)
            }
            .foregroundStyle(SM.fg)
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
    }

    private func statCards(_ sub: Subscription) -> some View {
        HStack(spacing: 10) {
            statCard("detail_yearly", Yen.text(store.monthly(sub) * 12), mono: true)
            statCard("detail_per_day", Yen.text(store.monthly(sub) * 12 / 365), mono: true)
            statCard("detail_category", store.category(sub.categoryID).name, mono: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    private func statCard(_ key: String, _ value: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key.loc).font(SM.f(10.5)).foregroundStyle(SM.sub)
            Text(verbatim: value)
                .font(mono ? SM.n(16, .medium) : SM.f(13, .medium))
                .foregroundStyle(SM.fg)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .smCard(radius: 14)
    }

    private func infoCard(_ sub: Subscription) -> some View {
        VStack(spacing: 0) {
            infoRow("detail_next", DateText.short(sub.nextRenewal) + TRF("detail_days_suffix_format", sub.daysLeft()),
                    color: sub.daysLeft() <= 3 ? SM.alert : SM.fg, divider: true)
            infoRow("detail_cycle", cycleFull(sub), color: SM.fg, divider: true)
            infoRow("detail_pay", store.payment(sub.paymentMethodID).label, color: SM.fg, divider: true)
            infoRow("detail_last_used",
                    sub.lastUsedAt.map(DateText.short) ?? TR("detail_last_used_never"),
                    color: sub.lastUsedAt == nil ? SM.dim : SM.fg, divider: true)
            infoRow("detail_history", store.historyText(sub), color: SM.amber, divider: false)
        }
        .smCard()
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func cycleFull(_ sub: Subscription) -> String {
        if sub.cycle == .year || sub.currency != .JPY { return store.rawLabel(sub) }
        return TRF("detail_cycle_monthly_format", Yen.text(store.monthly(sub)))
    }

    private func infoRow(_ key: String, _ value: String, color: Color, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(key.loc).font(SM.f(13)).foregroundStyle(SM.sub)
                Spacer(minLength: 12)
                Text(verbatim: value)
                    .font(SM.n(13, .medium))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            if divider { Rectangle().fill(SM.line).frame(height: 1) }
        }
    }

    private func actions(_ sub: Subscription) -> some View {
        VStack(spacing: 10) {
            Button { store.startCancel(one: sub.id) } label: {
                Text("detail_cancel_sim".loc)
                    .font(SM.f(14, .bold))
                    .foregroundStyle(SM.green)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(SM.greenTint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .smStroke(SM.greenLine, radius: 15)
            }
            .buttonStyle(.plain)

            Button { store.recordUsage(sub) } label: {
                Text("detail_used_today".loc)
                    .font(SM.f(14, .medium))
                    .foregroundStyle(SM.indigoFg)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(SM.indigoTint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { store.toggleUnused(sub) } label: {
                Text((sub.isUnused ? "detail_unmark_unused" : "detail_mark_unused").loc)
                    .font(SM.f(14, .medium))
                    .foregroundStyle(sub.isUnused ? SM.amber : SM.sub)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .smStroke(sub.isUnused ? Color(hex: 0xF5A623, alpha: 0.45) : SM.border, radius: 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        
    }
}

// MARK: - 解約シミュレーション

struct CancelSimScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ScreenNavBar(titleKey: "nav_cancel")

                summary
                targets
                footer
            }
        }
        .scrollBottomPadding()
    }

    private var summary: some View {
        let monthly = store.cancelMonthly
        return VStack(spacing: 0) {
            Text(verbatim: TRF("cancel_who_format", store.cancelWho))
                .font(SM.f(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(SM.sub)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: "¥").font(SM.f(24, .medium))
                Text(verbatim: Yen.num(monthly * 12)).font(SM.n(56, .semibold)).kerning(-1)
            }
            .foregroundStyle(SM.green)
            .padding(.top, 18)
            .lineLimit(1).minimumScaleFactor(0.5)

            Text("cancel_per_year".loc)
                .font(SM.f(13, .medium))
                .foregroundStyle(SM.green)
                .padding(.top, 10)

            Text(verbatim: TRF("cancel_breakdown_format", Yen.text(monthly), Yen.text(monthly * 12 / 365)))
                .font(SM.n(12, .regular))
                .foregroundStyle(SM.sub)
                .padding(.top, 16)
            Text(verbatim: TRF("cancel_three_years_format", Yen.text(monthly * 36)))
                .font(SM.n(12, .regular))
                .foregroundStyle(SM.sub)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private var targets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("cancel_targets".loc)
                .font(SM.f(11.5, .medium))
                .foregroundStyle(SM.sub)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            ForEach(store.cancelCandidates) { sub in
                let on = !store.cancelOff.contains(sub.id)
                Button {
                    store.toggleCancelTarget(sub)
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(on ? SM.greenSolid : Color.clear)
                            .frame(width: 22, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(on ? SM.greenLine : SM.border2, lineWidth: 1))
                            .overlay {
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(SM.onGreen)
                                }
                            }

                        InitialTile(text: sub.initial, color: store.category(sub.categoryID).color,
                                    size: 34, radius: 11, fontSize: 14)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: sub.name).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                            Text(verbatim: store.unusedNote(sub))
                                .font(SM.f(11)).foregroundStyle(SM.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(verbatim: TRF("cancel_save_format", Yen.text(store.monthly(sub) * 12)))
                            .font(SM.n(13, .medium))
                            .foregroundStyle(SM.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .smCard(radius: 14)
                    .smStroke(on ? SM.greenLine : SM.border2, radius: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            // 解約手順の案内は未実装。中身が無いボタンは置かない。
            Text("legal_trademarks".loc)
                .font(SM.f(10.5))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .foregroundStyle(SM.dim)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }
}
