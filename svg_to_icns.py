import os
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM

svg_path = "assets/images/phantom.svg"
output_dir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"

# 直接渲染原始 SVG（青色渐变幽灵），不替换颜色
drawing = svg2rlg(svg_path)
if drawing is None:
    print("Failed to load SVG")
    exit(1)

os.makedirs(output_dir, exist_ok=True)

# macOS AppIcon.appiconset 所需尺寸（文件名与 Contents.json 对应）
sizes = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

for filename, size in sizes.items():
    img = renderPM.drawToPIL(drawing, width=size, height=size)
    img = img.convert("RGBA")
    output_path = os.path.join(output_dir, filename)
    img.save(output_path, format="PNG")
    print(f"Saved {output_path} ({size}x{size})")

print("Done. Rebuild with: flutter build macos --release")
