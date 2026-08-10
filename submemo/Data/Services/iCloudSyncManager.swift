//
//  iCloudSyncManager.swift
//  submemo
//
//  UserDefaults の許可リストキー（サブスク・カスタムカテゴリの JSON ブロブ）を
//  NSUbiquitousKeyValueStore にミラーし、iCloud サインイン済みの端末間で同期する。
//
//  ・同期はオプトイン。isEnabled == false の間は何もしない。
//  ・競合ポリシー: ID 単位の合併（SyncMerge）。キーを丸ごと上書きすることはしない。
//    ローカルに1件しか無い端末が iCloud 側の全件を消してしまうのを防ぐため。
//  ・レコードが消えるのは、ユーザが能動的に削除した記録（SyncTombstones）がある場合のみ。
//  ・制限: 合計 1MB / 1024 キー / 値 1MB（Apple 制約）。
//  （shoplist の iCloudSyncManager に準拠）
//

import Combine
import Foundation

nonisolated extension Notification.Name {
    /// ローカルで UserDefaults を書き換えたとき（＝端末側の編集）に post。マネージャが購読して同期する。
    static let submemoLocalDataDidChange = Notification.Name("submemoLocalDataDidChange")
    /// リモートの変更を UserDefaults に適用した後に post。ストアが購読してディスクから再読込する。
    static let iCloudSyncDidApplyRemoteChange = Notification.Name("iCloudSyncDidApplyRemoteChange")
}

@MainActor
final class iCloudSyncManager: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case success
        case failure(String)
    }

    /// iCloud にミラーする UserDefaults キー。各値は Data ブロブ。
    let syncedKeys: [String]

    private static let enabledKey = "icloud_sync.enabled"
    private static let lastSyncedKey = "icloud_sync.last_synced_at"

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled { Task { await self.syncNow() } }
        }
    }

    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var status: Status = .idle

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    init(syncedKeys: [String] = SyncKeys.syncedData) {
        self.syncedKeys = syncedKeys
        let enabled = (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool) ?? false
        self.isEnabled = enabled
        if let date = UserDefaults.standard.object(forKey: Self.lastSyncedKey) as? Date {
            self.lastSyncedAt = date
        }

        // リモートの外部変更を購読 → 合併して両側へ反映。
        NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvs)
            .sink { [weak self] note in self?.handleExternalChange(note) }
            .store(in: &cancellables)

        // ローカル編集を購読 → 合併して iCloud へ反映（有効時のみ）。
        NotificationCenter.default
            .publisher(for: .submemoLocalDataDidChange)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &cancellables)

        kvs.synchronize()
    }

    /// 手動同期（設定画面・フォアグラウンド復帰）。
    func syncNow() async {
        status = .syncing
        guard isEnabled else { status = .failure(TR("icloud_err_off")); return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            status = .failure(TR("icloud_err_unavailable")); return
        }
        reconcile()
        guard kvs.synchronize() else { status = .failure(TR("icloud_err_unavailable")); return }
        stampSynced()
        status = .success
    }

    /// ローカルと iCloud を合併し、両側へ同じ結果を書く。
    ///
    /// 「push（ローカルで上書き）→ pull」にすると、インストール直後に1件作ってから同期したときに
    /// iCloud 上の全データがその1件で置き換わって消える。合併にすることで
    /// 「iCloud 上のデータ ＋ 新しく作ったもの」になり、消えるのはトゥームストーンがある ID だけになる。
    private func reconcile() {
        guard isEnabled else { return }

        // 1) トゥームストーンを先に合併する。データの生死判定に使うので順序が重要。
        //    ここで両端末の削除記録が揃っていないと、消したはずのものが復活する。
        let tombstones = reconcileTombstones()

        // 2) データキーごとに合併し、違っている側にだけ書き戻す。
        var localChanged = false
        for key in syncedKeys {
            guard let outcome = SyncMerge.reconcile(key: key,
                                                    local: defaults.data(forKey: key),
                                                    remote: kvs.data(forKey: key),
                                                    tombstones: tombstones)
            else { continue }
            if outcome.differsFromLocal {
                defaults.set(outcome.data, forKey: key)
                localChanged = true
            }
            if outcome.differsFromRemote {
                kvs.set(outcome.data, forKey: key)
            }
        }
        kvs.synchronize()

        if localChanged {
            // ストアがディスクから再読込する。ここで書き戻しは起こらないので合併ループにはならない。
            NotificationCenter.default.post(name: .iCloudSyncDidApplyRemoteChange, object: nil)
        }
    }

    /// 削除記録を local ∪ remote で合併し、両側へ書く。合併後の記録を返す。
    private func reconcileTombstones() -> SyncTombstones {
        let key = SyncKeys.tombstones
        let decoder = JSONDecoder()
        let local = defaults.data(forKey: key).flatMap { try? decoder.decode(SyncTombstones.self, from: $0) }
        let remote = kvs.data(forKey: key).flatMap { try? decoder.decode(SyncTombstones.self, from: $0) }
        guard local != nil || remote != nil else { return SyncTombstones() }

        let merged = SyncTombstones
            .merged(local ?? SyncTombstones(), remote ?? SyncTombstones())
            .pruned(now: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(merged) {
            if local != merged { defaults.set(data, forKey: key) }
            if remote != merged { kvs.set(data, forKey: key) }
        }
        return merged
    }

    private func handleExternalChange(_ note: Notification) {
        guard isEnabled else { return }
        let userInfo = note.userInfo ?? [:]
        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? syncedKeys
        // 削除記録の変更も合併のきっかけになる（他端末での削除がここで伝わる）。
        let watched = Set(syncedKeys + [SyncKeys.tombstones])
        guard changedKeys.contains(where: watched.contains) else { return }
        reconcile()
        stampSynced()
    }

    private func stampSynced() {
        let now = Date()
        lastSyncedAt = now
        defaults.set(now, forKey: Self.lastSyncedKey)
    }
}
