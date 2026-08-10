#!/usr/bin/env python3
"""App Store に出す紹介画像（コピー入り）を作る。

AppStore/mockup_alpha/<lang>/*.png（端末の透過 PNG）にコピーを載せ、
AppStore/store/<lang>/*.png へ 1320×2868 で書き出す。

    python3 AppStore/make_store.py

6 枚を同じ型で並べると単調なので、shoplist の dynamic セットと同じ考えで
抑揚を付けてある。

  - 背景を淡い／濃いで交互に切り替える（theme）
  - 1 枚だけコピーを下に置き、端末を上から見切れさせる（layout=bottom）
  - 1 枚は実画面から切り出した通知カードを浮かせる（float）

HTML を組み立てて Chrome の headless で撮っている。PIL で文字を置くより、
コピーの字送りや折り返しを直すのが楽なため。
"""

import http.server
import shutil
import socketserver
import subprocess
import threading
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
SHOTS = ROOT / "screenshots"
PARTS = ROOT / "parts"
DST = ROOT / "store"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CANVAS = (1320, 2868)
PORT = 8322

# 端末の表示幅。浮かせる部品の位置もこれを基準に決める。
PHONE_W = 1230
# .float の座標は PHONE_W = 1124 のときに合わせたもの。実幅に比例させる。
FLOAT_BASE = 1124

# 通知プレビューのカードが実画面のどこにあるか（1320×2868 のスクリーンショット内）。
NOTIF_CARD_BOX = (58, 1556, 1266, 1934)

# ── 載せる文言と、各ページの見せ方 ─────────────────────────────────────────
#   theme  : light（淡い背景・黒文字） / dark（indigo 背景・白文字）
#   layout : top（コピーが上、既定） / bottom（端末が上、コピーが下）
#   float  : 端末に重ねて浮かせる部品

PAGES = {
    "ja": [
        {
            "out": "00_title", "shot": "01_home", "kind": "title", "theme": "light",
            # タイトルだけ端末を少し小さく、上に寄せる。
            "phone": 1170, "gap": -20,
            "name": "サブメモ",
            "sub": "契約中のサブスクを、1画面で。",
            "pills": ["更新前に通知", "カテゴリ別に集計", "銀行に繋がない"],
        },
        {
            "out": "01_home", "shot": "01_home", "theme": "dark",
            "head": "毎月いくら払っているか<br>開いた瞬間に",
            "sub": "金額をタップすると、年額換算と1日あたりに変わります。",
        },
        {
            "out": "02_stats", "shot": "02_stats", "theme": "light", "layout": "bottom",
            # 見切れを浅くして、端末もコピーも少し下げる。
            "bleed": -200, "textgap": -44,
            "head": "何にいくら使っているか<br>カテゴリごとに",
            "sub": "使っていないものは、まとめて解約シミュレーション。",
        },
        {
            "out": "03_notif", "shot": "03_notif", "theme": "dark", "float": "notif_card",
            "head": "無料トライアルの終了を<br>見逃さない",
            "sub": "更新の数日前にも、金額と日付をロック画面でお知らせ。",
        },
        {
            "out": "04_detail", "shot": "04_detail", "theme": "light",
            "head": "このサブスク<br>年間いくら？",
            "sub": "値上げも記録に残るので、上がったことに気づけます。",
        },
        {
            "out": "05_add", "shot": "05_add", "theme": "dark",
            "head": "サービス名を<br>入れるだけ",
            "sub": "料金と更新日は候補から。銀行やカードには繋ぎません。",
        },
    ],
    "en": [
        {
            "out": "00_title", "shot": "01_home", "kind": "title", "theme": "light",
            "phone": 1170, "gap": -20,
            "name": "Submemo",
            "sub": "Every subscription, on one screen.",
            "pills": ["Renewal alerts", "By category", "No bank access"],
        },
        {
            "out": "01_home", "shot": "01_home", "theme": "dark",
            "head": "See what you pay<br>the moment you open it",
            "sub": "Tap the amount to switch to the yearly or daily figure.",
        },
        {
            "out": "02_stats", "shot": "02_stats", "theme": "light", "layout": "bottom",
            "bleed": -200, "textgap": -44,
            "head": "Where the money goes,<br>by category",
            "sub": "Then simulate cancelling everything you never use.",
        },
        {
            "out": "03_notif", "shot": "03_notif", "theme": "dark", "float": "notif_card",
            "head": "Never miss a free trial<br>ending again",
            "sub": "Plus the amount and date, days before each renewal.",
        },
        {
            "out": "04_detail", "shot": "04_detail", "theme": "light",
            "head": "What does this one<br>cost per year?",
            "sub": "Price changes are kept, so a hike never slips past you.",
        },
        {
            "out": "05_add", "shot": "05_add", "theme": "dark",
            "head": "Just type<br>the service name",
            "sub": "Price and date come from the suggestions. No bank access.",
        },
    ],
}

