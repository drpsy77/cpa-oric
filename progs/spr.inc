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
;  Tuiles (carte de tuiles en mode texte, docs/grapher.md « Tuiles ») :
;    t_set      TILESET : A/Y = descripteur du tableau $ des tuiles (une
;               ligne par tuile : ses codes, ligne par ligne), t_w, t_h
;               (1-4), X = 1 si la chaîne courante (r_sa, r_sc) donne
;               les caractères de la carte dans l'ordre des tuiles ;
;               réserve sous les tableaux (larg x haut + 1) pages
;               alignées, une fois (de nouveau si elles ne suffisent plus)
;    t_map      TMAP : A/Y = descripteur de la carte (tableau $ à deux
;               dimensions), t_x, t_y (signés) : caractère du monde au
;               coin ; fenêtre en (h_x1, h_y1), h_x2 x h_y2 cases
;    t_get      TILE : r_i, r_j = caractère du monde -> r_j = numéro de
;               la tuile (carte du dernier TMAP ; 0 hors de la carte)
;    t_font     TFONT : A/Y = descripteur d'un .SPR de genre 1, X = jeu,
;               t_c = premier code : dessins copiés dans la police
;  Un octet de la carte absent de la table, ou une case hors de la
;  carte, donne la tuile 0. Aucune division : t_x / t_w par 16
;  soustractions, une fois par commande.
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

; tuiles (TILESET, TMAP, TILE, TFONT) : même page zéro que les sprites
t_pp    = $B0           ; octet de la carte (2 octets)
t_ix    = $B2           ; table octet -> tuile (2 octets)
t_tp    = $B4           ; page en cours (TILESET, TFONT) (2 octets)
t_sp    = $B6           ; début de la fenêtre à l'écran (2 octets)
t_mp    = $B8           ; ligne de la carte (2 octets)
t_v     = $BA           ; ligne de D$ (TILESET) (2 octets)
t_kc    = $BC           ; TMAP : cases restantes de la tuile
t_j     = $BD           ;   tuile de la ligne
t_wd    = $BE           ;   largeur de la fenêtre

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

; sz_find0 : s_p = début du tableau r_dp ; si r_chk : s_e = sa fin, et
;   l'en-tête (SPR, version 1) est vérifié
sz_find0
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
        jsr sz_r8               ; en-tête : SPR, version 1
        ldy #3
sq2     lda (s_p),y
        cmp sz_sig,y
        bne sz_bad
        dey
        bpl sq2
sq3     rts
.)
sz_bad  lda #<sz_m_spr
        ldy #>sz_m_spr
        jmp r_fail

