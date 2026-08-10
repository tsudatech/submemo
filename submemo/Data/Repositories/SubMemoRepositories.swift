//
//  SubMemoRepositories.swift
//  submemo
//
//  UserDefaults に Codable JSON で保存するリポジトリ実装。
//  （shoplist の ShopRepositories と同じ方針。iCloud KVS 同期に載せられるよう、
//   キーごとに 1 つの JSON ブロブとして持つ）
//
//  保存キーは SyncKeys が単一の出所。ここと同期対象がずれると同期漏れになる。
//

import Foundation

/// UserDefaults を書き換えたら iCloud 同期へ push させるための通知。
private func notifyLocalDataChanged() {
    NotificationCenter.default.post(name: .submemoLocalDataDidChange, object: nil)
}

nonisolated protocol SubscriptionRepositoryProtocol {
    func load() -> [Subscription]
    func save(_ subscriptions: [Subscription])
}

nonisolated protocol SubCategoryRepositoryProtocol {
    func load() -> [SubCategory]
    func save(_ categories: [SubCategory])
}

nonisolated final class SubscriptionRepository: SubscriptionRepositoryProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [Subscription] {
        guard let data = defaults.data(forKey: SyncKeys.subscriptions),
              let items = try? JSONDecoder().decode([Subscription].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ subscriptions: [Subscription]) {
        guard let data = try? JSONEncoder().encode(subscriptions) else { return }
        defaults.set(data, forKey: SyncKeys.subscriptions)
        notifyLocalDataChanged()
    }
}

nonisolated final class SubCategoryRepository: SubCategoryRepositoryProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// カスタムカテゴリのみ保存する（組み込みはコード側に持つ）。
    func load() -> [SubCategory] {
        guard let data = defaults.data(forKey: SyncKeys.customCategories),
              let items = try? JSONDecoder().decode([SubCategory].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ categories: [SubCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        defaults.set(data, forKey: SyncKeys.customCategories)
        notifyLocalDataChanged()
    }
}

nonisolated protocol PaymentMethodRepositoryProtocol {
    func load() -> [PaymentMethod]
    func save(_ methods: [PaymentMethod])
    func loadHidden() -> Set<String>
    func saveHidden(_ ids: Set<String>)
}

nonisolated final class PaymentMethodRepository: PaymentMethodRepositoryProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// カスタムの支払い方法のみ保存する（組み込みはコード側に持つ）。
    func load() -> [PaymentMethod] {
        guard let data = defaults.data(forKey: SyncKeys.customPayments),
              let items = try? JSONDecoder().decode([PaymentMethod].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ methods: [PaymentMethod]) {
        guard let data = try? JSONEncoder().encode(methods) else { return }
        defaults.set(data, forKey: SyncKeys.customPayments)
        notifyLocalDataChanged()
    }

    /// 消した組み込みの ID。iCloud 同期でも扱えるよう Data(JSON) で持つ。
    func loadHidden() -> Set<String> {
        guard let data = defaults.data(forKey: SyncKeys.hiddenPayments),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    func saveHidden(_ ids: Set<String>) {
        // 並びを固定して保存する。Set の列挙順は不定で、同期の合併結果と
        // 毎回バイト列がずれて無駄な書き込みが起きるため。
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        defaults.set(data, forKey: SyncKeys.hiddenPayments)
        notifyLocalDataChanged()
    }
}
