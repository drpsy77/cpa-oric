; =====================================================================
;  DISKCOPY.COM — copie d'une disquette, ou de son système
;
;  DISKCOPY src: dst: [/T] [/V] [/S]
;    copie la disquette de src: sur celle de dst: (déjà formatée) :
;    amorçage et système (LSN 0-67), répertoire, puis les seuls blocs
;    occupés de la source
;    /T  copie tout (les 1 428 secteurs)
;    /V  relit chaque secteur écrit et le compare
;    /S  rend dst: démarrable sans toucher à ses fichiers (comme SYSGEN
;        de CP/M) : amorçage et système seulement (LSN 0-67) ; les
;        commandes se copient ensuite par COPY *.COM B:
;  DISKCOPY A: A: marche avec un seul lecteur : la source et la
;  destination sont demandées tour à tour (une fois par tranche).
;
;  Secteurs copiés par les entrées SELDSK, SETSEC, SETDMA, READ et
;  WRITE du BIOS, par tranches aussi grandes que la TPA (~165
;  secteurs). ESC entre deux tranches. Démarrage à chaud à la fin.
; =====================================================================

#include "cpa.inc"

DIR_LSN     = 68
NSECT       = 1428
NBLK        = 170

ptr     = $10           ; 2 octets
src     = $12
dst     = $13
opt_t   = $14
opt_v   = $15
opt_s   = $16
lsn     = $17           ; 2 octets : prochain secteur à examiner
k       = $19           ; secteurs de la tranche
cap     = $1A           ; secteurs par tranche
bufpg   = $1B           ; première page du tampon
i       = $1C
t0      = $1D
t1      = $1E
pch     = $1F
sptr    = $20           ; 2 octets
slice   = $23
single  = $24           ; 1 : un seul lecteur (src = dst)
ptr2    = $28           ; 2 octets
msg     = $2A
nent    = $2B

        *= $0500
start
.(
        lda #$FF
        sta src
        sta dst
        lda #0
        sta opt_t
        sta opt_v
        sta opt_s
        ldx #0
w       lda TAIL+1,x
        beq parsed
        cmp #" "
        bne word
        inx
        bne w
word    cmp #"/"
        bne letter
        lda TAIL+2,x
        ldy #0
        cmp #"T"
        beq o1
        iny
        cmp #"V"
        beq o1
        iny
        cmp #"S"
        bne usage
o1      lda #1
        sta opt_t,y
        inx
        inx
        jmp w
letter  sec
        sbc #"A"
        cmp #4
        bcs usage
        tay
        lda TAIL+2,x
        cmp #":"
        bne usage
        inx
        inx
        lda src
        bmi s1
        lda dst
        bpl usage
        sty dst
        jmp w
s1      sty src
        jmp w
usage   lda #<m_use
        ldy #>m_use
        jmp puts
parsed  lda dst
        bmi usage
        ldy #0
        lda src
        cmp dst
        bne two
        iny
two     sty single
        lda #>endb              ; tampon : pages libres jusqu'au haut
        clc                     ; de la TPA
        adc #1
        sta bufpg
        lda TPA_TOP+1
        sec
        sbc bufpg
        sta cap

        ldx #F_RESET            ; tampon du BDOS écrit, lecteurs oubliés
        jsr BDOS
        lda single
        beq chk
        jsr ask_src
chk     lda src                 ; les deux disquettes sont-elles lisibles ?
        jsr B_SELDSK
        cmp #0
        beq srcok
        lda #<m_srcbad
        ldy #>m_srcbad
        jmp fin
srcok   lda single
        bne conf
        lda dst
        jsr B_SELDSK
        cmp #0
        beq conf
        lda #<m_dstbad
        ldy #>m_dstbad
        jmp fin

conf    lda opt_s               ; confirmation
        beq c2
        lda #<m_cs
        ldy #>m_cs
        jsr puts
        jsr pdst
        lda #<m_cs2
        ldy #>m_cs2
        jsr puts
        jmp c3
c2      lda single
        beq c4
        lda #<m_c1
        ldy #>m_c1
        jsr puts
        jmp c3
c4      lda #<m_ca
        ldy #>m_ca
        jsr puts
        jsr pdst
        lda #<m_ca2
        ldy #>m_ca2
        jsr puts
        lda src
        jsr pdrv
        lda #<m_ca3
        ldy #>m_ca3
        jsr puts
c3      lda #<m_yn
        ldy #>m_yn
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
        jmp fin

go      jsr plan                ; blocs à copier
        bcs ioerr
        jsr copy
        bcs stop
        lda #<m_ok
        ldy #>m_ok
        jmp fin
ioerr   lda #<m_rerr
        ldy #>m_rerr
        jsr puts
stop    lda #<m_inc
        ldy #>m_inc
fin     jsr puts
        lda single              ; un seul lecteur : la disquette système
        beq wb                  ; avant le démarrage à chaud
        lda src
        bne wb
        lda #<m_sys
        ldy #>m_sys
        jsr puts
        jsr B_CONIN
        jsr crlf
wb      jmp WBOOT
.)