; sz_find : sprite s_n du tableau r_dp -> s_p (sa première case), s_l
;   (largeur), s_hh (hauteur) ; le fichier est vérifié si r_chk
sz_find
.(
        jsr sz_find0
        lda r_chk
        beq sq3
        ldy #5                  ; genre 0 : sprites
        lda (s_p),y
        bne sqf
        ldy #4                  ; rang < nombre de sprites
        lda s_n
        cmp (s_p),y
        bcc sq3
sql     jmp rz_lim
sqf     jmp sz_bad
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

; ---------------------------------------------------------------------
; Tuiles : TILESET D$ larg haut [K$]
;   Mémoire réservée (pages alignées) : page 0 = octet de la carte ->
;   numéro de la tuile (TILE) ; pages 1 à larg x haut : pour chaque
;   place (ligne, colonne) dans la tuile, octet de la carte -> code
;   affiché. TMAP n'a plus qu'à traduire : comme une carte de 1 x 1.
; ---------------------------------------------------------------------
t_set
.(
        stx t_hk
        jsr rz_desc
        lda t_w                 ; t_wh = largeur * hauteur
        ldx t_h
        jsr tz_mul8
        sta t_wh
        lda r_chk
        beq tq2
        lda t_w                 ; 1 à 4 colonnes, 1 à 4 lignes
        sec
        sbc #1
        cmp #4
        bcs tql
        lda t_h
        sec
        sbc #1
        cmp #4
        bcs tql
        ldy #5                  ; une ligne du tableau : t_wh codes
        lda (r_dp),y
        bne tq1
        dey
        lda (r_dp),y
        cmp t_wh
        bcc tqi
tq1     lda t_hk                ; K$ : pas plus de caractères que de
        beq tq2                 ;   tuiles
        ldy #3
        lda (r_dp),y
        bne tq2
        dey
        lda (r_dp),y
        sta t_n
        jsr rz_len
        cpy t_n
        beq tq2
        bcc tq2
tqi     jmp rz_idx
tql     jmp rz_lim
tq2     ldx t_wh                ; pages : t_wh + 1, réservées une fois
        inx                     ;   (de nouveau si elles ne suffisent
        cpx t_np                ;   plus)
        beq tq3
        bcc tq3
        jsr tz_res
tq3     jsr tz_ptr
        ldy #3                  ; nombre de tuiles : t_n (0 : 256)
        lda (r_dp),y
        beq tq4
        lda #0
        beq tq5
tq4     dey
        lda (r_dp),y
tq5     sta t_n
        lda #0                  ; tout octet inconnu : tuile 0
        sta t_z
        tay
tq7     sta (t_ix),y
        iny
        bne tq7
        lda t_hk
        bne tq9
tq8     tya                     ; sans K$ : l'octet est le numéro
        sta (t_ix),y
        iny
        cpy t_n
        bne tq8
        beq tqb
tq9     jsr rz_len              ; K$ : du dernier au premier, pour que
        tya                     ;   le premier l'emporte
        beq tqb
        tax
tqa     dex
        txa
        tay
        lda (r_sa),y
        sta t_z                 ; (à la fin : K$(0), octet de la tuile 0)
        tay
        txa
        sta (t_ix),y
        cpx #0
        bne tqa
tqb     ldy #4                  ; pas : octets par ligne de D$
        lda (r_dp),y
        sta rz_b
        iny
        lda (r_dp),y
        sta rz_b+1
        lda #$FF                ; tuile de la ligne t_v (aucune)
        sta t_k
        lda #0
        sta t_b
; pour chaque octet de la carte : ses codes, une page par place
tqc     ldy t_b
        lda (t_ix),y
        cmp t_k
        beq tqd
        sta t_k                 ; t_v = D$ + tuile * pas
        sta rz_a
        lda #0
        sta rz_a+1
        lda rz_b
        pha
        lda rz_b+1
        pha
        jsr rz_mul
        pla
        sta rz_b+1
        pla
        sta rz_b
        ldy #0
        clc
        lda (r_dp),y
        adc rz_p
        sta t_v
        iny
        lda (r_dp),y
        adc rz_p+1
        sta t_v+1
tqd     lda #0                  ; t_tp : page de la place 0
        sta t_tp
        ldx t_tb+1
        inx
        stx t_tp+1
        ldx #0
tqe     txa
        tay
        lda (t_v),y
        ldy t_b
        sta (t_tp),y
        inc t_tp+1
        inx
        cpx t_wh
        bne tqe
        inc t_b
        bne tqc
        lda #1
        sta t_ok
        rts
.)

; tz_mul8 : A <- A * X (petits nombres)
tz_mul8
.(
        sta t_v
        lda #0
        cpx #0
        beq tq2
tq1     clc
        adc t_v
        dex
        bne tq1
tq2     rts
.)

; tz_res : X pages alignées sous les tableaux, au-dessus de h_zbuf ->
;   t_tb (octet bas 0), t_np
tz_res
.(
        stx t_np
        lda r_ok
        bne tq1
        jsr r_init
tq1     lda #0
        sta t_tb
        sec
        lda r_top+1
        sbc t_np
        sta t_tb+1
        bcc tqm
        lda t_tb
        cmp h_zbuf
        lda t_tb+1
        sbc h_zbuf+1
        bcc tqm
        lda #0
        sta r_top
        sta h_ztop
        lda t_tb+1
        sta r_top+1
        sta h_ztop+1
        rts
tqm     lda #0
        sta t_np
        sta t_tb+1
        lda #<rz_m_mem
        ldy #>rz_m_mem
        jmp r_fail
.)

; tz_ptr : t_ix = table octet -> tuile (la page zéro est partagée)
tz_ptr  lda t_tb
        sta t_ix
        lda t_tb+1
        sta t_ix+1
        rts

; tz_div : t_dv (signé) / A (1 à 4) -> t_dv (quotient arrondi vers le
;   bas), t_dr (reste, 0 à A-1) ; 16 soustractions, sans division
tz_div
.(
        sta t_dd
        lda t_dv+1
        php
        bpl tq1
        jsr tz_not              ; négatif : (-v-1) / d, puis q = -q-1,
tq1     lda #0                  ;   r = d-1-r
        sta t_dr
        ldx #16
tq2     asl t_dv
        rol t_dv+1
        rol t_dr
        lda t_dr
        cmp t_dd
        bcc tq3
        sbc t_dd
        sta t_dr
        inc t_dv
tq3     dex
        bne tq2
        plp
        bpl tq4
        jsr tz_not
        lda t_dd
        clc
        sbc t_dr
        sta t_dr
tq4     rts
.)
tz_not  lda t_dv
        eor #$FF
        sta t_dv
        lda t_dv+1
        eor #$FF
        sta t_dv+1
        rts

; tz_cut : caractère du monde (t_x, t_y) -> tuile (t_cx, t_cy) et place
;   dans la tuile (t_rx, t_ry)
tz_cut
.(
        lda t_x
        sta t_dv
        lda t_x+1
        sta t_dv+1
        lda t_w
        jsr tz_div
        lda t_dv
        sta t_cx
        lda t_dv+1
        sta t_cx+1
        lda t_dr
        sta t_rx
        lda t_y
        sta t_dv
        lda t_y+1
        sta t_dv+1
        lda t_h
        jsr tz_div
        lda t_dv
        sta t_cy
        lda t_dv+1
        sta t_cy+1
        lda t_dr
        sta t_ry
        rts
.)

; tz_row : t_mp = ligne t_cy de la carte (0 <= t_cy < lignes)
tz_row
.(
        lda t_cy
        sta rz_a
        lda t_cy+1
        sta rz_a+1
        lda t_mc
        sta rz_b
        lda t_mc+1
        sta rz_b+1
        jsr rz_mul
        clc
        lda t_ma
        adc rz_p
        sta t_mp
        lda t_ma+1
        adc rz_p+1
        sta t_mp+1
        rts
.)

; tz_in : C=0 si 0 <= A/X (signé, A bas) < t_mr ; tz_inc : < t_mc
;   (pas de BIT abs : GRXASM peut recopier tz_in sans tz_inc)
tz_inc  ldy #2
        bne tz_cmp
tz_in   ldy #0
tz_cmp
.(
        sta t_v
        txa
        bmi tq1
        lda t_v
        cmp t_mr,y
        txa
        sbc t_mr+1,y
        rts
tq1     sec
        rts
.)

; ---------------------------------------------------------------------
; TMAP T$ X Y col lig larg haut
;   Par ligne de l'écran : trois morceaux de colonnes de tuiles (avant
;   la carte, dans la carte, après) ; hors de la carte, l'octet t_z
;   (tuile 0). Tuiles de 1 colonne : chaque caractère est traduit
;   directement (lda (carte),y / tax / lda table,x / sta (écran),y).
;   Plus larges : les octets des tuiles de la ligne sont d'abord
;   recopiés dans h_buf, puis chaque caractère est pris dans la table
;   de sa place (4 instructions modifiées à chaque ligne).
; ---------------------------------------------------------------------
t_map
.(
        jsr rz_desc
        lda t_ok                ; sans TILESET : erreur, ou rien (traduit)
        bne tq0
        lda r_chk
        beq tqr
        lda #<tz_m_set
        ldy #>tz_m_set
        jmp r_fail
tqr     rts
tq0     lda r_chk
        beq tq1
        lda h_x2                ; la fenêtre dans l'écran
        beq tql
        clc
        adc h_x1
        cmp #41
        bcs tql
        lda h_y2
        beq tql
        clc
        adc h_y1
        cmp #29
        bcs tql
        ldy #5                  ; deux dimensions
        lda (r_dp),y
        dey
        ora (r_dp),y
        bne tq1
        jmp rz_idx
tql     jmp rz_lim
tq1     ldy #5                  ; la carte, gardée pour TILE
tq2     lda (r_dp),y
        sta t_ma,y
        dey
        bpl tq2
        lda #1
        sta t_mok
        jsr tz_cut
        lda t_rx                ; t_nt : colonnes de tuiles touchées
        clc
        adc h_x2
        ldx #0
tq3     inx
        sec
        sbc t_w
        beq tq4
        bcs tq3
tq4     stx t_nt
        lda #0                  ; t_jl : première dans la carte
        ldx t_cx+1
        bpl tq6
        sec                     ; t_cx < 0 : -t_cx, au plus t_nt
        sbc t_cx
        tay
        lda #0
        sbc t_cx+1
        bne tq5
        tya
        cmp t_nt
        bcc tq6
tq5     lda t_nt
tq6     sta t_jl
        sec                     ; t_jh : après la dernière (t_mc - t_cx,
        lda t_mc                ;   au plus t_nt, au moins t_jl)
        sbc t_cx
        tay
        lda t_mc+1
        sbc t_cx+1
        bmi tq8                 ; (t_cx >= t_mc : aucune)
        bne tq7
        tya
        cmp t_nt
        bcc tq9
tq7     lda t_nt
        .byt $2C                ; (BIT abs : saute lda #0)
tq8     lda #0
tq9     cmp t_jl
        bcs tqa
        lda t_jl
tqa     sta t_jh
        lda t_ry                ; t_pg : page de la place (t_ry, 0)
        ldx t_w
        jsr tz_mul8
        sec                     ; (+ 1 : la page 0 est la table de TILE)
        adc t_tb+1
        sta t_pg
        lda t_cy
        ldx t_cy+1
        jsr tz_in
        bcs tqb
        jsr tz_row
tqb     lda h_x2
        sta t_wd
        lda h_y1
        sta t_row
        lda h_y2
        sta t_ny
; une ligne de l'écran
trow    lda t_row               ; début de la fenêtre à l'écran
        asl
        tay
        clc
        lda hz_rows,y
        adc h_x1
        sta t_sp
        lda hz_rows+1,y
        adc #0
        sta t_sp+1
        clc                     ; t_pp : octet de la première tuile
        lda t_mp
        adc t_cx
        sta t_pp
        lda t_mp+1
        adc t_cx+1
        sta t_pp+1
        lda t_jl
        sta t_l1
        lda t_jh
        sta t_l2
        lda t_cy                ; ligne de tuiles hors de la carte :
        ldx t_cy+1              ;   rien dedans
        jsr tz_in
        bcc trw
        lda t_nt
        sta t_l1
        sta t_l2
trw     lda t_w
        cmp #1
        beq tw1
        jmp twn
; tuiles d'une colonne : traduction directe
tw1     lda t_pg
        sta tw1b+2
        sta tw1d+2
        ldx t_z
tw1d    lda $FF00,x             ; (page modifiée)
        sta t_c0
        ldy #0
        lda t_c0
        cpy t_l1
        beq tw1a
tw1e    sta (t_sp),y            ; avant la carte
        iny
        cpy t_l1
        bne tw1e
tw1a    cpy t_l2
        beq tw1c
tw1f    lda (t_pp),y            ; dans la carte
        tax
tw1b    lda $FF00,x             ; (page modifiée)
        sta (t_sp),y
        iny
        cpy t_l2
        bne tw1f
tw1c    cpy t_wd
        beq tw1h
        lda t_c0
tw1g    sta (t_sp),y            ; après
        iny
        cpy t_wd
        bne tw1g
tw1h    jmp tnl
; tuiles plus larges : octets dans h_buf, puis une table par place
twn     ldy #0
        lda t_z
        cpy t_l1
        beq twn2
twn1    sta h_buf,y
        iny
        cpy t_l1
        bne twn1
twn2    cpy t_l2
        beq twn4
twn3    lda (t_pp),y
        sta h_buf,y
        iny
        cpy t_l2
        bne twn3
twn4    cpy t_nt
        beq twn6
        lda t_z
twn5    sta h_buf,y
        iny
        cpy t_nt
        bne twn5
twn6    ldx t_pg                ; pages des places de la ligne
        stx ts0+2
        inx
        stx ts1+2
        inx
        stx ts2+2
        inx
        stx ts3+2
        lda #0
        sta t_j
        sec
        lda t_w
        sbc t_rx
        sta t_kc
        ldy #0
        ldx h_buf
        lda t_rx                ; première tuile : à sa place t_rx
        beq ts0
        cmp #2
        bcc ts1
        beq ts2
        bcs ts3
ts0     lda $FF00,x             ; (page modifiée)
        sta (t_sp),y
        iny
        cpy t_wd
        beq tnl
        dec t_kc
        beq tnt
ts1     lda $FF00,x
        sta (t_sp),y
        iny
        cpy t_wd
        beq tnl
        dec t_kc
        beq tnt
ts2     lda $FF00,x
        sta (t_sp),y
        iny
        cpy t_wd
        beq tnl
        dec t_kc
        beq tnt
ts3     lda $FF00,x
        sta (t_sp),y
        iny
        cpy t_wd
        beq tnl
tnt     lda t_w                 ; tuile suivante
        sta t_kc
        inc t_j
        ldx t_j
        lda h_buf,x
        tax
        jmp ts0
; ligne suivante
tnl     inc t_row
        dec t_ny
        beq tend
        lda t_pg
        clc
        adc t_w
        sta t_pg
        inc t_ry
        lda t_ry
        cmp t_h
        bne tgo
        lda #0                  ; ligne de tuiles suivante
        sta t_ry
        lda t_tb+1
        sec
        adc #0
        sta t_pg
        inc t_cy
        bne tnl1
        inc t_cy+1
tnl1    lda t_cy
        ora t_cy+1
        bne tnl2
        lda t_ma                ; entrée dans la carte par le haut
        sta t_mp
        lda t_ma+1
        sta t_mp+1
        jmp tgo
tnl2    clc
        lda t_mp
        adc t_mc
        sta t_mp
        lda t_mp+1
        adc t_mc+1
        sta t_mp+1
tgo     jmp trow
tend    rts
.)

; ---------------------------------------------------------------------
; TILE(X,Y) : r_i, r_j -> r_j = numéro de la tuile
; ---------------------------------------------------------------------
t_get
.(
        lda r_i
        sta t_x
        lda r_i+1
        sta t_x+1
        lda r_j
        sta t_y
        lda r_j+1
        sta t_y+1
        lda #0
        sta r_j+1
        lda t_mok
        beq tq0
        jsr tz_cut
        lda t_cy
        ldx t_cy+1
        jsr tz_in
        bcs tq0
        lda t_cx
        ldx t_cx+1
        jsr tz_inc
        bcs tq0
        jsr tz_row
        jsr tz_ptr
        clc
        lda t_mp
        adc t_cx
        sta t_pp
        lda t_mp+1
        adc t_cx+1
        sta t_pp+1
        ldy #0
        lda (t_pp),y
        tay
        lda (t_ix),y
        .byt $2C                ; (BIT abs : saute lda #0)
tq0     lda #0
        sta r_j
        rts
.)

; ---------------------------------------------------------------------
; TFONT S$ code [ALT] : dessins d'un .SPR de genre 1 dans la police
; ---------------------------------------------------------------------
t_font
.(
        stx t_hk
        jsr rz_desc
        lda #0                  ; d'abord compter (et vérifier)
        jsr tz_walk
        lda r_chk
        beq tq2
        lda t_c                 ; codes 32 à 127 (ALT : 111)
        cmp #32
        bcc tql
        clc
        adc t_n
        bcs tql
        ldx t_hk
        cmp tz_lim,x
        bcc tq2
        beq tq2
tql     jmp rz_lim
tq2     lda t_c                 ; police : $B400 ou $B800 + 8 * code
        sta t_tp
        lda #0
        ldx #3
tq3     asl t_tp
        rol
        dex
        bne tq3
        ldx t_hk
        ora tz_fnt,x
        sta t_tp+1
        lda t_hk
        beq tq5x
        lda #1                  ; jeu secondaire : l'historique sera vidé
        sta s_hst
tq5x    lda #1                  ; puis copier
.)
; tz_walk : A = 0 : t_n <- nombre de cases du fichier (vérifié si
;   r_chk) ; A = 1 : copie de leurs dessins en (t_tp)
tz_walk
.(
        sta t_cp
        jsr sz_find0            ; s_p : début, s_e : fin (r_chk)
        ldy #5                  ; genre 1 : tuiles
        lda (s_p),y
        cmp #1
        beq tw0
        lda r_chk
        beq tw0
        jmp sz_bad
tw0     ldy #4
        lda (s_p),y
        sta t_k                 ; nombre de tuiles
        lda #0
        sta t_n
        clc
        lda s_p
        adc #8
        sta s_p
        bcc tw1
        inc s_p+1
tw1     lda t_k
        bne tw1b
        rts
tw1b
        lda r_chk
        beq tw2
        jsr sz_r8
tw2     ldy #0                  ; en-tête : largeur, hauteur
        lda (s_p),y
        sta s_l
        iny
        lda (s_p),y
        tax
        lda r_chk
        beq tw3
        lda s_l
        sec
        sbc #1
        cmp #4
        bcs twf
        txa
        sec
        sbc #1
        cmp #4
        bcs twf
tw3     lda s_l
        jsr tz_mul8             ; cases de cette tuile
        sta t_v+1
        clc
        adc t_n
        sta t_n
        bcs twf
        clc
        lda s_p
        adc #8
        sta s_p
        bcc tw4
        inc s_p+1
tw4     lda t_v+1               ; s_sz = 8 * cases
        asl
        asl
        asl
        sta s_sz
        lda #0
        rol
        sta s_sz+1
        lda r_chk
        beq tw5
        lda s_sz
        ldy s_sz+1
        jsr sz_room
tw5     lda t_cp
        beq tw7
        ldy #0
tw6     lda (s_p),y
        sta (t_tp),y
        iny
        cpy s_sz
        bne tw6
        clc
        lda t_tp
        adc s_sz
        sta t_tp
        bcc tw7
        inc t_tp+1
tw7     clc
        lda s_p
        adc s_sz
        sta s_p
        lda s_p+1
        adc s_sz+1
        sta s_p+1
        dec t_k
        jmp tw1
twf     jmp sz_bad
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
;#msg spr.msg

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
; tuiles
tz_lim  .byt 128,112    ; TFONT : fin des codes (jeu standard, secondaire)
tz_fnt  .byt $B4,$B8    ;   police
t_w     .byt 0          ; TILESET : largeur et hauteur d'une tuile
t_h     .byt 0
t_c     .byt 0          ; TFONT : premier code
t_ok    .byt 0          ; 1 : TILESET fait
t_tb    .word 0         ; tables (pages ; octet haut 0 : pas réservées)
t_np    .byt 0          ;   nombre de pages réservées
t_z     .byt 0          ; octet de la carte qui donne la tuile 0
t_x     .word 0         ; TMAP, TILE : caractère du monde
t_y     .word 0
t_ma    .word 0         ; carte du dernier TMAP : adresse, lignes,
t_mr    .word 0         ;   colonnes (copie du descripteur)
t_mc    .word 0
t_mok   .byt 0          ; 1 : TMAP fait
t_hk    .byt 0
t_wh    .byt 0
t_n     .byt 0
t_k     .byt 0
t_cp    .byt 0
t_b     .byt 0
t_nt    .byt 0
t_jl    .byt 0
t_jh    .byt 0
t_l1    .byt 0
t_l2    .byt 0
t_pg    .byt 0
t_c0    .byt 0
t_dv    .word 0
t_dd    .byt 0
t_dr    .byt 0
t_cx    .word 0
t_cy    .word 0
t_rx    .byt 0
t_ry    .byt 0
t_row   .byt 0
t_ny    .byt 0

