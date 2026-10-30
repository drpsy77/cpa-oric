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
;  Port, réglage et accès aux registres : bibliothèque acia_inc.s
;  (LOCI en $0380, Oricutron en $031C ; 9600 bauds 8N1 ; LDA / STA
;  absolus seulement). Le LOCI transmet la vitesse au modem USB : jamais
;  1200 bauds (le firmware de juin 2026 redémarre alors le Pico en mode
;  BOOTSEL).
;
;  Touches envoyées : ASCII 0-127 tel quel, DEL -> BS (8), CTRL-H à
;  CTRL-K (28-31) -> 8-11. Flèches, SHIFT et CTRL avec les flèches :
;  rien (pas encore d'ANSI). FUNCT ouvre les menus du système ; pendant
;  ce temps le LOCI garde ce qui arrive (il ne lit le modem que s'il a
;  de la place : rien n'est perdu).
;  Reçu : affiché par la fonction 2 du BDOS, pour que PUT le capture
;  (CR, LF, BS, FF, TAB compris ; autres codes de contrôle et octets
;  >= 128 ignorés). Un CR est affiché en CR LF (un
;  serveur qui ne renvoie que CR, ou l'écho local de RETURN, passe bien à
;  la ligne), un LF seul aussi (un serveur Unix, comme nc sur le Mac,
;  n'envoie que LF) ; un LF qui suit aussitôt un CR est sauté (pas de
;  ligne vide avec ceux qui envoient CR LF). La pause en fin d'écran est
;  coupée pendant TERM (elle bloquerait la réception) puis rendue.
; =====================================================================

#include "cpa.inc"

blind   = $11           ; 1 = envoi sans attendre l'émetteur (/B)
echo    = $12           ; 1 = écho local
savpg   = $13           ; PAGE_ON à rendre
diag    = $16           ; 1 = diagnostic (/D)
last    = $17           ; dernier état affiché (/D)
wascr   = $18           ; 1 = dernier caractère reçu CR, 2 = LF seul (début de ligne)
crlf    = $19           ; 1 = RETURN envoie CR LF (/L)

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
opd     jsr ac_find
        lda #<m_loci
        ldy #>m_loci
        bcc hello
        lda #<m_oric
        ldy #>m_oric
hello   ldx #F_PRINT
        jsr BDOS
        lda #<m_keys
        ldy #>m_keys
        ldx #F_PRINT
        jsr BDOS
        jsr dregs               ; /D : registres avant le réglage
        jsr ac_setup
        jsr dregs               ; /D : et après
        jsr ac_rsta
        and #$40                ; DSR absent : pas de modem branché
        beq loop
        lda #<m_nodsr
        ldy #>m_nodsr
        ldx #F_PRINT
        jsr BDOS

loop    jsr ac_rsta             ; reçu ?
        ldx diag
        beq nod
        cmp last                ; /D : chaque changement de l'état
        beq nod
        sta last
        pha
        lda #"["
        jsr out
        pla
        pha
        jsr phex
        lda #"]"
        jsr out
        pla
nod     and #$08
        beq key
        jsr ac_rdat
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
        jsr ac_wdat             ; (A gardé)
        cmp #13                 ; /L : LF après CR
        bne s9
        ldx crlf
        beq s9
        jsr txwait
        bcs lost
        lda #10
        jsr ac_wdat
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
        jsr out
        lda #10
        jmp out
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
        jsr ac_rsta
        jsr hexsp
        jsr ac_rcmd
        jsr hexsp
        jsr ac_rctl
        jsr hexsp
        lda #$FF                ; le premier état sera affiché
        sta last
        lda #13
        jsr out
        lda #10
        jmp out
r       rts
.)

; hexsp : affiche une espace puis A en hexadécimal
hexsp
        pha
        lda #" "
        jsr out
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
        jmp out
.)

; show : affiche le caractère reçu A (CONOUT ignore les codes inutiles) ;
;   CR -> CR LF, LF seul -> CR LF, LF qui suit aussitôt un CR sauté
show
.(
        and #$7F
        cmp #10
        bne s1
        ldx wascr
        dex
        bne lf                  ; LF seul : CR LF
        stx wascr               ; LF après CR : déjà fait (wascr = 0)
        rts
lf      ldx #2                  ; début de ligne, mais un LF suivant compte
        stx wascr
        lda #13
        bne cr                  ; (toujours)
s1      ldx #0
        cmp #13
        bne s2
        inx
s2      stx wascr
        cpx #1
        beq cr
        jmp out
cr      jsr out
        lda #10
        jmp out
.)

; out : affiche A par la fonction 2 du BDOS, pas par CONOUT du BIOS :
;   l'entrée du BDOS vide le tampon de PUT, donc PUT NOM TERM capture une
;   session entière (X n'est pas gardé)
out
        ldx #F_CONOUT
        jmp BDOS

; txwait : attend que l'émetteur soit libre (ac_txw) ; C=1 s'il ne l'est
;   pas après ~0,3 s. /B : pas de lecture de l'état, pause fixe d'environ
;   3 ms, C=0.
txwait
.(
        lda blind
        bne b
        jmp ac_txw
b       ldx #4
        ldy #0
p       dey
        bne p
        dex
        bne p
        clc
        rts
.)

#include "acia_inc.s"
#include "term.msg"
