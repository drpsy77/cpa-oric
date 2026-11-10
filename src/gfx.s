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
        cmp #2                  ; op 2 à 9 : banque GFX (gfx_draw.s), chargée
        bcc go                  ; au premier tracé ; refusée pendant un PUT
        lda put_on              ; (elle déborde sur le tampon de PUT) ;
        ora put_lost            ; après un chargement manqué, plus d'essai
        ora gfx_ko              ; jusqu'au prochain MODE (un message, pas
        bne err                 ; un par tracé)
        lda g_p
        asl
        tax
        ldy g_tab+1,x           ; (adresse de la routine, sans -1)
        lda g_tab,x
        tax
        lda #WIN_GFX
        jsr win_call
        pha
        lda win_id
        and #WIN_GFX
        bne gk
        inc gfx_ko
gk      pla
        rts
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

g_tab   .word g_cls-1, g_setpen-1, g_plot, g_line, g_box, g_fbox
        .word g_circle, g_text, g_attr, g_point, g_mode-1, g_getmode-1
        .word g_gsave_r-1, g_gload_r-1  ; banque IMG (bank.s, img.s)

g_ok    lda #0
        rts

g_setpen
        lda g_p+1
        sta g_pen
        jmp g_ok

g_getmode
        lda vmode
        rts


g_mode
.(
        lda #0                  ; la banque GFX sera de nouveau cherchée
        sta gfx_ko
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
        jsr font_init           ; écrasée si l'on revient du HIRES plein
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
