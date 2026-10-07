; =====================================================================
;  XDO.COM — appel d'un script par un script
;
;  Le CCP lance « XDO NOM [p1..p9] » à la place de DO quand un script
;  en cours appelle un autre script (par DO ou par son nom). XDO écrit
;  $$$.BAT : les lignes de NOM.BAT avec ses paramètres, puis la fin du
;  script appelant avec les siens, et enchaîne sur « DO $$$ ». Le
;  script appelé est donc relu à chaque appel (rien à recompiler), et
;  l'appelant reprend après la ligne d'appel. Un script sans appel ne
;  passe jamais par ici.
;
;  Les $ des textes recopiés sont doublés ($$) pour que DO les rende
;  tels quels. Tout est lu en mémoire avant l'écriture : le script
;  appelant peut être $$$.BAT lui-même. En cas d'erreur, le script
;  s'arrête.
; =====================================================================

#include "cpa.inc"

optr    = $10           ; 2 octets : prochain octet du résultat
pptr    = $12           ; 2 octets : paramètres en usage
pend    = $14           ; 1 = un $ attend le caractère suivant
t0      = $15
t1      = $16
idx     = $17
was_on  = $18
t2      = $19

        *= $0500

start
.(
        lda SCR_ON              ; un script est-il en cours ?
        sta was_on
        lda #0                  ; toute sortie arrête le script
        sta SCR_ON
        ldx #35                 ; état de l'appelant, avant toute lecture
cs      lda SCR_FCB,x
        sta afcb,x
        dex
        bpl cs
        ldx #127
cb      lda SCR_BUF,x
        sta abuf,x
        dex
        bpl cb
        ldx #79
cp      lda SCR_PAR,x
        sta apar,x
        dex
        bpl cp
        lda SCR_IDX
        sta idx

        lda FCB1+1              ; nom du script appelé
        cmp #" "
        bne named
        lda #<msg_use
        ldy #>msg_use
        jmp fail
named   ldx #11
cn      lda FCB1,x
        sta bfcb,x
        dex
        bpl cn
        lda bfcb+9
        cmp #" "
        bne typed
        lda #"B"
        sta bfcb+9
        lda #"A"
        sta bfcb+10
        lda #"T"
        sta bfcb+11
typed   jsr get_par             ; ses paramètres, casse d'origine
        lda #<buf
        sta optr
        lda #>buf
        sta optr+1
        lda #0
        sta pend

        ldx #F_OPEN             ; 1. le script appelé
        lda #<bfcb
        ldy #>bfcb
        jsr BDOS
        cmp #$FF
        bne opened
        lda #<msg_nofile
        ldy #>msg_nofile
        jmp fail
opened  lda #<bpar
        sta pptr
        lda #>bpar
        sta pptr+1
brec    lda #<bfcb
        ldy #>bfcb
        jsr read_rec
        bcs bdone
        ldx #0
bch     lda rbuf,x
        stx t1
        jsr filter
        bcs bdone
        ldx t1
        inx
        bpl bch
        bmi brec
bdone   jsr flush               ; un $ en fin de fichier est ignoré

        lda was_on              ; 2. la fin du script appelant
        beq write
        lda #<apar
        sta pptr
        lda #>apar
        sta pptr+1
        ldx idx
        bmi arec
ach     lda abuf,x
        stx t1
        jsr filter
        bcs write
        ldx t1
        inx
        bpl ach
arec    lda #<afcb
        ldy #>afcb
        jsr read_rec
        bcs write
        ldx #0
ach2    lda rbuf,x
        stx t1
        jsr filter
        bcs write
        ldx t1
        inx
        bpl ach2
        bmi arec

write   jsr flush
pad     lda optr                ; complète l'enregistrement par des ^Z
        sec
        sbc #<buf
        and #$7F
        beq padded
        lda #$1A
        jsr emit
        jmp pad
padded  ldx #F_DELETE           ; 3. $$$.BAT
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        ldx #F_MAKE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        cmp #$FF
        beq dskerr
        lda #<buf
        sta t0                  ; t0/pptr : enregistrement à écrire
        lda #>buf
        sta pptr+1
wrec    lda t0
        cmp optr
        lda pptr+1
        sbc optr+1
        bcs wdone
        lda t0
        ldy pptr+1
        ldx #F_SETDMA
        jsr BDOS
        ldx #F_WRITE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        cmp #0
        bne dskerr
        lda t0
        clc
        adc #128
        sta t0
        bcc wrec
        inc pptr+1
        bne wrec
wdone   ldx #F_CLOSE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        cmp #$FF
        beq dskerr
        lda #<DEF_DMA
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<cmd_do            ; 4. DO $$$
        ldy #>cmd_do
        ldx #F_CHAIN
        jmp BDOS
dskerr  lda #<msg_disk
        ldy #>msg_disk
.)
; fail : affiche le message A/Y et revient au CCP (script arrêté)
fail    ldx #F_PRINT
        jmp BDOS

