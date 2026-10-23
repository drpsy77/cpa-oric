; =====================================================================
;  TERM.COM — petit terminal série : parler au modem WiFi et aux serveurs
;
;  TERM [/E] [/D]
;    Ce qu'on tape part vers le port série ; ce qui arrive s'affiche.
;    CTRL-Q : quitter (la liaison reste ouverte : DTR reste actif).
;    /E     : écho local (pour un serveur qui ne renvoie pas les
;             caractères ; le modem, lui, les renvoie en mode commande).
;    /D     : diagnostic : registres état, commande et contrôle relus
;             avant et après le réglage, puis chaque changement de l'état
;             affiché entre crochets ([10] : émetteur libre, [18] : un
;             caractère reçu, bit 6 : pas de modem).
;
;  Port : l'ACIA 6551 émulée par le LOCI en $0380 (modem USB, un Pico W
;  avec PicoWiFiModemUSB : docs/loci-modem-wifi.md) ; sans LOCI, celle
;  d'Oricutron en $031C (serial = 'loopback' ou 'modem' dans
;  oricutron.cfg). Réglage : 9600 bauds, 8 bits, sans parité, 1 bit
;  d'arrêt, interruptions de l'ACIA coupées (tout est lu par scrutation).
;  Le LOCI transmet la vitesse au modem USB : jamais 1200 bauds (le
;  firmware de juin 2026 redémarre alors le Pico en mode BOOTSEL).
;
;  Touches envoyées : ASCII 0-127 tel quel, DEL -> BS (8), CTRL-H à
;  CTRL-K (28-31) -> 8-11. Flèches, SHIFT et CTRL avec les flèches :
;  rien (pas encore d'ANSI). FUNCT ouvre les menus du système ; pendant
;  ce temps le LOCI garde ce qui arrive (il ne lit le modem que s'il a
;  de la place : rien n'est perdu).
;  Reçu : affiché par CONOUT (CR, LF, BS, FF, TAB compris ; autres codes
;  de contrôle et octets >= 128 ignorés). La pause en fin d'écran est
;  coupée pendant TERM (elle bloquerait la réception) puis rendue.
; =====================================================================

#include "cpa.inc"

ap      = $10           ; adresse de l'ACIA (2 octets) : données, état, commande, contrôle
echo    = $12           ; 1 = écho local
savpg   = $13           ; PAGE_ON à rendre
cnt     = $14           ; compteur d'attente (2 octets)
diag    = $16           ; 1 = diagnostic (/D)
last    = $17           ; dernier état affiché (/D)

A_DATA  = 0             ; registres de l'ACIA, par (ap),y
A_STAT  = 1             ; bit 3 : reçu, bit 4 : émetteur libre, bit 6 : pas de DSR
A_CMD   = 2
A_CTRL  = 3

        *= $0500
start
.(
        lda PAGE_ON
        sta savpg
        lda #0
        sta PAGE_ON
        sta echo
        sta diag
        ldx #0                  ; options /E, /D
op      lda TAIL+1,x
        beq opd
        cmp #"/"
        bne opn
        lda TAIL+2,x
        and #$DF                ; e -> E
        ldy #1
        cmp #"E"
        bne op2
        sty echo
op2     cmp #"D"
        bne opn
        sty diag
opn     inx
        bne op
opd     lda #3
        sta ap+1
        jsr loci_chk
        bcs oric
        lda #$80                ; LOCI : $0380
        sta ap
        lda #<m_loci
        ldy #>m_loci
        bne hello
oric    lda #$1C                ; Oricutron : $031C
        sta ap
        lda #<m_oric
        ldy #>m_oric
hello   ldx #F_PRINT
        jsr BDOS
        lda #<m_keys
        ldy #>m_keys
        ldx #F_PRINT
        jsr BDOS
        jsr dregs               ; /D : registres avant le réglage
        ldy #A_STAT             ; remise à zéro programmée
        sta (ap),y
        ldy #A_CTRL
        lda #$1E                ; 9600 bauds, horloge interne, 8 bits, 1 arrêt
        sta (ap),y
        ldy #A_CMD
        lda #$0B                ; DTR, RTS, pas de parité, ni écho ni IRQ
        sta (ap),y
        ldx #0                  ; laisse au LOCI le temps de prendre l'ordre
        ldy #0
w1      dey
        bne w1
        dex
        bne w1
        jsr dregs               ; /D : et après
        ldy #A_STAT
        lda (ap),y
        and #$40                ; DSR absent : pas de modem branché
        beq loop
        lda #<m_nodsr
        ldy #>m_nodsr
        ldx #F_PRINT
        jsr BDOS

loop    ldy #A_STAT             ; reçu ?
        lda (ap),y
        ldx diag
        beq nod
        cmp last                ; /D : chaque changement de l'état
        beq nod
        sta last
        pha
        lda #"["
        jsr B_CONOUT
        pla
        pha
        jsr phex
        lda #"]"
        jsr B_CONOUT
        pla
nod     and #$08
        beq key
        ldy #A_DATA
        lda (ap),y
        jsr show
key     jsr B_CONST
        beq loop
        jsr B_CONIN
        cmp #17                 ; CTRL-Q : quitter
        beq quit
        cmp #$7F                ; DEL -> BS
        bne k1
        lda #8
        bne send
k1      cmp #28                 ; CTRL-H à CTRL-K -> 8 à 11
        bcc k2
        cmp #32
        bcs k3
        sbc #19                 ; (C=0 : 28 -> 8)
        bcs send
k2      cmp #8                  ; flèches (8 à 11) : rien
        bcc send
        cmp #12
        bcc loop
        bcs send
k3      cmp #$80                ; $80 et plus : SHIFT/CTRL + flèches, menus
        bcs loop
send    pha
        jsr txwait
        pla
        bcs lost
        ldy #A_DATA
        sta (ap),y
        ldx echo
        beq loop
        jsr show
        jmp loop
lost    lda #<m_lost
        ldy #>m_lost
        ldx #F_PRINT
        jsr BDOS
        jmp loop

quit    lda savpg
        sta PAGE_ON
        lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT
.)

; dregs : (/D) affiche « ACIA ee cc kk » : état, commande, contrôle
dregs
.(
        lda diag
        beq r
        lda #<m_regs
        ldy #>m_regs
        ldx #F_PRINT
        jsr BDOS
        ldy #A_STAT
l       sty cnt
        lda #" "
        jsr B_CONOUT
        ldy cnt
        lda (ap),y
        jsr phex
        ldy cnt
        iny
        cpy #4
        bne l
        lda #$FF                ; le premier état sera affiché
        sta last
        lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT
r       rts
.)

; phex : affiche A en deux chiffres hexadécimaux
phex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr dig
        pla
        and #$0F
dig     cmp #10
        bcc n
        adc #6                  ; (C=1) 10 -> "A"
n       adc #"0"
        jmp B_CONOUT
.)

; show : affiche le caractère reçu A (CONOUT ignore les codes inutiles)
show
        and #$7F
        jmp B_CONOUT

; txwait : attend que l'émetteur soit libre ; C=1 s'il ne l'est pas après
;   ~0,3 s (modem débranché : le LOCI ne vide plus le registre)
txwait
.(
        lda #0
        sta cnt
        lda #$40
        sta cnt+1
w       ldy #A_STAT
        lda (ap),y
        and #$10
        bne ok
        dec cnt
        bne w
        dec cnt+1
        bne w
        sec
        rts
ok      clc
        rts
.)

; loci_chk : C=0 si le LOCI répond (même test que mia_chk de loci_inc.s,
;   sans message) : opération 0 lancée, puis CLV/BVC/LDA #/LDX #/RTS lus
;   en $03B0. Sans LOCI, l'écriture tombe sur un registre du VIA, sans effet.
loci_chk
.(
        lda #0
        sta $03AF
        lda $03B0
        cmp #$B8
        bne no
        lda $03B1
        cmp #$50
        bne no
        lda $03B3
        cmp #$A9
        bne no
        lda $03B5
        cmp #$A2
        bne no
        lda $03B7
        cmp #$60
        bne no
        clc
        rts
no      sec
        rts
.)

#include "term.msg"
