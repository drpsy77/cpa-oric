; =====================================================================
;  UNTAP.COM — les blocs d'un fichier .TAP (cassette de l'Oric)
;
;  UNTAP NOM            liste les blocs (numéro, nom, BAS ou BIN,
;                       adresses, /R : démarrage automatique)
;  UNTAP NOM n          extrait le bloc n
;  UNTAP NOM *          extrait tous les blocs
;  /1                   BASIC de l'Oric-1 (ROM 1.0 : $82 INVERSE,
;                       $83 NORMAL, $F7 GO)
;    NOM     type .TAP par défaut, lecteur facultatif ; les fichiers
;            écrits vont sur le même lecteur
;  Bloc BASIC (type $00) -> NOM.BAS, en texte comme LIST : numéro,
;  espace, mots-clés en entier, CR LF. Caractères de contrôle, codes de
;  127 et plus, accolade, espace ou chiffre en tête de ligne, espace en
;  fin : notation « {hh} » (« {{ » pour l'accolade), que MKTAP décode.
;  Chaque ligne est recodée (crunch, bcr_inc.s, celui de MKTAP) et
;  comparée à l'originale : « ligne N : recodage different » si MKTAP ne
;  la redonnerait pas (minuscules hors texte, code inconnu, ligne vide).
;  Ce qui suit la fin du programme ($00 $00) dans le bloc, s'il y a plus
;  d'un octet -> NOM.BIN, à son adresse (affichée).
;  Bloc de code (autre type) -> NOM.BIN, octets tels quels.
;  Nom des fichiers : lettres et chiffres du nom du bloc, 8 au plus ;
;  vide ou déjà pris par un bloc précédent : nom du .TAP + numéro du bloc
;  (JEU2, AVENTU12). Un fichier qui existe est remplacé (comme COPY).
;  Lecture : au moins un $16, $24, en-tête de 9 octets, nom jusqu'au 0,
;  fin - début + 1 octets ; ce qui n'est pas un bloc est sauté. Format :
;  docs/oric-basic.md § 1 et § 5.1. Même résultat que tools/untap.py.
; =====================================================================

#include "cpa.inc"

T_DATA  = $91           ; mots-clés du BASIC (ROM 1.1)
T_REM   = $9D
T_PRINT = $BA
NKW     = 119           ; mots-clés de la table ($80-$F6)
MAXN    = 48            ; noms retenus (doublons)

sp      = $10           ; 2 octets : chaîne affichée
val     = $12           ; 2 octets : nombre
pa      = $14           ; 2 octets (crunch)
pb      = $16           ; 2 octets
po      = $18           ; 2 octets : destination de crunch
kp      = $1A           ; 2 octets : mot-clé (crunch, kword)
tok     = $1C           ; (crunch, kword)
sx      = $1D           ; (crunch, kword)
sy      = $1E           ; (crunch, sput)
dmode   = $1F           ; $80 : dans un DATA (crunch, detok)
slen    = $20           ; longueur de sbuf
ipos    = $21           ; position dans ibuf (128 : lire)
ieof    = $22           ; $80 : fin du .TAP
opos    = $23           ; position dans obuf
nblk    = $24           ; numéro du bloc en cours
want    = $25           ; 0 : liste ; $FF : tous ; sinon le bloc voulu
v10     = $26           ; $80 : /1 (ROM 1.0)
sp0     = $27           ; pile au départ
left    = $28           ; 2 octets : octets du bloc restant à lire
trunc   = $2A           ; $80 : bloc coupé par la fin du fichier
nnam    = $2B           ; noms retenus
llen    = $2C           ; longueur de lbuf
qmode   = $2D           ; $80 : dans une chaîne (detok)
rmode   = $2E           ; $80 : après REM (detok)
nok     = $2F           ; $80 : ligne que MKTAP ne redonnerait pas
num     = $30           ; 2 octets : numéro de la ligne
found   = $32           ; $80 : bloc voulu trouvé
dg      = $33           ; (ndec, getdec)
ox      = $34           ; X gardé par putb
tlen    = $35           ; longueur du nom du .TAP
hdr     = $36           ; 9 octets : en-tête du bloc ($36-$3E)
typ     = hdr+2
aut     = hdr+3
endh    = hdr+4
endl    = hdr+5
adrh    = hdr+6
adrl    = hdr+7
adr     = $3F           ; 2 octets : adresse affichée d'un .BIN
wcnt    = $41           ; 2 octets : octets du bloc déjà lus
fp      = $43           ; 2 octets : FCB (pname, pfull)
gx      = $45           ; X et Y gardés par getb
gy      = $46

        *= $0500
start
.(
        tsx
        stx sp0
        lda #0
        sta want
        sta v10
        sta nnam
        sta found
        ldx #1
        jsr skipsp
        lda TAIL,x
        bne s1
usage   lda #<m_use
        ldy #>m_use
        jmp fail
s1      lda #<ifcb
        sta fp
        lda #>ifcb
        sta fp+1
        jsr pname               ; le .TAP
        bcc s2
        lda #<m_name
        ldy #>m_name
        jmp fail
s2      lda ifcb+9              ; type .TAP par défaut
        cmp #" "
        bne opt
        lda #"T"
        sta ifcb+9
        lda #"A"
        sta ifcb+10
        lda #"P"
        sta ifcb+11
opt     jsr skipsp              ; options : n, *, /1
        lda TAIL,x
        beq go
        cmp #"*"
        bne o1
        lda #$FF
        sta want
        inx
        bne opt
o1      cmp #"/"
        bne o2
        lda TAIL+1,x
        cmp #"1"
        bne usage
        lda #$80
        sta v10
        inx
        inx
        bne opt
o2      jsr getdec              ; numéro du bloc, 1 à 255
        bcs usage
        lda val+1
        bne badn
        lda val
        beq badn
        sta want
        jmp opt
badn    lda #<m_bnum
        ldy #>m_bnum
        jmp fail
go      ldy #8                  ; nom du .TAP sans les espaces
t1      lda ifcb,y
        cmp #" "
        bne t2
        dey
        bne t1
t2      sty tlen
        lda ifcb                ; même lecteur pour les fichiers écrits
        sta ofcb
        lda #<ifcb
        ldy #>ifcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne o3
        lda #<ifcb
        ldy #>ifcb
        jsr pfull
        lda #<m_abs
        ldy #>m_abs
        jmp fail
o3      lda #128
        sta ipos
        lda #0
        sta ieof
        sta nblk
        jmp blocks
.)

fail    jsr puts
quit    ldx sp0
        txs
        rts

; ---------------------------------------------------------------------
; blocks : chaque bloc du .TAP, listé, extrait ou sauté
blocks
.(
next    jsr sync
        bcc b0
        jmp done
b0      inc nblk
        bne b1
        dec nblk                ; 255 blocs au plus
        jmp done
b1      ldx #0                  ; en-tête de 9 octets
h       jsr getb
        bcs eofh
        sta hdr,x
        inx
        cpx #9
        bne h
        ldx #0                  ; nom jusqu'au 0 (16 caractères gardés)
n       jsr getb
        bcs eofh
        cmp #0
        beq n2
        cpx #16
        bcs n
        sta bname,x
        inx
        bne n
eofh    dec nblk                ; en-tête coupé : pas un bloc
        jmp done
n2      sta bname,x
        sta trunc
        sta wcnt
        sta wcnt+1
        sec                     ; left = fin - début + 1 (0 si fin < début)
        lda endl
        sbc adrl
        sta left
        lda endh
        sbc adrh
        sta left+1
        bcs l1
        lda #0
        sta left
        sta left+1
        beq l2
l1      inc left
        bne l2
        inc left+1
l2      jsr mkname
        lda want
        bne x0
        jsr plist               ; liste
        jsr skip
        jsr pinc
        jmp next
x0      cmp #$FF
        beq x1
        cmp nblk
        beq x1
        jsr skip                ; pas celui-là
        jmp next
x1      lda #$80
        sta found
        lda typ
        bne code
        jsr xbas
        jmp x2
code    lda adrl
        sta adr
        lda adrh
        sta adr+1
        jsr xbin
x2      jsr pinc
        lda want
        cmp #$FF
        bne done
        jmp next
done    lda nblk
        bne d1
        lda #<m_none            ; rien qui ressemble à un bloc
        ldy #>m_none
        jmp fail
d1      lda want
        beq r
        bit found
        bmi r
        lda #<m_nob
        ldy #>m_nob
        jmp fail
r       rts
.)

; pinc : « bloc N incomplet » si la fin du fichier a coupé le bloc
pinc
.(
        bit trunc
        bpl r
        lda #<m_blk
        ldy #>m_blk
        jsr puts
        jsr pnblk
        lda #<m_inc
        ldy #>m_inc
        jmp puts
r       rts
.)

pnblk   lda nblk
        sta val
        lda #0
        sta val+1
        jmp pdec

; plist : « NNN nom-du-bloc      BAS 0501-0A3F /R »
plist
.(
        lda nblk                ; numéro sur 3 colonnes
        cmp #100
        bcs n3
        lda #" "
        jsr putc
        lda nblk
        cmp #10
        bcs n3
        lda #" "
        jsr putc
n3      jsr pnblk
        lda #" "
        jsr putc
        ldx #0
        lda bname
        bne nm
        lda #"-"                ; bloc sans nom
        jsr putc
        inx
        bne pad
nm      lda bname,x
        beq pad
        cmp #" "
        bcc q
        cmp #$7F
        bcc p
q       lda #"?"
p       jsr putc
        inx
        bne nm
pad     cpx #17
        bcs ty
        lda #" "
        jsr putc
        inx
        bne pad
ty      lda #<m_bas
        ldy #>m_bas
        ldx typ
        beq t
        lda #<m_bin
        ldy #>m_bin
t       jsr puts
        lda adrh
        jsr phex
        lda adrl
        jsr phex
        lda #"-"
        jsr putc
        lda endh
        jsr phex
        lda endl
        jsr phex
        lda aut
        beq e
        lda #<m_run
        ldy #>m_run
        jsr puts
e       jmp crlf
.)

; ---------------------------------------------------------------------
; mkname : nom du fichier du bloc nblk -> fname (8 caractères, espaces)
;   lettres et chiffres de bname, en majuscules, 8 au plus ; vide ou déjà
;   pris par un bloc précédent : nom du .TAP + numéro du bloc
mkname
.(
        jsr blank
        ldx #0
        ldy #0
l       lda bname,x
        beq e
        inx
        cmp #"a"
        bcc u
        cmp #"z"+1
        bcs l
        and #$DF
u       cmp #"0"
        bcc l
        cmp #"9"+1
        bcc k
        cmp #"A"
        bcc l
        cmp #"Z"+1
        bcs l
k       sta fname,y
        iny
        cpy #8
        bne l
e       cpy #0
        beq gen
        jsr seen
        bcc keep
gen     jsr blank               ; nom du .TAP + numéro
        lda nblk                ; chiffres du numéro -> pb (1 à 3)
        ldx #1
        cmp #10
        bcc g1
        inx
        cmp #100
        bcc g1
        inx
g1      stx pb
        lda #8
        sec
        sbc pb                  ; place pour le nom du .TAP
        cmp tlen
        bcc g2
        lda tlen
g2      sta pb+1
        ldy #0
g3      cpy pb+1
        beq g4
        lda ifcb+1,y
        sta fname,y
        iny
        bne g3
g4      lda nblk
        sta val
        lda #0
        sta val+1
        sty pb
        jsr ndec
        ldy pb
        ldx #0
g5      lda dbuf,x
        sta fname,y
        iny
        inx
        cpx dg
        bne g5
keep    lda nnam                ; retenu pour les blocs suivants
        cmp #MAXN
        bcs r
        asl
        asl
        asl
        tax
        ldy #0
k1      lda fname,y
        sta names,x
        inx
        iny
        cpy #8
        bne k1
        inc nnam
r       rts
.)

blank
.(
        ldy #7
        lda #" "
l       sta fname,y
        dey
        bpl l
        rts
.)

; seen : fname déjà parmi les noms retenus ? C=1 : oui
seen
.(
        lda nnam
        sta pb
        lda #0
        sta pb+1                ; début de l'entrée
l       lda pb
        beq no
        ldx pb+1
        ldy #0
c       lda names,x
        cmp fname,y
        bne nx
        inx
        iny
        cpy #8
        bne c
        sec
        rts
nx      lda pb+1
        clc
        adc #8
        sta pb+1
        dec pb
        jmp l
no      clc
        rts
.)

; ---------------------------------------------------------------------
; xbin : le reste du bloc -> NOM.BIN (adresse affichée : adr)
xbin
.(
        lda #"B"
        ldx #"I"
        ldy #"N"
        jsr create
l       jsr getd
        bcs e
        jsr putb
        jmp l
e       jsr wclose
        jmp pwrote
.)

; xbas : bloc BASIC -> NOM.BAS (texte) ; ce qui suit la fin du
;   programme, s'il y a plus d'un octet -> NOM.BIN
xbas
.(
        lda #"B"
        ldx #"A"
        ldy #"S"
        jsr create
line    jsr getd                ; lien (2 octets) : poids fort 0 = fin
        bcs eob
        jsr getd
        bcs eob
        cmp #0
        beq endp
        jsr getd                ; numéro
        bcs eob
        sta num
        jsr getd
        bcs eob
        sta num+1
        lda #0                  ; texte codé jusqu'au 0 -> lbuf
        sta llen
        sta nok
t       jsr getd
        bcs tend
        cmp #0
        beq tend
        ldx llen
        cpx #255
        bcs tovf
        sta lbuf,x
        inc llen
        bne t
tovf    lda #$80                ; plus de 255 octets : gardés tronqués
        sta nok
        bne t
tend    jsr detok
        jsr verify
        jsr wline
        bit nok
        bpl line
        lda #<m_lig             ; « ligne N : recodage different »
        ldy #>m_lig
        jsr puts
        lda num
        sta val
        lda num+1
        sta val+1
        jsr pdec
        lda #<m_dif
        ldy #>m_dif
        jsr puts
        jmp line
eob     jsr wclose              ; bloc fini avant le programme
        jmp pwrote
endp    jsr wclose              ; fin du programme : le .BAS est fini
        jsr pwrote
        lda left+1              ; plus d'un octet après : NOM.BIN
        bne rest
        lda left
        cmp #2
        bcc r
rest    lda adrl                ; à l'adresse début + octets lus
        clc
        adc wcnt
        sta adr
        lda adrh
        adc wcnt+1
        sta adr+1
        jmp xbin
r       rts
.)

; wline : « N texte » puis CR LF dans le .BAS
wline
.(
        lda num
        sta val
        lda num+1
        sta val+1
        jsr ndec
        ldx #0
d       lda dbuf,x
        jsr putb
        inx
        cpx dg
        bne d
        lda #" "
        jsr putb
        jsr wtext
        lda #13
        jsr putb
        lda #10
        jmp putb
.)

; wtext : sbuf dans le .BAS, avec la notation « {hh} » pour ce que
;   MKTAP ne relirait pas tel quel : codes de 0 à 31 et de 127 et plus,
;   espace ou chiffre en tête, espace en fin ; « {{ » pour l'accolade
wtext
.(
        ldx #0
l       cpx slen
        beq r
        lda sbuf,x
        cmp #"{"
        bne c1
        jsr putb
        lda #"{"
        bne w
c1      cmp #" "
        bcc esc
        cmp #$7F
        bcs esc
        cmp #" "
        bne c3
        cpx #0                  ; espace en tête
        beq esc
        inx                     ; espace en fin
        cpx slen
        php
        dex
        plp
        beq esc
        bne w
c3      cpx #0                  ; chiffre en tête
        bne w
        cmp #"0"
        bcc w
        cmp #"9"+1
        bcc esc
w       jsr putb
        inx
        bne l
esc     pha
        lda #"{"
        jsr putb
        pla
        jsr whex
        lda #"}"
        bne w
r       rts
.)

; whex : A en deux chiffres hexadécimaux dans le fichier (X gardé)
whex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        tay
        lda hexd,y
        jsr putb
        pla
        and #$0F
        tay
        lda hexd,y
        jmp putb
.)

; ---------------------------------------------------------------------
; detok : ligne codée lbuf (llen octets) -> texte sbuf (slen, 0 après),
;   comme LIST ; même découpage que crunch : chaîne entre guillemets,
;   DATA jusqu'au « : », REM jusqu'au bout, recopiés tels quels ; ailleurs
;   un code de $80 et plus est un mot-clé. nok : code inconnu, plus de
;   255 caractères.
detok
.(
        lda #0
        sta slen
        sta qmode
        sta rmode
        sta dmode
        tax
l       cpx llen
        bne c
        ldy slen
        lda #0
        sta sbuf,y
        rts
c       lda lbuf,x
        inx
        bit rmode
        bmi raw
        bit qmode
        bmi str
        cmp #$22
        bne c2
        ldy #$80
        sty qmode
        bne raw
str     cmp #$22
        bne raw
        ldy #0
        sty qmode
raw     jsr sput
        jmp l
c2      bit dmode
        bmi ch                  ; DATA : tel quel
        cmp #$80
        bcc ch
        jsr kword
        jmp post
ch      jsr sput
post    cmp #":"
        bne p1
        ldy #0
        sty dmode
        beq l
p1      cmp #T_DATA
        bne p2
        ldy #$80
        sty dmode
        bne l
p2      cmp #T_REM
        bne l
        ldy #$80
        sty rmode
        bne l
.)

; sput : A au bout de sbuf (255 au plus, sinon nok) ; A, X, Y gardés
sput
.(
        sty sy
        ldy slen
        cpy #255
        bcs o
        sta sbuf,y
        inc slen
        ldy sy
        rts
o       pha
        lda #$80
        sta nok
        pla
        ldy sy
        rts
.)

; kword : mot-clé A en toutes lettres dans sbuf ; code inconnu : tel
;   quel, et nok. A et X gardés.
kword
.(
        sta tok
        stx sx
        bit v10                 ; ROM 1.0 : trois codes à part
        bpl k11
        ldx #0
        cmp #$82
        beq alt
        ldx #7
        cmp #$83
        beq alt
        ldx #13
        cmp #$F7
        beq alt
k11     cmp #$80+NKW
        bcs unk
        lda #<bastab
        sta kp
        lda #>bastab
        sta kp+1
        lda tok
        sec
        sbc #$80
        tax
w       cpx #0                  ; X mots à sauter
        beq out
        ldy #0
s       lda (kp),y
        inc kp
        bne s1
        inc kp+1
s1      asl
        bcc s
        dex
        jmp w
out     ldy #0
o       lda (kp),y
        pha
        and #$7F
        jsr sput
        iny
        pla
        bpl o
        bmi done
alt     lda altw,x
        pha
        and #$7F
        jsr sput
        inx
        pla
        bpl alt
        bmi done
unk     jsr sput
        lda #$80
        sta nok
done    lda tok
        ldx sx
        rts
.)
altw    .byt "INVERS","E"+$80,"NORMA","L"+$80,"G","O"+$80

; verify : sbuf recodé par crunch doit redonner lbuf, sinon nok ; une
;   ligne vide aussi (MKTAP l'ignorerait)
verify
.(
        bit nok
        bmi bad
        lda llen
        beq bad
        lda #<cbuf
        sta po
        lda #>cbuf
        sta po+1
        ldx #0
        jsr crunch
        cpy llen
        bne bad
        ldy #0
c       lda cbuf,y
        cmp lbuf,y
        bne bad
        iny
        cpy llen
        bne c
        rts
bad     lda #$80
        sta nok
        rts
.)

; cr_bad : crunch refuse un code de $80 ou plus hors texte (n'arrive pas :
;   detok a déjà marqué ces lignes) ; retour au-delà de verify
cr_bad  pla
        pla
        lda #$80
        sta nok
        rts

#include "bcr_inc.s"

; ---------------------------------------------------------------------
; create : ofcb <- fname + type (A, X, Y), remplacé s'il existe, ouvert
create
.(
        sta ofcb+9
        stx ofcb+10
        sty ofcb+11
        ldy #7
n       lda fname,y
        sta ofcb+1,y
        dey
        bpl n
        lda #0
        ldy #12
z       sta ofcb,y
        iny
        cpy #36
        bne z
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        cmp #$FE
        bne m
        lda #<ofcb
        ldy #>ofcb
        jsr pfull
        lda #<m_ro
        ldy #>m_ro
        jmp fail
m       lda #<ofcb
        ldy #>ofcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_dir
        ldy #>m_dir
        jmp fail
ok      lda #0
        sta opos
        rts
.)

; wclose : dernier enregistrement complété par des ^Z, fichier fermé
wclose
.(
l       lda opos
        beq c
        lda #$1A
        jsr putb
        jmp l
c       lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jmp BDOS
.)

; pwrote : « NOM.BAS ecrit », « NOM.BIN AAAA-FFFF ecrit »
pwrote
.(
        lda #<ofcb
        ldy #>ofcb
        jsr pfull
        lda ofcb+10
        cmp #"I"
        bne d
        lda #" "
        jsr putc
        lda adr+1
        jsr phex
        lda adr
        jsr phex
        lda #"-"
        jsr putc
        lda endh
        jsr phex
        lda endl
        jsr phex
d       lda #<m_done
        ldy #>m_done
        jmp puts
.)

; putb : A dans le fichier écrit (X et Y gardés) ; disque plein :
;   fichier effacé, fin
putb
.(
        stx ox
        ldx opos
        sta obuf,x
        inx
        stx opos
        ldx ox
        bit opos                ; 128 : enregistrement plein
        bmi fl
        rts
fl      pha
        tya
        pha
        lda #<obuf
        ldy #>obuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<ofcb
        ldy #>ofcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        beq ok
        lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        lda #<m_full
        ldy #>m_full
        jmp fail
ok      lda #0
        sta opos
        pla
        tay
        ldx ox
        pla
        rts
.)

; ---------------------------------------------------------------------
; sync : jusqu'au début d'un bloc (un $16 ou plus, puis $24) ; C=1 :
;   fin du fichier
sync
.(
l       jsr getb
        bcs r
        cmp #$16
        bne l
s       jsr getb
        bcs r
        cmp #$16
        beq s
        cmp #$24
        bne l
        clc
r       rts
.)

; getd : octet suivant du bloc -> A ; C=1 : fin du bloc (ou du fichier :
;   trunc). Compte les octets lus (wcnt).
getd
.(
        lda left
        ora left+1
        beq e
        lda left
        bne d
        dec left+1
d       dec left
        inc wcnt
        bne g
        inc wcnt+1
g       jsr getb
        bcs f
        rts
f       lda #$80
        sta trunc
        lda #0
        sta left
        sta left+1
e       sec
        rts
.)

; skip : saute le reste du bloc
skip
.(
l       jsr getd
        bcc l
        rts
.)

; getb : octet suivant du .TAP -> A, C=0 ; C=1 : fin du fichier.
;   X et Y gardés.
getb
.(
        bit ieof
        bmi e
        stx gx
        sty gy
        ldx ipos
        bpl g
        lda #<ibuf
        ldy #>ibuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<ifcb
        ldy #>ifcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne f
        tax
g       lda ibuf,x
        inx
        stx ipos
        ldx gx
        ldy gy
        clc
        rts
f       lda #$80
        sta ieof
        ldx gx
        ldy gy
e       sec
        rts
.)

; ---------------------------------------------------------------------
; pname : nom en TAIL,X -> FCB fp (lecteur, nom, type ; 12-35 à zéro)
;   C=1 : nom vide ou invalide (jokers)
pname
.(
        ldy #0
        lda #0
        sta (fp),y
        iny
        lda #" "
b       sta (fp),y
        iny
        cpy #12
        bne b
        lda #0
z       sta (fp),y
        iny
        cpy #36
        bne z
        lda TAIL+1,x            ; lecteur
        cmp #":"
        bne nm
        lda TAIL,x
        and #$DF
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        ldy #0
        sta (fp),y
        inx
        inx
nm      ldy #1
n1      jsr nchr
        bcs n2
        cmp #"."
        beq ty
        cpy #9
        bcs n3
        sta (fp),y
        iny
n3      inx
        bne n1
ty      inx
        ldy #9
t1      jsr nchr
        bcs n2
        cmp #"."
        beq bad
        cpy #12
        bcs t2
        sta (fp),y
        iny
t2      inx
        bne t1
n2      ldy #1                  ; nom vide : refusé
        lda (fp),y
        cmp #" "
        beq bad
        clc
        rts
bad     sec
        rts
.)

; nchr : caractère TAIL,X du nom en majuscule -> C=1 en fin de nom
;   (espace, fin, /) ; jokers et « : » : erreur (pile rendue)
nchr
.(
        lda TAIL,x
        beq e
        cmp #" "
        beq e
        cmp #"/"
        beq e
        cmp #"*"
        beq bad
        cmp #"?"
        beq bad
        cmp #":"
        beq bad
        cmp #"a"
        bcc r
        cmp #"z"+1
        bcs r
        and #$DF
r       clc
        rts
e       sec
        rts
bad     lda #<m_name
        ldy #>m_name
        jmp fail
.)

skipsp
.(
l       lda TAIL,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)

; getdec : nombre décimal en TAIL,X (jusqu'à l'espace ou la fin) -> val,
;   C=0 ; C=1 : pas un nombre. Au-delà de 255, val+1 n'est pas nul.
getdec
.(
        lda #0
        sta val
        sta val+1
        sta dg
l       lda TAIL,x
        beq e
        cmp #" "
        beq e
        sec
        sbc #"0"
        cmp #10
        bcs no
        ldy val+1               ; déjà plus de 255 : on garde val+1
        bne n
        pha
        lda val                 ; val x 10 + chiffre (val <= 255)
        sta pb
        asl val
        rol val+1
        asl val
        rol val+1
        lda val
        clc
        adc pb
        sta val
        bcc m
        inc val+1
m       asl val
        rol val+1
        pla
        clc
        adc val
        sta val
        bcc n
        inc val+1
n       inc dg
        inx
        bne l
no      sec
        rts
e       lda dg
        beq no
        clc
        rts
.)

; ---------------------------------------------------------------------
; pfull : nom du FCB A/Y (B:NOM.EXT si le lecteur est donné)
pfull
.(
        sta fp
        sty fp+1
        ldy #0
        lda (fp),y
        beq nm
        clc
        adc #"A"-1
        jsr putc
        lda #":"
        jsr putc
nm      ldy #1
l1      lda (fp),y
        cmp #" "
        beq ex
        jsr putc
        iny
        cpy #9
        bne l1
ex      ldy #9
        lda (fp),y
        cmp #" "
        beq r
        lda #"."
        jsr putc
l2      lda (fp),y
        cmp #" "
        beq r
        jsr putc
        iny
        cpy #12
        bne l2
r       rts
.)

; ndec : val -> dbuf (chiffres décimaux sans zéros de tête), dg = nombre
;   (val est perdu)
ndec
.(
        lda #0
        sta dg
        ldy #4
d       ldx #0
s       lda val
        sec
        sbc dl,y
        pha
        lda val+1
        sbc dh,y
        bcc n
        sta val+1
        pla
        sta val
        inx
        bne s
n       pla
        txa
        bne put
        lda dg                  ; zéro de tête : sauté, sauf le dernier
        bne put0
        cpy #0
        bne nx
put0    txa
put     ora #"0"
        ldx dg
        sta dbuf,x
        inc dg
nx      dey
        bpl d
        rts
.)
dl      .byt <1,<10,<100,<1000,<10000
dh      .byt >1,>10,>100,>1000,>10000

; pdec : val en décimal à l'écran
pdec
.(
        jsr ndec
        ldx #0
l       lda dbuf,x
        jsr putc
        inx
        cpx dg
        bne l
        rts
.)

; phex : A en deux chiffres hexadécimaux à l'écran (X et Y gardés)
phex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr d
        pla
        and #$0F
d       stx pb
        tax
        lda hexd,x
        ldx pb
        jmp putc
.)
hexd    .asc "0123456789ABCDEF"

putc
.(
        sta pa
        pha
        txa
        pha
        tya
        pha
        lda pa
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts
.)
crlf    lda #13
        jsr putc
        lda #10
        jmp putc
puts
.(
        sta sp
        sty sp+1
        ldy #0
l       lda (sp),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

#include "untap.msg"
#include "bas_tab.s"

endc
ifcb    = endc          ; le .TAP (36 octets)
ofcb    = ifcb+36       ; le fichier écrit (36 octets)
bname   = ofcb+36       ; nom du bloc (16 caractères, 0)
fname   = bname+17      ; nom du fichier écrit (8)
dbuf    = fname+8       ; chiffres décimaux (5)
names   = dbuf+5        ; noms retenus (8 x MAXN)
ibuf    = names+8*MAXN  ; enregistrement lu
obuf    = ibuf+128      ; enregistrement à écrire
lbuf    = obuf+128      ; ligne codée (255 octets)
sbuf    = lbuf+256      ; ligne en texte (255 caractères, 0)
cbuf    = sbuf+256      ; ligne recodée (crunch)
