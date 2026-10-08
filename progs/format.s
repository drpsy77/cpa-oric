; =====================================================================
;  FORMAT.COM — formate une disquette au format CP/A
;
;  FORMAT X: [/Q]
;    X:  lecteur (A: à D:). FORMAT A: demande d'insérer la disquette à
;        formater, puis de remettre la disquette système (le système
;        reste en mémoire) : marche avec un seul lecteur
;    /Q  rapide : vide seulement le répertoire d'une disquette déjà
;        formatée (images du LOCI, d'Oricutron)
;
;  Format : 2 faces, 42 pistes, 17 secteurs de 256 octets remplis de
;  $E5 (le répertoire est donc vide). Chaque piste est écrite d'un coup
;  par la commande Write Track du WD1793, à partir d'une image de piste
;  construite en TPA, la même disposition que tools/mkdisk.py (le LOCI
;  attend exactement cet écart entre l'en-tête et les données). Les
;  secteurs sont entrelacés 2:1 (1, 10, 2, 11...) : un vrai lecteur a
;  le temps de traiter un secteur avant que le suivant passe sous la
;  tête. Chaque piste est relue aussitôt (17 secteurs, tous à $E5).
;
;  Le contrôleur est piloté directement (rien dans le BIOS pour Write
;  Track). Le pilote du système garde la piste de chaque lecteur :
;  FORMAT tient à jour les mêmes variables (PHY_DRV, DSK_TRK, voir
;  src/hw.inc). À la fin, démarrage à chaud : les répertoires sont
;  relus.
; =====================================================================

#include "cpa.inc"

; contrôleur Microdisc (src/hw.inc)
FDC_CMD     = $0310
FDC_TRK     = $0311
FDC_SEC     = $0312
FDC_DATA    = $0313
MD_CTRL     = $0314     ; écriture : contrôle ; lecture : bit 7 = /INTRQ
MD_DRQ      = $0318     ; lecture : bit 7 = /DRQ
MD_BASE     = $84       ; ROM et EPROM coupées (RAM overlay)
; variables du pilote disque du système (src/hw.inc)
PHY_DRV     = $FD7F     ; lecteur dont la piste est dans FDC_TRK
DSK_TRK     = $FDA4     ; piste de chaque lecteur (4 octets)

NCYL        = 42
NSLOT       = 17
SLOT        = 354       ; octets d'un secteur dans l'image de piste
TRKPG       = 24        ; image de piste : 24 pages (6 144 octets)
ENDOK       = 6040      ; fin utile de l'image (dernières données + CRC)
DIR_LSN     = 68        ; répertoire : LSN 68 à 83

CMD_RESTORE = $0B       ; piste 0, sans vérification
CMD_SEEK    = $1B       ; positionnement sans vérification (piste vierge)
CMD_WTRK    = $F4       ; Write Track, délai de 15 ms
CMD_READ    = $80
CMD_FINT    = $D0       ; Force Interrupt

ptr     = $10           ; 2 octets
drv     = $12           ; lecteur à formater (0-3)
quick   = $13
cyl     = $14
side    = $15
npg     = $16
to      = $17
nsec    = $18
i       = $19
tries   = $1A
sptr    = $1B           ; 2 octets
pch     = $1D

        *= $0500
start
.(
        lda #$FF
        sta drv
        lda #0
        sta quick
        ldx #0
w       lda TAIL+1,x            ; X: et /Q, dans n'importe quel ordre
        beq parsed
        cmp #" "
        bne word
        inx
        bne w
word    cmp #"/"
        bne letter
        lda TAIL+2,x
        cmp #"Q"
        bne usage
        sta quick
        inx
        inx
        jmp w
letter  sec
        sbc #"A"
        cmp #4
        bcs usage
        sta drv
        lda TAIL+2,x
        cmp #":"
        bne usage
        inx
        inx
        jmp w
usage   lda #<m_use
        ldy #>m_use
        jmp puts
parsed  lda drv
        bmi usage

        ldx #F_RESET            ; tampon écrit, lecteurs oubliés
        jsr BDOS
        lda drv
        bne conf
        lda #<m_ins
        ldy #>m_ins
        jsr puts
conf    lda #<m_all             ; « Tout B: sera efface. »
        ldy #>m_all
        jsr puts
        jsr pdrv
        lda #<m_all2
        ldy #>m_all2
        jsr puts
        jsr B_CONIN
        and #$DF
        pha
        cmp #" "
        bcc noecho
        jsr putc
noecho  jsr crlf
        pla
        cmp #"O"
        beq go
        lda #<m_abort
        ldy #>m_abort
        jsr puts
        jmp back
go      lda quick
        beq full
        jsr qformat
        jmp back
full    jsr fformat
back    lda drv                 ; A: : la disquette système, avant le
        bne wb                  ; démarrage à chaud
        lda #<m_sys
        ldy #>m_sys
        jsr puts
        jsr B_CONIN
        jsr crlf
wb      jmp WBOOT
.)

; ---------------------------------------------------------------------
; qformat : /Q, répertoire vide (16 secteurs de $E5) par le BIOS
; ---------------------------------------------------------------------
qformat
.(
        lda drv
        jsr B_SELDSK
        cmp #0
        beq ok
        lda #<m_unr
        ldy #>m_unr
        jmp puts
ok      ldy #0
        lda #$E5
f       sta sbuf,y
        iny
        bne f
        lda #<sbuf
        ldy #>sbuf
        jsr B_SETDMA
        lda #DIR_LSN
        sta nsec
l       lda nsec
        ldy #0
        jsr B_SETSEC
        jsr B_WRITE
        cmp #0
        bne err
        inc nsec
        lda nsec
        cmp #DIR_LSN+16
        bne l
        lda #<m_qok
        ldy #>m_qok
        jmp puts
err     lda #<m_werr
        ldy #>m_werr
        jmp puts
.)

; ---------------------------------------------------------------------
; fformat : formatage complet, piste par piste, avec relecture
; ---------------------------------------------------------------------
fformat
.(
        jsr build
        lda #0
        sta side
        jsr take
        lda #CMD_RESTORE
        jsr fcmd
        bcs absent
        and #$10                ; piste 0 jamais trouvée
        bne absent
        lda #0
        sta cyl
cl      lda #0
        sta side
sl      jsr progress
        jsr B_CONST             ; ESC entre deux pistes : abandon
        cmp #0
        beq noesc
        jsr B_CONIN
        cmp #27
        bne noesc
        lda #<m_int
        ldy #>m_int
        jmp puts
noesc   jsr patch
        jsr selside
        lda side
        bne noseek
        lda cyl
        sta FDC_DATA
        lda #CMD_SEEK
        jsr fcmd
        bcs absent
noseek  jsr wtrack
        bcs werr
        jsr vtrack
        bcs verr
        inc side
        lda side
        cmp #2
        bne sl
        inc cyl
        lda cyl
        cmp #NCYL
        bne cl
        lda #<m_ok
        ldy #>m_ok
        jmp puts
absent  lda #<m_abs
        ldy #>m_abs
        jsr puts
        jsr pdrv
        lda #<m_abs2
        ldy #>m_abs2
        jmp puts
werr    cmp #1
        bne wi
        lda #<m_wp
        ldy #>m_wp
        jmp puts
wi      cmp #2
        bne wt
        lda #<m_inc
        ldy #>m_inc
        jmp puts
wt      jmp absent
verr    lda #<m_verr
        ldy #>m_verr
        jsr puts
        lda nsec
        jsr pdec2
        jmp crlf
.)

; take : le contrôleur passe au lecteur drv (face 0) ; la piste du
;   lecteur précédent est rangée, comme dans md_sel (src/disk.s)
take
.(
        jsr selside
        jsr fwait
        ldx PHY_DRV
        cpx drv
        beq r
        lda FDC_TRK
        sta DSK_TRK,x
        ldx drv
        lda DSK_TRK,x
        sta FDC_TRK
        stx PHY_DRV
r       rts
.)

; selside : lecteur drv, face side
selside
        lda drv
        asl
        ora side
        asl
        asl
        asl
        asl
        ora #MD_BASE
        sta MD_CTRL
        rts

; fcmd : commande de type I (A), attend la fin -> A = état, C=1 si
;   le contrôleur ne répond pas (~3 s)
fcmd
.(
        sta FDC_CMD
        ldy #8
d       dey
        bne d
.)
; fwait : attend que le contrôleur soit libre -> A = état, C=1 si délai
fwait
.(
        ldx #0
        ldy #0
        lda #4
        sta to
l       lda FDC_CMD
        lsr
        bcc ok
        dey
        bne l
        dex
        bne l
        dec to
        bne l
        lda #CMD_FINT
        sta FDC_CMD
        sec
        rts
ok      lda FDC_CMD
        clc
        rts
.)

; wtrack : écrit la piste (image trk) -> C=1 et A = 1 protégée,
;   2 incomplète, 3 pas de réponse
wtrack
.(
        php
        sei
        lda #<trk
        sta ptr
        lda #>trk
        sta ptr+1
        lda #TRKPG
        sta npg
        ldy #0
        ldx #0
        stx to
        lda #CMD_WTRK
        sta FDC_CMD
        ; premier octet : le contrôleur le demande tout de suite (attente
        ; limitée, ~0,7 s) ; ensuite ~14 cycles par attente, comme
        ; l'écriture d'un secteur (src/disk.s)
w0      lda MD_DRQ
        bpl wgo
        dex
        bne w0
        lda MD_CTRL
        bpl early
        dec to
        bne w0
        lda #CMD_FINT
        sta FDC_CMD
        plp
        lda #3
        sec
        rts
wl      lda MD_DRQ
        bmi wchk
wgo     lda (ptr),y
        sta FDC_DATA
        iny
        bne wl
        inc ptr+1
        dec npg
        bne wl
fl      lda MD_DRQ              ; image écrite : $4E jusqu'à la fin de la
        bmi fchk                ; piste (impulsion d'index, ou 6 400
        lda #$4E                ; octets pour le LOCI et Oricutron)
        sta FDC_DATA
        jmp fl
fchk    lda MD_CTRL
        bmi fl
        bpl done
wchk    lda MD_CTRL
        bmi wl
early   lda #TRKPG              ; fin avant la fin de l'image : position ?
        sec
        sbc npg                 ; pages écrites
        cmp #>ENDOK
        bcc sh
        bne done
        cpy #<ENDOK
        bcs done
sh      lda #1
        .byt $2C                ; (saute lda #0)
done    lda #0
        sta i                   ; 1 : image pas entièrement écrite
        jsr fwait
        plp
        tax                     ; état
        and #$40                ; protégée en écriture
        bne prot
        lda i
        bne short
        txa
        and #$04                ; perte de données
        bne short
        clc
        rts
prot    lda #1
        sec
        rts
short   lda #2
        sec
        rts
.)

; vtrack : relit les 17 secteurs de la piste -> C=1 si l'un d'eux est
;   illisible ou n'est pas vierge ($E5) ; nsec = son numéro
vtrack
.(
        lda #1
        sta nsec
l       lda #2
        sta tries
t       jsr rsec
        bcc ok
        dec tries
        bne t
        rts
ok      inc nsec
        lda nsec
        cmp #NSLOT+1
        bne l
        clc
        rts
.)

; rsec : lit le secteur nsec de la piste dans sbuf -> C=1 si erreur ou
;   si un octet n'est pas $E5
rsec
.(
        php
        sei
        lda nsec
        sta FDC_SEC
        ldy #0
        ldx #0
        stx to
        lda #CMD_READ
        sta FDC_CMD
r0      lda MD_DRQ
        bpl rd1
        dex
        bne r0
        lda MD_CTRL
        bpl fin
        dec to
        bne r0
        lda #CMD_FINT
        sta FDC_CMD
        plp
        sec
        rts
rd      lda MD_DRQ
        bmi rchk
rd1     lda FDC_DATA
        sta sbuf,y
        iny
        bne rd
        beq fin
rchk    lda MD_CTRL
        bmi rd
fin     sty i                   ; 0 : les 256 octets lus
        jsr fwait
        plp
        and #$1C                ; non trouvé, CRC, perte de données
        bne bad
        lda i
        bne bad
        ldy #0
c       lda sbuf,y
        cmp #$E5
        bne bad
        iny
        bne c
        clc
        rts
bad     sec
        rts
.)

; build : image d'une piste dans trk (cylindre et face posés par patch)
build
.(
        lda #<trk
        sta ptr
        lda #>trk
        sta ptr+1
        lda #$4E                ; début de piste
        ldx #60
        jsr fill
        lda #0
        sta i
s       lda #$00                ; en-tête : synchro, $A1 x 3, $FE
        ldx #12
        jsr fill
        lda #$F5
        ldx #3
        jsr fill
        lda #$FE
        jsr put1
        lda #0                  ; cylindre, face
        jsr put1
        jsr put1
        ldx i
        lda iltab,x             ; secteur
        jsr put1
        lda #1                  ; 256 octets
        jsr put1
        lda #$F7                ; CRC (2 octets)
        jsr put1
        lda #$4E
        ldx #22
        jsr fill
        lda #$00                ; données : synchro, $A1 x 3, $FB
        ldx #12
        jsr fill
        lda #$F5
        ldx #3
        jsr fill
        lda #$FB
        jsr put1
        lda #$E5
        ldx #0                  ; 256 octets
        jsr fill
        lda #$F7
        jsr put1
        lda #$4E
        ldx #38
        jsr fill
        inc i
        lda i
        cmp #NSLOT
        bne s
        lda #$4E                ; jusqu'à 24 pages
        ldx #66                 ; 6 144 - 60 - 17 x 354
        jmp fill
.)

; fill : X fois l'octet A (0 : 256 fois) ; put1 : un octet A, en (ptr)
fill
.(
l       jsr put1
        dex
        bne l
        rts
.)
put1
.(
        ldy #0
        sta (ptr),y
        inc ptr
        bne r
        inc ptr+1
r       rts
.)

; patch : cylindre et face dans les 17 en-têtes
patch
.(
        lda #<trk76
        sta ptr
        lda #>trk76
        sta ptr+1
        ldx #NSLOT
l       ldy #0
        lda cyl
        sta (ptr),y
        iny
        lda side
        sta (ptr),y
        lda ptr
        clc
        adc #<SLOT
        sta ptr
        lda ptr+1
        adc #>SLOT
        sta ptr+1
        dex
        bne l
        rts
.)

; progress : « Piste 12 face 1 » sur la même ligne
progress
        lda #13
        jsr putc
        lda #<m_trk
        ldy #>m_trk
        jsr puts
        lda cyl
        jsr pdec2
        lda #<m_face
        ldy #>m_face
        jsr puts
        lda side
        ora #"0"
        jmp putc

; pdec2 : A (0-99) sur deux chiffres
pdec2
.(
        ldx #"0"
l       cmp #10
        bcc u
        sbc #10
        inx
        bne l
u       pha
        txa
        jsr putc
        pla
        ora #"0"
        jmp putc
.)

; pdrv : lettre du lecteur et « : »
pdrv    lda drv
        clc
        adc #"A"
        jsr putc
        lda #":"
        jmp putc

putc
.(
        sta pch
        pha
        txa
        pha
        tya
        pha
        lda pch
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
        sta sptr
        sty sptr+1
        ldy #0
l       lda (sptr),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

iltab   .byt 1,10,2,11,3,12,4,13,5,14,6,15,7,16,8,17,9

m_use   .asc "FORMAT X: [/Q] : formate X: (A a D)",13,10
        .asc "/Q : vide seulement le repertoire",13,10,0
m_ins   .asc "Inserez en A: la disquette a formater",13,10,0
m_all   .asc "Tout ",0
m_all2  .asc " sera efface. Suite (O/N) ? ",0
m_abort .asc "Abandon",13,10,0
m_sys   .asc "Remettez la disquette systeme en A:,",13,10
        .asc "puis une touche",13,10,0
m_unr   .asc "Disquette illisible : FORMAT sans /Q",13,10,0
m_werr  .asc "Erreur d'ecriture",13,10,0
m_qok   .asc "Repertoire vide",13,10,0
m_ok    .asc 13,10,"Formatage termine",13,10,0
m_int   .asc 13,10,"Interrompu : disquette a reformater",13,10,0
m_abs   .asc 13,10,"Lecteur ",0
m_abs2  .asc " absent ou vide",13,10,0
m_wp    .asc 13,10,"Disquette protegee en ecriture",13,10,0
m_inc   .asc 13,10,"Piste ecrite en partie seulement",13,10,0
m_verr  .asc 13,10,"Relecture : erreur secteur ",0
m_trk   .asc "Piste ",0
m_face  .asc " face ",0

endp
sbuf    = endp          ; secteur relu (256)
trk     = endp+256      ; image de piste (24 pages)
trk76   = endp+256+76   ; cylindre du premier en-tête
