//
//  AppStore.swift
//  submemo
//
//  アプリの状態をまとめて持つストア。
//  ・サブスクとカスタムカテゴリは UserDefaults に永続化する実データ
//  ・画面遷移や入力途中の値などの UI 状態はメモリのみ
//  画面ごとにモックを外していく途中なので、当面はこの1つに集約している。
//

import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {

    // MARK: - 画面

    enum Screen: Hashable {
        case onboard, home, detail, cancel, add1, form
        case stats, notif, settings
        case msgs, notifset, pays, fx, cats, catlist
    }

    /// タブバーに並べる4画面。
    static let tabScreens: [Screen] = [.home, .stats, .notif, .settings]

    /// タブバーを出す画面。カテゴリ一覧は集計の下層なのでタブを出したままにする。
    static func showsTabBar(_ s: Screen) -> Bool {
        tabScreens.contains(s) || s == .catlist
    }

    /// タブバーで点灯させるタブ。
    static func activeTab(for s: Screen) -> Screen {
        s == .catlist ? .stats : s
    }

    /// ヒーロー数値の見せ方。
    enum HeroMetric: CaseIterable { case month, year, day }

    /// 集計のヒーロー。ホームと違って「今月の請求額」は持たず、年額換算から始める。
    enum StatsMetric: CaseIterable { case year, month, day }

    /// その画面をはじめて開いたときに出すガイドの段階。各画面ひとつずつ。
    /// 0件のときと登録があるときでは指せる相手が違うので、内容を分けてある。
    enum CoachStep: Equatable {
        case none
        case homeEmpty, homeMain
        case statsEmpty, statsMain
        case notifEmpty, notifMain

        /// 0件のときのガイドか。済みの記録を分けるのに使う。
        var isEmptyGuide: Bool {
            self == .homeEmpty || self == .statsEmpty || self == .notifEmpty
        }

        /// ハイライトする要素。
        var target: CoachTarget? {
            switch self {
            case .homeEmpty:  return .homeEmptyCta
            case .homeMain:   return .homeHero
            case .statsEmpty: return .statsEmptyCta
            case .statsMain:  return .statsCats
            case .notifEmpty: return .notifEmptySettings
            case .notifMain:  return .notifTimeline
            case .none:       return nil
            }
        }

        /// ハイライトの下端を詰める量。
        /// 集計のカテゴリ内訳は、いちばん下の行にも区切り線が付くぶん枠が下に伸びて見えるので詰める。
        var holeBottomTrim: CGFloat {
            self == .statsMain ? 10 : 0
        }

        var textKey: String {
            switch self {
            case .homeEmpty:  return "coach_home_empty"
            case .homeMain:   return "coach_home_main"
            case .statsEmpty: return "coach_stats_empty"
            case .statsMain:  return "coach_stats_main"
            case .notifEmpty: return "coach_notif_empty"
            case .notifMain:  return "coach_notif_main"
            case .none:       return ""
            }
        }
    }

    /// 為替レートの更新方法。
    enum FxMode: String, CaseIterable, Identifiable {
        case daily, weekly, manual
        var id: String { rawValue }
        var labelKey: String { "fx_mode_\(rawValue)" }
    }

    // MARK: - 実データ（永続化する）

    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var customCategories: [SubCategory] = []
    @Published private(set) var customPayments: [PaymentMethod] = []
    /// 消した組み込みの支払い方法。組み込みはコード側にあるので、消した記録として持つ。
    @Published private(set) var hiddenPaymentIDs: Set<String> = []

    private let subscriptionRepository: SubscriptionRepositoryProtocol
    private let categoryRepository: SubCategoryRepositoryProtocol
    private let paymentRepository: PaymentMethodRepositoryProtocol
    /// ユーザが能動的に削除した記録。iCloud 合併でこれがある ID だけを消す。
    private let tombstones = TombstoneRepository()

    // MARK: - UI 状態（永続化しない）

    @Published var screen: Screen = .onboard
    @Published var obIndex = 0

    // ホーム
    @Published var sortHigh = true
    @Published var heroMetric: HeroMetric = .month
    /// スワイプで開いている行（同時に開くのは1行だけ）
    @Published var openSwipeID: UUID?

    // 集計
    /// 集計のヒーローで見せている単位。タップで切り替える。
    @Published var statsMetric: StatsMetric = .year

    // 画面ごとのガイド
    /// いま出しているガイドの段階。none なら出していない。
    @Published var coachStep: CoachStep = .none

    // 詳細・解約シミュレーション
    @Published var selectedID: UUID?
    @Published var fromNotif = false
    @Published var cancelOne: UUID?
    @Published var cancelOff: Set<UUID> = []

    // 集計 → カテゴリ一覧
    @Published var catListID: String?

    // 追加
    @Published var query = ""
    @Published var draft = Draft()
    /// カテゴリ一覧から追加を始めたときに引き継ぐカテゴリ。
    private var pendingCategoryID: String?
    /// 候補をタップしたが、すでに同名が登録されていたときの相手。
    @Published private var pickedDuplicate: Subscription?
    /// 「別プランとして追加」で進む先の候補。
    private var pendingSeed: SeedService?

    // 通知
    @Published private(set) var nset = NotifSettings()
    /// 通知が許可されなかった。設定画面で iOS の設定へ誘導する。
    @Published var notifPermissionDenied = false
    private static let notifSettingsKey = "submemo.notifSettings"

    // 為替
    /// 手で決めたレート（通貨コード → 1通貨あたりの円）。入っている通貨は取得値より優先する。
    @Published private(set) var manualRates: [String: Double] = [:]
    /// 為替画面でいま調整している通貨。
    @Published var fxSelected: Currency = .USD
    @Published private(set) var fxMode: FxMode = .daily
    /// 最後に取得できたレートと時刻。未取得なら nil。
    @Published private(set) var fxRates: ExchangeRates?
    /// 取得中か。
    @Published private(set) var fxFetching = false
    /// 取得に失敗した理由。成功したら消す。
    @Published private(set) var fxError: String?

    private static let fxModeKey = "submemo.fxMode"
    private static let fxManualRatesKey = "submemo.fxManualRates"
    /// 旧版の手動レート（USD の値ひとつ）。読み込み時に新しい形へ移す。
    private static let legacyManualRateKey = "submemo.fxManualRate"

    // カテゴリ編集シート
    @Published var catEdit: CatEdit?

    // 支払い方法の編集シート
    @Published var payEdit: PayEdit?

    // CSV 書き出しシート
    @Published var csv = CsvState()

    /// 設定のサンプルデータ操作の結果メッセージ（Debug）。
    @Published var sampleSummary: String?

    // MARK: - 付随する状態の型

    /// 追加と編集の両方で使う入力内容。editingID があれば既存の1件を書き換える。
    struct Draft {
        var editingID: UUID?
        var nameKey: String?
        var customName: String?
        var price: Double = 1000
        var cycle: Cycle = .month
        var categoryID: String = SubCategory.otherID
        var paymentMethodID: String = PaymentMethod.unsetID
        var trial = false
        var currency: Currency = .JPY
        var nextRenewal: Date = Date()
        /// 更新日を手で触ったか。触るまではサイクル変更に追従させる。
        var dateTouched = false

        var isEditing: Bool { editingID != nil }
        /// 入力欄に出す名前。未入力なら空（プレースホルダを見せる）。
        var editableName: String { customName ?? nameKey.map(TR) ?? "" }
        /// タイルや要約に出す名前。未入力なら既定名。
        var displayName: String {
            let n = editableName.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? TR("add_manual_name") : n
        }
        var initial: String { String(displayName.prefix(1)) }
    }

    nonisolated struct NotifSettings: Codable, Equatable {
        var before7 = false
        var before3 = true
        var before1 = false
        var beforeSame = true
        var time = "9:00"
        /// 無料トライアル終了を知らせるか。更新前の通知とは独立して切れる。
        var trialEnabled = true
        var trialDays = 3
        var snooze: Snooze = .oneDay
        var lockAmount = true
        var quietNight = true

        init() {}

        /// 項目が増えても、前のバージョンで保存した設定を読めるようにする。
        /// 自動合成のままだと新しいキーが無いだけでデコードに失敗し、
        /// 設定がまるごと既定値に戻ってしまう。
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            before7 = try c.decodeIfPresent(Bool.self, forKey: .before7) ?? false
            before3 = try c.decodeIfPresent(Bool.self, forKey: .before3) ?? true
            before1 = try c.decodeIfPresent(Bool.self, forKey: .before1) ?? false
            beforeSame = try c.decodeIfPresent(Bool.self, forKey: .beforeSame) ?? true
            time = try c.decodeIfPresent(String.self, forKey: .time) ?? "9:00"
            trialEnabled = try c.decodeIfPresent(Bool.self, forKey: .trialEnabled) ?? true
            trialDays = try c.decodeIfPresent(Int.self, forKey: .trialDays) ?? 3
            snooze = try c.decodeIfPresent(Snooze.self, forKey: .snooze) ?? .oneDay
            lockAmount = try c.decodeIfPresent(Bool.self, forKey: .lockAmount) ?? true
            quietNight = try c.decodeIfPresent(Bool.self, forKey: .quietNight) ?? true
        }

        nonisolated enum Snooze: String, Codable, CaseIterable, Identifiable {
            case oneHour, oneDay, dayBefore
            var id: String { rawValue }
            var labelKey: String { "snooze_\(rawValue)" }
        }

        /// 何日前に知らせるか。多い順（早い通知が先）。
        var enabledLeads: [Int] {
            var out: [Int] = []
            if before7 { out.append(7) }
            if before3 { out.append(3) }
            if before1 { out.append(1) }
            if beforeSame { out.append(0) }
            return out
        }

        /// "9:00" を (9, 0) に。壊れていたら 9:00 にする。
        var hourMinute: (hour: Int, minute: Int) {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return (9, 0) }
            return (parts[0], parts[1])
        }
    }

    struct CatEdit {
        var id: String
        var name: String
        var colorHex: UInt
        var isNew: Bool
    }

    struct PayEdit {
        var id: String
        var name: String
        var last4: String
        var colorHex: UInt
        var isNew: Bool
    }

    struct CsvState {
        var open = false
        var done = false
        var range: CsvExporter.Range = .all
        var columns = CsvExporter.Columns()
        /// 書き出したファイルの場所。共有シートに渡す。
        var fileURL: URL?
        /// 書き出しに失敗したときの理由。
        var error: String?
    }

    // MARK: - 初期化

    init(subscriptionRepository: SubscriptionRepositoryProtocol = SubscriptionRepository(),
         categoryRepository: SubCategoryRepositoryProtocol = SubCategoryRepository(),
         paymentRepository: PaymentMethodRepositoryProtocol = PaymentMethodRepository()) {
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.paymentRepository = paymentRepository

        customCategories = categoryRepository.load()
        customPayments = paymentRepository.load()
        hiddenPaymentIDs = paymentRepository.loadHidden()

        let defaults = UserDefaults.standard
        fxMode = FxMode(rawValue: defaults.string(forKey: Self.fxModeKey) ?? "") ?? .daily
        fxRates = ExchangeRateService.loadCached()
        manualRates = Self.loadManualRates(from: defaults)
        if let data = UserDefaults.standard.data(forKey: Self.notifSettingsKey),
           let saved = try? JSONDecoder().decode(NotifSettings.self, from: data) {
            nset = saved
        }
        // 更新日が過ぎているものはサイクル分だけ先送りしてから読み込む。
        let loaded = subscriptionRepository.load()
        let rolled = loaded.map { $0.rolledForward() }
        subscriptions = rolled
        if rolled != loaded { subscriptionRepository.save(rolled) }

        // 登録が1件でもあれば、オンボーディングは飛ばして本編から始める。
        if !subscriptions.isEmpty { screen = .home }

        // iCloud 同期で UserDefaults が合併結果に置き換わったら再読込する。
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRemoteChange),
            name: .iCloudSyncDidApplyRemoteChange, object: nil)

        applyDebugScreenHook()
    }

    @objc private func handleRemoteChange() {
        Task { @MainActor in self.reload() }
    }

    /// ディスク（UserDefaults）から読み直す。同期の合併結果を画面へ反映するのに使う。
    func reload() {
        customCategories = categoryRepository.load()
        customPayments = paymentRepository.load()
        hiddenPaymentIDs = paymentRepository.loadHidden()

        let defaults = UserDefaults.standard
        fxMode = FxMode(rawValue: defaults.string(forKey: Self.fxModeKey) ?? "") ?? .daily
        fxRates = ExchangeRateService.loadCached()
        manualRates = Self.loadManualRates(from: defaults)
        hiddenPaymentIDs = paymentRepository.loadHidden()
        if let data = UserDefaults.standard.data(forKey: Self.notifSettingsKey),
           let saved = try? JSONDecoder().decode(NotifSettings.self, from: data) {
            nset = saved
        }
        subscriptions = subscriptionRepository.load().map { $0.rolledForward() }
    }

    /// 起動時に特定の画面・データ状態から始めるフック（動作確認・スクリーンショット用）。
    private func applyDebugScreenHook() {
        let env = ProcessInfo.processInfo.environment
        // PROTO_SAMPLES=ja|en|none で起動時のデータを差し替える。
        switch env["PROTO_SAMPLES"] {
        case "ja":   deleteAll(); addSamples(.japanese)
        case "en":   deleteAll(); addSamples(.english)
        case "none": deleteAll()
        default:     break
        }
        if !subscriptions.isEmpty, screen == .onboard { screen = .home }

        guard let raw = env["PROTO_SCREEN"] else { return }
        switch raw {
        case "onboard":   screen = .onboard
        case "home":      screen = .home
        case "detail":    screen = .detail; selectedID = subscriptions.first?.id
        case "notifopen": screen = .detail; selectedID = trialItem?.id ?? subscriptions.first?.id; fromNotif = true
        case "cancel":    screen = .cancel
        case "add1":      screen = .add1
        case "add2":      pickManual()
        case "edit":      if let s = subscriptions.first { startEdit(s) }
        case "stats":     screen = .stats
        case "notif":     screen = .notif
        case "notifset":  screen = .notifset
        case "msgs":      screen = .msgs
        case "settings":  screen = .settings
        case "cats":      screen = .cats
        case "catlist":   openCategory(catStats.first?.id ?? SubCategory.otherID)
        case "catlistempty": openCategory("telecom")
        case "pays":      screen = .pays
        case "fx":        screen = .fx
        case "csv":       screen = .settings; csv.open = true
        case "csvdone":   screen = .settings; csv.open = true; csv.done = true
        default: break
        }
    }

    private func persistSubscriptions() {
        subscriptionRepository.save(subscriptions)
        // 登録が変われば予約もずれる。許可済みのときだけ黙って組み直す。
        rescheduleNotifications()
    }

    // MARK: - 通知の予約

    /// 通知設定を変える唯一の入口。保存し、許可を求めたうえで予約し直す。
    func updateNotifSettings(_ mutate: (inout NotifSettings) -> Void) {
        mutate(&nset)
        if let data = try? JSONEncoder().encode(nset) {
            UserDefaults.standard.set(data, forKey: Self.notifSettingsKey)
        }
        // 設定を触るのは「通知が欲しい」という意思表示なので、ここで許可を求める。
        Task {
            let result = await NotificationScheduler.enable(plans: notificationPlans)
            notifPermissionDenied = (result == .denied)
        }
    }

    /// 許可済みのときだけ予約し直す（起動・復帰・データ変更時）。
    func rescheduleNotifications() {
        Task { await NotificationScheduler.rescheduleIfAuthorized(plans: notificationPlans) }
    }

    /// いま予約すべき通知の一覧。文言は画面のプレビューと同じ組み立てにする。
    var notificationPlans: [NotificationPlan] {
        let cal = Calendar.current
        let now = Date()
        let (hour, minute) = nset.hourMinute
        var out: [NotificationPlan] = []

        for sub in subscriptions {
            // トライアルは「N日前」に加えて当日も出す。N日前の時刻がすでに過ぎていると
            // 一度も知らせないまま課金が始まってしまうため。
            let leads: [Int]
            if sub.isTrial {
                leads = nset.trialEnabled ? Array(Set([nset.trialDays, 0])).sorted(by: >) : []
            } else {
                leads = nset.enabledLeads
            }
            for lead in leads {
                guard let day = cal.date(byAdding: .day, value: -lead, to: sub.nextRenewal),
                      var fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
                else { continue }
                // 夜間（22:00–8:00）は鳴らさず、翌朝8時に寄せる。
                if nset.quietNight {
                    let h = cal.component(.hour, from: fire)
                    if h >= 22 || h < 8 {
                        let base = h >= 22 ? cal.date(byAdding: .day, value: 1, to: fire) ?? fire : fire
                        fire = cal.date(bySettingHour: 8, minute: 0, second: 0, of: base) ?? fire
                    }
                }
                guard fire > now else { continue }
                out.append(NotificationPlan(
                    id: "\(sub.id.uuidString).\(lead)",
                    fireDate: fire,
                    title: notifTitle(sub, lead: lead),
                    body: notifBody(sub, lead: lead),
                    isTrial: sub.isTrial,
                    subscriptionID: sub.id,
                    lead: lead))
            }
        }
        return out
    }

    private func notifTitle(_ sub: Subscription, lead: Int) -> String {
        if sub.isTrial {
            // 当日に「0日後に終わります」と出さない。
            return lead == 0
                ? TRF("msg_trial_today_format", sub.name)
                : TRF("msg_trial_title_format", sub.name, lead)
        }
        if lead == 0 { return TRF("msg_today_title_format", sub.name) }
        return TRF("msg_renewal_title_format", sub.name, lead)
    }

    private func notifBody(_ sub: Subscription, lead: Int) -> String {
        // ロック画面に金額を出さない設定なら、日付だけの文面にする。
        guard nset.lockAmount else { return TR("notif_body_generic") }
        let date = DateText.short(sub.nextRenewal)
        if sub.isTrial {
            return TRF("msg_trial_body_format", date,
                       TRF("per_month_amount_format", Yen.text(monthly(sub))))
        }
        if lead == 0 {
            return TRF("msg_today_body_format", Yen.text(billingYen(sub)),
                       payment(sub.paymentMethodID).label)
        }
        return TRF("msg_renewal_body_format", date, Yen.text(billingYen(sub)))
    }

    // MARK: - 導出：サブスク一覧

    /// 登録されている全件。
    var all: [Subscription] { subscriptions }

    /// 課金中のもの（無料トライアル中は合計に入れない）。
    var live: [Subscription] { subscriptions.filter { !$0.isTrial } }

    var isEmpty: Bool { subscriptions.isEmpty }
    var unusedItems: [Subscription] { subscriptions.filter(\.isUnused) }
    var trialItem: Subscription? { subscriptions.first(where: \.isTrial) }

    /// 月額換算（現在の為替レートを適用）。
    func monthly(_ sub: Subscription) -> Double { billingYen(sub) * sub.cycle.monthlyFactor }
    /// 請求単位の金額を円で。
    func billingYen(_ sub: Subscription) -> Double { sub.price * rate(for: sub.currency) }

    var totalMonthly: Double { live.reduce(0) { $0 + monthly($1) } }
    var totalYearly: Double { totalMonthly * 12 }
    var totalPerDay: Double { totalYearly / 365 }

    var sortedItems: [Subscription] {
        subscriptions.sorted {
            sortHigh ? monthly($0) > monthly($1) : $0.daysLeft() < $1.daysLeft()
        }
    }

    func sub(_ id: UUID?) -> Subscription? { id.flatMap { i in subscriptions.first { $0.id == i } } }
    /// 詳細・解約で対象にしている1件。未選択なら先頭。
    var selected: Subscription? { sub(selectedID) ?? subscriptions.first }

    /// 「¥5,900 / 年」「$20 / 月」「毎月」。
    func rawLabel(_ sub: Subscription) -> String {
        if sub.cycle == .year {
            return TRF("raw_yearly_format", Yen.text(billingYen(sub)))
        }
        if sub.currency != .JPY {
            return TRF("raw_monthly_format", sub.currency.symbol + Yen.num(sub.price))
        }
        return TR("raw_monthly_plain")
    }

    /// 詳細の「価格の記録」。
    func historyText(_ sub: Subscription) -> String {
        if sub.isTrial { return TR("hist_trial") }
        if let c = sub.priceChange {
            let sym = c.currency.symbol
            return "\(DateText.yearMonth(c.date))  \(sym)\(Yen.num(c.from)) → \(sym)\(Yen.num(c.to))"
        }
        if sub.currency != .JPY {
            return TRF("hist_fx_format", sub.currency.symbol + Yen.num(sub.price),
                       sub.currency.symbol,
                       String(format: "%.1f", rate(for: sub.currency)))
        }
        return TR("hist_unchanged")
    }

    // MARK: - 導出：カテゴリ

    /// 組み込み ＋ ユーザー追加。組み込みを編集したときは同じ ID のカスタムで「置き換える」。
    /// 単純に連結すると、編集した組み込みが二重に並んでしまう。
    var categories: [SubCategory] {
        Self.merged(builtIns: SubCategory.builtIns, custom: customCategories, hidden: [])
    }

    /// 組み込みとユーザー定義を ID で突き合わせて1本の並びにする。
    /// 組み込みの位置は保ったまま中身だけ差し替え、独自に足したものを後ろに置く。
    private static func merged<T: Identifiable>(builtIns: [T], custom: [T],
                                                hidden: Set<String>) -> [T] where T.ID == String {
        var overrides: [String: T] = [:]
        for item in custom { overrides[item.id] = item }
        let builtInIDs = Set(builtIns.map(\.id))

        var out = builtIns
            .filter { !hidden.contains($0.id) }
            .map { overrides[$0.id] ?? $0 }
        out += custom.filter { !builtInIDs.contains($0.id) }
        return out
    }

    func category(_ id: String) -> SubCategory {
        categories.first { $0.id == id } ?? .other
    }

    /// 一覧行の 2 行目（「動画 ・ 毎月」）。
    func meta(for sub: Subscription) -> String {
        let cycleText = sub.cycle == .year && sub.currency == .JPY
            ? rawLabel(sub)
            : (sub.cycle == .year ? TR("raw_yearly_split") : rawLabel(sub))
        return category(sub.categoryID).name + Sep.mid + cycleText
    }

    // MARK: - 導出：月とヒーロー数値

    /// 今月に実際に請求が発生する合計（年払いは今月に更新日が来るときだけ入る）。
    /// 過去の月は出さない ── 請求の履歴を持っていないので、いま登録されている内容で
    /// 遡って計算した数字しか出せず、実績のように見えて実績ではないため。
    var billedThisMonth: Double {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: Date()) else { return 0 }
        return subscriptions.reduce(0) { sum, s in
            sum + Double(s.renewalCount(in: interval)) * billingYen(s)
        }
    }
    var annualItems: [Subscription] { subscriptions.filter { $0.cycle == .year } }

    struct Hero {
        var label: String
        var value: Double
        var subA: String
        var subB: String
        var animates: Bool
    }

    var hero: Hero {
        switch heroMetric {
        case .year:
            return Hero(label: TR("hero_year"), value: totalYearly,
                        subA: TRF("hero_sub_split", Yen.text(totalMonthly)),
                        subB: TRF("hero_sub_day", Yen.text(totalPerDay)),
                        animates: true)
        case .day:
            return Hero(label: TR("hero_day"), value: totalPerDay,
                        subA: TRF("hero_sub_split", Yen.text(totalMonthly)),
                        subB: TRF("hero_sub_year", Yen.text(totalYearly)),
                        animates: true)
        case .month:
            return Hero(label: TR("hero_this_month"), value: billedThisMonth,
                        subA: TRF("hero_sub_split_if", Yen.text(totalMonthly)),
                        subB: TRF("hero_sub_year", Yen.text(totalYearly)),
                        animates: true)
        }
    }

    /// 集計のヒーロー。選んでいる単位を大きく出し、残りの2つを下に並べる。
    var statsHero: Hero {
        switch statsMetric {
        case .year:
            return Hero(label: TR("hero_year"), value: totalYearly,
                        subA: TRF("hero_sub_split", Yen.text(totalMonthly)),
                        subB: TRF("hero_sub_day", Yen.text(totalPerDay)),
                        animates: true)
        case .month:
            return Hero(label: TR("stats_hero_month"), value: totalMonthly,
                        subA: TRF("hero_sub_year", Yen.text(totalYearly)),
                        subB: TRF("hero_sub_day", Yen.text(totalPerDay)),
                        animates: true)
        case .day:
            return Hero(label: TR("hero_day"), value: totalPerDay,
                        subA: TRF("hero_sub_split", Yen.text(totalMonthly)),
                        subB: TRF("hero_sub_year", Yen.text(totalYearly)),
                        animates: true)
        }
    }

    /// 「年払い 2件（月割り ¥867）は今月の請求に入りません」
    var billedNote: String? {
        let annual = annualItems
        guard !annual.isEmpty else { return nil }
        let split = annual.reduce(0) { $0 + monthly($1) }
        return TRF("home_annual_note_format", annual.count, Yen.text(split))
    }

    // MARK: - 導出：解約シミュレーション

    var cancelTargetIDs: [UUID] {
        if let one = cancelOne { return [one] }
        return unusedItems.map(\.id)
    }
    var cancelCandidates: [Subscription] { subscriptions.filter { cancelTargetIDs.contains($0.id) } }
    var cancelMonthly: Double {
        cancelCandidates.filter { !cancelOff.contains($0.id) }.reduce(0) { $0 + monthly($1) }
    }
    var cancelWho: String {
        if cancelOne != nil { return selected?.name ?? "" }
        return TRF("cancel_unused_count_format", unusedItems.count)
    }

    // MARK: - 導出：追加画面

    /// 候補一覧。未入力なら「よく使われている」順の先頭、入力中は名前と読みで絞り込む。
    var suggestions: [SeedService] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return AppContent.popular }
        let hit = AppContent.catalog.filter {
            $0.name.lowercased().contains(q) || $0.reading.lowercased().contains(q)
        }
        // カタログが大きいので、絞り込み後は多めに見せる（スクロールで追える範囲）。
        return Array(hit.prefix(25))
    }

    /// 入力中の通貨の実効レート。取得済みなら取得値、無ければ既定値。
    var draftRate: Double { rate(for: draft.currency) }

    /// 1通貨あたりの円。手で決めた値があればそれ、無ければ取得値、それも無ければ既定値。
    func rate(for currency: Currency) -> Double {
        guard currency != .JPY else { return 1 }
        return manualRates[currency.rawValue]
            ?? fxRates?.rate(for: currency)
            ?? currency.defaultRate
    }

    /// 1 USD あたりの円。設定画面の要約など、USD だけを見たいところで使う。
    var fxRate: Double { rate(for: .USD) }

    /// 為替画面で扱う通貨。外貨で登録があるものだけ出し、無ければ USD を既定で見せる。
    var fxCurrencies: [Currency] {
        let used = Set(subscriptions.map(\.currency)).subtracting([.JPY])
        guard !used.isEmpty else { return [.USD] }
        return Currency.allCases.filter { used.contains($0) }
    }

    /// いま調整している通貨。登録から消えていたら先頭に寄せる。
    var fxCurrent: Currency {
        fxCurrencies.contains(fxSelected) ? fxSelected : (fxCurrencies.first ?? .USD)
    }
    /// 入力額を円に直したもの（請求単位のまま）。
    var draftYen: Double {
        draft.currency == .JPY ? draft.price : draft.price * draftRate
    }
    /// 月額換算。
    var draftMonthly: Double { draftYen * draft.cycle.monthlyFactor }

    // MARK: - 導出：集計

    struct CatStat: Identifiable {
        let id: String
        let name: String
        let color: Color
        let yen: Double
        let ratio: Double
    }

    var catStats: [CatStat] {
        var sums: [String: Double] = [:]
        for s in live { sums[s.categoryID, default: 0] += monthly(s) }
        let total = max(totalMonthly, 1)
        return sums.keys
            .sorted { (sums[$0] ?? 0) > (sums[$1] ?? 0) }
            .map { id in
                let c = category(id)
                return CatStat(id: id, name: c.name, color: c.color,
                               yen: sums[id] ?? 0, ratio: (sums[id] ?? 0) / total)
            }
    }

    var ranking: [Subscription] { Array(live.sorted { monthly($0) > monthly($1) }.prefix(5)) }
    var rankingMax: Double { max(live.map { monthly($0) }.max() ?? 1, 1) }

    struct PayStat: Identifiable {
        let method: PaymentMethod
        let count: Int
        let yen: Double
        let ratio: Double
        var id: String { method.id }
    }

    /// 支払い方法別の内訳。使われていないものは出さない。
    var payStats: [PayStat] {
        let total = max(totalMonthly, 1)
        return paymentMethods.compactMap { method in
            let inP = live.filter { $0.paymentMethodID == method.id }
            guard !inP.isEmpty else { return nil }
            let sum = inP.reduce(0) { $0 + monthly($1) }
            return PayStat(method: method, count: inP.count, yen: sum, ratio: sum / total)
        }
    }

    // MARK: - 導出：支払い方法

    /// 組み込み ＋ ユーザー追加。「未設定」は選択肢として最後に置く。
    var paymentMethods: [PaymentMethod] {
        // 「未設定」は消せない受け皿なので、常に末尾に置く。
        let builtIns = PaymentMethod.builtIns.filter { $0.id != PaymentMethod.unsetID }
        let list = Self.merged(builtIns: builtIns, custom: customPayments, hidden: hiddenPaymentIDs)
        let unset = customPayments.first { $0.id == PaymentMethod.unsetID } ?? .unset
        return list.filter { $0.id != PaymentMethod.unsetID } + [unset]
    }

    func payment(_ id: String) -> PaymentMethod {
        paymentMethods.first { $0.id == id } ?? .unset
    }

    // MARK: - 導出：カテゴリ一覧（集計からドリルダウン）

    /// 表示中のカテゴリ。未指定なら金額のいちばん大きいカテゴリ。
    var catListCategory: SubCategory {
        category(catListID ?? catStats.first?.id ?? SubCategory.otherID)
    }

    /// そのカテゴリの全件（無料トライアル中も含む）。金額の大きい順。
    var catListItems: [Subscription] {
        subscriptions
            .filter { $0.categoryID == catListCategory.id }
            .sorted { monthly($0) > monthly($1) }
    }

    /// そのカテゴリの月額合計（無料トライアル中は入れない）。
    var catListMonthly: Double {
        catListItems.filter { !$0.isTrial }.reduce(0) { $0 + monthly($1) }
    }

    /// 全体に占める割合。
    var catListShare: Double {
        totalMonthly > 0 ? catListMonthly / totalMonthly : 0
    }

    /// 一覧の各行に敷く帯の割合（0〜1）。合計が 0 のときは細く出す。
    func catListBar(_ sub: Subscription) -> Double {
        guard catListMonthly > 0 else { return 0.03 }
        return min(1, max(0.03, monthly(sub) / catListMonthly))
    }

    /// これからの予定（更新が近い順に5件）。
    var timeline: [Subscription] {
        Array(subscriptions.sorted { $0.daysLeft() < $1.daysLeft() }.prefix(5))
    }

    var fxItems: [Subscription] { subscriptions.filter { $0.currency != .JPY } }

    // MARK: - 導出：通知の文面

    /// 「実際に届く文面」を登録内容から組み立てる。
    /// ここに並べるのは実際に予約する種類だけ。予約しないものを「届く文面」として見せない。
    /// 材料になる登録が無い種類は出さないので、件数は 0〜3 で変わる。
    /// 「届く通知（プレビュー）」。実際に予約する予定そのものから作る。
    /// 別々に組み立てると、日数や金額の伏せ方が実物とずれて
    /// 「こう届きます」と見せた文面が届かない、ということが起きる。
    var notifPreviews: [NotifPreview] {
        var out: [NotifPreview] = []
        var seen: Set<NotifPreview.Kind> = []

        for plan in notificationPlans.sorted(by: { $0.fireDate < $1.fireDate }) {
            let kind: NotifPreview.Kind = plan.isTrial ? .trial
                                        : (plan.lead == 0 ? .today : .renewal)
            // 種類ごとに、いちばん早く届くものを1件だけ。
            guard !seen.contains(kind) else { continue }
            seen.insert(kind)
            out.append(NotifPreview(
                kind: kind,
                title: plan.title,
                body: plan.body,
                action: kind == .today ? TR("msg_today_act")
                                       : TRF("msg_action_snooze_format", TR(nset.snooze.labelKey)),
                subscriptionID: plan.subscriptionID))
        }

        // 並びは種類の定義順（更新前 → トライアル → 当日）に揃える。
        return NotifPreview.Kind.allCases.compactMap { kind in
            out.first { $0.kind == kind }
        }
    }

    // MARK: - 導出：通知設定

    /// 設定画面の「通知」行に出す要約。
    /// 更新前をすべて切ってもトライアルは別に鳴るので、notifSummary をそのまま使うと
    /// 「オフ」と書いてあるのに通知が届く、という食い違いになる。
    var notifSettingsSummary: String {
        if !nset.enabledLeads.isEmpty { return notifSummary }
        return nset.trialEnabled ? TR("notif_trial_only") : TR("notif_off")
    }

    /// 「更新の◯日前に通知」の値。トライアルは別枠なのでここには含めない。
    var notifSummary: String {
        var parts: [String] = []
        if nset.before7 { parts.append(TR("before_7")) }
        if nset.before3 { parts.append(TR("before_3")) }
        if nset.before1 { parts.append(TR("before_1")) }
        if nset.beforeSame { parts.append(TR("before_0")) }
        return parts.isEmpty ? TR("notif_off")
            : parts.joined(separator: Sep.mid.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - 導出：CSV

    /// 期間チップの表示名。「今年」は実際の年を入れる。
    func csvRangeLabel(_ range: CsvExporter.Range) -> String {
        guard range == .thisYear else { return TR(range.labelKey) }
        return TRF("csv_range_thisYear_format", Calendar.current.component(.year, from: Date()))
    }


    /// 選んだ期間に入る登録。次回更新日で絞る。
    var csvTargets: [Subscription] {
        subscriptions.filter { csv.range.contains($0.nextRenewal) }
    }

    private func csvRow(_ sub: Subscription) -> CsvExporter.Row {
        // 桁区切りは入れない。"1,590" だと表計算が数値として読めない。
        CsvExporter.Row(name: sub.name,
                        price: String(Int(billingYen(sub).rounded())),
                        nextRenewal: sub.nextRenewal,
                        category: category(sub.categoryID).name,
                        payment: payment(sub.paymentMethodID).label)
    }

    var csvRowsLabel: String { TRF("csv_rows_format", csvTargets.count, csv.columns.count) }
    var csvFileName: String { "submemo-\(csv.range.fileToken()).csv" }
    var csvHeaderLine: String { CsvExporter.header(csv.columns).joined(separator: ",") }

    /// 先頭1件を使ったプレビュー行。対象が無いときは代わりに「—」。
    var csvSampleLine: String {
        guard let first = csvTargets.first else { return "—" }
        return CsvExporter.fields(of: csvRow(first), columns: csv.columns).joined(separator: ",")
    }

    /// 実際にファイルへ書き出す。結果は csv.fileURL / csv.error に入る。
    func runCsvExport() {
        do {
            let url = try CsvExporter.write(rows: csvTargets.map(csvRow),
                                            columns: csv.columns,
                                            fileName: csvFileName)
            csv.fileURL = url
            csv.error = nil
        } catch {
            csv.fileURL = nil
            csv.error = TR("csv_error")
        }
        csv.done = true
    }

    func closeCsv() {
        // 書き出した一時ファイルは残さない。
        if let url = csv.fileURL { try? FileManager.default.removeItem(at: url) }
        csv = CsvState()
    }

    // MARK: - 画面遷移
    //
    // 戻り先を各画面に書くと「設定 → 通知の設定 → 戻る」で通知タブに出る、といった矛盾が起きる。
    // どこから来たかを履歴に積み、戻るは必ず「直前の画面」へ返す。
    // タブの切り替えは階層の入れ替えなので履歴を捨てる（タブ間を戻り続けないため）。

    /// 押した画面の履歴。末尾が直前の画面。
    @Published private(set) var history: [Screen] = []

    /// 下層へ進む。
    func go(_ s: Screen) {
        openSwipeID = nil
        guard s != screen else { return }
        history.append(screen)
        screen = s
    }

    /// タブを切り替える。履歴はここで断ち切る。
    func goTab(_ s: Screen) {
        openSwipeID = nil
        history = []
        screen = s
    }

    /// 直前の画面へ戻る。履歴が無ければホームへ。
    func back() {
        openSwipeID = nil
        screen = history.popLast() ?? .home
    }

    /// 戻るボタンに出す文言。戻り先の画面名を出すので、行き先とラベルが必ず一致する。
    var backTitleKey: String {
        Self.title(of: history.last ?? .home)
    }

    /// 戻るボタンを出す画面か（タブ直下は出さない）。
    var canGoBack: Bool { !history.isEmpty }

    private static func title(of screen: Screen) -> String {
        switch screen {
        case .home, .onboard:      return "tab_home"
        case .stats, .catlist:     return "tab_stats"
        case .notif:               return "tab_notif"
        case .settings:            return "tab_settings"
        case .detail:              return "nav_detail"
        case .cancel:              return "nav_cancel"
        case .add1, .form:         return "add_title"
        case .msgs:                return "msgs_title"
        case .notifset:            return "notifset_title"
        case .pays:                return "pays_title"
        case .fx:                  return "fx_title"
        case .cats:                return "cats_title"
        }
    }

    func onboardNext() {
        if obIndex < AppContent.onboarding.count - 1 { obIndex += 1 } else { goTab(.home) }
    }

    func open(_ sub: Subscription, fromNotification: Bool = false) {
        selectedID = sub.id
        fromNotif = fromNotification
        go(.detail)
    }

    /// 追加を始める。カテゴリ一覧から来たときは、そのカテゴリを引き継ぐ。
    func startAdd(categoryID: String? = nil) {
        query = ""
        draft = Draft()
        pendingCategoryID = categoryID
        dismissDuplicateNotice()
        go(.add1)
    }

    /// 集計からカテゴリの内訳へ。
    func openCategory(_ id: String) {
        catListID = id
        go(.catlist)
    }

    func startCancel(one: UUID?) {
        cancelOne = one
        cancelOff = []
        go(.cancel)
    }

    func toggleCancelTarget(_ sub: Subscription) {
        if cancelOff.contains(sub.id) { cancelOff.remove(sub.id) } else { cancelOff.insert(sub.id) }
    }

    func cycleHeroMetric() {
        let order = HeroMetric.allCases
        let i = order.firstIndex(of: heroMetric) ?? 0
        heroMetric = order[(i + 1) % order.count]
    }

    // MARK: - 画面ごとのガイド

    /// 済みの記録。0件のときと登録があるときで別々に持つ。
    /// 同じキーにすると、空のうちに一度見ただけで登録後のガイドが出なくなる。
    /// キーに版を入れてあるのは、内容を作り替えたときに前の記録を引き継がないため。
    private static func coachKey(_ screen: Screen, empty: Bool) -> String {
        "submemo.coach.v3.\(screen)" + (empty ? ".empty" : "")
    }

    func isCoachDone(_ screen: Screen, empty: Bool) -> Bool {
        UserDefaults.standard.bool(forKey: Self.coachKey(screen, empty: empty))
    }

    /// その画面をはじめて開いたときにガイドを出す。
    /// 0件のうちに見たかどうかとは別に数えるので、最初の1件を入れたあと
    /// 各画面を回ったときにも、その状態に合った案内が1度ずつ出る。
    func startCoachIfNeeded(for screen: Screen) {
        let empty = isEmpty
        guard coachStep == .none, !isCoachDone(screen, empty: empty) else { return }
        switch (screen, empty) {
        case (.home, true):   coachStep = .homeEmpty
        case (.home, false):  coachStep = .homeMain
        case (.stats, true):  coachStep = .statsEmpty
        case (.stats, false): coachStep = .statsMain
        case (.notif, true):  coachStep = .notifEmpty
        case (.notif, false): coachStep = .notifMain
        default:              break
        }
    }

    /// 読んだら済みにする。
    func finishCoach() {
        UserDefaults.standard.set(true, forKey: Self.coachKey(screen, empty: coachStep.isEmptyGuide))
        coachStep = .none
    }

    /// ガイドの「読んだ」記録を消す。0件のとき用も登録あり用も両方。
    func clearCoachMarks() {
        for screen in Self.tabScreens {
            for empty in [true, false] {
                UserDefaults.standard.removeObject(forKey: Self.coachKey(screen, empty: empty))
            }
        }
        coachStep = .none
    }

    /// ガイドの「読んだ」記録を消して、もう一度出るようにする（Debug）。
    func resetCoachMarks() {
        clearCoachMarks()
        sampleSummary = TR("settings_coach_reset_done")
    }

    /// 年額換算 → 月額換算 → 1日あたり の順に回す。
    func cycleStatsMetric() {
        let order = StatsMetric.allCases
        let i = order.firstIndex(of: statsMetric) ?? 0
        statsMetric = order[(i + 1) % order.count]
    }

    // MARK: - サブスクの CRUD

    /// 「今日からサイクル1つ分あと」。新規登録の次回更新日の既定値。
    static func defaultNextRenewal(for cycle: Cycle, from today: Date = Date()) -> Date {
        let cal = Calendar.current
        let step = cycle.step
        return cal.date(byAdding: step.unit, value: step.value, to: cal.startOfDay(for: today)) ?? today
    }

    /// 名前が一致する既存の登録。大文字小文字と前後の空白は無視する。
    func existing(named name: String) -> Subscription? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        return subscriptions.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == needle
        }
    }

    /// 追加画面に出す「すでに登録されています」の対象。
    /// 家族で別々に契約している場合があるので、追加は禁止せず選ばせる（design 3c）。
    var duplicateNotice: Subscription? {
        pickedDuplicate ?? existing(named: query)
    }

    func dismissDuplicateNotice() {
        pickedDuplicate = nil
        pendingSeed = nil
    }

    func pick(_ seed: SeedService) {
        // すでに同じ名前があるときは、その場で知らせて選んでもらう。
        if let dup = existing(named: seed.name) {
            pickedDuplicate = dup
            pendingSeed = seed
            return
        }
        startForm(with: seed)
    }

    /// 重複を承知で「別プランとして追加」。
    func addAnyway() {
        let seed = pendingSeed
        dismissDuplicateNotice()
        if let seed { startForm(with: seed) } else { pickManual(name: query) }
    }

    private func startForm(with seed: SeedService) {
        // 「◯◯にサブスクを追加」から入ったときは、そのカテゴリを優先する。
        draft = Draft(nameKey: seed.nameKey,
                      customName: seed.nameKey == nil ? seed.literal : nil,
                      price: Double(seed.price),
                      categoryID: pendingCategoryID ?? seed.categoryID,
                      currency: seed.currency,
                      nextRenewal: Self.defaultNextRenewal(for: seed.cycle))
        draft.cycle = seed.cycle
        go(.form)
    }

    func pickManual(name: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        dismissDuplicateNotice()
        draft = Draft(customName: trimmed.isEmpty ? nil : trimmed,
                      categoryID: pendingCategoryID ?? SubCategory.otherID,
                      nextRenewal: Self.defaultNextRenewal(for: .month))
        go(.form)
    }

    /// 既存の1件を編集する。
    func startEdit(_ sub: Subscription) {
        selectedID = sub.id
        draft = Draft(editingID: sub.id,
                      nameKey: sub.nameKey,
                      customName: sub.customName,
                      price: sub.price,
                      cycle: sub.cycle,
                      categoryID: sub.categoryID,
                      paymentMethodID: sub.paymentMethodID,
                      trial: sub.isTrial,
                      currency: sub.currency,
                      nextRenewal: sub.nextRenewal,
                      dateTouched: true)
        go(.form)
    }

    func stepPrice(_ delta: Int) {
        let step = draft.currency == .JPY ? 100.0 : 1.0
        draft.price = max(0, draft.price + Double(delta) * step)
    }

    func selectCurrency(_ c: Currency) {
        guard draft.currency != c else { return }
        draft.currency = c
        // 通貨を変えたら金額の桁が変わるので、編集中でなければ既定額に戻す。
        if !draft.isEditing { draft.price = c == .JPY ? 1000 : 20 }
    }

    func selectCycle(_ c: Cycle) {
        draft.cycle = c
        // まだ更新日を触っていなければ、新しいサイクルに合わせて引き直す。
        if !draft.dateTouched { draft.nextRenewal = Self.defaultNextRenewal(for: c) }
    }

    /// 入力中の内容を保存する。編集中なら書き換え、そうでなければ追加する。
    func saveDraft() {
        let name = draft.editableName.trimmingCharacters(in: .whitespaces)
        // 候補から選んだ名前をそのまま使うときだけ nameKey を残す（翻訳を効かせるため）。
        let keepsKey = draft.nameKey != nil && name == draft.nameKey.map(TR)
        let nameKey = keepsKey ? draft.nameKey : nil
        let customName = keepsKey ? nil : (name.isEmpty ? TR("add_manual_name") : name)

        if let id = draft.editingID, let i = subscriptions.firstIndex(where: { $0.id == id }) {
            let old = subscriptions[i]
            var updated = old
            updated.nameKey = nameKey
            updated.customName = customName
            updated.categoryID = draft.categoryID
            updated.price = draft.price
            updated.currency = draft.currency
            updated.cycle = draft.cycle
            updated.nextRenewal = draft.nextRenewal
            updated.paymentMethodID = draft.paymentMethodID
            updated.isTrial = draft.trial
            updated.updatedAt = Date()
            // 同じ通貨のまま金額が変わったら、値上げ・値下げとして記録に残す。
            if old.currency == draft.currency, old.price != draft.price, old.price > 0 {
                updated.priceChange = PriceChange(date: Date(), from: old.price,
                                                  to: draft.price, currency: draft.currency)
            }
            subscriptions[i] = updated
            persistSubscriptions()
            // 保存は「進む」ではなく「戻る」。来た画面（詳細 or 一覧）へ返す。
            back()
        } else {
            let new = Subscription(
                nameKey: nameKey,
                customName: customName,
                categoryID: draft.categoryID,
                price: draft.price,
                currency: draft.currency,
                cycle: draft.cycle,
                nextRenewal: draft.nextRenewal,
                paymentMethodID: draft.paymentMethodID,
                isTrial: draft.trial
            )
            subscriptions.append(new)
            persistSubscriptions()
            goTab(.home)
        }
    }

    /// フォームを閉じる。戻り先は履歴に任せる。
    func cancelForm() { back() }

    func delete(_ sub: Subscription) {
        subscriptions.removeAll { $0.id == sub.id }
        openSwipeID = nil
        if selectedID == sub.id { selectedID = nil }
        // 記録しないと、他端末との合併で復活する。
        tombstones.record([SyncTombstones.subscriptionKey(sub.id)])
        persistSubscriptions()
    }

    /// 「今日使った」と記録する。使ったばかりなら「使っていない」印は外す。
    func recordUsage(_ sub: Subscription, at date: Date = Date()) {
        guard let i = subscriptions.firstIndex(where: { $0.id == sub.id }) else { return }
        subscriptions[i].lastUsedAt = date
        subscriptions[i].isUnused = false
        subscriptions[i].updatedAt = Date()
        persistSubscriptions()
    }

    /// 「使っていない」欄に添える一行。
    /// 利用記録があれば実際の経過を、無ければ自己申告であることをそのまま書く。
    /// （iOS は他アプリ・他サービスの利用状況を取れないので、勝手に「ひらいていません」とは言えない）
    func unusedNote(_ sub: Subscription) -> String {
        guard let lastUsedAt = sub.lastUsedAt else {
            return TR(sub.isUnused ? "unused_note_marked" : "cancel_note_candidate")
        }
        let months = sub.monthsSinceLastUse() ?? 0
        return months >= 1
            ? TRF("unused_note_since_format", DateText.short(lastUsedAt), months)
            : TRF("unused_note_recent_format", DateText.short(lastUsedAt))
    }

    func toggleUnused(_ sub: Subscription) {
        guard let i = subscriptions.firstIndex(where: { $0.id == sub.id }) else { return }
        subscriptions[i].isUnused.toggle()
        subscriptions[i].updatedAt = Date()
        persistSubscriptions()
    }

    // MARK: - カテゴリの CRUD（カスタムのみ永続化）

    func editCategory(_ c: SubCategory) {
        catEdit = CatEdit(id: c.id, name: c.name, colorHex: c.colorHex, isNew: false)
    }

    func addCategory() {
        catEdit = CatEdit(id: UUID().uuidString, name: "", colorHex: SM.palette[6], isNew: true)
    }

    func saveCategory() {
        guard let e = catEdit else { return }
        let trimmed = e.name.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? TR("cat_new_default") : trimmed

        if e.isNew {
            customCategories.append(SubCategory(id: e.id, customName: name, colorHex: e.colorHex))
        } else if let i = customCategories.firstIndex(where: { $0.id == e.id }) {
            customCategories[i].customName = name
            customCategories[i].nameKey = nil
            customCategories[i].colorHex = e.colorHex
            customCategories[i].updatedAt = Date()
        } else if SubCategory.builtIns.contains(where: { $0.id == e.id }) {
            // 組み込みの編集は、同じ ID のカスタムを重ねて上書きする。
            customCategories.append(SubCategory(id: e.id, customName: name, colorHex: e.colorHex))
        }
        categoryRepository.save(customCategories)
        catEdit = nil
    }

    func deleteCategory() {
        guard let e = catEdit else { return }
        let removed = customCategories.contains { $0.id == e.id }
        customCategories.removeAll { $0.id == e.id }
        if removed { tombstones.record([SyncTombstones.categoryKey(e.id)]) }
        // そのカテゴリのサブスクは消さず「その他」に移す。
        for i in subscriptions.indices where subscriptions[i].categoryID == e.id {
            subscriptions[i].categoryID = SubCategory.otherID
            subscriptions[i].updatedAt = Date()
        }
        categoryRepository.save(customCategories)
        persistSubscriptions()
        catEdit = nil
    }

    /// 組み込みカテゴリと「その他」は消せない。
    var canDeleteEditingCategory: Bool {
        guard let e = catEdit, !e.isNew else { return false }
        return !SubCategory.builtIns.contains { $0.id == e.id }
    }

    // MARK: - 支払い方法の CRUD（カスタムのみ永続化）

    func editPayment(_ method: PaymentMethod) {
        payEdit = PayEdit(id: method.id, name: method.name, last4: method.last4 ?? "",
                          colorHex: method.colorHex, isNew: false)
    }

    func addPayment() {
        payEdit = PayEdit(id: UUID().uuidString, name: "", last4: "",
                          colorHex: SM.palette[6], isNew: true)
    }

    func savePayment() {
        guard let e = payEdit else { return }
        let name = e.name.trimmingCharacters(in: .whitespaces)
        let resolved = name.isEmpty ? TR("pay_new_default") : name
        // 数字4桁だけを預かる。それ以外の入力は落とす。
        let digits = String(e.last4.filter(\.isNumber).suffix(4))

        let updated = PaymentMethod(id: e.id, customName: resolved,
                                    last4: digits.isEmpty ? nil : digits,
                                    colorHex: e.colorHex)
        // 組み込みの編集も同じ ID のカスタムとして持つ。一覧側で置き換わるので重複しない。
        if let i = customPayments.firstIndex(where: { $0.id == e.id }) {
            customPayments[i] = updated
        } else {
            customPayments.append(updated)
        }
        paymentRepository.save(customPayments)
        payEdit = nil
    }

    func deletePayment() {
        guard let e = payEdit, canDeleteEditingPayment else { return }

        if PaymentMethod.builtIns.contains(where: { $0.id == e.id }) {
            // 組み込みはコード側にあるので消せない。非表示の記録として残す。
            hiddenPaymentIDs.insert(e.id)
            paymentRepository.saveHidden(hiddenPaymentIDs)
        }
        if customPayments.contains(where: { $0.id == e.id }) {
            customPayments.removeAll { $0.id == e.id }
            tombstones.record([SyncTombstones.paymentKey(e.id)])
            paymentRepository.save(customPayments)
        }
        // 使用中でも消せる。そのサブスクは消さず「未設定」に移す。
        for i in subscriptions.indices where subscriptions[i].paymentMethodID == e.id {
            subscriptions[i].paymentMethodID = PaymentMethod.unsetID
            subscriptions[i].updatedAt = Date()
        }
        persistSubscriptions()
        payEdit = nil
    }

    /// 受け皿の「未設定」だけは消せない。それ以外は使用中でも消せる。
    var canDeleteEditingPayment: Bool {
        guard let e = payEdit, !e.isNew else { return false }
        return e.id != PaymentMethod.unsetID
    }

    /// 編集中の支払い方法を使っているサブスクの件数。削除の影響を伝えるのに使う。
    var editingPaymentUsageCount: Int {
        guard let e = payEdit else { return 0 }
        return subscriptions.filter { $0.paymentMethodID == e.id }.count
    }

    // MARK: - 為替

    /// 手動でレートを上下する。触った時点で「手動」に切り替える。
    /// 自動のままだと次の取得で上書きされ、直した意味が消えるため。
    /// 表示中の通貨のレートを上下する。触った時点で「手動」に切り替える。
    func stepFxRate(_ delta: Double) {
        let currency = fxCurrent
        let next = ((rate(for: currency) + delta) * 10).rounded() / 10
        manualRates[currency.rawValue] = max(0.1, next)
        if fxMode != .manual {
            fxMode = .manual
            UserDefaults.standard.set(FxMode.manual.rawValue, forKey: Self.fxModeKey)
        }
        persistManualRates()
    }

    func setFxMode(_ mode: FxMode) {
        fxMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.fxModeKey)
        if mode == .manual {
            // いま効いている値をそのまま手動値として固定する。
            // 空のままだと「手動」なのに自動取得の値が使われ続けてしまう。
            for currency in fxCurrencies where manualRates[currency.rawValue] == nil {
                manualRates[currency.rawValue] = rate(for: currency)
            }
            persistManualRates()
        } else {
            // 自動に戻したら手入力値は捨て、すぐ取りに行く。
            manualRates.removeAll()
            persistManualRates()
            Task { await refreshRates(force: true) }
        }
    }

    private func persistManualRates() {
        let defaults = UserDefaults.standard
        if manualRates.isEmpty {
            defaults.removeObject(forKey: Self.fxManualRatesKey)
        } else if let data = try? JSONEncoder().encode(manualRates) {
            defaults.set(data, forKey: Self.fxManualRatesKey)
        }
        // 移行済みなので旧キーは残さない。
        defaults.removeObject(forKey: Self.legacyManualRateKey)
    }

    /// 保存済みの手動レート。旧版（USD ひとつ）で保存されていたら引き継ぐ。
    private static func loadManualRates(from defaults: UserDefaults) -> [String: Double] {
        if let data = defaults.data(forKey: fxManualRatesKey),
           let saved = try? JSONDecoder().decode([String: Double].self, from: data) {
            return saved
        }
        if let legacy = defaults.object(forKey: legacyManualRateKey) as? Double {
            return [Currency.USD.rawValue: legacy]
        }
        return [:]
    }

    /// 取得の間隔。手動のときは自動で取りに行かない。
    private var fxRefreshInterval: TimeInterval? {
        switch fxMode {
        case .daily:  return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .manual: return nil
        }
    }

    /// レートを取りに行く。force でなければ設定した間隔を過ぎたときだけ。
    func refreshRates(force: Bool = false) async {
        guard let interval = fxRefreshInterval else { return }
        if !force, let fetchedAt = fxRates?.fetchedAt,
           Date().timeIntervalSince(fetchedAt) < interval { return }
        guard !fxFetching else { return }

        fxFetching = true
        defer { fxFetching = false }
        do {
            let rates = try await ExchangeRateService.fetch()
            ExchangeRateService.save(rates)
            fxRates = rates
            fxError = nil
        } catch {
            // 取れなかったことは隠さない。直前のレートで動かし続ける。
            fxError = TR("fx_error_unavailable")
        }
    }

    /// 「1 USD あたり ・ 8/9 6:00 更新」。手動で決めた値ならそう言い、未取得ならその旨を出す。
    var fxUpdatedText: String {
        let code = fxCurrent.rawValue
        if manualRates[code] != nil { return TRF("fx_manual_format", code) }
        guard let fetchedAt = fxRates?.fetchedAt else {
            return TRF("fx_never_fetched_format", code)
        }
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return TRF("fx_updated_format", code, f.string(from: fetchedAt))
    }

    // MARK: - サンプルデータ（Debug）

    /// 現在の表示言語に合わせたサンプル言語。
    static var localeSampleLanguage: SampleDataLanguage {
        Locale.current.language.languageCode?.identifier == "ja" ? .japanese : .english
    }

    /// サンプルを投入する。同じ言語で2回押しても増えない（ID が決定的なため）。
    @discardableResult
    func addSamples(_ lang: SampleDataLanguage) -> Int {
        let samples = SampleDataGenerator.generate(language: lang)
        let existing = Set(subscriptions.map(\.id))
        let toAdd = samples.filter { !existing.contains($0.id) }
        guard !toAdd.isEmpty else {
            sampleSummary = TRF("settings_sample_added_summary_format", 0)
            return 0
        }
        subscriptions.append(contentsOf: toAdd)
        persistSubscriptions()
        sampleSummary = TRF("settings_sample_added_summary_format", toAdd.count)
        return toAdd.count
    }

    /// サンプルとして入れたものだけ削除する。
    func removeSamples() {
        let removed = subscriptions.filter(\.isSample)
        guard !removed.isEmpty else { return }
        subscriptions.removeAll(where: \.isSample)
        tombstones.record(removed.map { SyncTombstones.subscriptionKey($0.id) })
        persistSubscriptions()
        sampleSummary = TR("settings_sample_removed_message")
    }

    /// 登録・カスタムカテゴリをすべて消してまっさらに戻す。
    func deleteAll() {
        tombstones.record(subscriptions.map { SyncTombstones.subscriptionKey($0.id) }
                          + customCategories.map { SyncTombstones.categoryKey($0.id) }
                          + customPayments.map { SyncTombstones.paymentKey($0.id) })
        subscriptions.removeAll()
        customCategories.removeAll()
        customPayments.removeAll()
        hiddenPaymentIDs.removeAll()
        selectedID = nil
        persistSubscriptions()
        categoryRepository.save(customCategories)
        paymentRepository.save(customPayments)
        paymentRepository.saveHidden(hiddenPaymentIDs)
        // まっさらに戻す操作なので、ガイドの「読んだ」記録も一緒に消す。
        // ここを残すと、次に1件入れたあとのガイドが出ないまま初期状態を確かめることになる。
        clearCoachMarks()
        sampleSummary = nil
    }
}
