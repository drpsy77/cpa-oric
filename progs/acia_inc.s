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
;    ac_txw    attend l'émetteur libre au plus 5 s : C=1 s'il ne l'est
;              pas (modem débranché : le LOCI ne vide plus le registre).
;              Le Pico W retient parfois l'envoi plusieurs dixièmes de
;              seconde : une attente plus courte perdait des octets.
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

; ac_txw : C=0 quand l'émetteur est libre, C=1 au bout de 5 s (compteur
;   50 Hz : interruptions permises)
ac_txw
.(
        jsr ac_rsta
        and #$10
        bne ok
        lda SYS_TICKS
        sta ac_cnt
w       jsr ac_rsta
        and #$10
        bne ok
        lda SYS_TICKS
        sec
        sbc ac_cnt
        cmp #250
        bcc w
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

ac_cnt  .byt 0                  ; compteur 50 Hz au départ de ac_txw
ac_tmo  .byt 0                  ; délai de ac_getw
ac_t0   .byt 0                  ; compteur 50 Hz au départ

; =====================================================================
;  Appel du modem et fichier HOSTS (TERM, XFER)
;
;  Le programme définit ac_wrk : 266 octets libres hors du fichier (après
;  sa fin), et inclut acia.msg juste avant cette bibliothèque.
;
;    ac_dial  X = début du nom d'hôte dans TAIL+1 (« @ » en tête sauté),
;             A/Y = port par défaut (chiffres terminés par 0) ; ACIA déjà
;             réglée (ac_find, ac_setup). Cherche le nom dans HOSTS
;             (ac_host), compose et attend CONNECT (20 s au plus, ESC pour
;             renoncer). C=0 : liaison ouverte ; C=1 : échec, message
;             affiché. Si le modem ne répond pas à AT (liaison restée
;             ouverte), +++ et ATH0 d'abord. Un OK reçu après ATDT est
;             une réponse en retard : sauté.
;    ac_host  la recherche seule : adresse en ac_wrk+AC_ADR (terminée par
;             0 ; + ou = en tête : telnet), port en ac_wrk+AC_PRT
;    ac_esc   C=1 si ESC a été tapé
;    ac_busy  C=1 (message affiché) si la console à distance est active :
;             TERM et XFER liraient l'ACIA à sa place
;    ac_ser   fonction 117 du BDOS avec le bloc ac_blk (op, p1)
;    ac_hang  raccroche (+++ si la liaison est ouverte, puis ATH0)
;    ac_at    AT, après avoir vidé la ligne de commande du modem (CR) et
;             les réponses en retard : Z=1 si OK
;
;  HOSTS : fichier texte, une ligne « nom adresse[:port] » par hôte ; une
;  ligne qui commence par « ; » ou un blanc est ignorée. Nom : 15
;  caractères au plus, majuscules et minuscules confondues. Adresse
;  précédée de « + » ou « = » : telnet simulé ou vrai (sinon « - » :
;  octets bruts ; rien dans Oricutron, qui ne connaît pas ces signes).
;  Cherché sur le lecteur courant, puis sur A:. Un nom absent (ou pas de
;  fichier) part tel quel au modem (adresse IP, nom DNS) ; « nom:port »
;  tapé force le port.
; =====================================================================
AC_REC  = 36            ; ac_wrk : FCB de HOSTS (36 octets), puis :
AC_NAM  = 164           ;   enregistrement lu (128) ; nom cherché (16)
AC_ADR  = 180           ;   adresse (48)
AC_PRT  = 228           ;   port (6)
AC_LIN  = 234           ;   ligne reçue du modem (32)

ac_dial
.(
        jsr ac_host
        jsr ac_at               ; le modem répond-il ?
        beq dial
        cmp #4
        beq jesc
        jsr ac_hpl              ; liaison restée ouverte : +++, ATH0
        jsr ac_at
        beq dial
        cmp #4
        beq jesc
mute    lda #<ac_mmut
        ldy #>ac_mmut
        jmp fail
jesc    jmp esc
dial    lda #<ac_mcal           ; « Appel de adresse:port... »
        ldy #>ac_mcal
        ldx #F_PRINT
        jsr BDOS
        lda #0
        sta ac_dst
        jsr ac_show
        lda #<ac_mdot
        ldy #>ac_mdot
        ldx #F_PRINT
        jsr BDOS
        lda #<ac_satd           ; ATDT, mode, adresse:port, CR
        ldy #>ac_satd
        jsr ac_say
        lda ac_rdat+1
        cmp #$1C                ; Oricutron : sans signe de mode
        beq d1
        lda ac_wrk+AC_ADR
        cmp #"+"
        beq d0
        cmp #"="
        beq d0
        lda #"-"
d0      jsr ac_put
d1      inc ac_dst
        jsr ac_show
        lda #13
        jsr ac_put
d2      ldx #40                 ; 20 s
        jsr ac_resp
        cmp #0                  ; OK : réponse en retard d'une commande
        beq d2                  ;   précédente, sautée
        cmp #3
        beq mute
        cmp #4
        beq cesc
        pha                     ; ligne du modem : CONNECT, NO CARRIER...
        lda #0
        sta ac_dst
        tay
l       lda ac_wrk+AC_LIN,y
        beq l2
        jsr ac_ch
        iny
        bne l
l2      lda #<(ac_mdot+3)
        ldy #>(ac_mdot+3)
        ldx #F_PRINT
        jsr BDOS
        pla
        cmp #1                  ; CONNECT : C=0
        bne f2
        clc
        rts
cesc    lda #13                 ; un caractère arrête la composition
        jsr ac_put
esc     lda #<ac_mesc
        ldy #>ac_mesc
fail    ldx #F_PRINT
        jsr BDOS
f2      sec
        rts
.)

; ac_hang : raccroche : ATH0, précédé de +++ si le modem ne répond pas à
;   AT (liaison ouverte). ac_hpl : +++ et ATH0 sans essayer AT.
ac_hang
        jsr ac_at
        beq ac_h0
ac_hpl  ldy #60                 ; une seconde de silence avant et après +++
        jsr ac_wait
        lda #<ac_spl
        ldy #>ac_spl
        jsr ac_say
        ldy #60
        jsr ac_wait
ac_h0   lda #<ac_sath
        ldy #>ac_sath
        jsr ac_say
        ldx #4
        jmp ac_resp

; ac_at : vide la ligne de commande du modem (un reste, octets partis
;   pendant une liaison coupée, ferait répondre ERROR) et ce qui attend
;   (réponses en retard), puis envoie AT et attend la réponse 1 s ; Z=1 si
;   OK, sinon A = code de ac_resp
ac_at
        lda #13
        jsr ac_put
        jsr ac_purge
        lda #<ac_sat
        ldy #>ac_sat
        jsr ac_say
        ldx #2
        jsr ac_resp
        cmp #0
        rts

; ac_purge : jette ce qui arrive, jusqu'à 0,2 s de silence (255 octets au
;   plus)
ac_purge
.(
        ldx #0
p       ldy #10
        jsr ac_getw
        bcc r
        dex
        bne p
r       rts
.)

