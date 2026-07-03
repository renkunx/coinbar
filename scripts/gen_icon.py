#!/usr/bin/env python3
"""生成 CoinBar 应用图标：橙色渐变圆 + ₿ 比特币符号 + 高光。
输出 1024×1024 PNG，供 sips/iconutil 转为 .icns。
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "AppIcon-1024.png")

def find_font():
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # —— 主体：圆角矩形（macOS Big Sur+ 风格 squircle 感，用大圆角近似）
    margin = 60
    radius = 230
    # 径向渐变：从亮橙(中心)到深橙(边缘)
    cx = cy = SIZE / 2
    max_r = ((SIZE / 2) ** 2 + (SIZE / 2) ** 2) ** 0.5
    # 先画一个圆形蒙版区域做渐变
    for y in range(SIZE):
        for x in range(SIZE):
            # 仅在 squircle 内绘制（用圆角矩形近似）
            pass  # 像素级太慢，改用分层

    # 重置画布，用分层方式
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # 1) 圆角矩形 mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle(
        [margin, margin, SIZE - margin, SIZE - margin],
        radius=radius,
        fill=255,
    )

    # 2) 渐变填充（橙色，中心亮边缘深）
    grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gpix = grad.load()
    bright = (255, 176, 32)   # 中心亮橙 #FFB020
    dark = (232, 122, 10)     # 边缘深橙 #E87A0A
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

    # 应用 mask 到渐变
    body = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    img.alpha_composite(body)

    # 3) 顶部高光（柔光）
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.ellipse(
        [SIZE * 0.18, SIZE * 0.10, SIZE * 0.82, SIZE * 0.50],
        fill=(255, 255, 255, 70),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(80))
    hl_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hl_masked.paste(highlight, (0, 0), mask)
    img.alpha_composite(hl_masked)

    # 4) ₿ 符号（白色，加投影感）
    font_path = find_font()
    draw = ImageDraw.Draw(img)
    # 字号需根据字体微调，先用较大值
    font_size = 560
    font = None
    if font_path:
        try:
            font = ImageFont.truetype(font_path, font_size)
        except Exception:
            font = None
    if font is None:
        font = ImageFont.load_default()

    symbol = "₿"
    # 测量并居中
    bbox = draw.textbbox((0, 0), symbol, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) / 2 - bbox[0]
    ty = (SIZE - th) / 2 - bbox[1] - 20  # 略上移视觉居中

    # 投影
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.text((tx + 8, ty + 12), symbol, font=font, fill=(120, 50, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(shadow)

    # 主文字
    draw.text((tx, ty), symbol, font=font, fill=(255, 255, 255, 255))

    img.save(OUT, "PNG")
    print(f"已生成: {OUT}")

if __name__ == "__main__":
    main()
