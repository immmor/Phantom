"""使用 resvg 将 SVG 渲染为 Windows 图标与托盘图标（不依赖 reportlab/cairo）。

依赖:
  - resvg (brew install resvg)   # 首选渲染器
  - Pillow (pip install pillow)  # 缩放与合成 ICO
macOS 上若没有 resvg，会降级使用系统自带的 qlmanage（Quick Look）渲染。
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

SVG_PATH = Path("assets/images/phantom.svg")          # 托盘/剪影图标（无背景）
ICON_SVG_PATH = Path("assets/images/phantom_icon_navy.svg")  # APP 图标（墨蓝底青幽灵）
ICO_PATH = Path("windows/runner/resources/app_icon.ico")
STATUS_DIR = Path("assets/images/icon")
ROOT_ICON_PNG = Path("assets/images/icon.png")   # Linux 打包用（deb/appimage/rpm）
ROOT_ICON_ICO = Path("assets/images/icon.ico")   # 通用 Windows 图标（遗留兼容）
APP_ICON_SIZES = [256, 128, 96, 64, 48, 32, 16]
TRAY_ICON_SIZES = [48, 32, 16]
TRAY_TEMPLATE_SIZE = 64  # macOS 顶部栏模板图标尺寸
LINUX_ICON_SIZE = 512    # Linux 桌面图标尺寸


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


def to_template(img: Image.Image) -> Image.Image:
    """将彩色图标转为 macOS 菜单栏模板图标：黑色剪影 + 原 alpha。"""
    _, _, _, alpha = img.split()
    black = Image.new("RGBA", img.size, (0, 0, 0, 255))
    black.putalpha(alpha)
    return black


def trim_and_fit(img: Image.Image, canvas: int, padding: int = 0) -> Image.Image:
    """裁剪透明边缘后等比缩放到 canvas 画布（居中，四周留 padding 像素）。"""
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    max_side = max(1, canvas - 2 * padding)
    ratio = min(max_side / img.width, max_side / img.height)
    if ratio != 1:
        new_size = (
            max(1, round(img.width * ratio)),
            max(1, round(img.height * ratio)),
        )
        img = img.resize(new_size, Image.LANCZOS)
    canvas_img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    canvas_img.paste(
        img,
        ((canvas - img.width) // 2, (canvas - img.height) // 2),
        img,
    )
    return canvas_img


def write_root_icons(source_png: Path) -> None:
    """生成 assets/images/ 下的通用图标（icon.png / icon.ico）。"""
    source = Image.open(source_png).convert("RGBA")

    img = source.resize((LINUX_ICON_SIZE, LINUX_ICON_SIZE), Image.LANCZOS)
    img.save(ROOT_ICON_PNG, format="PNG")
    print(f"Saved PNG to {ROOT_ICON_PNG} ({LINUX_ICON_SIZE}x{LINUX_ICON_SIZE})")

    images = []
    for size in APP_ICON_SIZES:
        img = source.resize((size, size), Image.LANCZOS)
        images.append(img)
    images[0].save(
        ROOT_ICON_ICO,
        format="ICO",
        sizes=[(s, s) for s in APP_ICON_SIZES],
        append_images=images[1:],
    )
    print(f"Saved ICO to {ROOT_ICON_ICO}")


def write_status_icons(source_png: Path) -> None:
    """生成 Windows 与 macOS 托盘图标。当前 status_1/2/3 使用同一幽灵图标。"""
    source = Image.open(source_png).convert("RGBA")
    STATUS_DIR.mkdir(parents=True, exist_ok=True)

    # Windows 托盘图标：彩色 ICO（16/32/48），图形填满、边缘留 1px 防粘连
    for name in ("status_1.ico", "status_2.ico", "status_3.ico"):
        images = []
        for size in TRAY_ICON_SIZES:
            img = trim_and_fit(source, size, padding=1)
            images.append(img)
        ico_path = STATUS_DIR / name
        images[0].save(
            ico_path,
            format="ICO",
            sizes=[(s, s) for s in TRAY_ICON_SIZES],
            append_images=images[1:],
        )
        print(f"Saved ICO to {ico_path}")

    # macOS 托盘图标：黑色剪影模板 PNG，图形填满、四周留 3px
    template = to_template(trim_and_fit(source, TRAY_TEMPLATE_SIZE, padding=3))
    for name in ("status_1.png", "status_2.png", "status_3.png"):
        png_path = STATUS_DIR / name
        template.save(png_path, format="PNG")
        print(f"Saved template PNG to {png_path}")


def main() -> None:
    for svg in (SVG_PATH, ICON_SVG_PATH):
        if not svg.exists():
            print(f"SVG not found: {svg}")
            sys.exit(1)

    with tempfile.TemporaryDirectory() as tmp:
        # APP 图标（墨蓝底）：Windows app_icon.ico + 根目录通用图标
        app_png = Path(tmp) / "app_icon_1024.png"
        if render_with_resvg(ICON_SVG_PATH, app_png):
            print("Rendered app icon with resvg")
        elif render_with_qlmanage(ICON_SVG_PATH, app_png):
            print("Rendered app icon with qlmanage (Quick Look fallback)")
        else:
            print("No SVG renderer available. Install resvg: brew install resvg")
            sys.exit(1)
        write_ico(app_png, ICO_PATH, APP_ICON_SIZES)
        write_root_icons(app_png)

        # 托盘图标（无背景剪影，保持原样）
        tray_png = Path(tmp) / "tray_1024.png"
        if render_with_resvg(SVG_PATH, tray_png):
            print("Rendered tray icon with resvg")
        elif render_with_qlmanage(SVG_PATH, tray_png):
            print("Rendered tray icon with qlmanage (Quick Look fallback)")
        else:
            print("No SVG renderer available. Install resvg: brew install resvg")
            sys.exit(1)
        write_status_icons(tray_png)


if __name__ == "__main__":
    main()
