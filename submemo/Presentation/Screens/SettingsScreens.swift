//
//  SettingsScreens.swift
//  submemo
//
//  設定と、そこから開く カテゴリ / 支払い方法 / 通貨と為替レート / CSV書き出し。
//

import SwiftUI

// MARK: - 設定

struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var iCloudSync: iCloudSyncManager
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.default.rawValue
    @State private var confirmClearSamples = false
    @State private var confirmDeleteAll = false

    private var appearance: AppearanceMode { AppearanceMode.current(from: appearanceRaw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitleBar("tab_settings")

                rowsCard

                Text((iCloudSync.isEnabled ? "settings_note_icloud" : "settings_note").loc)
                    .font(SM.f(10.5)).lineSpacing(9).foregroundStyle(SM.dim)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)

                if AppFlags.needSampleData { debugDataSection }

            }
        }
        .scrollBottomPadding()
        .confirmationDialog("settings_sample_clear_confirm_title".loc,
                            isPresented: $confirmClearSamples, titleVisibility: .visible) {
            Button("settings_sample_clear".loc, role: .destructive) { store.removeSamples() }
            Button("cancel".loc, role: .cancel) {}
        } message: {
            Text("settings_sample_clear_confirm_message".loc)
        }
        .confirmationDialog("settings_delete_all_confirm_title".loc,
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("settings_delete_all".loc, role: .destructive) { store.deleteAll() }
            Button("cancel".loc, role: .cancel) {}
        } message: {
            Text("settings_delete_all_confirm_message".loc)
        }
    }

    // MARK: - サンプルデータ（Debug ビルドのみ）

    private var debugDataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("settings_section_data".loc)
                .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(SampleDataLanguage.allCases) { lang in
                    debugRow("plus.circle", lang.labelKey, lang.subKey, tint: SM.indigo) {
                        store.addSamples(lang)
                    }
                    Rectangle().fill(SM.line).frame(height: 1)
                }
                debugRow("questionmark.circle", "settings_coach_reset", "settings_coach_reset_sub",
                         tint: SM.indigo) {
                    store.resetCoachMarks()
                }
                Rectangle().fill(SM.line).frame(height: 1)
                debugRow("trash", "settings_sample_clear", "settings_sample_clear_sub", tint: SM.amber) {
                    confirmClearSamples = true
                }
                Rectangle().fill(SM.line).frame(height: 1)
                debugRow("exclamationmark.triangle", "settings_delete_all", "settings_delete_all_sub",
                         tint: SM.alert) {
                    confirmDeleteAll = true
                }
            }
            .smCard()
            .padding(.horizontal, 20)

            if let summary = store.sampleSummary {
                Text(verbatim: summary)
                    .font(SM.f(11.5)).foregroundStyle(SM.sub)
                    .padding(.horizontal, 24).padding(.top, 10)
            }
        }
    }

    private func debugRow(_ icon: String, _ titleKey: String, _ subKey: String,
                          tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey.loc).font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                    Text(subKey.loc).font(SM.f(10.5)).foregroundStyle(SM.sub)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowsCard: some View {
        VStack(spacing: 0) {
            row("settings_notif", store.notifSettingsSummary, SM.indigo) { store.go(.notifset) }
            row("settings_cats", TRF("settings_cats_value_format", store.categories.count), SM.indigo) { store.go(.cats) }
            row("settings_pays", TRF("settings_count_format", store.payStats.count), SM.indigo) { store.go(.pays) }
            row("settings_theme", TR(appearance.titleKey), SM.indigo) { appearanceRaw = appearance.next.rawValue }
            row("settings_base", store.baseCurrency.rawValue, SM.indigo) { store.go(.base) }
            row("settings_fx",
                TRF("settings_fx_value_format", store.fxCurrent.symbol,
                    String(format: "%.1f", store.rate(for: store.fxCurrent))),
                SM.indigo) { store.go(.fx) }
            annualSplitRow
            row("settings_storage",
                TR(iCloudSync.isEnabled ? "settings_storage_value_icloud" : "settings_storage_value"),
                SM.green, action: nil)
            iCloudToggleRow
            if iCloudSync.isEnabled { iCloudSyncRow }
            row("settings_msgs", TRF("settings_count_format", store.notifPreviews.count), SM.indigo) { store.go(.msgs) }
            row("settings_csv", "›", SM.sub, isLast: true) {
                store.csv.open = true
                store.csv.done = false
            }
        }
        .smCard()
        .padding(20)
    }

    // MARK: - iCloud 同期

    /// 「年払いを月割りで含める」。ホームの月表示の意味が変わるので、説明も添える。
    private var annualSplitRow: some View {
        VStack(spacing: 0) {
            Button {
                store.setSplitsAnnual(!store.splitsAnnual)
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings_annual_split".loc).font(SM.f(13)).foregroundStyle(SM.fg)
                        Text("settings_annual_split_note".loc)
                            .font(SM.f(10.5)).foregroundStyle(SM.sub)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 12)
                    SMSwitch(isOn: store.splitsAnnual)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rectangle().fill(SM.line).frame(height: 1)
        }
    }

    private var iCloudToggleRow: some View {
        VStack(spacing: 0) {
            Button {
                iCloudSync.isEnabled.toggle()
            } label: {
                HStack {
                    Text("settings_icloud_toggle".loc).font(SM.f(13)).foregroundStyle(SM.fg)
                    Spacer(minLength: 12)
                    SMSwitch(isOn: iCloudSync.isEnabled)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rectangle().fill(SM.line).frame(height: 1)
        }
    }

    private var iCloudSyncRow: some View {
        VStack(spacing: 0) {
            Button {
                Task { await iCloudSync.syncNow() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings_icloud_now".loc).font(SM.f(13)).foregroundStyle(SM.fg)
                        Text(verbatim: iCloudStatusText)
                            .font(SM.f(10.5)).foregroundStyle(iCloudStatusColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 12)
                    if iCloudSync.status == .syncing {
                        ProgressView().tint(SM.indigo)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SM.indigo)
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rectangle().fill(SM.line).frame(height: 1)
        }
    }

    private var iCloudStatusText: String {
        if case let .failure(message) = iCloudSync.status { return message }
        guard let date = iCloudSync.lastSyncedAt else { return TR("settings_icloud_never") }
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return TRF("settings_icloud_synced_format", f.string(from: date))
    }

    private var iCloudStatusColor: Color {
        if case .failure = iCloudSync.status { return SM.red }
        return SM.sub
    }

    @ViewBuilder
    private func row(_ key: String, _ value: String, _ color: Color,
                     isLast: Bool = false, action: (() -> Void)?) -> some View {
        let content = HStack {
            Text(key.loc).font(SM.f(13)).foregroundStyle(SM.fg)
            Spacer(minLength: 12)
            Text(verbatim: value).font(SM.f(13, .medium)).foregroundStyle(color)
        }
        .padding(16)
        .contentShape(Rectangle())

        VStack(spacing: 0) {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
            if !isLast { Rectangle().fill(SM.line).frame(height: 1) }
        }
    }
}

// MARK: - カテゴリ

struct CategoriesScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "cats_title") {
                    Button { store.addCategory() } label: {
                        Text("add_plus".loc).font(SM.f(13, .medium)).foregroundStyle(SM.indigo)
                    }
                    .buttonStyle(.plain)
                }

                Text(verbatim: TRF("cats_total_format", store.categories.count))
                    .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                    .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 8)

                VStack(spacing: 2) {
                    ForEach(store.categories) { c in
                        let inCat = store.all.filter { $0.categoryID == c.id }
                        let sum = inCat.reduce(0) { $0 + store.monthly($1) }
                        Button { store.editCategory(c) } label: {
                            HStack(spacing: 13) {
                                InitialTile(text: c.initial, color: c.color,
                                            size: 38, radius: 12, fontSize: 15)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: c.name).font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                                    Text(verbatim: TRF("settings_count_format", inCat.count))
                                        .font(SM.f(11)).foregroundStyle(SM.sub)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(verbatim: sum > 0
                                     ? TRF("per_month_amount_format", Money.text(sum))
                                     : TR("cats_unused"))
                                    .font(SM.n(12.5, .medium))
                                    .foregroundStyle(sum > 0 ? SM.fg : SM.dim)
                                ChevronRight()
                            }
                            .padding(.horizontal, 8).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Text("cats_note".loc)
                    .font(SM.f(10.5)).lineSpacing(9).foregroundStyle(SM.dim)
                    .padding(.horizontal, 24).padding(.top, 22)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollBottomPadding()
    }
}

/// カテゴリの追加・編集シート。
struct CategoryEditSheet: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        BottomSheet(estimatedHeight: 430) {
            if let edit = store.catEdit {
                VStack(spacing: 20) {
                    HStack {
                        Button { store.catEdit = nil } label: {
                            Text("cancel".loc).font(SM.f(13)).foregroundStyle(SM.sub)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text((edit.isNew ? "cats_sheet_new" : "cats_sheet_edit").loc)
                            .font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                        Spacer()
                        Button { store.saveCategory() } label: {
                            Text("save".loc).font(SM.f(13, .bold)).foregroundStyle(SM.indigo)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 14) {
                        InitialTile(text: edit.name.isEmpty ? "＋" : String(edit.name.prefix(1)),
                                    color: Color(hex: edit.colorHex),
                                    size: 52, radius: 16, fontSize: 21)
                        TextField("", text: Binding(
                            get: { store.catEdit?.name ?? "" },
                            set: { store.catEdit?.name = $0 }
                        ), prompt: Text("cats_name_placeholder".loc).foregroundStyle(SM.dim))
                            .font(SM.f(15))
                            .foregroundStyle(SM.fg)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(SM.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .smStroke(SM.border, radius: 13)
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        Text("cats_color".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                                  spacing: 12) {
                            ForEach(SM.palette, id: \.self) { hex in
                                Button { store.catEdit?.colorHex = hex } label: {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: hex))
                                        .frame(height: 36)
                                        .overlay {
                                            if edit.colorHex == hex {
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .stroke(Color(hex: hex), lineWidth: 2)
                                                    .padding(-4)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text((edit.isNew ? "cats_usage_new" : "cats_usage_edit").loc)
                        .font(SM.f(10.5)).lineSpacing(8).foregroundStyle(SM.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.canDeleteEditingCategory {
                        Button { store.deleteCategory() } label: {
                            Text("cats_delete".loc)
                                .font(SM.f(13, .medium)).foregroundStyle(SM.alert)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .smStroke(Color(hex: 0xFF5C5C, alpha: 0.35), radius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 支払い方法

struct PaymentsScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "pays_title") {
                    Button { store.addPayment() } label: {
                        Text("add_plus".loc).font(SM.f(13, .medium)).foregroundStyle(SM.indigo)
                    }
                    .buttonStyle(.plain)
                }

                Text("pays_breakdown".loc)
                    .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                    .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 8)

                // 使われている支払い方法は内訳つきで、まだ使っていないものは下にまとめる。
                VStack(spacing: 16) {
                    ForEach(store.payStats) { p in
                        Button { store.editPayment(p.method) } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                methodRow(p.method,
                                          sub: TRF("settings_count_format", p.count),
                                          trailing: TRF("per_month_amount_format", Money.text(p.yen)))
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(SM.line2)
                                        Capsule().fill(p.method.color).frame(width: geo.size.width * p.ratio)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if !unusedMethods.isEmpty {
                    Text("pays_unused".loc)
                        .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 8)

                    VStack(spacing: 2) {
                        ForEach(unusedMethods) { m in
                            Button { store.editPayment(m) } label: {
                                methodRow(m, sub: nil, trailing: nil)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("pays_privacy_title".loc).font(SM.f(12.5, .medium)).foregroundStyle(SM.fg)
                    Text("pays_privacy_body".loc)
                        .font(SM.f(11)).lineSpacing(8).foregroundStyle(SM.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .smCard()
                .padding(.horizontal, 20)
                .padding(.top, 26)
                
            }
        }
        .scrollBottomPadding()
    }

    /// まだ1件も紐づいていない支払い方法。
    private var unusedMethods: [PaymentMethod] {
        let used = Set(store.payStats.map(\.id))
        return store.paymentMethods.filter { !used.contains($0.id) }
    }

    private func methodRow(_ m: PaymentMethod, sub: String?, trailing: String?) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(m.color).frame(width: 38, height: 26)
                .overlay(Text(verbatim: m.initial)
                    .font(SM.f(11, .bold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: m.name).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                let parts = [m.detail, sub].compactMap { $0 }.filter { !$0.isEmpty }
                if !parts.isEmpty {
                    Text(verbatim: parts.joined(separator: Sep.mid))
                        .font(SM.f(10.5)).foregroundStyle(SM.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                Text(verbatim: trailing).font(SM.n(13, .medium)).foregroundStyle(SM.fg)
            } else {
                ChevronRight()
            }
        }
    }
}

/// 支払い方法の追加・編集シート。
/// カード番号や有効期限は預からず、名前・下4桁・色だけを持つ。
struct PaymentEditSheet: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        BottomSheet(estimatedHeight: 470) {
            if let edit = store.payEdit {
                VStack(spacing: 20) {
                    HStack {
                        Button { store.payEdit = nil } label: {
                            Text("cancel".loc).font(SM.f(13)).foregroundStyle(SM.sub)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text((edit.isNew ? "pays_sheet_new" : "pays_sheet_edit").loc)
                            .font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                        Spacer()
                        Button { store.savePayment() } label: {
                            Text("save".loc).font(SM.f(13, .bold)).foregroundStyle(SM.indigo)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: edit.colorHex))
                            .frame(width: 62, height: 42)
                            .overlay(Text(verbatim: edit.name.isEmpty ? "＋" : String(edit.name.prefix(1)))
                                .font(SM.f(17, .bold)).foregroundStyle(.white))
                        TextField("", text: Binding(
                            get: { store.payEdit?.name ?? "" },
                            set: { store.payEdit?.name = $0 }
                        ), prompt: Text("pays_name_placeholder".loc).foregroundStyle(SM.dim))
                            .font(SM.f(15))
                            .foregroundStyle(SM.fg)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(SM.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .smStroke(SM.border, radius: 13)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("pays_last4".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
                        TextField("", text: Binding(
                            get: { store.payEdit?.last4 ?? "" },
                            // 数字4桁だけを受け取る。カード番号は預からない。
                            set: { store.payEdit?.last4 = String($0.filter(\.isNumber).prefix(4)) }
                        ), prompt: Text("pays_last4_placeholder".loc).foregroundStyle(SM.dim))
                            .font(SM.n(15, .regular))
                            .keyboardType(.numberPad)
                            .foregroundStyle(SM.fg)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(SM.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .smStroke(SM.border, radius: 13)
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        Text("cats_color".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                                  spacing: 12) {
                            ForEach(SM.palette, id: \.self) { hex in
                                Button { store.payEdit?.colorHex = hex } label: {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: hex))
                                        .frame(height: 36)
                                        .overlay {
                                            if edit.colorHex == hex {
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .stroke(Color(hex: hex), lineWidth: 2)
                                                    .padding(-4)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 使用中でも消せるので、何件が影響を受けるかを先に伝える。
                    Text(verbatim: store.editingPaymentUsageCount > 0
                         ? TRF("pays_delete_note_format", store.editingPaymentUsageCount)
                         : TR("pays_privacy_body"))
                        .font(SM.f(10.5)).lineSpacing(8).foregroundStyle(SM.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.canDeleteEditingPayment {
                        Button { store.deletePayment() } label: {
                            Text("pays_delete".loc)
                                .font(SM.f(13, .medium)).foregroundStyle(SM.alert)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .smStroke(Color(hex: 0xFF5C5C, alpha: 0.35), radius: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 通貨と為替レート

struct FxScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenNavBar(titleKey: "fx_title")

                VStack(spacing: 0) {
                    // 外貨で登録している通貨が2つ以上あるときだけ、切り替えを出す。
                    if store.fxCurrencies.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(store.fxCurrencies) { c in
                                Chip(title: c.rawValue, isKey: false,
                                     selected: store.fxCurrent == c, height: 34, fill: false) {
                                    store.fxSelected = c
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    }

                    Text("fx_current".loc).font(SM.f(11.5)).foregroundStyle(SM.sub)
                    HStack(spacing: 18) {
                        stepButton("minus") { store.stepFxRate(-0.5) }
                        Text(verbatim: "¥" + String(format: "%.1f", store.rate(for: store.fxCurrent)))
                            .font(SM.n(40, .semibold)).foregroundStyle(SM.fg)
                        stepButton("plus") { store.stepFxRate(0.5) }
                    }
                    .padding(.top, 14)
                    // 実際の取得時刻を出す。取得中・失敗もここで伝える。
                    Group {
                        if store.fxFetching {
                            Text("fx_fetching".loc).foregroundStyle(SM.sub)
                        } else if let error = store.fxError {
                            Text(verbatim: error).foregroundStyle(SM.red)
                        } else {
                            Text(verbatim: store.fxUpdatedText).foregroundStyle(SM.sub)
                        }
                    }
                    .font(SM.f(11.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 30)

                VStack(alignment: .leading, spacing: 11) {
                    SectionLabel(key: "fx_mode_label")
                    HStack(spacing: 8) {
                        ForEach(AppStore.FxMode.allCases) { m in
                            Chip(title: m.labelKey, selected: store.fxMode == m) { store.setFxMode(m) }
                        }
                    }

                    // 毎日取りに行っても土日は値が動かない。取得できていないと
                    // 誤解されないよう、元データの都合をここで断っておく。
                    Text("fx_mode_note".loc)
                        .font(SM.f(10.5)).lineSpacing(9).foregroundStyle(SM.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)

                Text("fx_items_label".loc)
                    .font(SM.f(11.5, .medium)).tracking(0.6).foregroundStyle(SM.sub)
                    .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 8)

                VStack(spacing: 2) {
                    ForEach(store.fxItems) { sub in
                        HStack(spacing: 13) {
                            InitialTile(text: sub.initial, color: store.category(sub.categoryID).color,
                                        size: 38, radius: 12, fontSize: 15)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: sub.name).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                                Text(verbatim: store.rawLabel(sub)).font(SM.n(11, .regular)).foregroundStyle(SM.sub)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: Money.text(store.monthly(sub)))
                                .font(SM.n(14, .medium)).foregroundStyle(SM.fg)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 11)
                    }
                }
                .padding(.horizontal, 20)

                Text("fx_note".loc)
                    .font(SM.f(10.5)).lineSpacing(9).foregroundStyle(SM.dim)
                    .padding(.horizontal, 24).padding(.top, 22)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollBottomPadding()
        .task { await store.refreshRates() }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SM.fg)
                .frame(width: 40, height: 40)
                .smStroke(SM.border2, radius: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CSV 書き出し

struct CsvSheet: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        BottomSheet(estimatedHeight: 420) {
            Group {
                if store.csv.done { doneBody } else { formBody }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var doneBody: some View {
        let failed = store.csv.error != nil
        return VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(failed ? SM.redTint : Color(hex: 0x2FBF71, alpha: 0.14))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: failed ? "exclamationmark.triangle" : "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(failed ? SM.red : SM.green))

            Text((failed ? "csv_failed_title" : "csv_done_title").loc)
                .font(SM.f(15, .bold)).foregroundStyle(SM.fg)

            VStack(spacing: 4) {
                if let error = store.csv.error {
                    Text(verbatim: error)
                } else {
                    Text(verbatim: store.csvFileName + Sep.mid + store.csvRowsLabel)
                    Text("csv_done_note".loc)
                }
            }
            .font(SM.n(11.5, .regular))
            .multilineTextAlignment(.center)
            .foregroundStyle(SM.sub)

            HStack(spacing: 9) {
                if let url = store.csv.fileURL {
                    // 「ファイル」アプリへの保存も他アプリへの送信も、共有シートに任せる。
                    ShareLink(item: url) {
                        Text("csv_share".loc)
                            .font(SM.f(13, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(SM.indigo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button { store.closeCsv() } label: {
                    Text("close".loc)
                        .font(SM.f(13, .medium)).foregroundStyle(SM.fg)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .smStroke(SM.border2, radius: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.top, 10)
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Text("csv_title".loc).font(SM.f(14, .medium)).foregroundStyle(SM.fg)
                HStack {
                    Button { store.closeCsv() } label: {
                        Text("cancel".loc).font(SM.f(13)).foregroundStyle(SM.sub)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 11) {
                Text("csv_range".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
                HStack(spacing: 8) {
                    ForEach(CsvExporter.Range.allCases) { r in
                        // 「今年」は実際の年を出す。文言に年を焼き込むと年明けにずれる。
                        Chip(title: store.csvRangeLabel(r), isKey: false,
                             selected: store.csv.range == r) { store.csv.range = r }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 11) {
                Text("csv_columns".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    Chip(title: "csv_col_price", selected: store.csv.columns.price, height: 38, fill: false) {
                        store.csv.columns.price.toggle()
                    }
                    Chip(title: "csv_col_next", selected: store.csv.columns.next, height: 38, fill: false) {
                        store.csv.columns.next.toggle()
                    }
                    Chip(title: "csv_col_cat", selected: store.csv.columns.category, height: 38, fill: false) {
                        store.csv.columns.category.toggle()
                    }
                    Chip(title: "csv_col_pay", selected: store.csv.columns.pay, height: 38, fill: false) {
                        store.csv.columns.pay.toggle()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: store.csvHeaderLine)
                Text(verbatim: store.csvSampleLine)
            }
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(SM.sub)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(SM.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("csv_encoding_note".loc)
                .font(SM.f(10.5)).lineSpacing(8).foregroundStyle(SM.dim)
                .fixedSize(horizontal: false, vertical: true)

            Button { store.runCsvExport() } label: {
                Text(verbatim: TRF("csv_run_format", store.csvRowsLabel))
                    .font(SM.f(14, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(SM.indigo, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
