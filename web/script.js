"use strict";

// ── Translations ─────────────────────────────────────────────────────────────

const translations = {
  ja: {
    page_title: "サブメモ - サブスクの請求額と更新日をまとめるアプリ",
    meta_description:
      "サブメモは、契約中のサブスクを手で書き留めて、今月いくら払っているかと次の更新日を1画面で見られる iPhone アプリです。無料トライアルの終了も更新の数日前もロック画面に通知します。銀行やカードには繋ぎません。",
    app_name: "サブメモ",
    nav_features: "機能",
    nav_screenshots: "スクリーンショット",
    nav_download: "ダウンロード",
    nav_privacy: "プライバシー",
    nav_contact: "お問い合わせ",
    hero_title_line1: "サブスク、",
    hero_title_line2: "いくら払っているか言えますか。",
    hero_description:
      "サブメモは、契約中のサブスクを手で書き留めて、今月いくら払っているかと次の更新日を1画面で見られる iPhone アプリです。無料トライアルの終了も、更新の数日前も、ロック画面に通知します。銀行やカードには繋ぎません。",
    hero_download_button: "App Store でダウンロード",
    hero_features_button: "機能を見る",
    features_title: "主な機能",
    feature_capture_title: "サービス名を入れるだけ",
    feature_capture_text:
      "主要なサービスを候補として持っているので、名前を選べば料金と更新サイクルが入ります。一覧にないものは手で追加できます。",
    feature_total_title: "今月・年額・1日あたり",
    feature_total_text:
      "今月の請求額を大きく表示。金額をタップすると年額換算・1日あたりに切り替わります。年払いは月割りにして並べて見られます。",
    feature_trial_title: "無料トライアルの終了通知",
    feature_trial_text:
      "終了の数日前に最優先で通知し、ロック画面にも表示します。本文に金額と日付が入るので、開かなくても判断できます。",
    feature_timeline_title: "これからの予定",
    feature_timeline_text:
      "更新日とトライアル終了日を近い順に一覧。何日前に知らせるかは 7 日前・3 日前・前日・当日から選べ、「あとで」で再通知もできます。",
    feature_stats_title: "カテゴリ別の内訳",
    feature_stats_text:
      "動画・音楽・クラウドなどカテゴリごとの割合と金額を集計。カテゴリをタップすれば、その中身の一覧が開きます。",
    feature_cancel_title: "解約シミュレーション",
    feature_cancel_text:
      "使っていない印をつけたものをまとめて、解約したら年いくら浮くかを計算。対象はタップで出し入れできます。",
    feature_fx_title: "外貨のサブスクも円で",
    feature_fx_text:
      "USD・EUR 建ての料金を円に換算して合計に含めます。レートは欧州中央銀行の公表値を自動取得。手動で決めることもできます。",
    feature_icloud_title: "iCloud 同期",
    feature_icloud_text:
      "登録内容を iCloud Key-Value Store 経由で端末間ミラーリング。機種変更や再インストールでも続きから使えます。オフにもできます。",
    feature_csv_title: "CSV で書き出し",
    feature_csv_text:
      "期間と列を選んで CSV に書き出せます。UTF-8（BOM つき）なので、Excel やスプレッドシートでそのまま開けます。",
    feature_privacy_title: "銀行にもカードにも繋がない",
    feature_privacy_text:
      "明細を読み取る仕組みは持ちません。登録内容は端末内に保存され、当方のサーバーには一切送信されません。アカウント登録も不要です。",
    screenshots_title: "スクリーンショット",
    screenshots_home_title: "ホーム",
    screenshots_home_text: "今月の請求額と契約中の一覧",
    screenshots_stats_title: "集計と見直し",
    screenshots_stats_text: "カテゴリ内訳と、使っていないものの洗い出し",
    screenshots_notif_title: "これからの予定",
    screenshots_notif_text: "更新日とトライアル終了日を近い順に",
    screenshots_detail_title: "詳細",
    screenshots_detail_text: "料金・カテゴリ・支払い方法をその場で編集",
    download_title: "ダウンロード",
    download_heading: "App Store で今すぐダウンロード",
    download_subheading: "iOS 26.0 以降に対応しています。",
    download_button: "App Store でダウンロード",
    download_requirements_title: "システム要件",
    download_requirements_ios: "iOS 26.0 以降",
    download_requirements_devices: "iPhone 専用・縦向き",
    download_requirements_price: "無料ダウンロード",
    privacy_title: "プライバシーポリシー",
    privacy_handling_heading: "個人情報の取り扱いについて",
    privacy_handling_text:
      "サブメモはユーザーのプライバシーを尊重し、個人情報の保護に努めています。",
    privacy_collect_heading: "収集する情報",
    privacy_collect_text:
      "アプリが個人情報を当方のサーバーに送信して収集することはありません。アカウント登録もなく、利用状況の解析や広告のための計測も行いません。",
    privacy_bank_heading: "銀行口座・クレジットカードとの連携について",
    privacy_bank_text:
      "サブメモは銀行口座やクレジットカードの明細を読み取る仕組みを一切持ちません。登録されるサブスクの内容は、すべてユーザーが自分で入力したものです。",
    privacy_storage_heading: "情報の保存",
    privacy_storage_text:
      "サブスク・カテゴリ・支払い方法・設定はすべて端末内（UserDefaults）に保存され、当方のサーバーには送信されません。任意で iCloud 同期を有効にした場合、データは Apple の iCloud Key-Value Store を介してユーザー本人の iCloud アカウント領域にのみミラーされ、当方からはアクセスできません。",
    privacy_network_heading: "外部との通信",
    privacy_network_text:
      "外貨建てのサブスクを円に換算するため、為替レートの取得時のみ外部の公開 API（api.frankfurter.app／欧州中央銀行の公表値）へ通信します。送信するのは通貨コードだけで、登録内容や端末を識別する情報は一切含みません。この通信はレートの自動更新を「手動」に設定すれば行われません。",
    privacy_notifications_heading: "通知について",
    privacy_notifications_text:
      "更新前とトライアル終了の通知は、すべて端末内のローカル通知として処理され、当方のサーバーやプッシュ通知サービスは経由しません。通知の許可はいつでも iOS の設定から変更できます。",
    privacy_export_heading: "書き出したデータ",
    privacy_export_text:
      "CSV の書き出しでは、端末内にファイルを作成して iOS の共有画面に渡します。保存先や送信先を決めるのはユーザーで、当方が内容を受け取ることはありません。",
    privacy_sharing_heading: "第三者との共有",
    privacy_sharing_text:
      "当方がユーザーの情報を第三者と共有することはありません。",
    privacy_trademark_heading: "サービス名について",
    privacy_trademark_text:
      "アプリ内に表示される各サービス名および商標は、各権利者に帰属します。本アプリはこれらのサービスと提携・関連するものではありません。",
    privacy_contact_heading: "お問い合わせ",
    privacy_contact_text_before: "プライバシーポリシーに関するご質問は、",
    privacy_contact_link: "お問い合わせ",
    privacy_contact_text_after: "までご連絡ください。",
    privacy_update: "最終更新: 2026 年 8 月",
    contact_title: "お問い合わせ",
    contact_intro:
      "アプリに関するご質問、バグ報告、機能要望などがございましたら、お気軽にお問い合わせください。",
    contact_email_heading: "📧 メール",
    contact_bug_heading: "🐛 バグ報告",
    contact_bug_text:
      "アプリ内の不具合や問題を発見された場合は、上記メールアドレスまで詳細をお送りください。",
    contact_feature_heading: "💡 機能要望",
    contact_feature_text:
      "対応してほしいサービスの候補や、新しい機能のご要望もお待ちしています。",
    footer_copyright: "© 2026 サブメモ. All rights reserved.",
  },

  en: {
    page_title: "Submemo - Keep every subscription and renewal in one place",
    meta_description:
      "Submemo is an iPhone app for tracking the subscriptions you already pay for. Add them by hand and see this month's total and the next renewal on one screen, with Lock Screen alerts before a free trial ends. It never connects to your bank or card.",
    app_name: "Submemo",
    nav_features: "Features",
    nav_screenshots: "Screenshots",
    nav_download: "Download",
    nav_privacy: "Privacy",
    nav_contact: "Contact",
    hero_title_line1: "Subscriptions.",
    hero_title_line2: "Could you name what they cost?",
    hero_description:
      "Submemo is an iPhone app for tracking the subscriptions you already pay for. Add them by hand and see this month's total and the next renewal on one screen. It warns you before a free trial ends and a few days before each renewal — on the Lock Screen. It never connects to your bank or card.",
    hero_download_button: "Download on the App Store",
    hero_features_button: "View features",
    features_title: "Main features",
    feature_capture_title: "Just type the service name",
    feature_capture_text:
      "A built-in catalog of common services fills in the price and billing cycle for you. Anything not listed can be added by hand.",
    feature_total_title: "This month, per year, per day",
    feature_total_text:
      "This month's bill up front. Tap the amount to switch to the yearly equivalent or the daily cost. Yearly plans are shown split by month too.",
    feature_trial_title: "Free-trial alerts",
    feature_trial_text:
      "A top-priority alert a few days before a trial ends, shown on the Lock Screen. The amount and date are in the text, so you can decide without opening it.",
    feature_timeline_title: "What's coming",
    feature_timeline_text:
      "Renewals and trial end dates listed soonest first. Choose 7 days, 3 days, the day before, or same day — and snooze with “Later”.",
    feature_stats_title: "Category breakdown",
    feature_stats_text:
      "See the share and amount per category — video, music, cloud and more. Tap a category to open everything inside it.",
    feature_cancel_title: "Cancellation estimate",
    feature_cancel_text:
      "Group the ones you marked as unused and see what cancelling would save you in a year. Tap to include or exclude each one.",
    feature_fx_title: "Foreign currency, converted",
    feature_fx_text:
      "USD and EUR prices are converted to yen and included in the total. Rates come from the European Central Bank automatically, or you can set them yourself.",
    feature_icloud_title: "iCloud sync",
    feature_icloud_text:
      "Your entries mirror across devices via iCloud Key-Value Store, so you pick up where you left off after a new phone or reinstall. You can turn it off.",
    feature_csv_title: "CSV export",
    feature_csv_text:
      "Pick a period and the columns you want. The file is UTF-8 with a BOM, so it opens straight in Excel or a spreadsheet.",
    feature_privacy_title: "No bank, no card. Ever.",
    feature_privacy_text:
      "There is no statement-reading machinery here. What you add stays on your device and is never sent to our servers. No account required.",
    screenshots_title: "Screenshots",
    screenshots_home_title: "Home",
    screenshots_home_text: "This month's bill and everything active",
    screenshots_stats_title: "Stats & review",
    screenshots_stats_text:
      "Category breakdown, plus what you're not using",
    screenshots_notif_title: "What's coming",
    screenshots_notif_text: "Renewals and trial end dates, soonest first",
    screenshots_detail_title: "Details",
    screenshots_detail_text:
      "Edit the price, category, and payment method in place",
    download_title: "Download",
    download_heading: "Download now on the App Store",
    download_subheading: "Requires iOS 26.0 or later.",
    download_button: "Download on the App Store",
    download_requirements_title: "System requirements",
    download_requirements_ios: "iOS 26.0 or later",
    download_requirements_devices: "iPhone only, portrait",
    download_requirements_price: "Free download",
    privacy_title: "Privacy Policy",
    privacy_handling_heading: "How we handle personal information",
    privacy_handling_text:
      "Submemo respects your privacy and is committed to protecting your personal information.",
    privacy_collect_heading: "Information we collect",
    privacy_collect_text:
      "The app never sends personal information to our servers. There is no account to create, and no analytics or advertising measurement.",
    privacy_bank_heading: "About bank and credit card connections",
    privacy_bank_text:
      "Submemo has no mechanism for reading bank or credit card statements. Everything recorded in the app is entered by you.",
    privacy_storage_heading: "Where your data is stored",
    privacy_storage_text:
      "Subscriptions, categories, payment methods, and settings are all stored on your device (UserDefaults) and are never sent to our servers. If you turn on iCloud sync, the data is mirrored only into your own iCloud account area through Apple's iCloud Key-Value Store, which we cannot access.",
    privacy_network_heading: "Network access",
    privacy_network_text:
      "To convert foreign-currency subscriptions into yen, the app contacts a public API (api.frankfurter.app, which publishes European Central Bank reference rates) — and only when fetching a rate. The request contains currency codes alone: none of your entries and nothing identifying your device. Setting rate updates to “Manual” stops this request entirely.",
    privacy_notifications_heading: "Notifications",
    privacy_notifications_text:
      "Renewal and trial-end alerts are handled entirely as local notifications on your device. They never pass through our servers or a push notification service. You can change the permission any time in iOS Settings.",
    privacy_export_heading: "Exported data",
    privacy_export_text:
      "CSV export writes a file on your device and hands it to the iOS share sheet. You choose where it goes; we never receive its contents.",
    privacy_sharing_heading: "Sharing with third parties",
    privacy_sharing_text:
      "We do not share your information with any third party.",
    privacy_trademark_heading: "About service names",
    privacy_trademark_text:
      "Service names and trademarks shown in the app belong to their respective owners. This app is not affiliated with or endorsed by any of them.",
    privacy_contact_heading: "Contact",
    privacy_contact_text_before:
      "For questions about this privacy policy, please ",
    privacy_contact_link: "get in touch",
    privacy_contact_text_after: ".",
    privacy_update: "Last updated: August 2026",
    contact_title: "Contact",
    contact_intro:
      "If you have questions, bug reports, or feature requests about the app, feel free to reach out.",
    contact_email_heading: "📧 Email",
    contact_bug_heading: "🐛 Bug reports",
    contact_bug_text:
      "Found a bug or something behaving oddly? Send the details to the address above.",
    contact_feature_heading: "💡 Feature requests",
    contact_feature_text:
      "Services you'd like added to the catalog, or ideas for new features — both are welcome.",
    footer_copyright: "© 2026 Submemo. All rights reserved.",
  },
};

