; =====================================================================
;  GRXPACK.COM — compacte un programme de GRAPHER (.GRX)
;
;  GRXPACK SOURCE DEST    écrit DEST.GRX, le programme de SOURCE.GRX sans
;                         ce qui ne sert pas à l'exécuter
;  GRXPACK SOURCE /L n    montre la ligne de SOURCE.GRX qui a donné la
;                         ligne n du programme compact (le numéro que
;                         donne une erreur de GRAPHER ou de GRXASM)
;
;  Retiré, et rien d'autre :
;   - les commentaires, les lignes vides ou faites d'un commentaire, le
;     retrait ;
;   - les espaces de fin de ligne et ceux qui en suivent un autre ;
;   - dans un calcul où GRAPHER les ignore (toute la ligne pour une
;     affectation, LET, IF, WHILE, PRINT et PRINTV ; ailleurs entre
;     parenthèses), les espaces qui touchent un opérateur, une parenthèse
;     du côté intérieur ou une virgule, sauf contre un guillemet.
;  Gardé tel quel : le texte entre guillemets, celui d'ECHO, ECHOV et
;  GTEXT (un « ; » y est du texte), le « ; » final de PRINT, la casse,
;  les fins de ligne (CR, LF ou CR LF, comme dans la source). Une
;  tabulation devient un espace, comme au chargement par GRAPHER ; le
;  texte s'arrête au premier ^Z (ou au premier octet 0).
;
;  La source est lue et le résultat écrit par enregistrements (pas de
;  limite de mémoire), dans DEST.$$$, renommé à la fin (rien n'est perdu
;  si le disque est plein). Même travail que tools/grxpack.py, auquel
;  tools/test_grxpack.py le compare.
; =====================================================================

#include "cpa.inc"

ip      = $10           ; position dans l'enregistrement lu (128 : à lire)
op      = $11           ; position dans l'enregistrement à écrire
eof     = $12           ; 1 : fin de la source
pbf     = $13           ; 1 : un caractère rendu à la lecture (pbc)
pbc     = $14
mode    = $15           ; 1 : /L n
llen    = $16           ; longueur de la ligne lue
olen    = $17           ; longueur de la ligne compacte
eolk    = $18           ; fin de la ligne lue : bit 0 CR, bit 1 LF
cls     = $19           ; classe du premier mot (K_xxx)
calc    = $1A           ; 1 : toute la ligne est un calcul
force   = $1B           ; 1 : un espace gardé après le premier mot
prem    = $1C           ; 1 : rien encore après le premier mot
niv     = $1D           ; niveau de parenthèses
guil    = $1E           ; 1 : entre guillemets
c2      = $1F           ; caractère qui suit des espaces
sx      = $20           ; X gardé
tmp     = $21
nsrc    = $22           ; lignes lues (mot)
nout    = $24           ; lignes gardées (mot)
nin     = $26           ; octets lus (mot)
nby     = $28           ; octets écrits (mot)
want    = $2A           ; /L : ligne demandée (mot)
num     = $2C           ; nombre à afficher (mot)
p1      = $2E           ; pointeur de travail
tp      = $30           ; pointeur de travail
ZEND    = $32

K_TXT   = 1             ; ECHO, ECHOV : le texte de la ligne
K_RAW   = 2             ; GTEXT : le reste de la ligne
K_PRT   = 3             ; PRINT, PRINTV : calculs, « ; » final
K_CAL   = 4             ; IF, WHILE, LET : un calcul jusqu'à la fin
LMAX    = 255           ; ligne la plus longue (GRAPHER : 126)

        *= $0500
