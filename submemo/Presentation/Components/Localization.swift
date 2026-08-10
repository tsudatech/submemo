//
//  Localization.swift
//  submemo
//
//  ローカライズの小さなヘルパー（shoplist の .lproj + Localizable.strings 方式に準拠）
//

import SwiftUI

/// NSLocalizedString の短縮。合成文字列や String(format:) の材料に使う。
nonisolated func TR(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// String(format:) の短縮。
nonisolated func TRF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

extension String {
    /// 文字列キーを LocalizedStringKey へ。
    /// - キーを渡した場合（`Text("home_title".loc)`）→ 翻訳される
    /// - 既に翻訳済みの文字列を渡した場合 → キーが見つからず、その文字列がそのまま表示される
    var loc: LocalizedStringKey { LocalizedStringKey(self) }
}

/// 金額表示。
/// このプロトタイプの基準通貨は日本円なので、ja / en とも ¥ で表示し、
/// 桁区切りだけを現在ロケールに合わせる（外貨は Currency.symbol を使う）。
enum Yen {
    /// 記号なしの数字だけ（"1,590"）
    static func num(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number)
    }
    /// 記号つき（"¥1,590"）
    static func text(_ value: Double) -> String { "¥" + num(value) }
}

/// 語をつなぐ区切り（ja「 ・ 」/ en「 · 」）。
enum Sep {
    static var mid: String { TR("list_joiner") }
}

/// プロトタイプ内の日付表示。すべて現在ロケールの書式に従う。
enum DateText {
    /// 一覧向けの短い表記。今年以外は年も添える。
    static func short(_ date: Date) -> String {
        let cal = Calendar.current
        return cal.component(.year, from: date) == cal.component(.year, from: Date())
            ? date.formatted(.dateTime.month(.defaultDigits).day())
            : date.formatted(.dateTime.year().month(.defaultDigits).day())
    }
    /// 「8月」「Aug」相当。
    static func monthShort(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated))
    }
    /// 「2026年8月」「Aug 2026」相当。
    static func yearMonth(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.abbreviated))
    }
    /// 日にちの数字だけ（タイムラインの左肩）。
    static func dayNumber(_ date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }
    /// CSV に書き出す ISO 形式（ロケール非依存。端末のカレンダー日付をそのまま使う）。
    static func iso(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
