"""Derive all Go-On branding assets from the ONE official logo.

The supplied logo is never redrawn or recoloured. Every output is a technical
derivative of it:

* ``go_on_logo.png``            - transparent-background logo used inside the app
* Android launcher              - adaptive foreground + legacy mipmaps
* Web icons / favicon           - PWA + browser tab icons
* ``go_on_badge.png`` (backend) - logo on Espresso tile, embedded by PDF / Excel

Background removal is a soft matte against the (near-white) backdrop, so the
logo's own gradients/anti-aliasing are preserved and no new colour is
introduced into the artwork. The Espresso tile used behind the (light beige)
logo on icons/badges is a separate layer taken from the existing design
tokens (hero = #2B1A13); it is NOT part of the logo artwork.

Usage (from repo root)::

    .venv\\Scripts\\python.exe scripts\\generate_go_on_brand_assets.py
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
MOBILE = REPO / "mobile"
BRAND_DIR = MOBILE / "assets" / "branding"
SOURCE_COPY = BRAND_DIR / "source" / "go_on_logo_original.png"
ANDROID_RES = MOBILE / "android" / "app" / "src" / "main" / "res"
WEB_DIR = MOBILE / "web"
BACKEND_BRAND_DIR = REPO / "app" / "assets" / "branding"

ESPRESSO = (0x2B, 0x1A, 0x13, 255)  # AppColors.hero


# --------------------------------------------------------------------------
# Matte: remove only the backdrop, keep the logo pixels intact
# --------------------------------------------------------------------------
def _shift(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    return np.roll(np.roll(a, dy, axis=0), dx, axis=1)


def _erode(mask: np.ndarray, iterations: int) -> np.ndarray:
    for _ in range(iterations):
        out = mask.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                out &= _shift(mask, dy, dx)
        mask = out
    return mask


def extract_transparent_logo(src_path: Path) -> Image.Image:
    rgb = np.asarray(Image.open(src_path).convert("RGB")).astype(np.float32)
    border = np.concatenate([rgb[:16].reshape(-1, 3), rgb[-16:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    diff = rgb - bg
    dist = np.abs(diff).max(axis=2)

    # Fully-opaque interior (>= 2px away from any non-logo pixel).
    core = _erode(dist >= 30, 2)

    # Propagate the nearest interior colour outwards to estimate the local
    # foreground colour for anti-aliased edge pixels.
    fg = np.where(core[..., None], rgb, 0.0)
    have = core.copy()
    for _ in range(5):
        acc = np.zeros_like(fg)
        cnt = np.zeros(have.shape, dtype=np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                acc += _shift(np.where(have[..., None], fg, 0.0), dy, dx)
                cnt += _shift(have.astype(np.float32), dy, dx)
        fill = (~have) & (cnt > 0)
        fg[fill] = acc[fill] / cnt[fill][:, None]
        have |= fill

    fgdiff = fg - bg
    denom = np.maximum((fgdiff * fgdiff).sum(axis=2), 1e-6)
    alpha = np.clip((diff * fgdiff).sum(axis=2) / denom, 0.0, 1.0)
    alpha[~have] = 0.0
    alpha[(dist <= 2.5) & ~core] = 0.0     # backdrop noise
    alpha[alpha < 0.04] = 0.0
    alpha[core] = 1.0

    a3 = np.maximum(alpha, 1e-6)[..., None]
    color = np.where(alpha[..., None] >= 0.985, rgb, bg + diff / a3)
    color = np.clip(color, 0, 255)

    out = np.dstack([color, alpha * 255.0]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim(img: Image.Image) -> Image.Image:
    bbox = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    return img.crop(bbox)


# --------------------------------------------------------------------------
# Composition helpers
# --------------------------------------------------------------------------
def fit_logo(logo_trim: Image.Image, longest_side: int) -> Image.Image:
    w, h = logo_trim.size
    scale = longest_side / max(w, h)
    return logo_trim.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)


def paste_centered(canvas: Image.Image, logo: Image.Image) -> None:
    x = (canvas.width - logo.width) // 2
    y = (canvas.height - logo.height) // 2
    canvas.alpha_composite(logo, (x, y))


def rounded_mask(size: int, radius_frac: float) -> Image.Image:
    ss = 4
    m = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size * ss - 1, size * ss - 1], radius=int(size * ss * radius_frac), fill=255
    )
    return m.resize((size, size), Image.LANCZOS)


def badge(logo_trim: Image.Image, size: int, logo_frac: float, radius_frac: float | None) -> Image.Image:
    """Espresso tile + official logo. radius_frac=None -> full-bleed square."""
    tile = Image.new("RGBA", (size, size), ESPRESSO)
    paste_centered(tile, fit_logo(logo_trim, round(size * logo_frac)))
    if radius_frac is not None:
        tile.putalpha(rounded_mask(size, radius_frac))
    return tile


def foreground(logo_trim: Image.Image, size: int, logo_frac: float) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    paste_centered(canvas, fit_logo(logo_trim, round(size * logo_frac)))
    return canvas


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  wrote {path.relative_to(REPO)}  {img.size[0]}x{img.size[1]}  {path.stat().st_size:,} B")


# --------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, default=None, help="Official logo (defaults to the archived copy)")
    args = ap.parse_args()

    SOURCE_COPY.parent.mkdir(parents=True, exist_ok=True)
    if args.source and args.source.resolve() != SOURCE_COPY.resolve():
        shutil.copyfile(args.source, SOURCE_COPY)
    if not SOURCE_COPY.exists():
        raise SystemExit("Official logo missing: pass --source <path-to-logo.png>")

    print("Extracting transparent logo ...")
    full = extract_transparent_logo(SOURCE_COPY)
    logo_trim = trim(full)
    print(f"  tight logo bbox: {logo_trim.size}")

    # 1. In-app logo: transparent, square, ~4% breathing room, 512px.
    side = round(max(logo_trim.size) * 1.08)
    app_logo = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    paste_centered(app_logo, logo_trim)
    app_logo = app_logo.resize((512, 512), Image.LANCZOS)
    save_png(app_logo, BRAND_DIR / "go_on_logo.png")

    # 2. Android adaptive icon (108dp canvas, logo kept inside 66dp safe zone).
    densities = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
    for name, scale in densities.items():
        save_png(
            foreground(logo_trim, round(108 * scale), 0.54),
            ANDROID_RES / f"drawable-{name}" / "ic_launcher_foreground.png",
        )
        # Legacy (pre-API 26) launcher icon: 48dp
        save_png(
            badge(logo_trim, round(48 * scale), 0.68, 0.20),
            ANDROID_RES / f"mipmap-{name}" / "ic_launcher.png",
        )
        # Round launcher icon: 48dp (circular badge)
        save_png(
            badge(logo_trim, round(48 * scale), 0.64, 0.50),
            ANDROID_RES / f"mipmap-{name}" / "ic_launcher_round.png",
        )
    # Default drawable fallback
    save_png(
        foreground(logo_trim, round(108 * 4.0), 0.54),
        ANDROID_RES / "drawable" / "ic_launcher_foreground.png",
    )
    v26 = ANDROID_RES / "mipmap-anydpi-v26"
    v26.mkdir(parents=True, exist_ok=True)
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    (v26 / "ic_launcher.xml").write_text(adaptive_xml, encoding="utf-8")
    (v26 / "ic_launcher_round.xml").write_text(adaptive_xml, encoding="utf-8")
    (ANDROID_RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#2B1A13</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print("  wrote adaptive-icon xml (standard + round) + background colour")

    # 3. Web icons.
    save_png(badge(logo_trim, 192, 0.68, 0.20), WEB_DIR / "icons" / "Icon-192.png")
    save_png(badge(logo_trim, 512, 0.68, 0.20), WEB_DIR / "icons" / "Icon-512.png")
    save_png(badge(logo_trim, 192, 0.56, None), WEB_DIR / "icons" / "Icon-maskable-192.png")
    save_png(badge(logo_trim, 512, 0.56, None), WEB_DIR / "icons" / "Icon-maskable-512.png")
    save_png(badge(logo_trim, 64, 0.72, 0.20), WEB_DIR / "favicon.png")

    # 4. Backend report badge (small: keeps PDF / XLSX light).
    save_png(badge(logo_trim, 256, 0.72, 0.20), BACKEND_BRAND_DIR / "go_on_badge.png")

    # 5. Fidelity check: re-compositing over the original backdrop must match.
    src = np.asarray(Image.open(SOURCE_COPY).convert("RGB")).astype(np.float32)
    bg = np.median(np.concatenate([src[:16].reshape(-1, 3), src[-16:].reshape(-1, 3)]), axis=0)
    comp = Image.new("RGBA", full.size, tuple(int(v) for v in bg) + (255,))
    comp.alpha_composite(full)
    err = np.abs(np.asarray(comp.convert("RGB")).astype(np.float32) - src)
    print(f"Fidelity vs original (composited on its own backdrop): max={err.max():.1f} mean={err.mean():.4f}")


if __name__ == "__main__":
    main()
