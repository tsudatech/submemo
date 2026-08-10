# サブメモ — Marketing Site

サブメモ（iPhone 向けサブスク管理アプリ）の紹介ページ。HTML / CSS / Vanilla JS のみで構成された静的サイトで、GitHub Pages 等にそのままデプロイできる。

`tsudatech/tasks_web` の構成を踏襲し、配色をアプリの dark theme（`SM` の色トークン）と brand indigo (`#5B7CFA`) に合わせてある。

## ファイル

| ファイル | 役割 |
|---|---|
| `index.html` | セマンティック HTML。各テキストは `data-i18n-key` で多言語化対応 |
| `styles.css` | カラーパレット・レイアウト・レスポンシブ。primary は `#5B7CFA`、背景は dark (`#1B2129`) |
| `script.js` | 言語切替 (ja / en) ／ scroll ヘッダ ／ fade-in ／ ripple ／ lazy load ／ parallax |
| `images/app-icon.png` | hero と favicon に使う 1024×1024 のアプリアイコン（Assets からコピー） |

## スクリーンショット

`index.html` の Screenshots セクションは初期状態で `style="display: none"` で非表示。
実機スクショを用意したら以下に配置し、`<section class="screenshots" ...>` の `display: none` を外す。
あわせてヘッダのナビゲーション `nav_screenshots` の `<li style="display: none">` も外す。

```
images/ja/home.png    images/en/home.png
images/ja/stats.png   images/en/stats.png
images/ja/notif.png   images/en/notif.png
images/ja/detail.png  images/en/detail.png
```

シミュレータからの取得例：

```bash
xcrun simctl io booted screenshot web/images/ja/home.png
```

## ローカル確認

```bash
cd web
python3 -m http.server 8080
# http://localhost:8080
# 言語は ?lang=en で切り替えられる
```

## デプロイ (GitHub Pages の場合)

リポジトリ設定 → Pages → Source を `web` ディレクトリに向けるか、`web` 配下の中身を `gh-pages` ブランチへコピーする。

## 記載内容の根拠

プライバシーの記述はアプリの実装に合わせてある。変更したら追随させること。

| 記述 | 実装箇所 |
|---|---|
| 端末内に保存（UserDefaults） | `Data/Repositories/*` |
| iCloud Key-Value Store（任意） | `Data/Services/iCloudSyncManager.swift` |
| 外部通信は為替レートの取得のみ | `Data/Services/ExchangeRateService.swift` |
| 通知はすべてローカル通知 | `Data/Services/NotificationScheduler.swift` |
| CSV は共有シートに渡すだけ | `Domain/Stores/AppStore.swift` の `runCsvExport()` |

## 未確定の項目（公開前に差し替え）

- App Store のダウンロード URL（現状 `href="#"` のプレースホルダ）
- 最終更新日（`privacy_update`）とコピーライトの年
- スクリーンショット（未配置。セクションごと非表示にしてある）
