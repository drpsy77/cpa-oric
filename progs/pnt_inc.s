; =====================================================================
;  pnt_inc.s — remplissage d'une zone de l'image (HIRES ou SPLIT)
;  Partagé : recopié dans HIRES.INC par tools/strip_inc.py (marque ;#inc,
;  avec hpnt_inc.s : h_paint, l'appel depuis h_x1, h_y1, h_pm), inclus
;  tel quel par progs/logo.s (REMPLIS). Jamais assemblé seul.
;
;  paint : depuis le point (p_x, p_y), remplit tout ce qui lui est relié
;    et dans le même état que lui : éteint si p_pen = 1 (ou 2), allumé si
;    p_pen = 0 (gomme). L'image a p_ny lignes (128 en SPLIT, 200 en
;    plein écran) et 240 colonnes. Les cases d'attribut (encre, papier)
;    sont des murs, jamais écrites ; le bord de l'image aussi. Un point
;    de départ hors de l'image ou déjà dans l'état voulu : rien.
;  Méthode : remplissage par segments de ligne (Heckbert, Graphics Gems).
;    Un segment (ligne y, de x1 à x2, sens dy) attend sur une pile : la
;    ligne y - dy est déjà remplie de x1 à x2, la ligne y est à explorer.
;    Dépilé, il est parcouru : chaque suite de points à remplir est
;    étendue à gauche et à droite, remplie, et la ligne y + dy est
;    empilée sur sa largeur ; ce qui déborde de x1..x2 est empilé vers
;    y - dy. Ainsi la pile ne grandit qu'avec les détours de la forme,
;    pas avec sa hauteur. Le curseur (pq, p_m, p_cx) avance d'un point à
;    l'autre sans rediviser par 6 ; un octet entier (6 points) à remplir,
;    ou sans rien à remplir, est traité d'un coup.
;    Pile de P_STKN octets (4 par segment) : pleine, le segment est
;    abandonné (p_ovf = 1 : remplissage incomplet). Cela arrive quand
;    une ligne remplie touche beaucoup de petites ouvertures (plus de
;    63 : hachures, pointillés) ; un nouveau remplissage dans la partie
;    restée vide finit le travail.
;  Page zéro : pq, 2 octets, à définir par l'inclueur (P_ZP).
; =====================================================================

P_IMG   = $A000
P_STKN  = 252           ; 63 segments (index sur un octet)
pq      = P_ZP          ; octet du point sous le curseur

