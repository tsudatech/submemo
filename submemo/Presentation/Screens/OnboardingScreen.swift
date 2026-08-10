//
//  OnboardingScreen.swift
//  submemo
//
//  オンボーディング（3ページ）。「銀行にもカードにも繋がない」ことを最初に伝える。
//

import SwiftUI

struct OnboardingScreen: View {
    @EnvironmentObject private var store: AppStore

    private var page: OnboardPage { AppContent.onboarding[store.obIndex] }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 26) {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(SM.indigo)
                    .frame(width: 64, height: 64)
                    .overlay(Text(verbatim: "¥").font(SM.f(32, .bold)).foregroundStyle(.white))

                Text(page.titleKey.loc)
                    .font(SM.f(30, .bold))
                    .lineSpacing(11)
                    .foregroundStyle(SM.fg)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.bodyKey.loc)
                    .font(SM.f(14))
                    .lineSpacing(11)
                    .foregroundStyle(SM.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(AppContent.onboarding) { p in
                    Capsule()
                        .fill(p.id == store.obIndex ? SM.indigo : SM.border2)
                        .frame(width: p.id == store.obIndex ? 20 : 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 26)
            .animation(.easeOut(duration: 0.2), value: store.obIndex)

            Button {
                store.onboardNext()
            } label: {
                Text(page.ctaKey.loc)
                    .font(SM.f(15, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(SM.indigo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                store.goTab(.home)
            } label: {
                Text("ob_skip".loc)
                    .font(SM.f(13))
                    .foregroundStyle(SM.sub)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
    }
}
