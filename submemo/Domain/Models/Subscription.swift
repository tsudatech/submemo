//
//  Subscription.swift
//  submemo
//
//  サブスクのドメインモデル。UserDefaults に Codable JSON で永続化する。
//  表示に必要な値（月額換算・残日数・請求単位の表記）は保存せず、
//  料金・サイクル・次回更新日から都度計算する。
//

import Foundation

// MARK: - 更新サイクル

nonisolated enum Cycle: String, Codable, CaseIterable, Identifiable {
    case month, year, week, bimonthly

    var id: String { rawValue }

    /// 追加画面のチップ表示（「月ごと」「年ごと」…）
    var chipKey: String { "cycle_chip_\(rawValue)" }

    /// 月額換算の係数（週は 52/12、隔月は 1/2）
    var monthlyFactor: Double {
        switch self {
        case .month:     return 1
        case .year:      return 1.0 / 12.0
        case .week:      return 52.0 / 12.0
        case .bimonthly: return 0.5
        }
    }

    /// 次の更新日を求めるときの加算量。
    var step: (unit: Calendar.Component, value: Int) {
        switch self {
        case .month:     return (.month, 1)
        case .year:      return (.year, 1)
        case .week:      return (.day, 7)
        case .bimonthly: return (.month, 2)
        }
    }
}

// MARK: - 通貨

nonisolated enum Currency: String, Codable, CaseIterable, Identifiable {
    case JPY, USD, EUR

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .JPY: return "¥"
        case .USD: return "$"
        case .EUR: return "€"
        }
    }

    /// 既定レート（円/1通貨単位）。USD は設定画面で上下できる。
    var defaultRate: Double {
        switch self {
        case .JPY: return 1
        case .USD: return 154
        case .EUR: return 168
        }
    }
}

// MARK: - 値上げ・値下げの記録

nonisolated struct PriceChange: Codable, Equatable, Hashable {
    var date: Date
    var from: Double
    var to: Double
    /// 記録時の通貨。外貨建てのまま値上げされた場合に記号を出し分ける。
    var currency: Currency

    init(date: Date, from: Double, to: Double, currency: Currency = .JPY) {
        self.date = date
        self.from = from
        self.to = to
        self.currency = currency
    }

    /// currency を持たない旧データも読めるようにする。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        from = try c.decode(Double.self, forKey: .from)
        to = try c.decode(Double.self, forKey: .to)
        currency = try c.decodeIfPresent(Currency.self, forKey: .currency) ?? .JPY
    }
}

// MARK: - サブスク

