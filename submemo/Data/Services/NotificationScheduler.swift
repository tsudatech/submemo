//
//  NotificationScheduler.swift
//  submemo
//
//  更新・トライアル終了のローカル通知スケジューリング。
//  （shoplist の ReminderScheduler と同じ方針でローカル通知のみを使う）
//
//  ・通知許可を求めるのは「ユーザーが通知を望む操作をした瞬間」だけ（enable）。
//    起動時など受け身の場面では許可済みのときだけ組み直す（rescheduleIfAuthorized）ので、
//    文脈の無いタイミングで許可ダイアログは出ない。
//  ・本文は画面に出しているプレビュー（NotifPreview）と同じ文言を使う。
//    「金額と日付を必ず本文に入れる」という方針を1か所で守るため。
//  ・iOS の保留通知は 64 件まで。近い順に切って、超えた分は諦める。
//

import UserNotifications
import Foundation

@MainActor
enum NotificationScheduler {
    /// 予約の上限。iOS の制限（64）より少し余裕を持たせる。
    private static let maxPending = 60
    static let prefix = "submemo.renewal."
    /// 「あとで」で積み直したぶん。作り直しの対象から外すために別の接頭辞にする。
    static let snoozePrefix = "submemo.snoozed."

    /// 通知に付けるアクションの束。
    static let categoryID = "submemo.renewal"
    static let snoozeActionID = "submemo.action.snooze"

    private static var center: UNUserNotificationCenter { .current() }

    enum Permission { case granted, denied }

    /// 通知に「あとで」ボタンを付ける。起動時に一度登録する。
    static func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: TR("notif_action_snooze"),
            options: [])
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [snooze],
            intentIdentifiers: [],
            options: [])
        center.setNotificationCategories([category])
    }

    /// 「あとで」を押されたぶんを積み直す。
    static func snooze(_ request: UNNotificationRequest, until date: Date) {
        let content = UNMutableNotificationContent()
        content.title = request.content.title
        content.body = request.content.body
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.interruptionLevel = request.content.interruptionLevel

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        // 元の ID を引き継ぐと作り直しで消えるので、専用の接頭辞を付ける。
        let id = snoozePrefix + request.identifier + "." + String(Int(date.timeIntervalSince1970))
        center.add(UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// ユーザーが通知を望む操作（通知設定の変更）をしたときに呼ぶ。
    /// 未確定なら許可を求め、許可されていれば予約し直す。
    @discardableResult
    static func enable(plans: [NotificationPlan]) async -> Permission {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { cancelAll(); return .denied }
        apply(plans)
        return .granted
    }

    /// 許可済みのときだけ予約し直す。許可ダイアログを出さないので起動時に呼んでよい。
    static func rescheduleIfAuthorized(plans: [NotificationPlan]) async {
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        apply(plans)
    }

    static func cancelAll() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier)
                .filter { $0.hasPrefix(prefix) || $0.hasPrefix(snoozePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 予約を作り直す。作り直しなので、まず自分の予約だけを消す。
    private static func apply(_ plans: [NotificationPlan]) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)

            let cal = Calendar.current
            for plan in plans.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxPending) {
                let content = UNMutableNotificationContent()
                content.title = plan.title
                content.body = plan.body
                content.sound = .default
                content.categoryIdentifier = categoryID
                if plan.isTrial {
                    // トライアル終了は取り逃がすと課金が始まる。時間指定で割り込ませる。
                    content.interruptionLevel = .timeSensitive
                }

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
                let request = UNNotificationRequest(
                    identifier: prefix + plan.id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                center.add(request)
            }
        }
    }
}

/// 1件分の予約内容。文言と発火時刻はストア側で決めて、ここは並べるだけにする。
nonisolated struct NotificationPlan {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
    let isTrial: Bool
    /// どのサブスクの通知か。プレビューからその詳細を開くのに使う。
    let subscriptionID: UUID
    /// 更新日の何日前か。0 は当日。
    let lead: Int
}
