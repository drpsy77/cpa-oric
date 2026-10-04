import sys
m=open(sys.argv[1],'rb').read()
for r in range(28):
    row=m[0xBB80+40*r:0xBB80+40*r+40]
    s=''.join(chr(c&0x7f) if 32<=(c&0x7f)<127 else ('#' if c&0x80 else '.') for c in row)
    print('%2d|%s|'%(r,s))
print('PC area: ticks=%d curx=%d cury=%d kb_head=%d caps=%d' % (m[0x21B]|m[0x21C]<<8, m[0x210], m[0x211], m[0x215], m[0x21A]))
