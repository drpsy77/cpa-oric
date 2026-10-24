; =====================================================================
;  arr.inc — tableaux et chaînes de GRAPHER (palier B), commune à
;  l'interpréteur (GRAPHER.COM) et aux programmes traduits par GRXASM (qui
;  ne l'incluent que s'ils ont un DIM). Incluse avant hires.inc.
;
;  À définir par le programme qui l'inclut :
;    r_i, r_j   deux mots (r_j sert aussi de valeur, r_v)
;    r_fail     erreur : A/Y = message (0 à la fin) ; ne revient pas
;    r_esc      ESC pendant une saisie : l'interpréteur arrête le
;               programme (ne revient pas) ; GRX.INC l'ignore (revient)
;
;  Descripteurs : 8 octets par tableau, en R_DESC (26 tableaux
;  d'entiers, puis 26 tableaux d'octets « $ ») : adresse, taille 1,
;  taille 2 (0 : une dimension), octets par élément (1 ou 2), nombre de
;  dimensions. Les tableaux sont réservés sous R_DESC, vers le bas,
;  jusqu'à h_zbuf (fin du programme ou du texte du .GRX) ; h_ztop suit,
;  pour que les images .HIZ et les animations ne les recouvrent pas.
;  Indices à partir de 0. Une chaîne : le contenu d'un tableau $ jusqu'au
;  premier 0 (ou à sa capacité, 255 au plus).
;  Deux dimensions : le programme écrit (colonne, ligne), comme l'écran de
;  l'Oric : DIM T$(c,l) = l lignes de c octets, T$(x,y) = colonne x de la
;  ligne y. En mémoire et dans le descripteur, rien ne change : l lignes
;  consécutives de c éléments, taille 1 = lignes, taille 2 = colonnes ;
;  r_dim2 et r_ea2 (donc r_get2) échangent r_i et r_j en entrant. Les
;  routines internes (rz_ea2...) gardent l'ordre (ligne, colonne).
;  r_chk <> 0 : indices et tableaux vérifiés (interprété) ; 0 : rien
;  (programmes traduits : la vitesse d'abord).
;
;    r_dim1     A/Y = descripteur, X = 1 ou 2 octets, r_j = taille
;    r_dim2     idem, r_i = colonnes, r_j = lignes (échangés en entrant)
;    r_get1     A/Y : élément r_j -> r_j ; r_get2 : élément (r_i, r_j) =
;               (colonne, ligne)
;    r_ea1      A/Y : adresse de l'élément r_j -> r_sa ; r_ea2 : (r_i, r_j)
;               = (colonne, ligne) ; r_i et r_j sont échangés
;    r_atoj     r_j <- r_sa (adresse à garder pendant le calcul de la valeur)
;    r_stw      r_j -> mot à l'adresse r_i ; r_stb : octet (0-255)
;    r_whole    A/Y : tout le tableau $ (une dimension) -> chaîne
;    r_row      A/Y : ligne r_j d'un tableau $ à deux dimensions -> chaîne
;    r_lit      chaîne écrite après l'appel (0 à la fin)
;    r_save     chaîne courante -> chaîne gardée (r_s1, r_c1) ; r_swap :
;               échange les deux
;    r_len      longueur de la chaîne courante -> r_j
;    r_cmp      X = 1 = 2 <> 3 < 4 <= 5 > 6 >= : gardée ? courante -> r_j
;    r_copy     chaîne gardée -> chaîne courante (le reste à 0)
;    r_print    PRINT : en LORES au curseur, rien en HIRES plein écran,
;               sinon dans la console avec passage à la ligne
;    r_input    saisie dans la chaîne courante ; r_ninput : entier -> r_j
;    r_fill     A/Y : tout le tableau à r_j
;  Rectangles de l'écran (LORES : cases ; image : octets sur lignes de
;  points), sans vérification (se servent de hires.inc : hz_rows, h_ylo,
;  h_yhi, h_buf, page zéro hp hq hs) :
;    r_rows     nombre de lignes de l'écran -> A (28 en LORES)
;    r_sdef     h_x1..h_y2 = tout l'écran, r_sf = octet vide (32 ou 64)
;    r_blit     A = 0 : mémoire (hs, lignes de r_bst octets) -> écran en
;               (h_x1, h_y1), h_x2 colonnes sur h_y2 lignes ; A = 1 : écran
;               -> mémoire (PASTE, GRAB)
;    r_scrl     A = 0 SCROLH, 1 SCROLV, 2 ROTH, 3 ROTV : le rectangle
;               (h_x1, h_y1)-(h_x2, h_y2) glisse de r_sn (signé) ; cases
;               libérées : r_sf
;  Page zéro : $C8-$CF.
; =====================================================================

R_DESC  = $9D60         ; 52 descripteurs de 8 octets, jusqu'à $9F00
R_NBYT  = R_DESC+208    ; tableaux d'octets (« $ »)

r_dp    = $C8           ; descripteur (2 octets)
r_sa    = $CA           ; élément, ou chaîne courante (2 octets)
r_s1    = $CC           ; chaîne gardée (2 octets)
r_sc    = $CE           ; capacité de la chaîne courante
r_c1    = $CF           ;   et de la chaîne gardée

