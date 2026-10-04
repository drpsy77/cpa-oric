; =====================================================================
;  GO.COM — lance du code en mémoire
;
;  GO adr [param...]       adresse en hexadécimal ($ facultatif)
;  Le code est appelé comme un .COM : un RTS ramène au prompt.
;  Les paramètres qui suivent l'adresse lui sont transmis : ligne en
;  $0480 (espace en tête), FCB1 = premier paramètre (le second FCB est
;  vidé, comme sous DEBUG).
;
;  GO est chargé en $0500 comme tout .COM : le code lancé doit être
;  en dehors de $0500-$05FF (commencer en $0600 après un POKE).
; =====================================================================

#include "cpa.inc"

val     = $10           ; adresse lue (2 octets)
nd      = $12

        *= $0500
start
.(
        ldx #1
        jsr gethex
        bcs usage
        lda val
        sta jump+1
        lda val+1
        sta jump+2
        ldy #1                  ; la suite de la ligne devient les paramètres
sh      lda TAIL,x
        sta TAIL,y
        beq shd
        inx
        iny
        bne sh
shd     dey
        sty TAIL
        ldx #15                 ; FCB1 <- FCB2, FCB2 vide
cf      lda FCB2,x
        sta FCB1,x
        dex
        bpl cf
        ldx #15                 ; FCB2 vide : lecteur 0, nom en
cl      lda #0                  ; espaces, octets 12-15 à 0
        cpx #12
        bcs z
        lda #" "
z       sta FCB2,x
        dex
        bne cl
        stx FCB2                ; X = 0
jump    jmp $FFFF               ; son RTS revient directement au CCP
usage   lda #<m_usage
        ldy #>m_usage
        ldx #F_PRINT
        jmp BDOS
.)

; gethex : nombre hexadécimal en TAIL,X (espaces sautés, $ admis).
;   C=0 : val, X après le nombre (qui doit finir sur un espace ou la fin).
;   C=1 : pas de nombre.
gethex
.(
        lda #0
        sta val
        sta val+1
        sta nd
sp      lda TAIL,x
        cmp #" "
        bne s2
        inx
        bne sp
s2      cmp #"$"
        bne dig
        inx
dig     lda TAIL,x
        jsr hexval
        bcs end
        ldy #4
sh      asl val
        rol val+1
        dey
        bne sh
        ora val
        sta val
        inc nd
        inx
        bne dig
end     lda nd
        beq no
        lda TAIL,x
        beq yes
        cmp #" "
        bne no
yes     clc
        rts
no      sec
        rts
.)

; hexval : A = caractère -> A = 0-15, C=0 ; C=1 si ce n'est pas un chiffre
hexval
.(
        cmp #"0"
        bcc no
        cmp #"9"+1
        bcc digit
        and #$DF
        cmp #"A"
        bcc no
        cmp #"G"
        bcs no
        sbc #"A"-11
        clc
        rts
digit   sbc #"0"-1
        clc
        rts
no      sec
        rts
.)

m_usage .asc "GO adr [param...]  (hexa)",13,10
        .asc "RTS ramene au prompt",13,10,"$"
