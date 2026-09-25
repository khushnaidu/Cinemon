"""App Store screenshots: iPhone captures -> 1320x2868 marketing images.

Each raw screenshot (any iPhone size) is placed on black, with a caption in
SF above it and rounded corners, at the 6.9-inch size App Store Connect
requires. Captions come from docs/app-store/listing.md's table, by number.

    python3 tool/app_store_screenshots.py RAW_DIR OUT_DIR

RAW_DIR holds 01.png, 02.png... (or .jpg / .jpeg / .heic converted first).
"""

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 2868
MARGIN = 96          # sides of the screenshot
TOP = 330            # where the screenshot starts
RADIUS = 64
FONT = "/System/Library/Fonts/SFNS.ttf"
LISTING = Path(__file__).resolve().parent.parent / "docs/app-store/listing.md"


def captions() -> dict[str, str]:
    rows = re.findall(r"^\| (\d\d) \| [^|]+\| ([^|]+) \|$", LISTING.read_text(), re.M)
    return {n: c.strip() for n, c in rows}


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name("Semibold")
    except Exception:
        pass
    return f


def wrap(draw, text, f, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def compose(raw: Path, caption: str, out: Path) -> None:
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    f = font(76)
    lines = wrap(draw, caption, f, W - 2 * 110)
    line_h = 92
    y = (TOP - line_h * len(lines)) // 2 + 10
    for line in lines:
        x = (W - draw.textlength(line, font=f)) / 2
        draw.text((x, y), line, font=f, fill=(255, 255, 255))
        y += line_h

    shot = Image.open(raw).convert("RGB")
    width = W - 2 * MARGIN
    height = round(shot.height * width / shot.width)
    room = H - TOP - 80
    if height > room:  # taller phones: fit by height instead
        height = room
        width = round(shot.width * height / shot.height)
    shot = shot.resize((width, height), Image.LANCZOS)

    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), RADIUS, fill=255)
    canvas.paste(shot, ((W - width) // 2, TOP), mask)
    # A hairline edge, so a dark screenshot doesn't melt into the black.
    ImageDraw.Draw(canvas).rounded_rectangle(
        ((W - width) // 2, TOP, (W + width) // 2 - 1, TOP + height - 1),
        RADIUS, outline=(58, 58, 60), width=3)

    canvas.save(out, "PNG")


def main() -> None:
    raw_dir, out_dir = Path(sys.argv[1]).expanduser(), Path(sys.argv[2]).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)
    caps = captions()
    shots = sorted(p for p in raw_dir.iterdir()
                   if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    if not shots:
        sys.exit(f"No screenshots in {raw_dir}")
    for p in shots:
        n = p.stem[:2]
        caption = caps.get(n, "")
        compose(p, caption, out_dir / f"{n}.png")
        print(f"{p.name} -> {n}.png  {caption}")


if __name__ == "__main__":
    main()
