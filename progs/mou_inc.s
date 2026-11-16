; =====================================================================
;  mou_inc.s — souris USB du LOCI (bibliothèque incluse par un programme,
;  jamais assemblée seule ; essai : tools/test_mou.py). La souris reste un
;  confort : tout programme qui s'en sert marche aussi au clavier seul.
;
;  Le LOCI tient en XRAM, à l'adresse donnée par XREG (périphérique 0,
;  canal 0, registre 1), 5 octets : boutons (bit 0 gauche, 1 droit,
;  2 milieu), compteurs X, Y, molette (modulo 256), défilement
;  horizontal. La bibliothèque les lit par la fenêtre 0 de la XRAM
;  ($03A4-$03A7 ; la fenêtre 1 sert au pilote disque du système), quand
;  le programme appelle mo_poll : rien sous interruption, rien de
;  résident. Entre deux appels, pas plus de 127 pas de mouvement (environ
;  1,3 cm) : appeler mo_poll dans la boucle d'attente des touches, et
;  mo_sync après un long travail (le mouvement fait pendant est oublié).
;
;  Position tenue par la bibliothèque, en unités choisies par le
;  programme : mo_x de 0 à mo_xmax, mo_y de 0 à mo_ymax (vers le bas).
;  Une unité vaut 2^mo_n pas de la souris (une souris courante en donne
;  environ 100 par cm) ; mo_n = mo_unit (fixé par le programme selon ses
;  unités : 0 pour des points, 2 pour des cases du texte) + mo_reg
;  (réglage de l'utilisateur, 0 à 4, gardé dans le fichier 0:CPA.MOU de
;  la mémoire du LOCI, commun à tous les programmes ; 2 sans fichier).
;  Les restes de la division sont gardés : un mouvement lent avance aussi.
;
;  Sans LOCI (ou LOCI qui refuse XREG) : mo_on = 0, mo_poll rend toujours
;  A = 0 ; le programme marche au clavier seul.
;
;  Appels : mo_init, mo_poll, mo_sync, mo_setn, mo_save, mo_end.
;  Ni page zéro ni tampon : variables à la fin de la bibliothèque.
; =====================================================================

MO_XRAM = $FF00         ; rapport de la souris en XRAM (5 octets)

; ---------------------------------------------------------------------
; mo_init : cherche le LOCI, lui fait tenir la souris en MO_XRAM, lit le
;   réglage (0:CPA.MOU), calcule mo_n (mo_unit doit être fixé avant),
;   prend les compteurs comme point de départ. Ne touche pas à mo_x,
;   mo_y. C=0 et mo_on = 1 si la souris est là ; sinon C=1, mo_on = 0.
; ---------------------------------------------------------------------
mo_init
.(
        lda #0
        sta mo_on
        lda $0319               ; "L" : démarré par le LOCI
        cmp #"L"
        bne no
        lda #0                  ; opération 0 : vide la pile d'échange ;
        sta $03AF               ;   le LOCI réécrit alors en $03B0
        ldx #4                  ;   CLV / BVC / LDA # / LDX # / RTS
c       ldy mo_spo,x            ;   (sans LOCI : registres du VIA, et un
        lda $03B0,y             ;   JSR $03B0 planterait)
        cmp mo_spc,x
        bne no
        dex
        bpl c
        lda #<MO_XRAM
        ldx #>MO_XRAM
        jsr mo_xreg
        bcs no
        lda #2                  ; réglage par défaut
        sta mo_reg
        ldx #1                  ; O_RDONLY
        jsr mo_open
        bcs n
        pha
        lda #0                  ; compte (16 bits) : poids fort d'abord
        sta $03AC
        lda #1
        sta $03AC
        pla
        pha
        sta $03B4
        lda #$16                ; read_xstack
        jsr mo_call
        bcs cl
        cmp #1
        bne cl
        lda $03AC
        cmp #5
        bcs cl                  ; réglage hors limites : défaut
        sta mo_reg
cl      pla
        jsr mo_close
n       jsr mo_setn
        lda #1
        sta mo_on
        jsr mo_sync
        clc
        rts
no      sec
        rts
.)

