; =====================================================================
;  grx.inc — bibliothèque d'exécution des programmes traduits par
;  GRXASM NOM (NOM.GRX -> NOM.ASM). Incluse par NOM.ASM, avant
;  hires.inc ; jamais assemblée seule.
;
;  Modèle : la valeur d'une expression est dans g_ev ; l'opérande de
;  gauche d'une opération dans g_et (g_pop le reprend sur la pile des
;  valeurs, où g_push l'a mis). Variables V_A à V_Z (2 octets) ; celles
;  à deux caractères (V_AX, V_A1...) sont écrites par GRXASM dans NOM.ASM.
;  Une boucle a 6 octets Bn : compte (REPEAT), ou arrivée, pas et adresse
;  de la variable (FOR).
;  Les textes (GTEXT, ECHO) et les noms d'images (GLOAD, GSAVE) suivent
;  l'appel dans le code (g_str les y prend).
;  Page zéro : $10-$2C. ESC n'arrête jamais le programme : INKEY, GET
;  et WAIT le rendent comme une autre touche (27), INPUT l'ignore.
; =====================================================================

g_ev    = $10           ; valeur (2 octets)
g_et    = $12           ; opérande de gauche (2 octets)
g_mt    = $14           ; multiplication, comparaison (2 octets)
g_mr    = $16           ; reste (2 octets)
g_sg    = $18           ; signes de la division (2 octets)
g_vsp   = $1C           ; pile des valeurs
g_pk    = $1D           ; touche gardée par le test d'ESC
g_sp    = $1E           ; pile du 6502 au lancement
g_gd    = $1F
g_t     = $20           ; adresse du texte suivant l'appel (2 octets)
g_ip    = $22           ; (2 octets)
g_lx    = $24
g_fl    = $25
g_hk    = $26           ; INKEY : code de la dernière touche lue
g_hi    = $27           ;   et sa place dans la matrice (KB_HELD)
g_seed  = $28           ; hasard : xorshift 32 bits (4 octets)
g_rok   = $2C           ; 0 : graine pas encore tirée (premier RND)

g_init
.(
        tsx                     ; pile telle qu'au lancement du programme
        inx
        inx
        stx g_sp
        lda #0
        sta g_rok               ; graine tirée au premier RND
        sta g_vsp
        sta g_pk
        sta g_hk
        ldx #51
z       sta g_vars,x
        dex
        bpl z
        jsr h_init
        lda #G_GETMODE          ; lancé en mode SPLIT : on y reste
        jsr h_gfx
        cmp #1
        bne r
        lda #128
        sta h_lines
r       rts
.)

; g_end : fin normale : HIRES et LORES rendent la console, sans attendre
g_end   jsr g_totext
        ldx g_sp
        txs
        rts

; g_totext : quitte le HIRES plein écran ou le LORES (console rendue)
g_totext
.(
        lda s_hst               ; jeu secondaire redessiné par SPR.INC :
        beq tn                  ;   l'historique des lignes est vidé
        lda #0
        sta $BA80
tn      lda h_lo
        bne t
        lda h_lines
        cmp #200
        bne r
t       jmp h_text
r       rts
.)

; a_fail : erreur ou ESC dans ANIM (anim.inc, inclus seulement si le
;   programme anime) : même arrêt que les autres erreurs
a_fail  = g_stop

; arr.inc (incluse seulement si le programme a des tableaux ou des
;   chaînes) : ses valeurs sont g_et et g_ev, ses erreurs s'arrêtent ici
r_i     = g_et
r_j     = g_ev
r_fail
        pha
        tya
        pha
        jsr g_totext
        lda #<g_m_err
        ldy #>g_m_err
        jsr g_puts
        pla
        tay
        pla
        jmp g_stop
; r_esc : ESC pendant INPUT (arr.inc) : ignoré ; le programme traduit
;   ne s'arrête jamais sur ESC (A gardé)
r_esc   rts