BRAND = {"ja": "サブメモ", "en": "Submemo"}
JA_FONT = '"Hiragino Sans", "Noto Sans JP", sans-serif'
EN_FONT = '-apple-system, "Helvetica Neue", "Inter", sans-serif'

STYLE = """
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  width: 1320px; height: 2868px; overflow: hidden;
  font-family: %(font)s;
  display: flex; flex-direction: column; align-items: center; text-align: center;
}
/* 淡い面。make_mockup.py の背景と同じで、並べたときに揃う。 */
body.light {
  background:
    radial-gradient(circle at 16%% 10%%, rgba(91,124,250,0.20) 0%%, transparent 46%%),
    radial-gradient(circle at 88%% 88%%, rgba(91,124,250,0.15) 0%%, transparent 44%%),
    linear-gradient(180deg, #F4F6FF 0%%, #E2E7FA 100%%);
  color: #141821;
}
/* 濃い面。淡い面と交互に並べて、一覧で見たときに単調にならないようにする。 */
body.dark {
  background:
    radial-gradient(circle at 20%% 8%%, rgba(255,255,255,0.20) 0%%, transparent 44%%),
    linear-gradient(165deg, #6D8BFF 0%%, #4460D8 58%%, #3A50BE 100%%);
  color: #FFFFFF;
}

.brand {
  /* 親が幅いっぱいの箱でも、内容ぶんの幅で中央に来るようにする。 */
  display: inline-block;
  margin-top: 104px; padding: 14px 30px; border-radius: 999px;
  font-size: %(brand)spx; font-weight: 700; letter-spacing: .02em;
}
body.light .brand { background: #5B7CFA; color: #fff; }
body.dark  .brand { background: rgba(255,255,255,0.94); color: #3E58CC; }

.icon {
  width: 208px; height: 208px; border-radius: 48px; margin-top: 84px;
  box-shadow: 0 26px 54px rgba(40,58,120,0.26);
}
h1 { margin-top: 36px; font-size: %(h1)spx; font-weight: 800; letter-spacing: .01em; }
h2 {
  margin-top: 28px; font-size: %(head)spx; font-weight: 800; line-height: 1.38;
  letter-spacing: .01em; text-wrap: %(wrap)s;
}
.sub {
  margin-top: 18px; font-size: %(sub)spx; font-weight: 600; line-height: 1.5;
  letter-spacing: .01em; max-width: %(subw)spx; text-wrap: %(wrap)s;
}
body.light .sub { color: #6B7280; }
body.dark  .sub { color: rgba(255,255,255,0.82); }

.pills { display: flex; gap: 18px; margin-top: 36px; }
.pills span {
  padding: 18px 30px; border-radius: 999px; background: #5B7CFA; color: #fff;
  font-size: %(pill)spx; font-weight: 700; box-shadow: 0 10px 26px rgba(91,124,250,0.34);
}

/* 端末は透過 PNG をそのまま置く。影は画像側に入っている。 */
.stage { position: relative; }
.phone { width: %(phone)spx; display: block; }
/* 実画面から切り出した通知カードを、画面内の同じカードにぴったり重ねて拡大する。
   ずらして置くと同じものが二重に見えるので、必ず元の位置へ被せる。 */
.float { position: absolute; width: %(fw)spx; left: %(fl)spx; top: %(ft)spx; }
"""


