//
//  NotificationResponder.swift
//  submemo
//
//  通知に出した「あとで」ボタンの受け口。
//
//  UNUserNotificationCenter のデリゲートはアプリ起動時に一度だけ差しておく必要がある。
//  ここを繋がないと、ボタンは表示されても押しても何も起きない。
//

import UserNotifications
import Foundation

@MainActor
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    /// 再通知までの間隔を決めるための設定の読み出し口。ストアが差し込む。
    var snoozeProvider: () -> AppStore.NotifSettings.Snooze = { .oneDay }
    /// 通知本体をタップされたときに開く先。ストアが差し込む。
    var onOpen: (UUID) -> Void = { _ in }

    func attach() {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
    }

    /// アプリを開いている間に届いた通知も、ふつうに出す。
    /// 出さないと「設定したのに来ない」と受け取られる。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier

        switch response.actionIdentifier {
        case NotificationScheduler.snoozeActionID:
            await MainActor.run {
                let when = Self.snoozeDate(for: snoozeProvider(),
                                           originalFireDate: Self.fireDate(of: response.notification))
                NotificationScheduler.snooze(response.notification.request, until: when)
            }
        case UNNotificationDefaultActionIdentifier:
            // 通知そのものをタップ。該当のサブスクの詳細を開く。
            guard let id = Self.subscriptionID(from: identifier) else { return }
            await MainActor.run { onOpen(id) }
        default:
            break
        }
    }

    /// 予約 ID からサブスクの UUID を取り出す。
    /// 形式は "submemo.renewal.<uuid>.<lead>"、スヌーズ分は前に接頭辞がもう一段付く。
    nonisolated static func subscriptionID(from identifier: String) -> UUID? {
        identifier.split(separator: ".").compactMap { UUID(uuidString: String($0)) }.first
    }

    /// 再通知の時刻。
    /// 「更新前日」は元の通知が指していた更新日を基準にする ── いま時刻から1日後にすると
    /// 更新日を過ぎてしまい、意味が逆になるため。
    static func snoozeDate(for snooze: AppStore.NotifSettings.Snooze,
                           originalFireDate: Date?,
                           now: Date = Date()) -> Date {
        let cal = Calendar.current
        switch snooze {
        case .oneHour:
            return cal.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        case .oneDay:
            return cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        case .dayBefore:
            // 元の通知が「N日前」なら、その更新日の前日 9:00 に寄せる。
            guard let fired = originalFireDate,
                  let dayBefore = cal.date(byAdding: .day, value: -1, to: fired),
                  let at9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore),
                  at9 > now
            else {
                return cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
            }
            return at9
        }
    }

    /// その通知が本来どの日時を指していたか。
    private static func fireDate(of notification: UNNotification) -> Date? {
        guard let trigger = notification.request.trigger as? UNCalendarNotificationTrigger else { return nil }
        return trigger.nextTriggerDate() ?? Calendar.current.date(from: trigger.dateComponents)
    }
}
