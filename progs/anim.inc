; =====================================================================
;  anim.inc — animations HIRES plein écran (.ANI) pour les programmes
;  .COM (bibliothèque ; à inclure AVANT hires.inc, qui reste à la fin)
;
;  Fichier .ANI (fabriqué par tools/mkanim.py) : en-tête de 16 octets
;  ("ANI", 1, nombre d'images, drapeaux : bit 0 = image de retour,
;  0, taille des données, 6 x 0), puis chaque image : délai en 1/50 s,
;  longueur (2 octets), flux décompressé par h_unz (hires.inc). L'image 1
;  est codée par rapport à l'écran effacé, les autres par rapport à la
;  précédente ; l'image de retour ramène de la dernière à la première.
;
;  a_play    A/Y = FCB (nom et type), X = passages (0 : jusqu'à une
;            touche). Le programme est en HIRES plein écran. Le fichier
;            entier est chargé en h_zbuf (jusqu'à $A000).
;            -> C=1 : erreur, A = 1 absent, 3 trop grand, 4 pas une
;               animation ; C=0 : A = 0 (passages finis, la dernière image
;               reste à l'écran) ou la touche qui a arrêté.
;            Flèches gauche / droite : la phase du timer recule ou avance
;            de 8 lignes (calage de la ligne de déchirure, à la main).
;  a_msg     A = code d'erreur -> A/Y = message (terminé par 0)
;  a_grx     pour GRAPHER /A : A = passages, nom après l'appel (lecteur,
;            puis 11 caractères) ; une erreur ou ESC appelle a_fail (A/Y =
;            message), que le programme définit.
;
;  Cadence : chaque image s'affiche au top 50 Hz qui suit son délai (pas
;  de dérive si le décodage déborde). Pendant l'animation, T1 tourne à
;  19 968 cycles, la durée d'une trame vidéo (312 lignes x 64) : la
;  ligne de déchirure ne bouge plus. Il est remis à 20 000 à la fin
;  (le démarrage à chaud le remet aussi).
; =====================================================================

A_T1LL  = $0306         ; latch du timer 1 du 6522
A_LOCK  = 19966         ; période 19 968 cycles = une trame vidéo
A_SYS   = 19998         ; réglage du système (src/hw.inc, T1_PERIOD)
A_STEP  = 512           ; 8 lignes de 64 cycles

a_play
.(
        stx a_n
        sta hq
        sty hq+1
        jsr h_zread
        cmp #0
        beq hz_ld
        sec
        rts
hz_ld   lda hs                  ; fin des données lues
        sta a_e
        lda hs+1
        sta a_e+1
        lda h_zbuf              ; en-tête
        sta hs
        lda h_zbuf+1
        sta hs+1
        ldy #3
hz_sg   lda (hs),y
        cmp a_sig,y
        bne hz_bad
        dey
        bpl hz_sg
        ldy #4
        lda (hs),y
        sta a_nf
        iny
        lda (hs),y
        sta a_nf+1
        ora a_nf
        beq hz_bad              ; aucune image
        iny
        lda (hs),y
        and #1
        sta a_lp
        clc                     ; images : après les 16 octets
        lda hs
        adc #16
        sta a_f0
        lda hs+1
        adc #0
        sta a_f0+1
        ldy #8                  ; fin des images <= fin des données lues
        clc
        lda a_f0
        adc (hs),y
        tax
        iny
        lda a_f0+1
        adc (hs),y
        bcs hz_bad
        cmp a_e+1
        bcc hz_go
        bne hz_bad
        cpx a_e
        bcc hz_go
        beq hz_go
hz_bad  lda #4
        sec
        rts
hz_go   lda #<A_LOCK            ; timer calé sur la trame vidéo
        sta A_T1LL
        lda #>A_LOCK
        sta A_T1LL+1
        lda SYS_TICKS           ; première image : au prochain top
        sta a_tg
        lda SYS_TICKS+1
        sta a_tg+1
hz_ps   lda #0                  ; passage depuis l'écran effacé
        sta a_rt
        jsr h_cls
        lda a_f0
        sta a_p
        lda a_f0+1
        sta a_p+1
hz_pl   lda a_nf                ; images de ce passage
        sta a_k
        lda a_nf+1
        sta a_k+1
hz_fr   jsr a_wait
        cmp #0
        beq hz_fd
        jmp hz_key
hz_fd
        lda a_p                 ; délai, longueur, flux
        sta hs
        lda a_p+1
        sta hs+1
        ldy #0
        lda (hs),y
        bne hz_d1
        lda #1
hz_d1   sta a_dl
        iny
        lda (hs),y
        sta a_s
        iny
        lda (hs),y
        sta a_s+1
        clc                     ; image suivante : p + 3 + longueur
        lda a_p
        adc #3
        tax
        lda a_p+1
        adc #0
        tay
        txa
        clc
        adc a_s
        sta a_p
        tya
        adc a_s+1
        sta a_p+1
        txa
        jsr h_unz
        clc                     ; prochain top : celui-ci + délai
        lda a_t0
        adc a_dl
        sta a_tg
        lda a_t0+1
        adc #0
        sta a_tg+1
        lda a_k                 ; 1re image du passage ?
        cmp a_nf
        bne hz_nx
        lda a_k+1
        cmp a_nf+1
        bne hz_nx
        lda a_rt
        beq hz_f1
        lda a_f1                ; image de retour faite : on reprend à
        sta a_p                 ; l'image 2
        lda a_f1+1
        sta a_p+1
        jmp hz_nx
hz_f1   lda a_p                 ; adresse de l'image 2
        sta a_f1
        lda a_p+1
        sta a_f1+1
hz_nx   lda a_k
        bne hz_k1
        dec a_k+1
hz_k1   dec a_k
        lda a_k
        ora a_k+1
        beq hz_pf
        jmp hz_fr
hz_pf   lda a_n                 ; passage fini
        beq hz_ag               ; 0 : sans fin
        dec a_n
        beq hz_end
hz_ag   lda a_lp
        bne hz_rf
        jmp hz_ps               ; pas d'image de retour : on efface
hz_rf   lda #1                  ; a_p = image de retour
        sta a_rt
        jmp hz_pl
hz_end  lda #0
hz_key  pha
        lda #<A_SYS             ; timer du système
        sta A_T1LL
        lda #>A_SYS
        sta A_T1LL+1
        pla
        clc
        rts
.)

