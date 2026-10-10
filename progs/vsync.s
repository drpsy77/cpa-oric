; =====================================================================
;  VSYNC.COM — cale le top 50 Hz du système sur le balayage de l'écran
;
;  VSYNC        un texte caché (encre = papier) n'est rendu visible que
;               pendant 8 lignes de balayage, à un instant fixe après le
;               top. Les flèches décalent le top (gauche / droite : une
;               ligne, haut / bas : 8 lignes) ; le texte apparaît en
;               entier quand le top tombe sur la fin de l'image HIRES
;               (ligne 200). RETURN garde le réglage, ESC l'annule.
;
;  Le timer du système (T1) tourne à une trame exacte (19 968 cycles) et
;  n'est relancé qu'au démarrage à froid : le réglage tient jusque-là.
;  Les animations (ANIM.INC : VOIR, GRAPHER) décodent chaque image juste
;  après le top, quand le faisceau a quitté l'image : plus de déchirure.
;  Rien ne permet de le faire seul : l'Oric n'a pas de signal VSYNC.
; =====================================================================

#include "cpa.inc"

T1CH    = $0305         ; compteur du timer 1 (lire l'octet haut ne
T1LL    = $0306         ; touche pas à l'interruption) et sa période
T1LH    = $0307
LOCK    = 19966         ; période du système (src/hw.inc, T1_PERIOD)
CUR_INK = $027A
CUR_PAP = $027B

; Le texte est en ligne ROW (lignes de balayage 8*ROW à 8*ROW+7). Calé,
; le top tombe à la ligne 200 ; ROW*8 = 112 vient 224 lignes plus tard
; (312 par trame), soit 14 336 cycles : le compteur vaut alors
; 19 967 - 14 336 = 5 631 = $15FF, l'instant où son octet haut passe de
; $16 à $15. L'encre est remise au papier 512 cycles (8 lignes) après,
; quand l'octet haut passe à $13.
ROW     = 14
HIDE    = SCREEN+ROW*40+1       ; attribut d'encre de la ligne
HW      = $15

v_n     = $10           ; décalage demandé, en lignes (signé, 2 octets)
v_s     = $12           ; décalage total, 0 à 311 (pour ESC)
v_t     = $14
v_p     = $16

        *= $0500
.(
        lda CON_CUREN
        sta curen
        lda #0
        sta CON_CUREN           ; pas de curseur
        sta v_s
        sta v_s+1
        lda #12                 ; écran effacé
        ldx #F_CONOUT
        jsr BDOS
        lda #<texts             ; textes : ligne, colonne, texte, 0
        sta v_p
        lda #>texts
        sta v_p+1
txt     ldy #0
        lda (v_p),y
        beq tx_e
        tax
        iny
        lda (v_p),y             ; colonne
        clc
        adc line_lo,x
        sta v_t
        lda line_hi,x
        adc #0
        sta v_t+1
        clc                     ; v_p sur le texte
        lda v_p
        adc #2
        sta v_p
        bcc tx_0
        inc v_p+1
tx_0    ldy #0
tx_c    lda (v_p),y
        beq tx_n
        sta (v_t),y
        iny
        bne tx_c
tx_n    sec                     ; texte suivant : après le 0
        tya
        adc v_p
        sta v_p
        bcc txt
        inc v_p+1
        bcs txt
tx_e

frame   lda CUR_PAP             ; encre = papier : texte caché
        sta HIDE
w1      lda T1CH                ; attend l'instant fixe après le top
        cmp #HW+1
        bne w1
w2      lda T1CH
        cmp #HW
        bne w2
        lda CUR_INK             ; visible pendant 8 lignes de balayage
        sta HIDE
w3      lda T1CH
        cmp #HW-2
        bne w3
        lda CUR_PAP
        sta HIDE
        jsr B_CONST
        cmp #0
        beq frame
        jsr B_CONIN
        cmp #13
        beq keep
        cmp #27
        beq cancel
        ldx #3
k_f     cmp keys,x
        beq k_ok
        dex
        bpl k_f
        bmi frame
k_ok    lda steps,x             ; décalage de cette touche
        sta v_n
        and #$80
        beq k_p
        lda #$FF
k_p     sta v_n+1
        clc                     ; total modulo 312
        lda v_s
        adc v_n
        sta v_s
        lda v_s+1
        adc v_n+1
        sta v_s+1
        bpl k_hi
        clc
        lda v_s
        adc #<312
        sta v_s
        lda v_s+1
        adc #>312
        sta v_s+1
k_hi    lda v_s
        cmp #<312
        lda v_s+1
        sbc #>312
        bcc k_sh
        sta v_s+1
        lda v_s
        sbc #<312
        sta v_s
k_sh    jsr shift
        jmp frame

cancel  sec                     ; ESC : 312 - total, une fois
        lda #<312
        sbc v_s
        sta v_n
        lda #>312
        sbc v_s+1
        sta v_n+1
        jsr shift
        lda #<m_esc
        ldy #>m_esc
        jmp fin
keep    lda #<m_ok
        ldy #>m_ok
fin     pha
        tya
        pha
        lda #12
        ldx #F_CONOUT
        jsr BDOS
        lda curen
        sta CON_CUREN
        pla
        tay
        pla
        ldx #F_PRINT
        jmp BDOS

; shift : une seule période allongée de v_n lignes (64 cycles chacune) :
;   le top et tous les suivants sont décalés d'autant
shift   ldx #6
sh_m    asl v_n
        rol v_n+1
        dex
        bne sh_m
        clc
        lda v_n
        adc #<LOCK
        sta T1LL
        lda v_n+1
        adc #>LOCK
        sta T1LH                ; prise au prochain passage à zéro
        lda SYS_TICKS
sh_w    cmp SYS_TICKS
        beq sh_w
        lda #<LOCK              ; période d'une trame ensuite
        sta T1LL
        lda #>LOCK
        sta T1LH
        rts
.)

curen   .byt 0
keys    .byt 8,9,11,10          ; gauche, droite, haut, bas
steps   .byt <-1,1,<-8,8

line_lo .byt <(SCREEN+0),<(SCREEN+40),<(SCREEN+80),<(SCREEN+120)
        .byt <(SCREEN+160),<(SCREEN+200),<(SCREEN+240),<(SCREEN+280)
        .byt <(SCREEN+320),<(SCREEN+360),<(SCREEN+400),<(SCREEN+440)
        .byt <(SCREEN+480),<(SCREEN+520),<(SCREEN+560),<(SCREEN+600)
        .byt <(SCREEN+640),<(SCREEN+680),<(SCREEN+720),<(SCREEN+760)
line_hi .byt >(SCREEN+0),>(SCREEN+40),>(SCREEN+80),>(SCREEN+120)
        .byt >(SCREEN+160),>(SCREEN+200),>(SCREEN+240),>(SCREEN+280)
        .byt >(SCREEN+320),>(SCREEN+360),>(SCREEN+400),>(SCREEN+440)
        .byt >(SCREEN+480),>(SCREEN+520),>(SCREEN+560),>(SCREEN+600)
        .byt >(SCREEN+640),>(SCREEN+680),>(SCREEN+720),>(SCREEN+760)

; ligne (1 à 19), colonne, texte, 0 ; une ligne 0 termine
texts   .byt 2,2
        .asc "VSYNC : calage de l'ecran",0
        .byt 4,2
        .asc "Le texte du milieu n'est visible qu'a",0
        .byt 5,2
        .asc "un instant precis du balayage.",0
        .byt 7,2
        .asc "Fleches gauche/droite : 1 ligne",0
        .byt 8,2
        .asc "Fleches haut/bas      : 8 lignes",0
        .byt 10,2
        .asc "Texte du milieu entier et immobile :",0
        .byt 11,2
        .asc "RETURN garde le reglage (ESC annule).",0
        .byt ROW,8
        .asc "**** ECRAN CALE ****",0
        .byt 17,2
        .asc "Reglage garde jusqu'au prochain",0
        .byt 18,2
        .asc "demarrage (animations sans dechirure).",0
        .byt 0

m_ok    .asc "Ecran cale.",13,10,"$"
m_esc   .asc "Reglage annule.",13,10,"$"