; ---------------------------------------------------------------------
; plan : bmap (un octet par bloc : 1 = à copier) d'après le répertoire
;   de la source (sans objet pour /T et /S). C=1 si le répertoire est
;   illisible.
; ---------------------------------------------------------------------
plan
.(
        ldx #NBLK-1
        lda opt_t
z       sta bmap,x
        dex
        cpx #$FF
        bne z
        lda #1                  ; blocs 0 et 1 : le répertoire
        sta bmap
        sta bmap+1
        lda opt_t
        ora opt_s
        beq rd
        clc
        rts
rd      lda src
        jsr B_SELDSK
        lda #<vbuf
        ldy #>vbuf
        jsr B_SETDMA
        lda #DIR_LSN
        sta i
sect    lda i
        ldy #0
        jsr B_SETSEC
        jsr B_READ
        cmp #0
        beq rok
        sec
        rts
rok     lda #<vbuf
        sta ptr
        lda #>vbuf
        sta ptr+1
        lda #8
        sta nent
ent     ldy #0
        lda (ptr),y
        cmp #$E5
        beq next
        ldy #16                 ; blocs de l'entrée
blk     lda (ptr),y
        beq nb
        cmp #NBLK
        bcs nb
        tax
        lda #1
        sta bmap,x
nb      iny
        cpy #32
        bne blk
next    lda ptr
        clc
        adc #32
        sta ptr
        bcc n2
        inc ptr+1
n2      dec nent
        bne ent
        inc i                   ; secteur suivant du répertoire
        lda i
        cmp #DIR_LSN+16
        bne sect
        clc
        rts
.)

; want : C=1 si le secteur lsn est à copier
want
.(
        lda lsn+1
        bne dat2
        lda lsn
        cmp #DIR_LSN
        bcs dat2
        sec                     ; amorçage et système : toujours
        rts
dat2    lda opt_s
        bne no
        lda lsn                 ; bloc = (lsn - 68) / 8
        sec
        sbc #DIR_LSN
        sta t0
        lda lsn+1
        sbc #0
        lsr
        ror t0
        lsr
        ror t0
        lsr
        ror t0
        ldx t0
        lda bmap,x
        beq no
        sec
        rts
no      clc
        rts
.)

; ---------------------------------------------------------------------
; copy : copie des secteurs, tranche par tranche -> C=1 si arrêt
; ---------------------------------------------------------------------
copy
.(
        lda #0
        sta lsn
        sta lsn+1
        sta slice
tr      ldx #0                  ; liste des secteurs de la tranche
        stx k
fill    lda lsn+1
        cmp #>NSECT
        bcc in
        bne filled
        lda lsn
        cmp #<NSECT
        bcs filled
in      jsr want
        bcc skip
        ldx k
        lda lsn
        sta lsnlo,x
        lda lsn+1
        sta lsnhi,x
        inc k
skip    inc lsn
        bne s2
        inc lsn+1
s2      lda k
        cmp cap
        bne fill
filled  lda k
        bne work
        clc                     ; plus rien à copier
        rts
work    inc slice
        jsr B_CONST             ; ESC : arrêt
        cmp #0
        beq noesc
        jsr B_CONIN
        cmp #27
        bne noesc
        sec
        rts
noesc   lda single
        beq r0
        lda slice
        cmp #1
        beq r0                  ; (la source est déjà là)
        jsr ask_src
r0      ldx #0
        jsr progress
        lda src
        jsr B_SELDSK
        lda #0
        jsr pass
        bcs rerr
        lda single
        beq w0
        jsr ask_dst
w0      ldx #1
        jsr progress
        lda dst
        jsr B_SELDSK
        lda #1
        jsr pass
        bcs werr
        lda opt_v
        beq nv
        ldx #2
        jsr progress
        jsr verify
        bcs verr
nv      jmp tr
rerr    lda #<m_rerr
        ldy #>m_rerr
        jmp err
werr    lda #<m_werr
        ldy #>m_werr
        jmp err
verr    lda #<m_verr
        ldy #>m_verr
err     jsr puts
        ldx i
        lda lsnlo,x
        sta t0
        lda lsnhi,x
        sta t1
        jsr pnum16
        jsr crlf
        sec
        rts
.)

; pass : lit (A = 0) ou écrit (A = 1) les k secteurs de la tranche,
;   page bufpg + i -> C=1 si erreur (i = rang du secteur)
pass
.(
        sta t0
        lda #0
        sta i
l       ldx i
        lda lsnlo,x
        ldy lsnhi,x
        jsr B_SETSEC
        lda #0
        ldx i
        txa
        clc
        adc bufpg
        tay
        lda #0
        jsr B_SETDMA
        lda t0
        bne wr
        jsr B_READ
        jmp ck
wr      jsr B_WRITE
ck      cmp #0
        bne bad
        inc i
        lda i
        cmp k
        bne l
        clc
        rts
bad     sec
        rts
.)