// ── Language ──────────────────────────────────────────────────────────────────

function detectLanguage() {
  const params = new URLSearchParams(window.location.search);
  if (params.has("lang")) return params.get("lang");
  const stored = localStorage.getItem("lang");
  if (stored) return stored;
  const browser = navigator.language || navigator.userLanguage || "ja";
  return browser.startsWith("ja") ? "ja" : "en";
}

function applyLanguage(lang) {
  const t = translations[lang] || translations["ja"];

  document.title = t["page_title"] || document.title;
  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) metaDesc.setAttribute("content", t["meta_description"] || "");

  document.documentElement.lang = lang;

  document.querySelectorAll("[data-i18n-key]").forEach((el) => {
    const key = el.getAttribute("data-i18n-key");
    if (t[key] !== undefined) {
      el.textContent = t[key];
    }
  });

  document.querySelectorAll("img[data-src-ja]").forEach((img) => {
    const src = lang === "ja" ? img.dataset.srcJa : img.dataset.srcEn;
    if (src) img.src = src;
  });

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.lang === lang);
  });

  localStorage.setItem("lang", lang);
}

// ── Scroll & Header ───────────────────────────────────────────────────────────

function initHeader() {
  const header = document.querySelector(".header");
  if (!header) return;

  let lastScrollY = window.scrollY;

  window.addEventListener(
    "scroll",
    () => {
      const currentScrollY = window.scrollY;
      if (currentScrollY > lastScrollY && currentScrollY > 100) {
        header.style.transform = "translateY(-100%)";
      } else {
        header.style.transform = "translateY(0)";
      }
      lastScrollY = currentScrollY;
    },
    { passive: true },
  );

  header.style.transition = "transform 0.3s ease";
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", (e) => {
      const targetId = anchor.getAttribute("href");
      if (targetId === "#") return;
      const target = document.querySelector(targetId);
      if (!target) return;
      e.preventDefault();
      const headerHeight =
        document.querySelector(".header")?.offsetHeight ?? 70;
      const top =
        target.getBoundingClientRect().top + window.scrollY - headerHeight;
      window.scrollTo({ top, behavior: "smooth" });
    });
  });
}

