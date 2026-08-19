"""使用 resvg 将 phantom_icon.svg 渲染为 macOS AppIcon.appiconset（Dock 图标）。

依赖:
  - resvg (brew install resvg)   # 首选渲染器
  - Pillow (pip install pillow)  # 缩放
macOS 上若没有 resvg，会降级使用系统自带的 qlmanage（Quick Look）渲染。
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

SVG_PATH = Path("assets/images/phantom_icon.svg")
OUTPUT_DIR = Path("macos/Runner/Assets.xcassets/AppIcon.appiconset")

# 与 Contents.json 严格对应
SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}


def render_with_resvg(svg: Path, png: Path, size: int = 1024) -> bool:
    """用 resvg 渲染 SVG 为透明 PNG，成功返回 True。"""
    if shutil.which("resvg") is None:
        return False
    cmd = ["resvg", "-w", str(size), "-h", str(size), str(svg), str(png)]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode != 0:
        print(f"resvg failed: {result.stderr.decode(errors='ignore')}")
        return False
    return True


def render_with_qlmanage(svg: Path, png: Path, size: int = 1024) -> bool:
    """macOS 兜底：用 Quick Look 渲染（仅 macOS，可能有背景色偏差）。"""
    if sys.platform != "darwin" or shutil.which("qlmanage") is None:
        return False
    with tempfile.TemporaryDirectory() as tmp:
        result = subprocess.run(
            ["qlmanage", "-t", "-s", str(size), "-o", tmp, str(svg)],
            capture_output=True,
        )
        if result.returncode != 0:
            print(f"qlmanage failed: {result.stderr.decode(errors='ignore')}")
            return False
        candidate = Path(tmp) / f"{svg.name}.png"
        if not candidate.exists():
            print("qlmanage produced no output")
            return False
        png.write_bytes(candidate.read_bytes())
    return True


def main() -> None:
    if not SVG_PATH.exists():
        print(f"SVG not found: {SVG_PATH}")
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmp:
        png_1024 = Path(tmp) / "phantom_1024.png"

        if render_with_resvg(SVG_PATH, png_1024):
            print("Rendered with resvg")
        elif render_with_qlmanage(SVG_PATH, png_1024):
            print("Rendered with qlmanage (Quick Look fallback)")
        else:
            print("No SVG renderer available. Install resvg: brew install resvg")
            sys.exit(1)

        source = Image.open(png_1024).convert("RGBA")
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

        for filename, size in SIZES.items():
            if size == source.width:
                img = source
            else:
                img = source.resize((size, size), Image.LANCZOS)
            output_path = OUTPUT_DIR / filename
            img.save(output_path, format="PNG")
            print(f"Saved {output_path} ({size}x{size})")

    print("Done. Rebuild with: flutter build macos --release")


if __name__ == "__main__":
    main()
