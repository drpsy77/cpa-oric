#!/usr/bin/env python3
"""Carte du système résident ($C000-$FFFF, version disquette) : docs/carte-memoire.html.

Assemble une copie de src/ où une étiquette marque le début de chaque fichier
inclus par cpa.s (et des parties de bios.s), avec les options de build.sh
(-DDISK -DCPLCMD -DSERIE, messages français) ; vérifie que le code obtenu est
octet pour octet celui de build/cpa_sys_all.bin, puis dessine la carte d'après
les étiquettes et les zones de hw.inc.
    python3 tools/carte_memoire.py [sortie.html]
"""
import html, os, re, shutil, subprocess, sys, tempfile

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XA = os.environ.get("XA") or (os.path.join(R, "tools", "xa")
                               if os.path.exists(os.path.join(R, "tools", "xa")) else "xa")
SORTIE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(R, "docs", "carte-memoire.html")

# couche de chaque fichier (docs/architecture.md § 1) et son rôle
MODULES = {
    "bios.s":     ("bios", "BIOS : démarrages, plantages, IRQ, clavier, console"),
    "bdos.s":     ("bdos", "BDOS : aiguillage des fonctions, console (1-12)"),
    "rline.s":    ("ccp", "lecture de ligne (BDOS 10) : édition, historique, complétion"),
    "ccp.s":      ("ccp", "CCP : prompt, table et commandes internes"),
    "menu.s":     ("menu", "menus déroulants (FUNCT), barre du prompt, voyants"),
    "gfx.s":      ("bdos", "graphisme du SPLIT (BDOS 115)"),
    "ccp_gfx.s":  ("ccp", "commandes de dessin du CCP"),
    "snd.s":      ("bdos", "son AY-3-8912 (BDOS 116)"),
    "serial.s":   ("bios", "pilote série, console à distance (BDOS 117, PUNCH, READER)"),
    "disk.s":     ("bios", "pilote de disquette (WD1793 / LOCI)"),
    "fs.s":       ("bdos", "fichiers CP/M 2.2 (BDOS 13-36)"),
    "ccp_disk.s": ("ccp", "commandes disque du CCP (DIR, lecteurs, .COM, CHAIN...)"),
    "put.s":      ("ccp", "PUT : partie résidente (la suite est dans la fenêtre)"),
    "bank.s":     ("ccp", "chargeur des banques de la fenêtre (CPA.BNK)"),
    "script.s":   ("ccp", "scripts .BAT (DO, $1-$9, AUTO.BAT)"),
    "tables.s":   ("data", "tables du graphisme (g_xcol, g_xbit)"),
    "font.s":     ("data", "police, 5 octets par caractère (dépliée par font_init)"),
}
BIOS_PARTIES = [  # (début du commentaire dans bios.s, nom)
    ("; Démarrage à froid", "démarrage à froid"),
    ("; Démarrage à chaud", "démarrage à chaud"),
    ("; Stubs recopiés en $0200", "page 2, plantages, NMI, IRQ"),
    ("; Clavier", "clavier"),
    ("; Console", "console"),
    ("; Utilitaires d'affichage", "affichage de textes"),
]
COUCHES = {
    "bios": ("BIOS", "#3b6fd4"), "bdos": ("BDOS", "#2e9b6b"), "ccp": ("CCP", "#d08a1e"),
    "menu": ("Menus", "#b54fb5"), "data": ("Tables, police", "#7a8796"),
    "work": ("Zones de travail", "#c9b458"), "win": ("Fenêtre", "#d8604a"),
    "var": ("Variables, tampons", "#4aa3b5"), "free": ("Libre", "transparent"),
    "vec": ("Vecteurs", "#444"),
}