; ac_resp : lit les lignes du modem pendant X demi-secondes au plus ;
;   A = 0 OK, 1 CONNECT, 2 échec (NO CARRIER, NO DIALTONE, ERROR, BUSY),
;   3 rien, 4 ESC. La dernière ligne lue est en ac_wrk+AC_LIN (terminée
;   par 0) ; les autres lignes (écho de la commande...) sont sautées.
ac_resp
.(
        stx ac_n
l0      ldy #0
        sty ac_li
l1      jsr ac_esc
        bcs esc
        ldy #25
        jsr ac_getw
        bcs got
        dec ac_n
        bne l1
        lda #3
        rts
esc     lda #4
        rts
got     and #$7F
        jsr ac_eol
        beq eol
        ldy ac_li
        cpy #31
        bcs l1
        sta ac_wrk+AC_LIN,y
        inc ac_li
        bne l1
eol     ldy ac_li
        beq l1                  ; ligne vide
        lda #0
        sta ac_wrk+AC_LIN,y
        lda ac_wrk+AC_LIN+1
        and #$DF
        tay
        lda ac_wrk+AC_LIN
        and #$DF
        ldx #0
t       cmp ac_rk1,x            ; deux premières lettres connues ?
        bne n
        pha
        tya
        cmp ac_rk2,x
        beq k
        pla
n       inx
        cpx #5
        bne t
        beq l0
k       pla
        lda ac_rkc,x
        rts
.)
ac_rk1  .asc "OCNEB"                ; OK, CONNECT, NO..., ERROR, BUSY
ac_rk2  .asc "KOORU"
ac_rkc  .byt 0,1,2,2,2

