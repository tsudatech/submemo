//
//  ReviewRequester.swift
//  submemo
//
//  App Store のレビュー依頼。
//
//  出すのは「解約したら年間いくら浮くか」が出た直後だけにしてある。
//  このアプリでいちばん満足度が高い瞬間で、ここ以外（起動直後・入力の途中・
//  エラーのあと）で出すと低評価を集めるだけになる。
//
//  iOS が出す回数を年3回までに制限しているので、こちらでも
//  「実際に使っている人か」「間を空けたか」を見て、無駄打ちを減らす。
//

import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewRequester {
    /// これ以上登録していれば「使っている人」とみなす。
    private static let minimumSubscriptions = 3
    /// 前回頼んでから空ける日数。
    private static let cooldownDays = 120

    private static let lastRequestKey = "submemo.review.lastRequestedAt"
    private static let lastVersionKey = "submemo.review.lastRequestedVersion"

    /// 条件を満たしていればレビューを依頼する。満たしていなければ何もしない。
    /// - Parameter subscriptionCount: いま登録されている件数。
    static func requestIfAppropriate(subscriptionCount: Int) {
        guard subscriptionCount >= minimumSubscriptions else { return }

        let defaults = UserDefaults.standard

        // 同じバージョンでは一度だけ。バージョンが上がれば、また頼める。
        if let last = defaults.string(forKey: lastVersionKey), last == currentVersion { return }

        // バージョンを跨いでも、間隔が空いていなければ出さない。
        if let at = defaults.object(forKey: lastRequestKey) as? Date,
           let next = Calendar.current.date(byAdding: .day, value: cooldownDays, to: at),
           Date() < next {
            return
        }

        guard let scene = activeScene else { return }

        defaults.set(Date(), forKey: lastRequestKey)
        defaults.set(currentVersion, forKey: lastVersionKey)

        // StoreKit の AppStore。このアプリのストア（Domain の AppStore）と
        // 名前が同じなので、必ずモジュール名から書くこと。
        StoreKit.AppStore.requestReview(in: scene)
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
