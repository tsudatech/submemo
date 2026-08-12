//
//  DesignSystem.swift
//  submemo
//
//  デザインドキュメント 1a「動くプロトタイプ」のパレット／タイポグラフィと共通UIパーツ。
//  1a は 393pt 幅の端末を前提に作られているため、寸法はドキュメントの px をそのまま pt として使う。
//

import SwiftUI
import UIKit

/// ライト/ダークのトレイトに応じて解決される動的カラー。
/// ルートの `preferredColorScheme` が変わると各定数が自動で解決し直される。
private func dyn(light: UInt, dark: UInt) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
    })
}

/// 白/黒の半透明（罫線・トラックなど）を明暗で出し分ける。
private func dynVeil(lightAlpha: CGFloat, darkAlpha: CGFloat) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: darkAlpha)
            : UIColor(white: 0, alpha: lightAlpha)
    })
}

/// 1a のカラートークン（`th` オブジェクト）をそのまま移植したもの。
enum SM {
    // 面
    static let bg      = dyn(light: 0xF6F7F9, dark: 0x1B2129)
    static let card    = dyn(light: 0xFFFFFF, dark: 0x262C36)

    // インク
    static let fg      = dyn(light: 0x141821, dark: 0xF2F4F7)
    static let sub     = dyn(light: 0x6B7280, dark: 0x8A93A2)
    static let dim     = dyn(light: 0x9AA1AC, dark: 0x5C6472)

    // 罫線・トラック
    static let line    = dynVeil(lightAlpha: 0.06, darkAlpha: 0.05)
    static let line2   = dynVeil(lightAlpha: 0.07, darkAlpha: 0.06)
    static let border  = dynVeil(lightAlpha: 0.10, darkAlpha: 0.10)
    static let border2 = dynVeil(lightAlpha: 0.14, darkAlpha: 0.12)
    static let border3 = dynVeil(lightAlpha: 0.16, darkAlpha: 0.16)
    static let track   = dynVeil(lightAlpha: 0.14, darkAlpha: 0.14)

    // アクセント（1a は明暗で同じインディゴを使い、文字色だけ明度を変える）
    static let indigo   = Color(hex: 0x5B7CFA)
    static let indigoFg = dyn(light: 0x3457C8, dark: 0x8FA8FF)

    // 状態色
    static let red     = dyn(light: 0xD93A3A, dark: 0xFF8A8A)   // 文字用の赤
    static let alert   = Color(hex: 0xFF5C5C)                    // 面・強調用の赤
    static let green   = dyn(light: 0x159A55, dark: 0x2FBF71)    // 文字用の緑
    static let greenSolid = Color(hex: 0x2FBF71)                 // 面用の緑
    static let onGreen = Color(hex: 0x06210F)                    // 緑の面にのせる文字
    static let amber   = Color(hex: 0xF5A623)
    static let onAmber = Color(hex: 0x241A05)                    // アンバーの面にのせる文字
    static let editGray = Color(hex: 0x3A4150)                   // スワイプの「編集」

    // 半透明の下地
    static let indigoTint = Color(hex: 0x5B7CFA, alpha: 0.16)
    static let indigoLine = Color(hex: 0x5B7CFA, alpha: 0.60)
    static let redTint    = Color(hex: 0xFF5C5C, alpha: 0.08)
    static let redLine    = Color(hex: 0xFF5C5C, alpha: 0.30)
    static let greenTint  = Color(hex: 0x2FBF71, alpha: 0.08)
    static let greenLine  = Color(hex: 0x2FBF71, alpha: 0.32)
    static let amberTint  = Color(hex: 0xF5A623, alpha: 0.06)
    static let amberLine  = Color(hex: 0xF5A623, alpha: 0.28)

