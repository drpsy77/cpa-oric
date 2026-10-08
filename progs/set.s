; =====================================================================
;  SET.COM — attributs des fichiers
;
;  SET afn                affiche les attributs
;  SET afn RO|RW|SYS|DIR  lecture seule / lecture-écriture /
;                         caché pour DIR (système) / visible
;  Plusieurs options possibles : SET HELP.COM RO SYS
;  R/O : le fichier ne peut être ni effacé, ni renommé, ni écrit.
;  SYS : DIR ne le montre pas (DIRS oui) ; il reste utilisable.
; =====================================================================

#include "cpa.inc"

ptr     = $10
cnt     = $12           ; nombre de noms
i       = $13
ro      = $14           ; $80 / $00 / $FF (inchangé)
sys     = $15
tp      = $16
wptr    = $1A
sptr    = $1C

        *= $0500
start
.(
        lda FCB1+1
        cmp #" "
        bne arg
        lda #<m_usage
        ldy #>m_usage
        jmp puts
arg     lda #$FF
        sta ro
        sta sys
        ldx #1                  ; options : mots après le premier
        jsr skipsp
        jsr skipw
opt     jsr skipsp
        lda TAIL,x
        beq optend
        stx tp
        lda #<w_ro              ; RO
        ldy #>w_ro
        jsr word_is
        bcs n1
        lda #$80
        sta ro
        bne opt
n1      ldx tp
        lda #<w_rw
        ldy #>w_rw
        jsr word_is
        bcs n2
        lda #0
        sta ro
        beq opt
n2      ldx tp
        lda #<w_sys
        ldy #>w_sys
        jsr word_is
        bcs n3
        lda #$80
        sta sys
        bne opt
n3      ldx tp
        lda #<w_dir
        ldy #>w_dir
        jsr word_is
        bcs bad
        lda #0
        sta sys
        beq opt
bad     lda #<m_badopt
        ldy #>m_badopt
        jmp puts
optend  ; --- liste des fichiers ---
        lda #0
        sta cnt
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #0
        sta FCB1+12             ; tous les extents
        lda #"?"
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
doall   lda #0
        sta i
each    lda i
        cmp cnt
        beq done
        jsr name_ptr
        lda ro                  ; nouveaux attributs
        cmp #$FF                ; $FF : inchangé
        beq k1
        ldy #8
        lda (ptr),y
        and #$7F
        ora ro
        sta (ptr),y
k1      lda sys
        cmp #$FF
        beq k2
        ldy #9
        lda (ptr),y
        and #$7F
        ora sys
        sta (ptr),y
k2      lda ro
        and sys                 ; les deux à $FF : rien à écrire
        cmp #$FF
        beq show
        lda FCB1                ; FCB : lecteur demandé, nom et attributs
        sta fcb
        ldy #0
cp      lda (ptr),y
        sta fcb+1,y
        iny
        cpy #11
        bne cp
        ldx #F_ATTRIB
        lda #<fcb
        ldy #>fcb
        jsr BDOS
show    jsr show_name
        inc i
        jmp each
done    rts
.)

; add_name : nom de l'entrée trouvée (DMA, 32 octets) ajouté à la liste
; s'il n'y est pas déjà (un fichier peut avoir plusieurs entrées)
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
        rts                     ; déjà là
nx      inc i
        bne look
new     jsr name_ptr            ; ptr = place du nouveau nom
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
        lda #<list
        sta ptr
        lda #>list
        sta ptr+1
        ldx i
        beq np_r
np1     clc
        lda ptr
        adc #11
        sta ptr
        bcc np2
        inc ptr+1
np2     dex
        bne np1
np_r    rts

; show_name : « NOM.EXT   R/O SYS »
show_name
.(
        ldy #0
nm      lda (ptr),y
        and #$7F
        jsr putc
        iny
        cpy #8
        bne nm
        lda #"."
        jsr putc
ext     lda (ptr),y
        and #$7F
        jsr putc
        iny
        cpy #11
        bne ext
        ldy #8
        lda (ptr),y
        bpl rw
        lda #<m_ro
        ldy #>m_ro
        jsr puts
        jmp sy
rw      lda #<m_rw
        ldy #>m_rw
        jsr puts
sy      ldy #9
        lda (ptr),y
        bpl dir
        lda #<m_sys
        ldy #>m_sys
        jsr puts
        jmp crlf
dir     lda #<m_dir
        ldy #>m_dir
        jsr puts
        jmp crlf
.)

; word_is : le mot en TAIL,X vaut-il la chaîne A/Y ? C=0 oui (X après)
word_is
.(
        sta wptr
        sty wptr+1
        ldy #0
loop    lda (wptr),y
        beq end
        cmp TAIL,x
        bne no
        inx
        iny
        bne loop
end     lda TAIL,x              ; le mot doit finir ici
        beq yes
        cmp #" "
        beq yes
no      sec
        rts
yes     clc
        rts
.)

skipsp  lda TAIL,x
        cmp #" "
        bne ss_r
        inx
        bne skipsp
ss_r    rts

skipw   lda TAIL,x
        beq sw_r
        cmp #" "
        beq sw_r
        inx
        bne skipw
sw_r    rts

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

w_ro    .asc "RO",0
w_rw    .asc "RW",0
w_sys   .asc "SYS",0
w_dir   .asc "DIR",0
m_ro    .asc "  R/O",0
m_rw    .asc "  R/W",0
m_sys   .asc " SYS",0
m_dir   .asc " DIR",0
m_usage .asc "Usage : SET afn [RO|RW|SYS|DIR]",13,10,0
m_badopt .asc "Options : RO RW SYS DIR",13,10,0
m_none  .asc "No file",13,10,0

fcb     .dsb 36,0
list                            ; noms trouvés (11 octets chacun)
