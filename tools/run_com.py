#!/usr/bin/env python3
"""Exécute un .COM de CP/A dans un 6502 simulé (py65), avec un BDOS
minimal sur un dossier du PC. Pour tester ASM.COM hors de l'émulateur.
  run_com.py DOSSIER PROG.COM [ARGS]"""
import sys, os
# py65 installé par tools/setup_linux.sh dans tools/pylib
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pylib'))
from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

def main():
    d, prog = sys.argv[1], sys.argv[2]
    args = ' '.join(sys.argv[3:]).upper()
    mem = bytearray(65536)
    code = open(os.path.join(d, prog), 'rb').read()
    mem[0x500:0x500+len(code)] = code
    mem[0x20C] = 0x00; mem[0x20D] = 0xB4
    mem[0x200:0x203] = bytes([0x4C, 0xF0, 0xFF])     # WBOOT -> $FFF0 : fin
    mem[0x206:0x209] = bytes([0x4C, 0xF3, 0xFF])     # IRQ/BRK -> $FFF3 : fin
    mem[0xFFFE] = 0x06; mem[0xFFFF] = 0x02
    mem[0x210] = 2                                   # CON_CURX
    lines = [l for l in os.environ.get('INPUT', '').split('|')]
    def setfcb(a, name):
        mem[a:a+36] = bytes(36)
        n, _, e = name.partition('.')
        mem[a+1:a+9] = n.ljust(8)[:8].encode(); mem[a+9:a+12] = e.ljust(3)[:3].encode()
    words = args.split()
    setfcb(0x45C, words[0] if words else '')
    mem[0x480] = len(args); mem[0x481:0x481+len(args)] = args.encode()
    m = MPU(memory=mem)
    m.pc = 0x500; m.sp = 0xFD
    mem[0x1FE] = 0xFF; mem[0x1FF] = 0x01  # rts -> $0200
    files = {}   # fcb addr -> [name, data, pos, write]
    dma = 0x480
    out = []
    def fname(a):
        n = mem[a+1:a+9].decode().strip(); e = mem[a+9:a+12].decode().strip()
        return os.path.join(d, n + ('.' + e if e else ''))
    def lookup(p):
        for f in os.listdir(d):
            if f.upper() == os.path.basename(p).upper(): return os.path.join(d, f)
        return None
    steps = 0
    while True:
        pc = m.pc
        if pc == 0xFFF0: break
        if pc == 0xFFF3: print('\n*BRK* non intercepté'); break
        if pc in (0x203, 0xC006, 0xC009, 0xC00C):
            a = m.a
            if pc == 0xC00C: out.append(chr(a))
            elif pc == 0xC006: m.a = 0
            elif pc == 0xC009: m.a = 13
            else:
                x = m.x; adr = a | (m.y << 8); m.a = 0
                if x == 2: out.append(chr(a))
                elif x == 9:
                    while mem[adr] != 0x24: out.append(chr(mem[adr])); adr += 1
                elif x == 26: dma = adr
                elif x == 10:
                    if not lines or (len(lines) == 1 and lines[0] == ''): print('\n[fin des entrées]'); break
                    l = lines.pop(0)[:mem[adr]]
                    out.append(l + '\n')
                    mem[adr+1] = len(l); mem[adr+2:adr+2+len(l)] = l.encode()
                elif x == 15:
                    p = lookup(fname(adr))
                    if p: files[adr] = [p, open(p,'rb').read(), 0, None]
                    else: m.a = 0xFF
                elif x == 19:
                    p = lookup(fname(adr))
                    if p: os.remove(p)
                elif x == 22:
                    files[adr] = [fname(adr), b'', 0, bytearray()]
                elif x == 20:
                    f = files[adr]; blk = f[1][f[2]:f[2]+128]
                    if not blk: m.a = 1
                    else:
                        blk = blk + b'\x1a' * (128 - len(blk))
                        mem[dma:dma+128] = blk; f[2] += 128
                elif x == 21:
                    files[adr][3] += mem[dma:dma+128]
                elif x == 16:
                    f = files.get(adr)
                    if f and f[3] is not None: open(f[0], 'wb').write(f[3])
                elif x == 115:
                    pass        # graphisme : mode texte (GETMODE -> 0)
                else:
                    print('BDOS ?', x); break
            # rts
            lo = mem[0x100 + ((m.sp + 1) & 255)]; hi = mem[0x100 + ((m.sp + 2) & 255)]
            m.sp = (m.sp + 2) & 255; m.pc = ((hi << 8) | lo) + 1
            continue
        m.step(); steps += 1
        if steps > int(os.environ.get("MAXSTEPS", "400000000")): print("trop long PC=%04X" % m.pc); break
    sys.stdout.write(''.join(out).replace('\r', ''))
    print('[%d instructions]' % steps)
main()