    // フォント（本文は system、数字は等幅数字）
    static func f(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func n(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// カテゴリ標準8色 ＋ カラーピッカーのパレット。
    static let palette: [UInt] = [
        0xE5484D, 0xD9822B, 0xF2A93B, 0x30A46C, 0x2EC4B6, 0x00A2C7,
        0x5B7CFA, 0x7C6CFF, 0x8E4EC6, 0xE06B9B, 0x6E7C99, 0x8B93A2,
    ]
}

// ドメインモデルは色を 0xRRGGBB で持つ。実色への解決は Presentation 層で行う。
extension SubCategory {
    var color: Color { Color(hex: colorHex) }
}
extension PaymentMethod {
    var color: Color { Color(hex: colorHex) }
}
extension NotifPreview {
    var color: Color { Color(hex: colorHex) }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - 共通の小物

/// 頭文字タイル。1a はロゴを一切使わず、この色タイル＋頭文字で各サービスを表す。
struct InitialTile: View {
    let text: String
    let color: Color
    var size: CGFloat = 42
    var radius: CGFloat = 13
    var fontSize: CGFloat = 17

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(verbatim: text)
                    .font(SM.f(fontSize, .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// チップの見た目。選択時の下地・文字・枠の組み合わせを決める。
enum ChipTone {
    case indigo             // 既定（更新サイクル・通貨・期間など）
    case red                // トライアル関連
    case solid(Color)       // 月切替・カテゴリ（選択時にベタ塗り）
}

/// 選択状態を持つ角丸チップ。
struct Chip: View {
    let title: String
    var isKey: Bool = true          // title がローカライズキーかどうか
    let selected: Bool
    var tone: ChipTone = .indigo
    var height: CGFloat = 42
    var fill: Bool = true           // 横幅いっぱいに広げるか
    let action: () -> Void

    private var colors: (bg: Color, fg: Color, border: Color) {
        switch tone {
        case .indigo:
            return selected ? (SM.indigoTint, SM.indigoFg, SM.indigoLine) : (.clear, SM.sub, SM.border)
        case .red:
            return selected
                ? (Color(hex: 0xFF5C5C, alpha: 0.14), SM.red, Color(hex: 0xFF5C5C, alpha: 0.55))
                : (.clear, SM.sub, SM.border)
        case let .solid(color):
            return selected ? (color, .white, color) : (.clear, SM.sub, SM.border)
        }
    }

    var body: some View {
        let c = colors
        Button(action: action) {
            Group {
                if isKey { Text(title.loc) } else { Text(verbatim: title) }
            }
            .font(SM.f(12.5, .medium))
            .foregroundStyle(c.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: height)
            .background(c.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(c.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// iOS 標準に寄せた見た目のトグル（1a のノブ付きスイッチ）。
struct SMSwitch: View {
    let isOn: Bool
    var onColor: Color = SM.indigo

    var body: some View {
        Capsule()
            .fill(isOn ? onColor : SM.track)
            .frame(width: 46, height: 28)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .padding(3)
            }
            .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

/// セクションの小見出し（うすいラベル）。
struct SectionLabel: View {
    let key: String
    var color: Color = SM.sub
    var body: some View {
        Text(key.loc)
            .font(SM.f(11.5, .medium))
            .tracking(0.5)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 右向きシェブロン（一覧行の末尾）。
struct ChevronRight: View {
    var color: Color = SM.sub
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
    }
}

/// 数字が 0 から立ち上がるカウントアップ表示（1a の `anim` を再現）。
/// 初回表示のときだけ動き、以降は値をそのまま出す。
struct CountUpNumber: View {
    let value: Double
    var font: Font = SM.n(58, .semibold)
    var animates: Bool = true

    @State private var shown: Double = 0
    @State private var didAnimate = false

    var body: some View {
        Text(verbatim: Money.num(shown))
            .font(font)
            .kerning(-1)
            .foregroundStyle(SM.fg)
            .task(id: value) {
                guard animates, !didAnimate else { shown = value; return }
                didAnimate = true
                let steps = 12
                for i in 1...steps {
                    try? await Task.sleep(for: .milliseconds(26))
                    guard !Task.isCancelled else { return }
                    shown = value * Double(i) / Double(steps)
                }
                shown = value
            }
    }
}

/// カード面の共通装飾。
extension View {
    func smCard(radius: CGFloat = 16) -> some View {
        background(SM.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    func smStroke(_ color: Color, radius: CGFloat = 16, lineWidth: CGFloat = 1) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(color, lineWidth: lineWidth))
    }
}