; a_wait : attend le top 50 Hz qui atteint a_tg (a_t0 <- ce top) ; les
;   flèches gauche / droite décalent la phase ; une autre touche -> A
a_wait
.(
hz_w0   lda SYS_TICKS
        sta a_lt
hz_w1   jsr B_CONST
        cmp #0
        beq hz_w2
        jsr B_CONIN
        ldx #<(A_LOCK-A_STEP)
        ldy #>(A_LOCK-A_STEP)
        cmp #8
        beq hz_ph
        ldx #<(A_LOCK+A_STEP)
        ldy #>(A_LOCK+A_STEP)
        cmp #9
        beq hz_ph
        rts
hz_ph   stx A_T1LL              ; une seule période plus courte ou plus
        sty A_T1LL+1            ; longue : la phase est décalée
        lda SYS_TICKS
hz_p1   cmp SYS_TICKS
        beq hz_p1
        lda #<A_LOCK
        sta A_T1LL
        lda #>A_LOCK
        sta A_T1LL+1
        jmp hz_w0
hz_w2   lda SYS_TICKS           ; un top ?
        cmp a_lt
        beq hz_w1
        sta a_lt
        sec                     ; atteint : ticks - a_tg >= 0
        lda SYS_TICKS
        sbc a_tg
        lda SYS_TICKS+1
        sbc a_tg+1
        bmi hz_w1
        lda SYS_TICKS
        sta a_t0
        lda SYS_TICKS+1
        sta a_t0+1
        lda #0
        rts
.)

; a_msg : code d'erreur de a_play -> A/Y message
a_msg
.(
        cmp #3
        beq hz_m3
        cmp #4
        beq hz_m4
        lda #<a_m1
        ldy #>a_m1
        rts
hz_m3   lda #<a_m3
        ldy #>a_m3
        rts
hz_m4   lda #<a_m4
        ldy #>a_m4
        rts
.)

; a_grx : GRAPHER /A (A = passages ; nom après l'appel)
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
        bcs hz_er
        cmp #27
        bne hz_r
        lda #<a_me
        ldy #>a_me
        jmp a_fail
hz_er   jsr a_msg
        jmp a_fail
hz_r    rts
.)

a_sig   .asc "ANI",1
a_m1    .asc "animation introuvable",0
a_m3    .asc "animation trop grande",0
a_m4    .asc "pas une animation",0
a_mh    .asc "HIRES d'abord",0
a_me    .asc "Interrompu",0
a_n     .byt 0
a_n2    .byt 0
a_nf    .word 0
a_k     .word 0
a_lp    .byt 0
a_rt    .byt 0
a_dl    .byt 0
a_lt    .byt 0
a_s     .word 0
a_p     .word 0
a_f0    .word 0
a_f1    .word 0
a_tg    .word 0
a_t0    .word 0
a_e     .word 0
a_fcb   .dsb 36,0
