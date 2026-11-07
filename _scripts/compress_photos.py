#!/usr/bin/env python3
"""Compress photos for the blog: `make photos`, also run by `make build`
and `make preview`.

Reads originals from the gitignored inbox `_photos/` and writes web-sized
copies to `blog/images/`, the folder every post and draft reads from.

For each photo it:
  - applies the camera's EXIF rotation, so the pixels are upright;
  - converts to sRGB (phones shoot Display P3, which browsers would otherwise
    show washed out or not at all consistently);
  - scales the long edge down to MAX_EDGE px (never up);
  - strips all metadata, including GPS location;
  - saves as WebP (or JPEG with --format jpg) under a lowercase, hyphenated
    name, e.g. `_photos/IMG 1234.HEIC` -> `blog/images/img-1234.webp`.

Originals are never modified or deleted. A photo whose output already exists
(as .webp or .jpg) is never converted again, so re-running is cheap; --force redoes them all.

Needs Pillow (`pip install pillow`), imported only when there is a photo to
convert, so a build with nothing new runs without it. HEIC/HEIF (iPhone) files are decoded with
macOS's built-in `sips`, since Pillow cannot read them without a plugin.
Local only: nothing in the Quarto build or CI runs this.
"""

from __future__ import annotations

import argparse
import io
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INBOX = ROOT / "_photos"
OUTDIR = ROOT / "blog" / "images"

MAX_EDGE = 1400  # px; the post column is 40rem (~680px), so this covers 2x screens
QUALITY = {"webp": 75, "jpg": 80}
WARN_BYTES = 400_000  # flag outputs larger than this

PILLOW_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff"}
SIPS_EXTS = {".heic", ".heif"}


def load_pillow() -> None:
    """Import Pillow into module globals; only needed when converting."""
    global Image, ImageCms, ImageOps
    try:
        from PIL import Image, ImageCms, ImageOps
    except ImportError:
        sys.exit("compress_photos: needs Pillow. Install it with `pip install pillow`.")


def slugify(stem: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", stem.lower()).strip("-")
    return slug or "photo"


def open_image(path: Path) -> Image.Image:
    """Open `path`, going through sips for HEIC/HEIF."""
    if path.suffix.lower() not in SIPS_EXTS:
        img = Image.open(path)
        img.load()
        return img
    if not shutil.which("sips"):
        raise RuntimeError("HEIC/HEIF needs macOS's `sips`; export the photo as JPEG instead")
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "decoded.tiff"
        # sips keeps the ICC profile and EXIF orientation in the TIFF.
        subprocess.run(
            ["sips", "-s", "format", "tiff", str(path), "--out", str(out)],
            check=True,
            capture_output=True,
        )
        img = Image.open(out)
        img.load()
        return img


def to_srgb(img: Image.Image) -> Image.Image:
    """Convert to sRGB using the embedded ICC profile, if any."""
    has_alpha = img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info)
    icc = img.info.get("icc_profile")
    img = img.convert("RGBA" if has_alpha else "RGB")
    if icc:
        src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        dst = ImageCms.createProfile("sRGB")
        img = ImageCms.profileToProfile(img, src, dst, outputMode=img.mode)
    return img


def compress(src: Path, dst: Path, fmt: str) -> None:
    img = open_image(src)
    img = ImageOps.exif_transpose(img)
    img = to_srgb(img)
    img.thumbnail((MAX_EDGE, MAX_EDGE), Image.LANCZOS)  # only ever shrinks

    # Saving without exif=/icc_profile= drops all metadata, GPS included.
    if fmt == "webp":
        img.save(dst, "WEBP", quality=QUALITY["webp"], method=6)
    else:
        if img.mode == "RGBA":  # JPEG has no alpha: flatten onto white
            bg = Image.new("RGB", img.size, "white")
            bg.paste(img, mask=img.getchannel("A"))
            img = bg
        img.save(dst, "JPEG", quality=QUALITY["jpg"], optimize=True, progressive=True)


def kb(n: int) -> str:
    return f"{n / 1000:,.0f} KB"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--format", choices=["webp", "jpg"], default="webp")
    ap.add_argument("--force", action="store_true", help="redo photos already compressed")
    args = ap.parse_args()

    INBOX.mkdir(exist_ok=True)
    OUTDIR.mkdir(parents=True, exist_ok=True)
    exts = PILLOW_EXTS | SIPS_EXTS
    sources = sorted(p for p in INBOX.iterdir() if p.is_file() and p.suffix.lower() in exts)
    if not sources:
        return 0  # nothing to do; silent, since `make build` runs this every time

    # Two originals must not map to the same output name.
    seen: dict[str, Path] = {}
    for src in sources:
        name = slugify(src.stem)
        if name in seen:
            print(f"error: {src.name} and {seen[name].name} both become {name}.{args.format}; rename one")
            return 1
        seen[name] = src

    # A photo counts as converted if either output format exists, so one
    # converted with --format jpg is not converted again as WebP.
    def converted(name: str) -> bool:
        return any((OUTDIR / f"{name}.{fmt}").exists() for fmt in QUALITY)

    todo = {n: s for n, s in seen.items() if args.force or not converted(n)}
    if not todo:
        return 0  # every photo already converted
    load_pillow()

    failed = 0
    for name, src in todo.items():
        dst = OUTDIR / f"{name}.{args.format}"
        rel = dst.relative_to(ROOT)
        try:
            compress(src, dst, args.format)
        except Exception as e:  # report and keep going with the rest
            print(f"FAIL  {src.name}: {e}")
            failed += 1
            continue
        before, after = src.stat().st_size, dst.stat().st_size
        with Image.open(dst) as out:
            w, h = out.size
        warn = "  (large: consider a tighter crop)" if after > WARN_BYTES else ""
        print(f"done  {src.name} -> {rel}  {w}x{h}  {kb(before)} -> {kb(after)}{warn}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
