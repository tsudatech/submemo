//
//  AppearanceMode.swift
//  submemo
//
//  アプリの外観モード（システム / ライト / ダーク）。既定はライト。
//  ヘッダーの ☀/☾ ボタンと設定画面の「テーマ」行から切り替え、
//  @AppStorage("appearanceMode") を通じてアプリ全体で共有する。
//  （shoplist の AppearanceMode を流用）
//

import SwiftUI

/// 選択可能な外観モード。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `preferredColorScheme` に渡す値。`system` は nil（端末設定に追従）。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// 設定画面に表示するラベルのローカライズキー。
    var titleKey: String {
        switch self {
        case .system: return "appearance_system"
        case .light:  return "appearance_light"
        case .dark:   return "appearance_dark"
        }
    }

    /// 「システム → ライト → ダーク → システム」と巡回する。
    var next: AppearanceMode {
        switch self {
        case .system: return .light
        case .light:  return .dark
        case .dark:   return .system
        }
    }

    /// 何も選んでいないときの既定。端末の設定に追従させず、ライトで固定する。
    static let `default` = AppearanceMode.light

    /// 保存値から復元する。未設定・不正値のときは既定にフォールバック。
    static func current(from raw: String) -> AppearanceMode {
        AppearanceMode(rawValue: raw) ?? .default
    }
}

/// `@AppStorage("appearanceMode")` を購読し、配下へ `preferredColorScheme` を適用する ViewModifier。
private struct AppAppearanceModifier: ViewModifier {
    @AppStorage("appearanceMode") private var raw = AppearanceMode.default.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(AppearanceMode.current(from: raw).colorScheme)
    }
}

extension View {
    /// 外観モード設定に応じて `preferredColorScheme` を適用する。
    func appAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}

/// 画面右上の ☀ / ☾ トグル。いまの見た目の逆側へ一発で切り替える。
struct ThemeToggleButton: View {
    @AppStorage("appearanceMode") private var raw = AppearanceMode.default.rawValue
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            raw = (scheme == .dark ? AppearanceMode.light : AppearanceMode.dark).rawValue
        } label: {
            Image(systemName: scheme == .dark ? "sun.max" : "moon")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SM.sub)
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SM.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("a11y_toggle_theme".loc)
    }
}
