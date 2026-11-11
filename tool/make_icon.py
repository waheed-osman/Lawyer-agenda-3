#!/usr/bin/env python3
"""يرسم أيقونة التطبيق (ميزان العدالة) ويكتبها بأحجام mipmap داخل tool/icons/.
تشغيله اختياري: الملفات الجاهزة موجودة، ويستخدمها tool/setup_android.py."""
from PIL import Image, ImageDraw
import os

S = 4096  # رسم بدقة عالية ثم تصغير
NAVY1, NAVY2, GOLD = (20, 40, 75), (34, 62, 105), (236, 190, 80)


def draw(size=1024):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # خلفية مربعة بزوايا دائرية وتدرج رأسي
    bg = Image.new("RGBA", (S, S))
    px = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / S
        c = tuple(int(NAVY1[i] + (NAVY2[i] - NAVY1[i]) * t) for i in range(3)) + (255,)
        px.line([(0, y), (S, y)], fill=c)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
    img.paste(bg, (0, 0), mask)

    d = ImageDraw.Draw(img)
    u = S / 100.0
    cx = 50 * u
    w = int(2.6 * u)  # سُمك الخطوط

    def line(a, b, width=w):
        d.line([(a[0] * u, a[1] * u), (b[0] * u, b[1] * u)], fill=GOLD, width=width)

    # القاعدة والعمود
    d.rounded_rectangle([cx - 15 * u, 80 * u, cx + 15 * u, 85 * u], radius=int(2 * u), fill=GOLD)
    d.rounded_rectangle([cx - 9 * u, 74 * u, cx + 9 * u, 80 * u], radius=int(1.5 * u), fill=GOLD)
    d.rectangle([cx - 1.6 * u, 24 * u, cx + 1.6 * u, 76 * u], fill=GOLD)
    # كرة أعلى العمود
    d.ellipse([cx - 4 * u, 17 * u, cx + 4 * u, 25 * u], fill=GOLD)
    # الذراع
    line((22, 31), (78, 31), int(3.2 * u))
    d.ellipse([cx - 2.6 * u, 28.4 * u, cx + 2.6 * u, 33.6 * u], fill=NAVY1)
    # الكفتان: سلاسل مثلثة + طبق نصف دائري
    for x in (22, 78):
        line((x, 31), (x - 11, 55))
        line((x, 31), (x + 11, 55))
        d.pieslice([(x - 14) * u, 41 * u, (x + 14) * u, 69 * u], 0, 180, fill=GOLD)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    os.makedirs(out, exist_ok=True)
    base = draw(1024)
    for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        d = os.path.join(out, f"mipmap-{name}")
        os.makedirs(d, exist_ok=True)
        base.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
    base.resize((512, 512), Image.LANCZOS).save(os.path.join(out, "icon_512.png"))
    print("done")
