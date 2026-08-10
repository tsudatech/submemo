//
//  AppFlags.swift
//  submemo
//
//  ビルド時フラグの名前空間（shoplist / tasks プロジェクトに準拠）。
//

import Foundation

enum AppFlags {
    /// 設定にサンプルデータ機能（日本語／英語の投入・削除、全データ削除）を出すか。
    /// Debug ビルドのみ true。
    static var needSampleData: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
