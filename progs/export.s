; =====================================================================
;  EXPORT.COM — copie un fichier de CP/A sur la clé USB du LOCI
;
;  EXPORT fic [nom]
;  EXPORT afn [dossier]
;    fic  fichier de CP/A (lecteur facultatif : B:LETTRE.TXT)
;    afn  jokers (*.LOG, B:*.*) : chaque fichier sous son nom (en
;         minuscules si le modèle est tapé en minuscules), à la racine
;         de la clé ou dans le dossier donné (1:/ORIC) ; ESC entre deux
;         fichiers ; un .DSK est sauté
;    nom  nom sur la clé, avec un chemin si l'on veut (1:/DOCS/X.TXT,
;         0:X.TXT pour la mémoire interne du LOCI) ; par défaut, le nom
;         de fic tel qu'il a été tapé (minuscules gardées), à la racine
;         de la clé
;  Un fichier du même nom sur la clé est remplacé. Les ^Z ($1A) qui
;  complètent le dernier enregistrement sont retirés (même règle que
;  STAT) : un texte arrive à sa vraie taille. Les fins de ligne restent
;  CR LF. Refuse d'écrire un .DSK (image de disquette, peut-être celle
;  qui est en service).
; =====================================================================

#include "cpa.inc"

w1      = $10           ; position des mots dans args
w2      = $11
fd      = $12
cnt     = $13
tot     = $14           ; 4 octets : octets écrits
nf      = $18           ; fichiers trouvés (jokers)
i       = $19
nok     = $1A           ; fichiers exportés
lower   = $1B           ; 1 : noms en minuscules
plen    = $1C           ; longueur du dossier de destination
lp      = $1D           ; 2 octets : nom de la liste

MAXF    = 128

        *= $0500
start
.(
        jsr get_args
        ldx #0
        jsr skipsp
        lda args,x
        bne a1
usage   lda #<m_use
        ldy #>m_use
        jmp lputs
a1      stx w1
        jsr skipw
        jsr skipsp
        stx w2
        lda FCB1+1
        cmp #" "
        beq usage
        ldy #11
q       lda FCB1,y
        cmp #"?"
        bne q2
        jmp wild                ; jokers : plusieurs fichiers
q2      dey
        bne q

        ; nom sur la clé : le 2e mot, sinon le 1er sans son lecteur
        ldx w2
        lda args,x
        bne cpn
        ldx w1
        lda args+1,x
        cmp #":"
        bne cpn
        inx
        inx
cpn     ldy #0
cl      lda args,x
        beq ce
        cmp #" "
        beq ce
        sta uname,y
        inx
        iny
        cpy #100
        bne cl
ce      lda #0
        sta uname,y
        jsr dskchk              ; jamais d'image de disquette
        bcc okn
        lda #<m_dsk
        ldy #>m_dsk
        jmp lputs
okn     jsr mia_chk
        bcc open
        rts
open    ldx #35                 ; fichier de CP/A
        lda #0
z       sta fcb,x
        dex
        bpl z
        ldx #15
c       lda FCB1,x
        sta fcb,x
        dex
        bpl c
        jmp xone
.)

; ---------------------------------------------------------------------
; wild : EXPORT *.LOG [dossier] — chaque fichier sous son nom (en
;   minuscules si le modèle a été tapé en minuscules), dans le dossier
; ---------------------------------------------------------------------
wild
.(
        lda #0                  ; minuscules dans le modèle tapé ?
        sta lower
        ldx w1
        lda args+1,x            ; (sans le lecteur)
        cmp #":"
        bne lw
        inx
        inx
lw      lda args,x
        beq lwe
        cmp #" "
        beq lwe
        cmp #"a"
        bcc lwn
        cmp #"z"+1
        bcs lwn
        inc lower
lwn     inx
        bne lw
lwe     ldx w2                  ; dossier : le 2e mot, « / » ajouté
        ldy #0
pc      lda args,x
        beq pe
        cmp #" "
        beq pe
        sta pfx,y
        inx
        iny
        cpy #60
        bne pc
pe      tya
        beq pz
        lda pfx-1,y
        cmp #"/"
        beq pz
        cmp #":"
        beq pz
        lda #"/"
        sta pfx,y
        iny
pz      sty plen

        jsr mia_chk
        bcc go
        rts
go      ldx #11                 ; noms (premier extent de chacun)
c2      lda FCB1,x
        sta fcb,x
        dex
        bpl c2
        lda #0
        sta fcb+12
        sta nf
        lda #<DEF_DMA
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<fcb
        ldy #>fcb
        ldx #F_SFIRST
        jsr BDOS
sl      cmp #$FF
        beq listed
        lda nf
        cmp #MAXF
        bcs nx
        jsr lname
        ldy #1
c3      lda DEF_DMA,y
        and #$7F
        dey
        sta (lp),y
        iny
        iny
        cpy #12
        bne c3
        inc nf
nx      ldx #F_SNEXT
        jsr BDOS
        jmp sl
listed  lda nf
        bne some
        lda #<m_nf
        ldy #>m_nf
        jmp lputs
some    lda #0
        sta i
        sta nok
each    jsr B_CONST             ; ESC entre deux fichiers
        cmp #0
        beq noesc
        jsr B_CONIN
        cmp #27
        bne noesc
        jmp fin
noesc   lda i
        jsr lname
        ldx #35                 ; FCB du fichier
        lda #0
z       sta fcb+1,x
        dex
        bpl z
        lda FCB1
        sta fcb
        ldy #10
cf      lda (lp),y
        sta fcb+1,y
        dey
        bpl cf
        ldy plen                ; nom sur la clé : dossier + NOM.EXT
        ldx #0
nm      lda fcb+1,x
        cmp #" "
        beq nme
        jsr lcase
        sta uname,y
        iny
        inx
        cpx #8
        bne nm
nme     lda fcb+9
        cmp #" "
        beq ext0
        lda #"."
        sta uname,y
        iny
        ldx #8
ex      lda fcb+1,x
        cmp #" "
        beq ext0
        jsr lcase
        sta uname,y
        iny
        inx
        cpx #11
        bne ex
ext0    lda #0
        sta uname,y
        ldy plen                ; « LETTRE.TXT : »
pn      lda uname,y
        beq pnd
        jsr lputc
        iny
        bne pn
pnd     lda #<m_sep
        ldy #>m_sep
        jsr lputs
        ldy #0                  ; longueur pour dskchk
ln      lda uname,y
        beq lnd
        iny
        bne ln
lnd     jsr dskchk
        bcc cp
        lda #<m_dsk
        ldy #>m_dsk
        jsr lputs
        jmp nxt
cp      jsr xone
        bcs fin                 ; erreur de la clé : arrêt
        inc nok
nxt     inc i
        lda i
        cmp nf
        beq fin
        jmp each
fin     lda nok
        jsr pbyte
        lda #<m_done
        ldy #>m_done
        jmp lputs
.)

