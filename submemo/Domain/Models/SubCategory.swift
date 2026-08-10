//
//  SubCategory.swift
//  submemo
//
//  カテゴリのドメインモデル。組み込み（built-in）＋ユーザー追加のカスタムを扱えるよう
//  enum ではなく struct にする。色は 0xRRGGBB で持ち、Presentation 層で実色に解決する。
//

import Foundation

nonisolated struct SubCategory: Identifiable, Codable, Equatable, Hashable {
    let id: String
    /// 組み込みカテゴリのローカライズキー（カスタムは nil）。
    var nameKey: String?
    /// カスタムカテゴリのユーザー入力名（組み込みは nil）。
    var customName: String?
    var colorHex: UInt
    let isBuiltIn: Bool
    /// 最後に編集した日時。iCloud 同期の合併で新旧を判定する。
    var updatedAt: Date

    init(id: String, nameKey: String? = nil, customName: String? = nil,
         colorHex: UInt, isBuiltIn: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.nameKey = nameKey
        self.customName = customName
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.updatedAt = updatedAt
    }

    /// updatedAt を持たない旧データも読めるようにする（無いと全カスタムカテゴリが復号に失敗して消える）。
    /// 旧データは .distantPast 扱い＝この端末で編集し直せば必ず勝つ。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameKey = try c.decodeIfPresent(String.self, forKey: .nameKey)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        colorHex = try c.decodeIfPresent(UInt.self, forKey: .colorHex) ?? 0x8B93A2
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    var name: String { customName ?? nameKey.map(TR) ?? id }
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }
}

nonisolated extension SubCategory {
    /// 「その他」。カテゴリが見つからないときの受け皿。
    static let otherID = "other"

    static let builtIns: [SubCategory] = [
        SubCategory(id: "video",    nameKey: "cat_video",    colorHex: 0xE5484D, isBuiltIn: true),
        SubCategory(id: "music",    nameKey: "cat_music",    colorHex: 0x30A46C, isBuiltIn: true),
        SubCategory(id: "cloud",    nameKey: "cat_cloud",    colorHex: 0x5B7CFA, isBuiltIn: true),
        SubCategory(id: "game",     nameKey: "cat_game",     colorHex: 0x8E4EC6, isBuiltIn: true),
        SubCategory(id: "learning", nameKey: "cat_learning", colorHex: 0xF2A93B, isBuiltIn: true),
        SubCategory(id: "telecom",  nameKey: "cat_telecom",  colorHex: 0x00A2C7, isBuiltIn: true),
        SubCategory(id: "life",     nameKey: "cat_life",     colorHex: 0xE06B9B, isBuiltIn: true),
        SubCategory(id: otherID,    nameKey: "cat_other",    colorHex: 0x8B93A2, isBuiltIn: true),
    ]

    static let other = builtIns.last!

    static func custom(name: String, colorHex: UInt) -> SubCategory {
        SubCategory(id: UUID().uuidString, customName: name, colorHex: colorHex)
    }
}
