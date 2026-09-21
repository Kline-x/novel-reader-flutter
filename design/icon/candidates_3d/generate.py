import os, sys
OUT = sys.argv[1]
CX = 512
os.makedirs(OUT, exist_ok=True)

# 立体感全靠「同一个形被拆成几个面、各面受光不同」，不是靠加投影。
# 三档光：顶面最亮、左面中间、右面压暗，光源统一在左上。
DEFS = '''  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.72" y2="1">
      <stop offset="0" stop-color="#14486A"/>
      <stop offset="0.55" stop-color="#0B2B41"/>
      <stop offset="1" stop-color="#05151F"/>
    </linearGradient>
    <linearGradient id="fTop" gradientUnits="userSpaceOnUse" x1="512" y1="140" x2="512" y2="760">
      <stop offset="0" stop-color="#EAFBFF"/><stop offset="1" stop-color="#A8E7FF"/>
    </linearGradient>
    <linearGradient id="fLeft" gradientUnits="userSpaceOnUse" x1="512" y1="220" x2="512" y2="900">
      <stop offset="0" stop-color="#6FD3F9"/><stop offset="1" stop-color="#3CACE6"/>
    </linearGradient>
    <linearGradient id="fRight" gradientUnits="userSpaceOnUse" x1="512" y1="220" x2="512" y2="900">
      <stop offset="0" stop-color="#2F90CB"/><stop offset="1" stop-color="#1B6497"/>
    </linearGradient>
    <linearGradient id="fBack" gradientUnits="userSpaceOnUse" x1="512" y1="220" x2="512" y2="900">
      <stop offset="0" stop-color="#1D6EA3"/><stop offset="1" stop-color="#134C72"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#EAFBFF" stop-opacity="0.9"/>
      <stop offset="0.5" stop-color="#7FDCFF" stop-opacity="0.28"/>
      <stop offset="1" stop-color="#7FDCFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="cone" gradientUnits="userSpaceOnUse" x1="512" y1="438" x2="512" y2="806">
      <stop offset="0" stop-color="#EAFBFF" stop-opacity="0.42"/>
      <stop offset="1" stop-color="#7FDCFF" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#01080D" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#01080D" stop-opacity="0"/>
    </radialGradient>
  </defs>
'''
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n')

def wrap(body):
    return (HEAD + DEFS + '  <rect width="1024" height="1024" fill="url(#bg)"/>\n'
            + body + '\n</svg>\n')

def poly(pts, fill):
    s = ' '.join(f'{x:.1f},{y:.1f}' for x, y in pts)
    return f'  <polygon points="{s}" fill="{fill}"/>'

def ground(cy, rx=250, ry=42):
    """接地阴影：立体的形需要一个落点，否则看着像飘着"""
    return f'  <ellipse cx="{CX}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#shadow)"/>'

def iso_box(cx, top_y, w, d, h):
    """等距立方：返回 顶面 / 左面 / 右面"""
    T = (cx, top_y); R = (cx + w, top_y + d); B = (cx, top_y + 2*d); L = (cx - w, top_y + d)
    return ([T, R, B, L],
            [L, B, (B[0], B[1] + h), (L[0], L[1] + h)],
            [R, B, (B[0], B[1] + h), (R[0], R[1] + h)])

C = {}

# G 冰棱：一颗竖立的冰晶，四个可见面的棱线交于正中。
#   光从左上来，同一块形靠面的明暗差自己立起来
g = [ground(878, 210, 40)]
apex, low = (512, 168), (512, 856)
gl, gr, gf = (268, 452), (756, 452), (512, 548)
g += [poly([apex, gl, gf], 'url(#fTop)'),
      poly([apex, gf, gr], 'url(#fLeft)'),
      poly([gl, gf, low], 'url(#fLeft)'),
      poly([gf, gr, low], 'url(#fRight)')]
C['G_binleng'] = '\n'.join(g)

# H 书页扇：一册书摊开，纸页绕着书脊扇形展开。
#   靠每一页的转角差和明暗交替造厚度，不是画一摞方块
h = [ground(852, 270, 38)]
h.append('  <g transform="translate(512 790)">')
fills = ['url(#fRight)', 'url(#fLeft)', 'url(#fTop)', 'url(#fLeft)', 'url(#fRight)']
for i, ang in enumerate((-52, -26, 0, 26, 52)):
    h.append(f'    <rect x="-118" y="-470" width="236" height="470" rx="26" '
             f'fill="{fills[i]}" transform="rotate({ang})"/>')
