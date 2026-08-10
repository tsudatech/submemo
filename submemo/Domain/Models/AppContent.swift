//
//  AppContent.swift
//  submemo
//
//  アプリに同梱する静的コンテンツ。ユーザーのデータではないので永続化しない。
//  ・登録候補のカタログ（追加画面の検索元）
//  ・オンボーディングの3ページ
//  ・通知の文面プレビュー
//

import Foundation

// MARK: - 登録候補

nonisolated struct SeedService: Identifiable {
    let id: Int
    /// 日英で表記が変わるサービスだけローカライズキーを持つ。
    /// 大半（Netflix, Spotify …）は同じ綴りなので literal をそのまま出す。
    let nameKey: String?
    let literal: String
    /// かな・ローマ字の読み。日本語で検索したときに拾うための材料。
    let reading: String
    /// 請求単位の金額（cycle に対応）。currency の単位。
    let price: Int
    let currency: Currency
    let categoryID: String
    let cycle: Cycle

    init(_ id: Int, _ literal: String, key: String? = nil, reading: String,
         price: Int, currency: Currency = .JPY, category: String, cycle: Cycle = .month) {
        self.id = id
        self.literal = literal
        self.nameKey = key
        self.reading = reading
        self.price = price
        self.currency = currency
        self.categoryID = category
        self.cycle = cycle
    }

    var name: String { nameKey.map(TR) ?? literal }
    var initial: String { String(name.prefix(1)) }

    /// 候補一覧の右端に出す料金表記。
    var priceLabel: String {
        let amount = currency == .JPY
            ? Yen.text(Double(price))
            : currency.symbol + Yen.num(Double(price))
        return amount + TR(cycle == .year ? "per_year_suffix" : "per_month_suffix")
    }
}

// MARK: - 通知の文面プレビュー

/// 「実際に届く文面」1件。登録内容から組み立てるので、文言は保持せず結果だけ持つ。
nonisolated struct NotifPreview: Identifiable {
    /// 種類（更新前・トライアル・当日）。並びも兼ねる。
    /// 実際に予約する種類だけを持つ。増やすときは NotificationScheduler 側も一緒に。
    enum Kind: String, CaseIterable {
        case renewal, trial, today

        var tagKey: String { "msg_tag_\(rawValue)" }
        var colorHex: UInt {
            switch self {
            case .renewal: return 0x5B7CFA
            case .trial:   return 0xFF5C5C
            case .today:   return 0x8B93A2
            }
        }
    }

    let kind: Kind
    let title: String
    let body: String
    let action: String
    /// タップで開く対象。月次サマリーなど対象が無いものは nil。
    let subscriptionID: UUID?

    var id: String { kind.rawValue }
    var tagKey: String { kind.tagKey }
    var colorHex: UInt { kind.colorHex }
}

// MARK: - オンボーディング

nonisolated struct OnboardPage: Identifiable {
    let id: Int
    let titleKey: String
    let bodyKey: String
    let ctaKey: String
}

enum AppContent {

