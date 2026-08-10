//
//  ContentView.swift
//  submemo
//
//  ルート。デザインドキュメント 1a「動くプロトタイプ」の画面群を表示する。
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentViewRoot()
    }
}

#Preview {
    ContentView()
        .environmentObject(iCloudSyncManager())
}