def build_html(lang: str, page: dict) -> str:
    kind = page.get("kind")
    theme = page.get("theme", "light")
    layout = page.get("layout", "top")
    phone = page.get("phone", PHONE_W)
    style = STYLE % {
        "font": JA_FONT if lang == "ja" else EN_FONT,
              # 英語は同じ級数だと日本語より小さく見えるので、少し上げてある。
        "head": 96 if lang == "ja" else 104,
        "sub": 42 if lang == "ja" else 42,
        "brand": 30 if lang == "ja" else 33,
        "h1": 106 if lang == "ja" else 112,
        "pill": 32 if lang == "ja" else 35,
        # 英語は末尾に1語だけ残らないよう均す。日本語は語の途中で切られるので
        # 使わず、折り返したい位置に <br> を入れてある。
        "wrap": "normal" if lang == "ja" else "balance",
        "subw": 1180 if lang == "ja" else 1230,
        "phone": phone,
        "fw": round(1044 * phone / FLOAT_BASE),
        "fl": round(-62 * phone / FLOAT_BASE),
        "ft": round(1088 * phone / FLOAT_BASE),
    }

    if kind == "title":
        pills = "".join(f"<span>{p}</span>" for p in page["pills"])
        text = (
            f'<img class="icon" src="/web/images/app-icon.png" alt="">'
            f'<h1>{page["name"]}</h1>'
            f'<p class="sub">{page["sub"]}</p>'
            f'<div class="pills">{pills}</div>'
        )
        gap = page.get("gap", 40)
    else:
        text = (
            f'<div class="brand">{BRAND[lang]}</div>'
            f'<h2>{page["head"]}</h2>'
            f'<p class="sub">{page["sub"]}</p>'
        )
        gap = page.get("gap", -4)

    floater = ""
    if page.get("float"):
        floater = f'<img class="float" src="/AppStore/parts/{lang}/{page["float"]}.png" alt="">'
    phone_img = f'<img class="phone" src="/AppStore/mockup_alpha/{lang}/{page["shot"]}.png" alt="">'

    if layout == "bottom":
        # 端末を上に置き、上端を見切れさせる。テキストはその下。
        stage = f'<div class="stage" style="margin-top:{page.get("bleed", -280)}px">{phone_img}{floater}</div>'
        body = f'{stage}<div style="margin-top:{page.get("textgap", 54)}px">{text}</div>'
    else:
        stage = f'<div class="stage" style="margin-top:{gap}px">{phone_img}{floater}</div>'
        body = f"{text}{stage}"

    return (
        f'<!doctype html><html lang="{lang}"><head><meta charset="UTF-8">'
        f"<style>{style}</style></head>"
        f'<body class="{theme} {layout}">{body}</body></html>'
    )


def build_parts() -> None:
    """浮かせる部品を実画面から切り出す。作り物ではなく本物を使う。"""
    for lang in PAGES:
        src = SHOTS / lang / "03_notif.png"
        if not src.exists():
            continue
        card = Image.open(src).convert("RGBA").crop(NOTIF_CARD_BOX)
        radius = 46

        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, card.width - 1, card.height - 1], radius=radius, fill=255)
        card.putalpha(mask)

        # まわりに影のぶんの余白を足す。
        pad = 90
        out = Image.new("RGBA", (card.width + pad * 2, card.height + pad * 2), (0, 0, 0, 0))
        shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [pad, pad + 20, pad + card.width, pad + card.height + 20],
            radius=radius, fill=(10, 16, 38, 130))
        out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(36)))
        out.alpha_composite(card, (pad, pad))

        dest = PARTS / lang / "notif_card.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        out.save(dest)


def serve():
    """リポジトリ直下を配る。画像を絶対パスで読ませるだけの用途。"""
    handler = lambda *a, **kw: http.server.SimpleHTTPRequestHandler(
        *a, directory=str(REPO), **kw)
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), handler)
    httpd.allow_reuse_address = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def main() -> None:
    build_parts()
    httpd = serve()
    # 画像を絶対パスで読ませたいので、HTML もリポジトリ配下に置いて HTTP で開く。
    tmp = REPO / ".store_tmp"
    tmp.mkdir(exist_ok=True)
    made = 0
    try:
        for lang, pages in PAGES.items():
            for page in pages:
                html = tmp / f"{lang}_{page['out']}.html"
                html.write_text(build_html(lang, page), encoding="utf-8")
                out = DST / lang / f"{page['out']}.png"
                out.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run([
                    CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    f"--window-size={CANVAS[0]},{CANVAS[1]}",
                    "--virtual-time-budget=3000",
                    f"--screenshot={out}",
                    f"http://127.0.0.1:{PORT}/.store_tmp/{html.name}",
                ], check=True, capture_output=True)
                made += 1
                print(f"  {lang}/{page['out']}.png")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        httpd.shutdown()
    print(f"{made} 枚を {DST} に書き出しました（{CANVAS[0]}×{CANVAS[1]}）")


if __name__ == "__main__":
    main()