; mo_setn : mo_n = mo_unit + mo_reg (7 au plus)
mo_setn
.(
        lda mo_unit
        clc
        adc mo_reg
        cmp #8
        bcc s
        lda #7
s       sta mo_n
        rts
.)

; ---------------------------------------------------------------------
; mo_save : écrit mo_reg dans 0:CPA.MOU ; C=1 si l'écriture échoue (ou
;   sans souris). Fichier d'un octet, réécrit sur place.
; ---------------------------------------------------------------------
mo_save
.(
        lda mo_on
        beq no
        ldx #$12                ; O_WRONLY + O_CREAT
        jsr mo_open
        bcs r
        pha
        sta $03B4
        lda mo_reg
        sta $03AC
        lda #$18                ; write_xstack
        jsr mo_call
        pla
        php
        jsr mo_close
        plp
r       rts
no      sec
        rts
.)

; ---------------------------------------------------------------------
; mo_end : le LOCI cesse d'écrire en XRAM ; mo_on = 0. À appeler avant de
;   quitter (sans cela, il continue d'écrire en MO_XRAM : sans danger).
; ---------------------------------------------------------------------
mo_end
.(
        lda mo_on
        beq r
        lda #0
        sta mo_on
        lda #$FF
        tax
        jmp mo_xreg
r       rts
.)

; ---------------------------------------------------------------------
; mo_sync : les compteurs actuels deviennent le point de départ (le
;   mouvement fait depuis la dernière lecture est oublié), restes à 0,
;   boutons pris sans les compter comme enfoncés.
; ---------------------------------------------------------------------
mo_sync
.(
        lda mo_on
        beq r
        jsr mo_rd
        sta mo_aw
        stx mo_ax
        sty mo_ax+1
        lda mo_bn
        sta mo_b
        lda #0
        sta mo_rx
        sta mo_rx+1
        sta mo_bp
        sta mo_br
        sta mo_w
r       rts
.)

; ---------------------------------------------------------------------
; mo_poll : lit la souris. Met à jour mo_x, mo_y (bornés), mo_b (boutons
;   tenus), mo_bp (enfoncés depuis la lecture d'avant), mo_br (relâchés),
;   mo_w (crans de molette depuis la lecture d'avant, signé).
;   A = ce qui a changé (bit 0 : position, bit 1 : boutons, bit 2 :
;   molette ; Z=1 si rien). Sans souris : A = 0.
; ---------------------------------------------------------------------
mo_poll
.(
        lda #0
        sta mo_chg
        sta mo_bp
        sta mo_br
        lda mo_on
        beq r
        jsr mo_rd               ; A = molette, X, Y = compteurs
        pha
        tya
        pha
        txa
        ldx #0
        jsr mo_axe              ; X
        pla
        ldx #1
        jsr mo_axe              ; Y
        pla
        tay                     ; molette : différence, sans division
        sec
        sbc mo_aw
        sty mo_aw
        sta mo_w
        beq b
        lda #4
        jsr mo_set
b       lda mo_bn               ; boutons
        eor mo_b
        beq r
        tax                     ; bits changés
        and mo_bn
        sta mo_bp
        txa
        and mo_b
        sta mo_br
        lda mo_bn
        sta mo_b
        lda #2
        jsr mo_set
r       lda mo_chg
        rts
.)

; mo_set : ajoute le bit A à mo_chg
mo_set
        ora mo_chg
        sta mo_chg
        rts

; mo_axe : A = compteur lu, X = axe (0 : X, 1 : Y)
mo_axe
.(
        tay
        sec
        sbc mo_ax,x             ; d = nouveau - ancien, signé
        sta mo_sl
        tya
        sta mo_ax,x
        ldy #0                  ; s = d (étendu à 16 bits) + reste
        lda mo_sl
        bpl p
        dey
p       sty mo_sh
        clc
        adc mo_rx,x
        sta mo_sl
        bcc m
        inc mo_sh
m       ldy mo_n
        and mo_msk,y
        sta mo_rx,x             ; nouveau reste
        cpy #0
        beq q
sh      lda mo_sh               ; décalage arithmétique de n bits
        cmp #$80
        ror
        sta mo_sh
        ror mo_sl
        dey
        bne sh
q       lda mo_sl               ; q (-128..127 : |s| < 256)
        beq r
        clc
        adc mo_x,x
        tay
        lda mo_sh
        adc #0
        bmi lo                  ; sous 0
        bne hi                  ; au-delà de 255
        tya
        cmp mo_xmax,x
        bcc ok
        beq ok
hi      lda mo_xmax,x
        .byt $2C                ; BIT abs : saute le LDA #0
lo      lda #0
ok      cmp mo_x,x
        beq r
        sta mo_x,x
        lda #1
        jmp mo_set
r       rts
.)

; mo_rd : lit le rapport -> mo_bn = boutons, X = compteur X,
;   Y = compteur Y, A = molette
mo_rd
        lda #1
        sta $03A5               ; STEP0
        lda #<MO_XRAM
        sta $03A6               ; ADDR0
        lda #>MO_XRAM
        sta $03A7
        lda $03A4               ; RW0 : un octet, puis le suivant
        and #7
        sta mo_bn
        ldx $03A4
        ldy $03A4
        lda $03A4
        rts

; mo_xreg : la souris est tenue en XRAM à l'adresse A (bas) / X (haut)
;   ($FFFF : plus tenue) ; C=1 si le LOCI refuse
mo_xreg
        pha
        lda #0
        sta $03AC               ; périphérique 0
        sta $03AC               ; canal 0
        lda #1
        sta $03AC               ; registre 1 : souris
        stx $03AC               ; adresse : octet haut
        pla
        sta $03AC               ;   puis octet bas
        lda #1                  ; XREG
; mo_call : lance l'opération A et attend ; A/X = résultat, C=1 si erreur
mo_call
        sta $03AF
        jsr $03B0
        cpx #$80
        rts

; mo_open : ouvre 0:CPA.MOU, X = drapeaux -> A = descripteur, C=1 si erreur
mo_open
.(
        ldy #mo_spo-mo_fn-1     ; chemin empilé à l'envers
p       lda mo_fn,y
        sta $03AC
        dey
        bpl p
        stx $03B4
        lda #$14                ; open
        jmp mo_call
.)

; mo_close : ferme le descripteur A
mo_close
        sta $03B4
        lda #$15                ; close
        jmp mo_call

mo_fn   .asc "0:CPA.MOU"
mo_spo  .byt 0,1,3,5,7          ; code attendu en $03B0 après l'opération 0
mo_spc  .byt $B8,$50,$A9,$A2,$60
mo_msk  .byt 0,1,3,7,15,31,63,127

; Variables publiques (dans cet ordre : X puis Y pour mo_axe)
mo_x    .byt 0                  ; position
mo_y    .byt 0
mo_xmax .byt 239                ; bornes (comprises)
mo_ymax .byt 199
mo_on   .byt 0                  ; 1 : souris active
mo_unit .byt 0                  ; unité du programme (2^n pas)
mo_reg  .byt 2                  ; réglage de l'utilisateur (0 à 4)
mo_n    .byt 2                  ; mo_unit + mo_reg
mo_b    .byt 0                  ; boutons tenus : bit 0 gauche, 1 droit,
mo_bp   .byt 0                  ;   2 milieu ; enfoncés, relâchés depuis
mo_br   .byt 0                  ;   la lecture d'avant
mo_w    .byt 0                  ; crans de molette (signé)
; Internes
mo_ax   .byt 0,0                ; anciens compteurs X, Y
mo_rx   .byt 0,0                ; restes X, Y
mo_aw   .byt 0                  ; ancien compteur de molette
mo_bn   .byt 0
mo_sl   .byt 0
mo_sh   .byt 0
mo_chg  .byt 0
