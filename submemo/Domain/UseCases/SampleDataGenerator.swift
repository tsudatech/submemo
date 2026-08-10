//
//  SampleDataGenerator.swift
//  submemo
//
//  設定のサンプルデータ機能（Debug のみ）で使う決定論的ジェネレータ。
//  日本語／英語のサブスク一式を「今日」起点に生成する。
//  ID は seed 文字列から安定生成するので、同じ言語で2回追加しても重複しない（idempotent）。
//  サービス名はアプリの表示言語ではなく、選んだ言語のリテラルを使う
//  （英語UIで日本語サンプルを入れる、といった確認ができるようにするため）。
//  （shoplist の SampleDataGenerator と同じ設計方針）
//

import CryptoKit
import Foundation

nonisolated enum SampleDataLanguage: String, CaseIterable, Identifiable {
    case japanese, english
    var id: String { rawValue }

    var labelKey: String { self == .japanese ? "settings_sample_add_jp" : "settings_sample_add_en" }
    var subKey: String { self == .japanese ? "settings_sample_add_jp_sub" : "settings_sample_add_en_sub" }
}

nonisolated enum SampleDataGenerator {

    /// seed 文字列から安定した UUID を生成する（同一 seed → 同一 ID）。
    static func stableUUID(from seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40   // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // variant
        let t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: t)
    }

    /// 言語別のサービス名。
    private static func names(_ lang: SampleDataLanguage) -> [String: String] {
        switch lang {
        case .japanese:
            return ["netflix": "Netflix", "spotify": "Spotify Premium", "youtube": "YouTube Premium",
                    "icloud": "iCloud+ 200GB", "chatgpt": "ChatGPT Plus", "adobe": "Adobe フォトプラン",
                    "amazon": "Amazon プライム", "gym": "エニタイムフィットネス",
                    "switch": "Nintendo Switch Online", "perplexity": "Perplexity Pro"]
        case .english:
            return ["netflix": "Netflix", "spotify": "Spotify Premium", "youtube": "YouTube Premium",
                    "icloud": "iCloud+ 200GB", "chatgpt": "ChatGPT Plus", "adobe": "Adobe Photography Plan",
                    "amazon": "Amazon Prime", "gym": "Anytime Fitness",
                    "switch": "Nintendo Switch Online", "perplexity": "Perplexity Pro"]
        }
    }

    /// サンプルのサブスク一式（10件）。すべて isSample = true。
    static func generate(language lang: SampleDataLanguage, today: Date = Date()) -> [Subscription] {
        let n = names(lang)
        let cal = Calendar.current
        let base = cal.startOfDay(for: today)
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: base) ?? base }
        func monthsAgo(_ m: Int) -> Date { cal.date(byAdding: .month, value: -m, to: base) ?? base }

        func sub(_ seed: String, _ nameKey: String, category: String,
                 price: Double, currency: Currency = .JPY, cycle: Cycle = .month,
                 inDays: Int, pay: String, trial: Bool = false, unused: Bool = false,
                 usedMonthsAgo: Int? = nil, change: PriceChange? = nil) -> Subscription {
            Subscription(id: stableUUID(from: "s-sub-\(lang.rawValue)-\(seed)"),
                         customName: n[nameKey] ?? nameKey,
                         categoryID: category,
                         price: price, currency: currency, cycle: cycle,
                         nextRenewal: day(inDays), paymentMethodID: pay,
                         isTrial: trial, isUnused: unused,
                         lastUsedAt: usedMonthsAgo.map(monthsAgo),
                         priceChange: change,
                         createdAt: base, updatedAt: base, isSample: true)
        }

        return [
            sub("netflix", "netflix", category: "video", price: 1590, inDays: 6, pay: "card4242", usedMonthsAgo: 0,
                change: PriceChange(date: monthsAgo(24), from: 1490, to: 1590)),
            sub("spotify", "spotify", category: "music", price: 1080, inDays: 3, pay: "appStore", usedMonthsAgo: 0),
            sub("youtube", "youtube", category: "video", price: 1280, inDays: 15, pay: "card4242",
                change: PriceChange(date: monthsAgo(36), from: 1180, to: 1280)),
            sub("icloud", "icloud", category: "cloud", price: 450, inDays: 22, pay: "appStore"),
            sub("chatgpt", "chatgpt", category: "learning", price: 20, currency: .USD, inDays: 9, pay: "card1881"),
            sub("adobe", "adobe", category: "other", price: 1180, inDays: 26, pay: "card4242"),
            sub("amazon", "amazon", category: "life", price: 5900, cycle: .year, inDays: 220, pay: "card4242",
                change: PriceChange(date: monthsAgo(41), from: 4900, to: 5900)),
            sub("gym", "gym", category: "life", price: 7480, inDays: 19, pay: "bankTransfer", unused: true, usedMonthsAgo: 4),
            sub("switch", "switch", category: "game", price: 4500, cycle: .year, inDays: 167, pay: "appStore", unused: true, usedMonthsAgo: 7),
            sub("perplexity", "perplexity", category: "learning", price: 3000, inDays: 3, pay: "card1881", trial: true),
        ]
    }
}
