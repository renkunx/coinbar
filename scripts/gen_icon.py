#!/usr/bin/env python3
"""生成 CoinBar 应用图标：橙色渐变圆角方块 + ₿ 比特币符号 + 高光。
输出 1024×1024 PNG，供 sips/iconutil 转为 .icns。
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "AppIcon-1024.png")

# nf-fa-btc: Font Awesome Bitcoin 图标，设计感强，适合 App Icon
SYMBOL = "\uf15a"

def find_font(size):
    """尝试加载 Nerd Font，优先使用 FiraCode Nerd Font Bold。"""
    home = os.path.expanduser("~")
    candidates = [
        f"{home}/Library/Fonts/FiraCodeNerdFont-Bold.ttf",
        f"{home}/Library/Fonts/FiraCodeNerdFont-SemiBold.ttf",
        f"{home}/Library/Fonts/UbuntuSansNerdFont-Bold.ttf",
        f"{home}/Library/Fonts/FiraCodeNerdFont-Regular.ttf",
        # fallback 系统字体
        "/System/Library/Fonts/Supplemental/Arial Black.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for fp in candidates:
        if not os.path.exists(fp):
            continue
        try:
            font = ImageFont.truetype(fp, size)
            test = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
            td = ImageDraw.Draw(test)
            td.text((50, 50), SYMBOL, font=font, fill=(255, 255, 255, 255))
            px = list(test.getdata())
            white_count = sum(1 for p in px if p[3] > 0)
            if white_count > 10:
                print(f"  使用字体: {os.path.basename(fp)} ({size}pt)")
                return font
        except Exception as e:
            print(f"  跳过 {os.path.basename(fp)}: {e}")
    raise RuntimeError("没有找到能渲染 Bitcoin 图标的字体")

def main():
    print("正在生成 CoinBar 图标...")
    cx = cy = SIZE / 2
    max_r = ((SIZE / 2) ** 2 + (SIZE / 2) ** 2) ** 0.5

    # ---- 1. 圆角矩形 mask ----
    margin = 60
    radius = 220
    mask = Image.new("L", (SIZE, SIZE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle(
        [margin, margin, SIZE - margin, SIZE - margin],
        radius=radius,
        fill=255,
    )

    # ---- 2. 渐变填充（橙色，中心亮边缘深） ----
    print("  绘制渐变背景...")
    grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gpix = grad.load()
    bright = (255, 176, 32)   # 中心亮橙
    dark = (232, 122, 10)     # 边缘深橙
    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            t = min(1.0, dist / max_r)
            r = int(bright[0] + (dark[0] - bright[0]) * t)
            g = int(bright[1] + (dark[1] - bright[1]) * t)
            b = int(bright[2] + (dark[2] - bright[2]) * t)
            gpix[x, y] = (r, g, b, 255)

    # 应用 mask
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(grad, (0, 0), mask)

    # ---- 3. 顶部高光 ----
    print("  添加高光...")
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.ellipse(
        [SIZE * 0.20, SIZE * 0.12, SIZE * 0.80, SIZE * 0.50],
        fill=(255, 255, 255, 65),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(80))
    hl_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hl_masked.paste(highlight, (0, 0), mask)
    img.alpha_composite(hl_masked)

    # ---- 4. ₿ 符号 ----
    print("  渲染 ₿ 符号...")
    font = find_font(620)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), SYMBOL, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) / 2 - bbox[0]
    ty = (SIZE - th) / 2 - bbox[1] - 10

    # 投影
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.text((tx + 6, ty + 10), SYMBOL, font=font, fill=(100, 40, 0, 130))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(shadow)

    # 主文字（白色）
    draw.text((tx, ty), SYMBOL, font=font, fill=(255, 255, 255, 255))

    # ---- 5. 保存 ----
    img.save(OUT, "PNG")

    # 验证
    pixels = list(img.getdata())
    white = sum(1 for p in pixels if p[0] > 240 and p[1] > 240 and p[2] > 240 and p[3] > 200)
    print(f"  白色像素数: {white} {'✅' if white > 100 else '❌ 符号可能太小'}")
    print(f"✅ 已生成: {os.path.abspath(OUT)}")

if __name__ == "__main__":
    main()