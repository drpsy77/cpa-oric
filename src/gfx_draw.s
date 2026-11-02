; =====================================================================
;  gfx_draw.s — primitives de tracé du mode SPLIT (BDOS 115, op 2 à 9 :
;               PLOT, LINE, BOX, FBOX, CIRCLE, TEXT, ATTR, POINT)
;
;  Version disquette : banque GFX de la fenêtre, assemblée avec le système
;  (cpa.s, après les vecteurs, *= WIN) et rangée dans CPA.BNK par
;  tools/mkbnk.py ; gfx_call (gfx.s) la fait charger par win_call au
;  premier tracé, et la refuse pendant un PUT (la banque déborde sur le
;  tampon de PUT : $F7C0 à $FBFF au plus). Les tables g_xcol, g_xbit
;  (tables.s), les variables (page 2) et g_ok restent résidents.
;  Version ROM : incluse à la suite de gfx.s.
; =====================================================================
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
        clc                     ; la police dépliée par font_init (un
        adc #<(CHARSET+32*8)    ; caractère redéfini par le programme
        sta ZP_M1               ; est dessiné tel quel)
        lda ZP_M1+1
        adc #>(CHARSET+32*8)
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