; ac_say : envoie au modem la chaîne A/Y terminée par 0 (X, Y perdus)
ac_say
.(
        sta ac_sl+1
        sty ac_sl+2
        ldx #0
l       jsr ac_sl
        beq r
        jsr ac_put
        inx
        bne l
r       rts
.)
ac_sl   lda $FFFF,x
        rts

; ac_wait : attend Y cinquantièmes de seconde
ac_wait
.(
        sty ac_tmo
        lda SYS_TICKS
        sta ac_t0
w       lda SYS_TICKS
        sec
        sbc ac_t0
        cmp ac_tmo
        bcc w
        rts
.)

; ac_show : « adresse:port » (sans signe de mode) à l'écran (ac_dst = 0)
;   ou au modem (ac_dst = 1)
ac_show
.(
        ldy #0
        lda ac_wrk+AC_ADR
        cmp #"+"
        beq s0
        cmp #"="
        bne l
s0      iny
l       lda ac_wrk+AC_ADR,y
        beq p
        jsr ac_ch
        iny
        bne l
p       lda #":"
        jsr ac_ch
        ldy #0
l2      lda ac_wrk+AC_PRT,y
        beq r
        jsr ac_ch
        iny
        bne l2
r       rts
.)

; ac_ch : caractère A à l'écran (ac_dst = 0, fonction 2 du BDOS) ou au
;   modem (ac_dst = 1) ; garde Y
ac_ch
.(
        ldx ac_dst
        beq s
        jmp ac_put
s       sty ac_sy
        ldx #F_CONOUT
        jsr BDOS
        ldy ac_sy
        rts
.)

; ac_esc : C=1 si ESC a été tapé
ac_esc
.(
        jsr B_CONST
        cmp #0
        beq n
        jsr B_CONIN
        cmp #27
        beq r
n       clc
r       rts
.)

; ac_host : voir l'en-tête. X = nom dans TAIL+1, A/Y = port par défaut.
ac_host
.(
        sta ac_sl+1             ; port par défaut
        sty ac_sl+2
        stx ac_n
        ldx #0
p0      jsr ac_sl
        sta ac_wrk+AC_PRT,x
        inx
        cmp #0
        bne p0
        ldx ac_n
        lda TAIL+1,x
        cmp #"@"
        bne n0
        inx
n0      ldy #0                  ; nom tapé, en minuscules
        sty ac_fp
n1      lda TAIL+1,x
        jsr ac_end
        beq n4
        cmp #":"
        beq n2
        cpy #15
        bcs n1b
        jsr ac_low
        sta ac_wrk+AC_NAM,y
        iny
n1b     inx
        bne n1
n2      inc ac_fp               ; « :port » tapé
        lda #0
        sta ac_wrk+AC_NAM,y
        ldy #0
n2a     inx
        lda TAIL+1,x
        jsr ac_end
        beq n2c
        cpy #5
        bcs n2a
        sta ac_wrk+AC_PRT,y
        iny
        bne n2a
n2c     lda #0
        sta ac_wrk+AC_PRT,y
        beq n5
n4      lda #0
        sta ac_wrk+AC_NAM,y
n5      ldy #0                  ; adresse par défaut : le nom
c0      lda ac_wrk+AC_NAM,y
        sta ac_wrk+AC_ADR,y
        iny
        cmp #0
        bne c0
        lda #0                  ; HOSTS : lecteur courant, puis A:
        jsr ac_hop
        bcc rd
        lda #1
        jsr ac_hop
        bcc rd
        rts
skip    lda ac_lc               ; jusqu'à la fin de la ligne
s1      jsr ac_eol
        beq line
        jsr ac_hgc
        bcc s1
        rts
rd      lda #$80
        sta ac_hi
line    jsr ac_hgc              ; début de ligne
        bcs r
        cmp #";"
        beq skip
        cmp #" "+1
        bcc skip                ; blanc, CR, LF...
        ldy #0                  ; le nom
        sty ac_bad
cm      jsr ac_low
        cpy #16
        bcs bad
        cmp ac_wrk+AC_NAM,y
        beq ok
bad     sta ac_bad
ok      iny
        jsr ac_hgc
        bcs r
        cmp #" "+1
        bcs cm
        lda ac_bad
        bne skip
        cpy #16
        bcs skip
        lda ac_wrk+AC_NAM,y     ; nom cherché fini aussi ?
        bne skip
f1      lda ac_lc               ; trouvé : blancs sautés
        cmp #" "
        beq f2
        cmp #9
        bne f3
f2      jsr ac_hgc
        bcc f1
        rts
f3      cmp #" "+1
        bcc r                   ; pas d'adresse : le nom reste
        cmp #";"
        beq r
        ldy #0
f4      lda ac_lc
        cmp #" "+1
        bcc f6
        cmp #";"
        beq f6
        cmp #":"
        beq f7
        cpy #47
        bcs f5
        sta ac_wrk+AC_ADR,y
        iny
f5      jsr ac_hgc
        bcc f4
f6      lda #0
        sta ac_wrk+AC_ADR,y
r       rts
f7      lda #0                  ; port de la ligne, sauf « :port » tapé
        sta ac_wrk+AC_ADR,y
        lda ac_fp
        bne r
        tay
f8      jsr ac_hgc
        bcs f9
        cmp #"0"
        bcc f9
        cmp #"9"+1
        bcs f9
        cpy #5
        bcs f8
        sta ac_wrk+AC_PRT,y
        iny
        bne f8
f9      lda #0
        sta ac_wrk+AC_PRT,y
        rts
.)

