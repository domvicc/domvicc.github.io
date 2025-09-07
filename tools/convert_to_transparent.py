from PIL import Image

in_path = 'assets/img/projects/dom_vicc.jpeg'
out_path = 'assets/img/header-logo.png'

img = Image.open(in_path).convert('RGBA')

# Tolerance for "near-white" background
threshold = 240

pixels = img.load()
width, height = img.size

for y in range(height):
    for x in range(width):
        r, g, b, a = pixels[x, y]
        if r >= threshold and g >= threshold and b >= threshold:
            # make transparent
            pixels[x, y] = (r, g, b, 0)

img.save(out_path)
print(f'Wrote {out_path}')
