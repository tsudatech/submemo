//
//  CoachMark.swift
//  submemo
//
//  その画面をはじめて開いたときに出すガイド（コーチマーク方式）。
//  対象の要素だけを明るく残して暗幕をくり抜き、そこに吹き出しを添える。
//  shoplist の Onboarding.swift を土台に、SM の配色へ移植した。
//
//  ハイライトしたい要素には .coachAnchor(_:) を付ける。位置は anchorPreference で
//  画面の外まで伝わるので、暗幕はタブバーを含む最前面（Navigation 側）で重ねている。
//

import SwiftUI

// MARK: - ハイライト対象

enum CoachTarget: Hashable {
    /// 0件のとき
    case homeEmptyCta, statsEmptyCta, notifEmptySettings
    /// 登録があるとき
    case homeHero, statsCats, notifTimeline
}

struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>],
                       nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// この要素をガイドのハイライト対象として登録する。
    func coachAnchor(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [target: $0] }
    }

    /// 条件を満たすときだけ登録する。一覧の先頭行だけを対象にする、といった用途。
    @ViewBuilder
    func coachAnchorIf(_ target: CoachTarget, _ active: Bool) -> some View {
        if active { coachAnchor(target) } else { self }
    }

    /// 対象が指定されているときだけ登録する。共通部品に外から差し込むときに使う。
    @ViewBuilder
    func coachAnchor(ifSet target: CoachTarget?) -> some View {
        if let target { coachAnchor(target) } else { self }
    }
}

// MARK: - 暗幕のくり抜き

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle().overlay { mask().blendMode(.destinationOut) }
        }
    }
}

// MARK: - 吹き出しの三角

private struct Caret: Shape {
    var pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointingUp {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - スポットライト＋吹き出し

struct CoachSpotlight: View {
    let rect: CGRect
    let size: CGSize
    let text: String
    var cornerRadius: CGFloat = 18
    /// ハイライトの下端を詰める量。中身より下に伸びて見えるときに使う。
    var bottomTrim: CGFloat = 0
    var onDone: () -> Void

    /// 吹き出しの高さ。文言の行数で変わるので測ってから位置を決める。
    @State private var bubbleHeight: CGFloat = 120

    private struct BubbleHeightKey: PreferenceKey {
        static var defaultValue: CGFloat { 0 }
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var hole: CGRect {
        var r = rect.insetBy(dx: -8, dy: -8)
        r.size.height -= bottomTrim
        return r
    }

    /// 吹き出しをハイライトの上に出すか。下に置くと画面外やタブバーに掛かるときだけ上に回す。
    /// 位置を決め打ちにすると、空状態のように画面の真ん中が対象のとき、
    /// 上に出した吹き出しが見出しや別のボタンを隠してしまう。
    private var placeAbove: Bool {
        let tabBarRoom: CGFloat = 100
        return hole.maxY + 10 + bubbleHeight > size.height - tabBarRoom
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55).reverseMask { holeShape }
            holeShape
                .stroke(.white.opacity(0.9), lineWidth: 2)
            bubble
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // どこを触っても閉じる。
        .onTapGesture { onDone() }
        .transition(.opacity)
    }

    private var holeShape: some Shape {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: hole)
    }

    private var bubble: some View {
        let bubbleW: CGFloat = 276
        let cx = min(max(rect.midX, 20 + bubbleW / 2), size.width - 20 - bubbleW / 2)
        let caretDX = max(-bubbleW / 2 + 26, min(bubbleW / 2 - 26, rect.midX - cx))

        let caret = Caret(pointingUp: !placeAbove)
            .fill(SM.card)
            .frame(width: 18, height: 10)
            .offset(x: caretDX)

        let card = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(SM.indigo)
                Text(verbatim: text)
                    .font(SM.f(13.5, .medium))
                    .lineSpacing(6)
                    .foregroundStyle(SM.fg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer(minLength: 12)
                Button(action: onDone) {
                    Text("coach_done".loc)
                        .font(SM.f(11.5, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(SM.indigo, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: bubbleW)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SM.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(SM.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)

        return VStack(spacing: 0) {
            if placeAbove { card; caret } else { caret; card }
        }
        .background(
            GeometryReader { inner in
                Color.clear.preference(key: BubbleHeightKey.self, value: inner.size.height)
            }
        )
        .onPreferenceChange(BubbleHeightKey.self) { height in
            if height > 0 { bubbleHeight = height }
        }
        // position は中心指定なので、測った高さの半分だけずらして端を穴に寄せる。
        .position(x: cx,
                  y: placeAbove ? hole.minY - 10 - bubbleHeight / 2
                                : hole.maxY + 10 + bubbleHeight / 2)
    }
}
