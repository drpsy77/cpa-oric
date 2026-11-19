; bcr_inc.s : codage d'une ligne de BASIC comme la ROM 1.1 (TokeniseLine,
; $C5FA), partagé par MKTAP (codage des .BAS) et UNTAP (vérification des
; lignes rendues en texte). Inclus par un programme, jamais assemblé seul.
; Le programme fournit :
;   sbuf (texte, 0 après), slen, po (2 octets, page zéro : destination),
;   pa, kp (2 octets), tok, sx, sy, dmode (page zéro), bastab
;   (progs/bas_tab.s), T_PRINT, T_DATA, T_REM, et cr_bad : où aller quand
;   un caractère de code $80 ou plus est hors texte (la ROM couperait la
;   ligne ; on y arrive par JMP, la pile porte encore le retour de crunch).
; crunch : texte sbuf,X (après le numéro) -> (po),Y comme TokeniseLine
;   de la ROM 1.1 ($C5FA), lettres en majuscules hors texte -> Y =
;   octets codés. Erreur : caractère de code $80 ou plus hors texte.
crunch
.(
        ldy #0
        sty dmode
cl      cpx slen
        bne c0
        rts
c0      lda sbuf,x
        cmp #$22                ; chaîne : jusqu'au guillemet
        bne c1
s       sta (po),y
        iny
        inx
        cpx slen
        bne s0
        rts
s0      lda sbuf,x
        cmp #$22
        bne s
        sta (po),y
        iny
        inx
        jmp cl
c1      cmp #" "
        beq st
        bit dmode               ; DATA : tel quel jusqu'au « : »
        bmi st
        cmp #"?"
        bne c2
        lda #T_PRINT
        bne st
c2      cmp #"0"                ; chiffres, « : », « ; »
        bcc kw
        cmp #";"+1
        bcc st
kw      cmp #$80
        bcc k0
        jmp cr_bad
k0      stx sx                  ; mots-clés, dans l'ordre de la table
        sty sy
        lda #<bastab
        sta kp
        lda #>bastab
        sta kp+1
        lda #$80
        sta tok
k1      ldy #0
k2      lda sbuf,x
        jsr upc
        sta pa
        lda (kp),y
        and #$7F
        cmp pa
        bne kn
        lda (kp),y
        bmi kf
        inx
        iny
        bne k2
kn      lda (kp),y              ; mot suivant
        iny
        asl
        bcc kn
        tya
        clc
        adc kp
        sta kp
        bcc k3
        inc kp+1
k3      inc tok
        ldx sx
        ldy #0
        lda (kp),y
        bne k1
        lda sbuf,x              ; aucun : le caractère, en majuscule
        jsr upc
        ldy sy
        jmp st
kf      lda tok
        ldy sy
st      inx
        sta (po),y
        iny
        cmp #":"
        bne p1
        lda #0
        sta dmode
        jmp cl
p1      cmp #T_DATA
        bne p2
        lda #$80
        sta dmode
        jmp cl
p2      cmp #T_REM
        beq r
        jmp cl
r       cpx slen                ; REM : le reste tel quel
        beq done
        lda sbuf,x
        sta (po),y
        iny
        inx
        bne r
done    rts
.)

upc
.(
        cmp #"a"
        bcc r
        cmp #"z"+1
        bcs r
        and #$DF
r       rts
.)

