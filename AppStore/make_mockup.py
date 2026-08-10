#!/usr/bin/env python3
"""App Store 用のスクリーンショットを iPhone のフレームに嵌める。

AppStore/screenshots/<lang>/*.png を読み、2種類を書き出す。

  AppStore/mockup/<lang>/*.png        背景つき・不透明・1320×2868
                                      App Store Connect はアルファ付きを受け付けないため、
                                      提出用はこちら。
  AppStore/mockup_alpha/<lang>/*.png  端末と影だけの透過 PNG。周囲は余白ぶんだけ。
                                      別の背景に重ねたいとき（Web・プレスキット）用。

    python3 AppStore/make_mockup.py

キャッチコピーは載せない。文言が決まったら、この出力の上に重ねる想定。
"""

from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "screenshots"
DST_FLAT = ROOT / "mockup"
DST_ALPHA = ROOT / "mockup_alpha"

# 6.9 インチ（iPhone 17 Pro Max）のスクリーンショット寸法。
CANVAS = (1320, 2868)
RATIO = CANVAS[0] / CANVAS[1]

# 端末の見た目。ベゼルは実機よりやや細めにして、画面を大きく見せる。
DEVICE_W = 1060
BEZEL = 20
SCREEN_W = DEVICE_W - BEZEL * 2
SCREEN_H = round(SCREEN_W / RATIO)
DEVICE_H = SCREEN_H + BEZEL * 2
SCREEN_RADIUS = 78
DEVICE_RADIUS = SCREEN_RADIUS + BEZEL

# 影がぼけて切れないよう、端末のまわりに取る余白。
MARGIN = 120
SHADOW_OFFSET = 26
SHADOW_BLUR = 46

BEZEL_COLOR = (26, 28, 33)
# アプリの indigo (#5B7CFA) を淡くした背景。
BG_TOP = (0xF4, 0xF6, 0xFF)
BG_BOTTOM = (0xE2, 0xE7, 0xFA)
GLOW = (0x5B, 0x7C, 0xFA)
# 背景つきは青みのある影、透過版はどんな背景にも合うよう黒にする。
SHADOW_ON_BG = (30, 38, 60, 110)
SHADOW_ON_ALPHA = (0, 0, 0, 88)


def rounded_mask(size, radius) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                           radius=radius, fill=255)
    return mask


def device_layer(shot_path: Path, shadow_color) -> Image.Image:
    """端末（ベゼル＋画面）と影だけを描いた透過レイヤー。まわりは MARGIN ぶんの余白。"""
    size = (DEVICE_W + MARGIN * 2, DEVICE_H + MARGIN * 2)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    x, y = MARGIN, MARGIN

    # 影。端末と同じ形をぼかして少し下にずらす。
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, y + SHADOW_OFFSET, x + DEVICE_W, y + DEVICE_H + SHADOW_OFFSET],
        radius=DEVICE_RADIUS, fill=shadow_color)
    layer = Image.alpha_composite(layer, shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)))

    # 本体（ベゼル）。
    body = Image.new("RGBA", (DEVICE_W, DEVICE_H), BEZEL_COLOR + (255,))
    body.putalpha(rounded_mask((DEVICE_W, DEVICE_H), DEVICE_RADIUS))
    layer.alpha_composite(body, (x, y))

    # 画面。
    shot = Image.open(shot_path).convert("RGBA").resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    shot.putalpha(rounded_mask((SCREEN_W, SCREEN_H), SCREEN_RADIUS))
    layer.alpha_composite(shot, (x + BEZEL, y + BEZEL))

    # ベゼルの内側に細いハイライトを入れて、板に貼っただけに見えないようにする。
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [x, y, x + DEVICE_W, y + DEVICE_H],
        radius=DEVICE_RADIUS, outline=(255, 255, 255, 40), width=3)
    return Image.alpha_composite(layer, edge)


def gradient_background() -> Image.Image:
    """上から下への淡いグラデーションに、うっすら光の円を重ねる。"""
    w, h = CANVAS
    bg = Image.new("RGB", CANVAS)
    draw = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / (h - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
        draw.line([(0, y), (w, y)], fill=color)

    # 左上と右下に、ぼかした円をごく薄く置いて平坦さを消す。
    glow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-360, -420, 760, 700], fill=GLOW + (46,))
    gd.ellipse([w - 700, h - 900, w + 380, h + 180], fill=GLOW + (34,))
    glow = glow.filter(ImageFilter.GaussianBlur(180))
    return Image.alpha_composite(bg.convert("RGBA"), glow)


def write_flat(shot_path: Path, out_path: Path) -> None:
    """提出用。背景を敷いてアルファを落とす。"""
    canvas = gradient_background()
    layer = device_layer(shot_path, SHADOW_ON_BG)
    pos = ((CANVAS[0] - layer.width) // 2, (CANVAS[1] - layer.height) // 2)
    canvas.alpha_composite(layer, pos)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path)


def write_alpha(shot_path: Path, out_path: Path) -> None:
    """重ねもの用。背景は敷かず、端末と影だけを残す。"""
    layer = device_layer(shot_path, SHADOW_ON_ALPHA)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    layer.save(out_path)


def main() -> None:
    made = 0
    for lang_dir in sorted(p for p in SRC.iterdir() if p.is_dir()):
        for shot in sorted(lang_dir.glob("*.png")):
            write_flat(shot, DST_FLAT / lang_dir.name / shot.name)
            write_alpha(shot, DST_ALPHA / lang_dir.name / shot.name)
            made += 1
            print(f"  {lang_dir.name}/{shot.name}")
    print(f"{made} 枚 × 2種を書き出しました")
    print(f"  提出用（不透明 {CANVAS[0]}×{CANVAS[1]}）: {DST_FLAT}")
    print(f"  透過（{DEVICE_W + MARGIN * 2}×{DEVICE_H + MARGIN * 2}）: {DST_ALPHA}")


if __name__ == "__main__":
    main()
