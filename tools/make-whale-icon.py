"""生成鲸鱼娘应用图标 v2 —— 强化鲸鱼特征
改进：上翘尾鳍、加粗喷水、流线身体、加深轮廓
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = r"D:\ds\qqbot\assets\app.ico"
os.makedirs(os.path.dirname(OUT), exist_ok=True)


def make_icon(size):
    S = size
    K = 4
    s = S * K
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # ══ 1. 蓝紫渐变底 ══
    grad = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / s
        r = int(70 + (168 - 70) * t)
        g = int(130 + (120 - 130) * t)
        b = int(220 + (255 - 220) * t)
        gd.line([(0, y), (s, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=int(s * 0.2237), fill=255)
    img.paste(grad, (0, 0), mask)

    # ══ 2. 顶部玻璃高光 ══
    hl = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse(
        [-int(s * .32), -int(s * .80), int(s * 1.12), int(s * .40)],
        fill=(255, 255, 255, 44))
    hl = hl.filter(ImageFilter.GaussianBlur(s * .02))
    img = Image.alpha_composite(
        img, Image.composite(hl, Image.new("RGBA", (s, s)), mask))
    d = ImageDraw.Draw(img)

    WHITE = (255, 255, 255, 255)
    BELLY = (222, 236, 252, 255)
    DARK  = (30, 38, 66, 255)
    PINK  = (255, 140, 178, 255)
    PINK2 = (255, 105, 155, 255)
    CYAN  = (120, 210, 255, 255)
    CYAN2 = (90, 190, 245, 255)

    cx = s * 0.48          # 略左，给尾巴留空间
    cy = s * 0.60
    W  = s * 0.62

    # ══ 3. 尾鳍（右上，鲸鱼标志性特征）══
    tx = cx + W * 0.34
    ty = cy - W * 0.16
    tw = W * 0.185
    th = W * 0.135
    # 上翘的两片尾鳍（心形裂尾）
    d.ellipse([tx - tw * 0.15, ty - th * 2.35,
               tx + tw * 0.92, ty - th * 0.28], fill=WHITE)   # 左上片
    d.ellipse([tx + tw * 0.05, ty - th * 2.20,
               tx + tw * 1.22, ty - th * 0.22], fill=WHITE)   # 右上片
    # 尾柄
    d.line([(cx + W * 0.18, cy + W * 0.02), (tx + tw * 0.45, ty - th * 0.6)],
           fill=WHITE, width=max(2, int(W * 0.115)))

    # ══ 4. 身体（流线椭圆，比 v1 更扁长）══
    bw = W * 0.46
    bh = W * 0.355
    body_top = cy - bh * 0.42
    d.ellipse([cx - bw, body_top, cx + bw, cy + bh * 1.28], fill=WHITE)

    # 白肚
    dbw = bw * 0.73
    dbh = bh * 0.76
    d.ellipse([cx - dbw, cy - dbh * 0.02,
               cx + dbw, cy + dbh * 1.22], fill=BELLY)

    # 侧鳍
    fin_w = W * 0.105
    fin_h = W * 0.135
    for sx in (-1, 1):
        fx = cx + sx * (bw * 0.98)
        fy = cy + bh * 0.36
        d.ellipse([fx - fin_w, fy - fin_h, fx + fin_w, fy + fin_h], fill=WHITE)

    # ══ 5. 喷水柱（加粗，最关键识别点）══
    sp_x = cx - bw * 0.16
    sp_y = body_top + bh * 0.06
    # 主柱：粗椭圆
    d.ellipse([sp_x - W * 0.052, sp_y - W * 0.30,
               sp_x + W * 0.052, sp_y + W * 0.02], fill=CYAN)
    # 柱内高光
    d.ellipse([sp_x - W * 0.020, sp_y - W * 0.27,
               sp_x + W * 0.012, sp_y - W * 0.02], fill=(255, 255, 255, 170))
    # 两侧水花（更大）
    for sx, ox, oy, rr in ((-1, 0.145, 0.245, 0.062),
                           (1, 0.130, 0.285, 0.050),
                           (-1, 0.085, 0.345, 0.038),
                           (1, 0.190, 0.365, 0.034)):
        dx = sp_x + sx * W * ox
        dy = sp_y - W * oy
        d.ellipse([dx - W * rr, dy - W * rr,
                   dx + W * rr, dy + W * rr], fill=CYAN2)

    # ══ 6. 大眼睛（鲸鱼娘）══
    ew = W * 0.088
    ey = cy + bh * 0.03
    for sx in (-1, 1):
        ex = cx + sx * bw * 0.40
        d.ellipse([ex - ew * 1.30, ey - ew * 1.42,
                   ex + ew * 1.30, ey + ew * 1.42], fill=(255, 255, 255, 255))
        # 深色瞳孔
        d.ellipse([ex - ew * 0.82, ey - ew * 0.92,
                   ex + ew * 0.82, ey + ew * 0.92], fill=DARK)
        # 主高光
        d.ellipse([ex - ew * 0.22, ey - ew * 0.66,
                   ex + ew * 0.38, ey - ew * 0.06], fill=(255, 255, 255, 255))
        # 次高光
        d.ellipse([ex + ew * 0.22, ey + ew * 0.30,
                   ex + ew * 0.58, ey + ew * 0.66], fill=(255, 255, 255, 190))

    # ══ 7. 腮红 ══
    bw2 = W * 0.055
    by = ey + ew * 2.05
    for sx in (-1, 1):
        bx = cx + sx * bw * 0.655
        d.ellipse([bx - bw2 * 1.25, by - bw2 * 0.72,
                   bx + bw2 * 1.25, by + bw2 * 0.72], fill=(255, 140, 178, 190))

    # ══ 8. 头顶蝴蝶结 ══
    if S >= 24:
        bx0 = cx - bw * 0.62
        by0 = body_top - W * 0.020
        br = W * 0.042
        d.ellipse([bx0 - br * 2.0, by0 - br * 0.95,
                   bx0 - br * 0.12, by0 + br * 0.95], fill=PINK)
        d.ellipse([bx0 + br * 0.12, by0 - br * 0.95,
                   bx0 + br * 2.0, by0 + br * 0.95], fill=PINK)
        d.ellipse([bx0 - br * 0.48, by0 - br * 0.48,
                   bx0 + br * 0.48, by0 + br * 0.48], fill=PINK2)

    return img.resize((S, S), Image.LANCZOS)


def main():
    sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    imgs = [make_icon(z) for z in sizes]
    imgs[-1].save(OUT, format="ICO",
                  sizes=[(z, z) for z in sizes],
                  append_images=imgs[:-1])
    png = OUT.replace(".ico", ".png")
    imgs[-1].save(png, format="PNG")
    print(f"OK {OUT} ({os.path.getsize(OUT)//1024}KB) -> {png}")


if __name__ == "__main__":
    main()