; r_init : descripteurs à 0 (416 octets), place des tableaux sous R_DESC
r_init
.(
        ldy #0
        tya
qrz1     sta R_DESC,y
        iny
        bne qrz1
        ldy #160
qrz2     dey
        sta R_DESC+256,y
        bne qrz2
        lda #<R_DESC
        sta r_top
        sta h_ztop
        lda #>R_DESC
        sta r_top+1
        sta h_ztop+1
        lda #1
        sta r_ok
        rts
.)

; ---------------------------------------------------------------------
; DIM
; ---------------------------------------------------------------------
r_dim2  jsr rz_sw                ; (colonnes, lignes) -> (lignes, colonnes)
        jmp rz_dim
r_dim1  pha
        lda r_j
        sta r_i
        lda r_j+1
        sta r_i+1
        lda #0
        sta r_j
        sta r_j+1
        pla
rz_dim
.(
        sta r_dp
        sty r_dp+1
        stx rz_es
        lda r_ok
        bne qd1
        jsr r_init
qd1      ldy #1                  ; déjà réservé ?
        lda (r_dp),y
        beq qd2
        lda #<rz_m_dim
        ldy #>rz_m_dim
        jmp r_fail
qd2      lda r_i+1               ; taille 1 : de 1 à 32767
        bmi qlim0
        ora r_i
        bne qd3
qlim0    jmp rz_lim
qd3      lda r_j+1               ; taille 2 : 0 (une dimension) ou plus
        bmi qlim0
        ldx #1
        lda r_j
        ora r_j+1
        beq qone
        inx
qone     stx rz_nd
        jsr rz_count            ; rz_p = nombre d'éléments
        bcc qd4
        jmp qmem
qd4      lda rz_es
        cmp #2
        bne qsz
        asl rz_p
        rol rz_p+1
        bcs qmem
        bmi qmem
qsz      sec                     ; adresse = haut - taille
        lda r_top
        sbc rz_p
        sta rz_b
        lda r_top+1
        sbc rz_p+1
        sta rz_b+1
        bcc qmem
        lda rz_b                ; au-dessus de h_zbuf ?
        cmp h_zbuf
        lda rz_b+1
        sbc h_zbuf+1
        bcc qmem
        ldy #0                  ; descripteur
        lda rz_b
        sta (r_dp),y
        sta r_top
        sta h_ztop
        sta r_sa
        iny
        lda rz_b+1
        sta (r_dp),y
        sta r_top+1
        sta h_ztop+1
        sta r_sa+1
        iny
        lda r_i
        sta (r_dp),y
        iny
        lda r_i+1
        sta (r_dp),y
        iny
        lda r_j
        sta (r_dp),y
        iny
        lda r_j+1
        sta (r_dp),y
        iny
        lda rz_es
        sta (r_dp),y
        iny
        lda rz_nd
        sta (r_dp),y
        lda #0                  ; éléments à 0
        sta rz_v
        sta rz_v+1
        jmp rz_fillb
qlim     jmp rz_lim
qmem     lda #<rz_m_mem
        ldy #>rz_m_mem
        jmp r_fail
.)

; rz_count : rz_p <- taille 1 * taille 2 (r_i, r_j ; 0 : 1) ; C=1 si plus
;   de 32767
rz_count
.(
        lda r_i
        sta rz_a
        lda r_i+1
        sta rz_a+1
        lda r_j
        sta rz_b
        lda r_j+1
        sta rz_b+1
        ora rz_b
        bne qm
        inc rz_b                ; une dimension : * 1
qm       jmp rz_mul
.)

; rz_mul : rz_p <- rz_a * rz_b (positifs) ; C=1 si plus de 32767
rz_mul
.(
        lda #0
        sta rz_p
        sta rz_p+1
qloop    lda rz_b
        ora rz_b+1
        beq qdone
        lsr rz_b+1
        ror rz_b
        bcc qnx
        clc
        lda rz_p
        adc rz_a
        sta rz_p
        lda rz_p+1
        adc rz_a+1
        sta rz_p+1
        bcs qbig
        bmi qbig
qnx      lda rz_b                ; plus rien à ajouter : fini
        ora rz_b+1
        beq qdone
        asl rz_a
        rol rz_a+1
        bcs qbig
        bmi qbig
        bcc qloop
qdone    clc
        rts
qbig     sec
        rts
.)

; ---------------------------------------------------------------------
; Éléments
; ---------------------------------------------------------------------
; rz_desc : A/Y -> r_dp ; si r_chk : erreur si le tableau n'est pas réservé
rz_desc
.(
        sta r_dp
        sty r_dp+1
        lda r_chk
        beq qr
        ldy #1
        lda (r_dp),y
        bne qr
        lda #<rz_m_nodim
        ldy #>rz_m_nodim
        jmp r_fail
qr       rts
.)

