; =====================================================================
;  hires.inc — écran haute résolution pour les programmes .COM
;  (bibliothèque incluse à la fin d'un programme ; jamais assemblée seule)
;
;  Deux géométries, mêmes routines :
;    HIRES plein écran : 240 x 200 points, $A000-$BF3F. Les 3 lignes de
;      texte du bas (toujours en texte pour le circuit vidéo) ne
;      contiennent que des attributs : elles restent noires.
;    SPLIT : 240 x 128 points, le mode SPLIT du système (fonction 115) :
;      barre de menus et console sous l'image.
;
;  Règle du HIRES plein écran : le programme prend l'écran pour lui. Le
;  système n'y affiche plus rien de lui-même (ni curseur, ni menus FUNCT,
;  ni voyants) ; le programme ne doit pas écrire sur la console (BDOS 2,
;  9...) avant h_text. À la fin du programme (même par CTRL-C ou après
;  un plantage), le démarrage à chaud remet le mode texte.
;
;  Routines (paramètres dans h_x1, h_y1, h_x2, h_y2, h_r) :
;    h_init    tables et copie de la police (en mode texte ou SPLIT,
;              avant le premier h_full ; h_full l'appelle au besoin)
;    h_full    HIRES plein écran, image effacée
;    h_split   mode SPLIT (fonction 115), image effacée
;    h_text    retour au mode texte (fonction 115, la police est remise)
;    h_cls     efface l'image
;    h_pen     A = 0 efface, 1 trace, 2 inverse
;    h_plot    point (h_x1, h_y1)
;    h_line    ligne (h_x1, h_y1) - (h_x2, h_y2)
;    h_box     rectangle, h_fbox rectangle plein (mêmes coins)
;    h_circle  cercle de centre (h_x1, h_y1), rayon h_r (127 au plus)
;    h_print   chaîne A/Y (terminée par 0) à la case h_x1 (0-39), à
;              partir de la ligne de points h_y1
;    h_attr    attribut A (encre 0-7, papier 16-23) dans la case h_x1,
;              lignes h_y1 à h_y2
;    h_point   -> A = 1 si le point (h_x1, h_y1) est allumé
;    h_load    A/Y = FCB (type déjà mis) : en plein écran, image .HIR
;              (8 000 octets bruts, $A000-$BF3F) ; en SPLIT, image .IMG
;              du système ; dans les deux modes, image compressée .HIZ
;              (chargée en h_zbuf, puis h_unz). -> A = 0, 1 fichier
;              absent, 3 trop grand pour la mémoire libre
;    h_unz     A/Y = flux compressé (format de tools/lzhir.py) ->
;              image (8 000 octets ; 5 120 en SPLIT) ; distance 0 =
;              octets gardés (animations). -> A/Y = octet après le flux
;    h_zread   hq = FCB : fichier entier en mémoire à partir de h_zbuf
;              (mot, défaut h_free), jusqu'à $A000 au plus. -> A = 0
;              (hs = fin des données), 1 absent, 3 trop grand
;    h_save    A/Y = FCB : même format selon le mode. -> A = 0, 2 plein
;    h_key     attend une touche -> A
;  x 0-239, y 0-199 (0-127 en SPLIT) ; hors de l'image, rien n'est
;  dessiné. Les cases d'attribut sont épargnées par les tracés.
;  h_lines : 200 en plein écran, 128 en SPLIT, 0 en mode texte.
;
;  Page zéro : $C0-$C7. Tables après la fin du programme : h_free est
;  la première adresse libre pour les tampons du programme.
; =====================================================================

H_IMG   = $A000
H_BOT   = $BF40         ; après l'image plein écran : 3 lignes de texte
H_ATTR  = $BFDF         ; dernière case : $1E = haute résolution
H_SPLSW = $A000+127*40  ; SPLIT : retour au texte (ligne 127)
H_FONT  = $B400+32*8    ; police du mode texte, codes 32-127

hp      = $C0           ; adresse de l'octet du point
hq      = $C2           ; pointeur de travail
hs      = $C4           ; chaîne de h_print
hc      = $C6           ; compteur

h_init
.(
        lda h_ok
        bne hz_r
        ldy #0                  ; police : 768 octets
        ldx #3
        lda #<H_FONT
        sta hq
        lda #>H_FONT
        sta hq+1
        lda #<h_fnt
        sta hp
        lda #>h_fnt
        sta hp+1
hz_f1      lda (hq),y
        sta (hp),y
        iny
        bne hz_f1
        inc hq+1
        inc hp+1
        dex
        bne hz_f1
        lda #<H_IMG             ; lignes : $A000 + 40 * y
        sta hq
        lda #>H_IMG
        sta hq+1
        ldx #0
hz_y1      lda hq
        sta h_ylo,x
        lda hq+1
        sta h_yhi,x
        clc
        lda hq
        adc #40
        sta hq
        bcc hz_y2
        inc hq+1
hz_y2      inx
        cpx #200
        bne hz_y1
        ldx #0                  ; colonnes : x / 6, bit 5 - x mod 6
        ldy #0
        lda #$20
hz_c1      sta h_xbit,x
        pha
        tya
        sta h_xcol,x
        pla
        lsr
        bne hz_c2
        iny
        lda #$20
hz_c2      inx
        cpx #240
        bne hz_c1
        lda #1
        sta h_ok
        sta h_pm
hz_r       rts
.)

; h_gfx : fonction 115 du BDOS avec le bloc h_blk (op = A, p1 = X)
h_gfx
        sta h_blk
        stx h_blk+1
        ldx #F_GFX
        lda #<h_blk
        ldy #>h_blk
        jmp BDOS

h_full
.(
        jsr h_init
        lda #G_GETMODE          ; depuis le SPLIT : d'abord le texte
        jsr h_gfx
        cmp #0
        beq hz_txt
        jsr h_text
hz_txt     lda #0                  ; plus de curseur
        sta CON_CUREN
        sta CON_CURVIS
        lda #200
        sta h_lines
        jsr h_cls
        jsr h_bottom
        lda #<H_IMG             ; la TPA s'arrête sous l'image
        sta TPA_TOP
        lda #>H_IMG
        sta TPA_TOP+1
        rts
.)

; h_bottom : 3 lignes de texte du bas en attributs seulement, puis la
;   bascule en haute résolution pour la trame suivante
h_bottom
.(
        ldx #H_ATTR-H_BOT-1
        lda #$10
hz_l       sta H_BOT,x
        dex
        bpl hz_l
        lda #$1E
        sta H_ATTR
        rts
.)

h_split
        jsr h_init
        lda #128
        sta h_lines
        lda #G_MODE
        ldx #1
        jmp h_gfx

h_text
        lda #0
        sta h_lines
        lda #G_MODE
        ldx #0
        jmp h_gfx

h_key   jmp B_CONIN

h_pen   sta h_pm
        rts

; h_cls : octets de points vides sur toute l'image
h_cls
.(
        lda #<H_IMG
        sta hq
        lda #>H_IMG
        sta hq+1
        ldx #20                 ; SPLIT : 20 pages ($A000-$B3FF) ;
        lda h_lines             ; plein écran : 31 pages, puis $BF00-$BF3F
        cmp #200
        bne hz_n
        ldx #31
hz_n       lda #$40
        ldy #0
hz_l       sta (hq),y
        iny
        bne hz_l
        inc hq+1
        dex
        bne hz_l
        ldx h_lines
        cpx #200
        beq hz_full
        lda #$1A                ; SPLIT : retour au texte à la ligne 127
        sta H_SPLSW
        rts
hz_full    ldy #63
hz_f2      sta $BF00,y
        dey
        bpl hz_f2
        jmp h_bottom
.)

; h_addr : (h_px, h_py) 16 bits -> hp, h_mask. C=1 si hors de l'image
h_addr
.(
        lda h_px+1
        ora h_py+1
        bne hz_out
        ldx h_py
        cpx h_lines
        bcs hz_out
        ldy h_px
        cpy #240
        bcs hz_out
        lda h_ylo,x
        clc
        adc h_xcol,y
        sta hp
        lda h_yhi,x
        adc #0
        sta hp+1
        lda h_xbit,y
        sta h_mask
        clc
        rts
hz_out     sec
        rts
.)

; h_pset : point (h_px, h_py) selon le crayon, cases d'attribut épargnées
h_pset
.(
        jsr h_addr
        bcs hz_r
        ldy #0
        lda (hp),y
        tax
        and #$60
        beq hz_r
        lda h_pm
        beq hz_erase
        cmp #1
        beq hz_draw
        txa
        eor h_mask
        jmp hz_st
hz_draw    txa
        ora h_mask
        jmp hz_st
hz_erase   lda h_mask
        eor #$FF
        sta h_t
        txa
        and h_t
hz_st      sta (hp),y
hz_r       rts
.)

; h_setp : h_px = A, h_py = X (8 bits)
h_setp
        sta h_px
        stx h_py
        lda #0
        sta h_px+1
        sta h_py+1
        rts

h_plot
        lda h_x1
        ldx h_y1
        jsr h_setp
        jmp h_pset

h_point
.(
        lda h_x1
        ldx h_y1
        jsr h_setp
        jsr h_addr
        bcs hz_no
        ldy #0
        lda (hp),y
        tax
        and #$60
        beq hz_no
        txa
        and h_mask
        beq hz_no
        lda #1
        rts
hz_no      lda #0
        rts
.)

; h_line : de (h_x1, h_y1) à (h_x2, h_y2) (Bresenham)
h_line
        lda h_x2
        sta h_ex
        lda h_y2
        sta h_ey
        lda h_x1
        ldx h_y1
; h_ln : de (A, X) à (h_ex, h_ey)
h_ln
.(
        jsr h_setp
        lda #1
        sta h_sx
        sec
        lda h_ex
        sbc h_px
        bcs hz_dxp
        eor #$FF
        adc #1
        ldx #$FF
        stx h_sx
hz_dxp     sta h_dx
        lda #0
        sta h_dx+1
        lda #1
        sta h_sy
        sec
        lda h_ey
        sbc h_py
        bcs hz_dyp
        eor #$FF
        adc #1
        ldx #$FF
        stx h_sy
hz_dyp     sta h_dy                ; dy = -|y2 - y1| sur 16 bits
        lda #0
        sec
        sbc h_dy
        sta h_dy
        lda #0
        sbc #0
        sta h_dy+1
        clc                     ; err = dx + dy
        lda h_dx
        adc h_dy
        sta h_err
        lda h_dx+1
        adc h_dy+1
        sta h_err+1
hz_loop    jsr h_pset
        lda h_px
        cmp h_ex
        bne hz_cont
        lda h_py
        cmp h_ey
        beq hz_done
hz_cont    lda h_err               ; e2 = 2 * err
        asl
        sta h_e2
        lda h_err+1
        rol
        sta h_e2+1
        sec                     ; e2 >= dy ?
        lda h_e2
        sbc h_dy
        lda h_e2+1
        sbc h_dy+1
        bmi hz_nox
        clc
        lda h_err
        adc h_dy
        sta h_err
        lda h_err+1
        adc h_dy+1
        sta h_err+1
        clc
        lda h_px
        adc h_sx
        sta h_px
hz_nox     sec                     ; e2 <= dx ?
        lda h_dx
        sbc h_e2
        lda h_dx+1
        sbc h_e2+1
        bmi hz_loop
        clc
        lda h_err
        adc h_dx
        sta h_err
        lda h_err+1
        adc h_dx+1
        sta h_err+1
        clc
        lda h_py
        adc h_sy
        sta h_py
        jmp hz_loop
hz_done    rts
.)

; h_hl : ligne horizontale de h_x1 à h_x2 sur la ligne X
h_hl
        stx h_ey
        lda h_x2
        sta h_ex
        lda h_x1
        jmp h_ln

h_box
        ldx h_y1
        jsr h_hl
        ldx h_y2
        jsr h_hl
        lda h_x1
        sta h_ex
        lda h_y2
        sta h_ey
        lda h_x1
        ldx h_y1
        jsr h_ln
        lda h_x2
        sta h_ex
        lda h_y2
        sta h_ey
        lda h_x2
        ldx h_y1
        jmp h_ln

h_fbox
.(
        lda h_y1                ; de la plus petite à la plus grande ligne
        ldx h_y2
        cmp h_y2
        bcc hz_ok
        stx h_y1
        sta h_y2
        lda h_y1
hz_ok      sta hc
hz_loop    ldx hc
        jsr h_hl
        lda hc
        cmp h_y2
        beq hz_done
        inc hc
        jmp hz_loop
hz_done    rts
.)

; h_circle : algorithme du point milieu
h_circle
.(
        lda h_r
        bpl hz_rok
        lda #127
hz_rok     sta h_dx                ; x = r
        lda #0
        sta h_dy                ; y = 0
        sec                     ; err = 1 - r
        lda #1
        sbc h_dx
        sta h_err
        lda #0
        sbc #0
        sta h_err+1
hz_loop    lda h_dx                ; tant que x >= y
        cmp h_dy
        bcc hz_done
        jsr hz_oct8
        inc h_dy
        lda h_err+1
        bpl hz_pos
        lda h_dy                ; err += 2y + 1
        asl
        sec
        adc h_err
        sta h_err
        lda h_err+1
        adc #0
        sta h_err+1
        jmp hz_loop
hz_pos     dec h_dx                ; x--, err += 2(y - x) + 1
        sec
        lda h_dy
        sbc h_dx
        sta h_e2
        lda #0
        sbc #0
        sta h_e2+1
        asl h_e2
        rol h_e2+1
        sec
        lda h_err
        adc h_e2
        sta h_err
        lda h_err+1
        adc h_e2+1
        sta h_err+1
        jmp hz_loop
hz_done    rts

; oct8 : les 8 points symétriques
hz_oct8    lda h_dx
        ldx h_dy
        jsr hz_quad
        lda h_dy
        ldx h_dx
hz_quad    sta h_e2                ; décalages : horizontal, vertical
        stx h_e2+1
        lda #0
        jsr hz_pt
        lda #1
        jsr hz_pt
        lda #2
        jsr hz_pt
        lda #3
hz_pt      sta h_t
        and #1
        bne hz_mx
        clc
        lda h_x1
        adc h_e2
        sta h_px
        lda #0
        adc #0
        sta h_px+1
        jmp hz_yy
hz_mx      sec
        lda h_x1
        sbc h_e2
        sta h_px
        lda #0
        sbc #0
        sta h_px+1
hz_yy      lda h_t
        and #2
        bne hz_my
        clc
        lda h_y1
        adc h_e2+1
        sta h_py
        lda #0
        adc #0
        sta h_py+1
        jmp h_pset
hz_my      sec
        lda h_y1
        sbc h_e2+1
        sta h_py
        lda #0
        sbc #0
        sta h_py+1
        jmp h_pset
.)

; h_tlim : dernière ligne + 1 utilisable par le texte et les attributs
;   (en SPLIT, la ligne 127 porte le retour au texte)
h_tlim
.(
        lda h_lines
        cmp #128
        bne hz_r
        lda #127
hz_r       sta h_t
        rts
.)

h_print
.(
        sta hs
        sty hs+1
        jsr h_tlim
        lda h_x1
        sta h_cx
        ldy #0
hz_ch      sty h_cy
        lda (hs),y
        beq hz_done
        ldx h_cx
        cpx #40
        bcs hz_done
        sec                     ; dessin du caractère dans la police
        sbc #32
        bcc hz_next
        cmp #96
        bcs hz_next
        ldx #0
        stx hq+1
        asl
        rol hq+1
        asl
        rol hq+1
        asl
        rol hq+1
        clc
        adc #<h_fnt
        sta hq
        lda hq+1
        adc #>h_fnt
        sta hq+1
        lda #0
        sta hc                  ; ligne 0 à 7 du caractère
hz_row     clc
        lda h_y1
        adc hc
        bcs hz_next
        cmp h_t
        bcs hz_next
        tax
        lda h_ylo,x
        clc
        adc h_cx
        sta hp
        lda h_yhi,x
        adc #0
        sta hp+1
        ldy hc
        lda (hq),y
        ora #$40
        ldy #0
        sta (hp),y
        inc hc
        lda hc
        cmp #8
        bne hz_row
hz_next    inc h_cx
        ldy h_cy
        iny
        bne hz_ch
hz_done    rts
.)

h_attr
.(
        and #$1F
        sta h_e2
        jsr h_tlim
        lda h_x1
        cmp #40
        bcs hz_done
        lda h_y1
        sta hc
hz_loop    ldx hc
        cpx h_t
        bcs hz_done
        lda h_ylo,x
        clc
        adc h_x1
        sta hp
        lda h_yhi,x
        adc #0
        sta hp+1
        lda h_e2
        ldy #0
        sta (hp),y
        lda hc
        cmp h_y2
        beq hz_done
        inc hc
        jmp hz_loop
hz_done    rts
.)

; ---------------------------------------------------------------------
; Images
; ---------------------------------------------------------------------
h_load
.(
        sta hq
        sty hq+1
        ldy #11                 ; type HIZ : image compressée
hz_t    lda (hq),y
        and #$7F
        cmp hz_tz-9,y
        bne hz_raw
        dey
        cpy #8
        bne hz_t
        lda h_lines             ; (pas en mode texte : l'image recouvrirait
        beq hz_none             ;  la police et l'écran)
        jsr h_zread
        cmp #0
        bne hz_zr
        lda h_zbuf
        ldy h_zbuf+1
        jsr h_unz
        ldx h_lines
        cpx #200
        bne hz_zs
        jsr h_bottom
        lda #0
hz_zr   rts
hz_zs   lda #$1A                ; SPLIT : retour au texte à la ligne 127
        sta H_SPLSW
        lda #0
        rts
hz_none lda #1
        rts
hz_tz   .asc "HIZ"
hz_raw  ldx h_lines
        cpx #200
        beq hz_full
        ldx #G_GLOAD            ; SPLIT : image du système (.IMG)
        jmp h_sys
hz_full    jsr h_fcb0
        ldx #F_OPEN
        jsr h_bdf
        cmp #$FF
        bne hz_ok
        lda #1
        rts
hz_ok      jsr h_dma0
hz_rd      jsr h_dma
        ldx #F_READ
        jsr h_bdf
        cmp #0
        bne hz_end
        jsr h_dnext
        bne hz_rd
hz_end     jsr h_bottom            ; les 3 lignes du bas sont refaites
        jmp h_dmaend
.)

h_save
.(
        sta hq
        sty hq+1
        ldx h_lines
        cpx #200
        beq hz_full
        ldx #G_GSAVE
        jmp h_sys
hz_full    jsr h_fcb0
        ldx #F_DELETE
        jsr h_bdf
        jsr h_fcb0
        ldx #F_MAKE
        jsr h_bdf
        cmp #$FF
        beq hz_fail
        jsr h_dma0
hz_wr      jsr h_dma
        ldx #F_WRITE
        jsr h_bdf
        cmp #0
        bne hz_wfail
        jsr h_dnext
        bne hz_wr
        ldx #F_CLOSE
        jsr h_bdf
        jmp h_dmaend
hz_wfail   ldx #F_CLOSE
        jsr h_bdf
        jsr h_dmaend
hz_fail    lda #2
        rts
.)

; h_zread : fichier (FCB hq) en mémoire à partir de h_zbuf, jusqu'à $A000
h_zread
.(
        jsr h_fcb0
        ldx #F_OPEN
        jsr h_bdf
        cmp #$FF
        bne hz_o
        lda #1
        rts
hz_o    lda h_zbuf
        sta hs
        lda h_zbuf+1
        sta hs+1
hz_rd   lda hs+1                ; place pour 128 octets sous l'image ?
        cmp #>(H_IMG-128)
        bcc hz_ok
        bne hz_big
        lda hs
        cmp #$81
        bcs hz_big
hz_ok   jsr h_dma
        ldx #F_READ
        jsr h_bdf
        cmp #0
        bne hz_eof
        clc
        lda hs
        adc #128
        sta hs
        bcc hz_rd
        inc hs+1
        jmp hz_rd
hz_eof  jmp h_dmaend
hz_big  jsr h_dmaend
        lda #3
        rts
.)

; h_unz : flux A/Y -> image, à partir de $A000 jusqu'à $BF40 (plein
;   écran) ou $B400 (SPLIT). Groupes de 8 jetons après un octet de
;   drapeaux (bit 0 d'abord) ; 1 : littéral ; 0 : distance (16 bits),
;   longueur, copie depuis l'adresse en cours moins la distance (modulo
;   65 536) ; distance 0 : octets gardés, rien n'est copié. Une copie ne
;   dépasse jamais la fin de l'image (fichier abîmé).
;   Page zéro : hp flux, hq image, hs source de copie, hc drapeaux,
;   hc+1 jetons restants. -> A/Y = octet après le flux
h_unz
.(
        sta hp
        sty hp+1
        lda #<H_IMG
        sta hq
        lda #>H_IMG
        sta hq+1
        ldx #>H_BOT             ; fin : plein écran $BF40, SPLIT $B400
        lda #<H_BOT
        ldy h_lines
        cpy #128
        bne hz_e
        ldx #$B4
        lda #0
hz_e    sta h_zel
        stx h_zeh
        dex
        stx h_zlh
        ldy #0
        sty hc+1
hz_nx   dec hc+1                ; jeton suivant
        bpl hz_hf
        lda (hp),y              ; nouvel octet de drapeaux (Y = 0)
        sta hc
        inc hp
        bne hz_r1
        inc hp+1
hz_r1   lda #7
        sta hc+1
hz_hf   lsr hc
        bcc hz_cp
        lda (hp),y              ; littéral
        sta (hq),y
        inc hp
        bne hz_l1
        inc hp+1
hz_l1   inc hq
        bne hz_l2
        inc hq+1
hz_l2   lda hq+1
        cmp h_zeh
        bcc hz_nx
        lda hq
        cmp h_zel
        bcc hz_nx
        bcs hz_fin
hz_cp   lda (hp),y              ; distance, longueur
        sta hs
        iny
        lda (hp),y
        sta hs+1
        iny
        lda (hp),y
        tax
        bne hz_c0
        inx                     ; longueur 0 (fichier abîmé) : 1
hz_c0   clc
        lda hp
        adc #3
        sta hp
        bcc hz_c1
        inc hp+1
hz_c1   lda hq+1                ; loin de la fin : 256 octets au moins
        cmp h_zlh
        bcc hz_c2
        sec                     ; reste = fin - adresse en cours
        lda h_zel
        sbc hq
        tay
        lda h_zeh
        sbc hq+1
        bne hz_c2               ; 256 ou plus : pas de borne
        sty h_zt
        cpx h_zt
        bcc hz_c2
        ldx h_zt                ; la copie s'arrête à la fin de l'image
hz_c2   lda hs
        ora hs+1
        beq hz_sk
        sec                     ; source = adresse en cours - distance
        lda hq
        sbc hs
        sta hs
        lda hq+1
        sbc hs+1
        sta hs+1
        ldy #0
hz_cb   lda (hs),y
        sta (hq),y
        iny
        dex
        bne hz_cb
        tya
        jmp hz_ad
hz_sk   txa                     ; saut : octets gardés
hz_ad   ldy #0
        clc
        adc hq
        sta hq
        bcc hz_tf
        inc hq+1
hz_tf   lda hq+1                ; fin de l'image ?
        cmp h_zeh
        bcc hz_j
        bne hz_fin
        lda hq
        cmp h_zel
        bcs hz_fin
hz_j    jmp hz_nx
hz_fin  lda hp
        ldy hp+1
        rts
.)

; h_sys : GLOAD / GSAVE du système (X = op, A/Y = FCB)
h_sys   stx h_blk
        sta h_blk+1
        sty h_blk+2
        ldx #F_GFX
        lda #<h_blk
        ldy #>h_blk
        jmp BDOS

; h_fcb0 : octets 12-35 du FCB (hq) à zéro
h_fcb0
.(
        ldy #12
        lda #0
hz_l       sta (hq),y
        iny
        cpy #36
        bne hz_l
        rts
.)

; h_bdf : fonction X du BDOS sur le FCB hq
h_bdf   lda hq
        ldy hq+1
        jmp BDOS

; h_dma0 : premier enregistrement de l'image (63 : $A000-$BF7F)
h_dma0  lda #<H_IMG
        sta hs
        lda #>H_IMG
        sta hs+1
        lda #63
        sta hc
        rts

h_dma   ldx #F_SETDMA
        lda hs
        ldy hs+1
        jmp BDOS

; h_dnext : enregistrement suivant ; Z=1 si c'était le dernier
h_dnext clc
        lda hs
        adc #128
        sta hs
        bcc hz_dn1
        inc hs+1
hz_dn1     dec hc
        rts

h_dmaend
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #0
        rts

; ---------------------------------------------------------------------
; Variables (dans le programme) et tables (après sa fin)
; ---------------------------------------------------------------------
h_x1    .byt 0
h_y1    .byt 0
h_x2    .byt 0
h_y2    .byt 0
h_r     .byt 0
h_lines .byt 0
h_ok    .byt 0
h_pm    .byt 1
h_mask  .byt 0
h_t     .byt 0
h_cx    .byt 0
h_cy    .byt 0
h_ex    .byt 0
h_ey    .byt 0
h_sx    .byt 0
h_sy    .byt 0
h_px    .word 0
h_py    .word 0
h_dx    .word 0
h_dy    .word 0
h_err   .word 0
h_e2    .word 0
h_blk   .byt 0,0,0,0,0,0
h_zbuf  .word h_free
h_zel   .byt 0
h_zeh   .byt 0
h_zt    .byt 0
h_zlh   .byt 0
h_end

h_ylo   = h_end
h_yhi   = h_ylo+200
h_xcol  = h_yhi+200
h_xbit  = h_xcol+240
h_fnt   = h_xbit+240
h_free  = h_fnt+768
