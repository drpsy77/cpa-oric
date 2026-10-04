; =====================================================================
;  gfx.s — mode SPLIT et primitives graphiques (BDOS fonction 115)
;
;  Mode SPLIT : lignes de points 0-127 en haute résolution (240 x 128),
;  puis du texte : barre de menus (ligne 16) et console (lignes 17 à 26).
;  Deux attributs suffisent, comme le HIRES du BASIC tout l'octet $A000
;  reste utilisable :
;     $1E en $BFDF : dernière case de l'écran (ligne de texte 27), passe
;                    en haute résolution pour la trame suivante. La ligne
;                    27 ne contient que des attributs : le vrai circuit
;                    change de mode à la ligne de points suivante, et ses 7
;                    dernières lignes de points seraient dessinées avec la
;                    police du mode HIRES ($9800, dans la TPA).
;     $1A en $B3D8 : première case de la ligne de points 127, retour au
;                    texte. Le vrai circuit vidéo ne change de mode qu'à
;                    la ligne suivante : placé sur la ligne 127, l'attribut
;                    agit pile à la ligne 128, première ligne de la barre.
;                    (Oricutron change de mode tout de suite : la fin de la
;                    ligne 127 montre alors la ligne de texte 15, vide.)
;  La ligne de texte 15 est gardée vide pour cette raison.
;  La police du mode texte ($B400) et l'écran texte ($BB80) restent en
;  place. La TPA s'arrête en $9FFF (tpa_top = $A000).
;
;  Appel : X = 115, A/Y = adresse d'un bloc  [op, p1, p2, p3, p4, p5]
;  Retour : A = 0 si OK, $FF si erreur (pas en mode SPLIT, op inconnue)
;     op 0  GCLS                     efface l'image
;     op 1  PEN    mode              0 efface, 1 trace, 2 inverse
;     op 2  PLOT   x, y              x 0-239, y 0-127
;     op 3  LINE   x1, y1, x2, y2
;     op 4  BOX    x1, y1, x2, y2    rectangle
;     op 5  FBOX   x1, y1, x2, y2    rectangle plein
;     op 6  CIRCLE x, y, r
;     op 7  TEXT   col, y, adr_lo, adr_hi   chaîne terminée par 0,
;                                    col = case 0-39 (6 points), y en points
;     op 8  ATTR   col, y1, y2, val  écrit un attribut (encre 0-7,
;                                    papier 16-23) dans une colonne de cases
;     op 9  POINT  x, y              -> A = 1 si le point est allumé
;     op 10 MODE   m                 0 texte, 1 SPLIT (image effacée),
;                                    2 SPLIT en gardant l'image
;     op 11 GETMODE                  -> A = 0 texte, 1 SPLIT
;     op 12 GSAVE  fcb_lo, fcb_hi    enregistre l'image (5 Ko, $A000-$B3FF)
;     op 13 GLOAD  fcb_lo, fcb_hi    charge une image et passe en SPLIT
;                  (version disque ; type .IMG si le nom n'en a pas)
;                  -> A = 0 OK, 1 fichier absent, 2 disque ou
;                     répertoire plein, $FF pas en mode SPLIT (GSAVE)
; =====================================================================

GFX_FUNC = 115
G_NOPS   = 14

gfx_call
.(
        ldy #5                  ; recopie le bloc de paramètres
cp      lda (ZP_PTR),y
        sta g_p,y
        dey
        bpl cp
        lda g_p
        cmp #G_NOPS
        bcs err
        cmp #10                 ; MODE et GETMODE marchent dans tous les modes
        bcs go
        ldx vmode
        beq err
go      asl
        tax
        lda g_tab+1,x
        pha
        lda g_tab,x
        pha
        rts
err     lda #$FF
        rts
.)

g_tab   .word g_cls-1, g_setpen-1, g_plot-1, g_line-1, g_box-1, g_fbox-1
        .word g_circle-1, g_text-1, g_attr-1, g_point-1, g_mode-1, g_getmode-1
#ifdef DISK
        .word g_gsave-1, g_gload-1
#else
        .word g_bad-1, g_bad-1
g_bad   lda #$FF
        rts
#endif

g_ok    lda #0
        rts

g_setpen
        lda g_p+1
        sta g_pen
        jmp g_ok

g_getmode
        lda vmode
        rts

#ifdef DISK
g_gsave
        lda g_p+1
        ldy g_p+2
        jmp img_save
g_gload
        lda g_p+1
        ldy g_p+2
        jmp img_load

; ---------------------------------------------------------------------
; Images du mode SPLIT sur disque : 40 enregistrements, $A000-$B3FF
; ---------------------------------------------------------------------
; img_prep : FCB A/Y, type IMG par défaut, octets 12-35 à zéro, DMA sauvé
img_prep
.(
        sta img_fcb
        sty img_fcb+1
        sta ZP_PTR2
        sty ZP_PTR2+1
        ldy #9
        lda (ZP_PTR2),y
        cmp #" "
        bne ext
        lda #"I"
        sta (ZP_PTR2),y
        iny
        lda #"M"
        sta (ZP_PTR2),y
        iny
        lda #"G"
        sta (ZP_PTR2),y
ext     ldy #12
        lda #0
z       sta (ZP_PTR2),y
        iny
        cpy #36
        bne z
        lda dma
        sta img_dma
        lda dma+1
        sta img_dma+1
        lda #<IMG_BASE
        sta dma
        lda #>IMG_BASE
        sta dma+1
        lda #40
        sta img_cnt
        rts
.)

img_bdos                        ; fonction X sur le FCB de l'image
        lda img_fcb
        ldy img_fcb+1
        jmp bdos

img_next                        ; enregistrement suivant ; Z=1 si fini
        clc
        lda dma
        adc #128
        sta dma
        bcc in1
        inc dma+1
in1     dec img_cnt
        rts

img_end                         ; rend le DMA de l'appelant, A = code
        pha
        lda img_dma
        sta dma
        lda img_dma+1
        sta dma+1
        pla
        rts

; img_save : A/Y = FCB. A = 0 OK, 2 plein, $FF pas en mode SPLIT
img_save
.(
        ldx vmode
        bne ok
        lda #$FF
        rts
ok      jsr img_prep
        ldx #19                 ; remplace un fichier existant
        jsr img_bdos
        ldx #22
        jsr img_bdos
        cmp #$FF
        beq full
loop    ldx #21
        jsr img_bdos
        cmp #0
        bne wfail
        jsr img_next
        bne loop
        ldx #16
        jsr img_bdos
        lda #0
        jmp img_end
wfail   ldx #16
        jsr img_bdos
full    lda #2
        jmp img_end
.)

; img_load : A/Y = FCB. A = 0 OK (mode SPLIT), 1 fichier absent
img_load
.(
        jsr img_prep
        ldx #15
        jsr img_bdos
        cmp #$FF
        bne loop
        lda #1
        jmp img_end
loop    ldx #20
        jsr img_bdos
        cmp #0
        bne done
        jsr img_next
        bne loop
done    lda vmode               ; déjà en SPLIT : on garde la console
        beq sw
        lda #ATTR_TEXT50
        sta IMG_SWITCH
        bne fin
sw      jsr video_split
fin     lda #0
        jmp img_end
.)
#endif

g_mode
.(
        lda g_p+1
        beq text
        cmp #2
        beq keep
        jsr gcls
keep    jsr video_split
        jmp g_ok
text    jsr video_text
        jmp g_ok
.)

; ---------------------------------------------------------------------
; Changement de mode
; ---------------------------------------------------------------------
; video_vars_text : variables du mode texte (sans toucher à l'écran)
video_vars_text
        lda #0
        sta vmode
        sta bar_row
        lda #FIRST_ROW
        sta con_first
        lda #LAST_ROW
        sta con_last
        lda #<SCREEN
        sta ZP_BAR
        lda #>SCREEN
        sta ZP_BAR+1
        lda #<TPA_END
        sta tpa_top
        lda #>TPA_END
        sta tpa_top+1
        jmp cap_top

; cap_top : un débogueur résident peut abaisser le haut de la TPA
cap_top
        lda top_cap
        beq ct_r
        cmp tpa_top+1
        bcs ct_r
        sta tpa_top+1
        lda #0
        sta tpa_top
ct_r    rts

video_text
        jsr cur_off_sys
        jsr video_vars_text
        lda #ATTR_TEXT50
        sta SCREEN+LAST_ROW*40+COLS-1 ; plus de bascule en fin d'écran
        jsr cls_body
        jsr draw_status
        jmp cur_on_sys

video_split
        jsr cur_off_sys
        lda #1
        sta vmode
        lda #SPLIT_BAR
        sta bar_row
        lda #SPLIT_BAR+1
        sta con_first
        lda #LAST_ROW-1
        sta con_last
        lda #<(SCREEN+SPLIT_BAR*40)
        sta ZP_BAR
        lda #>(SCREEN+SPLIT_BAR*40)
        sta ZP_BAR+1
        lda #<IMG_BASE
        sta tpa_top
        lda #>IMG_BASE
        sta tpa_top+1
        jsr cap_top
        lda #ATTR_TEXT50        ; retour au texte à la ligne de points 128
        sta IMG_SWITCH
        sta IMG_END
        lda #" "                ; ligne de texte 15 vide (lue par
        ldy #COLS-1             ; Oricutron en fin de ligne de points 127)
br1     sta SCREEN+15*40,y
        dey
        bpl br1
        ldx #SPLIT_BAR
        jsr clear_row
        jsr cls_body
        jsr draw_status
        ldx #LAST_ROW           ; ligne 27 : attributs seulement (papier,
        jsr clear_row           ; encre, puis $08 = rien à dessiner)
        lda #8
        ldy #COLS-2
br2     sta SCREEN+LAST_ROW*40,y
        dey
        cpy #FIRST_COL
        bcs br2
        lda #ATTR_HIRES         ; et bascule en haute résolution en fin de trame
        sta SCREEN+LAST_ROW*40+COLS-1
        jmp cur_on_sys

; curseur caché pendant les changements de mode
cur_off_sys
        php
        sei
        lda cur_vis
        beq cfs
        jsr cur_toggle
cfs     lda #0
        sta cur_en
        plp
        rts

cur_on_sys
        lda #1
        sta cur_en
        php
        sei
        jsr show_cursor
        plp
        rts

; gcls : efface l'image (octets de points vides)
gcls
.(
        lda #<IMG_BASE
        sta ZP_G
        lda #>IMG_BASE
        sta ZP_G+1
        ldx #>(IMG_END-IMG_BASE)
        ldy #0
        lda #$40
loop    sta (ZP_G),y
        iny
        bne loop
        inc ZP_G+1
        dex
        bne loop
        lda vmode               ; l'attribut de retour au texte est dans l'image
        beq r
        lda #ATTR_TEXT50
        sta IMG_SWITCH
r       rts
.)

g_cls   jsr gcls
        jmp g_ok

; ---------------------------------------------------------------------
; Points
; ---------------------------------------------------------------------
; g_addr : (g_px, g_py) 16 bits -> ZP_G, g_mask. C=1 si hors de l'image
g_addr
.(
        lda g_px+1
        ora g_py+1
        bne out
        ldx g_py
        cpx #IMG_LINES
        bcs out
        ldy g_px
        cpy #240
        bcs out
        lda g_ylo,x
        clc
        adc g_xcol,y
        sta ZP_G
        lda g_yhi,x
        adc #0
        sta ZP_G+1
        lda g_xbit,y
        sta g_mask
        clc
        rts
out     sec
        rts
.)

; plot : point (g_px, g_py) selon g_pen ; les cases d'attribut sont épargnées
plot
.(
        jsr g_addr
        bcs r
        ldy #0
        lda (ZP_G),y
        sta g_tmp
        and #$60
        beq r
        lda g_pen
        beq erase
        cmp #1
        beq draw
        lda g_tmp
        eor g_mask
        jmp st
draw    lda g_tmp
        ora g_mask
        jmp st
erase   lda g_mask
        eor #$FF
        and g_tmp
st      sta (ZP_G),y
r       rts
.)

; set_p : g_px = A, g_py = X (8 bits)
set_p
        sta g_px
        stx g_py
        lda #0
        sta g_px+1
        sta g_py+1
        rts

g_plot
        lda g_p+1
        ldx g_p+2
        jsr set_p
        jsr plot
        jmp g_ok

g_point
.(
        lda g_p+1
        ldx g_p+2
        jsr set_p
        jsr g_addr
        bcs no
        ldy #0
        lda (ZP_G),y
        tax
        and #$60
        beq no
        txa
        and g_mask
        beq no
        lda #1
        rts
no      lda #0
        rts
.)

; ---------------------------------------------------------------------
; Lignes (Bresenham)
; ---------------------------------------------------------------------
; line : de (A, X) à (g_x2, g_y2)
line
.(
        jsr set_p
        ; dx = |x2-x1|, sx
        lda #1
        sta g_sx
        sec
        lda g_x2
        sbc g_px
        bcs dxp
        eor #$FF
        adc #1
        ldx #$FF
        stx g_sx
dxp     sta g_dx
        lda #0
        sta g_dx+1
        ; dy = -|y2-y1|, sy
        lda #1
        sta g_sy
        sec
        lda g_y2
        sbc g_py
        bcs dyp
        eor #$FF
        adc #1
        ldx #$FF
        stx g_sy
dyp     sta g_dy                ; puis négation sur 16 bits
        lda #0
        sec
        sbc g_dy
        sta g_dy
        lda #0
        sbc #0
        sta g_dy+1
        ; err = dx + dy
        clc
        lda g_dx
        adc g_dy
        sta g_err
        lda g_dx+1
        adc g_dy+1
        sta g_err+1
loop    jsr plot
        lda g_px
        cmp g_x2
        bne cont
        lda g_py
        cmp g_y2
        beq done
cont    lda g_err               ; e2 = 2 * err
        asl
        sta g_e2
        lda g_err+1
        rol
        sta g_e2+1
        sec                     ; e2 >= dy ?
        lda g_e2
        sbc g_dy
        lda g_e2+1
        sbc g_dy+1
        bmi noX
        clc
        lda g_err
        adc g_dy
        sta g_err
        lda g_err+1
        adc g_dy+1
        sta g_err+1
        clc
        lda g_px
        adc g_sx
        sta g_px
noX     sec                     ; e2 <= dx ?
        lda g_dx
        sbc g_e2
        lda g_dx+1
        sbc g_e2+1
        bmi loop
        clc
        lda g_err
        adc g_dx
        sta g_err
        lda g_err+1
        adc g_dx+1
        sta g_err+1
        clc
        lda g_py
        adc g_sy
        sta g_py
        jmp loop
done    rts
.)

g_line
        lda g_p+3
        sta g_x2
        lda g_p+4
        sta g_y2
        lda g_p+1
        ldx g_p+2
        jsr line
        jmp g_ok

; hline_y : ligne horizontale de g_p+1 à g_p+3 sur la ligne X
hline_y
        stx g_y2
        lda g_p+3
        sta g_x2
        lda g_p+1
        jmp line

g_box
        ldx g_p+2               ; haut
        jsr hline_y
        ldx g_p+4               ; bas
        jsr hline_y
        lda g_p+1               ; gauche
        sta g_x2
        lda g_p+4
        sta g_y2
        lda g_p+1
        ldx g_p+2
        jsr line
        lda g_p+3               ; droite
        sta g_x2
        lda g_p+4
        sta g_y2
        lda g_p+3
        ldx g_p+2
        jsr line
        jmp g_ok

g_fbox
.(
        lda g_p+2               ; y1 <= y2
        cmp g_p+4
        bcc ok
        ldx g_p+4
        sta g_p+4
        stx g_p+2
ok      lda g_p+2
        sta g_cnt
loop    ldx g_cnt
        jsr hline_y
        lda g_cnt
        cmp g_p+4
        beq done
        inc g_cnt
        jmp loop
done    jmp g_ok
.)

; ---------------------------------------------------------------------
; Cercle (algorithme du point milieu)
; ---------------------------------------------------------------------
g_circle
.(
        lda g_p+1
        sta g_cx
        lda g_p+2
        sta g_cy
        lda g_p+3
        bpl rok                 ; rayon limité à 127
        lda #127
rok     sta g_r
        sta g_dx                ; x = r
        lda #0
        sta g_dy                ; y = 0
        sec                     ; err = 1 - r
        lda #1
        sbc g_r
        sta g_err
        lda #0
        sbc #0
        sta g_err+1
loop    lda g_dx                ; tant que x >= y
        cmp g_dy
        bcc done
        jsr oct8
        inc g_dy
        lda g_err+1
        bpl pos
        lda g_dy                ; err += 2y + 1
        asl
        sec
        adc g_err
        sta g_err
        lda g_err+1
        adc #0
        sta g_err+1
        jmp loop
pos     dec g_dx                ; x--, err += 2(y - x) + 1
        sec                     ; t = y - x sur 16 bits signés
        lda g_dy
        sbc g_dx
        sta g_e2
        lda #0
        sbc #0
        sta g_e2+1
        asl g_e2                ; t * 2
        rol g_e2+1
        sec                     ; err += t + 1
        lda g_err
        adc g_e2
        sta g_err
        lda g_err+1
        adc g_e2+1
        sta g_err+1
        jmp loop
done    jmp g_ok

; oct8 : les 8 points symétriques (cx ± x, cy ± y) et (cx ± y, cy ± x)
oct8    lda g_dx
        ldx g_dy
        jsr quad
        lda g_dy
        ldx g_dx
quad    sta g_e2                ; a = décalage horizontal, x = vertical
        stx g_e2+1
        lda #0                  ; +a, +b
        jsr pt
        lda #1                  ; -a, +b
        jsr pt
        lda #2                  ; +a, -b
        jsr pt
        lda #3                  ; -a, -b
pt      sta g_tmp
        lda g_tmp
        and #1
        bne mx
        clc
        lda g_cx
        adc g_e2
        sta g_px
        lda #0
        adc #0
        sta g_px+1
        jmp yy
mx      sec
        lda g_cx
        sbc g_e2
        sta g_px
        lda #0
        sbc #0
        sta g_px+1
yy      lda g_tmp
        and #2
        bne my
        clc
        lda g_cy
        adc g_e2+1
        sta g_py
        lda #0
        adc #0
        sta g_py+1
        jmp plot
my      sec
        lda g_cy
        sbc g_e2+1
        sta g_py
        lda #0
        sbc #0
        sta g_py+1
        jmp plot
.)

; ---------------------------------------------------------------------
; Texte et attributs
; ---------------------------------------------------------------------
g_text
.(
        lda g_p+3
        sta ZP_M2
        lda g_p+4
        sta ZP_M2+1
        lda g_p+1
        sta g_cx                ; colonne courante
        ldy #0
ch      sty g_cnt
        lda (ZP_M2),y
        beq done
        ldx g_cx
        cpx #40
        bcs done
        sec                     ; adresse du dessin du caractère
        sbc #32
        bcc next
        cmp #96
        bcs next
        sta g_tmp
        lda #0
        sta ZP_M1+1
        lda g_tmp
        asl
        rol ZP_M1+1
        asl
        rol ZP_M1+1
        asl
        rol ZP_M1+1
        clc
        adc #<font_data
        sta ZP_M1
        lda ZP_M1+1
        adc #>font_data
        sta ZP_M1+1
        lda #0
        sta g_r                 ; ligne 0 à 7 du caractère
row     lda g_p+2
        clc
        adc g_r
        cmp #IMG_LINES
        bcs next
        tax
        lda g_ylo,x
        clc
        adc g_cx
        sta ZP_G
        lda g_yhi,x
        adc #0
        sta ZP_G+1
        ldy g_r
        lda (ZP_M1),y
        ora #$40
        ldy #0
        sta (ZP_G),y
        inc g_r
        lda g_r
        cmp #8
        bne row
next    inc g_cx
        ldy g_cnt
        iny
        bne ch
done    jmp g_ok
.)

g_attr
.(
        lda g_p+2
        sta g_cnt
loop    ldx g_cnt
        cpx #IMG_LINES-1        ; la ligne 127 porte le retour au texte
        bcs done
        lda g_ylo,x
        clc
        adc g_p+1
        sta ZP_G
        lda g_yhi,x
        adc #0
        sta ZP_G+1
        lda g_p+4
        and #$1F
        ldy #0
        sta (ZP_G),y
        lda g_cnt
        cmp g_p+3
        beq done
        inc g_cnt
        jmp loop
done    jmp g_ok
.)