; rz_sw : échange r_i et r_j (A, X, Y gardés)
rz_sw
.(
        pha
        lda r_i
        pha
        lda r_j
        sta r_i
        pla
        sta r_j
        lda r_i+1
        pha
        lda r_j+1
        sta r_i+1
        pla
        sta r_j+1
        pla
        rts
.)

; rz_fld : A = octet Y du descripteur
rz_fld  lda (r_dp),y
        rts

; r_ea1 : élément r_j (le tableau mis à plat, ligne après ligne) ; en
;   vérification, r_i et r_j sont changés
r_ea1
.(
        jsr rz_desc
        lda r_j
        sta rz_ix
        lda r_j+1
        sta rz_ix+1
        lda r_chk
        beq qok
        lda rz_ix+1
        bmi qbad
        ldy #2                  ; 0 <= indice < taille 1 * taille 2
        jsr rz_fld
        sta r_i
        iny
        jsr rz_fld
        sta r_i+1
        iny
        jsr rz_fld
        sta r_j
        iny
        jsr rz_fld
        sta r_j+1
        jsr rz_count
        lda rz_ix
        cmp rz_p
        lda rz_ix+1
        sbc rz_p+1
        bcs qbad
qok      lda rz_ix
        sta rz_p
        lda rz_ix+1
        sta rz_p+1
        jmp rz_addr
qbad     jmp rz_idx
.)

; r_ea2 : élément (r_i, r_j) = (colonne, ligne)
r_ea2   jsr rz_sw
        jsr rz_desc
rz_ea2                          ; (r_dp déjà choisi ; r_i ligne, r_j colonne)
.(
        lda r_chk
        beq qcalc
        ldy #7
        jsr rz_fld
        cmp #2
        bne qbad
        lda r_i+1               ; 0 <= r_i < taille 1
        bmi qbad
        ldy #2
        lda r_i
        cmp (r_dp),y
        iny
        lda r_i+1
        sbc (r_dp),y
        bcs qbad
        lda r_j+1               ; 0 <= r_j < taille 2
        bmi qbad
        iny
        lda r_j
        cmp (r_dp),y
        iny
        lda r_j+1
        sbc (r_dp),y
        bcs qbad
qcalc    lda r_i                 ; r_i * taille 2 + r_j
        sta rz_a
        lda r_i+1
        sta rz_a+1
        ldy #4
        jsr rz_fld
        sta rz_b
        iny
        jsr rz_fld
        sta rz_b+1
        jsr rz_mul
        clc
        lda rz_p
        adc r_j
        sta rz_p
        lda rz_p+1
        adc r_j+1
        sta rz_p+1
        jmp rz_addr
qbad     jmp rz_idx
.)

; rz_addr : r_sa <- adresse + rz_p * (octets par élément)
rz_addr
.(
        ldy #6
        jsr rz_fld
        cmp #2
        bne qb
        asl rz_p
        rol rz_p+1
qb       ldy #0
        clc
        lda (r_dp),y
        adc rz_p
        sta r_sa
        iny
        lda (r_dp),y
        adc rz_p+1
        sta r_sa+1
        rts
.)

; r_get1 / r_get2 : valeur de l'élément -> r_j
r_get1  jsr r_ea1
        jmp rz_rd
r_get2  jsr r_ea2
rz_rd
.(
        ldy #6
        jsr rz_fld
        ldy #0
        cmp #2
        bne qb
        lda (r_sa),y
        sta r_j
        iny
        lda (r_sa),y
        sta r_j+1
        rts
qb       lda (r_sa),y
        sta r_j
        sty r_j+1
        rts
.)

; r_atoj : r_j <- adresse de l'élément (r_sa), pour la garder sur une pile
r_atoj  lda r_sa
        sta r_j
        lda r_sa+1
        sta r_j+1
        rts

; r_stw : r_j -> mot à l'adresse r_i ; r_stb : octet (0-255)
r_stw   ldy #0
        lda r_j
        sta (r_i),y
        iny
        lda r_j+1
        sta (r_i),y
        rts
r_stb   lda r_j+1
        beq qstb1
        lda r_chk               ; traduit : l'octet bas, sans erreur
        beq qstb1
        jmp rz_rng
qstb1    ldy #0
        lda r_j
        sta (r_i),y
        rts

; r_fill : tout le tableau A/Y à r_j
r_fill
.(
        jsr rz_desc
        lda r_j
        sta rz_v
        lda r_j+1
        sta rz_v+1
        ldy #2
        jsr rz_fld
        sta r_i
        iny
        jsr rz_fld
        sta r_i+1
        iny
        jsr rz_fld
        sta r_j
        iny
        jsr rz_fld
        sta r_j+1
        jsr rz_count            ; rz_p = nombre d'éléments
        ldy #6
        jsr rz_fld
        sta rz_es
        cmp #2
        beq qw
        lda rz_v+1              ; tableau $ : 0-255 (vérifié en interprété)
        beq qa
        lda r_chk
        bne qbad
        beq qa
qw       asl rz_p
        rol rz_p+1
qa       ldy #0
        lda (r_dp),y
        sta r_sa
        iny
        lda (r_dp),y
        sta r_sa+1
        jmp rz_fillb
qbad     jmp rz_rng
.)