h.append('  </g>')
C['H_shuye_shan'] = '\n'.join(h)

# I 等距阁：屋顶飘了三次，病根是檐口外挑——挑出去的那一圈下面就是背景，
#   眼睛立刻把屋顶和屋身判成两个物件，整体读成「上传」。
#   这版让屋顶底边和屋身顶边**完全重合**，不留一丝缝；檐口线改成压在屋身上的一道带
i = [ground(892, 250, 40)]
T, R, B, L_ = (512, 430), (752, 564), (512, 698), (272, 564)
btop, blf, brt = iso_box(512, 430, 240, 134, 150)
i += [poly(blf, 'url(#fLeft)'), poly(brt, 'url(#fRight)')]
i += [poly([L_, B, (B[0], B[1] + 26), (L_[0], L_[1] + 26)], 'url(#fRight)'),
      poly([B, R, (R[0], R[1] + 26), (B[0], B[1] + 26)], 'url(#fRight)')]
apex = (512, 286)   # 脊太高会读成帐篷，压到这个高度才是屋顶
i += [poly([apex, L_, B], 'url(#fTop)'), poly([apex, B, R], 'url(#fLeft)')]
C['I_dengju_ge'] = chr(10).join(i)

# J 书匣：等距的一只匣子，盖子刚掀开，里面透出光。
#   盖子离太远就成了「解压/上传」，贴着开一条缝才是「打开」
j = [ground(880, 240, 40)]
top, lf, rt = iso_box(512, 470, 240, 134, 150)
j += [poly(lf, 'url(#fLeft)'), poly(rt, 'url(#fRight)'),
      poly(top, 'url(#fBack)'),
      '  <ellipse cx="512" cy="604" rx="196" ry="110" fill="url(#glow)"/>',
      poly([(x, y - 108) for (x, y) in top], 'url(#fTop)')]
C['J_shuxia'] = '\n'.join(j)

# K 夜读灯：一盏灯把光泼在一册书上。
#   光锥上一版画反了——尖在下、口在上，成了个漏斗。光是从灯口往外散的
k = [ground(886, 240, 36)]
k.append('  <rect x="502" y="188" width="20" height="92" rx="9" fill="url(#fRight)"/>')
k.append(poly([(436, 272), (588, 272), (664, 424), (360, 424)], 'url(#fTop)'))
k.append('  <ellipse cx="512" cy="424" rx="152" ry="40" fill="url(#fLeft)"/>')
k.append('  <path d="M 380 438 L 250 792 L 774 792 L 644 438 Z" fill="url(#cone)"/>')
k.append('  <ellipse cx="512" cy="430" rx="110" ry="26" fill="url(#glow)"/>')
btop, blf, brt = iso_box(512, 668, 210, 116, 52)
k += [poly(blf, 'url(#fLeft)'), poly(brt, 'url(#fRight)'), poly(btop, 'url(#fTop)')]
C['K_yedu_deng'] = chr(10).join(k)

# L 等距书：一册合起来的书，封面、书脊、书口三个面各自受光
l = [ground(860, 250, 40)]
top, lf, rt = iso_box(512, 396, 250, 140, 104)
l += [poly(lf, 'url(#fLeft)'), poly(rt, 'url(#fRight)'), poly(top, 'url(#fTop)')]
for n in range(1, 4):                                # 书口页线，顺着右面的斜向走
    dy = n * 24
    l.append(f'  <path d="M 512 {676+dy} L 762 {536+dy}" stroke="#0B2B41" '
             f'stroke-width="9" stroke-opacity="0.35" stroke-linecap="round"/>')
# 书签带：沿着封面平面的走向铺，不能垂直插进去——那会看成封面被豁了一块
T, R, B, L_ = (512, 396), (762, 536), (512, 676), (262, 536)
def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
l.append(poly([lerp(T, L_, 0.20), lerp(R, B, 0.20),
               lerp(R, B, 0.34), lerp(T, L_, 0.34)], 'url(#fLeft)'))
C['L_dengju_shu'] = '\n'.join(l)

for name, body in C.items():
    open(f'{OUT}/{name}.svg', 'w', encoding='utf-8', newline='\n').write(wrap(body))
print('\n'.join(sorted(C)))
