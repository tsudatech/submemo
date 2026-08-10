//
//  Navigation.swift
//  submemo
//
//  1a プロトタイプのルーティング。1画面ずつ差し替える単純な構成で、
//  ホーム / 集計 / 通知 / 設定 の4画面だけ下部タブバーを出す。
//

import SwiftUI

struct ContentViewRoot: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    /// 戻るスワイプの横移動量。0 が通常表示、画面幅ぶんで戻り切る。
    @State private var dragX: CGFloat = 0
    /// 戻り操作の最中か。この間だけ戻り先を下に敷く。
    @State private var isGoingBack = false
    /// 通知の「あとで」を受ける係。起動時に一度だけ差す。
    @State private var notificationResponder = NotificationResponder()

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                SM.bg.ignoresSafeArea()

                // 戻り先。iOS と同じく、現在の画面より少しゆっくり右へ追従させる。
                if isGoingBack, let previous = store.history.last {
                    // 手前の画面がタブバーを持っているなら、下敷き側は出さない。
                    // 出すと同じ位置に2本並んでしまう。
                    screen(previous,
                           showsTabBar: AppStore.showsTabBar(previous)
                                        && !AppStore.showsTabBar(store.screen))
                        .offset(x: (dragX - width) * 0.3)
                        // 下敷きは見せるだけ。触れると二重に反応してしまう。
                        .allowsHitTesting(false)
                }

                screen(store.screen, showsTabBar: AppStore.showsTabBar(store.screen))
                    .offset(x: dragX)
                    .shadow(color: .black.opacity(isGoingBack ? 0.18 : 0), radius: 12, x: -6)

            }
            .frame(width: width, height: geo.size.height)
            // 画面ごとのガイド。タブバーの上にも被せたいので、いちばん外側で重ねる。
            .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
                GeometryReader { proxy in coachOverlay(anchors: anchors, proxy: proxy) }
                    .ignoresSafeArea()
            }
            // 左端から始まった横ドラッグだけを拾う。縦スクロールとは開始位置で棲み分ける。
            .simultaneousGesture(backDrag(width: width))
            // 戻るボタンからも同じスライドで戻す（スワイプと見た目を揃える）。
            .environment(\.animatedBack) { slideBack(width: width) }
        }
        .environmentObject(store)
        // シートは標準の presentation に載せる。キーボードに合わせた持ち上げを
        // UIKit 側に任せるため、出入りのタイミングがキーボードと完全に揃う。
        // シートの中身は別のビュー階層に出るので、ストアはここで明示的に渡す。
        .sheet(isPresented: sheetBinding(isOpen: store.catEdit != nil) { store.catEdit = nil }) {
            CategoryEditSheet().environmentObject(store)
        }
        .sheet(isPresented: sheetBinding(isOpen: store.payEdit != nil) { store.payEdit = nil }) {
            PaymentEditSheet().environmentObject(store)
        }
        .sheet(isPresented: sheetBinding(isOpen: store.csv.open) { store.closeCsv() }) {
            CsvSheet().environmentObject(store)
        }
        // キーボードの外側タップで閉じる。ルートに1度だけ仕込めば、シートの中にも効く。
        .dismissKeyboardOnTapOutside()
        .task {
            // 「あとで」を押したときの再通知は、この設定を見て間隔を決める。
            notificationResponder.snoozeProvider = { store.nset.snooze }
            notificationResponder.onOpen = { id in
                guard let sub = store.sub(id) else { return }
                store.open(sub, fromNotification: true)
            }
            notificationResponder.attach()
        }
        .onChange(of: scenePhase) { _, phase in
            // 復帰のたびに予約を引き直す。日付が進んで期限切れになった予約を掃除するため。
            if phase == .active {
                store.rescheduleNotifications()
                Task { await store.refreshRates() }
            }
        }
    }

    /// 0件のときのガイド。対象が画面に無ければ何も出さない。
    @ViewBuilder
    private func coachOverlay(anchors: [CoachTarget: Anchor<CGRect>], proxy: GeometryProxy) -> some View {
        let step = store.coachStep
        if let target = step.target, let anchor = anchors[target] {
            CoachSpotlight(
                rect: proxy[anchor],
                size: proxy.size,
                text: TR(step.textKey),
                bottomTrim: step.holeBottomTrim,
                onDone: { withAnimation(.easeInOut(duration: 0.2)) { store.finishCoach() } }
            )
        }
    }

    /// 下スワイプで閉じられたときにストア側の状態も落とすための橋渡し。
    private func sheetBinding(isOpen: Bool, onClose: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { isOpen }, set: { if !$0 { onClose() } })
    }

    // MARK: - 戻るスワイプ

    private func backDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard store.canGoBack else { return }
                if !isGoingBack {
                    // 引き始めの条件：左端 30pt 以内から、右向きに、横が縦より優勢。
                    guard value.startLocation.x < 30,
                          value.translation.width > 0,
                          value.translation.width > abs(value.translation.height)
                    else { return }
                    isGoingBack = true
                }
                dragX = min(width, max(0, value.translation.width))
            }
            .onEnded { value in
                guard isGoingBack else { return }
                // 半分まで引いたか、勢いよく振り切ったら戻る。
                let flick = value.predictedEndTranslation.width > width * 0.6
                if dragX > width * 0.3 || flick {
                    finishBack(width: width)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { dragX = 0 } completion: {
                        isGoingBack = false
                    }
                }
            }
    }

    /// 戻るボタン用。スワイプと同じ経路を通すので見た目が揃う。
    private func slideBack(width: CGFloat) {
        guard store.canGoBack, !isGoingBack else { return }
        isGoingBack = true
        finishBack(width: width)
    }

    /// 右へ抜けきってから画面を差し替える。差し替えた瞬間に位置を戻すので跳ねない。
    private func finishBack(width: CGFloat) {
        withAnimation(.easeOut(duration: 0.25)) {
            dragX = width
        } completion: {
            store.back()
            dragX = 0
            isGoingBack = false
        }
    }

    // MARK: - 画面

    @ViewBuilder
    private func screen(_ screen: AppStore.Screen, showsTabBar: Bool) -> some View {
        screenBody(screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(SM.bg)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsTabBar { SMTabBar() }
            }
    }

    @ViewBuilder
    private func screenBody(_ screen: AppStore.Screen) -> some View {
        switch screen {
        case .onboard:  OnboardingScreen()
        case .home:     HomeScreen()
        case .detail:   DetailScreen()
        case .cancel:   CancelSimScreen()
        case .add1:     AddSearchScreen()
        case .form:     SubscriptionFormScreen()
        case .stats:    StatsScreen()
        case .notif:    NotifScreen()
        case .notifset: NotifSettingsScreen()
        case .msgs:     NotifMessagesScreen()
        case .settings: SettingsScreen()
        case .cats:     CategoriesScreen()
        case .catlist:  CategoryListScreen()
        case .pays:     PaymentsScreen()
        case .fx:       FxScreen()
        }
    }
}