; ac_hop : ouvre HOSTS sur le lecteur A (0 : courant, 1 : A:) ; C=1 absent
ac_hop
.(
        pha
        ldx #35
        lda #0
z       sta ac_wrk,x
        dex
        bpl z
        pla
        sta ac_wrk
        ldx #10
c       lda ac_hnm,x
        sta ac_wrk+1,x
        dex
        bpl c
        lda #<ac_wrk
        ldy #>ac_wrk
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        rts
.)
ac_hnm  .asc "HOSTS      "

; ac_hgc : caractère suivant de HOSTS dans A et ac_lc ; C=1 à la fin
ac_hgc
.(
        ldx ac_hi
        bpl g
        lda #<(ac_wrk+AC_REC)
        ldy #>(ac_wrk+AC_REC)
        ldx #F_SETDMA
        jsr BDOS
        lda #<ac_wrk
        ldy #>ac_wrk
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne eof
        tax
g       lda ac_wrk+AC_REC,x
        inx
        stx ac_hi
        and #$7F
        cmp #$1A
        beq eof
        sta ac_lc
        clc
        rts
eof     lda #$1A
        sta ac_lc
        sec
        rts
.)

; ac_eol : Z=1 si A est CR ou LF
ac_eol
        cmp #13
        beq ac_e1
        cmp #10
ac_e1   rts

; ac_end : Z=1 si A est 0, une espace ou « / » (fin d'un mot de TAIL)
ac_end
        cmp #0
        beq ac_e2
        cmp #" "
        beq ac_e2
        cmp #"/"
ac_e2   rts

; ac_low : lettre A en minuscule
ac_low
.(
        cmp #"A"
        bcc r
        cmp #"Z"+1
        bcs r
        ora #$20
r       rts
.)

; ac_busy : C=1 et message si la console à distance est active
ac_busy
.(
        lda #SE_STATE
        sta ac_blk
        jsr ac_ser
        cmp #$FF                ; pas de pilote série
        beq no
        and #2
        beq no
        lda #<ac_mrem
        ldy #>ac_mrem
        ldx #F_PRINT
        jsr BDOS
        sec
        rts
no      clc
        rts
.)

; ac_ser : fonction 117 du BDOS, bloc ac_blk (op, p1 ; le BDOS ne lit pas
;   plus loin)
ac_ser
        lda #<ac_blk
        ldy #>ac_blk
        ldx #F_SERIAL
        jmp BDOS
ac_blk  .byt 0,0

ac_sat  .asc "AT",13,0
ac_sath .asc "ATH0",13,0
ac_spl  .asc "+++",0
ac_satd .asc "ATDT",0
ac_n    .byt 0                  ; compteur (ac_resp) ; position (ac_host)
ac_li   .byt 0                  ; longueur de la ligne du modem
ac_dst  .byt 0                  ; ac_ch : 0 écran, 1 modem
ac_sy   .byt 0
ac_fp   .byt 0                  ; 1 = port tapé
ac_hi   .byt 0                  ; position dans l'enregistrement de HOSTS
ac_lc   .byt 0                  ; dernier caractère lu de HOSTS
ac_bad  .byt 0                  ; nom de la ligne différent
