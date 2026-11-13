"""Generate StarPilot brand assets: flat 3-color icon + splash wordmark."""
import math
import os
from PIL import Image, ImageDraw, ImageFont

S = 2048
SCALE = S / 1024.0
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
RED = (255, 42, 42, 255)
GREY = (120, 120, 120, 255)
DARKGREY = (22, 22, 22, 255)


def p(x, y):
    return (x * SCALE, y * SCALE)


def star4(draw, cx, cy, outer, inner, fill):
    pts = []
    for i in range(8):
        r = outer if i % 2 == 0 else inner
        a = math.radians(-90 + i * 45)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=fill)


def make_icon():
    img = Image.new('RGBA', (S, S), BLACK)
    d = ImageDraw.Draw(img)

    # Outer orbit ring: red lower/right arc, thin white top arc, white nodes.
    d.arc([80 * SCALE, 80 * SCALE, 944 * SCALE, 944 * SCALE],
          start=332, end=200, fill=RED, width=int(13 * SCALE))
    d.arc([104 * SCALE, 104 * SCALE, 920 * SCALE, 920 * SCALE],
          start=202, end=330, fill=(235, 235, 235, 255), width=int(4 * SCALE))
    for ang, rad, col in [(322, 432, WHITE), (202, 432, WHITE)]:
        a = math.radians(ang)
        x = 512 + rad * math.cos(a)
        y = 512 + rad * math.sin(a)
        d.ellipse([p(x - 15, y - 15), p(x + 15, y + 15)], fill=col)

    # Planet horizon at the bottom.
    d.ellipse([p(160, 810), p(864, 1200)], fill=DARKGREY, outline=WHITE, width=int(9 * SCALE))
    d.arc([p(160, 810), p(864, 1200)], start=200, end=340, fill=WHITE, width=int(12 * SCALE))
    d.arc([p(176, 826), p(848, 1184)], start=20, end=160, fill=RED, width=int(6 * SCALE))

    # Crescent moon on the left.
    mask = Image.new('L', (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([p(110, 150), p(630, 670)], fill=255)
    md.ellipse([p(240, 80), p(760, 600)], fill=0)
    img.paste(WHITE, (0, 0), mask)
    for cx, cy, r in [(250, 390, 18), (280, 510, 13), (235, 600, 10)]:
        d.ellipse([p(cx - r, cy - r), p(cx + r, cy + r)], fill=GREY)

    # Main four-point star, red rim + white core.
    star4(d, 650 * SCALE, 390 * SCALE, 158 * SCALE, 36 * SCALE, RED)
    star4(d, 650 * SCALE, 390 * SCALE, 126 * SCALE, 29 * SCALE, WHITE)

    # Small field stars.
    for cx, cy, ro, ri, col in [
        (250, 250, 20, 5, RED), (742, 238, 13, 3, WHITE),
        (812, 610, 11, 3, WHITE), (718, 772, 9, 2, WHITE),
    ]:
        star4(d, cx * SCALE, cy * SCALE, ro * SCALE, ri * SCALE, col)

    # Telescope: tapered tube, lens, mount, tripod.
    x1, y1 = 325, 705
    x2, y2 = 555, 595
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy)
    px, py = -dy / ln, dx / ln
    h1, h2 = 15, 44
    tube = [
        p(x1 + px * h1, y1 + py * h1), p(x2 + px * h2, y2 + py * h2),
        p(x2 - px * h2, y2 - py * h2), p(x1 - px * h1, y1 - py * h1),
    ]
    d.polygon(tube, fill=WHITE, outline=BLACK, width=int(9 * SCALE))
    bx, by = x1 + dx * 0.78, y1 + dy * 0.78
    d.line([p(bx + px * h2 * 0.9, by + py * h2 * 0.9),
            p(bx - px * h2 * 0.9, by - py * h2 * 0.9)], fill=BLACK, width=int(9 * SCALE))
    d.ellipse([p(x2 - 58, y2 - 58), p(x2 + 58, y2 + 58)], fill=BLACK)
    d.ellipse([p(x2 - 50, y2 - 50), p(x2 + 50, y2 + 50)], fill=WHITE)
    d.ellipse([p(x2 - 34, y2 - 34), p(x2 + 34, y2 + 34)], fill=BLACK)
    d.arc([p(x2 - 42, y2 - 42), p(x2 + 42, y2 + 42)], start=0, end=360,
          fill=RED, width=int(7 * SCALE))
    d.ellipse([p(x1 - 28, y1 - 28), p(x1 + 28, y1 + 28)], fill=BLACK)
    d.ellipse([p(x1 - 21, y1 - 21), p(x1 + 21, y1 + 21)], fill=WHITE)
    d.ellipse([p(x1 - 11, y1 - 11), p(x1 + 11, y1 + 11)], fill=BLACK)
    d.rectangle([p(421, 650), p(445, 712)], fill=WHITE)
    d.rectangle([p(410, 700), p(456, 762)], fill=WHITE, outline=BLACK, width=int(6 * SCALE))
    d.ellipse([p(418, 686), p(448, 714)], fill=RED)
    for ex, ey in [(350, 895), (445, 905), (515, 875)]:
        d.line([p(433, 762), p(ex, ey)], fill=WHITE, width=int(15 * SCALE))
    d.line([p(370, 835), p(500, 835)], fill=WHITE, width=int(10 * SCALE))

    return img


def make_splash(icon):
    W = H = 1024
    img = Image.new('RGB', (W, H), (0, 0, 0))
    icon_small = icon.resize((700, 700), Image.LANCZOS)
    img.paste(icon_small, (162, 60), icon_small)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 104)
    sub = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
    text = "StarPilot"
    box = d.textbbox((0, 0), text, font=font)
    tw = box[2] - box[0]
    d.text(((W - tw) / 2, 790), text, font=font, fill=(255, 255, 255))
    d.rectangle([(W - 210) / 2, 908, (W + 210) / 2, 916], fill=(255, 42, 42))
    sub_text = "DEEP SKY  ·  WRIST"
    sb = d.textbbox((0, 0), sub_text, font=sub)
    sw = sb[2] - sb[0]
    d.text(((W - sw) / 2, 936), sub_text, font=sub, fill=(255, 42, 42))
    return img


def main():
    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    watch = os.path.join(base, "starpilot-watch")
    app_media = os.path.join(watch, "AppScope", "resources", "base", "media")
    entry_media = os.path.join(watch, "entry", "src", "main", "resources", "base", "media")
    os.makedirs(app_media, exist_ok=True)
    os.makedirs(entry_media, exist_ok=True)

    icon = make_icon()
    icon1024 = icon.resize((1024, 1024), Image.LANCZOS)
    icon512 = icon.resize((512, 512), Image.LANCZOS)
    icon512.save(os.path.join(app_media, "app_icon.png"))
    icon512.save(os.path.join(entry_media, "app_icon.png"))
    make_splash(icon1024).save(os.path.join(entry_media, "splash_logo.png"))
    os.makedirs(os.path.join(base, "brand"), exist_ok=True)
    icon1024.save(os.path.join(base, "brand", "brand_icon_1024.png"))
    print("generated icons + splash")


if __name__ == "__main__":
    main()
