; =====================================================================
;  acia_inc.s — accès à l'ACIA 6551 du modem, par scrutation
;
;  Bibliothèque incluse par TERM et XFER (jamais assemblée seule ; elle
;  n'a pas de #include : le programme inclut cpa.inc avant elle).
;
;  Port : l'ACIA émulée par le LOCI en $0380 (modem USB, un Pico W avec
;  PicoWiFiModemUSB : docs/loci-modem-wifi.md) ; sans LOCI, celle
;  d'Oricutron en $031C (serial = 'loopback' ou 'modem' dans
;  oricutron.cfg). Réglage : 9600 bauds, 8 bits, sans parité, 1 bit
;  d'arrêt, DTR actif, interruptions de l'ACIA coupées.
;
;  Accès aux registres : uniquement par LDA / STA absolus (routines
;  ac_rxxx / ac_wxxx, octet bas de l'adresse posé par ac_find). Jamais
;  d'adressage indexé : STA (zp),Y lit l'adresse visée avant de l'écrire,
;  et une lecture de l'ACIA a des effets (registre de données : octet
;  consommé), le LOCI en particulier.
;
;  Pas de tampon ni d'interruption : sur le LOCI, rien ne se perd si
;  l'Oric tarde à lire (le LOCI ne prend au modem que ce qu'il peut
;  garder, le Pico et TCP attendent : docs/loci-modem-wifi.md,
;  « Contrôle de flux »). Oricutron garde aussi ce qui arrive.
;
;  Routines :
;    ac_find   cherche le port et pose les adresses : C=0 LOCI ($0380),
;              C=1 Oricutron ($031C)
;    ac_setup  règle l'ACIA (remise à zéro, 9600 8N1, DTR) puis attend
;              que le LOCI ait pris l'ordre ; A <> 0 : pas de modem (DSR)
;    ac_get    octet reçu ? C=1 : oui, dans A ; C=0 : rien
;    ac_getw   attend un octet au plus Y cinquantièmes de seconde
;              (compteur 50 Hz) : C=1 reçu dans A, C=0 rien
;    ac_txw    attend l'émetteur libre au plus ~0,3 s : C=1 s'il ne l'est
;              pas (modem débranché : le LOCI ne vide plus le registre)
;    ac_put    envoie A (gardé) : C=1 si l'émetteur ne s'est pas libéré
;    ac_rdat, ac_rsta, ac_rcmd, ac_rctl : lecture des registres (données,
;              état, commande, contrôle) ; ac_wdat... : écriture. Gardent
;              X et Y. État : bit 3 reçu, bit 4 émetteur libre, bit 6 pas
;              de DSR.
; =====================================================================

; ac_find : C=0 si le LOCI répond, C=1 sinon (Oricutron)
ac_find
.(
        jsr ac_lchk
        php
        lda #$80                ; LOCI : $0380
        bcc f1
        lda #$1C                ; Oricutron : $031C
f1      sta ac_rdat+1
        sta ac_wdat+1
        clc
        adc #1
        sta ac_rsta+1
        sta ac_wsta+1
        adc #1
        sta ac_rcmd+1
        sta ac_wcmd+1
        adc #1
        sta ac_rctl+1
        sta ac_wctl+1
        plp
        rts
.)

; ac_setup : remise à zéro, 9600 bauds 8N1, DTR et RTS, sans IRQ ;
;   A <> 0 au retour : DSR absent (pas de modem branché)
ac_setup
.(
        jsr ac_wsta             ; remise à zéro programmée
        lda #$1E                ; 9600 bauds, horloge interne, 8 bits, 1 arrêt
        jsr ac_wctl
        lda #$0B                ; DTR, RTS, pas de parité, ni écho ni IRQ
        jsr ac_wcmd
        ldx #0                  ; laisse au LOCI le temps de prendre l'ordre
        ldy #0
w1      dey
        bne w1
        dex
        bne w1
        jsr ac_rsta
        and #$40
        rts
.)

; ac_get : C=1 et A = octet reçu, C=0 si rien n'attend
ac_get
.(
        jsr ac_rsta
        and #$08
        beq no
        jsr ac_rdat
        sec
        rts
no      clc
        rts
.)

; ac_getw : attend un octet au plus Y cinquantièmes de seconde
ac_getw
.(
        sty ac_tmo
        lda SYS_TICKS
        sta ac_t0
w       jsr ac_get
        bcs r
        lda SYS_TICKS
        sec
        sbc ac_t0
        cmp ac_tmo
        bcc w
        clc
r       rts
.)

; ac_txw : C=0 quand l'émetteur est libre, C=1 au bout de ~0,3 s
ac_txw
.(
        lda #0
        sta ac_cnt
        lda #$40
        sta ac_cnt+1
w       jsr ac_rsta
        and #$10
        bne ok
        dec ac_cnt
        bne w
        dec ac_cnt+1
        bne w
        sec
        rts
ok      clc
        rts
.)

; ac_put : envoie A (gardé) ; C=1 si l'émetteur est resté occupé
ac_put
.(
        pha
        jsr ac_txw
        pla
        bcs r
        jsr ac_wdat
r       rts
.)

; registres : LDA / STA absolus, octet bas posé par ac_find
ac_rdat lda $0380
        rts
ac_rsta lda $0381
        rts
ac_rcmd lda $0382
        rts
ac_rctl lda $0383
        rts
ac_wdat sta $0380
        rts
ac_wsta sta $0381
        rts
ac_wcmd sta $0382
        rts
ac_wctl sta $0383
        rts

; ac_lchk : C=0 si le LOCI répond (même test que mia_chk de loci_inc.s,
;   sans message) : opération 0 lancée, puis CLV/BVC/LDA #/LDX #/RTS lus
;   en $03B0. Sans LOCI, l'écriture tombe sur un registre du VIA, sans effet.
ac_lchk
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

ac_cnt  .byt 0,0                ; compteur d'attente de ac_txw
ac_tmo  .byt 0                  ; délai de ac_getw
ac_t0   .byt 0                  ; compteur 50 Hz au départ