; rz_fillb : rz_p octets à partir de r_sa : rz_v (rz_es = 2 : mots)
rz_fillb
.(
        ldx #0                  ; 0 : octet bas, 1 : octet haut
qloop    lda rz_p
        ora rz_p+1
        beq qr
        lda rz_v
        cpx #1
        bne qlo
        lda rz_v+1
qlo      ldy #0
        sta (r_sa),y
        inc r_sa
        bne qn1
        inc r_sa+1
qn1      lda rz_p
        bne qn2
        dec rz_p+1
qn2      dec rz_p
        lda rz_es
        cmp #2
        bne qloop
        txa
        eor #1
        tax
        jmp qloop
qr       rts
.)

; ---------------------------------------------------------------------
; Chaînes
; ---------------------------------------------------------------------
; rz_byt : erreur si le tableau r_dp n'est pas un tableau $ (r_chk)
;   à Y dimensions
rz_byt
.(
        lda r_chk
        beq qr
        sty rz_nd
        ldy #6
        jsr rz_fld
        cmp #1
        bne qbad
        iny
        jsr rz_fld
        cmp rz_nd
        bne qbad
qr       rts
qbad     jmp rz_idx
.)

; rz_cap : r_sc <- valeur A/X (lo/hi), 255 au plus
rz_cap
.(
        cpx #0
        beq qc1
        lda #255
qc1      sta r_sc
        rts
.)

; r_whole : tout un tableau $ à une dimension
r_whole
.(
        jsr rz_desc
        ldy #1
        jsr rz_byt
        ldy #0
        jsr rz_fld
        sta r_sa
        iny
        jsr rz_fld
        sta r_sa+1
        iny
        jsr rz_fld
        pha
        iny
        jsr rz_fld
        tax
        pla
        jmp rz_cap
.)

; r_row : ligne r_j d'un tableau $ à deux dimensions
r_row
.(
        jsr rz_desc
        ldy #2
        jsr rz_byt
        lda r_j
        sta r_i
        lda r_j+1
        sta r_i+1
        lda #0
        sta r_j
        sta r_j+1
        jsr rz_ea2              ; (vérifie la ligne ; colonne 0)
        ldy #4
        jsr rz_fld
        pha
        iny
        jsr rz_fld
        tax
        pla
        jmp rz_cap
.)

; r_lit : chaîne écrite après l'appel, terminée par 0
r_lit
.(
        pla
        sta r_sa
        pla
        sta r_sa+1
        inc r_sa
        bne ql1
        inc r_sa+1
ql1      ldy #0
ql2      lda (r_sa),y
        beq ql3
        iny
        bne ql2
ql3      sty r_sc
        tya                     ; retour après le 0
        clc
        adc r_sa
        tax
        lda r_sa+1
        adc #0
        pha
        txa
        pha
        rts
.)

; r_save : chaîne courante -> chaîne gardée
r_save  lda r_sa
        sta r_s1
        lda r_sa+1
        sta r_s1+1
        lda r_sc
        sta r_c1
        rts

; r_swap : chaîne courante <-> chaîne gardée
r_swap  lda r_sa
        ldy r_s1
        sta r_s1
        sty r_sa
        lda r_sa+1
        ldy r_s1+1
        sta r_s1+1
        sty r_sa+1
        lda r_sc
        ldy r_c1
        sta r_c1
        sty r_sc
        rts

; rz_len : Y <- longueur de la chaîne courante (premier 0 ou capacité)
rz_len
.(
        ldy #0
ql       cpy r_sc
        beq qr
        lda (r_sa),y
        beq qr
        iny
        bne ql
qr       rts
.)
; rz_len1 : X <- longueur de la chaîne gardée
rz_len1
.(
        ldy #0
ql       cpy r_c1
        beq qr
        lda (r_s1),y
        beq qr
        iny
        bne ql
qr       tya
        tax
        rts
.)

r_len   jsr rz_len
        sty r_j
        lda #0
        sta r_j+1
        rts

; r_cmp : chaîne gardée (gauche) op chaîne courante (droite) -> 1 ou 0
r_cmp
.(
        stx rz_nd               ; opérateur
        jsr rz_len1
        stx rz_a                ; longueur gauche
        jsr rz_len
        sty rz_a+1              ; longueur droite
        ldy #0
ql       cpy rz_a
        beq qendl
        cpy rz_a+1
        beq qcgt                 ; la droite finit avant : gauche >
        lda (r_s1),y
        cmp (r_sa),y
        bcc qclt
        bne qcgt
        iny
        bne ql
qendl    cpy rz_a+1              ; la gauche finit : égales ou <
        beq qceq
qclt     lda #$FF
        bne qres
qcgt     lda #1
        bne qres
qceq     lda #0
qres     sta rz_v                ; -1, 0 ou 1
        ldx rz_nd
        lda #0
        dex
        bne qn1
        ldx rz_v                ; =
        bne qno
        beq qyes
qn1      dex
        bne qn2
        ldx rz_v                ; <>
        bne qyes
        beq qno
qn2      dex
        bne qn3
        ldx rz_v                ; <
        bmi qyes
        bpl qno
qn3      dex
        bne qn4
        ldx rz_v                ; <=
        bmi qyes
        beq qyes
        bne qno
qn4      dex
        bne qn5
        ldx rz_v                ; >
        bmi qno
        bne qyes
        beq qno
qn5      ldx rz_v                ; >=
        bpl qyes
qno      lda #0
        beq qst
qyes     lda #1
qst      sta r_j
        lda #0
        sta r_j+1
        rts
.)