; verify : relit chaque secteur écrit dans vbuf et le compare
verify
.(
        lda #<vbuf
        ldy #>vbuf
        jsr B_SETDMA
        lda #0
        sta i
        sta ptr
l       ldx i
        lda lsnlo,x
        ldy lsnhi,x
        jsr B_SETSEC
        jsr B_READ
        cmp #0
        bne bad
        lda i
        clc
        adc bufpg
        sta ptr+1
        ldy #0
c       lda (ptr),y
        cmp vbuf,y
        bne bad
        iny
        bne c
        inc i
        lda i
        cmp k
        bne l
        clc
        rts
bad     sec
        rts
.)

; progress : « Tranche 3 : lecture » (X = 0 lecture, 1 écriture,
;   2 relecture)
progress
.(
        stx msg
        lda #13
        jsr putc
        lda #<m_tr
        ldy #>m_tr
        jsr puts
        lda slice
        sta t0
        lda #0
        sta t1
        jsr pnum16
        ldx msg
        lda m_pl,x
        ldy m_ph,x
        jmp puts
.)
m_pl    .byt <m_rd,<m_wr,<m_vf
m_ph    .byt >m_rd,>m_wr,>m_vf

; ask_src / ask_dst : un seul lecteur, la disquette voulue
ask_src lda #<m_isrc
        ldy #>m_isrc
        jmp ask
ask_dst lda #<m_idst
        ldy #>m_idst
ask     jsr puts
        lda src
        jsr pdrv
        lda #<m_key
        ldy #>m_key
        jsr puts
        jsr B_CONIN
        jmp crlf

; pdrv : lettre du lecteur A, et « : » ; pdst : celle de dst
pdst    lda dst
pdrv    clc
        adc #"A"
        jsr putc
        lda #":"
        jmp putc

; pnum16 : t0/t1 en décimal
pnum16
.(
        ldy #4
        lda #0
        sta pch                 ; 1 : un chiffre déjà affiché
d       ldx #0
s       lda t0
        sec
        sbc p10l,y
        sta sptr
        lda t1
        sbc p10h,y
        bcc o
        sta t1
        lda sptr
        sta t0
        inx
        bne s
o       txa
        bne pr
        lda pch
        bne pr
        cpy #0
        bne nx
pr      txa
        ora #"0"
        jsr putc
        lda #1
        sta pch
nx      dey
        bpl d
        rts
.)
p10l    .byt 1,10,100,<1000,<10000
p10h    .byt 0,0,0,>1000,>10000

putc
.(
        sta sptr+1
        pha
        txa
        pha
        tya
        pha
        lda sptr+1
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
        sta ptr2
        sty ptr2+1
        ldy #0
l       lda (ptr2),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

m_use   .asc "DISKCOPY src: dst: [/T] [/V] [/S]",13,10
        .asc "copie une disquette (dst formatee)",13,10
        .asc "/T tout  /V relecture",13,10
        .asc "/S systeme seulement (SYSGEN)",13,10,0
m_srcbad .asc "Source illisible",13,10,0
m_dstbad .asc "Destination illisible : FORMAT ?",13,10,0
m_cs    .asc "Systeme (amorcage) copie sur ",0
m_cs2   .asc 13,10,"(fichiers gardes).",0
m_ca    .asc "Tout ",0
m_ca2   .asc " sera remplace par ",0
m_ca3   .asc ".",0
m_yn    .asc 13,10,"Suite (O/N) ? ",0
m_c1    .asc "La DESTINATION sera remplacee.",0
m_abort .asc "Abandon",13,10,0
m_ok    .asc 13,10,"Copie terminee",13,10,0
m_inc   .asc 13,10,"Copie interrompue : destination",13,10
        .asc "incomplete",13,10,0
m_sys   .asc "Remettez la disquette systeme en A:,",13,10
        .asc "puis une touche",13,10,0
m_isrc  .asc 13,10,"SOURCE en ",0
m_idst  .asc 13,10,"DESTINATION en ",0
m_key   .asc ", une touche",0
m_rerr  .asc 13,10,"Erreur de lecture, secteur ",0
m_werr  .asc 13,10,"Erreur d'ecriture, secteur ",0
m_verr  .asc 13,10,"Relecture differente, secteur ",0
m_tr    .asc "Tranche ",0
m_rd    .asc " : lecture    ",0
m_wr    .asc " : ecriture   ",0
m_vf    .asc " : relecture  ",0

endp
vbuf    = endp          ; secteur relu (256)
lsnlo   = endp+256      ; secteurs de la tranche (256 + 256)
lsnhi   = endp+512
bmap    = endp+768      ; blocs à copier (170)
endb    = endp+938
