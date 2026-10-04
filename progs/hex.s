; =====================================================================
;  HEX.COM — visualiseur et éditeur hexadécimal de fichiers pour CP/A
;
;  HEX fichier
;
;  Le fichier est lu par fenêtres en accès direct (BDOS 33-35) : un
;  fichier qui tient en mémoire est lu d'un coup, un plus gros est
;  parcouru par morceaux (jusqu'à 64 Ko). Les octets modifiés sont
;  réécrits sur place, enregistrement par enregistrement ; quitter une
;  fenêtre modifiée l'écrit. Sa taille est un nombre d'enregistrements
;  de 128 octets, comme sous CP/M. L'écran montre 26 lignes de 8 octets :
;
;     OOOO XX XX XX XX XX XX XX XX ........
;
;  On modifie les octets en hexadécimal ou en ASCII (^O bascule) ; la
;  taille du fichier ne change jamais. ^S écrit les modifications.
;
;  Touches : flèches, RETURN (ligne suivante), DEL (recule),
;    ^R / ^C page précédente / suivante, ^Q début, ^Z fin,
;    ^A aller à une adresse, ^F chercher (texte, ou #41 42 en hexa),
;    ^G occurrence suivante, ^O mode HEX/ASCII, ^S enregistrer,
;    ESC quitter. FUNCT ouvre les menus.
; =====================================================================

#include "cpa.inc"

ROWS    = 26            ; lignes de données (écran lignes 1 à 26)
PAGE    = 208           ; ROWS*8 octets par écran
STROW   = 27            ; ligne d'état
WIDTH   = 38
MAXIN   = 30
CR      = $0D

; --- page zéro ---
pos     = $10           ; position du curseur dans le fichier
top     = $12           ; position de la première ligne affichée
size    = $14           ; taille du fichier en mémoire
lim     = $16           ; fin de la mémoire utilisable
ptr     = $18
t0      = $1A
t1      = $1C
scr     = $1E
msgp    = $20           ; message de la ligne d'état (0 = aucun)
src     = $22
s0      = $24           ; recherche
off     = $26           ; affichage
askp    = $28
nib     = $2A           ; 1 = demi-octet fort déjà saisi
mode    = $2B           ; 0 = HEX, 1 = ASCII
modif   = $2C
rdonly  = $2D
wassplit = $2E
rr      = $2F
bi      = $30
hy      = $31
ay      = $32
curi    = $33
mh      = $34           ; masques de vidéo inverse
ml      = $35
ma      = $36
tmpb    = $37
inlen   = $38
spos    = $39
jj      = $3A
patlen  = $3B
pathex  = $3C
cnt     = $3D
wbase   = $40           ; fenêtre : début (décalage dans le fichier)
wlen    = $42           ;           longueur en octets (multiple de 128)
wmax    = $44           ; taille maximale de la fenêtre
dlo     = $46           ; enregistrements modifiés : premier, dernier
dhi     = $48
dirtyw  = $4A           ; 1 = la fenêtre a des modifications
elen    = $4B           ; longueur demandée à ensure
big     = $4C           ; 1 = fichier de plus de 64 Ko

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
.(
        cld
        lda FCB1+1              ; un nom de fichier est obligatoire
        cmp #" "
        bne arg
        lda #<m_usage
        ldy #>m_usage
        jmp fatal
arg     ldx #11
cp      lda FCB1,x
        sta fcb_main,x
        dex
        bpl cp
        lda #0                  ; mémoire : jusqu'au haut de la TPA
        sta lim                 ; ($A000 en SPLIT : l'image est gardée)
        lda TPA_TOP+1
        sta lim+1
        jsr load_file
        bcc ok
        lda #<m_nofile
        ldy #>m_nofile
        jmp fatal
ok      lda size
        ora size+1
        bne full
        lda #<m_empty
        ldy #>m_empty
        jmp fatal
full    ldx #F_GFX              ; lancé depuis le mode SPLIT ?
        lda #<gq_get
        ldy #>gq_get
        jsr BDOS
        sta wassplit
        beq txt
        ldx #F_GFX              ; oui : texte plein écran le temps de l'édition
        lda #<gq_text
        ldy #>gq_text
        jsr BDOS
txt     lda #<SCREEN            ; adresses des lignes de l'écran
        sta t0
        lda #>SCREEN
        sta t0+1
        ldx #0
tl      lda t0
        sta row_lo,x
        lda t0+1
        sta row_hi,x
        clc
        lda t0
        adc #40
        sta t0
        bcc tl1
        inc t0+1
tl1     inx
        cpx #28
        bne tl
        lda #<hx_bar
        ldy #>hx_bar
        jsr B_MENUBAR
        ldx #F_CONOUT           ; efface l'écran
        lda #$0C
        jsr BDOS
        jsr cur_hide
        lda #$14                ; ligne d'état : papier bleu, encre blanche
        sta SCREEN+STROW*40
        lda #$07
        sta SCREEN+STROW*40+1
        lda #0
        sta pos
        sta pos+1
        sta top
        sta top+1
        sta nib
        sta mode
        sta modif
        sta msgp+1
        sta patlen
        lda big
        beq main
        lda #<m_trunc
        ldy #>m_trunc
        jsr set_msg
.)

; ---------------------------------------------------------------------
; Boucle principale
; ---------------------------------------------------------------------
main
        jsr B_CONST             ; d'autres touches attendent : on
        bne getk                ; n'affiche qu'à la fin de la rafale
        jsr render
getk    jsr B_CONIN
        ldx #0                  ; une touche efface le message
        stx msgp+1
        jsr dispatch
        jmp main

fatal   ldx #F_PRINT
        jsr BDOS
        jmp WBOOT

; dispatch : A = touche ou code de menu ($81-$89)
dispatch
.(
        cmp #$81
        bcs menu
        cmp #$7F
        beq dl
        cmp #$20
        bcs ch
        tax
        lda cvec_hi,x
        pha
        lda cvec_lo,x
        pha
        rts
menu    cmp #$8A
        bcs none
        sec
        sbc #$81
        tax
        lda mvec_hi,x
        pha
        lda mvec_lo,x
        pha
none    rts
dl      jmp k_left
ch      jmp k_char
.)

cvec_lo .byt <(k_none-1),<(k_goto-1),<(k_none-1),<(k_pgdn-1),<(k_none-1),<(k_none-1),<(k_find-1),<(k_next-1)
        .byt <(k_left-1),<(k_right-1),<(k_down-1),<(k_up-1),<(k_none-1),<(k_cr-1),<(k_none-1),<(k_mode-1)
        .byt <(k_none-1),<(k_top-1),<(k_pgup-1),<(k_save-1),<(k_none-1),<(k_none-1),<(k_none-1),<(k_none-1)
        .byt <(k_none-1),<(k_none-1),<(k_bot-1),<(k_quit-1),<(k_none-1),<(k_none-1),<(k_none-1),<(k_none-1)
cvec_hi .byt >(k_none-1),>(k_goto-1),>(k_none-1),>(k_pgdn-1),>(k_none-1),>(k_none-1),>(k_find-1),>(k_next-1)
        .byt >(k_left-1),>(k_right-1),>(k_down-1),>(k_up-1),>(k_none-1),>(k_cr-1),>(k_none-1),>(k_mode-1)
        .byt >(k_none-1),>(k_top-1),>(k_pgup-1),>(k_save-1),>(k_none-1),>(k_none-1),>(k_none-1),>(k_none-1)
        .byt >(k_none-1),>(k_none-1),>(k_bot-1),>(k_quit-1),>(k_none-1),>(k_none-1),>(k_none-1),>(k_none-1)
mvec_lo .byt <(k_save-1),<(k_reload-1),<(k_quit-1),<(k_top-1),<(k_bot-1),<(k_goto-1),<(k_find-1),<(k_next-1),<(k_mode-1)
mvec_hi .byt >(k_save-1),>(k_reload-1),>(k_quit-1),>(k_top-1),>(k_bot-1),>(k_goto-1),>(k_find-1),>(k_next-1),>(k_mode-1)

k_none  rts

; ---------------------------------------------------------------------
; Déplacements
; ---------------------------------------------------------------------
k_left
        lda pos
        ora pos+1
        beq mv_r
        lda pos
        bne kl1
        dec pos+1
kl1     dec pos
        jmp moved

k_right
        lda #1
        bne add_pos
k_down
        lda #8
add_pos clc                     ; t0 = pos + A, accepté si < taille
        adc pos
        sta t0
        lda pos+1
        adc #0
        sta t0+1
chk_set lda t0
        cmp size
        lda t0+1
        sbc size+1
        bcs mv_r
set_pos lda t0
        sta pos
        lda t0+1
        sta pos+1
moved   lda #0
        sta nib
        jmp fix_top
mv_r    lda #0
        sta nib
        rts

k_up
        lda pos+1
        bne ku1
        lda pos
        cmp #8
        bcc mv_r
ku1     sec
        lda pos
        sbc #8
        sta pos
        bcs moved
        dec pos+1
        jmp moved

k_cr                            ; début de la ligne suivante
        lda pos
        and #$F8
        clc
        adc #8
        sta t0
        lda pos+1
        adc #0
        sta t0+1
        jmp chk_set

k_top
        lda #0
        sta pos
        sta pos+1
        sta top
        sta top+1
        jmp moved

k_bot
        sec
        lda size
        sbc #1
        sta t0
        lda size+1
        sbc #0
        sta t0+1
        jmp set_pos

k_pgdn
.(
        clc
        lda top
        adc #PAGE
        sta top
        bcc p1
        inc top+1
p1      clc
        lda pos
        adc #PAGE
        sta t0
        lda pos+1
        adc #0
        sta t0+1
        lda t0
        cmp size
        lda t0+1
        sbc size+1
        bcc p2
        jmp k_bot
p2      jmp set_pos
.)

k_pgup
.(
        sec
        lda top
        sbc #PAGE
        sta top
        lda top+1
        sbc #0
        sta top+1
        bcs p1
        lda #0
        sta top
        sta top+1
p1      sec
        lda pos
        sbc #PAGE
        sta t0
        lda pos+1
        sbc #0
        sta t0+1
        bcs p2
        lda #0
        sta t0
        sta t0+1
p2      jmp set_pos
.)

; fix_top : ajuste la première ligne affichée pour que le curseur soit
; visible et que l'écran ne dépasse pas la fin du fichier
fix_top
.(
        sec                     ; t1 = début de la dernière ligne - 25 lignes
        lda size
        sbc #1
        and #$F8
        sta t1
        lda size+1
        sbc #0
        sta t1+1
        sec
        lda t1
        sbc #PAGE-8
        sta t1
        lda t1+1
        sbc #0
        sta t1+1
        bcs m1
        lda #0
        sta t1
        sta t1+1
m1      lda t1                  ; top > t1 : top = t1
        cmp top
        lda t1+1
        sbc top+1
        bcs m2
        lda t1
        sta top
        lda t1+1
        sta top+1
m2      lda pos                 ; pos < top : top = début de la ligne
        cmp top
        lda pos+1
        sbc top+1
        bcs m3
        lda pos
        and #$F8
        sta top
        lda pos+1
        sta top+1
        rts
m3      clc                     ; pos >= top + PAGE : ligne du curseur en bas
        lda top
        adc #PAGE
        sta t1
        lda top+1
        adc #0
        sta t1+1
        lda pos
        cmp t1
        lda pos+1
        sbc t1+1
        bcc r
        lda pos
        and #$F8
        sec
        sbc #PAGE-8
        sta top
        lda pos+1
        sbc #0
        sta top+1
r       rts
.)

k_mode
        lda mode
        eor #1
        sta mode
        lda #0
        sta nib
        rts

; ---------------------------------------------------------------------
; Modification d'un octet
; ---------------------------------------------------------------------
k_char
.(
        ldx rdonly
        beq w
        lda #<m_ro
        ldy #>m_ro
        jmp set_msg
w       pha
        jsr pos_ptr
        pla
        ldx mode
        beq hx
        ldy #0                  ; ASCII : l'octet prend le code du caractère
        sta (ptr),y
        jmp chg_next
hx      jsr hexval
        bcs r
        ldy #0
        ldx nib
        bne lo
        asl                     ; premier chiffre : demi-octet fort
        asl
        asl
        asl
        sta tmpb
        lda (ptr),y
        and #$0F
        ora tmpb
        sta (ptr),y
        lda #1
        sta nib
        sta modif
        jmp mark_dirty
r       rts
lo      sta tmpb                ; second chiffre : demi-octet faible
        lda (ptr),y
        and #$F0
        ora tmpb
        sta (ptr),y
chg_next
        lda #1
        sta modif
        jsr mark_dirty
        jmp k_right
.)

; pos_ptr : ptr = adresse de l'octet pos (fenêtre chargée si besoin)
pos_ptr
        lda pos
        sta t0
        lda pos+1
        sta t0+1
        lda #1
        jmp ensure

; ensure : l'octet t0 et les A-1 suivants doivent être dans la fenêtre.
; ptr = leur adresse en mémoire. Préserve t0.
ensure
.(
        sta elen
        lda t0                  ; t0 >= wbase ?
        cmp wbase
        lda t0+1
        sbc wbase+1
        bcc load
        clc                     ; t0 + elen <= wbase + wlen ?
        lda t0
        adc elen
        sta t1
        lda t0+1
        adc #0
        sta t1+1
        clc
        lda wbase
        adc wlen
        tax
        lda wbase+1
        adc wlen+1
        cmp t1+1
        bcc load
        bne in
        cpx t1
        bcc load
in      sec                     ; ptr = BUF + t0 - wbase
        lda t0
        sbc wbase
        sta ptr
        lda t0+1
        sbc wbase+1
        sta ptr+1
        clc
        lda ptr
        adc #<BUF
        sta ptr
        lda ptr+1
        adc #>BUF
        sta ptr+1
        rts
load    jsr flush_win
        lda t0                  ; début : t0 arrondi, moins une demi-fenêtre
        and #$80
        sta wbase
        lda t0+1
        sta wbase+1
        lda wmax+1              ; demi-fenêtre (multiple de 256)
        lsr
        sta t1+1
        sec
        lda wbase+1
        sbc t1+1
        sta wbase+1
        bcs b1
        lda #0
        sta wbase
        sta wbase+1
b1      sec                     ; wlen = min(wmax, taille - wbase)
        lda size
        sbc wbase
        sta wlen
        lda size+1
        sbc wbase+1
        sta wlen+1
        lda wlen
        cmp wmax
        lda wlen+1
        sbc wmax+1
        bcc b2
        lda wmax                ; la fenêtre déborde : on la recule
        sta wlen
        lda wmax+1
        sta wlen+1
b2      jsr read_win
        jmp in
.)

; read_win : lit wlen octets depuis wbase en BUF (lecture directe)
read_win
.(
        lda #<BUF
        sta ptr
        lda #>BUF
        sta ptr+1
        lda wbase               ; numéro d'enregistrement = wbase / 128
        asl
        lda wbase+1
        rol
        sta fcb_main+FCB_R0
        lda #0
        rol
        sta fcb_main+FCB_R0+1
        lda wlen                ; nombre d'enregistrements
        asl
        lda wlen+1
        rol
        sta cnt
loop    lda cnt
        beq done
        ldy #127                ; un enregistrement absent se lit comme des 0
        lda #0
z       sta (ptr),y
        dey
        bpl z
        ldx #F_SETDMA
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #F_RREAD
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        clc
        lda ptr
        adc #128
        sta ptr
        bcc p1
        inc ptr+1
p1      inc fcb_main+FCB_R0
        bne p2
        inc fcb_main+FCB_R0+1
p2      dec cnt
        jmp loop
done    jmp dma_def
.)

; mark_dirty : l'enregistrement de pos est modifié
mark_dirty
.(
        lda pos                 ; r = pos / 128
        asl
        lda pos+1
        rol
        tax
        lda #0
        rol
        tay
        lda dirtyw
        bne more
        stx dlo
        sty dlo+1
        stx dhi
        sty dhi+1
        lda #1
        sta dirtyw
        rts
more    cpx dlo                 ; r < dlo ?
        tya
        sbc dlo+1
        bcs n1
        stx dlo
        sty dlo+1
n1      lda dhi                 ; r > dhi ?
        stx t1
        cmp t1
        sty t1
        lda dhi+1
        sbc t1
        bcs n2
        stx dhi
        sty dhi+1
n2      rts
.)

; flush_win : réécrit les enregistrements modifiés de la fenêtre
flush_win
.(
        lda dirtyw
        bne go
        rts
go      lda #0
        sta dirtyw
        lda dlo
        sta fcb_main+FCB_R0
        lda dlo+1
        sta fcb_main+FCB_R0+1
        lda #0
        sta fcb_main+FCB_R0+2
loop    lda fcb_main+FCB_R0+1   ; adresse = BUF + r * 128 - wbase
        lsr                     ; r * 128 = r * 256 / 2
        lda fcb_main+FCB_R0
        ror
        sta t1+1
        lda #0
        ror
        sta t1
        sec
        lda t1
        sbc wbase
        sta t1
        lda t1+1
        sbc wbase+1
        sta t1+1
        clc
        lda t1
        adc #<BUF
        tax
        lda t1+1
        adc #>BUF
        tay
        txa
        ldx #F_SETDMA
        jsr BDOS
        ldx #F_RWRITE
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #0
        bne err
        lda fcb_main+FCB_R0     ; enregistrement suivant
        cmp dhi
        bne nx
        lda fcb_main+FCB_R0+1
        cmp dhi+1
        beq done
nx      inc fcb_main+FCB_R0
        bne loop
        inc fcb_main+FCB_R0+1
        jmp loop
done    jsr dma_def
        lda modif               ; écrit sans ^S : on le signale
        beq r
        lda #<m_written
        ldy #>m_written
        jsr set_msg
r       rts
err     jsr dma_def
        lda #<m_dfull
        ldy #>m_dfull
        jmp set_msg
.)

; hexval : caractère A -> valeur 0-15 (C=0), sinon C=1
hexval
.(
        cmp #"0"
        bcc bad
        cmp #"9"+1
        bcc dig
        and #$DF
        cmp #"A"
        bcc bad
        cmp #"F"+1
        bcs bad
        sbc #"A"-11             ; C=0 : A - "A" + 10
        clc
        rts
dig     sbc #"0"-1              ; C=0 : A - "0"
        clc
        rts
bad     sec
        rts
.)

upc
        cmp #"a"
        bcc up_r
        cmp #"z"+1
        bcs up_r
        and #$DF
up_r    rts

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
render
.(
        lda top                 ; la fenêtre doit couvrir l'écran
        sta t0
        lda top+1
        sta t0+1
        sec                     ; longueur : min(208, taille - top)
        lda size
        sbc top
        tax
        lda size+1
        sbc top+1
        bne full
        cpx #PAGE
        bcc part
full    ldx #PAGE
part    txa
        jsr ensure
        lda top
        sta off
        lda top+1
        sta off+1
        lda #0
        sta rr
row     ldx rr
        inx
        lda row_lo,x
        sta scr
        lda row_hi,x
        sta scr+1
        lda off                 ; ligne au-delà de la fin ?
        cmp size
        lda off+1
        sbc size+1
        bcc data
        ldy #2
        lda #" "
blank   sta (scr),y
        iny
        cpy #40
        bne blank
        jmp next
data    lda #0
        sta mh
        sta ml
        ldy #2                  ; adresse dans le fichier
        lda off+1
        jsr hex2out
        lda off
        jsr hex2out
        lda #" "
        sta (scr),y
        lda #$FF                ; curi = index du curseur dans la ligne
        sta curi
        sec
        lda pos
        sbc off
        tax
        lda pos+1
        sbc off+1
        bne nocur
        cpx #8
        bcs nocur
        stx curi
nocur   sec                     ; ptr = BUF + off - wbase
        lda off
        sbc wbase
        sta ptr
        lda off+1
        sbc wbase+1
        sta ptr+1
        clc
        lda ptr
        adc #<BUF
        sta ptr
        lda ptr+1
        adc #>BUF
        sta ptr+1
        lda #7
        sta hy
        lda #31
        sta ay
        lda #0
        sta bi
octet   clc                     ; off + bi < taille ?
        lda off
        adc bi
        tax
        lda off+1
        adc #0
        sta tmpb
        cpx size
        lda tmpb
        sbc size+1
        bcc have
        ldy hy                  ; au-delà de la fin : blancs
        lda #" "
        sta (scr),y
        iny
        sta (scr),y
        ldy ay
        sta (scr),y
        jmp bnext
have    lda #0
        sta mh
        sta ml
        sta ma
        lda bi
        cmp curi
        bne nohl
        lda #$80                ; octet du curseur, en vidéo inverse
        ldx mode                ; dans la zone active
        bne hla
        sta ml
        ldx nib
        bne nohl
        sta mh
        jmp nohl
hla     sta ma
nohl    ldy bi
        lda (ptr),y
        pha
        ldy hy
        jsr hex2out
        pla
        cmp #$20
        bcc dot
        cmp #$7F
        bcc pr
dot     lda #"."
pr      ora ma
        ldy ay
        sta (scr),y
bnext   ldy hy                  ; espace après la paire
        iny
        iny
        lda #" "
        sta (scr),y
        iny
        sty hy
        inc ay
        inc bi
        lda bi
        cmp #8
        bne octet
        ldy #39
        lda #" "
        sta (scr),y
next    clc
        lda off
        adc #8
        sta off
        bcc n1
        inc off+1
n1      inc rr
        lda rr
        cmp #ROWS
        beq st
        jmp row
st      jmp draw_status
.)

; hex2out : A en deux chiffres en (scr),y et y+1 (masques mh/ml), Y += 2
hex2out
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda hexd,x
        ora mh
        sta (scr),y
        iny
        pla
        and #$0F
        tax
        lda hexd,x
        ora ml
        sta (scr),y
        iny
        rts

; --- curseur du système : caché pendant toute l'édition ---
cur_hide
.(
        php
        sei
        lda #0
        sta CON_CUREN
        lda CON_CURVIS
        beq r
        ldx CON_CURY
        lda row_lo,x
        sta t0
        lda row_hi,x
        sta t0+1
        ldy CON_CURX
        lda (t0),y
        eor #$80
        sta (t0),y
        lda #0
        sta CON_CURVIS
r       plp
        rts
.)

; ---------------------------------------------------------------------
; Ligne d'état :  NOM.EXT*      $pppp/$tttt =XX ddd HEX
; ---------------------------------------------------------------------
st_clear
        ldy #WIDTH-1
        lda #" "
stc     sta stline,y
        dey
        bpl stc
        rts

st_flush
        ldy #WIDTH-1
stf     lda stline,y
        sta SCREEN+STROW*40+2,y
        dey
        bpl stf
        rts

; st_puts : chaîne (src) copiée en stline à partir de Y
st_puts
.(
        sty tmpb
        ldy #0
loop    lda (src),y
        beq end
        sty jj
        ldy tmpb
        cpy #WIDTH
        bcs end
        sta stline,y
        inc tmpb
        ldy jj
        iny
        bne loop
end     ldy tmpb
        rts
.)

; st_hex : A en deux chiffres en stline,y ; Y += 2
st_hex
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda hexd,x
        sta stline,y
        iny
        pla
        and #$0F
        tax
        lda hexd,x
        sta stline,y
        iny
        rts

set_msg
        sta msgp
        sty msgp+1
        rts

draw_status
.(
        jsr st_clear
        lda msgp+1
        beq info
        lda msgp
        sta src
        lda msgp+1
        sta src+1
        ldy #0
        jsr st_puts
        jmp st_flush
info    ldy #0                  ; NOM.EXT sans les espaces
        ldx #1
nm      lda fcb_main,x
        and #$7F
        cmp #" "
        beq dot
        sta stline,y
        iny
        inx
        cpx #9
        bne nm
dot     lda #"."
        sta stline,y
        iny
        ldx #9
ext     lda fcb_main,x
        and #$7F
        cmp #" "
        beq ed
        sta stline,y
        iny
        inx
        cpx #12
        bne ext
ed      lda modif
        beq pp
        lda #"*"
        sta stline,y
pp      ldy #14                 ; position / taille
        lda #"$"
        sta stline,y
        iny
        lda pos+1
        jsr st_hex
        lda pos
        jsr st_hex
        lda #"/"
        sta stline,y
        iny
        lda #"$"
        sta stline,y
        iny
        lda size+1
        jsr st_hex
        lda size
        jsr st_hex
        jsr pos_ptr             ; octet courant en hexa et en décimal
        ldy #0
        lda (ptr),y
        sta tmpb
        ldy #26
        lda #"="
        sta stline,y
        iny
        lda tmpb
        jsr st_hex
        lda tmpb
        ldx #"0"-1
        sec
dh      inx
        sbc #100
        bcs dh
        adc #100
        stx stline+30
        ldx #"0"-1
        sec
dt      inx
        sbc #10
        bcs dt
        adc #10+"0"
        stx stline+31
        sta stline+32
        lda stline+30           ; zéros de tête en blanc
        cmp #"0"
        bne mds
        lda #" "
        sta stline+30
        lda stline+31
        cmp #"0"
        bne mds
        lda #" "
        sta stline+31
mds     ldx #0                  ; mode
        lda rdonly
        beq md
        ldx #8
        bne mc
md      lda mode
        beq mc
        ldx #4
mc      ldy #34
mcl     lda m_modes,x
        sta stline,y
        inx
        iny
        cpy #38
        bne mcl
        jmp st_flush
.)

; ---------------------------------------------------------------------
; Questions sur la ligne d'état
; ---------------------------------------------------------------------
; ask : question A/Y, saisie dans inbuf/inlen. C=1 si ESC.
ask
.(
        sta askp
        sty askp+1
        lda #0
        sta inlen
redraw  jsr st_clear
        lda askp
        sta src
        lda askp+1
        sta src+1
        ldy #0
        jsr st_puts
        sty spos
        ldx #0
il      cpx inlen
        beq ieol
        lda inbuf,x
        sta stline,y
        iny
        inx
        bne il
ieol    cpy #WIDTH
        bcs nc
        lda #$A0                ; curseur : espace en vidéo inverse
        sta stline,y
nc      jsr st_flush
key     jsr B_CONIN
        cmp #CR
        beq ok
        cmp #$1B
        beq esc
        cmp #$7F
        beq bs
        cmp #$08
        beq bs
        cmp #" "
        bcc key
        cmp #$7F
        bcs key
        ldx inlen
        cpx #MAXIN
        bcs key
        pha
        txa
        clc
        adc spos
        cmp #WIDTH-1
        pla
        bcs key
        sta inbuf,x
        inc inlen
        jmp redraw
bs      lda inlen
        beq key
        dec inlen
        jmp redraw
ok      clc
        rts
esc     sec
        rts
.)

; ask_yn : question A/Y, C=1 si la réponse est O (ou Y)
ask_yn
.(
        sta src
        sty src+1
        jsr st_clear
        ldy #0
        jsr st_puts
        jsr st_flush
        jsr B_CONIN
        jsr upc
        cmp #"O"
        beq yes
        cmp #"Y"
        beq yes
        clc
        rts
yes     sec
        rts
.)

; ---------------------------------------------------------------------
; Aller à une adresse (hexadécimale)
; ---------------------------------------------------------------------
k_goto
.(
        lda #<q_goto
        ldy #>q_goto
        jsr ask
        bcs r
        lda #0
        sta t0
        sta t0+1
        sta cnt
        ldx #0
loop    cpx inlen
        beq done
        lda inbuf,x
        inx
        cmp #"$"
        beq loop
        cmp #" "
        beq loop
        jsr hexval
        bcs bad
        ldy #4
sh      asl t0
        rol t0+1
        dey
        bne sh
        ora t0
        sta t0
        inc cnt
        jmp loop
done    lda cnt
        beq r
        lda t0                  ; au-delà de la fin : dernier octet
        cmp size
        lda t0+1
        sbc size+1
        bcc ok
        jmp k_bot
ok      jmp set_pos
bad     lda #<m_badhex
        ldy #>m_badhex
        jmp set_msg
r       rts
.)

; ---------------------------------------------------------------------
; Recherche : texte (majuscules = minuscules) ou #hexa (41 42 ou 4142)
; ---------------------------------------------------------------------
k_find
.(
        lda #<q_find
        ldy #>q_find
        jsr ask
        bcc gotin
        rts
gotin   lda inlen
        bne some
        rts
some
        lda #0
        sta patlen
        sta pathex
        lda inbuf
        cmp #"#"
        beq hexp
        ldx #0
cp      lda inbuf,x
        sta pat,x
        inx
        cpx inlen
        bne cp
        stx patlen
        jmp k_next
hexp    lda #1
        sta pathex
        lda #0
        sta cnt                 ; 1 = un chiffre en attente dans tmpb
        ldx #1
pl      cpx inlen
        beq pend
        lda inbuf,x
        inx
        cmp #" "
        beq flush
        jsr hexval
        bcs bad
        ldy cnt
        bne second
        sta tmpb
        inc cnt
        jmp pl
second  sta jj
        lda tmpb
        asl
        asl
        asl
        asl
        ora jj
        jsr addpat
        jmp pl
flush   lda cnt
        beq pl
        lda tmpb
        jsr addpat
        jmp pl
pend    lda cnt
        beq fin
        lda tmpb
        jsr addpat
fin     lda patlen
        beq bad
        jmp k_next
bad     lda #0
        sta patlen
        lda #<m_badpat
        ldy #>m_badpat
        jmp set_msg
r       rts
addpat  ldy patlen
        sta pat,y
        inc patlen
        lda #0
        sta cnt
        rts
.)

k_next
.(
        lda patlen
        bne go
        jmp k_find
go      clc                     ; à partir de l'octet qui suit le curseur
        lda pos
        adc #1
        sta s0
        lda pos+1
        adc #0
        sta s0+1
        jsr search
        bcc found
        lda #0                  ; puis depuis le début
        sta s0
        sta s0+1
        jsr search
        bcs nf
        lda #<m_wrap
        ldy #>m_wrap
        jsr set_msg
found   lda s0
        sta t0
        lda s0+1
        sta t0+1
        jmp set_pos
nf      lda #<m_notf
        ldy #>m_notf
        jmp set_msg
.)

; search : cherche pat à partir de s0. C=0 trouvé (en s0), C=1 sinon
search
.(
loop    clc                     ; s0 + patlen > taille : fini
        lda s0
        adc patlen
        sta t1
        lda s0+1
        adc #0
        sta t1+1
        lda size
        cmp t1
        lda size+1
        sbc t1+1
        bcc nf
        lda s0
        sta t0
        lda s0+1
        sta t0+1
        lda patlen
        jsr ensure
        ldy #0
cmpl    lda (ptr),y
        ldx pathex
        bne raw
        jsr upc
        sta tmpb
        lda pat,y
        jsr upc
        cmp tmpb
        bne miss
        beq nxt
raw     cmp pat,y
        bne miss
nxt     iny
        cpy patlen
        bne cmpl
        clc
        rts
miss    inc s0
        bne loop
        inc s0+1
        jmp loop
nf      sec
        rts
.)

; ---------------------------------------------------------------------
; Fichier
; ---------------------------------------------------------------------
; load_file : ouvre fcb_main et lit sa taille. C=1 si le fichier n'existe
; pas. La fenêtre est vide : elle se remplit au premier affichage.
load_file
.(
        ldx #12
        lda #0
z       sta fcb_main,x
        inx
        cpx #36
        bne z
        ldx #F_OPEN
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #$FF
        bne opened
        sec
        rts
opened  ldx #F_FSIZE
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        lda #0
        sta big
        sta rdonly
        sta dirtyw
        sta wbase
        sta wbase+1
        sta wlen
        sta wlen+1
        lda fcb_main+FCB_R0+1   ; 512 enregistrements ou plus : 64 Ko max
        cmp #2
        bcc small
        lda #1
        sta big
        lda #$FF
        sta fcb_main+FCB_R0
        lda #1
        sta fcb_main+FCB_R0+1
small   lda fcb_main+FCB_R0     ; taille = enregistrements * 128
        lsr fcb_main+FCB_R0+1
        ror
        sta size+1
        lda #0
        ror
        sta size
        sec                     ; fenêtre maximale : la mémoire libre
        lda lim
        sbc #<BUF
        and #$80
        sta wmax
        lda lim+1
        sbc #>BUF
        sta wmax+1
        cmp #$80                ; 32 Ko au plus (255 enregistrements)
        bcc wm
        lda #$7F
        sta wmax+1
        lda #$80
        sta wmax
wm      clc
        rts
.)

dma_def
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS

k_reload
.(
        lda modif
        beq go
        lda #<q_lose
        ldy #>q_lose
        jsr ask_yn
        bcc r
go      lda #0                  ; les modifications non écrites sont perdues
        sta dirtyw
        jsr load_file
        bcc ok
        lda #<m_nof2
        ldy #>m_nof2
        jmp set_msg
ok      lda #0
        sta modif
        sta nib
        lda pos                 ; le curseur reste dans le fichier
        cmp size
        lda pos+1
        sbc size+1
        bcc in
        jmp k_bot
in      lda #<m_reload
        ldy #>m_reload
        jsr set_msg
        jmp fix_top
r       rts
.)

; k_save : réécrit sur place les enregistrements modifiés
k_save
.(
        lda fcb_main+13         ; fichier protégé (R/O)
        bpl rw
        lda #<m_prot
        ldy #>m_prot
        jmp set_msg
rw      lda #0                  ; pas de message « écrit sans ^S »
        sta modif
        jsr flush_win
        ldx #F_CLOSE
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        lda msgp+1              ; erreur signalée par flush_win ?
        bne r
        lda #<m_saved
        ldy #>m_saved
        jmp set_msg
r       rts
.)


k_quit
.(
        lda modif
        beq go
        lda #<q_quit
        ldy #>q_quit
        jsr ask_yn
        bcc r
go      lda wassplit
        beq cls
        ldx #F_GFX              ; retour au mode SPLIT avec l'image intacte
        lda #<gq_split
        ldy #>gq_split
        jsr BDOS
        jmp WBOOT
cls     ldx #F_CONOUT
        lda #$0C
        jsr BDOS
        jmp WBOOT               ; réinstalle la barre de menus du système
r       rts
.)

; ---------------------------------------------------------------------
; Menus
; ---------------------------------------------------------------------
hx_bar  .byt 3
        .word mn_fic, mn_all, mn_mod

mn_fic  .byt 3,14
        .asc "Fichier",0
        .asc "Enregistrer ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Recharger",0
        .byt MA_TYPE
        .word c_reload
        .asc "Quitter  ESC",0
        .byt MA_TYPE
        .word c_quit

mn_all  .byt 5,13
        .asc "Aller",0
        .asc "Debut      ^Q",0
        .byt MA_TYPE
        .word c_top
        .asc "Fin        ^Z",0
        .byt MA_TYPE
        .word c_bot
        .asc "Adresse... ^A",0
        .byt MA_TYPE
        .word c_goto
        .asc "Chercher.. ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Suivant    ^G",0
        .byt MA_TYPE
        .word c_next

mn_mod  .byt 1,12
        .asc "Mode",0
        .asc "Hex/ASCII ^O",0
        .byt MA_TYPE
        .word c_mode

c_save   .byt $81,0
c_reload .byt $82,0
c_quit   .byt $83,0
c_top    .byt $84,0
c_bot    .byt $85,0
c_goto   .byt $86,0
c_find   .byt $87,0
c_next   .byt $88,0
c_mode   .byt $89,0

gq_get   .byt G_GETMODE,0,0,0,0,0
gq_text  .byt G_MODE,0,0,0,0,0
gq_split .byt G_MODE,2,0,0,0,0

; ---------------------------------------------------------------------
; Messages
; ---------------------------------------------------------------------
m_usage   .asc "Usage : HEX fichier",13,10,"$"
m_nofile  .asc "Fichier introuvable",13,10,"$"
m_empty   .asc "Fichier vide",13,10,"$"
m_nof2    .asc "Fichier introuvable",0
m_trunc   .asc "Plus de 64 Ko : debut seulement",0
m_written .asc "Modifications ecrites",0
m_ro      .asc "Lecture seule (fichier tronque)",0
m_saved   .asc "Enregistre",0
m_prot    .asc "Fichier protege (R/O)",0
m_reload  .asc "Fichier relu",0
m_dirfull .asc "Repertoire plein",0
m_dfull   .asc "Disque plein : non enregistre",0
m_badhex  .asc "Adresse incorrecte",0
m_badpat  .asc "Motif incorrect",0
m_notf    .asc "Introuvable",0
m_wrap    .asc "Trouve en repartant du debut",0
q_goto    .asc "Adresse (hexa) : ",0
q_find    .asc "Chercher (texte ou #hexa) : ",0
q_lose    .asc "Abandonner les modifs (O/N) ?",0
q_quit    .asc "Fichier modifie. Quitter (O/N) ?",0
m_modes   .asc "HEX ASC LECT"
hexd      .asc "0123456789ABCDEF"

row_lo  .dsb 28,0
row_hi  .dsb 28,0
inbuf   .dsb MAXIN+2,0
pat     .dsb MAXIN+2,0
stline  .dsb WIDTH,0
fcb_main .dsb 36,0
recbuf  .dsb 128,0

        .dsb (*+255)/256*256-*,0
BUF                             ; le fichier : BUF à BUF+size
