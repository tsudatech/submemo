//
//  DisplayCurrency.swift
//  submemo
//
//  合計を出すときの通貨（表示通貨）。
//
//  各サブスクを登録するときの通貨（Currency）とは別物。
//  内部の計算はすべて円で行い、画面に出す直前にここで選んだ通貨へ直す。
//

import Foundation

nonisolated enum DisplayCurrency: String, CaseIterable, Identifiable, Codable {
    case JPY, USD, EUR, GBP, KRW, TWD, AUD, SGD

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .JPY: return "¥"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .KRW: return "₩"
        case .TWD: return "NT$"
        case .AUD: return "A$"
        case .SGD: return "S$"
        }
    }

    var nameKey: String { "cur_name_\(rawValue)" }

    /// 小数を出す桁数。円・ウォン・台湾ドルは日常的に整数で扱う。
    var fractionDigits: Int {
        switch self {
        case .JPY, .KRW, .TWD: return 0
        default:               return 2
        }
    }

    /// 1通貨あたりの円。取得できるまで、また取得できない通貨で使う。
    var defaultRate: Double {
        switch self {
        case .JPY: return 1
        case .USD: return 154
        case .EUR: return 168
        case .GBP: return 196.4
        case .KRW: return 0.11
        case .TWD: return 4.8
        case .AUD: return 100.2
        case .SGD: return 114.7
        }
    }

    /// 為替レートを自動で取れるか。
    /// 台湾ドルは欧州中央銀行が公表していないので、既定値と手入力で使う。
    var isAutoFetchable: Bool { self != .TWD }

    /// 自動取得の対象（円は基準なので含めない）。
    static var fetchTargets: [DisplayCurrency] {
        allCases.filter { $0 != .JPY && $0.isAutoFetchable }
    }

    /// 端末の地域から推した初期値。対応していない通貨なら日本円にする。
    /// 使うのは初回だけ。あとからここを見ると、地域を変えた拍子に
    /// ユーザーが選んだ通貨を上書きしてしまう。
    static var deviceDefault: DisplayCurrency {
        if let code = Locale.current.currency?.identifier,
           let matched = DisplayCurrency(rawValue: code) {
            return matched
        }
        // 対応していない通貨の地域（カナダドルなど）。
        // アプリを日本語で見ているなら円、それ以外は米ドルに寄せる。
        // 端末の優先言語ではなく実際の表示言語を見る（このアプリは ja / en だけ）。
        let showsJapanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") == true
        return showsJapanese ? .JPY : .USD
    }
}
