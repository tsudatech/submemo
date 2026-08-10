//
//  SyncTombstones.swift
//  submemo
//
//  削除の明示記録（トゥームストーン）。
//
//  iCloud 同期では「そのレコードが手元に無い」理由が2つあり、保存データの中身だけでは区別できない。
//    ・まだ受信していない（インストール直後など）→ 消してはいけない
//    ・ユーザが能動的に削除した → iCloud 側からも消すべき
//  そこで削除を「不在」ではなく「削除した記録」として同期する。合併（SyncMerge）はこの記録を見て
//  レコードを残すか消すかを決める。記録が無い ID は決して消えない。
//  （shoplist の SyncTombstones に準拠）
//

import Foundation

/// UserDefaults / iCloud KVS で共有するストレージキーの単一の出所。
/// こことリポジトリ側の実際の保存先がずれると同期漏れになるので、必ずこの定義を参照する。
nonisolated enum SyncKeys {
    static let subscriptions = "submemo.subscriptions"
    static let customCategories = "submemo.customCategories"
    static let customPayments = "submemo.customPayments"
    static let hiddenPayments = "submemo.hiddenPayments"
    static let tombstones = "submemo.tombstones.v1"

    /// iCloud にミラーするデータキー。トゥームストーンは合併の前提として別に扱う。
    static let syncedData: [String] = [subscriptions, customCategories, customPayments, hiddenPayments]
}

/// 削除されたレコードの ID → 削除時刻。
nonisolated struct SyncTombstones: Codable, Equatable {
    /// 保持期間。KVS の容量制限（合計 1MB）があるため無限には持てない。
    /// これを超えてオフラインだった端末が持つデータは復活しうる（消失より復活を選ぶ）。
    static let retention: TimeInterval = 180 * 24 * 60 * 60

    var deletedAt: [String: Date]

    init(deletedAt: [String: Date] = [:]) { self.deletedAt = deletedAt }

    /// このレコードを削除済みとして扱うか。
    /// 削除より後に他端末で編集された（updatedAt が削除時刻より新しい）場合は復活させる。
    func isDeleted(_ id: String, updatedAt: Date) -> Bool {
        guard let deleted = deletedAt[id] else { return false }
        return deleted >= updatedAt
    }

    /// 2つの記録を合併する。ID ごとに新しい削除時刻を採る。
    /// 可換なのでどの端末で計算しても同じ結果になる（合併が非対称だと端末間で収束しない）。
    static func merged(_ a: SyncTombstones, _ b: SyncTombstones) -> SyncTombstones {
        var out = a.deletedAt
        for (id, date) in b.deletedAt where !(out[id].map { $0 >= date } ?? false) {
            out[id] = date
        }
        return SyncTombstones(deletedAt: out)
    }

    func pruned(now: Date) -> SyncTombstones {
        let cutoff = now.addingTimeInterval(-Self.retention)
        return SyncTombstones(deletedAt: deletedAt.filter { $0.value > cutoff })
    }

    // MARK: - ID の名前空間
    // 種類ごとに接頭辞を付け、サブスクとカテゴリで ID が衝突しないようにする。

    static func subscriptionKey(_ id: UUID) -> String { "sub:\(id.uuidString)" }
    static func categoryKey(_ id: String) -> String { "cat:\(id)" }
    static func paymentKey(_ id: String) -> String { "pay:\(id)" }
}

/// トゥームストーンの永続化。UserDefaults に JSON ブロブで持ち、同期対象に含める。
nonisolated final class TombstoneRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> SyncTombstones {
        guard let data = defaults.data(forKey: SyncKeys.tombstones),
              let tombstones = try? JSONDecoder().decode(SyncTombstones.self, from: data)
        else { return SyncTombstones() }
        return tombstones
    }

    func save(_ tombstones: SyncTombstones) {
        guard let data = try? JSONEncoder().encode(tombstones) else { return }
        defaults.set(data, forKey: SyncKeys.tombstones)
    }

    /// ユーザが能動的に削除したレコードを記録する。
    /// ここに記録された ID だけが iCloud 側からも消える。記録し忘れた削除は他端末から復活する。
    func record(_ ids: [String], at date: Date = Date()) {
        guard !ids.isEmpty else { return }
        var tombstones = load()
        for id in ids { tombstones.deletedAt[id] = date }
        save(tombstones.pruned(now: date))
        NotificationCenter.default.post(name: .submemoLocalDataDidChange, object: nil)
    }
}