start
.(
        ldx #0                  ; zone de travail à 0
        txa
z       sta ip,x
        inx
        cpx #ZEND-ip
        bne z
        lda #128
        sta ip
        lda FCB1+1
        cmp #" "+1
        bcc use
        cmp #"/"
        beq use
        ldx #<sfcb              ; source : FCB1, .GRX par défaut
        ldy #>sfcb
        lda #<FCB1
        jsr setfcb
        jsr options
        lda mode
        bne open
        lda FCB2+1              ; destination : FCB2, obligatoire
        cmp #" "+1
        bcc use
        cmp #"/"
        beq use
        ldx #<dfcb
        ldy #>dfcb
        lda #<FCB2
        jsr setfcb
        ldx #11                 ; DEST = SOURCE : refusé
s       lda sfcb,x
        cmp dfcb,x
        bne open
        dex
        bpl s
        lda #<m_same
        ldy #>m_same
        jmp pstop
use     jmp usage
open    lda #<sfcb
        ldy #>sfcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_nf
        ldy #>m_nf
        jmp pstop
ok      lda mode
        bne loop
        jsr make
loop    jsr rdline              ; une ligne de la source
        bcs fin
        inc nsrc
        bne l1
        inc nsrc+1
l1      jsr pack
        bcs loop                ; elle disparaît
        inc nout
        bne l2
        inc nout+1
l2      lda mode
        beq wr
        lda nout                ; /L : est-ce la ligne demandée ?
        cmp want
        bne loop
        lda nout+1
        cmp want+1
        bne loop
        jmp found
wr      ldx #0                  ; la ligne compacte, puis sa fin de ligne
w       cpx olen
        beq we
        stx sx
        lda out,x
        jsr putc
        ldx sx
        inx
        bne w
we      lda eolk
        and #1
        beq w2
        lda #13
        jsr putc
w2      lda eolk
        and #2
        beq loop
        lda #10
        jsr putc
        jmp loop
fin     lda mode
        beq f1
        lda #<m_nol             ; /L : le programme compact est plus court
        ldy #>m_nol
        jmp pstop
f1      jsr save
        jmp report
.)

; options : « /L n » dans la ligne de paramètres -> mode 1, want
options
.(
        ldx #0
o1      cpx TAIL
        bcs r
        lda TAIL+1,x
        inx
        cmp #"/"
        bne o1
        lda TAIL+1,x
        and #$DF
        cmp #"L"
        bne o1
        inx
        inc mode
sp      cpx TAIL
        bcs bad
        lda TAIL+1,x
        cmp #" "
        bne dig
        inx
        bne sp
dig     cpx TAIL
        bcs end
        lda TAIL+1,x
        sec
        sbc #"0"
        cmp #10
        bcs end
        pha                     ; want = want * 10 + chiffre
        lda want
        sta num
        lda want+1
        sta num+1
        asl want
        rol want+1
        asl want
        rol want+1
        clc
        lda want
        adc num
        sta want
        lda want+1
        adc num+1
        sta want+1
        asl want
        rol want+1
        pla
        clc
        adc want
        sta want
        bcc d1
        inc want+1
d1      inx
        bne dig
end     lda want
        ora want+1
        bne r
bad     jmp usage
r       rts
.)

; setfcb : FCB de la ligne de commande (A = poids faible, page de FCB1)
;   -> FCB X/Y, mis à 0 ; type .GRX s'il manque ; lecteur courant
;   écrit en clair (DEST = SOURCE se compare)
setfcb
.(
        sta p1
        lda #>FCB1
        sta p1+1
        stx tp
        sty tp+1
        ldy #35
        lda #0
z       sta (tp),y
        dey
        bpl z
        ldy #11
c       lda (p1),y
        sta (tp),y
        dey
        bpl c
        ldy #9
        lda (tp),y
        cmp #" "
        bne d
        ldx #0
t       lda t_grx,x
        sta (tp),y
        iny
        inx
        cpx #3
        bne t
d       ldy #0
        lda (tp),y
        bne r
        ldx #F_CURDSK
        jsr BDOS
        clc
        adc #1
        ldy #0
        sta (tp),y
r       rts
.)

; getc : caractère suivant de la source -> A, C=0 ; C=1 en fin de texte
;   (fin du fichier, ^Z ou 0)
getc
.(
        lda pbf
        beq g1
        lda #0
        sta pbf
        lda pbc
        clc
        rts
g1      lda eof
        bne ge
        ldx ip
        cpx #128
        bcc g2
        lda #<ibuf
        ldy #>ibuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<sfcb
        ldy #>sfcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne se
        ldx #0
g2      lda ibuf,x
        beq se
        cmp #$1A
        beq se
        inx
        stx ip
        inc nin
        bne g3
        inc nin+1
g3      clc
        rts
se      lda #1
        sta eof
ge      sec
        rts
.)