// ── Intersection Observer (fade-in) ──────────────────────────────────────────

function initFadeIn() {
  const targets = document.querySelectorAll(
    ".feature-card, .screenshot-item, .download-content, .privacy-content, .contact-method",
  );

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("fade-in-up");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 },
  );

  targets.forEach((el) => {
    el.style.opacity = "0";
    observer.observe(el);
  });

  document.addEventListener("animationstart", (e) => {
    if (e.animationName === "fadeInUp") {
      e.target.style.opacity = "";
    }
  });
}

// ── Ripple on buttons ─────────────────────────────────────────────────────────

function initRipple() {
  document.querySelectorAll(".btn, .app-store-placeholder").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      const rect = btn.getBoundingClientRect();
      const ripple = document.createElement("span");
      const size = Math.max(rect.width, rect.height);
      ripple.style.cssText = `
        position:absolute;width:${size}px;height:${size}px;
        left:${e.clientX - rect.left - size / 2}px;
        top:${e.clientY - rect.top - size / 2}px;
        background:rgba(255,255,255,0.25);border-radius:50%;
        transform:scale(0);animation:ripple 0.5s linear;pointer-events:none;
      `;
      btn.style.position = "relative";
      btn.style.overflow = "hidden";
      btn.appendChild(ripple);
      ripple.addEventListener("animationend", () => ripple.remove());
    });
  });

  const style = document.createElement("style");
  style.textContent = `@keyframes ripple{to{transform:scale(2.5);opacity:0}}`;
  document.head.appendChild(style);
}

// ── Lazy images ───────────────────────────────────────────────────────────────

function initLazyImages() {
  const images = document.querySelectorAll("img.lazy");
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const img = entry.target;
          img.src = img.dataset.src || img.src;
          img.classList.remove("lazy");
          observer.unobserve(img);
        }
      });
    });
    images.forEach((img) => observer.observe(img));
  }
}

// ── Parallax (hero) ───────────────────────────────────────────────────────────

function initParallax() {
  const hero = document.querySelector(".hero");
  if (!hero) return;
  window.addEventListener(
    "scroll",
    () => {
      const offset = window.scrollY * 0.3;
      hero.style.backgroundPositionY = `${offset}px`;
    },
    { passive: true },
  );
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  const lang = detectLanguage();
  applyLanguage(lang);

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.addEventListener("click", () => applyLanguage(btn.dataset.lang));
  });

  initHeader();
  initSmoothScroll();
  initFadeIn();
  initRipple();
  initLazyImages();
  initParallax();
});