/// 戻るボタンから、スワイプと同じスライドで戻すための入口。
private struct AnimatedBackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var animatedBack: () -> Void {
        get { self[AnimatedBackKey.self] }
        set { self[AnimatedBackKey.self] = newValue }
    }
}

/// 下層画面の見出し行。戻り先もラベルもストアの履歴から決まるので、
/// 「‹ 設定 と書いてあるのに通知に戻る」といった食い違いが起きない。
struct ScreenNavBar<Trailing: View>: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.animatedBack) private var animatedBack

    /// タイトル（ローカライズキー）。カテゴリ名など生の文字列は rawTitle を使う。
    var titleKey: String?
    var rawTitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Group {
                if let rawTitle { Text(verbatim: rawTitle) }
                else if let titleKey { Text(titleKey.loc) }
            }
            .font(SM.f(14, .medium))
            .foregroundStyle(SM.fg)

            HStack {
                Button { animatedBack() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text(store.backTitleKey.loc).font(SM.f(14))
                    }
                    .foregroundStyle(SM.sub)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 12)
                trailing
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}

extension ScreenNavBar where Trailing == EmptyView {
    init(titleKey: String? = nil, rawTitle: String? = nil) {
        self.init(titleKey: titleKey, rawTitle: rawTitle, trailing: { EmptyView() })
    }
}

/// 下部タブバー。
struct SMTabBar: View {
    @EnvironmentObject private var store: AppStore

    private func item(_ s: AppStore.Screen) -> (icon: String, label: String) {
        switch s {
        case .home:     return ("house", "tab_home")
        case .stats:    return ("chart.pie", "tab_stats")
        case .notif:    return ("bell", "tab_notif")
        default:        return ("gearshape", "tab_settings")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppStore.tabScreens, id: \.self) { s in
                let it = item(s)
                let active = AppStore.activeTab(for: store.screen) == s
                Button {
                    store.goTab(s)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: active ? it.icon + ".fill" : it.icon)
                            .font(.system(size: 19, weight: .medium))
                        Text(it.label.loc)
                            .font(SM.f(10, .medium))
                    }
                    .foregroundStyle(active ? SM.indigo : SM.dim)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(.bar)
        .overlay(alignment: .top) { Rectangle().fill(SM.line2).frame(height: 1) }
    }
}
