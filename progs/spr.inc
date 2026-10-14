; =====================================================================
;  spr.inc — sprites en mode texte (LORES) de GRAPHER, commune à
;  l'interpréteur (GRAPHER.COM) et aux programmes traduits par GRXASM
;  (qui ne l'incluent que s'ils s'en servent). Incluse après arr.inc,
;  dont elle se sert (descripteurs, r_top, rz_mul, rz_fillb, r_fail), et
;  avant hires.inc (hz_tad, h_zbuf, h_ztop). Référence :
;  docs/grapher.md, « Sprites ».
;
;  Un sprite (fichier .SPR chargé par BLOAD dans un tableau $) est un
;  groupe de 1 à 4 colonnes sur 1 à 4 lignes de cases. Chaque case
;  recouverte prend un caractère redessiné, tiré d'un tas de codes :
;    case = (décor AND NOT silhouette) OR dessin
;  Un tas par jeu de caractères (0 : standard $B400 ; 1 : secondaire
;  $B800) : un tableau d'entiers (les codes) dont les « sommet »
;  premiers éléments sont libres ; SOUS (96 octets, codes 32 à 127) :
;  l'octet du décor caché par chaque code pris, 0 si le code est libre.
;  Une case d'attribut (code 0-31) n'est jamais recouverte.
;
;  À définir par le programme qui l'inclut :
;    s_hst      octet : SPR.INC y met 1 quand le tas du jeu secondaire
;               est déclaré (le programme vide alors l'historique des
;               lignes, $BA80, en rendant la console)
;    (et ce que demandent arr.inc et hires.inc)
;
;    s_res      SPRITES : r_j = nombre d'emplacements (1-255) ; réserve
;               sous les tableaux 5 octets par emplacement et les SOUS
;               des deux tas (192 octets)
;    s_pool     SPOOL : A/Y = descripteur d'un tableau d'entiers, X = tas
;               (0, 1) ; tous ses codes deviennent libres (96 au plus)
;    s_show     SSHOW : A/Y = descripteur du tableau $ des sprites, X =
;               tas ; s_k emplacement, s_n rang du sprite, s_col, s_lig
;    s_hide     SHIDE : A = emplacement
;  Emplacement (5 octets) : tas + 1 (0 : libre), colonne, ligne,
;  largeur, hauteur.
;  r_chk <> 0 (interprété) : tout est vérifié ; 0 (traduit) : rien, sauf
;  le tas vide (la case reste alors sans sprite).
;  Page zéro : $B0-$BF.
; =====================================================================

s_p     = $B0           ; dessin de la case (2 octets)
s_q     = $B2           ; silhouette de la case (2 octets)
s_t     = $B4           ; caractère du décor (2 octets)
s_c     = $B6           ; caractère redessiné (2 octets)
s_so    = $B8           ; SOUS du tas, moins 32 (2 octets)
s_ar    = $BA           ; tableau des codes du tas (2 octets)
s_w     = $BC           ; emplacement (2 octets)
s_fn    = $BE           ; routine appelée pour chaque case (2 octets)

S_HIST  = $BA80         ; historique des lignes du système

; ---------------------------------------------------------------------
; SPRITES n
; ---------------------------------------------------------------------
s_res
.(
        lda r_chk
        beq sq2
        lda s_ns                ; une seule fois
        beq sq1
        lda #<rz_m_dim
        ldy #>rz_m_dim
        jmp r_fail
sq1     lda r_j+1               ; 1 à 255
        bne sq0
        lda r_j
        bne sq2
sq0     jmp rz_lim
sq2     lda r_ok
        bne sq3
        jsr r_init
sq3     lda r_j                 ; rz_p = 5 * n + 192
        sta s_ns
        sta rz_p
        lda #0
        sta rz_p+1
        asl rz_p
        rol rz_p+1
        asl rz_p
        rol rz_p+1
        clc
        lda rz_p
        adc r_j
        sta rz_p
        bcc sq4
        inc rz_p+1
sq4     clc
        lda rz_p
        adc #192
        sta rz_p
        bcc sq5
        inc rz_p+1
sq5     sec                     ; sous les tableaux, au-dessus de h_zbuf
        lda r_top
        sbc rz_p
        sta r_sa
        lda r_top+1
        sbc rz_p+1
        sta r_sa+1
        bcc sqm
        lda r_sa
        cmp h_zbuf
        lda r_sa+1
        sbc h_zbuf+1
        bcc sqm
        lda r_sa
        sta r_top
        sta h_ztop
        sta s_su
        clc
        adc #192
        sta s_sl
        lda r_sa+1
        sta r_top+1
        sta h_ztop+1
        sta s_su+1
        adc #0
        sta s_sl+1
        lda #0                  ; tout à 0 : emplacements libres
        sta rz_v
        sta rz_v+1
        lda #1
        sta rz_es
        jmp rz_fillb
sqm     lda #<rz_m_mem
        ldy #>rz_m_mem
        jmp r_fail
.)

; ---------------------------------------------------------------------
; SPOOL T [ALT]
; ---------------------------------------------------------------------
s_pool
.(
        stx s_h
        jsr rz_desc
        jsr sz_need
        ldy #2                  ; nombre d'éléments
        lda (r_dp),y
        sta rz_a
        iny
        lda (r_dp),y
        sta rz_a+1
        iny
        lda (r_dp),y
        sta rz_b
        iny
        lda (r_dp),y
        sta rz_b+1
        ora rz_b
        bne sq1
        inc rz_b
sq1     jsr rz_mul
        lda rz_p+1              ; 96 codes au plus
        bne sq2
        lda rz_p
        cmp #97
        bcc sq3
sq2     lda r_chk
        beq sq2b
        jmp rz_lim
sq2b    lda #96
sq3     ldx s_h
        sta s_hn,x
        sta s_ht,x
        ldy #0
        lda (r_dp),y
        sta s_hal,x
        iny
        lda (r_dp),y
        sta s_hah,x
        jsr sz_sel
        lda r_chk               ; codes de 32 à 127 (111 : secondaire)
        beq sq6
        ldx s_h
        lda s_hn,x
        asl
        tay
sq4     dey
        lda (s_ar),y
        bne sqb
        dey
        lda (s_ar),y
        cmp #32
        bcc sqb
        cmp #128
        bcs sqb
        cpx #0
        beq sq5
        cmp #112
        bcs sqb
sq5     cpy #0
        bne sq4
        beq sq6
sqb     jmp rz_lim
sq6     ldy #32                 ; aucun code pris
        lda #0
sq7     sta (s_so),y
        iny
        cpy #128
        bne sq7
        lda s_h
        beq sq8
        sta s_hst               ; jeu secondaire : historique abîmé
sq8     rts
.)

; ---------------------------------------------------------------------
; SHIDE k
; ---------------------------------------------------------------------
s_hide
.(
        jsr sz_slot
        ldy #0
        lda (s_w),y
        beq sq1
        jmp sz_off
sq1     rts
.)

; sz_off : retire le sprite de l'emplacement s_w (actif)
sz_off
.(
        ldy #0
        lda (s_w),y
        tax
        dex
        stx s_h
        tya
        sta (s_w),y             ; libre
        iny
        lda (s_w),y
        sta s_x0
        iny
        lda (s_w),y
        sta s_y0
        iny
        lda (s_w),y
        sta s_l
        iny
        lda (s_w),y
        sta s_hh
        jsr sz_sel
        lda #<sz_back
        sta s_fn
        lda #>sz_back
        sta s_fn+1
        jmp sz_each
.)

; sz_back : une case du sprite retiré (hq) : décor remis, code rendu
sz_back
.(
        ldy #0
        lda (hq),y
        and #$7F
        cmp #32
        bcc sq1
        sta s_r
        tay
        lda (s_so),y
        beq sq1                 ; pas un code pris (déjà rendu)
        ldy #0
        sta (hq),y
        ldy s_r
        lda #0
        sta (s_so),y
        ldx s_h                 ; rendu au tas (s'il n'est pas plein)
        ldy s_ht,x
        tya
        cmp s_hn,x
        bcs sq1
        inc s_ht,x
        asl
        tay
        lda s_r
        sta (s_ar),y
        iny
        lda #0
        sta (s_ar),y
sq1     rts
.)

; ---------------------------------------------------------------------
; SSHOW k S$ n col lig [ALT]
; ---------------------------------------------------------------------
s_show
.(
        sta s_dd
        sty s_dd+1
        stx s_hs
        lda s_k                 ; l'ancien sprite de l'emplacement
        jsr sz_slot
        ldy #0
        lda (s_w),y
        beq sq1
        jsr sz_off
sq1     lda s_dd
        ldy s_dd+1
        jsr rz_desc
        lda s_hs
        sta s_h
        jsr sz_sel
        lda r_chk
        beq sq2
        ldx s_h                 ; tas déclaré
        lda s_hn,x
        bne sq2
        lda #<sz_m_pool
        ldy #>sz_m_pool
        jmp r_fail
sq2     jsr sz_find             ; s_p : première case ; s_l, s_hh
        lda s_col
        sta s_x0
        lda s_lig
        sta s_y0
        lda r_chk
        beq sq4
        lda s_x0                ; dans l'écran
        cmp #40
        bcs sql
        lda s_y0
        cmp #28
        bcs sql
        clc
        lda s_x0
        adc s_l
        cmp #41
        bcs sql
        clc
        lda s_y0
        adc s_hh
        cmp #29
        bcs sql
        lda s_p                 ; assez de codes libres ?
        pha
        lda s_p+1
        pha
        lda #0
        sta s_r
        lda #<sz_cnt
        sta s_fn
        lda #>sz_cnt
        sta s_fn+1
        jsr sz_each
        pla
        sta s_p+1
        pla
        sta s_p
        ldx s_h
        lda s_ht,x
        cmp s_r
        bcs sq4
        lda #<sz_m_full
        ldy #>sz_m_full
        jmp r_fail
sql     jmp rz_lim
sq4     lda #<sz_put
        sta s_fn
        lda #>sz_put
        sta s_fn+1
        jsr sz_each
        ldy #0                  ; l'emplacement
        ldx s_h
        inx
        txa
        sta (s_w),y
        iny
        lda s_x0
        sta (s_w),y
        iny
        lda s_y0
        sta (s_w),y
        iny
        lda s_l
        sta (s_w),y
        iny
        lda s_hh
        sta (s_w),y
        rts
.)

; sz_cnt : codes à prendre (s_r) pour la case hq
sz_cnt
.(
        ldy #0
        lda (hq),y
        and #$7F
        cmp #32
        bcc sq1
        tay
        lda (s_so),y
        bne sq1
        inc s_r
sq1     rts
.)

; sz_put : la case hq reçoit la case s_p du sprite
sz_put
.(
        ldy #0
        lda (hq),y
        sta s_v
        and #$7F
        cmp #32
        bcc sq9                 ; attribut : jamais recouvert
        sta s_d
        tay
        lda (s_so),y
        beq sq1
        sty s_r                 ; déjà un sprite : on dessine sur lui
        jmp sq2
sq1     ldx s_h                 ; un code pris dans le tas
        ldy s_ht,x
        beq sq9                 ; (tas vide : case laissée)
        dey
        tya
        sta s_ht,x
        asl
        tay
        lda (s_ar),y
        sta s_r
        tay
        lda s_v
        sta (s_so),y
sq2     lda s_d                 ; caractère du décor
        jsr sz_gad
        sta s_t
        sty s_t+1
        lda s_r                 ; caractère redessiné
        jsr sz_gad
        sta s_c
        sty s_c+1
        clc                     ; silhouette : 8 octets après le dessin
        lda s_p
        adc #8
        sta s_q
        lda s_p+1
        adc #0
        sta s_q+1
        ldy #7
sq3     lda (s_q),y
        eor #$FF
        and (s_t),y
        ora (s_p),y
        sta (s_c),y
        dey
        bpl sq3
        lda s_v                 ; montré après avoir été dessiné
        and #$80
        ora s_r
        ldy #0
        sta (hq),y
sq9     rts
.)

; sz_gad : A = code -> A/Y = adresse de son dessin dans le jeu du tas
sz_gad
.(
        pha
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc s_bh
        tay
        pla
        asl
        asl
        asl
        rts
.)

; ---------------------------------------------------------------------
; Outils
; ---------------------------------------------------------------------
; sz_each : s_fn pour chaque case du rectangle (s_x0, s_y0, s_l, s_hh),
;   ligne par ligne, hq = adresse à l'écran ; s_p avance de 16 par case
sz_each
.(
        lda #0
        sta s_i
sq1     lda #0
        sta s_j
sq2     clc
        lda s_x0
        adc s_j
        tax
        clc
        lda s_y0
        adc s_i
        tay
        jsr hz_tad
        jsr sq9
        clc
        lda s_p
        adc #16
        sta s_p
        bcc sq3
        inc s_p+1
sq3     inc s_j
        lda s_j
        cmp s_l
        bne sq2
        inc s_i
        lda s_i
        cmp s_hh
        bne sq1
        rts
sq9     jmp (s_fn)
.)

; sz_sel : tas s_h -> s_ar (ses codes), s_so (SOUS - 32), s_bh (jeu)
sz_sel
.(
        ldx s_h
        lda s_hal,x
        sta s_ar
        lda s_hah,x
        sta s_ar+1
        lda #$B4
        cpx #0
        beq sq1
        lda #$B8
sq1     sta s_bh
        sec
        lda s_su
        sbc #32
        sta s_so
        lda s_su+1
        sbc #0
        sta s_so+1
        cpx #0
        beq sq2
        clc
        lda s_so
        adc #96
        sta s_so
        bcc sq2
        inc s_so+1
sq2     rts
.)

; sz_need : erreur si SPRITES n'a pas été fait (r_chk)
sz_need
.(
        lda r_chk
        beq sq1
        lda s_ns
        bne sq1
        lda #<sz_m_res
        ldy #>sz_m_res
        jmp r_fail
sq1     rts
.)

; sz_slot : A = emplacement -> s_w (vérifié si r_chk)
sz_slot
.(
        sta s_r
        jsr sz_need
        lda r_chk
        beq sq1
        lda s_r
        cmp s_ns
        bcc sq1
        jmp rz_lim
sq1     lda #0                  ; s_w = s_sl + 5 * k
        sta s_w+1
        lda s_r
        asl
        rol s_w+1
        asl
        rol s_w+1
        clc
        adc s_r
        bcc sq2
        inc s_w+1
sq2     clc
        adc s_sl
        sta s_w
        lda s_w+1
        adc s_sl+1
        sta s_w+1
        rts
.)

; sz_find : sprite s_n du tableau r_dp -> s_p (sa première case), s_l
;   (largeur), s_hh (hauteur) ; le fichier est vérifié si r_chk
sz_find
.(
        ldy #0
        lda (r_dp),y
        sta s_p
        iny
        lda (r_dp),y
        sta s_p+1
        lda r_chk
        beq sq3
        ldy #2                  ; fin du tableau : s_e
        lda (r_dp),y
        sta rz_a
        iny
        lda (r_dp),y
        sta rz_a+1
        iny
        lda (r_dp),y
        sta rz_b
        iny
        lda (r_dp),y
        sta rz_b+1
        ora rz_b
        bne sq1
        inc rz_b
sq1     jsr rz_mul
        clc
        lda s_p
        adc rz_p
        sta s_e
        lda s_p+1
        adc rz_p+1
        sta s_e+1
        jsr sz_r8               ; en-tête : SPR, version 1, genre 0
        ldy #3
sq2     lda (s_p),y
        cmp sz_sig,y
        bne sqf
        dey
        bpl sq2
        ldy #5
        lda (s_p),y
        bne sqf
        ldy #4                  ; rang < nombre de sprites
        lda s_n
        cmp (s_p),y
        bcc sq3
sql     jmp rz_lim
sqf     lda #<sz_m_spr
        ldy #>sz_m_spr
        jmp r_fail
sq3     ldx s_n
        clc                     ; premier en-tête de sprite
        lda s_p
        adc #8
        sta s_p
        bcc sq4
        inc s_p+1
sq4     lda r_chk
        beq sq6
        jsr sz_r8
sq6     ldy #0
        lda (s_p),y
        sta s_l
        iny
        lda (s_p),y
        sta s_hh
        lda r_chk               ; 1 à 4 colonnes, 1 à 4 lignes
        beq sq7
        lda s_l
        sec
        sbc #1
        cmp #4
        bcs sqg
        lda s_hh
        sec
        sbc #1
        cmp #4
        bcc sq7
sqg     jmp sqf
sq7     lda #0                  ; s_sz = 16 * largeur * hauteur
        ldy s_hh
sq8     clc
        adc s_l
        dey
        bne sq8
        sta s_sz
        lda #0
        sta s_sz+1
        ldy #4
sq9     asl s_sz
        rol s_sz+1
        dey
        bne sq9
        clc                     ; s_p : première case
        lda s_p
        adc #8
        sta s_p
        bcc sqa
        inc s_p+1
sqa     lda r_chk               ; les cases dans le tableau
        beq sqb
        lda s_sz
        ldy s_sz+1
        jsr sz_room
sqb     txa
        beq sqr
        dex
        clc
        lda s_p
        adc s_sz
        sta s_p
        lda s_p+1
        adc s_sz+1
        sta s_p+1
        jmp sq4
sqr     rts
.)

; sz_r8 : 8 octets en s_p dans le tableau ; sz_room : A/Y octets
sz_r8   lda #8
        ldy #0
sz_room
.(
        clc
        adc s_p
        sta s_v
        tya
        adc s_p+1
        cmp s_e+1
        bcc sq1
        bne sq2
        lda s_v
        cmp s_e
        beq sq1
        bcs sq2
sq1     rts
sq2     jmp rz_lim
.)

sz_sig  .asc "SPR",1
sz_m_res  .asc "SPRITES d'abord",0
sz_m_pool .asc "SPOOL d'abord",0
sz_m_spr  .asc "fichier .SPR ?",0
sz_m_full .asc "plus de caracteres pour les sprites",0

; paramètres de SSHOW
s_k     .byt 0
s_n     .byt 0
s_col   .byt 0
s_lig   .byt 0
; état
s_ns    .byt 0          ; nombre d'emplacements (0 : pas de SPRITES)
s_sl    .word 0         ; emplacements
s_su    .word 0         ; SOUS des deux tas
s_hn    .byt 0,0        ; tas : nombre de codes (0 : pas déclaré)
s_ht    .byt 0,0        ;   sommet
s_hal   .byt 0,0        ;   adresse du tableau
s_hah   .byt 0,0
; travail
s_h     .byt 0
s_hs    .byt 0
s_bh    .byt 0
s_dd    .word 0
s_x0    .byt 0
s_y0    .byt 0
s_l     .byt 0
s_hh    .byt 0
s_i     .byt 0
s_j     .byt 0
s_v     .byt 0
s_d     .byt 0
s_r     .byt 0
s_e     .word 0
s_sz    .word 0
