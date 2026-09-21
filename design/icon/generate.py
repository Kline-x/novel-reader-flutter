out = 'design/icon'
CX = 512

# 一层屋面。实心的一整片，不是一条带子：
# 脊在正中最高，两侧顺下来，到转角再挑起，底边平直收口。
# 上一版把底边也跟着起伏，整道檐就成了「胡须」，看不出是屋顶。
def eave(y_ridge, hw, drop, t):
    y_corner = y_ridge + drop
    y_bottom = y_corner + t
    # 第二个控制点压到转角线以下，末端才会往上挑——这就是飞檐的起翘
    return (f"M {CX} {y_ridge} "
            f"C {CX+hw*0.45:.0f} {y_ridge+drop*1.15:.0f} "
            f"{CX+hw*0.80:.0f} {y_corner+drop*0.55:.0f} {CX+hw} {y_corner} "
            f"L {CX+hw} {y_bottom} L {CX-hw} {y_bottom} L {CX-hw} {y_corner} "
            f"C {CX-hw*0.80:.0f} {y_corner+drop*0.55:.0f} "
            f"{CX-hw*0.45:.0f} {y_ridge+drop*1.15:.0f} {CX} {y_ridge} Z")

EAVES = [   # (脊 y, 半宽, 脊到转角的落差, 檐口厚)
    # 檐口厚度不能再薄：48px 下 1024 画布缩了 21 倍，
    # 26px 的檐口只剩 1.2px，转角先糊掉
    (300, 126, 46, 36),
    (436, 192, 54, 40),
    (578, 258, 62, 44),
]
BODIES = [  # 屋身：把三层檐串成一座阁，没有它三道檐就是三片飘着的瓦
    (512-64,  378, 128, 62, 14),
    (512-98,  528, 196, 54, 16),
    (512-136, 682, 272, 34, 14),
]
PLINTH = (512-276, 712, 552, 96, 28)
MAST   = (512-9, 262, 18, 42)       # 刹杆
FINIAL = (512, 236, 28)             # 宝顶

def content(eave_fill, body_fill, plinth_fill, finial_fill, page_fill=None):
    fx, fy, fr = FINIAL
    s = [f'<path d="M {fx} {fy-fr} L {fx+fr*0.62:.0f} {fy} L {fx} {fy+fr} '
         f'L {fx-fr*0.62:.0f} {fy} Z" fill="{finial_fill}"/>',
         f'<rect x="{MAST[0]}" y="{MAST[1]}" width="{MAST[2]}" height="{MAST[3]}" '
         f'rx="8" fill="{body_fill}"/>']
    for (x, y, w, h, r) in BODIES:
        s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{body_fill}"/>')
    for e in EAVES:
        s.append(f'<path d="{eave(*e)}" fill="{eave_fill}"/>')
    px, py, pw, ph, pr = PLINTH
    s.append(f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="{pr}" fill="{plinth_fill}"/>')
    if page_fill:
        # 书口：底座下缘一道细线，点明这一函是书，不是石台
        s.append(f'<rect x="{px+36}" y="{py+ph-32}" width="{pw-72}" height="10" '
                 f'rx="5" fill="{page_fill}" opacity="0.30"/>')
    return '\n'.join('  ' + l for l in s)

DEFS = '''  <defs>
    <!-- 背景：深夜色，把冰蓝整个让给主体 -->
    <linearGradient id="bg" x1="0" y1="0" x2="0.72" y2="1">
      <stop offset="0" stop-color="#14486A"/>
      <stop offset="0.55" stop-color="#0B2B41"/>
      <stop offset="1" stop-color="#05151F"/>
    </linearGradient>
    <!-- 檐口：最亮的一档冰蓝。必须 userSpaceOnUse——三道檐要共用同一段渐变，
         默认的 objectBoundingBox 会让每道檐各自从头渐变一遍，层次就散了 -->
    <linearGradient id="eave" gradientUnits="userSpaceOnUse"
                    x1="512" y1="280" x2="512" y2="660">
      <stop offset="0" stop-color="#CDF4FF"/>
      <stop offset="1" stop-color="#7FDCFF"/>
    </linearGradient>
    <!-- 屋身：压暗一档，让檐口浮起来 -->
    <linearGradient id="body" gradientUnits="userSpaceOnUse"
                    x1="512" y1="300" x2="512" y2="700">
      <stop offset="0" stop-color="#57C6F7"/>
      <stop offset="1" stop-color="#2E9FDC"/>
    </linearGradient>
  </defs>
'''

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n')
BODY = content('url(#eave)', 'url(#body)', 'url(#eave)', '#FFFFFF', '#05151F')

def w(name, text):
    open(f'{out}/{name}', 'w', encoding='utf-8', newline='\n').write(text)

w('app_icon.svg',
  HEAD + DEFS + '  <rect width="1024" height="1024" fill="url(#bg)"/>\n' + BODY + '\n</svg>\n')
w('app_icon_foreground.svg',
  HEAD + DEFS + '  <g transform="translate(512 512) scale(0.86) translate(-512 -512)">\n'
  + '\n'.join('  ' + l for l in BODY.split('\n')) + '\n  </g>\n</svg>\n')
w('app_icon_background.svg',
  HEAD + DEFS + '  <rect width="1024" height="1024" fill="url(#bg)"/>\n</svg>\n')
w('app_icon_monochrome.svg',
  HEAD + '  <g transform="translate(512 512) scale(0.86) translate(-512 -512)">\n'
  + '\n'.join('  ' + l for l in content('#000', '#000', '#000', '#000').split('\n'))
  + '\n  </g>\n</svg>\n')
print('generated')
