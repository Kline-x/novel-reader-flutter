import os, re, sys
SRC_LINE = sys.argv[1]      # lucide 线性（24 网格）
SRC_FILL = sys.argv[2]      # phosphor 实心（256 网格）
OUT = sys.argv[3]
os.makedirs(OUT, exist_ok=True)

# 不再手工摆点。底图用专业图标库的矢量——严格网格、曲率连续，
# 这是上一批「字体标」立刻拉开差距的同一个原因：用真正画好的轮廓。
DEFS = '''  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.72" y2="1">
      <stop offset="0" stop-color="#14486A"/>
      <stop offset="0.55" stop-color="#0B2B41"/>
      <stop offset="1" stop-color="#05151F"/>
    </linearGradient>
    <linearGradient id="bgSolid" x1="0" y1="0" x2="0.72" y2="1">
      <stop offset="0" stop-color="#9FE4FF"/>
      <stop offset="1" stop-color="#2E9FDC"/>
    </linearGradient>
    <linearGradient id="ice" gradientUnits="userSpaceOnUse" x1="512" y1="200" x2="512" y2="824">
      <stop offset="0" stop-color="#EAFBFF"/>
      <stop offset="1" stop-color="#6FD3F9"/>
    </linearGradient>
  </defs>
'''
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n')

def inner(path):
    """取出图标文件里的图形元素，丢掉外层 svg 与它的样式"""
    t = open(path, encoding='utf-8').read()
    t = re.sub(r'<\?xml.*?\?>', '', t, flags=re.S)
    t = re.sub(r'<!--.*?-->', '', t, flags=re.S)
    body = t[t.index('>', t.index('<svg')) + 1: t.rindex('</svg>')]
    return body.strip()

def line_icon(name, glyph, grid=24, span=592, weight=2.45, bgfill='url(#bg)'):
    """线性图标：按 grid→span 缩放，笔画粗细用 grid 单位给，缩放后自然等比"""
    k = span / grid
    off = 512 - span / 2
    g = inner(glyph)
    return (HEAD + DEFS
            + f'  <rect width="1024" height="1024" fill="{bgfill}"/>\n'
            + f'  <g transform="translate({off:.1f} {off:.1f}) scale({k:.4f})" '
              f'fill="none" stroke="url(#ice)" stroke-width="{weight}" '
              f'stroke-linecap="round" stroke-linejoin="round">\n'
            + '    ' + g.replace('\n', '\n    ') + '\n  </g>\n</svg>\n')

def fill_icon(name, glyph, grid=256, span=600, fill='url(#ice)', bgfill='url(#bg)'):
    k = span / grid
    off = 512 - span / 2
    g = inner(glyph)
    return (HEAD + DEFS
            + f'  <rect width="1024" height="1024" fill="{bgfill}"/>\n'
            + f'  <g transform="translate({off:.1f} {off:.1f}) scale({k:.4f})" '
              f'fill="{fill}">\n'
            + '    ' + g.replace('\n', '\n    ') + '\n  </g>\n</svg>\n')

jobs = [
    ('P1_kaijuan_xian', line_icon, f'{SRC_LINE}/book-open-text.svg', {}),
    ('P2_cangshu_xian', line_icon, f'{SRC_LINE}/library.svg', {}),
    ('P3_juanzhou_xian', line_icon, f'{SRC_LINE}/scroll-text.svg', {}),
    ('P4_yeyue_xian', line_icon, f'{SRC_LINE}/moon-star.svg', {}),
    ('P5_cangshu_shi', fill_icon, f'{SRC_FILL}/books.svg', {}),
    ('P6_juanzhou_shi', fill_icon, f'{SRC_FILL}/scroll.svg', {}),
    ('P7_kaijuan_shi', fill_icon, f'{SRC_FILL}/book-open-text.svg', {}),
    # 反底：实心冰蓝印面 + 深色图形，小尺寸对比最强
    ('P8_fandi_cangshu', fill_icon, f'{SRC_FILL}/books.svg',
     dict(fill='#07202F', bgfill='url(#bgSolid)')),
    ('P9_fandi_juan', fill_icon, f'{SRC_FILL}/scroll.svg',
     dict(fill='#07202F', bgfill='url(#bgSolid)')),
]
for name, fn, path, kw in jobs:
    open(f'{OUT}/{name}.svg', 'w', encoding='utf-8', newline='\n').write(
        fn(name, path, **kw))
print(len(jobs), 'composed')