; rdline : ligne suivante -> lin (terminée par 0), llen, eolk ; C=1 s'il
;   n'y en a plus. Une tabulation devient un espace.
rdline
.(
        lda #0
        sta llen
        sta eolk
        jsr getc
        bcc l0
        rts                     ; (C=1)
l       jsr getc
        bcs end
l0      cmp #13
        beq cr
        cmp #10
        beq lf
        cmp #9
        bne l1
        lda #" "
l1      ldx llen
        cpx #LMAX
        bcs long
        sta lin,x
        inc llen
        bne l
cr      lda #1
        sta eolk
        jsr getc
        bcs end
        cmp #10
        beq lf
        sta pbc                 ; autre chose : rendu
        inc pbf
        bne end
lf      lda eolk
        ora #2
        sta eolk
end     ldx llen
        lda #0
        sta lin,x
        clc
        rts
long    lda #<m_long            ; ligne trop longue : numéro, rien d'écrit
        ldy #>m_long
        jsr pstr
        inc nsrc
        bne lg
        inc nsrc+1
lg      ldx #nsrc
        jsr pzn
        jsr crlf
        lda mode
        bne lq
        jsr abandon
lq      jmp WBOOT
.)

; pack : lin -> out, olen ; C=1 si la ligne disparaît
pack
.(
        ldx #0
sp      lda lin,x
        cmp #" "
        bne s1
        inx
        bne sp
s1      cmp #0
        beq drop
        cmp #";"
        bne s2
drop    sec
        rts
s2      ldy #0                  ; premier mot : lettres
w       lda lin,x
        jsr isalpha
        bcs wend
        cpy #8
        bcs w1
        sta kw,y
w1      lda lin,x
        sta out,y
        iny
        inx
        bne w
wend    sty tmp                 ; tmp = longueur du mot
        lda #0
        sta cls
        sta calc
        sta force
        sta niv
        sta guil
        cpy #9
        bcs other               ; (aucune commande de plus de 8 lettres)
        sta kw,y
        stx sx
        jsr lookup              ; -> cls
        ldx sx
        ldy tmp
        lda cls
        beq var
        cmp #K_PRT
        bcs cal
        jmp text
cal     inc force
        inc calc
        bne other
var     cpy #1                  ; une ou deux lettres : une affectation
        bcc other
        cpy #3
        bcs other
        inc calc
other   lda #1
        sta prem
g       lda lin,x
        bne g0
        jmp gend
g0      ldy tmp                 ; (Y = position dans out, gardée dans tmp)
        lda guil
        beq g1
        lda lin,x               ; entre guillemets : tel quel
        sta out,y
        inc tmp
        inx
        cmp #34
        bne g
        lda #0
        sta guil
        beq g
g1      lda lin,x
        cmp #";"
        bne g2
        lda cls
        cmp #K_PRT
        beq gp
gcom    jmp gend                ; un commentaire
gp      inx                     ; PRINT : « ; » final (seul, ou suivi
        lda lin,x               ;   d'un autre) ?
        cmp #" "
        beq gp
        cmp #0
        beq semi
        cmp #";"
        bne gcom
semi    lda #";"
        sta out,y
        iny
        sty olen
        clc
        rts
g2      cmp #" "
        bne g5
gs      inx                     ; des espaces
        lda lin,x
        cmp #" "
        beq gs
        cmp #0
        beq gcom
        sta c2
        lda calc                ; hors d'un calcul : un seul reste
        ora niv
        beq keep
        lda force               ; juste après IF, WHILE, LET, PRINT : aussi
        and prem
        bne keep
        lda out-1,y             ; après un opérateur, « ( » ou « , » :
        jsr in_av               ;   inutile, sauf devant un guillemet
        bcs t2
        lda c2
        cmp #34
        beq keep
        bne skip
t2      lda out-1,y             ; avant un opérateur, « ) » ou « , » :
        cmp #34                 ;   inutile, sauf après un guillemet
        beq keep
        lda c2
        jsr in_ap
        bcc skip
keep    lda #" "
        sta out,y
        inc tmp
skip    lda #0
        sta prem
        jmp g
g5      pha
        lda #0
        sta prem
        pla
        cmp #34
        bne g6
        inc guil
        bne put
g6      cmp #"("
        bne g7
        inc niv
        bne put
g7      cmp #")"
        bne put
        lda niv
        beq g8
        dec niv
g8      lda #")"
put     sta out,y
        inc tmp
        inx
        jmp g
gend    ldy tmp                 ; espaces de fin retirés (pas entre
        lda guil                ;   guillemets)
        bne gd
tr      cpy #0
        beq gd
        lda out-1,y
        cmp #" "
        bne gd
        dey
        jmp tr
gd      sty olen
        clc
        rts

; ECHO, ECHOV, GTEXT : le reste de la ligne est du texte
text    stx sx
k       lda lin,x
        cmp #" "
        bne k1
        inx
        bne k
k1      cmp #0
        beq done                ; le mot seul
        cpx sx
        beq k2
        lda #" "
        sta out,y
        iny
k2      lda cls
        cmp #K_RAW
        beq all
        lda lin,x
        cmp #34
        bne all
        sta out,y               ; entre guillemets : jusqu'au guillemet
        iny                     ;   final, la suite est ignorée
        inx
q       lda lin,x
        beq done
        sta out,y
        iny
        inx
        cmp #34
        bne q
        beq done
all     lda lin,x
        beq done
        sta out,y
        iny
        inx
        bne all
done    sty olen
        clc
        rts
.)

; in_av, in_ap : C=0 si A est un opérateur, une virgule, ou « ( »
;   (in_av), « ) » (in_ap) ; X gardé
in_av   cmp #"("
        beq in_y
        bne in_op
in_ap   cmp #")"
        beq in_y
in_op
.(
        stx sx
        ldx #NOPS-1
l       cmp ops,x
        beq y
        dex
        bpl l
        ldx sx
        sec
        rts
y       ldx sx
.)
in_y    clc
        rts
ops     .asc "+-*/%=<>&|,"
NOPS    = *-ops

; isalpha : C=0 si A est une lettre (A est mis en majuscule)
isalpha
.(
        cmp #"a"
        bcc up
        cmp #"z"+1
        bcs up
        and #$DF
up      cmp #"A"
        bcc no
        cmp #"Z"+1
        bcs no
        clc
        rts
no      sec
        rts
.)

; lookup : kw (terminé par 0) dans ktab -> cls (0 : autre mot)
lookup
.(
        ldx #0
e       ldy #0
        lda ktab,x
        beq r                   ; fin de la table
c       lda ktab,x
        beq z
        cmp kw,y
        bne skip
        inx
        iny
        bne c
z       lda kw,y                ; le mot doit finir là
        bne skip
        lda ktab+1,x
        sta cls
r       rts
skip    lda ktab,x              ; entrée suivante
        beq s1
        inx
        bne skip
s1      inx
        inx
        bne e
.)
ktab    .asc "ECHO",0
        .byt K_TXT
        .asc "ECHOV",0
        .byt K_TXT
        .asc "GTEXT",0
        .byt K_RAW
        .asc "PRINT",0
        .byt K_PRT
        .asc "PRINTV",0
        .byt K_PRT
        .asc "IF",0
        .byt K_CAL
        .asc "WHILE",0
        .byt K_CAL
        .asc "LET",0
        .byt K_CAL
        .byt 0

; make : DEST.$$$ créé (un ancien est effacé)
make
.(
        ldx #35                 ; (dfcb : des 0 après le nom)
c       lda dfcb,x
        sta tfcb,x
        dex
        bpl c
        lda #"$"
        sta tfcb+9
        sta tfcb+10
        sta tfcb+11
        lda #<tfcb
        ldy #>tfcb
        ldx #F_DELETE
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne r
        lda #<m_dir
        ldy #>m_dir
        jmp pstop
r       rts
.)

; putc : A dans le fichier écrit
putc
.(
        ldx op
        sta obuf,x
        inx
        stx op
        inc nby
        bne p
        inc nby+1
p       cpx #128
        bcc r
        jsr wrrec
r       rts
.)

; wrrec : l'enregistrement obuf est écrit ; disque plein : rien ne reste
wrrec
.(
        lda #<obuf
        ldy #>obuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        bne full
        sta op
        rts
full    jsr abandon
        lda #<m_full
        ldy #>m_full
        jmp pstop
.)

; abandon : DEST.$$$ fermé et effacé
abandon
        lda #<tfcb
        ldy #>tfcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_DELETE
        jmp BDOS

; save : fin du fichier (^Z jusqu'au bout de l'enregistrement), puis
;   DEST.$$$ renommé DEST (l'ancien DEST est effacé)
save
.(
        ldx op
        beq cl
        lda #$1A
z       sta obuf,x
        inx
        cpx #128
        bne z
        jsr wrrec
cl      lda #<tfcb
        ldy #>tfcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<dfcb
        ldy #>dfcb
        ldx #F_DELETE
        jsr BDOS
        ldx #35
        lda #0
c       sta rfcb,x
        dex
        bpl c
        ldx #11
r1      lda tfcb,x
        sta rfcb,x
        lda dfcb,x
        sta rfcb+16,x
        dex
        bpl r1
        lda #<rfcb
        ldy #>rfcb
        ldx #F_RENAME
        jsr BDOS
        cmp #$FF
        bne r
        lda #<m_ro              ; DEST protégé : le résultat reste dans
        ldy #>m_ro              ;   DEST.$$$
        jmp pstop
r       rts
.)

; report : lignes et octets lus, puis écrits
report
.(
        lda #<m_in
        ldy #>m_in
        jsr pstr
        ldx #nsrc
        ldy #nin
        jsr pair
        lda #<m_out
        ldy #>m_out
        jsr pstr
        ldx #nout
        ldy #nby
        jsr pair
        jmp WBOOT
; pair : « n lignes, m octets » (mots de la page zéro en X et Y)
pair    tya
        pha
        jsr pzn
        lda #<m_lines
        ldy #>m_lines
        jsr pstr
        pla
        tax
        jsr pzn
        lda #<m_bytes
        ldy #>m_bytes
        jmp pstr
.)

; pzn : mot de la page zéro (X) en décimal
pzn     lda 0,x
        sta num
        lda 1,x
        sta num+1
        jmp pnum

; found : /L, la ligne de la source est en lin
found
.(
        lda #<m_l1
        ldy #>m_l1
        jsr pstr
        ldx #nout
        jsr pzn
        lda #<m_l2
        ldy #>m_l2
        jsr pstr
        ldx #nsrc
        jsr pzn
        lda #<m_l3
        ldy #>m_l3
        jsr pstr
        lda #<lin
        ldy #>lin
        jsr pstr
        jsr crlf
        jmp WBOOT
.)

crlf    lda #13
        jsr pchar
        lda #10
        jmp pchar

usage   lda #<m_use
        ldy #>m_use
; pstop : message A/Y, puis fin
pstop   jsr pstr
        jmp WBOOT

; pstr : chaîne A/Y terminée par 0 (255 caractères au plus)
pstr
.(
        sta p1
        sty p1+1
        ldy #0
l       lda (p1),y
        beq r
        sty tmp
        jsr pchar
        ldy tmp
        iny
        bne l
r       rts
.)

pchar   ldx #F_CONOUT
        jmp BDOS

; pnum : num (mot) en décimal, sans zéros devant
pnum
.(
        lda #0
        sta tmp                 ; 1 : un chiffre déjà écrit
        ldx #0
d       ldy #"0"
s       lda num
        sec
        sbc dlo,x
        pha
        lda num+1
        sbc dhi,x
        bcc n
        sta num+1
        pla
        sta num
        iny
        bne s
n       pla
        cpy #"0"
        bne w
        lda tmp
        bne w
        cpx #4
        bne nx
w       lda #1
        sta tmp
        tya
        stx sx
        jsr pchar
        ldx sx
nx      inx
        cpx #5
        bne d
        rts
.)
dlo     .byt <10000,<1000,<100,<10,<1
dhi     .byt >10000,>1000,>100,>10,>1

t_grx   .asc "GRX"

#include "grxpack.msg"          ; messages (progs/msg/fr, en)

; zones de travail, après le programme (pas dans le fichier)
kw      = *             ; premier mot en majuscules (8 lettres et un 0)
sfcb    = kw+9          ; source
dfcb    = sfcb+36       ; destination
tfcb    = dfcb+36       ; DEST.$$$
rfcb    = tfcb+36       ; renommage
ibuf    = rfcb+36       ; enregistrement lu
obuf    = ibuf+128      ; enregistrement à écrire
lin     = obuf+128      ; ligne lue
out     = lin+256       ; ligne compacte
