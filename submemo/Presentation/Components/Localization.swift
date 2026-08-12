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

/// 円そのものの表示。為替レートや候補の定価など、
/// 「円建ての事実」をそのまま出すところで使う。表示通貨には従わない。
nonisolated enum Yen {
    /// 記号なしの数字だけ（"1,590"）
    static func num(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number)
    }
    /// 記号つき（"¥1,590"）
    static func text(_ value: Double) -> String { "¥" + num(value) }
}

/// 合計や各サブスクの金額。設定で選んだ表示通貨に直して出す。
///
/// 計算は最後まで円で行い、ここで一度だけ換算する。
/// 途中で通貨を混ぜると、丸めが二重にかかって合計が合わなくなる。
nonisolated enum Money {
    /// 表示通貨と、その 1 単位あたりの円。AppStore が設定を読んで差し込む。
    nonisolated(unsafe) private(set) static var base: DisplayCurrency = .JPY
    nonisolated(unsafe) private(set) static var baseRate: Double = 1

    /// 登録通貨（JPY/USD/EUR）1単位あたりの円。候補の定価を直すのに使う。
    nonisolated(unsafe) private(set) static var yenPer: [String: Double] = [:]

    static func use(_ currency: DisplayCurrency, rate: Double, yenPer: [String: Double]) {
        base = currency
        baseRate = max(rate, 0.000001)   // 0 除算だけ避ける
        self.yenPer = yenPer
    }

    /// 登録通貨で書かれた額を、表示通貨の文字列にする。
    /// 候補の定価のように、円ではない額を渡すところから使う。
    static func from(_ amount: Double, code: String) -> String {
        let yen = code == DisplayCurrency.JPY.rawValue ? amount : amount * (yenPer[code] ?? 1)
        return text(yen)
    }

    /// 記号なしの数字だけ。表示通貨の桁数で丸める。
    static func num(_ yen: Double) -> String {
        let value = base == .JPY ? yen : yen / baseRate
        let digits = base.fractionDigits
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// 記号つき（"¥1,590" / "$10.32"）。
    static func text(_ yen: Double) -> String { base.symbol + num(yen) }
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
