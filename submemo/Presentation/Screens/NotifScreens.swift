//
//  NotifScreens.swift
//  submemo
//
//  これからの予定（通知タブ）、通知の設定、実際に届く文面の一覧。
//

import SwiftUI
import UIKit

// MARK: - これからの予定

struct NotifScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.timeline.isEmpty {
                // design 4e：予定が無いときは文面プレビューも設定カードも出さない。
                // 通知は登録があって初めて意味を持つので、設定への導線は副次に置く。
                VStack(spacing: 0) {
                    title
                    EmptyState(
                        illustration: { EmptyLinesGlyph() },
                        titleKey: "empty_notif_title",
                        bodyKey: "empty_notif_body",
                        ctaKey: "empty_add_cta",
                        action: { store.startAdd() },
                        secondaryKey: "empty_notif_settings",
                        secondaryAction: { store.go(.notifset) },
                        secondaryCoachTarget: .notifEmptySettings
                    )
                }
            } else {
                timelineBody
            }
        }
        .onAppear { store.startCoachIfNeeded(for: .notif) }
    }

    private var title: some View { ScreenTitleBar("notif_title") }

    private var timelineBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title

                VStack(spacing: 10) {
                    ForEach(store.timeline) { sub in
                        timelineRow(sub)
                    }
                }
                .coachAnchor(.notifTimeline)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Text("notif_preview_label".loc)
                    .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                    .padding(.horizontal, 20).padding(.top, 26)

                previewCard.padding(.horizontal, 20).padding(.top, 12)
                settingsCard.padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .scrollBottomPadding()
    }

    private func accentColor(_ sub: Subscription) -> Color {
        if sub.isTrial { return SM.alert }
        return sub.daysLeft() <= 6 ? SM.amber : SM.sub
    }

    private func timelineRow(_ sub: Subscription) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(verbatim: DateText.dayNumber(sub.nextRenewal))
                    .font(SM.n(17, .semibold))
                    .foregroundStyle(accentColor(sub))
                Text(verbatim: DateText.monthShort(sub.nextRenewal))
                    .font(SM.f(10)).foregroundStyle(SM.sub)
            }
            .frame(width: 52)
            .padding(.top, 12)

            HStack(spacing: 12) {
                Rectangle().fill(accentColor(sub)).frame(width: 2)
                InitialTile(text: sub.initial, color: store.category(sub.categoryID).color,
                            size: 34, radius: 11, fontSize: 14)
                    .padding(.leading, 13)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: sub.name).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                    Text(verbatim: sub.isTrial
                         ? TR("notif_note_trial")
                         : TRF("notif_note_renew_format", sub.daysLeft()))
                        .font(SM.f(11)).foregroundStyle(accentColor(sub))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: Money.text(store.monthly(sub)))
                    .font(SM.n(13, .medium)).foregroundStyle(SM.fg)
                    .padding(.trailing, 15)
            }
            .padding(.vertical, 14)
            .smCard(radius: 15)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    /// いちばん先に届く1件を、実際のロック画面の見え方で出す。
    @ViewBuilder
    private var previewCard: some View {
        if let preview = store.notifPreviews.first {
            Button {
                if let id = preview.subscriptionID, let sub = store.sub(id) {
                    store.open(sub, fromNotification: true)
                }
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SM.indigo).frame(width: 34, height: 34)
                        .overlay(Text(verbatim: "¥").font(SM.f(15, .bold)).foregroundStyle(.white))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("brand_name".loc).font(SM.f(12, .bold)).foregroundStyle(SM.fg)
                            Spacer()
                            Text("notif_now".loc).font(SM.f(10.5)).foregroundStyle(SM.sub)
                        }
                        Text(verbatim: preview.title)
                            .font(SM.f(11.5, .medium)).lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(SM.fg)
                        Text(verbatim: preview.body)
                            .font(SM.f(11.5)).lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(SM.sub)
                        if preview.subscriptionID != nil {
                            Text("notif_preview_cta".loc)
                                .font(SM.f(10.5, .medium)).foregroundStyle(SM.indigo)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(14)
                .smCard(radius: 18)
                .smStroke(SM.border, radius: 18)
            }
            .buttonStyle(.plain)
                // 対象のない月次サマリーはタップ不可。見た目は淡くしない。
            .allowsHitTesting(preview.subscriptionID != nil)
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            row("notif_row_before", store.notifSummary, color: SM.indigo) { store.go(.notifset) }
            Rectangle().fill(SM.line).frame(height: 1)
            row("notif_row_trial", TR("notif_row_trial_value"), color: SM.alert) { store.go(.notifset) }
            Rectangle().fill(SM.line).frame(height: 1)
            row("notif_row_open", "›", color: SM.sub) { store.go(.notifset) }
        }
        .smCard()
    }

    private func row(_ key: String, _ value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(key.loc).font(SM.f(13)).foregroundStyle(SM.fg)
                Spacer(minLength: 12)
                Text(verbatim: value).font(SM.f(13, .medium)).foregroundStyle(color)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 通知の設定

struct NotifSettingsScreen: View {
    @EnvironmentObject private var store: AppStore

    private let times = ["8:00", "9:00", "12:00", "20:00"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "notifset_title")

                if store.notifPermissionDenied { permissionDeniedCard }

                section("notifset_before") {
                    HStack(spacing: 8) {
                        Chip(title: "before_7", selected: store.nset.before7) { store.updateNotifSettings { $0.before7.toggle() } }
                        Chip(title: "before_3", selected: store.nset.before3) { store.updateNotifSettings { $0.before3.toggle() } }
                        Chip(title: "before_1", selected: store.nset.before1) { store.updateNotifSettings { $0.before1.toggle() } }
                        Chip(title: "before_0", selected: store.nset.beforeSame) { store.updateNotifSettings { $0.beforeSame.toggle() } }
                    }
                }
                .padding(.top, 26)

                section("notifset_time") {
                    HStack(spacing: 8) {
                        ForEach(times, id: \.self) { t in
                            Chip(title: t, isKey: false, selected: store.nset.time == t) {
                                store.updateNotifSettings { $0.time = t }
                            }
                        }
                    }
                }
                .padding(.top, 22)

                section("notifset_trial", color: SM.red) {
                    HStack(spacing: 8) {
                        ForEach([7, 3, 1], id: \.self) { n in
                            Chip(title: TRF("days_before_format", n), isKey: false,
                                 selected: store.nset.trialEnabled && store.nset.trialDays == n,
                                 tone: .red) {
                                store.updateNotifSettings { $0.trialEnabled = true; $0.trialDays = n }
                            }
                        }
                        // 更新前の通知を全部切っても鳴り続けることがないよう、ここでも切れるようにする。
                        Chip(title: "notif_off", selected: !store.nset.trialEnabled, tone: .red) {
                            store.updateNotifSettings { $0.trialEnabled = false }
                        }
                    }
                }
                .padding(.top, 22)

                section("notifset_snooze") {
                    HStack(spacing: 8) {
                        ForEach(AppStore.NotifSettings.Snooze.allCases) { s in
                            Chip(title: s.labelKey, selected: store.nset.snooze == s) {
                                store.updateNotifSettings { $0.snooze = s }
                            }
                        }
                    }
                }
                .padding(.top, 22)

                VStack(spacing: 0) {
                    toggleRow("notifset_lock_title", "notifset_lock_note", isOn: store.nset.lockAmount) {
                        store.updateNotifSettings { $0.lockAmount.toggle() }
                    }
                    Rectangle().fill(SM.line).frame(height: 1)
                    toggleRow("notifset_quiet_title", "notifset_quiet_note", isOn: store.nset.quietNight) {
                        store.updateNotifSettings { $0.quietNight.toggle() }
                    }
                }
                .smCard()
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Button { store.go(.msgs) } label: {
                    Text(verbatim: TRF("notifset_see_messages_format", store.notifPreviews.count))
                        .font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .smStroke(SM.border, radius: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("notifset_note".loc)
                    .font(SM.f(10.5)).lineSpacing(8).foregroundStyle(SM.dim)
                    .padding(.horizontal, 24).padding(.top, 20)
            }
        }
        .scrollBottomPadding()
    }

    /// 通知が許可されていないときの案内。ここを出さないと
    /// 「設定したのに来ない」状態に気づけない。
    private var permissionDeniedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("notif_denied_title".loc)
                .font(SM.f(12.5, .bold)).foregroundStyle(SM.red)
            Text("notif_denied_body".loc)
                .font(SM.f(11.5)).lineSpacing(7).foregroundStyle(SM.sub)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("notif_denied_open".loc)
                    .font(SM.f(12.5, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(SM.alert, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .smStroke(SM.redLine, radius: 14)
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private func section<Content: View>(_ key: String, color: Color = SM.sub,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(key: key, color: color)
            content()
        }
        .padding(.horizontal, 20)
    }

    private func toggleRow(_ titleKey: String, _ noteKey: String,
                           isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey.loc).font(SM.f(13)).foregroundStyle(SM.fg)
                    Text(noteKey.loc).font(SM.f(10.5)).foregroundStyle(SM.sub)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SMSwitch(isOn: isOn)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 通知の文面（5種）

struct NotifMessagesScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "msgs_title")

                Text("msgs_note".loc)
                    .font(SM.f(11.5)).lineSpacing(8).foregroundStyle(SM.sub)
                    .padding(.horizontal, 24).padding(.top, 22)
                    .fixedSize(horizontal: false, vertical: true)

                let previews = store.notifPreviews
                if previews.isEmpty {
                    Text("msgs_empty".loc)
                        .font(SM.f(12.5)).lineSpacing(8).foregroundStyle(SM.dim)
                        .padding(.horizontal, 24).padding(.top, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(previews) { m in
                        Button {
                            if let id = m.subscriptionID, let sub = store.sub(id) { store.open(sub) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 9) {
                                    Text(m.tagKey.loc)
                                        .font(SM.f(9.5, .medium)).foregroundStyle(m.color)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(m.color, lineWidth: 1))
                                    Text("brand_name".loc).font(SM.f(11.5, .bold)).foregroundStyle(SM.fg)
                                    Spacer()
                                    Text(verbatim: store.nset.time)
                                        .font(SM.n(10, .regular)).foregroundStyle(SM.sub)
                                }
                                Text(verbatim: m.title)
                                    .font(SM.f(13, .bold)).lineSpacing(6).foregroundStyle(SM.fg)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: m.body)
                                    .font(SM.f(11.5)).lineSpacing(7).foregroundStyle(SM.sub)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: m.action)
                                    .font(SM.f(10.5, .medium)).foregroundStyle(SM.indigo)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .smCard(radius: 18)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(m.subscriptionID != nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
            }
        }
        .scrollBottomPadding()
    }
}