; lcase : A en minuscule si lower
lcase
.(
        cmp #"A"
        bcc r
        cmp #"Z"+1
        bcs r
        pha
        lda lower
        beq p
        pla
        ora #$20
        rts
p       pla
r       rts
.)

; lname : lp <- liste + 11 x A
lname
.(
        tax
        lda #<list
        sta lp
        lda #>list
        sta lp+1
        cpx #0
        beq r
l       lda lp
        clc
        adc #11
        sta lp
        bcc n
        inc lp+1
n       dex
        bne l
r       rts
.)

; dskchk : C=1 si uname (longueur Y) finit par .DSK
dskchk
.(
        cpy #4
        bcc no
        lda uname-4,y
        cmp #"."
        bne no
        lda uname-3,y
        and #$DF
        cmp #"D"
        bne no
        lda uname-2,y
        and #$DF
        cmp #"S"
        bne no
        lda uname-1,y
        and #$DF
        cmp #"K"
        bne no
        sec
        rts
no      clc
        rts
.)

; xone : copie le fichier fcb (pas encore ouvert) sur la clé, sous le nom
;   uname ; affiche « 1234 octets copies » -> C=1 si erreur de la clé
xone
.(
        lda #<fcb
        ldy #>fcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne opened
        lda #<m_nf
        ldy #>m_nf
        jsr lputs
        clc
        rts
opened  lda #0
        sta fcb+32
        sta tot
        sta tot+1
        sta tot+2
        sta tot+3

        ; fichier de la clé, créé ou vidé
        lda #<uname
        ldy #>uname
        ldx #O_WRONLY+O_CREAT+O_TRUNC
        jsr usb_open
        bcc uok
        jsr usb_err
        sec
        rts
uok     sta fd

        ; lecture avec un enregistrement d'avance : on sait ainsi lequel
        ; est le dernier (ses ^Z sont retirés)
        jsr rd_rec
        bne last0               ; fichier vide
loop    jsr cp_next             ; iobuf <- enregistrement lu
        jsr rd_rec
        bne last
        ldx #128
        jsr wr_buf
        bcc loop
        rts
last    ldx #128                ; dernier : sans ses ^Z
t       lda iobuf-1,x
        cmp #$1A
        bne tl
        dex
        bne t
tl      txa
        beq last0
        jsr wr_buf
        bcc last0
        rts
last0   lda fd
        jsr usb_close
        bcc closed
        jsr usb_err
        sec
        rts
closed  ldx #3                  ; « 1234 octets copies »
cn      lda tot,x
        sta num,x
        dex
        bpl cn
        lda #0
        jsr pnum
        lda #<m_ok
        ldy #>m_ok
        jsr lputs
        clc
        rts
.)

; rd_rec : enregistrement suivant de fcb dans rec -> Z=1 si lu
rd_rec
.(
        lda #<rec
        ldy #>rec
        ldx #F_SETDMA
        jsr BDOS
        lda #<fcb
        ldy #>fcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        rts
.)

; cp_next : rec -> iobuf
cp_next
.(
        ldy #127
l       lda rec,y
        sta iobuf,y
        dey
        bpl l
        rts
.)

; wr_buf : écrit X octets de iobuf sur la clé, les ajoute au total
;   -> C=1 si erreur (message affiché, fichier de la clé fermé)
wr_buf
.(
        stx cnt
        lda fd
        jsr usb_write
        bcs err
        cmp cnt
        bne full
        clc
        adc tot
        sta tot
        bcc r
        inc tot+1
        bne r
        inc tot+2
        bne r
        inc tot+3
r       clc
        rts
full    lda #<m_full
        ldy #>m_full
        jsr lputs
        jmp cl
err     jsr usb_err
cl      lda fd
        jsr usb_close
        sec
        rts
.)

m_use   .asc "EXPORT fic [nom] : copie un fichier",13,10
        .asc "sur la cle USB du LOCI",13,10
        .asc "EXPORT *.LOG [dossier] : plusieurs",13,10,0
m_sep   .asc " : ",0
m_done  .asc " fichier(s) exporte(s)",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_dsk   .asc "Refuse : image de disquette (.DSK)",13,10,0
m_full  .asc "Cle USB pleine",13,10,0
m_ok    .asc " octets copies",13,10,0

#include "loci_inc.s"

; tampons, après la fin du programme
uname   = lib_free       ; nom sur la clé (101)
fcb     = lib_free+101
rec     = lib_free+137
pfx     = uname          ; dossier (jokers) : début de uname
list    = lib_free+265   ; noms (jokers), 11 octets chacun
