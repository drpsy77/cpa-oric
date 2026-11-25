#!/usr/bin/env python3
"""dis65.py : le source écrit se réassemble en un fichier identique, et reste
juste quand on le modifie.

  python3 tools/test_dis65.py

1. Fichiers entiers, sans description : les .COM de CP/A (build/progs), la
   ROM 1.1 (tools/oricutron/roms/basic11b.rom, si elle est là), les cas
   tordus de test_dis.py ; xa redonne le fichier.
2. Un programme fabriqué (tables de sauts en mots et en deux moitiés, saut
   par RTS, pointeurs, vecteur posé par deux LDA #) : les candidats proposés
   sont copiés dans la description, puis une instruction est insérée en tête
   du source écrit ; réassemblé, il est égal au programme d'origine assemblé
   avec la même insertion (toutes les adresses sont devenues des étiquettes).
3. Tous les mots-clés sur ce programme (noms, zones data et text, rem, fichier
   à part), un bloc lu dans un .TAP, et les erreurs de description.
"""
import os
import shutil
import subprocess
import sys
import tempfile

R = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(R, "..", "build", "progs")
XA = os.environ.get("XA") or os.path.join(R, "xa")
ROM = os.path.join(R, "oricutron", "roms", "basic11b.rom")
sys.path.insert(0, R)
import mktap                                    # noqa: E402
import test_dis                                 # noqa: E402

PROG = """        *= $6000
start   lda #<irq
        sta vec
        lda #>irq
        sta vec+1
        ldx #0
        txa
        asl
        tay
        lda jtab,y
        sta $3d
        lda jtab+1,y
        sta $3e
        jsr go
        jsr disp
        jsr show
        ldx #1
        lda tlo,x
        sta $40
        lda thi,x
        sta $41
        jmp ($0040)
go      jmp ($003d)
disp    lda rhi,x
        pha
        lda rlo,x
        pha
        rts
show    lda #<msg
        ldy #>msg
        jsr $ccb0
        lda ptab,x
        sta $42
        lda ptab+1,x
        sta $43
        jmp (vec)
r0      inc $50
        rts
r1      dec $50
        rts
r2      lda #1
        rts
r3      lda #2
        rts
r4      lda #3
        rts
r5      lda #4
        rts
irq     rti
vec     .word 0
jtab    .word r0, r1
tlo     .byt <r2, <r3
thi     .byt >r2, >r3
rlo     .byt <(r4-1), <(r5-1)
rhi     .byt >(r4-1), >(r5-1)
ptab    .word msg, msg2
msg     .asc "HELLO", 0
msg2    .asc "BYE", 0
gfx     .byt $40,$40,$55,$6A,$40,$41,$7F,$40,$55,$6A,$55,$6A,$40,$40,$55,$6A
        .byt $40,$41,$7F,$40,$55,$6A,$55,$6A,$40,$40,$55,$6A,$40,$41,$7F,$01
"""

ko = 0


def dit(bon, quoi, detail=""):
    global ko
    if not bon:
        ko += 1
    print("%s : %s%s" % ("bon" if bon else "FAUX", quoi, "\n" + detail if detail and not bon else ""))