; r_copy : chaîne gardée -> chaîne courante ; trop longue : erreur ; la
;   fin de la capacité est mise à 0
r_copy
.(
        jsr rz_len1             ; X = longueur de la source
        cpx r_sc
        beq qok
        bcc qok
        ldx r_sc                ; traduit : coupée à la capacité
        lda r_chk
        beq qok
        lda #<rz_m_long
        ldy #>rz_m_long
        jmp r_fail
qok      stx rz_a
        ldy #0
qcp      cpy rz_a
        beq qz
        lda (r_s1),y
        sta (r_sa),y
        iny
        bne qcp
qz       lda #0                  ; la fin de la capacité à 0
qzl      cpy r_sc
        beq qr
        sta (r_sa),y
        iny
        bne qzl
qr       rts
.)

; r_print : PRINT d'une chaîne
r_print
.(
        lda h_lo
        bne r_prt
        lda h_lines
        cmp #200
        beq qr
        jsr r_prt
        lda #13
        ldx #F_CONOUT
        jsr BDOS
        lda #10
        ldx #F_CONOUT
        jmp BDOS
qr       rts
.)

; r_prt : affiche la chaîne courante ; en LORES, les codes 0-31 tels
;   quels (attributs) ; dans la console, remplacés par un espace
r_prt
.(
        jsr rz_len
        sty rz_a
        ldy #0
ql       cpy rz_a
        beq qr
        lda (r_sa),y
        ldx h_lo
        beq qcon
        jsr h_lput              ; (garde X et Y)
        jmp qnx
qcon     cmp #32
        bcs qpr
        lda #" "
qpr      sty rz_a+1
        ldx #F_CONOUT
        jsr BDOS
        ldy rz_a+1
qnx      iny
        bne ql
qr       rts
.)

; ---------------------------------------------------------------------
; Saisie
; ---------------------------------------------------------------------
; r_input : saisie dans la chaîne courante (le reste à 0)
r_input
.(
        lda #0
        sta rz_flt              ; tous les caractères 32-126
        lda r_sc
        sta rz_max
        jsr rz_get              ; Y = longueur saisie
        lda #0
qzl      cpy r_sc
        beq qr
        sta (r_sa),y
        iny
        bne qzl
qr       rts
.)

; r_ninput : entier de -32768 à 32767 -> r_j ; refusé : son, on recommence
r_ninput
.(
qagain   lda #<rz_nbuf
        sta r_sa
        lda #>rz_nbuf
        sta r_sa+1
        lda #1
        sta rz_flt              ; chiffres et signe seulement
        lda #6
        sta rz_max
        jsr rz_get
        sty rz_nd               ; longueur
        jsr rz_atoi
        bcs qbad
        rts
qbad     jsr rz_bip
        jmp qagain
.)

; rz_atoi : rz_nbuf (rz_nd caractères) -> r_j ; C=1 si ce n'est pas un
;   entier de -32768 à 32767 (aussi pour fil.inc)
rz_atoi
.(
        lda #0
        sta r_j
        sta r_j+1
        sta rz_es               ; 1 : négatif
        tay
        cpy rz_nd
        beq qbad
        lda rz_nbuf
        cmp #"-"
        bne qdg
        inc rz_es
        iny
        cpy rz_nd
        beq qbad
qdg      lda rz_nbuf,y
        sec
        sbc #"0"
        cmp #10
        bcs qbad
        sta rz_v
        lda r_j+1               ; r_j * 10 + chiffre (32768 au plus)
        cmp #$0D
        bcs qbad
        lda r_j
        sta rz_a
        lda r_j+1
        sta rz_a+1
        asl r_j
        rol r_j+1
        asl r_j
        rol r_j+1
        clc
        lda r_j
        adc rz_a
        sta r_j
        lda r_j+1
        adc rz_a+1
        sta r_j+1
        asl r_j
        rol r_j+1
        clc
        lda r_j
        adc rz_v
        sta r_j
        bcc qd2
        inc r_j+1
qd2      lda r_j+1               ; plus de 32768 : refusé
        bpl qd3
        cmp #$80
        bne qbad
        lda r_j
        bne qbad
        lda rz_es               ; 32768 : seulement -32768
        beq qbad
qd3      iny
        cpy rz_nd
        bne qdg
        lda rz_es
        beq qr
        sec                     ; opposé
        lda #0
        sbc r_j
        sta r_j
        lda #0
        sbc r_j+1
        sta r_j+1
qr       clc
        rts
qbad     sec
        rts
.)