    /// 追加画面の「よく使われているサービス」。
    ///
    /// 料金は日本での代表的なプランの目安（税込・2026年時点）で、あくまで初期値。
    /// 選んだあとの確認画面でいくらでも直せるので、プランの細かい違いまでは並べない。
    /// reading は日本語で検索したときに拾うための材料（かな・カナ・ローマ字）。
    /// 並び順は「よく使われている」順で、検索していないときは先頭から出す。
    nonisolated static let catalog: [SeedService] = [
        // ── 動画 ──────────────────────────────────────────────
        SeedService(1,  "Netflix",              reading: "ねっとふりっくす ネットフリックス netflix",             price: 1590, category: "video"),
        SeedService(2,  "YouTube Premium",      reading: "ゆーちゅーぶ ユーチューブ youtube premium",             price: 1280, category: "video"),
        SeedService(3,  "Disney+",              reading: "でぃずにー ディズニープラス disney plus",               price: 1140, category: "video"),
        SeedService(4,  "U-NEXT",               reading: "ゆーねくすと ユーネクスト unext u-next",                price: 2189, category: "video"),
        SeedService(5,  "Hulu",                 reading: "ふーるー フールー hulu",                               price: 1026, category: "video"),
        SeedService(6,  "Prime Video",          key: "svc_primevideo", reading: "ぷらいむびでお プライムビデオ amazon prime video", price: 600, category: "video"),
        SeedService(7,  "DAZN",                 reading: "だぞーん ダゾーン dazn",                               price: 4200, category: "video"),
        SeedService(8,  "ABEMA",                key: "svc_abema", reading: "あべま アベマ abema premium",         price: 1080, category: "video"),
        SeedService(9,  "Apple TV+",            reading: "あっぷるてぃーびー アップルティービー apple tv",         price: 900,  category: "video"),
        SeedService(10, "dアニメストア",          key: "svc_danime", reading: "でぃーあにめ ディーアニメ danime anime", price: 550, category: "video"),
        SeedService(11, "Lemino",               key: "svc_lemino", reading: "れみの レミノ lemino",                price: 990,  category: "video"),
        SeedService(12, "FOD",                  key: "svc_fod", reading: "えふおーでぃー フジテレビ fod",           price: 976,  category: "video"),
        SeedService(13, "WOWOW",                key: "svc_wowow", reading: "わうわう ワウワウ wowow",              price: 2530, category: "video"),
        SeedService(14, "NHKオンデマンド",        key: "svc_nhk", reading: "えぬえいちけー エヌエイチケー nhk",       price: 990,  category: "video"),
        SeedService(15, "TELASA",               reading: "てらさ テラサ telasa",                                 price: 618,  category: "video"),
        SeedService(16, "Crunchyroll",          reading: "くらんちろーる クランチロール crunchyroll",             price: 990,  category: "video"),

        // ── 音楽 ──────────────────────────────────────────────
        SeedService(20, "Spotify Premium",      reading: "すぽてぃふぁい スポティファイ spotify",                 price: 1080, category: "music"),
        SeedService(21, "Apple Music",          reading: "あっぷるみゅーじっく アップルミュージック apple music",   price: 1080, category: "music"),
        SeedService(22, "Amazon Music Unlimited", reading: "あまぞんみゅーじっく アマゾンミュージック amazon music", price: 1080, category: "music"),
        SeedService(23, "YouTube Music Premium", reading: "ゆーちゅーぶみゅーじっく ユーチューブミュージック youtube music", price: 1080, category: "music"),
        SeedService(24, "LINE MUSIC",           reading: "らいんみゅーじっく ラインミュージック line music",       price: 1080, category: "music"),
        SeedService(25, "AWA",                  reading: "あわ アワ awa",                                        price: 980,  category: "music"),
        SeedService(26, "KKBOX",                reading: "けーけーぼっくす ケーケーボックス kkbox",                price: 980,  category: "music"),

        // ── クラウド ──────────────────────────────────────────
        SeedService(30, "iCloud+ 50GB",         reading: "あいくらうど アイクラウド icloud",                      price: 130,  category: "cloud"),
        SeedService(31, "iCloud+ 200GB",        reading: "あいくらうど アイクラウド icloud",                      price: 450,  category: "cloud"),
        SeedService(32, "iCloud+ 2TB",          reading: "あいくらうど アイクラウド icloud",                      price: 1500, category: "cloud"),
        SeedService(33, "Google One 100GB",     reading: "ぐーぐるわん グーグルワン google one",                   price: 250,  category: "cloud"),
        SeedService(34, "Google One 2TB",       reading: "ぐーぐるわん グーグルワン google one",                   price: 1300, category: "cloud"),
        SeedService(35, "Dropbox Plus",         reading: "どろっぷぼっくす ドロップボックス dropbox",              price: 1500, category: "cloud"),
        SeedService(36, "Microsoft 365 Personal", reading: "まいくろそふと マイクロソフト microsoft office",       price: 1490, category: "cloud"),
        SeedService(37, "OneDrive 100GB",       reading: "わんどらいぶ ワンドライブ onedrive",                     price: 260,  category: "cloud"),

        // ── ゲーム ────────────────────────────────────────────
        SeedService(40, "Nintendo Switch Online", key: "svc_switch", reading: "にんてんどう ニンテンドー nintendo switch", price: 2400, category: "game", cycle: .year),
        SeedService(41, "Nintendo Switch Online + 追加パック", key: "svc_switch_pack", reading: "にんてんどう ニンテンドー nintendo switch", price: 4900, category: "game", cycle: .year),
        SeedService(42, "PlayStation Plus",     reading: "ぷれすて プレステ playstation psplus",                  price: 850,  category: "game"),
        SeedService(43, "Xbox Game Pass Ultimate", reading: "えっくすぼっくす エックスボックス xbox game pass",     price: 1850, category: "game"),
        SeedService(44, "Apple Arcade",         reading: "あっぷるあーけーど アップルアーケード apple arcade",      price: 900,  category: "game"),
        SeedService(45, "EA Play",              reading: "いーえーぷれい イーエープレイ ea play",                  price: 580,  category: "game"),

        // ── 学習 ──────────────────────────────────────────────
        SeedService(50, "ChatGPT Plus",         reading: "ちゃっとじーぴーてぃー チャットジーピーティー chatgpt openai", price: 20, currency: .USD, category: "learning"),
        SeedService(51, "Claude Pro",           reading: "くろーど クロード claude anthropic",                     price: 20, currency: .USD, category: "learning"),
        SeedService(52, "Perplexity Pro",       reading: "ぱーぷれきしてぃ パープレキシティ perplexity",            price: 20, currency: .USD, category: "learning"),
        SeedService(53, "Google AI Pro",        reading: "じぇみに ジェミニ gemini google ai",                     price: 2900, category: "learning"),
        SeedService(54, "日経電子版",             key: "svc_nikkei", reading: "にっけい ニッケイ nikkei にほんけいざい", price: 4277, category: "learning"),
        SeedService(55, "NewsPicks",            reading: "にゅーずぴっくす ニューズピックス newspicks",             price: 1850, category: "learning"),
        SeedService(56, "Kindle Unlimited",     reading: "きんどる キンドル kindle unlimited",                     price: 980,  category: "learning"),
        SeedService(57, "Audible",              reading: "おーでぃぶる オーディブル audible",                      price: 1500, category: "learning"),
        SeedService(58, "Duolingo Super",       reading: "でゅおりんご デュオリンゴ duolingo",                     price: 1100, category: "learning"),
        SeedService(59, "スタディサプリ",          key: "svc_studysapuri", reading: "すたでぃさぷり スタディサプリ studysapuri", price: 2178, category: "learning"),
        SeedService(60, "dマガジン",              key: "svc_dmagazine", reading: "でぃーまがじん ディーマガジン dmagazine", price: 580, category: "learning"),
        SeedService(61, "楽天マガジン",           key: "svc_rakutenmagazine", reading: "らくてんまがじん ラクテンマガジン rakuten magazine", price: 572, category: "learning"),

        // ── 通信 ──────────────────────────────────────────────
        SeedService(70, "楽天モバイル",           key: "svc_rakutenmobile", reading: "らくてんもばいる ラクテンモバイル rakuten mobile", price: 3278, category: "telecom"),
        SeedService(71, "ahamo",                reading: "あはも アハモ ahamo docomo",                            price: 2970, category: "telecom"),
        SeedService(72, "LINEMO",               reading: "らいんも ラインモ linemo",                              price: 2728, category: "telecom"),
        SeedService(73, "UQ mobile",            reading: "ゆーきゅー ユーキュー uq mobile",                        price: 2728, category: "telecom"),
        SeedService(74, "Y!mobile",             reading: "わいもばいる ワイモバイル ymobile",                      price: 2365, category: "telecom"),
        SeedService(75, "IIJmio",               reading: "あいあいじぇい アイアイジェイ iijmio",                    price: 2000, category: "telecom"),
        SeedService(76, "mineo",                reading: "まいねお マイネオ mineo",                                price: 1958, category: "telecom"),
        SeedService(77, "NURO 光",               key: "svc_nuro", reading: "にゅーろひかり ニューロヒカリ nuro",     price: 5200, category: "telecom"),
        SeedService(78, "ドコモ光",               key: "svc_docomohikari", reading: "どこもひかり ドコモヒカリ docomo hikari", price: 5720, category: "telecom"),
        SeedService(79, "SoftBank 光",           key: "svc_softbankhikari", reading: "そふとばんくひかり ソフトバンクヒカリ softbank hikari", price: 5720, category: "telecom"),
        SeedService(80, "auひかり",               key: "svc_auhikari", reading: "えーゆーひかり エーユーヒカリ au hikari", price: 5610, category: "telecom"),

        // ── 生活 ──────────────────────────────────────────────
        SeedService(90, "Amazon プライム",        key: "svc_amazon", reading: "あまぞんぷらいむ アマゾンプライム amazon prime", price: 5900, category: "life", cycle: .year),
        SeedService(91, "chocoZAP",             reading: "ちょこざっぷ チョコザップ chocozap",                     price: 3278, category: "life"),
        SeedService(92, "エニタイムフィットネス",   key: "svc_gym", reading: "えにたいむ エニタイム anytime fitness", price: 7480, category: "life"),
        SeedService(93, "ゴールドジム",           key: "svc_goldsgym", reading: "ごーるどじむ ゴールドジム golds gym", price: 12000, category: "life"),
        SeedService(94, "コナミスポーツクラブ",     key: "svc_konami", reading: "こなみ コナミ konami sports",        price: 9000, category: "life"),
        SeedService(95, "Uber One",              reading: "うーばー ウーバー uber one eats",                        price: 498,  category: "life"),
        SeedService(96, "Oisix",                 reading: "おいしっくす オイシックス oisix",                        price: 1980, category: "life"),
        SeedService(97, "タイムズカー",            key: "svc_timescar", reading: "たいむず タイムズ times car share", price: 880,  category: "life"),
        SeedService(98, "JAF",                   reading: "じぇーえーえふ ジェーエーエフ jaf",                       price: 4000, category: "life", cycle: .year),

        // ── その他 ────────────────────────────────────────────
        SeedService(110, "Adobe フォトプラン",     key: "svc_adobe", reading: "あどび アドビ adobe photoshop lightroom", price: 1180, category: "other"),
        SeedService(111, "Adobe Creative Cloud", reading: "あどび アドビ adobe creative cloud",                    price: 7780, category: "other"),
        SeedService(112, "Canva Pro",            reading: "きゃんば キャンバ canva",                               price: 1500, category: "other"),
        SeedService(113, "Figma Professional",   reading: "ふぃぐま フィグマ figma",                               price: 15, currency: .USD, category: "other"),
        SeedService(114, "Notion Plus",          reading: "のーしょん ノーション notion",                          price: 10, currency: .USD, category: "other"),
        SeedService(115, "Evernote Personal",    reading: "えばーのーと エバーノート evernote",                     price: 1100, category: "other"),
        SeedService(116, "1Password",            reading: "わんぱすわーど ワンパスワード 1password",                price: 3,  currency: .USD, category: "other"),
        SeedService(117, "Dropbox Sign",         reading: "どろっぷぼっくす ドロップボックス dropbox sign",          price: 2000, category: "other"),
        SeedService(118, "Zoom Pro",             reading: "ずーむ ズーム zoom",                                    price: 2125, category: "other"),
        SeedService(119, "X Premium",            reading: "えっくす エックス x twitter premium",                   price: 1380, category: "other"),
        SeedService(120, "Discord Nitro",        reading: "でぃすこーど ディスコード discord nitro",                price: 1050, category: "other"),
        SeedService(121, "Apple One",            reading: "あっぷるわん アップルワン apple one",                    price: 1200, category: "other"),
        SeedService(122, "Yahoo!プレミアム",       key: "svc_yahoopremium", reading: "やふー ヤフー yahoo premium",   price: 508,  category: "other"),
        SeedService(123, "LINEスタンプ プレミアム", key: "svc_linesticker", reading: "らいんすたんぷ ラインスタンプ line sticker", price: 240, category: "other"),
        SeedService(124, "note プレミアム",         key: "svc_note", reading: "のーと ノート note premium",           price: 500,  category: "other"),
        SeedService(125, "少年ジャンプ+",           key: "svc_jump", reading: "じゃんぷ ジャンプ jump shonen",        price: 980,  category: "other"),
    ]

    /// 検索していないときに出す「よく使われているサービス」。
    /// カタログはカテゴリ順に並べているので、そのまま先頭を取ると動画ばかりになる。
    /// ここで分野をまたいだ代表例を選んでおく。
    nonisolated static let popular: [SeedService] = {
        let ids = [1, 20, 90, 2, 50, 31, 3, 70]
        return ids.compactMap { id in catalog.first { $0.id == id } }
    }()

    /// オンボーディング。
    nonisolated static let onboarding: [OnboardPage] = [
        OnboardPage(id: 0, titleKey: "ob1_title", bodyKey: "ob1_body", ctaKey: "ob_next"),
        OnboardPage(id: 1, titleKey: "ob2_title", bodyKey: "ob2_body", ctaKey: "ob_next"),
        OnboardPage(id: 2, titleKey: "ob3_title", bodyKey: "ob3_body", ctaKey: "ob_start"),
    ]

}