def xa(tmp, source, sortie, lab=None):
    c = [XA, "-o", sortie, source] + (["-l", lab] if lab else [])
    p = subprocess.run(c, cwd=tmp, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return open(os.path.join(tmp, sortie), "rb").read() if p.returncode == 0 else None


def dis65(tmp, *args):
    p = subprocess.run([sys.executable, os.path.join(R, "dis65.py")] + list(args), cwd=tmp,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return p.returncode, p.stdout.decode("utf-8")


def entiers(tmp):
    """fichiers entiers, sans description"""
    jobs = []
    if os.path.isdir(B):
        for n in sorted(f for f in os.listdir(B) if f.endswith(".COM")):
            jobs.append((n, open(os.path.join(B, n), "rb").read(), ["0500"], ()))
    else:
        print("build/progs absent : les .COM ne sont pas essayés (./build.sh)")
    if os.path.exists(ROM):
        jobs.append(("BASIC11.ROM", open(ROM, "rb").read(), ["C000"],
                     ("StartBASIC cld", "jsr SetScreen", "sta VIA_DDRA", ".word Reset")))
    cas = test_dis.fabriques()
    jobs.append(("CAS.BIN", cas[0][1], ["9800", "9800", "985C"],
                 ("PrintChar = $F5C1", "VIA_ORB = $0300", ".byt $AD,$12,$00", ".byt $BD,$80,$00",
                  "lda $0080,y", "jsr $0050", "L981A+1", "jsr PrintChar", "sta VIA_ORB",
                  "bcc $97A1", "jsr $F581", "jmp (L9840)", ".byt $2C", "L985C   nop",
                  "L980F   lda #$02", '"Il a dit "', "L9840   .dsb 28,$FF")))
    for nom, data, args, _, _ in cas[2:]:
        jobs.append((nom, data, args[:1], ()))
    total = 0
    for nom, data, args, attendus in jobs:
        d = os.path.join(tmp, nom.replace(".", "_"))
        os.mkdir(d)
        open(os.path.join(d, nom), "wb").write(data)
        rc, sortie = dis65(d, nom, *args)
        src = os.path.join(d, os.path.splitext(nom)[0].lower() + ".s")
        texte = open(src, encoding="utf-8").read() if os.path.exists(src) else ""
        absents = [a for a in attendus if a not in texte]
        bon = rc == 0 and "fichier identique" in sortie and not absents
        total += bon
        if not bon:
            dit(False, "%s %s" % (nom, " ".join(args)),
                sortie + "".join("  absent du source : %s\n" % a for a in absents))
    dit(total == len(jobs), "%d fichiers entiers réassemblés à l'identique sur %d"
        % (total, len(jobs)))


def inserer(source):
    """un NOP juste après *= : tout le programme est décalé d'un octet"""
    l = source.split("\n")
    k = next(i for i, x in enumerate(l) if x.strip().startswith("*="))
    return "\n".join(l[:k + 1] + ["        nop"] + l[k + 1:])


def fabrique(tmp):
    d = os.path.join(tmp, "prog")
    os.mkdir(d)
    open(os.path.join(d, "orig.s"), "w").write(PROG)
    ref = xa(d, "orig.s", "p.bin", "orig.lab")
    if ref is None:
        dit(False, "programme fabriqué : xa")
        return
    lab = {n: int(a, 16) for a, n in (l.split()[:2] for l in open(os.path.join(d, "orig.lab")))}
    open(os.path.join(d, "orig1.s"), "w").write(inserer(PROG))
    ref1 = xa(d, "orig1.s", "p1.bin")

    # 2. description faite des candidats proposés, jusqu'à ce qu'il n'y en ait plus
    desc = os.path.join(d, "p.dis")
    open(desc, "w").write("file p.bin 6000\nentry 6000\n")
    vus = []
    for tour in range(4):
        rc, sortie = dis65(d, "p.dis")
        if "candidats" not in sortie:
            break
        cand = [l[2:] for l in sortie.split("candidats")[1].split("\n")[1:] if l.startswith("  ")]
        vus += cand
        open(desc, "a").write("\n".join(cand) + "\n")
    attendus = ["entry %04X" % lab["irq"], "lo 6000 %04X" % lab["irq"],
                "table %04X 2" % lab["jtab"],
                "table2 %04X %04X 2" % (lab["tlo"], lab["thi"]),
                "rtstable2 %04X %04X 2" % (lab["rlo"], lab["rhi"]),
                "pointers %04X 2" % lab["ptab"],
                "lo %04X %04X" % (lab["show"], lab["msg"])]
    absents = [a for a in attendus if not any(c.startswith(a) for c in vus)]
    dit(not absents and rc == 0 and "fichier identique" in sortie and "candidats" not in sortie,
        "candidats proposés, description complétée (%d lignes)" % len(vus),
        sortie + "".join("  candidat absent : %s\n" % a for a in absents))
    src = open(os.path.join(d, "p.s"), encoding="utf-8").read()
    open(os.path.join(d, "p1.s"), "w", encoding="utf-8").write(inserer(src))
    dit(ref1 is not None and xa(d, "p1.s", "q1.bin") == ref1,
        "source décalé d'un octet : égal à l'original décalé")

    # sans les tables, le même décalage donne un programme faux (le test mesure bien)
    open(os.path.join(d, "nu.dis"), "w").write("file p.bin 6000\n")
    dis65(d, "nu.dis")
    nu = open(os.path.join(d, "nu.s"), encoding="utf-8").read()
    open(os.path.join(d, "nu1.s"), "w", encoding="utf-8").write(inserer(nu))
    dit(xa(d, "nu1.s", "nu1.bin") != ref1, "sans description, le source décalé est faux (attendu)")

    # 3. tous les mots-clés
    t = dict(lab)
    t["fin"] = 0x6000 + len(ref) - 1
    t["msgfin"] = lab["gfx"] - 1
    t["show2"] = lab["show"] + 2
    open(os.path.join(d, "tout.dis"), "w").write("""; essai
file  p.bin 6000 %(fin)04X
entry 6000 Start
entry %(irq)04X Irq          ; vecteur
lo 6000 %(irq)04X
hi 6005 %(irq)04X
lo %(show)04X %(msg)04X
hi %(show2)04X %(msg)04X
name  %(vec)04X Vec
name  3D Jump
name  CCB0 PrintStr
table %(jtab)04X 2 JumpTab
table2 %(tlo)04X %(thi)04X 2 Lows
rtstable2 %(rlo)04X %(rhi)04X 2
pointers %(ptab)04X 2 Texts
text  %(msg)04X-%(msgfin)04X
data  %(gfx)04X-%(fin)04X Gfx
rem   %(disp)04X saut par RTS ; les adresses sont diminuées de 1
rem   %(disp)04X (deuxième ligne)
""" % t)
    rc, sortie = dis65(d, "tout.dis")
    src = open(os.path.join(d, "tout.s"), encoding="utf-8").read()
    gfx = os.path.join(d, "tout_gfx.s")
    g = open(gfx, encoding="utf-8").read() if os.path.exists(gfx) else ""
    attendus = ["Jump    = $3D", "PrintStr = $CCB0", "Start   lda #<Irq", "lda #>Irq", "sta Vec\n",
                "sta Jump\n", "jmp (Jump)", "jmp (Vec)", "jsr PrintStr", "JumpTab .word L",
                "Lows    .byt <L", ".byt >L", "-1\n", "Texts   .word L", '.asc "HELLO"',
                '#include "tout_gfx.s"', "; saut par RTS ; les adresses sont diminuées de 1\n"
                "; (deuxième ligne)\nL"]
    absents = [a for a in attendus if a not in src]
    absents += [a for a in ("Gfx     .byt $40,$40,$55,$6A,$40,$41,$7F,$40,$55,$6A,$55,$6A,$40,"
                            "$40,$55,$6A",) if a not in g]
    dit(rc == 0 and "fichier identique" in sortie and not absents and "attention" not in sortie,
        "tous les mots-clés, zone data dans un fichier à part",
        sortie + "".join("  absent du source : %s\n" % a for a in absents))
    open(os.path.join(d, "tout1.s"), "w", encoding="utf-8").write(inserer(src))
    dit(xa(d, "tout1.s", "t1.bin") == ref1, "ce source décalé d'un octet : égal à l'original décalé")

    # bloc d'un .TAP (le deuxième), adresse lue dans l'en-tête
    tap = (mktap.entete("A", 0x80, 0, 0x9000, 0x9002) + b"\xEA\xEA\x60"
           + mktap.entete("P", 0x80, 0, 0x6000, 0x6000 + len(ref) - 1) + ref)
    open(os.path.join(d, "Mon jeu (1984).tap"), "wb").write(tap)
    rc, sortie = dis65(d, "Mon jeu (1984).tap", "2")
    dit(rc == 0 and "fichier identique" in sortie and "$6000-$%04X" % t["fin"] in sortie
        and os.path.exists(os.path.join(d, "mon_jeu_19842.dis")),
        "bloc 2 d'un .TAP, description écrite", sortie)

    # erreurs de description
    for texte, message in (
            ("file p.bin 6000\nentri 6000\n", "ligne 2 : mot-clé inconnu"),
            ("entry 6000\n", "pas de ligne"),
            ("file p.bin 6000\ndata 6010-6020\ntext 6020-6030\n", "déjà dans une autre zone"),
            ("file p.bin 6000\nname 6000 A1\nname 6003 A1\n", "nom donné deux fois"),
            ("file p.bin 6000\nname 6000 lda\n", "nom refusé"),
            ("file p.bin 6000\ntable 7000 2\n", "hors du fichier"),
            ("file p.bin 6000\nentry 9000\n", "hors du fichier"),
            ("file absent.bin 6000\n", "fichier absent")):
        open(os.path.join(d, "err.dis"), "w").write(texte)
        rc, sortie = dis65(d, "err.dis")
        dit(rc != 0 and message in sortie, "erreur signalée : " + message, sortie)
    # une déclaration fausse est signalée, le source reste identique
    open(os.path.join(d, "avis.dis"), "w").write(
        "file p.bin 6000\nlo 6002 6100\ndata %04X-%04X\nname 6001 Milieu\n"
        % (lab["go"], lab["go"] + 2))
    rc, sortie = dis65(d, "avis.dis")
    dit(rc == 0 and sortie.count("attention") >= 3 and "fichier identique" in sortie,
        "déclarations fausses signalées, source toujours identique", sortie)

    # texte derrière un JSR, pointeur chargé avant un JMP, nom jamais utilisé
    open(os.path.join(d, "q.s"), "w").write("""        *= $7000
        jsr print
        .byt $3C,$41,$00
        lda #<msg
        ldy #>msg
        jmp print
print   rts
msg     .asc "OK",0
""")
    xa(d, "q.s", "q.bin")
    open(os.path.join(d, "q.dis"), "w").write(
        "file q.bin 7000\ntext 7003-7005\nentry 7000\nentry 7006\ntext 700E-7010\n"
        "name 9E18 Jamais\n")
    rc, sortie = dis65(d, "q.dis")
    dit(rc == 0 and "fichier identique" in sortie
        and "entre dans une zone déclarée en $7003" in sortie and "non documenté" not in sortie
        and "name 9E18 Jamais : hors du fichier et jamais utilisé" in sortie
        and "lo 7006 700E" in sortie and "avant JMP" in sortie,
        "texte derrière un JSR, pointeur avant un JMP vers une zone text, nom jamais utilisé",
        sortie)


def main():
    if not os.path.isfile(XA):
        sys.exit("tools/xa absent : ./tools/build_xa.sh d'abord")
    tmp = tempfile.mkdtemp()
    try:
        entiers(tmp)
        fabrique(tmp)
    finally:
        shutil.rmtree(tmp)
    print("DIS65 : %s" % ("tout est bon" if not ko else "%d FAUX" % ko))
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