; rz_get : saisie de rz_max caractères au plus en r_sa -> Y = longueur ;
;   LORES : au curseur d'écriture, sans dépasser la ligne ; sinon la
;   saisie de ligne de la console (fonction 10 du BDOS)
rz_get
.(
        lda h_lo
        bne qlo
        lda r_sa                ; tampon du BDOS en r_sa - 2 : les deux
        sec                     ; octets d'avant sont gardés
        sbc #2
        sta r_dp
        lda r_sa+1
        sbc #0
        sta r_dp+1
        ldy #0
        lda (r_dp),y
        sta rz_a
        iny
        lda (r_dp),y
        sta rz_a+1
        lda rz_max
        dey
        sta (r_dp),y
        lda r_dp
        ldy r_dp+1
        ldx #10
        jsr BDOS
        ldy #1
        lda (r_dp),y
        sta rz_nd
        lda rz_a+1
        sta (r_dp),y
        dey
        lda rz_a
        sta (r_dp),y
        lda #13
        ldx #F_CONOUT
        jsr BDOS
        lda #10
        ldx #F_CONOUT
        jsr BDOS
        lda rz_flt              ; nombre : caractères vérifiés ensuite
        ldy rz_nd
        rts
qlo      lda #40                 ; LORES : pas plus loin que la ligne
        sec
        sbc h_lx                ; (h_lx : 40 au plus)
        cmp rz_max
        bcs qm1
        sta rz_max
qm1      ldy #0
        sty rz_nd
qkey     lda h_lx                ; curseur : la case en vidéo inverse
        sta h_x1
        lda h_ly
        sta h_y1
        lda h_lx
        cmp #40
        bcs qnocur
        jsr h_scrn
        sta rz_v
        ora #$80
        jsr h_chr
qnocur   jsr h_key
        pha
        lda h_lx
        cmp #40
        bcs qnc2
        lda rz_v                ; la case reprend son contenu
        jsr h_chr
qnc2     pla
        cmp #27                 ; ESC : arrêt en interprété ; ignoré
        bne qk1                 ;   dans un programme traduit (r_esc)
        jsr r_esc
qk1      cmp #13
        beq qdone
        cmp #127
        beq qdel
        cmp #8
        beq qdel
        cmp #32
        bcc qkey
        cmp #127
        bcs qkey
        ldy rz_flt
        beq qok
        cmp #"-"
        beq qok
        cmp #"0"
        bcc qkey
        cmp #"9"+1
        bcs qkey
qok      ldy rz_nd
        cpy rz_max
        bcs qkey
        sta (r_sa),y
        inc rz_nd
        jsr h_lput
        jmp qkey
qdel     lda rz_nd
        beq qkey
        dec rz_nd
        dec h_lx
        lda h_lx
        sta h_x1
        lda #" "
        jsr h_chr
        jmp qkey
qdone    ldy rz_nd
        rts
qz0      ldy #0
        rts
.)

; rz_bip : un son bref (saisie refusée)
rz_bip  lda #<rz_snd
        ldy #>rz_snd
        ldx #F_SND
        jmp BDOS

; ---------------------------------------------------------------------
; Erreurs
; ---------------------------------------------------------------------
rz_idx  lda #<rz_m_idx
        ldy #>rz_m_idx
        jmp r_fail
rz_lim  lda #<rz_m_lim
        ldy #>rz_m_lim
        jmp r_fail
rz_rng  lda #<rz_m_rng
        ldy #>rz_m_rng
        jmp r_fail

;#msg arr.msg

rz_snd  .byt S_NOTE,0,61,10,4,0
r_chk   .byt 0
r_ok    .byt 0
r_top   .word R_DESC
rz_es   .byt 0
rz_nd   .byt 0
rz_flt  .byt 0
rz_max  .byt 0
rz_ix   .word 0
rz_a    .word 0
rz_b    .word 0
rz_p    .word 0
rz_v    .word 0
rz_nbuf .dsb 8,0

; ---------------------------------------------------------------------
; Rectangles : copie (PASTE, GRAB), défilement et rotation (SCROLH,
; SCROLV, ROTH, ROTV). LORES : une case = un caractère ; image (HIRES,
; SPLIT) : un octet (6 points) en largeur, une ligne de points en
; hauteur. Rien n'est vérifié : c'est au programme de rester dans
; l'écran.
; ---------------------------------------------------------------------
; r_rows : nombre de lignes de l'écran -> A (28 en LORES, h_lines sinon)
r_rows
.(
        lda h_lo
        beq rz_ro1
        lda #28
        rts
rz_ro1  lda h_lines
        rts
.)

