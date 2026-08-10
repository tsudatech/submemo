//
//  SyncMerge.swift
//  submemo
//
//  ローカル（UserDefaults）と iCloud（NSUbiquitousKeyValueStore）の JSON ブロブを「合併」する。
//
//  設計の要点（shoplist の SyncMerge に準拠）:
//  ・キー単位の丸ごと上書きは禁止。インストール直後の端末が1件作っただけで iCloud 側の全件を
//    消してしまうため。ID 単位で足し合わせる。
//  ・レコードが消えるのはトゥームストーン（= ユーザが能動的に削除した記録）がある場合のみ。
//  ・合併は可換・決定的でなければならない。非対称だと端末Aと端末Bが互いの結果を上書きし合って
//    収束しない（ping-pong）。同時刻の衝突は正規化 JSON の大小で機械的に決着させる。
//

import Foundation

nonisolated enum SyncMerge {
    /// 合併結果と、それが元の値と違うか（＝書き戻す必要があるか）。
    struct Outcome {
        let data: Data
        let differsFromLocal: Bool
        let differsFromRemote: Bool
    }

    /// 端末間でバイト列を一致させるためキー順を固定する。
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    /// 同期キー1つ分の local / remote を合併する。どちらにも値が無ければ nil。
    static func reconcile(key: String, local: Data?, remote: Data?, tombstones: SyncTombstones) -> Outcome? {
        switch key {
        case SyncKeys.subscriptions:
            return outcome([Subscription].self, local, remote, empty: []) {
                mergeByID($0, $1,
                          id: { SyncTombstones.subscriptionKey($0.id) },
                          updatedAt: { $0.updatedAt },
                          tombstones: tombstones)
            }

        case SyncKeys.customCategories:
            return outcome([SubCategory].self, local, remote, empty: []) {
                mergeByID($0, $1,
                          id: { SyncTombstones.categoryKey($0.id) },
                          updatedAt: { $0.updatedAt },
                          tombstones: tombstones)
            }

        case SyncKeys.customPayments:
            return outcome([PaymentMethod].self, local, remote, empty: []) {
                mergeByID($0, $1,
                          id: { SyncTombstones.paymentKey($0.id) },
                          updatedAt: { $0.updatedAt },
                          tombstones: tombstones)
            }

        case SyncKeys.hiddenPayments:
            // 消した組み込みの ID。これ自体が「消した記録」なので和集合で足りる。
            return outcome([String].self, local, remote, empty: []) {
                Array(Set($0).union($1)).sorted()
            }

        default:
            // 未知のキーは触らない（合併方法が分からないものを上書きしないため）。
            return nil
        }
    }

    // MARK: - 型ごとの入口

    private static func outcome<T: Codable & Equatable>(
        _ type: T.Type, _ local: Data?, _ remote: Data?, empty: T, _ merge: (T, T) -> T
    ) -> Outcome? {
        // 復号できないブロブは「無い」扱い。片側が壊れていても、もう片側を残す方が安全。
        let localValue = local.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        let remoteValue = remote.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        guard localValue != nil || remoteValue != nil else { return nil }

        let merged = merge(localValue ?? empty, remoteValue ?? empty)
        guard let data = try? encoder.encode(merged) else { return nil }
        // バイト列ではなく値で比較する。整形の違いだけで書き込みが発生するのを避けるため。
        return Outcome(data: data,
                       differsFromLocal: localValue != merged,
                       differsFromRemote: remoteValue != merged)
    }

    // MARK: - 汎用の ID 単位合併

    /// ID 単位で足し合わせる。ローカルの並び順を保ち、リモートにしか無いものを後ろに足す。
    /// （並び順を作り直すと内容が同じでも「変わった」と判定され、無駄な書き込みが続く）
    private static func mergeByID<T: Codable>(
        _ local: [T], _ remote: [T],
        id: (T) -> String, updatedAt: (T) -> Date, tombstones: SyncTombstones
    ) -> [T] {
        var remoteByID: [String: T] = [:]
        for element in remote { remoteByID[id(element)] = element }
        let localIDs = Set(local.map(id))

        var out: [T] = []
        var seen = Set<String>()

        func keep(_ candidate: T?) {
            guard let winner = candidate else { return }
            let key = id(winner)
            guard seen.insert(key).inserted else { return }
            guard !tombstones.isDeleted(key, updatedAt: updatedAt(winner)) else { return }
            out.append(winner)
        }

        for element in local { keep(pickNewer(element, remoteByID[id(element)], updatedAt: updatedAt)) }
        for element in remote where !localIDs.contains(id(element)) { keep(element) }
        return out
    }

    // MARK: - 衝突の決着

    /// 更新時刻が新しい方を採る。片側しか無ければそれを採る。
    /// 同時刻なら正規化 JSON の大小で決める ── 恣意的だが決定的なので、どの端末で計算しても
    /// 同じ結果になり、互いを上書きし続けることがない。
    private static func pickNewer<T: Encodable>(_ a: T?, _ b: T?, updatedAt: (T) -> Date) -> T? {
        guard let a else { return b }
        guard let b else { return a }
        let dateA = updatedAt(a), dateB = updatedAt(b)
        if dateA != dateB { return dateA > dateB ? a : b }
        return canonical(a) >= canonical(b) ? a : b
    }

    private static func canonical<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