nonisolated struct Subscription: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    /// 候補から選んだときのローカライズキー（手入力・サンプルは nil）。
    var nameKey: String?
    /// 手入力した名前。nameKey があるときは nil。
    var customName: String?
    var categoryID: String
    /// 請求単位の金額（月払いなら月額、年払いなら年額）。通貨は currency。
    var price: Double
    var currency: Currency
    var cycle: Cycle
    /// 次回更新日。過去になったら読み込み時にサイクル分だけ先送りする。
    var nextRenewal: Date
    var paymentMethodID: String
    var isTrial: Bool
    /// 「使っていない」印。ユーザーの判断。
    var isUnused: Bool
    /// 最後に使ったと記録した日。
    /// iOS には他アプリ・他サービスの利用状況を知る手段が無いので、自己申告で持つ。
    var lastUsedAt: Date?
    var priceChange: PriceChange?
    var createdAt: Date
    var updatedAt: Date
    /// Debug のサンプルデータとして投入されたもの。まとめて削除できる。
    var isSample: Bool

    init(id: UUID = UUID(),
         nameKey: String? = nil,
         customName: String? = nil,
         categoryID: String,
         price: Double,
         currency: Currency = .JPY,
         cycle: Cycle = .month,
         nextRenewal: Date,
         paymentMethodID: String = PaymentMethod.unsetID,
         isTrial: Bool = false,
         isUnused: Bool = false,
         lastUsedAt: Date? = nil,
         priceChange: PriceChange? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         isSample: Bool = false) {
        self.id = id
        self.nameKey = nameKey
        self.customName = customName
        self.categoryID = categoryID
        self.price = price
        self.currency = currency
        self.cycle = cycle
        self.nextRenewal = nextRenewal
        self.paymentMethodID = paymentMethodID
        self.isTrial = isTrial
        self.isUnused = isUnused
        self.lastUsedAt = lastUsedAt
        self.priceChange = priceChange
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSample = isSample
    }

    /// 旧キー（支払い方法を PayKey enum で直接持っていたころ）。読み込みにだけ使う。
    private enum LegacyKeys: String, CodingKey {
        case paymentMethod
    }

    /// 項目が増えても古い保存データを読めるようにする（欠けていたら既定値）。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        nameKey = try c.decodeIfPresent(String.self, forKey: .nameKey)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        categoryID = try c.decodeIfPresent(String.self, forKey: .categoryID) ?? SubCategory.otherID
        price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
        currency = try c.decodeIfPresent(Currency.self, forKey: .currency) ?? .JPY
        cycle = try c.decodeIfPresent(Cycle.self, forKey: .cycle) ?? .month
        nextRenewal = try c.decodeIfPresent(Date.self, forKey: .nextRenewal) ?? Date()
        // 旧データは PayKey の rawValue が入っている。ID をそのまま引き継いでいるので読める。
        let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
        paymentMethodID = try c.decodeIfPresent(String.self, forKey: .paymentMethodID)
            ?? legacy?.decodeIfPresent(String.self, forKey: .paymentMethod)
            ?? PaymentMethod.unsetID
        isTrial = try c.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
        isUnused = try c.decodeIfPresent(Bool.self, forKey: .isUnused) ?? false
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        priceChange = try c.decodeIfPresent(PriceChange.self, forKey: .priceChange)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
    }

    // MARK: 表示のための導出

    var name: String { customName ?? nameKey.map(TR) ?? "" }
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }

    /// 最後に使ってから何か月経ったか。記録が無ければ nil。
    func monthsSinceLastUse(from now: Date = Date()) -> Int? {
        guard let lastUsedAt else { return nil }
        return Calendar.current.dateComponents([.month], from: lastUsedAt, to: now).month
    }

    /// 次の更新まであと何日か。今日なら 0。
    func daysLeft(from today: Date = Date()) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: today)
        let b = cal.startOfDay(for: nextRenewal)
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    /// 次回更新日が過去になっていたら、サイクル分だけ先送りしたコピーを返す。
    func rolledForward(to today: Date = Date()) -> Subscription {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        guard cal.startOfDay(for: nextRenewal) < start else { return self }
        var copy = self
        let step = cycle.step
        var guardCount = 0
        while cal.startOfDay(for: copy.nextRenewal) < start, guardCount < 1000 {
            guard let next = cal.date(byAdding: step.unit, value: step.value, to: copy.nextRenewal) else { break }
            copy.nextRenewal = next
            guardCount += 1
        }
        return copy
    }

    /// 指定期間に何回請求が発生するか（月の請求額の集計に使う）。
    func renewalCount(in interval: DateInterval) -> Int {
        let cal = Calendar.current
        let step = cycle.step
        var date = nextRenewal

        // いったん期間の開始より前まで戻す。
        var i = 0
        while date >= interval.start, i < 500 {
            guard let prev = cal.date(byAdding: step.unit, value: -step.value, to: date) else { break }
            date = prev
            i += 1
        }
        // そこから前進して、期間に入るものを数える。
        var count = 0
        i = 0
        while i < 500 {
            guard let next = cal.date(byAdding: step.unit, value: step.value, to: date) else { break }
            date = next
            i += 1
            if date >= interval.end { break }
            if date >= interval.start { count += 1 }
        }
        return count
    }
}
