"""生成 QQ Bot 控制台图标 —— 多尺寸 ICO
设计：圆角蓝渐变底 + 经典 QQ 企鹅（黑身白肚 + 红围巾 + 黄脚 + 黑眼）
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = r"D:\ds\qqbot\assets\app.ico"
os.makedirs(os.path.dirname(OUT), exist_ok=True)


def make_icon(size):
    S = size
    K = 4                      # 超采样倍率
    s = S * K
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # ══ 1. 圆角蓝渐变底 ══
    grad = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / s
        r = int(0 + 30 * t)
        g = int(113 + 60 * t)
        b = int(227 + 20 * t)
        gd.line([(0, y), (s, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=int(s * 0.2237), fill=255)
    img.paste(grad, (0, 0), mask)

    # ══ 2. 顶部玻璃高光 ══
    hl = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse(
        [-int(s * .3), -int(s * .78), int(s * 1.1), int(s * .42)],
        fill=(255, 255, 255, 42))
    hl = hl.filter(ImageFilter.GaussianBlur(s * .02))
    img = Image.alpha_composite(
        img, Image.composite(hl, Image.new("RGBA", (s, s)), mask))
    d = ImageDraw.Draw(img)

    # ══ 3. 企鹅几何参数 ══
    cx = s * 0.50
    cy = s * 0.545
    W  = s * 0.60                 # 总宽

    BLACK = (28, 28, 32, 255)
    WHITE = (255, 255, 255, 255)
    RED   = (232, 50, 44, 255)
    YELL  = (255, 178, 26, 255)

    # ── 身体：黑椭圆 ──
    bw = W * 0.50
    bh = W * 0.585
    body_top = cy - bh * 0.80
    d.ellipse([cx - bw, body_top, cx + bw, cy + bh * 1.02], fill=BLACK)

    # ── 白肚 ──
    dbw = bw * 0.70
    dbh = bh * 0.72
    d.ellipse([cx - dbw, cy - dbh * 0.48, cx + dbw, cy + dbh * 1.02], fill=WHITE)

    # ── 头：黑圆 ──
    hw = W * 0.365
    hcy = body_top - hw * 0.42
    d.ellipse([cx - hw, hcy - hw, cx + hw, hcy + hw], fill=BLACK)

    # ── 白眼眶（QQ 企鹅的经典"大白眼"）──
    eo = hw * 0.60
    eoy = hcy - hw * 0.06
    d.ellipse([cx - eo, eoy - eo * 0.92, cx + eo, eoy + eo * 0.92], fill=WHITE)

    # ── 黑眼珠 ──
    ep = hw * 0.255
    for sx in (-1, 1):
        ex = cx + sx * hw * 0.385
        d.ellipse([ex - ep, eoy - ep * 1.05, ex + ep, eoy + ep * 1.05], fill=BLACK)

    # ── 嘴：橙黄椭圆 ──
    mw = hw * 0.50
    mh = hw * 0.31
    my = eoy + eo * 0.92 - mh * 0.12
    d.ellipse([cx - mw, my, cx + mw, my + mh * 1.7], fill=YELL)
    # 嘴中线
    d.line([(cx, my + mh * 0.28), (cx, my + mh * 1.45)],
           fill=(200, 120, 10, 255), width=max(1, int(s * 0.004)))

    # ── 红围巾 ──
    sy = body_top + bh * 0.10
    s_h = W * 0.085
    d.rounded_rectangle(
        [cx - bw * 0.795, sy, cx + bw * 0.795, sy + s_h],
        radius=int(s_h * 0.42), fill=RED)
    # 围巾垂下的尾巴
    tail_w = W * 0.115
    d.rounded_rectangle(
        [cx - bw * 0.52 - tail_w * 0.5, sy + s_h * 0.55,
         cx - bw * 0.52 + tail_w * 0.5, sy + s_h * 2.45],
        radius=int(tail_w * 0.32), fill=RED)

    # ── 翅膀（两侧小黑圆）──
    fw = bw * 0.30
    fy = cy - bh * 0.10
    for sx in (-1, 1):
        fx = cx + sx * (bw * 0.90)
        d.ellipse([fx - fw * 0.62, fy - fw * 1.05, fx + fw * 0.62, fy + fw * 1.05],
                  fill=BLACK)

    # ── 黄脚 ──
    fw2 = bw * 0.30
    fh2 = bh * 0.115
    fy2 = cy + bh * 0.98
    for sx in (-1, 1):
        fx2 = cx + sx * bw * 0.42
        d.ellipse([fx2 - fw2, fy2, fx2 + fw2, fy2 + fh2 * 1.55], fill=YELL)

    # ══ 4. 缩小 ══
    return img.resize((S, S), Image.LANCZOS)


def main():
    sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    imgs = [make_icon(z) for z in sizes]
    imgs[-1].save(OUT, format="ICO",
                  sizes=[(z, z) for z in sizes],
                  append_images=imgs[:-1])
    png = OUT.replace(".ico", ".png")
    imgs[-1].save(png, format="PNG")
    print(f"OK {OUT} ({os.path.getsize(OUT)//1024}KB)")
    print(f"   preview: {png}")


if __name__ == "__main__":
    main()
