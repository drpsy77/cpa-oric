; =====================================================================
;  STAT.COM — taille des fichiers, espace libre (comme STAT de CP/M)
;
;  STAT afn     pour chaque fichier : enregistrements de 128 octets,
;               blocs de 2 Ko occupés, taille en octets
;  STAT         espace libre sur le disque
;
;  Taille en octets : le répertoire CP/M ne compte que des
;  enregistrements de 128 octets. Le dernier est lu et les ^Z ($1A)
;  qui le complètent sont retirés (EDIT, PUT, LOGO et l'outil PC
;  mkdisk.py complètent ainsi). Un fichier binaire dont les derniers
;  octets valent réellement $1A paraît donc un peu plus court.
; =====================================================================

#include "cpa.inc"

ptr     = $10           ; 2 octets
cnt     = $12           ; nombre de noms
i       = $13
num     = $14           ; nombre à afficher (3 octets)
t0      = $17
t1      = $18
dg      = $19
nz      = $1A
pad     = $1B           ; 1 = sur 6 colonnes
sptr    = $1C           ; 2 octets
recs    = $1E           ; 2 octets
used    = $20           ; blocs occupés

NBLK    = 168           ; blocs de données (170 moins le répertoire)

        *= $0500
start
.(
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda FCB1+1
        cmp #" "
        bne files
        jmp free
files   lda #0
        sta cnt
        lda #"?"                ; tous les extents
        sta FCB1+12
        ldx #F_SFIRST
        lda #<FCB1
        ldy #>FCB1
        jsr BDOS
sl      cmp #$FF
        beq listed
        jsr add_name
        ldx #F_SNEXT
        jsr BDOS
        jmp sl
listed  lda cnt
        bne doall
        lda #<m_none
        ldy #>m_none
        jmp puts
doall   lda #<m_head
        ldy #>m_head
        jsr puts
        lda #0
        sta i
each    lda i
        cmp cnt
        bne one
        rts
one     jsr name_ptr
        jsr do_file
        inc i
        jmp each
.)

; do_file : une ligne pour le fichier dont le nom est en (ptr)
do_file
.(
        ldy #35                 ; FCB vide
        lda #0
z       sta fcb,y
        dey
        bpl z
        lda FCB1                ; lecteur donné (STAT B:NOM)
        sta fcb
        ldy #10
cp      lda (ptr),y             ; nom sans les attributs
        and #$7F
        sta fcb+1,y
        dey
        bpl cp
        ldy #0                  ; NOM     .EXT
nm      lda fcb+1,y
        jsr putc
        iny
        cpy #8
        bne nm
        lda #"."
        jsr putc
ext     lda fcb+1,y
        jsr putc
        iny
        cpy #11
        bne ext
        ldx #F_OPEN
        jsr bdos_fcb
        ldx #F_FSIZE
        jsr bdos_fcb
        lda fcb+33
        sta recs
        sta num
        lda fcb+34
        sta recs+1
        sta num+1
        lda #0
        sta num+2
        lda #1
        sta pad
        jsr pdec                ; enregistrements
        lda recs                ; blocs = (enreg. + 15) / 16
        clc
        adc #15
        sta num
        lda recs+1
        adc #0
        ldx #4
dv      lsr
        ror num
        dex
        bne dv
        sta num+1
        jsr pdec
        lda recs                ; octets
        ora recs+1
        beq zero
        lda recs                ; dernier enregistrement : recs - 1
        sec
        sbc #1
        sta fcb+33
        sta num+1
        lda recs+1
        sbc #0
        sta fcb+34
        sta num+2
        lda #0
        sta num
        lsr num+2               ; (recs - 1) * 128
        ror num+1
        ror num
        ldx #F_RREAD
        jsr bdos_fcb
        ldy #128                ; illisible : enregistrement entier
        cmp #0
        bne add
        ldy #127                ; sinon sans les ^Z de la fin
tz      lda DEF_DMA,y
        cmp #$1A
        bne last
        dey
        bpl tz
last    iny
add     tya
        clc
        adc num
        sta num
        bcc show
        inc num+1
        bne show
        inc num+2
        bne show
zero    sta num
        sta num+1
        sta num+2
show    jsr pdec
        jmp crlf
.)

bdos_fcb
        lda #<fcb
        ldy #>fcb
        jmp BDOS

