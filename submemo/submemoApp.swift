//
//  submemoApp.swift
//  submemo
//
//  Created by 津田準 on 2026/08/07.
//

import SwiftUI

@main
struct submemoApp: App {
    /// iCloud KVS 同期マネージャ。サブスク・カスタムカテゴリの JSON ブロブを端末間で合併同期する。
    @StateObject private var iCloudSync = iCloudSyncManager(syncedKeys: SyncKeys.syncedData)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(iCloudSync)
                // 外観モード（システム / ライト / ダーク）を設定に応じて適用する。
                .appAppearance()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // 起動・フォアグラウンド復帰時に iCloud と合併同期（有効時のみ）。
            if iCloudSync.isEnabled { Task { await iCloudSync.syncNow() } }
        }
    }
}