; a_grx : ANIM traduit (A = passages ; nom après l'appel) : se sert de
;   ANIM.INC (a_play, a_fcb, a_sig, a_msg), inclus si le programme anime
a_grx
.(
        sta a_n2
        pla                     ; adresse du nom - 1
        sta hs
        pla
        sta hs+1
        ldy #12
hz_c    lda (hs),y
        sta a_fcb-1,y
        dey
        bne hz_c
        clc                     ; retour après le nom
        lda hs
        adc #12
        tax
        lda hs+1
        adc #0
        pha
        txa
        pha
        lda a_fcb+9             ; type ANI par défaut
        cmp #" "
        bne hz_ty
        ldx #2
hz_t    lda a_sig,x
        sta a_fcb+9,x
        dex
        bpl hz_t
hz_ty   lda h_lines             ; depuis le texte : plein écran
        bne hz_md
        jsr h_full
        jmp hz_go
hz_md   cmp #200
        beq hz_go
        lda #<a_mh              ; SPLIT : refusé
        ldy #>a_mh
        jmp a_fail
hz_go   lda #<a_fcb
        ldy #>a_fcb
        ldx a_n2
        jsr a_play
        bcs hz_er               ; ESC finit l'animation comme une
        rts                     ;   autre touche
hz_er   jsr a_msg
        jmp a_fail
.)

a_n2    .byt 0

; g_stop : message A/Y (0 à la fin), puis fin du programme
g_stop
        pha
        tya
        pha
        jsr g_totext            ; pas de console en HIRES ni en LORES
        pla
        tay
        pla
        jsr g_puts
        jsr g_crlf
        ldx g_sp
        txs
        rts

g_getkey
        lda g_pk
        beq gk1
        ldx #0
        stx g_pk
        rts
gk1     jmp h_key

; ---------------------------------------------------------------------
; Pile des valeurs et opérations (g_et op g_ev -> g_ev)
; ---------------------------------------------------------------------
g_push  ldy g_vsp                ; (profondeur vérifiée par GRXASM)
        lda g_ev
        sta g_vlo,y
        lda g_ev+1
        sta g_vhi,y
        inc g_vsp
        rts

g_pop   dec g_vsp
        ldy g_vsp
        lda g_vlo,y
        sta g_et
        lda g_vhi,y
        sta g_et+1
        rts

g_add   clc
        lda g_et
        adc g_ev
        sta g_ev
        lda g_et+1
        adc g_ev+1
        sta g_ev+1
        rts

g_sub   sec
        lda g_et
        sbc g_ev
        sta g_ev
        lda g_et+1
        sbc g_ev+1
        sta g_ev+1
        rts

; g_and, g_or (comme g_cmp) : Z=1 si le résultat est nul (IF traduit)
g_and   lda g_et
        and g_ev
        sta g_ev
        lda g_et+1
        and g_ev+1
        sta g_ev+1
        ora g_ev
        rts

g_or    lda g_et
        ora g_ev
        sta g_ev
        lda g_et+1
        ora g_ev+1
        sta g_ev+1
        ora g_ev
        rts

; g_rsub : g_ev <- g_ev - g_et (opérandes inversés : X - Y, Y dans g_et)
g_rsub  sec
        lda g_ev
        sbc g_et
        sta g_ev
        lda g_ev+1
        sbc g_et+1
        sta g_ev+1
        rts

g_neg   sec
        lda #0
        sbc g_ev
        sta g_ev
        lda #0
        sbc g_ev+1
        sta g_ev+1
        rts

; g_mul : g_ev <- g_et * g_ev (16 bits bas)
g_mul
.(
        lda #0
        sta g_mt
        sta g_mt+1
        ldx #16
loop    lsr g_ev+1
        ror g_ev
        bcc no
        clc
        lda g_mt
        adc g_et
        sta g_mt
        lda g_mt+1
        adc g_et+1
        sta g_mt+1
no      asl g_et
        rol g_et+1
        dex
        bne loop
        lda g_mt
        sta g_ev
        lda g_mt+1
        sta g_ev+1
        rts
.)

; g_udiv : g_et / g_ev (non signés) -> g_et quotient, g_mr reste
g_udiv
.(
        lda #0
        sta g_mr
        sta g_mr+1
        ldx #16
loop    asl g_et
        rol g_et+1
        rol g_mr
        rol g_mr+1
        sec
        lda g_mr
        sbc g_ev
        tay
        lda g_mr+1
        sbc g_ev+1
        bcc no
        sta g_mr+1
        sty g_mr
        inc g_et
no      dex
        bne loop
        rts
.)

; g_div / g_mod : division signée (quotient tronqué vers 0, reste du
;   signe du dividende)
g_mod   jsr g_sdiv
        lda g_mr
        sta g_ev
        lda g_mr+1
        sta g_ev+1
        rts
g_div
g_sdiv
.(
        lda g_et+1              ; (division par zéro : non vérifiée)
        sta g_sg
        eor g_ev+1
        sta g_sg+1
        lda g_et+1
        bpl p1
        sec
        lda #0
        sbc g_et
        sta g_et
        lda #0
        sbc g_et+1
        sta g_et+1
p1      lda g_ev+1
        bpl p2
        jsr g_neg
p2      jsr g_udiv
        lda g_et
        sta g_ev
        lda g_et+1
        sta g_ev+1
        bit g_sg+1
        bpl p3
        jsr g_neg
p3      bit g_sg
        bpl r
        sec
        lda #0
        sbc g_mr
        sta g_mr
        lda #0
        sbc g_mr+1
        sta g_mr+1
r       rts
.)

; g_cmp : X = 1 =, 2 <>, 3 <, 4 <=, 5 >, 6 >= ; g_ev <- 1 ou 0
g_cmp
.(
        sec
        lda g_et
        sbc g_ev
        sta g_mt
        lda g_et+1
        sbc g_ev+1
        sta g_mt+1
        ora g_mt                ; (ORA et LDA laissent V)
        sta g_mt
        lda g_mt+1
        bvc nv
        eor #$80
nv      and #$80
        sta g_mt+1              ; $80 si g_et < g_ev
        lda #0
        sta g_ev+1
        cpx #1
        beq eq
        cpx #2
        beq ne
        cpx #3
        beq lt
        cpx #4
        beq le
        cpx #5
        beq gt
        lda g_mt+1              ; >=
        beq yes
        bne no
eq      lda g_mt
        beq yes
        bne no
ne      lda g_mt
        bne yes
        beq no
lt      lda g_mt+1
        bne yes
        beq no
le      lda g_mt+1
        bne yes
        lda g_mt
        beq yes
        bne no
gt      lda g_mt+1
        bne no
        lda g_mt
        bne yes
no      lda #0
        sta g_ev
        rts
yes     lda #1
        sta g_ev
        rts
.)

; ---------------------------------------------------------------------
; Fonctions
; ---------------------------------------------------------------------
; g_rnd : g_ev <- nombre au hasard de 0 à g_ev - 1 (0 si g_ev <= 0)
;   Graine : le compteur 50 Hz au premier appel, puis 4 tours pour que
;   deux tirages proches divergent. Générateur : step.
g_rnd
.(
        lda g_ev+1
        bmi zero
        ora g_ev
        beq zero
        lda g_rok
        bne go
        inc g_rok
        lda SYS_TICKS
        sta g_seed
        lda SYS_TICKS+1
        sta g_seed+1
        lda #$5A                ; jamais nulle
        sta g_seed+2
        lda #$A5
        sta g_seed+3
        ldx #4
w       jsr step
        dex
        bne w
go      jsr step
        lda g_seed+2            ; mot haut, 15 bits, pour la division
        sta g_et
        lda g_seed+3
        and #$7F
        sta g_et+1
        lda g_ev+1              ; n < 256 : (mot haut * n) / 65536, sans
        bne big                 ;   division
        sta g_mt
        ldx #8
l       lsr g_ev
        bcc n
        pha
        clc
        lda g_mt
        adc g_seed+2
        sta g_mt
        pla
        adc g_seed+3
n       ror
        ror g_mt
        dex
        bne l
        sta g_ev
        rts
big     jsr g_udiv              ; sinon : reste de la division
        lda g_mr
        sta g_ev
        lda g_mr+1
        sta g_ev+1
        rts
zero    lda #0
        sta g_ev
        sta g_ev+1
        rts

; step : xorshift 32 bits (8, 9, 23) : x ^= x << 8 ; x ^= x >> 9 ;
;   x ^= x << 23 ; période 2^32 - 1 (X conservé)
step    lda g_seed+3
        eor g_seed+2
        sta g_seed+3
        lda g_seed+2
        eor g_seed+1
        sta g_seed+2
        lda g_seed+1
        eor g_seed
        sta g_seed+1
        lda g_seed+2
        lsr
        lda g_seed+1
        ror
        eor g_seed
        sta g_seed
        lda g_seed+3
        lsr
        lda g_seed+2
        ror
        eor g_seed+1
        sta g_seed+1
        lda g_seed+3
        lsr
        eor g_seed+2
        sta g_seed+2
        lda g_seed+1
        lsr
        lda g_seed
        ror
        eor g_seed+3
        sta g_seed+3
        lda #0
        ror
        eor g_seed+2
        sta g_seed+2
        rts
.)

g_abs   lda g_ev+1
        bpl ga1
        jmp g_neg
ga1     rts

; g_point : g_et = x, g_ev = y -> 1 si le point est allumé
g_point
.(
        lda h_lines
        beq zero
        lda g_et+1
        ora g_ev+1
        bne zero
        lda h_x1                ; les paramètres en cours sont gardés
        pha
        lda h_y1
        pha
        lda g_et
        sta h_x1
        lda g_ev
        sta h_y1
        jsr h_point
        sta g_ev
        pla
        sta h_y1
        pla
        sta h_x1
        lda #0
        sta g_ev+1
        rts
zero    lda #0
        sta g_ev
        sta g_ev+1
        rts
.)

; g_inkey : touche (0 si aucune), sans attendre et sans délai de
;   répétition : une touche tapée depuis le dernier INKEY (le tampon est
;   vidé ; ESC est une touche comme une autre : 27), sinon celle qui est
;   encore enfoncée (KB_HELD)
g_inkey
.(
        lda g_pk
        ldx #0
        stx g_pk
v       sta g_ev
        jsr B_CONST
        beq e
        jsr h_key
        jmp v
e       lda KB_HELD
        ldx g_ev
        beq h
        sta g_hi                ; touche neuve : on retient sa place
        stx g_hk
        bne r
h       cmp #$FF                ; rien de neuf : la même touche
        beq r                   ; encore enfoncée ?
        cmp g_hi
        bne r
        ldx g_hk
        stx g_ev
r       lda #0
        sta g_ev+1
        rts
.)

; ---------------------------------------------------------------------
; Commandes
; ---------------------------------------------------------------------
g_cls   lda h_lines             ; rien hors du mode HIRES ou SPLIT
        beq gc_r
        jmp h_cls
gc_r    rts

g_print
        lda h_lo
        beq gp_c
        jsr g_fmt               ; LORES : au curseur, sans passer à la ligne
        lda #<g_num
        ldy #>g_num
        jmp h_lstr
gp_c    lda h_lines
        cmp #200
        beq gp_r
        jsr g_fmt
        lda #<g_num
        ldy #>g_num
        jsr g_puts
        jmp g_crlf
gp_r    rts

g_gnum  jsr g_fmt
        lda #<g_num
        ldy #>g_num
        jmp h_print

; g_str : (à appeler en premier par la routine) g_t <- adresse du texte
;   qui suit l'appel de la routine ; celle-ci reviendra après lui
; g_nm : de même pour un nom d'image (lecteur + 11 caractères, sans 0
;   final : le lecteur courant s'écrit 0)
g_nm    lda #11                 ; dernier octet du nom
        bne g_st0
g_str   lda #0                  ; texte : jusqu'au 0
g_st0
.(
        sta g_ln
        pla                     ; notre retour
        sta g_ip
        pla
        sta g_ip+1
        pla                     ; retour de la routine : texte - 1
        sta g_t
        pla
        sta g_t+1
        inc g_t
        bne t1
        inc g_t+1
t1      ldy g_ln                ; fin du nom, ou du texte
        bne e
l       lda (g_t),y
        beq e
        iny
        bne l
e       tya                     ; retour de la routine : le 0 final
        clc
        adc g_t
        tax
        lda g_t+1
        adc #0
        pha
        txa
        pha
        lda g_ip+1              ; et notre retour
        pha
        lda g_ip
        pha
        rts
.)

g_gtext jsr g_str
        lda g_t
        ldy g_t+1
        jmp h_print

g_echo  jsr g_str
        lda h_lo
        bne g_eclo
        lda h_lines
        cmp #200
        beq ge_r
        lda g_t
        ldy g_t+1
        jsr g_puts
        jmp g_crlf
ge_r    rts

; g_eclo : ECHO en LORES : au curseur, sans déborder ; vide : ligne
;   suivante ; entre guillemets : tel quel
g_eclo
.(
        ldy #0
        lda (g_t),y
        bne t
        jmp h_lnl
t       cmp #34
        bne l2
        iny
l1      lda (g_t),y
        beq r
        cmp #34
        beq r
        jsr h_lput
        iny
        bne l1
l2      lda (g_t),y
        beq r
        jsr h_lput
        iny
        bne l2
r       rts
.)

; ---------------------------------------------------------------------
; LORES (h_x1 = colonne, h_y1 = ligne)
; ---------------------------------------------------------------------
g_lcls
.(
        lda h_lo
        beq c
        jmp h_lcls
c       lda h_lines             ; hors du LORES : la console (pas en HIRES)
        cmp #200
        beq r
        lda #12
        jmp g_putc
r       rts
.)
; g_paste, g_grab : A/Y = descripteur du tableau $ ; ligne puis colonne
;   sur la pile des valeurs ; coin h_x1 h_y1, largeur h_x2, hauteur h_y2
g_grab  ldx #1
        .byt $2C                ; (BIT abs : saute ldx #0)
g_paste ldx #0
        stx g_gd
        pha
        tya
        pha
        jsr g_pop               ; colonne -> g_ev
        lda g_et
        sta g_ev
        lda g_et+1
        sta g_ev+1
        jsr g_pop               ; ligne -> g_et
        pla
        tay
        pla
        jsr r_ea2
        ldy #4                  ; octets par ligne du tableau
        lda (r_dp),y
        sta r_bst
        iny
        lda (r_dp),y
        sta r_bst+1
        lda r_sa
        sta hs
        lda r_sa+1
        sta hs+1
        lda g_gd
        jmp r_blit
; g_tmap : A/Y = descripteur de la carte ; X puis Y sur la pile des
;   valeurs ; fenêtre h_x1 h_y1 h_x2 h_y2 (SPR.INC : t_map)
g_tmap  pha
        tya
        pha
        jsr g_pop               ; Y
        lda g_et
        sta t_y
        lda g_et+1
        sta t_y+1
        jsr g_pop               ; X
        lda g_et
        sta t_x
        lda g_et+1
        sta t_x+1
        pla
        tay
        pla
        jmp t_map
g_spc   lda h_x1
        ldx h_y1
        jmp h_lspc
; g_get : attend une touche -> g_ev (ESC : 27)
g_get   jsr g_wait
        sta g_ev
        lda #0
        sta g_ev+1
        rts
; g_scrn : g_et = colonne, g_ev = ligne -> octet de la case
g_scrn
.(
        lda h_x1                ; les paramètres en cours sont gardés
        pha
        lda h_y1
        pha
        lda g_et
        sta h_x1
        lda g_ev
        sta h_y1
        jsr h_scrn
        sta g_ev
        pla
        sta h_y1
        pla
        sta h_x1
        lda #0
        sta g_ev+1
        rts
.)

; g_wait : attend une touche -> A (ESC compris : le programme traduit
;   ne s'arrête jamais sur ESC)
g_wait  jmp g_getkey

; g_delay : g_ev cinquantièmes de seconde
g_delay
.(
        clc
        lda SYS_TICKS
        adc g_ev
        sta g_mt
        lda SYS_TICKS+1
        adc g_ev+1
        sta g_mt+1
w       sec
        lda SYS_TICKS
        sbc g_mt
        lda SYS_TICKS+1
        sbc g_mt+1
        bmi w
        rts
.)

; g_gload / g_gsave : nom (lecteur, 8 + 3 caractères) après l'appel ;
;   type vide : .HIR en HIRES, .IMG en SPLIT ; depuis le mode texte,
;   GLOAD choisit le mode d'après le type (HIR par défaut)
; g_fnm : nom d'un fichier de données (après l'appel) -> g_fcbuf, le
;   FCB de FIL.INC (incluse seulement si le programme s'en sert)
g_fnm   jsr g_nm
        jmp g_fcb
f_fcb   = g_fcbuf
f_fmt   = g_fmt
f_nbuf  = g_num
f_mlo   = g_m_nolo+g_m_el       ; (sans « Erreur : » : g_m_el caractères)
f_mful  = g_m_full+g_m_el
f_mro   = g_m_ro+g_m_el
f_mdir  = g_m_dir+g_m_el

g_gload
.(
        jsr g_nm
        jsr g_fcb
        lda h_lines
        bne mode
        jsr g_isimg
        beq spl
        jsr h_full
        jmp ld
spl     lda h_lo                ; depuis le LORES : la console d'abord
        beq spl1
        jsr h_text
spl1    lda #128
        sta h_lines
        jmp ld
mode    jsr g_deftype
ld      lda #<g_fcbuf
        ldy #>g_fcbuf
        jsr h_load
        cmp #0
        beq r
        lda h_lines             ; HIRES plein (pour le BDOS, mode texte) :
        cmp #200                ;   g_stop le quittera avant le message
        beq nf
        lda #G_GETMODE          ; SPLIT sans image : on est resté en texte
        jsr h_gfx
        cmp #0
        bne nf
        sta h_lines
nf      lda #<g_m_noimg
        ldy #>g_m_noimg
        jmp g_stop
r       rts
.)

g_gsave
.(
        jsr g_nm
        jsr g_fcb
        lda h_lines
        beq r
        jsr g_deftype
        lda #<g_fcbuf
        ldy #>g_fcbuf
        jsr h_save
        cmp #0
        beq r
        lda #<g_m_full
        ldy #>g_m_full
        jmp g_stop
r       rts
.)

; g_fcb : 12 octets du texte (g_t) -> g_fcbuf, le reste à 0
g_fcb
.(
        ldy #0
l       lda (g_t),y
        sta g_fcbuf,y
        iny
        cpy #12
        bne l
        lda #0
z       sta g_fcbuf,y
        iny
        cpy #36
        bne z
        rts
.)

g_deftype
.(
        lda g_fcbuf+9
        cmp #" "
        bne r
        ldx #2
        ldy #2
        lda h_lines
        cmp #200
        bne l
        ldy #5
l       lda g_timg,y
        sta g_fcbuf+9,x
        dey
        dex
        bpl l
r       rts
.)

; g_isimg : Z=1 si le type est IMG (type vide : HIR, mis ici)
g_isimg
.(
        lda g_fcbuf+9
        cmp #" "
        bne t
        ldx #2
d       lda g_thir,x
        sta g_fcbuf+9,x
        dex
        bpl d
t       ldx #2
l       lda g_fcbuf+9,x
        cmp g_timg,x
        bne r
        dex
        bpl l
        lda #0
r       rts
.)

; ---------------------------------------------------------------------
; Boucles
; ---------------------------------------------------------------------
; g_rept : A/Y = compte (REPEAT) ; C=1 s'il est <= 0, sinon il diminue
;   de 1 et C=0
g_rept
.(
        sta g_t
        sty g_t+1
        ldy #1
        lda (g_t),y
        bmi end
        dey
        ora (g_t),y
        beq end
        lda (g_t),y             ; compte - 1
        sec
        sbc #1
        sta (g_t),y
        iny
        lda (g_t),y
        sbc #0
        sta (g_t),y
        clc
        rts
end     sec
        rts
.)

; g_forok : A/Y = bloc de la boucle (arrivée, pas, adresse de la
;   variable) ; C=1 si la variable a
;   dépassé l'arrivée (pas > 0 : var > arrivée ; pas < 0 : var < arrivée)
g_forok
.(
        sta g_t
        sty g_t+1
        jsr g_fvar              ; (pas nul : non vérifié)              ; g_ip <- adresse de la variable
        sec                     ; var - arrivée (signé)
        ldy #0
        lda (g_ip),y
        sbc (g_t),y
        sta g_mt
        iny
        lda (g_ip),y
        sbc (g_t),y
        sta g_mt+1
        ora g_mt
        sta g_gd                ; 0 : égaux
        lda g_mt+1
        bvc nv
        eor #$80
nv      sta g_mt+1              ; bit 7 : var < arrivée
        ldy #3
        lda (g_t),y
        bmi down
        lda g_gd
        beq in
        lda g_mt+1
        bmi in
        sec
        rts
down    lda g_mt+1
        bpl in
        sec
        rts
in      clc
        rts
.)

; g_forstep : variable += pas (bloc A/Y) ; C=1 en cas de dépassement (fin)
g_forstep
.(
        sta g_t
        sty g_t+1
        jsr g_fvar
        ldy #0
        clc
        lda (g_ip),y
        ldy #2
        adc (g_t),y
        ldy #0
        sta (g_ip),y
        iny
        lda (g_ip),y
        ldy #3
        adc (g_t),y
        ldy #1
        sta (g_ip),y
        clc
        bvc r
        sec
r       rts
.)

; g_fvar : g_ip <- adresse de la variable de la boucle (bloc g_t, +4)
g_fvar  ldy #4
        lda (g_t),y
        sta g_ip
        iny
        lda (g_t),y
        sta g_ip+1
        rts

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
g_putc  ldx #F_CONOUT
        jmp BDOS
g_crlf  lda #13
        jsr g_putc
        lda #10
        jmp g_putc

g_puts
.(
        sta g_ip
        sty g_ip+1
        ldy #0
loop    lda (g_ip),y
        beq r
        sty g_gd
        jsr g_putc
        ldy g_gd
        iny
        bne loop
r       rts
.)

; g_fmt : g_ev (signé) -> g_num, en décimal
g_fmt
.(
        ldy #0
        lda g_ev+1
        bpl pos
        jsr g_neg
        lda #"-"
        sta g_num
        iny
pos     sty g_gd
        lda #0
        sta g_lx
        ldx #0
dig     ldy #0
sub     sec
        lda g_ev
        sbc g_dlo,x
        pha
        lda g_ev+1
        sbc g_dhi,x
        bcc dn
        sta g_ev+1
        pla
        sta g_ev
        iny
        bne sub
dn      pla
        tya
        bne show
        lda g_lx
        beq nx
        tya
show    ora #"0"
        ldy g_gd
        sta g_num,y
        inc g_gd
        sta g_lx
nx      inx
        cpx #4
        bne dig
        lda g_ev
        ora #"0"
        ldy g_gd
        sta g_num,y
        iny
        lda #0
        sta g_num,y
        rts
.)
g_dlo   .byt <10000,<1000,<100,<10
g_dhi   .byt >10000,>1000,>100,>10

g_timg  .asc "IMG"
g_thir  .asc "HIR"
;#msg grx.msg

g_num   .dsb 8,0
g_fcbuf .dsb 36,0
g_ln    .byt 0
s_hst   .byt 0          ; 1 : jeu secondaire redessiné (SPR.INC)
g_vlo   .dsb 24,0
g_vhi   .dsb 24,0
g_vars  .dsb 52,0
V_A     = g_vars
V_B     = g_vars+2
V_C     = g_vars+4
V_D     = g_vars+6
V_E     = g_vars+8
V_F     = g_vars+10
V_G     = g_vars+12
V_H     = g_vars+14
V_I     = g_vars+16
V_J     = g_vars+18
V_K     = g_vars+20
V_L     = g_vars+22
V_M     = g_vars+24
V_N     = g_vars+26
V_O     = g_vars+28
V_P     = g_vars+30
V_Q     = g_vars+32
V_R     = g_vars+34
V_S     = g_vars+36
V_T     = g_vars+38
V_U     = g_vars+40
V_V     = g_vars+42
V_W     = g_vars+44
V_X     = g_vars+46
V_Y     = g_vars+48
V_Z     = g_vars+50