; paint : remplit depuis (p_x, p_y)
paint
.(
        lda p_y
        cmp p_ny
        bcs pz_x
        lda p_x
        cmp #240
        bcc pz_go
pz_x    rts
pz_go   lda #0
        sta p_sp
        sta p_ovf
        lda p_x
        sta p_rl
        sta p_rr
        lda #1                 ; (y + 1, x, x, vers le bas)
        sta p_dy
        lda p_y
        clc
        adc #1
        sta p_qy
        jsr p_push
        lda #$FF               ; (y, x, x, vers le haut) : dépilé d'abord
        sta p_dy
        lda p_y
        sta p_qy
        jsr p_push
pz_loop lda p_sp               ; segment suivant : ligne p_y à explorer de
        bne pz_more            ;   p_xl à p_xr ; la ligne p_y - p_dy l'est déjà
        rts
pz_more sec
        sbc #4
        sta p_sp
        tax
        lda p_stk,x
        cmp p_ny               ; ligne hors de l'image ($FF ou >= p_ny)
        bcs pz_loop
        sta p_y
        lda p_stk+1,x
        sta p_xl
        sta p_cx
        lda p_stk+2,x
        sta p_xr
        lda p_stk+3,x
        sta p_dy
        jsr p_cur
        jsr p_ok               ; le point en xl est-il à remplir ?
        bcs pz_yes
        jmp pz_skip
pz_yes  jsr p_set
        lda pq                 ; oui : curseur gardé, puis vers la gauche
        sta p_sq
        lda pq+1
        sta p_sq+1
        lda p_m
        sta p_sm
pz_lft  jsr p_left
        bcs pz_le
        lda p_m                ; dernier point d'un octet : l'octet entier ?
        cmp #1
        bne pz_l1
        jsr p_byte
        bcc pz_l1
        lda p_cx
        sec
        sbc #5
        sta p_cx
        lda #$20
        sta p_m
        jmp pz_lft
pz_l1   jsr p_ok
        bcc pz_le2
        jsr p_set
        jmp pz_lft
pz_le   lda p_cx               ; au bord : rempli jusqu'à p_cx
        jmp pz_ls
pz_le2  lda p_cx               ; p_cx n'est pas à remplir
        clc
        adc #1
pz_ls   sta p_rl               ; début de la suite
        lda p_sq               ; curseur repris en xl
        sta pq
        lda p_sq+1
        sta pq+1
        lda p_sm
        sta p_m
        lda p_xl
        sta p_cx
        lda p_rl               ; déborde à gauche de xl : la ligne d'où
        cmp p_xl               ;   l'on vient y est à explorer (y - dy)
        bcs pz_rgt
        lda p_xl
        sec
        sbc #1
        sta p_rr
        jsr p_back
pz_rgt  jsr p_right            ; vers la droite, depuis un point rempli
        bcs pz_re
        lda p_m                ; premier point d'un octet : l'octet entier ?
        cmp #$20
        bne pz_r1
        jsr p_byte
        bcc pz_r1
        lda p_cx
        clc
        adc #5
        sta p_cx
        lda #1
        sta p_m
        jmp pz_rgt
pz_r1   jsr p_ok
        bcc pz_re2
        jsr p_set
        jmp pz_rgt
pz_re   lda p_cx               ; au bord : rempli jusqu'à p_cx
        sta p_rr
        jsr p_fwd
        jmp pz_loop            ; (xr atteint)
pz_re2  lda p_cx               ; p_cx n'est pas à remplir : la suite finit
        sec                    ;   juste avant
        sbc #1
        sta p_rr
        jsr p_fwd
pz_skip lda p_cx               ; p_cx n'est pas à remplir : la suite d'après,
        cmp p_xr               ;   jusqu'à xr
        bcc pz_sk1
        jmp pz_loop
pz_sk1  jsr p_right
        lda p_m                ; un octet entier sans point à remplir est sauté
        cmp #$20
        bne pz_s1
        jsr p_skip
        bcc pz_s1
        lda p_cx
        clc
        adc #5
        sta p_cx
        lda #1
        sta p_m
        jmp pz_skip
pz_s1   jsr p_ok
        bcc pz_skip
        jsr p_set              ; nouvelle suite : commence ici
        lda p_cx
        sta p_rl
        jmp pz_rgt
.)

; p_fwd : la suite (p_rl..p_rr) de la ligne p_y est remplie : la ligne
;   suivante (p_y + p_dy) est à explorer sur sa largeur ; ce qui déborde
;   à droite de xr, la ligne d'où l'on vient (p_y - p_dy)
p_fwd
.(
        lda p_y
        clc
        adc p_dy
        sta p_qy
        jsr p_push
        lda p_rr
        cmp p_xr
        bcc pz_r
        beq pz_r
        lda p_rl               ; (gardé : p_back prend p_rl..p_rr)
        pha
        lda p_xr
        clc
        adc #1
        sta p_rl
        jsr p_back
        pla
        sta p_rl
pz_r    rts
.)

; p_back : (p_y - p_dy, p_rl, p_rr) est à explorer, dans l'autre sens
p_back
.(
        lda p_y
        sec
        sbc p_dy
        sta p_qy
        lda p_dy               ; sens inversé
        eor #$FE
        sta p_dy
        jsr p_push
        lda p_dy
        eor #$FE
        sta p_dy
        rts
.)

; p_push : empile (p_qy, p_rl, p_rr, p_dy)
p_push
.(
        ldx p_sp
        cpx #P_STKN-3
        bcs pz_full
        lda p_qy
        sta p_stk,x
        lda p_rl
        sta p_stk+1,x
        lda p_rr
        sta p_stk+2,x
        lda p_dy
        sta p_stk+3,x
        inx
        inx
        inx
        inx
        stx p_sp
        rts
pz_full lda #1
        sta p_ovf
        rts
.)

