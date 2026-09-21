import os, sys
OUT = sys.argv[1]
CX = 512
os.makedirs(OUT, exist_ok=True)

DEFS = '''  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.72" y2="1">
      <stop offset="0" stop-color="#14486A"/>
      <stop offset="0.55" stop-color="#0B2B41"/>
      <stop offset="1" stop-color="#05151F"/>
    </linearGradient>
    <linearGradient id="ice" gradientUnits="userSpaceOnUse" x1="512" y1="200" x2="512" y2="860">
      <stop offset="0" stop-color="#CDF4FF"/>
      <stop offset="1" stop-color="#7FDCFF"/>
    </linearGradient>
    <linearGradient id="mid" gradientUnits="userSpaceOnUse" x1="512" y1="240" x2="512" y2="860">
      <stop offset="0" stop-color="#57C6F7"/>
      <stop offset="1" stop-color="#2E9FDC"/>
    </linearGradient>
  </defs>
'''
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n')

def wrap(body):
    return (HEAD + DEFS + '  <rect width="1024" height="1024" fill="url(#bg)"/>\n'
            + body + '\n</svg>\n')

def rect(x, y, w, h, r, fill):
    return (f'  <rect x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" '
            f'rx="{r:.0f}" fill="{fill}"/>')

def eave(y_ridge, hw, drop, t, fill):
    """实心屋面：脊在正中，两侧顺下，转角挑起，底边平直"""
    yc, yb = y_ridge + drop, y_ridge + drop + t
    return (f'  <path d="M {CX} {y_ridge} '
            f'C {CX+hw*0.45:.0f} {y_ridge+drop*1.15:.0f} {CX+hw*0.80:.0f} {yc+drop*0.55:.0f} {CX+hw} {yc} '
            f'L {CX+hw} {yb} L {CX-hw} {yb} L {CX-hw} {yc} '
            f'C {CX-hw*0.80:.0f} {yc+drop*0.55:.0f} {CX-hw*0.45:.0f} {y_ridge+drop*1.15:.0f} {CX} {y_ridge} Z" '
            f'fill="{fill}"/>')

def spines(cx, bottom, widths, heights, gap, fill, band=None):
    """一排书脊，底对齐。band 给每根加签条——
    不加的话，高矮不一的竖条会被直接读成柱状图"""
    total = sum(widths) + gap * (len(widths) - 1)
    x = cx - total / 2
    out = []
    for w, h in zip(widths, heights):
        top = bottom - h
        out.append(rect(x, top, w, h, min(14, w // 4), fill))
        if band:
            out.append(rect(x + w * 0.16, top + h * 0.20, w * 0.68, h * 0.11, 6, band))
            out.append(rect(x + w * 0.16, top + h * 0.38, w * 0.68, h * 0.06, 4, band))
        x += w + gap
    return '\n'.join(out)

C = {}

# A 飞檐叠阁：三层屋面逐层收窄，底下托着一函书
a = ['  <path d="M 512 208 L 529 236 L 512 264 L 495 236 Z" fill="#FFFFFF"/>',
     rect(503, 262, 18, 42, 8, 'url(#mid)')]
for (x, y, w, h, r) in [(448,378,128,62,14), (414,528,196,54,16), (376,682,272,34,14)]:
    a.append(rect(x, y, w, h, r, 'url(#mid)'))
for (yr, hw, dr, t) in [(300,126,46,36), (436,192,54,40), (578,258,62,44)]:
    a.append(eave(yr, hw, dr, t, 'url(#ice)'))
a.append(rect(236, 712, 552, 96, 28, 'url(#ice)'))
a.append('  <rect x="272" y="776" width="480" height="10" rx="5" fill="#05151F" opacity="0.30"/>')
C['A_feiyan_diege'] = '\n'.join(a)

# B 一檐一架：一道飞檐罩着一排书。去掉台基，否则整体读成希腊神庙
b = [spines(512, 726, [58, 82, 66, 90, 62], [214, 262, 230, 274, 240], 20,
            'url(#mid)', '#0B2B41'),
     eave(330, 296, 76, 48, 'url(#ice)'),
     rect(272, 726, 480, 40, 16, 'url(#ice)')]
C['B_yiyan_yijia'] = '\n'.join(b)

# C 月洞门：园林月洞门里立着三册书
c = ['  <circle cx="512" cy="498" r="248" fill="none" stroke="url(#ice)" stroke-width="56"/>',
     spines(512, 660, [64, 78, 68], [190, 232, 206], 22, 'url(#mid)', '#0B2B41'),
     rect(372, 660, 280, 30, 12, 'url(#ice)')]
C['C_yuedongmen'] = '\n'.join(c)

# D 函套：蓝布函套裹着一函书，露出书口与两枚骨签
d = [rect(276, 236, 472, 552, 40, 'url(#mid)'),
     rect(276, 236, 150, 552, 40, 'url(#ice)'),
     rect(406, 236, 20, 552, 0, 'url(#ice)')]
for y in (386, 608):
    d.append(rect(322, y, 62, 26, 12, '#05151F'))
for y in (352, 470, 588, 706):
    d.append(rect(492, y, 214, 12, 6, 'url(#ice)'))
C['D_hantao'] = '\n'.join(d)

# E 藏书印：一枚方印，印文是阁
e = ['  <rect x="252" y="252" width="520" height="520" rx="66" '
     'fill="none" stroke="url(#ice)" stroke-width="50"/>',
     eave(392, 166, 44, 34, 'url(#ice)'),
     rect(430, 494, 34, 128, 10, 'url(#mid)'),
     rect(560, 494, 34, 128, 10, 'url(#mid)'),
     rect(392, 622, 240, 36, 14, 'url(#ice)')]
C['E_cangshuyin'] = '\n'.join(e)

# F 一册一月：弦月斜挂在一册书上方。
# 满月正对着一条横板会被读成用户头像，所以月要偏、要缺，书也要看得出书脊和书页
f = ['  <path d="M 700 248 A 152 152 0 1 0 700 528 '
     'A 120 120 0 1 1 700 248 Z" fill="url(#ice)"/>',
     rect(296, 556, 96, 300, 20, 'url(#ice)'),
     rect(392, 580, 336, 252, 18, 'url(#mid)')]
for i, y in enumerate((636, 700, 764)):
    f.append(rect(434, y, 252 - i * 34, 12, 6, 'url(#ice)'))
C['F_yice_yiyue'] = '\n'.join(f)

for name, body in C.items():
    open(f'{OUT}/{name}.svg', 'w', encoding='utf-8', newline='\n').write(wrap(body))
print('\n'.join(sorted(C)))
