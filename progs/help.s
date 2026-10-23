; =====================================================================
;  HELP.COM — aide de CP/A
;
;  HELP          commandes internes et liste des sujets
;  HELP sujet    TOUCHES PROGRAMMES EDIT HEX LOGO ASM DEBUG MEMOIRE
;                USB GRAPHER CMDER (en anglais : KEYS PROGRAMS EDIT HEX
;                LOGO ASM DEBUG MEMORY USB GRAPHER CMDER)
;                (les premières lettres suffisent)
;  Les textes viennent de tools/gen_readme_txt.py (helptab.msg, dans
;  progs/msg/fr et progs/msg/en), comme README.TXT. Ils sont compressés (LZSS, format de tools/lzhir.py) :
;  unz les décode dans le tampon buf, qui suit le programme, du début
;  jusqu'à la fin de la rubrique demandée.
; =====================================================================

#include "cpa.inc"

ptr     = $10
key     = $12
wlen    = $14
idx     = $15
src     = $16           ; flux compressé (unz)
dst     = $18           ; texte décodé
cpy_p   = $1A           ; source d'une copie
dist    = $1C
flg     = $1E           ; drapeaux du groupe de 8 jetons
cnt     = $1F
stop    = $20           ; fin de la rubrique dans buf

        *= $0500
start
.(
        ldx #0                  ; longueur du mot (nom de FCB1)
len     lda FCB1+1,x
        cmp #" "
        beq lend
        inx
        cpx #8
        bne len
lend    stx wlen
        lda #0
        sta idx
        cpx #0
        beq show                ; pas de sujet : texte par défaut
        lda #<help_keys
        sta key
        lda #>help_keys
        sta key+1
next    inc idx
        ldy #0
        lda (key),y
        beq unknown             ; fin de la table
cmp1    lda (key),y             ; compare jusqu'à la fin de la clé ou du mot
        beq found
        cpy wlen
        beq found
        cmp FCB1+1,y
        bne skip
        iny
        bne cmp1
skip    ldy #0                  ; clé suivante
sk      lda (key),y
        beq sk2
        iny
        bne sk
sk2     iny
        tya
        clc
        adc key
        sta key
        bcc next
        inc key+1
        bne next
unknown lda #<m_unknown
        ldy #>m_unknown
        jsr puts
        lda #0
        sta idx
show    lda idx
        asl
        tax
        clc
        lda help_ends,x
        adc #<buf
        sta stop
        lda help_ends+1,x
        adc #>buf
        sta stop+1
        jsr unz
        lda idx
        asl
        tax
        clc
        lda help_offs,x
        adc #<buf
        pha
        lda help_offs+1,x
        adc #>buf
        tay
        pla
        jmp puts
found   jmp show
.)

puts
.(
        sta ptr
        sty ptr+1
loop    ldy #0
        lda (ptr),y
        beq done
        ldx #F_CONOUT
        jsr BDOS
        inc ptr
        bne loop
        inc ptr+1
        bne loop
done    rts
.)

; unz : décode hz_data dans buf jusqu'à stop (au moins).
; Groupes de 8 jetons précédés d'un octet de drapeaux lu à partir du bit 0 :
; 1 = littéral (1 octet), 0 = copie (distance 16 bits, longueur), source =
; position en cours moins la distance. Une copie peut dépasser stop :
; sans effet, la place après le texte est libre.
unz
.(
        lda #<hz_data
        sta src
        lda #>hz_data
        sta src+1
        lda #<buf
        sta dst
        lda #>buf
        sta dst+1
grp     jsr getb                ; drapeaux du groupe
        sta flg
        lda #8
        sta cnt
tok     lda dst+1               ; dst >= stop : fini
        cmp stop+1
        bcc go
        bne fin
        lda dst
        cmp stop
        bcs fin
go      lsr flg
        bcc copy
        jsr getb                ; littéral
        jsr putb
        jmp nxt
copy    jsr getb                ; distance
        sta dist
        jsr getb
        sta dist+1
        sec
        lda dst
        sbc dist
        sta cpy_p
        lda dst+1
        sbc dist+1
        sta cpy_p+1
        jsr getb                ; longueur (4 à 255)
        tax
        sta dist                ; gardée pour avancer dst
        ldy #0
cl      lda (cpy_p),y           ; octet par octet : les copies qui se
        sta (dst),y             ; recouvrent marchent
        iny
        dex
        bne cl
        clc
        lda dst
        adc dist
        sta dst
        bcc nxt
        inc dst+1
nxt     dec cnt
        bne tok
        beq grp
fin     rts
.)

getb
.(
        ldy #0
        lda (src),y
        inc src
        bne r
        inc src+1
r       rts
.)

putb
.(
        ldy #0
        sta (dst),y
        inc dst
        bne r
        inc dst+1
r       rts
.)


#include "helptab.msg"         ; textes et clés, en français ou en anglais (progs/msg/fr, en)

buf                             ; texte décodé (jusqu'à ~19 Ko, bien sous la TPA)
