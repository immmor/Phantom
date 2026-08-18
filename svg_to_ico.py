"""使用 resvg 将 SVG 渲染为 Windows 图标（不依赖 reportlab/cairo）。

依赖:
  - resvg (brew install resvg)   # 首选渲染器
  - Pillow (pip install pillow)  # 缩放与合成 ICO
macOS 上若没有 resvg，会降级使用系统自带的 qlmanage（Quick Look）渲染。
"""
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

SVG_PATH = Path("assets/images/phantom.svg")
ICO_PATH = Path("windows/runner/resources/app_icon.ico")
SIZES = [256, 128, 96, 64, 48, 32, 16]


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


def write_ico(png: Path, ico: Path, sizes: list[int]) -> None:
    """从一张高分辨率 PNG 缩放出多尺寸并写入 .ico 文件。"""
    source = Image.open(png).convert("RGBA")

    # 保存各尺寸 PNG 数据，并同时构造 ICO 图像列表
    images = []
    for size in sizes:
        if size == source.width and size == source.height:
            img = source
        else:
            img = source.resize((size, size), Image.LANCZOS)
        images.append(img)

    ico.parent.mkdir(parents=True, exist_ok=True)
    images[0].save(
        ico,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:],
    )
    print(f"Saved ICO to {ico} ({len(images)} sizes: {', '.join(str(s) for s in sizes)})")


def main() -> None:
    if not SVG_PATH.exists():
        print(f"SVG not found: {SVG_PATH}")
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "phantom_1024.png"

        if render_with_resvg(SVG_PATH, png):
            print("Rendered with resvg")
        elif render_with_qlmanage(SVG_PATH, png):
            print("Rendered with qlmanage (Quick Look fallback)")
        else:
            print("No SVG renderer available. Install resvg: brew install resvg")
            sys.exit(1)

        write_ico(png, ICO_PATH, SIZES)


if __name__ == "__main__":
    main()
