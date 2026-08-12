//
//  ExchangeRateService.swift
//  submemo
//
//  外貨→円のレート取得。
//
//  ・Frankfurter（欧州中央銀行の公開データ）を使う。APIキー不要・無料。
//    https://api.frankfurter.app/latest?from=JPY&to=USD,EUR
//  ・取得できたレートと取得時刻は UserDefaults に持ち、オフラインでも直前の値で動く。
//  ・取れなかったことは黙って隠さない。画面に「取得できなかった」と出すため error を返す。
//  ・ECB は平日しか値を更新しないので、休日は同じ値が返る。それで問題ない用途。
//

import Foundation

nonisolated struct ExchangeRates: Codable, Equatable {
    /// 1通貨あたりの円。
    var perYen: [String: Double]
    var fetchedAt: Date

    func rate(for currency: Currency) -> Double? {
        currency == .JPY ? 1 : perYen[currency.rawValue]
    }

    func rate(for currency: DisplayCurrency) -> Double? {
        currency == .JPY ? 1 : perYen[currency.rawValue]
    }
}

nonisolated enum ExchangeRateService {
    private static let storageKey = "submemo.exchangeRates"

    /// 取りに行く通貨。JPY は基準なので含めない。
    /// 表示通貨として選べるもののうち、欧州中央銀行が公表しているものだけ。
    private static let targets: [DisplayCurrency] = DisplayCurrency.fetchTargets

    enum FetchError: Error { case network, malformed }

    // MARK: - 保存

    static func loadCached(from defaults: UserDefaults = .standard) -> ExchangeRates? {
        guard let data = defaults.data(forKey: storageKey),
              let rates = try? JSONDecoder().decode(ExchangeRates.self, from: data) else { return nil }
        return rates
    }

    static func save(_ rates: ExchangeRates, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - 取得

    /// 最新レートを取りに行く。失敗したら投げる（呼び出し側で前回値を使い続ける）。
    static func fetch(now: Date = Date()) async throws -> ExchangeRates {
        let symbols = targets.map(\.rawValue).joined(separator: ",")
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=JPY&to=\(symbols)") else {
            throw FetchError.malformed
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.network
        }

        struct Payload: Decodable { let rates: [String: Double] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw FetchError.malformed
        }

        // API は「1円あたりの外貨」を返すので、逆数を取って「1外貨あたりの円」にする。
        var perYen: [String: Double] = [:]
        for currency in targets {
            guard let value = payload.rates[currency.rawValue], value > 0 else { continue }
            perYen[currency.rawValue] = (1 / value * 100).rounded() / 100
        }
        guard !perYen.isEmpty else { throw FetchError.malformed }

        return ExchangeRates(perYen: perYen, fetchedAt: now)
    }
}
