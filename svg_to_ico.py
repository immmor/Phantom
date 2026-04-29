import io
import struct
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM
from PIL import Image

svg_path = "assets/images/phantom.svg"
ico_path = "windows/runner/resources/app_icon.ico"

svg_content = open(svg_path, 'r').read()

svg_content = svg_content.replace('fill="url(#bodyGrad)"', 'fill="#8B9DC3"')
svg_content = svg_content.replace('fill="url(#hatGrad)"', 'fill="#2C3E50"')
svg_content = svg_content.replace('style="stop-color:#5D6D7E;stop-opacity:1"', 'stop-color="#5D6D7E"')
svg_content = svg_content.replace('style="stop-color:#1A252F;stop-opacity:1"', 'stop-color="#1A252F"')

temp_svg = "/tmp/phantom_flat.svg"
open(temp_svg, 'w').write(svg_content)

sizes = [256, 128, 96, 64, 48, 32, 16]

drawing = svg2rlg(temp_svg)
if drawing is None:
    print("Failed to load SVG")
    exit(1)

imgs = []
for size in sizes:
    img = renderPM.drawToPIL(drawing, width=size, height=size)
    img = img.convert("RGBA")
    imgs.append(img)

imgs[0].save(
    ico_path,
    format="ICO",
    sizes=[(s, s) for s in sizes],
    append_images=imgs[1:]
)

print(f"Saved ICO to {ico_path}")