//
//  SubscriptionFormScreen.swift
//  submemo
//
//  サブスクの入力フォーム。新規登録（候補を選んだあとの「内容の確認」）と
//  既存の編集で同じ画面を使う。store.draft.editingID の有無でモードが決まる。
//

import SwiftUI

struct SubscriptionFormScreen: View {
    @EnvironmentObject private var store: AppStore
    /// 金額欄にカーソルがあるか。± を押したときに外して、打ち替えと衝突させない。
    @FocusState private var priceFocused: Bool
    /// 金額欄に出している文字。編集中は桁区切りを外し、離れたら整形して戻す。
    @State private var priceText = ""
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { store.draft.isEditing }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identity
                    priceCard.padding(.top, 24)
                    cycleSection.padding(.top, 18)
                    nextRenewalCard.padding(.top, 18)
                    categorySection.padding(.top, 18)
                    paymentSection.padding(.top, 18)
                    trialToggle.padding(.top, 18)
                    summary.padding(.top, 18)
                    if isEditing { deleteButton.padding(.top, 24) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
            }
            .scrollBottomPadding()
            .scrollDismissesKeyboard(.immediately)

            Button { store.saveDraft() } label: {
                Text((isEditing ? "save" : "add_save").loc)
                    .font(SM.f(15, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(SM.indigo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .confirmationDialog("form_delete_confirm_title".loc,
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("row_delete".loc, role: .destructive) {
                if let sub = store.sub(store.draft.editingID) {
                    store.delete(sub)
                    store.goTab(.home)
                }
            }
            Button("cancel".loc, role: .cancel) {}
        } message: {
            Text("form_delete_confirm_message".loc)
        }
    }

    // MARK: - ヘッダー

    private var navBar: some View {
        ScreenNavBar(titleKey: isEditing ? "form_title_edit" : "add_confirm_title")
    }

    // MARK: - 名前

    private var nameBinding: Binding<String> {
        Binding(
            get: { store.draft.editableName },
            set: { store.draft.customName = $0 }
        )
    }

    private var identity: some View {
        HStack(spacing: 14) {
            InitialTile(text: store.draft.initial,
                        color: store.category(store.draft.categoryID).color,
                        size: 56, radius: 17, fontSize: 23)
            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: nameBinding,
                          prompt: Text("form_name_placeholder".loc).foregroundStyle(SM.dim))
                    .font(SM.f(17, .medium))
                    .foregroundStyle(SM.fg)
                    .focused($nameFocused)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .smCard(radius: 12)
                    .smStroke(SM.border, radius: 12)
                // 候補から入れたときだけ、上書きできることを添える。
                if !isEditing, store.draft.nameKey != nil {
                    Text("add_autofill_note".loc).font(SM.f(11.5)).foregroundStyle(SM.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - 料金

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("add_price".loc).font(SM.f(11)).foregroundStyle(SM.sub)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Currency.allCases) { c in
                        Chip(title: "\(c.symbol) \(c.rawValue)", isKey: false,
                             selected: store.draft.currency == c, height: 28, fill: false) {
                            store.selectCurrency(c)
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                stepper("minus") { priceFocused = false; store.stepPrice(-1) }
                // 数字はそのまま打ち替えられる。± だけだと桁の大きい額が遠い。
                HStack(spacing: 1) {
                    Text(verbatim: store.draft.currency.symbol)
                        .font(SM.n(30, .semibold))
                    // フォントは TextField に直接あてる。まわりの .font() は
                    // 入力欄には届かず、既定サイズのまま小さく出てしまう。
                    TextField("", text: $priceText)
                        .font(SM.n(30, .semibold))
                        .keyboardType(store.draft.currency == .JPY ? .numberPad : .decimalPad)
                        .multilineTextAlignment(.leading)
                        .fixedSize()
                        .focused($priceFocused)
                }
                .foregroundStyle(SM.fg)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                // ± の内側ならどこを触っても編集に入れる。数字だけだと的が小さい。
                .contentShape(Rectangle())
                .onTapGesture { priceFocused = true }
                stepper("plus") { priceFocused = false; store.stepPrice(1) }
            }
            .padding(.top, 4)

            if store.draft.currency != .JPY {
                Text(verbatim: TRF("add_fx_line_format", Money.text(store.draftYen),
                                   store.draft.currency.symbol,
                                   String(format: "%.1f", store.draftRate)))
                    .font(SM.n(12.5, .medium))
                    .foregroundStyle(SM.indigoFg)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .onAppear { priceText = Self.display(store.draft.price) }
        .onChange(of: priceFocused) { _, focused in
            // 編集に入ったら桁区切りを外し、離れたら整形して戻す。
            priceText = focused ? Self.plain(store.draft.price)
                                : Self.display(store.draft.price)
        }
        .onChange(of: priceText) { _, text in
            // 打っているあいだも要約に反映させる。
            guard priceFocused else { return }
            store.setDraftPrice(Self.parse(text))
        }
        .onChange(of: store.draft.price) { _, value in
            // ±・通貨・サイクルの変更を欄に反映する（編集中は邪魔しない）。
            guard !priceFocused else { return }
            priceText = Self.display(value)
        }
        .smCard()
    }

    private func stepper(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SM.fg)
                .frame(width: 36, height: 36)
                .smStroke(SM.border2, radius: 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - サイクル・次回更新日

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("add_cycle".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
            HStack(spacing: 8) {
                ForEach(Cycle.allCases) { c in
                    Chip(title: c.chipKey, selected: store.draft.cycle == c) {
                        store.selectCycle(c)
                    }
                }
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { store.draft.nextRenewal },
            set: { store.draft.nextRenewal = $0; store.draft.dateTouched = true }
        )
    }

    private var nextRenewalCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.draft.hasRenewalDate.toggle()
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("form_next_renewal".loc).font(SM.f(13)).foregroundStyle(SM.fg)
                        // オンにすると何が変わるかを書いておく。
                        // 入れないと通知が組めず、今月の請求額にも入らない。
                        Text("form_next_renewal_note".loc)
                            .font(SM.f(10.5)).lineSpacing(4).foregroundStyle(SM.sub)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 12)
                    SMSwitch(isOn: store.draft.hasRenewalDate)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.draft.hasRenewalDate {
                Rectangle().fill(SM.line).frame(height: 1)
                HStack {
                    Text("form_next_renewal_date".loc).font(SM.f(13)).foregroundStyle(SM.fg)
                    Spacer(minLength: 12)
                    DatePicker("", selection: dateBinding, displayedComponents: .date)
                        .labelsHidden()
                        .tint(SM.indigo)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .smCard()
    }

    // MARK: - カテゴリ・支払い方法

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("add_category".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(store.categories) { c in
                    Chip(title: c.name, isKey: false, selected: store.draft.categoryID == c.id,
                         tone: .solid(c.color), height: 36, fill: false) {
                        store.draft.categoryID = c.id
                    }
                }
                // 入力の途中で足せるように。作ったものはそのまま選ばれる。
                addChip { store.addCategory() }
            }
        }
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("detail_pay".loc).font(SM.f(11)).foregroundStyle(SM.sub).padding(.leading, 2)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(store.paymentMethods) { p in
                    Chip(title: p.label, isKey: false,
                         selected: store.draft.paymentMethodID == p.id,
                         tone: .solid(p.color), height: 36, fill: false) {
                        store.draft.paymentMethodID = p.id
                    }
                }
                addChip { store.addPayment() }
            }
        }
    }

    /// 表示用（"1,590"）。
    private static func display(_ v: Double) -> String { Yen.num(v) }

    /// 編集用。桁区切りを入れず、端数が無ければ整数で出す。
    private static func plain(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    /// 入力文字を金額に。区切りや余計な文字は落とす。
    private static func parse(_ text: String) -> Double {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        return Double(cleaned) ?? 0
    }

    /// カテゴリ・支払い方法の末尾に置く「＋ 追加」。
    private func addChip(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                Text("add_new_chip".loc).font(SM.f(12.5, .medium))
            }
            .foregroundStyle(SM.sub)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(SM.border2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - トライアル・要約・削除

    private var trialToggle: some View {
        Button {
            store.draft.trial.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("add_trial_title".loc).font(SM.f(13.5, .medium)).foregroundStyle(SM.fg)
                    Text("add_trial_note".loc).font(SM.f(11)).foregroundStyle(SM.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SMSwitch(isOn: store.draft.trial, onColor: SM.alert)
            }
            .padding(16)
            .smCard()
            .smStroke(store.draft.trial ? Color(hex: 0xFF5C5C, alpha: 0.5) : SM.line2)
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        let m = store.draftMonthly
        // 編集中は自分自身の分を入れ替えた合計を出す。
        let others = store.totalMonthly - (store.sub(store.draft.editingID).map { store.monthly($0) } ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: TRF("add_summary_format", Money.text(m), Money.text(m * 12), Money.text(m * 12 / 365)))
                .font(SM.n(11.5, .regular))
                .foregroundStyle(SM.sub)
            Text(verbatim: TRF(isEditing ? "form_new_total_format" : "add_new_total_format",
                               Money.text(others + (store.draft.trial ? 0 : m))))
                .font(SM.n(11.5, .regular))
                .foregroundStyle(SM.sub)
        }
        .lineSpacing(6)
        .padding(.horizontal, 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var deleteButton: some View {
        Button { confirmDelete = true } label: {
            Text("form_delete".loc)
                .font(SM.f(13, .medium)).foregroundStyle(SM.alert)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(SM.redTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .smStroke(Color(hex: 0xFF5C5C, alpha: 0.35), radius: 14)
        }
        .buttonStyle(.plain)
    }
}
