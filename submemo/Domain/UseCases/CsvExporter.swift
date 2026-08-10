//
//  CsvExporter.swift
//  submemo
//
//  登録内容を CSV に書き出す。
//
//  ・文字コードは UTF-8（BOM つき）。Excel が BOM 無しの UTF-8 を Shift_JIS と誤認して
//    日本語が化けるため、画面の説明どおり BOM を付ける。
//  ・改行は CRLF。Excel と他の表計算ソフトの双方で素直に開ける。
//  ・区切り文字・引用符・改行を含む値は RFC 4180 に従って引用する。
//

import Foundation

nonisolated enum CsvExporter {

    /// 書き出す期間。
    nonisolated enum Range: String, Codable, CaseIterable, Identifiable {
        case all, thisYear, thisMonth

        var id: String { rawValue }
        var labelKey: String { "csv_range_\(rawValue)" }

        /// ファイル名に入れる識別子。
        func fileToken(now: Date = Date()) -> String {
            let cal = Calendar.current
            switch self {
            case .all:       return "all"
            case .thisYear:  return String(cal.component(.year, from: now))
            case .thisMonth: return String(format: "%04d-%02d",
                                           cal.component(.year, from: now),
                                           cal.component(.month, from: now))
            }
        }

        /// 次回更新日がこの期間に入るか。
        func contains(_ date: Date, now: Date = Date()) -> Bool {
            let cal = Calendar.current
            switch self {
            case .all:       return true
            case .thisYear:  return cal.component(.year, from: date) == cal.component(.year, from: now)
            case .thisMonth: return cal.isDate(date, equalTo: now, toGranularity: .month)
            }
        }
    }

    /// 含める列。サービス名は常に含む。
    nonisolated struct Columns: Codable, Equatable {
        var price = true
        var next = true
        var category = true
        var pay = false

        var count: Int { 1 + [price, next, category, pay].filter { $0 }.count }
    }

    /// 1行ぶんの材料。金額やカテゴリ名の解決はストア側で済ませて渡す。
    nonisolated struct Row {
        let name: String
        let price: String
        let nextRenewal: Date
        let category: String
        let payment: String
    }

    /// ヘッダー行。
    static func header(_ columns: Columns) -> [String] {
        var out = [TR("csv_col_name")]
        if columns.price { out.append(TR("csv_col_price")) }
        if columns.next { out.append(TR("csv_col_next")) }
        if columns.category { out.append(TR("csv_col_cat")) }
        if columns.pay { out.append(TR("csv_col_pay")) }
        return out
    }

    static func fields(of row: Row, columns: Columns) -> [String] {
        var out = [row.name]
        if columns.price { out.append(row.price) }
        if columns.next { out.append(DateText.iso(row.nextRenewal)) }
        if columns.category { out.append(row.category) }
        if columns.pay { out.append(row.payment) }
        return out
    }

    /// CSV 本文を組み立てる。
    static func makeText(rows: [Row], columns: Columns) -> String {
        var lines = [line(header(columns))]
        lines += rows.map { line(fields(of: $0, columns: columns)) }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// 一時領域にファイルを書き出して、その場所を返す。共有シートへ渡す用。
    static func write(rows: [Row], columns: Columns, fileName: String) throws -> URL {
        let text = makeText(rows: rows, columns: columns)
        // BOM（EF BB BF）を先頭に付ける。
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(text.utf8))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - RFC 4180

    private static func line(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: ",")
    }

    /// カンマ・引用符・改行を含む値は引用符で囲み、中の引用符は2重にする。
    private static func escaped(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
