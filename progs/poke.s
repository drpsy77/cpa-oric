; =====================================================================
;  POKE.COM — écrit des octets en mémoire
;
;  POKE adr bb [bb...]     nombres en hexadécimal ($ facultatif)
;  Exemple : POKE 0600 A9 41 20 0C C0 60
;
;  Comme tout .COM, POKE est chargé en $0500 : il occupe $0500-$05FF
;  pendant son exécution. Il peut pourtant écrire dans cette zone (pour
;  un SAVE ensuite) : les octets sont d'abord décodés dans la ligne de
;  paramètres, puis la boucle de copie s'exécute depuis la page zéro
;  ($00D0-$00DD), sauf si la cible est elle-même en page zéro.
;  Après POKE, le code tapé en $0500-$05FF serait écrasé par GO.COM :
;  pour POKE puis GO, commencer en $0600.
; =====================================================================

#include "cpa.inc"

val     = $10           ; nombre lu (2 octets)
nd      = $12           ; nombre de chiffres lus
n       = $13           ; nombre d'octets décodés
dst     = $14           ; adresse de destination (2 octets)
TRAMP   = $D0           ; boucle de copie exécutée en page zéro

        *= $0500
start
.(
        ldx #1
        jsr gethex              ; adresse
        bcs usage
        lda val
        sta dst
        lda val+1
        sta dst+1
        lda #0
        sta n
loop    jsr gethex              ; octets
        bcs end
        lda val+1
        bne usage               ; plus de FF
        lda val
        ldy n
        sta TAIL+1,y            ; décodé sur place (jamais devant la lecture)
        inc n
        bne loop
end     lda TAIL,x              ; arrêt sur autre chose que la fin : erreur
        bne usage
        lda n
        beq usage
        lda dst                 ; la boucle de copie reçoit ses paramètres
        sta cp_dst+1
        lda dst+1
        sta cp_dst+2
        lda n
        sta cp_n+1
        lda dst+1
        beq copy                ; cible en page zéro : copie sur place
        ldx #cp_end-copy-1      ; sinon depuis la page zéro
mv      lda copy,x
        sta TRAMP,x
        dex
        bpl mv
        jmp TRAMP
usage   lda #<m_usage
        ldy #>m_usage
        ldx #F_PRINT
        jmp BDOS
.)

; boucle de copie, relogeable (aucune adresse interne), sans variable
copy    ldy #0
cp_l    lda TAIL+1,y
cp_dst  sta $FFFF,y
        iny
cp_n    cpy #0
        bne cp_l
        rts
cp_end

; gethex : nombre hexadécimal en TAIL,X (espaces sautés, $ admis).
;   C=0 : val, X après le nombre (qui doit finir sur un espace ou la fin).
;   C=1 : pas de nombre, X sur le caractère fautif (0 : fin de ligne).
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
        lda TAIL,x              ; le nombre doit finir proprement
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
        and #$DF                ; minuscule -> majuscule
        cmp #"A"
        bcc no
        cmp #"G"
        bcs no
        sbc #"A"-11             ; C=0 : A - "A" + 10
        clc
        rts
digit   sbc #"0"-1              ; C=0 : A - "0"
        clc
        rts
no      sec
        rts
.)

m_usage .asc "POKE adr bb [bb...]  (hexa)",13,10
        .asc "Code a lancer : 0600 et +",13,10,"$"
