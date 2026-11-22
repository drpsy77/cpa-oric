; =====================================================================
;  HELP.COM — aide de CP/A
;
;  HELP              la liste des pages
;  HELP mot          la page du mot : une commande (HELP COPY, HELP DIS)
;                    ou un sujet (HELP TOUCHES, HELP USB)
;  HELP GRAPHER mot  la page d'un mot du vocabulaire de GRAPHER (HELP
;  HELP LOGO mot     GRAPHER PLOT), de LOGO (HELP LOGO REPETE)
;  Le mot entier est cherché d'abord, puis le premier mot de la table
;  qui commence ainsi (HELP ED : EDIT). Un mot absent de la table où on
;  le cherche (mots généraux, ou vocabulaire de la page du premier mot) :
;  « Mot inconnu dans ce contexte », puis la page où l'on en est.
;  Les textes et les tables des mots viennent de
;  tools/gen_readme_txt.py (helptab.msg, dans progs/msg/fr et
;  progs/msg/en), comme README.TXT. Les textes sont compressés par lots
;  de pages (LZSS, format de tools/lzhir.py) : unz décode le lot de la
;  page dans le tampon buf, qui suit le programme, du début du lot
;  jusqu'à la fin de la page demandée.
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
stop    = $20           ; fin de la page dans buf
pass    = $22           ; 0 : mot entier, 1 : début du mot
wp      = $23           ; mot cherché
k0      = $25           ; début de la table des mots

        *= $0500
start
.(
        lda #0
        sta idx
        lda #<FCB1+1            ; premier mot : les mots généraux
        ldy #>FCB1+1
        jsr word
        beq show                ; pas de mot : la liste des pages
        lda #<help_keys
        ldy #>help_keys
        jsr find
        bcs unknown
        sta idx
        lda #<FCB2+1            ; second mot : le vocabulaire de la page
        ldy #>FCB2+1
        jsr word
        beq show
        ldx #0
ctx     lda help_ctx,x
        bmi unknown             ; la page n'a pas de vocabulaire
        cmp idx
        beq voc
        inx
        inx
        inx
        bne ctx
voc     lda help_ctx+2,x
        tay
        lda help_ctx+1,x
        jsr find
        bcs unknown
        sta idx
        bcc show
unknown lda #<m_unknown
        ldy #>m_unknown
        jsr puts
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
        clc                     ; données compressées du lot de la page
        lda help_src,x
        adc #<hz_data
        sta src
        lda help_src+1,x
        adc #>hz_data
        sta src+1
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
.)

; word : A/Y = nom d'un FCB -> wp, wlen = sa longueur (jusqu'à un espace
;   ou un « ? », 8 au plus) ; Z=1 s'il est vide
word
.(
        sta wp
        sty wp+1
        ldy #0
len     lda (wp),y
        cmp #"!"                ; espace (ou 0 : FCB pas rempli)
        bcc lend
        cmp #"?"
        beq lend
        iny
        cpy #8
        bne len
lend    sty wlen
        cpy #0
        rts
.)

; find : cherche le mot (wp, wlen) dans la table A/Y (lettres, puis $80 +
;   page ; 0 à la fin) -> C=0, A = page ; C=1 : absent. Deux passes : le
;   mot entier, puis le premier mot de la table qui commence ainsi.
find
.(
        sta k0
        sty k0+1
        lda #0
        sta pass
again   lda k0
        sta key
        lda k0+1
        sta key+1
next    ldy #0
        lda (key),y
        beq endtab              ; fin de la table
cmp1    lda (key),y
        bmi kend                ; fin de la clé
        cpy wlen
        beq wend                ; fin du mot avant celle de la clé
        cmp (wp),y
        bne skip
        iny
        bne cmp1
kend    cpy wlen                ; clé finie : le mot aussi ?
        beq hit
        bne skip
wend    lda pass                ; début d'une clé : à la 2e passe
        beq skip
fend    iny
        lda (key),y
        bpl fend
hit     lda (key),y             ; $80 + numéro de la page
        and #$7F
        clc
        rts
skip    lda (key),y             ; clé suivante, après l'octet de fin
        bmi sk2
        iny
        bne skip
sk2     iny
        tya
        clc
        adc key
        sta key
        bcc next
        inc key+1
        bne next
endtab  lda pass
        bne fail
        inc pass
        bne again
fail    sec
        rts
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

; unz : décode le lot (src) dans buf jusqu'à stop (au moins).
; Groupes de 8 jetons précédés d'un octet de drapeaux lu à partir du bit 0 :
; 1 = littéral (1 octet), 0 = copie (distance 16 bits, longueur), source =
; position en cours moins la distance. Une copie peut dépasser stop :
; sans effet, la place après le texte est libre.
unz
.(
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

buf                             ; texte décodé : un lot (18 Ko au plus), sous $A000