; p_cur : curseur sur (p_cx, p_y) : pq = P_IMG + 40 y + x / 6, p_m
p_cur
.(
        lda p_y                ; 40 y = 5 y * 8
        sta pq
        lda #0
        sta pq+1
        asl pq
        rol pq+1
        asl pq
        rol pq+1
        lda pq
        clc
        adc p_y
        sta pq
        bcc pz_a
        inc pq+1
pz_a    asl pq
        rol pq+1
        asl pq
        rol pq+1
        asl pq
        rol pq+1
        lda pq+1
        clc
        adc #>P_IMG
        sta pq+1
        lda p_cx               ; colonne x / 6, reste en X
        ldy #0
pz_d    cmp #6
        bcc pz_e
        sbc #6
        iny
        bne pz_d
pz_e    tax
        tya
        clc
        adc pq
        sta pq
        bcc pz_f
        inc pq+1
pz_f    lda #$20               ; masque : bit 5 - reste
pz_g    dex
        bmi pz_h
        lsr
        bpl pz_g
pz_h    sta p_m
        rts
.)

; p_ok : C=1 si le point sous le curseur est à remplir
p_ok
.(
        ldy #0
        lda (pq),y
        and #$40
        beq pz_no              ; case d'attribut
        lda (pq),y
        and p_m
        beq pz_off
        lda p_pen              ; allumé : à remplir si on gomme
        beq pz_yes
pz_no   clc
        rts
pz_off  lda p_pen              ; éteint : à remplir si on trace
        beq pz_no
pz_yes  sec
        rts
.)

; p_set : le point sous le curseur prend l'état du crayon
p_set
.(
        ldy #0
        lda p_pen
        beq pz_er
        lda (pq),y
        ora p_m
        bne pz_st              ; (toujours)
pz_er   lda p_m
        eor #$FF
        and (pq),y
pz_st   sta (pq),y
        rts
.)

; p_byte : C=1 si les six points de l'octet sous le curseur étaient tous à
;   remplir : ils le sont (le curseur ne bouge pas)
p_byte
.(
        ldy #0
        lda (pq),y
        and #$40
        beq pz_no
        lda (pq),y
        and #$3F
        ldx p_pen
        beq pz_er
        cmp #0
        bne pz_no              ; un point allumé
        lda (pq),y
        ora #$3F
        bne pz_st              ; (toujours)
pz_er   cmp #$3F
        bne pz_no              ; un point éteint
        lda (pq),y
        and #$C0
pz_st   sta (pq),y
        sec
        rts
pz_no   clc
        rts
.)

; p_skip : C=1 si l'octet sous le curseur n'a aucun point à remplir
p_skip
.(
        ldy #0
        lda (pq),y
        and #$40
        beq pz_yes             ; case d'attribut
        lda (pq),y
        and #$3F
        ldx p_pen
        beq pz_er
        cmp #$3F               ; trace : tous allumés ?
        beq pz_yes
pz_no   clc
        rts
pz_er   cmp #0                 ; gomme : tous éteints ?
        bne pz_no
pz_yes  sec
        rts
.)

; p_right, p_left : curseur d'un point à droite, à gauche ; C=1 au bord
p_right
.(
        lda p_cx
        cmp #239
        bcs pz_r
        inc p_cx
        lsr p_m
        bne pz_ok
        lda #$20
        sta p_m
        inc pq
        bne pz_ok
        inc pq+1
pz_ok   clc
pz_r    rts
.)
p_left
.(
        lda p_cx
        beq pz_bord
        dec p_cx
        asl p_m
        lda p_m
        cmp #$40
        bne pz_ok
        lda #1
        sta p_m
        lda pq
        bne pz_d
        dec pq+1
pz_d    dec pq
pz_ok   clc
        rts
pz_bord sec
        rts
.)

p_x     .byt 0          ; point de départ
p_y     .byt 0          ;   (puis ligne du segment en cours)
p_ny    .byt 128        ; lignes de l'image
p_pen   .byt 1          ; 0 gomme, sinon trace
p_ovf   .byt 0          ; 1 : pile pleine, remplissage incomplet
p_m     .byt 0          ; curseur : masque, colonne
p_cx    .byt 0
p_xl    .byt 0          ; segment en cours
p_xr    .byt 0
p_rl    .byt 0          ; suite de points trouvée
p_rr    .byt 0
p_dy    .byt 0          ; sens : 1 vers le bas, $FF vers le haut
p_qy    .byt 0          ; ligne à empiler
p_sq    .word 0         ; curseur gardé
p_sm    .byt 0
p_sp    .byt 0          ; pile des segments
p_stk   .dsb P_STKN
