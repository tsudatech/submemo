//
//  EmptyState.swift
//  submemo
//
//  0件のときの表示（design §4）。ホーム・集計・通知で共通の骨格を使う。
//
//  design の指定どおり、画面見出しの下からタブバーの上までを使って中央に寄せる。
//  絵柄・見出し・説明・主ボタン・（あれば）副次の導線、という並びは3画面で共通。
//

import SwiftUI

struct EmptyState<Illustration: View>: View {
    @ViewBuilder var illustration: Illustration
    let titleKey: String
    let bodyKey: String
    let ctaKey: String
    let action: () -> Void
    /// 副次の導線（通知画面の「先に通知の設定を見ておく」など）。
    var secondaryKey: String? = nil
    var secondaryAction: (() -> Void)? = nil
    /// ガイドでハイライトしたい要素。指定が無ければ登録しない。
    var ctaCoachTarget: CoachTarget? = nil
    var secondaryCoachTarget: CoachTarget? = nil

    /// 絵柄の枠。中身の高さは画面ごとに違うので、枠を固定して見出し以降の位置を揃える。
    private static var glyphHeight: CGFloat { 96 }

    var body: some View {
        VStack(spacing: 22) {
            illustration.frame(height: Self.glyphHeight)

            Text(titleKey.loc)
                .font(SM.f(19, .bold))
                .lineSpacing(13)
                .foregroundStyle(SM.fg)
                .multilineTextAlignment(.center)

            // 説明が2行の画面と3行の画面でボタンの位置がずれないよう、3行ぶんを確保する。
            ZStack(alignment: .top) {
                Text(verbatim: "\n\n")
                    .font(SM.f(12.5))
                    .lineSpacing(12)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)

                Text(bodyKey.loc)
                    .font(SM.f(12.5))
                    .lineSpacing(12)
                    .foregroundStyle(SM.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Text(ctaKey.loc)
                    .font(SM.f(14.5, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(SM.indigo, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .coachAnchor(ifSet: ctaCoachTarget)
            .padding(.top, 6)

            // 副次の導線が無い画面でも、ブロック全体の中心がずれないよう場所は空けておく。
            Group {
                if let secondaryKey, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryKey.loc)
                            .font(SM.f(12))
                            .foregroundStyle(SM.sub)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .coachAnchor(ifSet: secondaryCoachTarget)
                } else {
                    Text(verbatim: " ").font(SM.f(12)).hidden()
                }
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 絵柄

/// ホーム：点線の角丸タイルに ¥（design 4a）。
struct EmptyYenTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(SM.border2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .frame(width: 96, height: 96)
            .overlay(Text(verbatim: "¥").font(SM.f(30)).foregroundStyle(SM.dim))
    }
}

/// 集計：伸びていく棒グラフの影（design 4c）。
struct EmptyBarsGlyph: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach([26.0, 46.0, 66.0], id: \.self) { height in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(SM.sub)
                    .frame(width: 22, height: height)
            }
        }
        .frame(height: 78, alignment: .bottom)
        .opacity(0.3)
    }
}

/// 通知：予定が並ぶ様子の影（design 4e）。
struct EmptyLinesGlyph: View {
    var body: some View {
        VStack(spacing: 9) {
            ForEach([1.0, 0.78, 0.52], id: \.self) { ratio in
                Capsule()
                    .fill(SM.sub)
                    .frame(width: 132 * ratio, height: 11)
                    .frame(width: 132, alignment: .leading)
            }
        }
        .opacity(0.3)
    }
}