def assembler():
    t = tempfile.mkdtemp()
    src = os.path.join(t, "src")
    shutil.copytree(os.path.join(R, "src"), src)
    n = [0]

    def rep(m):
        n[0] += 1
        return "zz_%02d_%s\n%s" % (n[0], re.sub(r"\W", "_", m.group(1)), m.group(0))
    p = os.path.join(src, "cpa.s")
    s = open(p).read()
    open(p, "w").write(re.sub(r'^#include "([^"]+)"', rep, s, flags=re.M))
    p = os.path.join(src, "bios.s")
    lignes = open(p).read().split("\n")
    out = []
    for l in lignes:
        for i, (deb, _) in enumerate(BIOS_PARTIES):
            if l.startswith(deb):
                out.append("zb_%d" % i)
        out.append(l)
    open(p, "w").write("\n".join(out))
    b, sym = os.path.join(t, "m.bin"), os.path.join(t, "m.sym")
    subprocess.run([XA, "-I", "msg/fr", "-DDISK", "-DCPLCMD", "-DSERIE", "-o", b, "-l", sym,
                    "-e", os.path.join(t, "m.err"), "cpa.s"], cwd=src, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ref = os.path.join(R, "build", "cpa_sys_all.bin")
    if os.path.exists(ref) and open(ref, "rb").read() != open(b, "rb").read():
        raise SystemExit("carte_memoire : le code diffère de build/cpa_sys_all.bin (./build.sh ?)")
    et = {}
    for l in open(sym):
        a = l.split()
        if len(a) >= 2:
            et.setdefault(a[1], int(a[0], 16))
    shutil.rmtree(t)
    return et


def zones(et):
    z = [(0xC000, 0xC030, "bios", "table du BIOS", "16 entrées de 3 octets (BOOT... MENUBAR)")]
    mods = sorted((v, k) for k, v in et.items() if k.startswith("zz_") and v >= 0xC000
                  and v < et["rom_end"])
    for i, (a, k) in enumerate(mods):
        f = re.sub(r"^zz_\d+_", "", k)
        f = f[:-2] + ".s" if f.endswith("_s") else f
        fin = mods[i + 1][0] if i + 1 < len(mods) else et["rom_end"]
        couche, role = MODULES.get(f, ("data", f))
        if f == "bios.s":
            parts = sorted(et["zb_%d" % j] for j in range(len(BIOS_PARTIES)))
            for j, (d, (_, nom)) in enumerate(zip(parts, BIOS_PARTIES)):
                e = parts[j + 1] if j + 1 < len(parts) else fin
                z.append((d, e, "bios", "bios.s : " + nom, ""))
            continue
        z.append((a, fin, couche, f, role))
    E = et
    z += [
        (E["rom_end"], E["ALV"], "free", "marge du code", "jusqu'à SYS_END"),
        (E["ALV"], E["ALV"] + 168, "work", "ALV", "cartes d'allocation des 4 lecteurs (4 × 42)"),
        (E["ALV"] + 168, E["ORIGBUF"], "free", "libre", ""),
        (E["ORIGBUF"], E["ORIGBUF"] + 80, "work", "ORIGBUF", "ligne de commande avant les majuscules"),
        (E["scr_fcb"], E["scr_fcb"] + 36, "work", "scr_fcb", "FCB du script DO"),
        (E["scr_buf"], E["scr_buf"] + 128, "work", "scr_buf", "enregistrement du script"),
        (E["scr_par"], E["scr_par"] + 80, "work", "scr_par", "paramètres $1-$9 du script"),
        (E["scr_par"] + 80, E["WIN"], "free", "libre", ""),
        (E["WIN"], E["win_put_end"], "win", "fenêtre : banque PUT",
         "chargée avec le système ; ou IMG (GSAVE, GLOAD, SAVE), lue dans CPA.BNK, jusqu'à %04X"
         % E["img_bank_end"]),
        (E["win_put_end"], E["PUTBUF"], "free", "marge de PUT", ""),
        (E["PUTBUF"], E["PUTBUF"] + 768, "win", "tampon de PUT",
         "768 octets ; au démarrage à froid, le code de ce démarrage (%04X-%04X) ; "
         "chargeur des banques en $FC80" % (E["PUTBUF"], E["cold_end"] - 1)),
        (0xFD00, 0xFD04, "var", "variables du FS", "bloc, blocs libres"),
        (0xFD04, 0xFD13, "var", "banques", "bk_..."),
        (0xFD13, 0xFD22, "var", "pilote série", "sr_..."),
        (0xFD22, 0xFD58, "free", "libre", "variables du BDOS libres"),
        (0xFD58, 0xFD80, "var", "disque et FS", "dsk_..., fs_..., lecteurs"),
        (0xFD80, 0xFDA4, "var", "CCP_FCB", "FCB du CCP"),
        (0xFDA4, 0xFDB0, "var", "pistes, complétion", "dsk_trk, cp_..., vecteurs de lecteurs"),
        (0xFDB0, 0xFDD4, "var", "CCP_FCB2", "FCB des banques et de GSAVE"),
        (0xFDD4, 0xFDF8, "var", "put_fcb", "FCB de PUT"),
        (0xFDF8, 0xFDF9, "var", "win_id", "contenu de la fenêtre"),
        (0xFDF9, 0xFE00, "free", "libre", ""),
        (0xFE00, 0xFF00, "var", "SECBUF", "tampon de secteur"),
    ]
    ff = sorted((v, k) for k, v in et.items() if k.startswith("zz_") and v >= 0xFF00)
    noms = {"tables_ff_s": ("line_lo, line_hi, carte du clavier", "data"),
            "rl_keys_s": ("touches de l'édition de ligne (rl_keys, rl_vecs)", "data"),
            "menu_col_s": ("encres des menus (m_colors)", "menu")}
    for i, (a, k) in enumerate(ff):
        f = re.sub(r"^zz_\d+_", "", k)
        fin = ff[i + 1][0] if i + 1 < len(ff) else E["ff_end"]
        role, c = noms.get(f, (f, "data"))
        z.append((a, fin, c, f[:-2] + ".s", role))
    z += [(E["ff_end"], 0xFFFA, "free", "libre", "page $FF00"),
          (0xFFFA, 0x10000, "vec", "vecteurs du 6502", "NMI, RESET, IRQ")]
    z.sort()
    for (a, b, *_), (c, *_) in zip(z, z[1:]):
        assert b == c, "trou ou chevauchement en %04X / %04X" % (b, c)
    return z


def page(z, et):
    esc = html.escape
    def barre(lo, hi, haut, classe):
        out = []
        for a, b, c, nom, role in z:
            a2, b2 = max(a, lo), min(b, hi)
            if a2 >= b2:
                continue
            h = (b2 - a2) * haut / (hi - lo)
            t = "%s  $%04X-$%04X  %d octets" % (nom, a, b - 1, b - a)
            lab = esc(nom.replace("bios.s : ", "")) if h >= 13 else ""
            out.append('<div class="z c-%s" style="height:%.2fpx" title="%s"><span>%s</span>'
                       '<em>%s</em></div>' % (c, h, esc(t), lab, "$%04X" % a if h >= 13 else ""))
        return '<div class="barre %s">%s</div>' % (classe, "".join(out))

    tot = {}
    for a, b, c, *_ in z:
        tot[c] = tot.get(c, 0) + b - a
    leg = "".join('<span class="lg"><i class="c-%s"></i>%s <b>%s</b></span>'
                  % (c, esc(COUCHES[c][0]), "{:,}".format(tot.get(c, 0)).replace(",", " "))
                  for c in COUCHES if tot.get(c))
    rangs = "".join(
        '<tr><td class="ad">$%04X-$%04X</td><td class="nb">%s</td><td><i class="c-%s"></i>%s</td>'
        '<td>%s</td></tr>' % (a, b - 1, "{:,}".format(b - a).replace(",", " "), c, esc(nom),
                              esc(role))
        for a, b, c, nom, role in z)
    css_c = "".join(".c-%s{background:%s}" % (k, v[1]) for k, v in COUCHES.items())
    return """<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Carte du système</title>
<style>
:root{--fond:#f7f6f2;--texte:#1d1f23;--doux:#6b7079;--trait:#d9d6cc;--carte:#fff}
@media (prefers-color-scheme:dark){:root{--fond:#16181c;--texte:#e8e6e1;--doux:#9aa0aa;--trait:#30343b;--carte:#1e2126}}
*{box-sizing:border-box}
body{margin:0;background:var(--fond);color:var(--texte);font:15px/1.45 system-ui,-apple-system,sans-serif}
main{max-width:1060px;margin:0 auto;padding:24px 16px 48px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:16px;margin:28px 0 10px}
p.s{color:var(--doux);margin:0 0 18px}
.lgs{display:flex;flex-wrap:wrap;gap:6px 16px;margin:0 0 18px;font-size:13px}
.lg i,td i{display:inline-block;width:11px;height:11px;border-radius:2px;margin-right:6px;vertical-align:-1px;border:1px solid var(--trait)}
.lg b{font-weight:600;font-variant-numeric:tabular-nums}
.cartes{display:flex;gap:28px;flex-wrap:wrap;align-items:flex-start}
.col h3{font-size:13px;margin:0 0 6px;color:var(--doux);font-weight:600}
.barre{width:300px;border:1px solid var(--trait);border-radius:6px;overflow:hidden;background:var(--carte)}
.z{position:relative;border-bottom:1px solid rgba(0,0,0,.18);color:#fff;font-size:11.5px;overflow:hidden}
.z span{position:absolute;left:8px;top:50%%;transform:translateY(-50%%);white-space:nowrap;text-shadow:0 1px 1px rgba(0,0,0,.35)}
.z em{position:absolute;right:6px;top:1px;font:10.5px ui-monospace,Menlo,monospace;font-style:normal;opacity:.85}
.z.c-free{background:repeating-linear-gradient(45deg,transparent 0 5px,rgba(127,127,127,.18) 5px 10px);color:var(--doux)}
.z.c-free span{text-shadow:none}.z.c-work,.z.c-var{color:#10181c}
.z.c-work span,.z.c-var span{text-shadow:none}
%s
table{width:100%%;border-collapse:collapse;font-size:13.5px;background:var(--carte);border:1px solid var(--trait);border-radius:6px}
td,th{padding:5px 9px;border-bottom:1px solid var(--trait);text-align:left;vertical-align:top}
th{font-size:12px;color:var(--doux);font-weight:600}
td.ad{font:12.5px ui-monospace,Menlo,monospace;white-space:nowrap}
td.nb{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.tw{overflow-x:auto}
@media (max-width:700px){.barre{width:calc(100vw - 32px)}}
</style></head><body><main>
<h1>Carte du système résident ($C000-$FFFF)</h1>
<p class="s">Version disquette, système français, options de <code>build.sh</code> (CPLCMD, SERIE).
RAM overlay chargée depuis la disquette. Fait par <code>tools/carte_memoire.py</code> d'après
les étiquettes de l'assemblage ; survoler une zone pour ses adresses.</p>
<div class="lgs">%s</div>
<div class="cartes">
<div class="col"><h3>Les 16 Ko, à l'échelle</h3>%s</div>
<div class="col"><h3>Zoom : $F500-$FFFF (travail, fenêtre, variables)</h3>%s</div>
</div>
<h2>Détail</h2>
<div class="tw"><table><tr><th>Adresses</th><th>Octets</th><th>Zone</th><th>Rôle</th></tr>%s</table></div>
</main></body></html>
""" % (css_c, leg, barre(0xC000, 0x10000, 1400, ""), barre(0xF500, 0x10000, 1400, "zoom"), rangs)


et = assembler()
z = zones(et)
open(SORTIE, "w").write(page(z, et))
print("Carte : %s (%d zones ; code jusqu'à %04X, marge %d)"
      % (os.path.relpath(SORTIE, R), len(z), et["rom_end"], et["ALV"] - et["rom_end"]))