; free : espace libre = blocs de données moins ceux des entrées du répertoire
free
.(
        ldy #11
        lda #"?"
q       sta fcb,y
        dey
        bne q
        lda FCB1                ; lecteur donné (STAT B:), sinon courant
        sta fcb
        sty used
        sty pad
        lda #"?"
        sta fcb+12
        ldx #F_SFIRST
        jsr bdos_fcb
loop    cmp #$FF
        beq done
        ldy #16
bl      lda DEF_DMA,y
        beq nb
        inc used
nb      iny
        cpy #32
        bne bl
        ldx #F_SNEXT
        jsr BDOS
        jmp loop
done    ldx #F_CURDSK           ; lecteur illisible : rien de plus
        jsr BDOS
        ldx fcb
        beq cur
        dex
        txa
cur     tax                     ; lecteur (0 = A:)
        lda #0
        sec
msk     rol
        dex
        bpl msk
        sta cnt
        ldx #F_LOGIN
        jsr BDOS
        and cnt
        bne ok
        rts
ok      lda #<m_free
        ldy #>m_free
        jsr puts
        lda #NBLK               ; en Ko : blocs libres * 2
        sec
        sbc used
        pha
        asl
        sta num
        lda #0
        rol
        sta num+1
        lda #0
        sta num+2
        jsr pdec
        lda #<m_free2
        ldy #>m_free2
        jsr puts
        pla
        sta num
        lda #0
        sta num+1
        jsr pdec
        lda #<m_free3
        ldy #>m_free3
        jmp puts
.)

; add_name : nom de l'entrée trouvée (DMA) ajouté à la liste s'il n'y
; est pas déjà (un gros fichier a plusieurs entrées)
add_name
.(
        lda #0
        sta i
look    lda i
        cmp cnt
        beq new
        jsr name_ptr
        ldy #0
cmp1    lda (ptr),y
        eor DEF_DMA+1,y
        and #$7F
        bne nx
        iny
        cpy #11
        bne cmp1
        rts
nx      inc i
        bne look
new     jsr name_ptr
        ldy #0
cp      lda DEF_DMA+1,y
        sta (ptr),y
        iny
        cpy #11
        bne cp
        inc cnt
        rts
.)

; name_ptr : ptr = list + 11 * i
name_ptr
.(
        lda #<list
        sta ptr
        lda #>list
        sta ptr+1
        ldx i
        beq r
l       clc
        lda ptr
        adc #11
        sta ptr
        bcc n
        inc ptr+1
n       dex
        bne l
r       rts
.)

; pdec : affiche num (24 bits) en décimal ; pad=1 : sur 7 colonnes
; (espace puis 6 chiffres cadrés à droite), pad=0 : sans espaces
pdec
.(
        lda pad
        beq go
        lda #" "
        jsr putc
go      ldx #0
        stx nz
pw      lda #0
        sta dg
sub     lda num
        sec
        sbc p0,x
        sta t0
        lda num+1
        sbc p1,x
        sta t1
        lda num+2
        sbc p2,x
        bcc out
        sta num+2
        lda t1
        sta num+1
        lda t0
        sta num
        inc dg
        bne sub
out     lda dg
        ora nz
        bne show
        cpx #5
        beq show
        lda pad
        beq skip
        lda #" "
        jsr putc
        jmp skip
show    lda dg
        ora #"0"
        jsr putc
        sta nz
skip    inx
        cpx #6
        bne pw
        rts
.)
p0      .byt $A0,$10,$E8,$64,$0A,$01
p1      .byt $86,$27,$03,$00,$00,$00
p2      .byt $01,$00,$00,$00,$00,$00

; putc : affiche A (A, X et Y conservés)
putc    pha
        txa
        pha
        tya
        pha
        tsx
        lda $0103,x
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts

crlf    lda #13
        jsr putc
        lda #10
        jmp putc

puts
.(
        sta sptr
        sty sptr+1
        ldy #0
loop    lda (sptr),y
        beq done
        jsr putc
        iny
        bne loop
done    rts
.)

m_head  .asc "Fichier       Enreg  Blocs Octets",13,10,0
m_none  .asc "Aucun fichier",13,10,0
m_free  .asc "Libre : ",0
m_free2 .asc " Ko (",0
m_free3 .asc " blocs de 2 Ko)",13,10,0

fcb     .dsb 36,0
list                            ; noms trouvés (11 octets chacun)