; read_rec : enregistrement suivant du FCB A/Y dans rbuf, C=1 à la fin
read_rec
.(
        sta t0
        sty t1
        lda #<rbuf
        ldy #>rbuf
        ldx #F_SETDMA
        jsr BDOS
        lda t0
        ldy t1
        ldx #F_READ
        jsr BDOS
        cmp #0
        beq ok
        sec
        rts
ok      clc
        rts
.)

; filter : un caractère du texte source (paramètres en pptr).
;   C=1 sur ^Z (fin du texte). $$ -> $$, $1-$9 -> paramètre (ses $
;   doublés), $ suivi d'autre chose : les deux sont ignorés, comme DO.
filter
.(
        cmp #$1A
        beq eot
        ldx pend
        bne dollar
        cmp #"$"
        bne out
        inc pend
        clc
        rts
dollar  ldx #0
        stx pend
        cmp #"$"
        beq out                 ; $$ : écrit $$
        sec
        sbc #"1"
        cmp #9
        bcs skip
        jmp param
out     jsr emit_esc
skip    clc
        rts
eot     sec
        rts
.)

; flush : un $ resté seul (fin de fichier) est ignoré, comme DO
flush   lda #0
        sta pend
        rts

; param : recopie le paramètre numéro A (0 = $1) de pptr
param
.(
        sta t0
        ldy #0
word    jsr skip_sp
        lda t0
        beq copy
skipw   lda (pptr),y
        beq r
        cmp #" "
        beq endw
        iny
        bne skipw
endw    dec t0
        jmp word
copy    lda (pptr),y
        beq r
        cmp #" "
        beq r
        sty t2
        jsr emit_esc
        ldy t2
        iny
        bne copy
r       clc
        rts
skip_sp lda (pptr),y
        cmp #" "
        bne ss_r
        iny
        bne skip_sp
ss_r    rts
.)

; emit_esc : comme emit, mais un $ est écrit $$
emit_esc
        cmp #"$"
        bne emit
        jsr emit
        lda #"$"
; emit : ajoute A au résultat ; s'arrête si la mémoire est pleine
emit
.(
        ldy #0
        sta (optr),y
        inc optr
        bne nc
        inc optr+1
nc      lda optr+1
        cmp TPA_TOP+1
        bcs full
        rts
full    lda #<msg_big               ; abandonne tout
        ldy #>msg_big
        ldx #F_PRINT
        jsr BDOS
        jmp WBOOT
.)

; get_par : paramètres de l'appel (après XDO et le nom) dans bpar
get_par
.(
        ldx #0
        jsr sk
        jsr wd                  ; XDO
        jsr sk
        jsr wd                  ; nom du script
        jsr sk
        ldy #0
cp      lda ORIG_LINE,x
        sta bpar,y
        beq done
        inx
        iny
        cpy #79
        bne cp
        lda #0
        sta bpar,y
done    rts
sk      lda ORIG_LINE,x
        cmp #" "
        bne r
        inx
        bne sk
wd      lda ORIG_LINE,x
        beq r
        cmp #" "
        beq r
        inx
        bne wd
r       rts
.)

cmd_do  .asc "DO $$$",0
msg_use .asc "XDO NOM [p1..p9] : appel d'un script",13,10
        .asc "par un script (lance par le CCP)",13,10,"$"
msg_nofile .asc "Script introuvable",13,10,"$"
msg_disk .asc "Erreur disque (XDO)",13,10,"$"
msg_big .asc "Scripts trop longs (XDO)",13,10,"$"

ofcb    .byt 0
        .asc "$$$     BAT"
        .dsb 24,0
bfcb    .dsb 36,0
afcb    .dsb 36,0
bpar    .dsb 80,0
apar    .dsb 80,0
abuf    .dsb 128,0
rbuf    .dsb 128,0
buf
