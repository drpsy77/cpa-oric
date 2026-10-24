; =====================================================================
;  TERM.COM — petit terminal série : parler au modem WiFi et aux serveurs
;
;  TERM [/E] [/L] [/D] [/B]
;    Ce qu'on tape part vers le port série ; ce qui arrive s'affiche.
;    CTRL-Q : quitter (la liaison reste ouverte : DTR reste actif).
;    /E     : écho local (pour un serveur qui ne renvoie pas les
;             caractères ; le modem, lui, les renvoie en mode commande).
;    /L     : RETURN envoie CR LF au lieu de CR seul (serveurs qui
;             attendent LF, comme nc).
;    /D     : diagnostic : registres état, commande et contrôle relus
;             avant et après le réglage, puis chaque changement de l'état
;             affiché entre crochets ([10] : émetteur libre, [18] : un
;             caractère reçu, bit 6 : pas de modem).
;    /B     : envoi « en aveugle » : chaque caractère part sans attendre
;             l'état « émetteur libre » (pause fixe de ~3 ms), pour
;             vérifier les écritures quand les lectures de l'ACIA sont
;             fausses (TERM /B, puis ATDT vers nc sur le Mac).
;
;  Accès aux registres : uniquement par LDA / STA absolus (routines
;  r_xxx / w_xxx, adresses posées au démarrage). Jamais d'adressage
;  indexé : STA (zp),Y lit l'adresse visée avant de l'écrire, et une
;  lecture de l'ACIA a des effets (registre de données : octet consommé),
;  le LOCI en particulier (avis de son auteur, forum defence-force).
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
;  de contrôle et octets >= 128 ignorés). Un CR est affiché en CR LF (un
;  serveur qui ne renvoie que CR, ou l'écho local de RETURN, passe bien à
;  la ligne) ; un LF qui suit aussitôt un CR est sauté (pas de ligne vide
;  avec ceux qui envoient CR LF). La pause en fin d'écran est
;  coupée pendant TERM (elle bloquerait la réception) puis rendue.
; =====================================================================

#include "cpa.inc"

base    = $10           ; octet bas de l'adresse de l'ACIA ($80 LOCI, $1C Oricutron)
blind   = $11           ; 1 = envoi sans attendre l'émetteur (/B)
echo    = $12           ; 1 = écho local
savpg   = $13           ; PAGE_ON à rendre
cnt     = $14           ; compteur d'attente (2 octets)
diag    = $16           ; 1 = diagnostic (/D)
last    = $17           ; dernier état affiché (/D)
wascr   = $18           ; 1 = le dernier caractère affiché était un CR
crlf    = $19           ; 1 = RETURN envoie CR LF (/L)

; registres de l'ACIA (base + 0 à 3) : données, état (bit 3 : reçu,
; bit 4 : émetteur libre, bit 6 : pas de DSR), commande, contrôle

        *= $0500
start
.(
        lda PAGE_ON
        sta savpg
        lda #0
        sta PAGE_ON
        sta echo
        sta diag
        sta blind
        sta wascr
        sta crlf
        ldx #0                  ; options /E, /L, /D, /B
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
        bne op3
        sty diag
op3     cmp #"B"
        bne op4
        sty blind
op4     cmp #"L"
        bne opn
        sty crlf
opn     inx
        bne op
opd     jsr loci_chk
        bcs oric
        lda #$80                ; LOCI : $0380
        sta base
        lda #<m_loci
        ldy #>m_loci
        bne hello
oric    lda #$1C                ; Oricutron : $031C
        sta base
        lda #<m_oric
        ldy #>m_oric
hello   pha
        lda base                ; adresses des routines d'accès
        sta r_data+1
        sta w_data+1
        clc
        adc #1
        sta r_stat+1
        sta w_stat+1
        adc #1
        sta r_cmd+1
        sta w_cmd+1
        adc #1
        sta r_ctrl+1
        sta w_ctrl+1
        pla
        ldx #F_PRINT
        jsr BDOS
        lda #<m_keys
        ldy #>m_keys
        ldx #F_PRINT
        jsr BDOS
        jsr dregs               ; /D : registres avant le réglage
        jsr w_stat              ; remise à zéro programmée
        lda #$1E                ; 9600 bauds, horloge interne, 8 bits, 1 arrêt
        jsr w_ctrl
        lda #$0B                ; DTR, RTS, pas de parité, ni écho ni IRQ
        jsr w_cmd
        ldx #0                  ; laisse au LOCI le temps de prendre l'ordre
        ldy #0
w1      dey
        bne w1
        dex
        bne w1
        jsr dregs               ; /D : et après
        jsr r_stat
        and #$40                ; DSR absent : pas de modem branché
        beq loop
        lda #<m_nodsr
        ldy #>m_nodsr
        ldx #F_PRINT
        jsr BDOS

loop    jsr r_stat              ; reçu ?
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
        jsr r_data
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
        jsr w_data              ; (A gardé)
        cmp #13                 ; /L : LF après CR
        bne s9
        ldx crlf
        beq s9
        jsr txwait
        bcs lost
        lda #10
        jsr w_data
        lda #13
s9      ldx echo
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
        lda wascr               ; déjà en début de ligne : rien
        bne qr
        lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT
qr      rts
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
        jsr r_stat
        jsr hexsp
        jsr r_cmd
        jsr hexsp
        jsr r_ctrl
        jsr hexsp
        lda #$FF                ; le premier état sera affiché
        sta last
        lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT
r       rts
.)

; hexsp : affiche une espace puis A en hexadécimal
hexsp
        pha
        lda #" "
        jsr B_CONOUT
        pla
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

; show : affiche le caractère reçu A (CONOUT ignore les codes inutiles) ;
;   CR -> CR LF, LF qui suit aussitôt un CR sauté
show
.(
        and #$7F
        ldx #0
        cmp #10
        bne s1
        ldy wascr
        stx wascr
        beq out                 ; LF seul : affiché
        rts                     ; LF après CR : déjà fait
s1      cmp #13
        bne s2
        inx
s2      stx wascr
        cpx #1
        beq cr
out     jmp B_CONOUT
cr      jsr B_CONOUT
        lda #10
        jmp B_CONOUT
.)

; txwait : attend que l'émetteur soit libre ; C=1 s'il ne l'est pas après
;   ~0,3 s (modem débranché : le LOCI ne vide plus le registre).
;   /B : pas de lecture de l'état, pause fixe d'environ 3 ms, C=0.
txwait
.(
        lda blind
        beq nb
        ldx #4
        ldy #0
p       dey
        bne p
        dex
        bne p
        clc
        rts
nb      lda #0
        sta cnt
        lda #$40
        sta cnt+1
w       jsr r_stat
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

; routines d'accès aux registres : LDA / STA absolus, octet bas de
;   l'adresse posé au démarrage (base + 0 à 3). Préservent X et Y.
r_data  lda $0380
        rts
r_stat  lda $0381
        rts
r_cmd   lda $0382
        rts
r_ctrl  lda $0383
        rts
w_data  sta $0380
        rts
w_stat  sta $0381
        rts
w_cmd   sta $0382
        rts
w_ctrl  sta $0383
        rts

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