; r_sdef : rectangle = tout l'écran ; remplissage par défaut : espace en
;   LORES, octet vide (64) dans l'image
r_sdef
.(
        lda #0
        sta h_x1
        sta h_y1
        lda #39
        sta h_x2
        jsr r_rows
        sec
        sbc #1
        sta h_y2
        lda h_lo                ; (X et Y gardés)
        beq rz_sd1
        lda #32
        .byt $2C                ; (BIT abs : saute lda #64)
rz_sd1  lda #64
        sta r_sf
        rts
.)

; rz_ra : hq = adresse de la ligne Y, colonne h_x1
rz_ra
.(
        lda h_lo
        beq rz_ra1
        tya
        asl
        tay
        lda hz_rows+1,y
        tax
        lda hz_rows,y
        jmp rz_ra2
rz_ra1  ldx h_yhi,y
        lda h_ylo,y
rz_ra2  clc
        adc h_x1
        sta hq
        txa
        adc #0
        sta hq+1
        rts
.)

; rz_mv : rz_bn octets de (hp) vers (hq) ; rz_fl : rz_bn fois r_sf en (hq)
rz_mv
.(
        ldy #0
        ldx rz_bn
        beq rz_mv9
rz_mv1  lda (hp),y
        sta (hq),y
        iny
        dex
        bne rz_mv1
rz_mv9  rts
.)
rz_fl
.(
        ldy #0
        ldx rz_bn
        beq rz_fl9
        lda r_sf
rz_fl1  sta (hq),y
        iny
        dex
        bne rz_fl1
rz_fl9  rts
.)
; rz_mvr : rotation : rz_mv ; défilement : rz_fl
rz_mvr  lda rz_op
        and #2
        bne rz_mv
        beq rz_fl

; rz_pb : hp = h_buf + A ; rz_qb : hq = h_buf + A ; rz_rq : hq = rz_rw + A
rz_pb   clc
        adc #<h_buf
        sta hp
        lda #>h_buf
        adc #0
        sta hp+1
        rts
rz_qb   clc
        adc #<h_buf
        sta hq
        lda #>h_buf
        adc #0
        sta hq+1
        rts
rz_rq   clc
        adc rz_rw
        sta hq
        lda rz_rw+1
        adc #0
        sta hq+1
        rts
; rz_q2p : hp = hq
rz_q2p  lda hq
        sta hp
        lda hq+1
        sta hp+1
        rts

; r_blit : A = 0 : rectangle de la mémoire (hs ; lignes de r_bst octets)
;   vers l'écran, coin en (h_x1, h_y1), h_x2 colonnes sur h_y2 lignes ;
;   A = 1 : de l'écran vers la mémoire
r_blit
.(
        sta rz_op
        lda h_x2
        sta rz_bn
        lda h_y1
        sta rz_y
        lda h_y2
        sta rz_c
        beq rz_cp9
rz_cp1  ldy rz_y
        jsr rz_ra               ; hq = ligne de l'écran
        lda rz_op
        bne rz_cp2
        lda hs                  ; mémoire -> écran
        sta hp
        lda hs+1
        sta hp+1
        jmp rz_cp3
rz_cp2  jsr rz_q2p              ; écran -> mémoire
        lda hs
        sta hq
        lda hs+1
        sta hq+1
rz_cp3  jsr rz_mv
        clc
        lda hs
        adc r_bst
        sta hs
        lda hs+1
        adc r_bst+1
        sta hs+1
        inc rz_y
        dec rz_c
        bne rz_cp1
rz_cp9  rts
.)

; r_scrl : A = 0 SCROLH, 1 SCROLV, 2 ROTH, 3 ROTV : le rectangle
;   (h_x1, h_y1)-(h_x2, h_y2) glisse de r_sn cases (signé : > 0 vers la
;   droite ou vers le bas). Défilement : les cases libérées reçoivent
;   r_sf ; rotation : ce qui sort d'un côté rentre de l'autre
r_scrl
.(
        sta rz_op
        lda h_x2
        sec
        sbc h_x1
        sta rz_w
        inc rz_w
        lda h_y2
        sec
        sbc h_y1
        sta rz_h
        inc rz_h
        lda r_sn+1              ; |n| -> rz_bt, signe -> rz_sg (bit 7)
        sta rz_sg
        bpl rz_s1
        lda #0
        sec
        sbc r_sn
        sta rz_bt
        lda #0
        sbc r_sn+1
        sta rz_bt+1
        jmp rz_s2
rz_s1   lda r_sn
        sta rz_bt
        lda r_sn+1
        sta rz_bt+1
rz_s2   lda rz_op               ; taille dans le sens du glissement
        lsr
        lda rz_w
        bcc rz_s3
        lda rz_h
rz_s3   sta rz_z
        lda rz_op
        and #2
        beq rz_s5
rz_s4   lda rz_bt                ; rotation : |n| modulo la taille
        sec
        sbc rz_z
        tax
        lda rz_bt+1
        sbc #0
        bcc rz_s6
        sta rz_bt+1
        stx rz_bt
        jmp rz_s4
rz_s5   lda rz_bt+1              ; défilement : |n| au plus la taille
        bne rz_s5a
        lda rz_bt
        cmp rz_z
        bcc rz_s6
rz_s5a  lda rz_z
        sta rz_bt
rz_s6   lda rz_bt
        sta rz_k
        beq rz_s9               ; rien à faire
        lda rz_op
        lsr
        bcs rz_s8
        jmp rz_horz
rz_s8   jmp rz_vert
rz_s9   rts
.)

; rz_horz : ligne par ligne, par le tampon h_buf (40 octets)
rz_horz
.(
        lda h_y1
        sta rz_y
rz_h1   ldy rz_y
        jsr rz_ra               ; ligne -> tampon
        lda hq
        sta rz_rw
        lda hq+1
        sta rz_rw+1
        jsr rz_q2p
        lda #0
        jsr rz_qb
        lda rz_w
        sta rz_bn
        jsr rz_mv
        lda rz_w                ; ce qui reste dans le rectangle
        sec
        sbc rz_k
        sta rz_bn
        bit rz_sg
        bmi rz_h2
        lda #0                  ; vers la droite : tampon -> ligne + k
        jsr rz_pb
        lda rz_k
        jsr rz_rq
        jmp rz_h3
rz_h2   lda rz_k                ; vers la gauche : tampon + k -> ligne
        jsr rz_pb
        lda #0
        jsr rz_rq
rz_h3   jsr rz_mv
        lda rz_k                ; les k cases libérées
        sta rz_bn
        lda rz_w
        sec
        sbc rz_k
        bit rz_sg
        bmi rz_h4
        jsr rz_pb               ; droite : tampon + w - k -> début
        lda #0
        jsr rz_rq
        jmp rz_h5
rz_h4   jsr rz_rq               ; gauche : tampon -> ligne + w - k
        lda #0
        jsr rz_pb
rz_h5   jsr rz_mvr
        lda rz_y
        cmp h_y2
        beq rz_h9
        inc rz_y
        jmp rz_h1
rz_h9   rts
.)

; rz_vert : lignes entières recopiées ; rotation : k fois d'une ligne,
;   dans le sens le plus court, la ligne qui sort passant par h_buf
rz_vert
.(
        lda rz_op
        and #2
        beq rz_v5
        lda rz_h                ; h - k < k : k' = h - k dans l'autre sens
        sec
        sbc rz_k
        cmp rz_k
        bcs rz_v1
        sta rz_k
        lda rz_sg
        eor #$80
        sta rz_sg
rz_v1   lda rz_k
        sta rz_c
        lda #1
        sta rz_k
rz_v2   jsr rz_eout             ; ligne qui sort -> tampon
        jsr rz_ra
        jsr rz_q2p
        lda #0
        jsr rz_qb
        jsr rz_mv
        jsr rz_vcp
        jsr rz_ein              ; tampon -> ligne qui entre
        jsr rz_ra
        lda #0
        jsr rz_pb
        jsr rz_mv
        dec rz_c
        bne rz_v2
        rts
rz_v5   jsr rz_vcp              ; défilement, puis k lignes remplies
        lda rz_k
        sta rz_c
        lda h_y1
        bit rz_sg
        bmi rz_v6
        sta rz_y                ; vers le bas : à partir de y1
        jmp rz_v7
rz_v6   lda h_y2                ; vers le haut : de y2 - k + 1 à y2
        sec
        sbc rz_k
        sta rz_y
        inc rz_y
rz_v7   ldy rz_y
        jsr rz_ra
        jsr rz_fl
        inc rz_y
        dec rz_c
        bne rz_v7
        rts
.)
; rz_eout / rz_ein : Y = ligne qui sort, qui entre ; rz_bn = largeur
rz_eout lda rz_w
        sta rz_bn
        ldy h_y2
        bit rz_sg
        bpl rz_eo1
        ldy h_y1
rz_eo1  rts
rz_ein  ldy h_y1
        bit rz_sg
        bpl rz_ei1
        ldy h_y2
rz_ei1  rts

; rz_vcp : h - k lignes recopiées de k lignes plus haut (vers le bas)
;   ou plus bas (vers le haut)
rz_vcp
.(
        lda rz_w
        sta rz_bn
        lda rz_h
        sec
        sbc rz_k
        beq rz_vc9
        sta rz_bc2
        lda h_y2                ; vers le bas : de y2 en remontant
        bit rz_sg
        bpl rz_vc1
        lda h_y1                ; vers le haut : de y1 en descendant
rz_vc1  sta rz_y
rz_vc2  lda rz_y                ; source : y - k (bas) ou y + k (haut)
        bit rz_sg
        bmi rz_vc3
        sec
        sbc rz_k
        jmp rz_vc4
rz_vc3  clc
        adc rz_k
rz_vc4  tay
        jsr rz_ra
        jsr rz_q2p
        ldy rz_y
        jsr rz_ra
        jsr rz_mv
        bit rz_sg
        bmi rz_vc5
        dec rz_y
        jmp rz_vc6
rz_vc5  inc rz_y
rz_vc6  dec rz_bc2
        bne rz_vc2
rz_vc9  rts
.)

; variables des rectangles
r_sn    .word 0         ; glissement de r_scrl (signé)
r_sf    .byt 32         ; octet des cases libérées
r_bst   .word 0         ; r_blit : octets par ligne de la mémoire
rz_op   .byt 0
rz_w    .byt 0
rz_h    .byt 0
rz_k    .byt 0
rz_bn   .byt 0
rz_y    .byt 0
rz_c    .byt 0
rz_bc2  .byt 0
rz_z    .byt 0
rz_sg   .byt 0
rz_bt   .word 0
rz_rw   .word 0
