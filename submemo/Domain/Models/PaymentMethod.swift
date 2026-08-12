//
//  PaymentMethod.swift
//  submemo
//
//  支払い方法のドメインモデル。組み込み（built-in）＋ユーザー追加のカスタムを扱えるよう
//  enum ではなく struct にする。カスタムのみ永続化し、iCloud 同期の対象にする。
//
//  カード番号・有効期限は持たない。どのカードから引かれるかを自分で見分けるための
//  ラベルとして、名前と下4桁だけを預かる（design の「カードの下4桁だけを記録します」）。
//

import Foundation

nonisolated struct PaymentMethod: Identifiable, Codable, Equatable, Hashable {
    let id: String
    /// 組み込みのローカライズキー（カスタムは nil）。
    var nameKey: String?
    /// カスタムのユーザー入力名（組み込みは nil）。
    var customName: String?
    /// カードの下4桁。任意。
    var last4: String?
    var colorHex: UInt
    let isBuiltIn: Bool
    /// 最後に編集した日時。iCloud 同期の合併で新旧を判定する。
    var updatedAt: Date

    init(id: String, nameKey: String? = nil, customName: String? = nil, last4: String? = nil,
         colorHex: UInt, isBuiltIn: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.nameKey = nameKey
        self.customName = customName
        self.last4 = last4
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.updatedAt = updatedAt
    }

    /// 項目が増えても古い保存データを読めるようにする。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameKey = try c.decodeIfPresent(String.self, forKey: .nameKey)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        last4 = try c.decodeIfPresent(String.self, forKey: .last4)
        colorHex = try c.decodeIfPresent(UInt.self, forKey: .colorHex) ?? 0x6E7C99
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    /// 一覧の見出し（「メインカード」）。
    var name: String { customName ?? nameKey.map(TR) ?? id }

    /// その下の補足（「Visa ・・・4242」相当）。組み込みは専用の文言、カスタムは下4桁。
    var detail: String {
        if let last4, !last4.isEmpty { return TRF("pay_last4_format", last4) }
        if isBuiltIn { return TR("pay_sub_\(id)") }
        return ""
    }

    /// 詳細画面やチップに出す表記。組み込みは従来どおりの文言を使う。
    var label: String {
        if isBuiltIn { return TR("pay_label_\(id)") }
        if let last4, !last4.isEmpty { return name + Sep.mid + TRF("pay_last4_format", last4) }
        return name
    }

    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }
}

nonisolated extension PaymentMethod {
    /// 「未設定」。登録時の既定値であり、消せない。
    static let unsetID = "unset"

    /// 組み込みの支払い方法。ID は旧 PayKey の rawValue と同じにしてあるので、
    /// 以前に保存したサブスクの支払い方法がそのまま読める。
    /// 最初から入っているのは「未設定」だけ。
    /// カードや口座は人によって名前も枚数も違うので、こちらで用意しておくと
    /// 「使っていないサンプルが並んでいる」状態になる。必要な人が自分で足す。
    static let builtIns: [PaymentMethod] = [
        PaymentMethod(id: unsetID, nameKey: "pay_name_unset", colorHex: 0x6E7C99, isBuiltIn: true),
    ]

    /// Debug のサンプルデータが参照する支払い方法。投入時に一緒に作る。
    static let samples: [PaymentMethod] = [
        PaymentMethod(id: "card4242", nameKey: "pay_name_card4242", last4: "4242", colorHex: 0x5B7CFA),
        PaymentMethod(id: "card1881", nameKey: "pay_name_card1881", last4: "1881", colorHex: 0x8E4EC6),
        PaymentMethod(id: "appStore", nameKey: "pay_name_appStore", colorHex: 0x8B93A2),
        PaymentMethod(id: "bankTransfer", nameKey: "pay_name_bankTransfer", colorHex: 0x00A2C7),
    ]

    static let unset = builtIns.last!

    static func custom(name: String, last4: String?, colorHex: UInt) -> PaymentMethod {
        PaymentMethod(id: UUID().uuidString, customName: name,
                      last4: last4?.isEmpty == true ? nil : last4, colorHex: colorHex)
    }
}
