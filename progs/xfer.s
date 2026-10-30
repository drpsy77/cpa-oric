; =====================================================================
;  XFER.COM — envoi et réception de fichiers par le modem (XMODEM)
;
;  XFER R fic [nom] [/T]   reçoit nom du serveur et l'écrit dans fic
;  XFER E fic [nom] [/T]   envoie fic au serveur, sous le nom nom
;    (S est accepté pour E : « send » sur la disquette anglaise)
;    fic  fichier de CP/A, lecteur facultatif (B:LETTRE.TXT), sans jokers
;    nom  nom du fichier côté serveur ; par défaut fic tel qu'il a été
;         tapé, sans le lecteur (minuscules gardées)
;    /T   texte : le serveur passe les fins de ligne LF du Mac en CR LF
;         (et l'inverse), une tabulation en espace, et le texte en ASCII
;         (accents et cédille retirés, oe, ae)
;
;  La liaison doit être établie : TERM, ATDT-hote:port vers le serveur
;  (tools/xfer_server.py sur le Mac ou le Pi), puis CTRL-Q (la liaison
;  reste ouverte). XFER envoie une ligne de commande au serveur
;  (« XFER GET nom [T] » ou « XFER PUT nom [T] », CR), attend sa réponse
;  (« +... » : d'accord ; « -A... » : fichier absent ; « -... » : autre
;  refus ; message affiché dans la langue de la disquette), puis le
;  transfert se fait en XMODEM : blocs de 128 octets (un enregistrement
;  CP/M), numérotés, contrôlés par CRC-16 (XMODEM-CRC ; en envoi, la
;  somme simple est acceptée si le récepteur la demande), chacun acquitté
;  avant le suivant. Le dernier enregistrement d'un fichier CP/M est déjà
;  complété par des ^Z ; le serveur les retire.
;
;  Réception : écrite dans NOM.$$$, qui remplace NOM à la fin seulement
;  (disque plein, ESC, coupure : l'ancien NOM reste intact) ; un NOM
;  protégé (R/O) n'est pas remplacé. ESC : annule (CAN envoyé au
;  serveur). Une erreur (bloc abîmé, délai) fait redemander le bloc,
;  dix fois au plus.
;
;  Port : bibliothèque acia_inc.s (LOCI en $0380, Oricutron en $031C). Le
;  réglage de l'ACIA n'est refait que s'il a changé (la liaison ouverte
;  par TERM n'est pas touchée).
; =====================================================================

#include "cpa.inc"

SOH     = $01
EOT     = $04
ACK     = $06
NAK     = $15
CAN     = $18

dir     = $10           ; 1 = recevoir, 0 = envoyer
text    = $11           ; 1 = /T
blk     = $12           ; numéro du bloc attendu ou envoyé (modulo 256)
nblk    = $13           ; 2 octets : blocs transférés
tries   = $15           ; erreurs de suite
crcm    = $16           ; 1 = CRC-16, 0 = somme simple
crc     = $17           ; 2 octets : CRC (bas, haut)
sum     = $19
first   = $1A           ; 1 = premier bloc pas encore reçu
w2      = $1B           ; position du nom de fichier dans TAIL
w3      = $1C           ; position du nom distant (0 : aucun)
tmo     = $1D           ; attentes de 5 s restantes
num     = $1E           ; 2 octets : nombre à afficher

        *= $0500
start
.(
        lda #0
        sta text
        sta w3
        ldx #0                  ; /T n'importe où
o1      lda TAIL+1,x
        beq o3
        cmp #"/"
        bne o2
        lda TAIL+2,x
        and #$DF
        cmp #"T"
        bne o2
        inc text
o2      inx
        bne o1
o3      ldx #0                  ; sens : R, E ou S, un seul caractère
        jsr skipsp
        lda TAIL+1,x
        and #$DF
        ldy #1
        cmp #"R"
        beq d1
        dey
        cmp #"E"
        beq d1
        cmp #"S"
        bne usage
d1      sty dir
        lda TAIL+2,x
        cmp #" "
        bne usage
        inx
        jsr skipsp
        lda TAIL+1,x            ; fichier : FCB2, rempli par le CCP
        beq usage
        cmp #"/"
        beq usage
        stx w2
        jsr skipw
        jsr skipsp
        lda TAIL+1,x            ; nom distant facultatif
        beq d2
        cmp #"/"
        beq d2
        stx w3
d2      lda FCB2+1
        cmp #" "
        bne d3
usage   lda #<m_use
        ldy #>m_use
        jmp puts
d3      ldx #11                 ; pas de jokers
d4      lda FCB2,x
        cmp #"?"
        beq wild
        dex
        bne d4
        jsr mkname
        jsr mkfcb
        jsr ac_find             ; port, réglé seulement s'il le faut
        jsr ac_rcmd
        cmp #$0B
        bne d5
        jsr ac_rctl
        cmp #$1E
        beq d6
d5      jsr ac_setup
d6      jsr ac_rsta
        and #$40
        beq d7
        lda #<m_nodsr
        ldy #>m_nodsr
        jmp puts
wild    lda #<m_wild
        ldy #>m_wild
        jmp puts
d7      lda #<buf               ; enregistrements lus et écrits dans buf
        ldy #>buf
        ldx #F_SETDMA
        jsr BDOS
        lda dir
        beq d8
        jmp receive
d8      jmp send
.)

; skipsp : X sur le premier caractère non blanc de TAIL+1
skipsp
.(
l       lda TAIL+1,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)

; skipw : X après le mot courant de TAIL+1
skipw
.(
l       lda TAIL+1,x
        beq r
        cmp #" "
        beq r
        inx
        bne l
r       rts
.)

; mkname : nom distant dans rname (terminé par 0) : le mot w3, sinon le
;   mot w2 sans « X: » ; s'arrête à un blanc ou à « / »
mkname
.(
        ldx w3
        bne m1
        ldx w2
        lda TAIL+2,x
        cmp #":"
        bne m1
        inx
        inx
m1      ldy #0
m2      lda TAIL+1,x
        beq m3
        cmp #" "
        beq m3
        cmp #"/"
        beq m3
        sta rname,y
        inx
        iny
        cpy #60
        bne m2
m3      lda #0
        sta rname,y
        rts
.)

; mkfcb : tfcb = fichier de FCB2 (lecteur, nom), ffcb = même nom en .$$$
mkfcb
.(
        ldx #35
        lda #0
z       sta tfcb,x
        sta ffcb,x
        dex
        bpl z
        ldx #11
c       lda FCB2,x
        sta tfcb,x
        sta ffcb,x
        dex
        bpl c
        lda #"$"
        sta ffcb+9
        sta ffcb+10
        sta ffcb+11
        rts
.)

; ---------------------------------------------------------------------
; receive : XFER R
receive
.(
        ldx #F_DELETE           ; NOM.$$$ refait à neuf
        jsr fbd
        ldx #F_MAKE
        jsr fbd
        cmp #$FF
        bne r1
        lda #<m_dfull
        ldy #>m_dfull
        jmp puts
r1      lda #<m_rcv
        ldy #>m_rcv
        jsr prname
        lda #<c_get
        ldy #>c_get
        jsr command
        bcc r2
        jmp rfail
r2      lda #1
        sta blk
        sta first
        lda #0
        sta nblk
        sta nblk+1
        sta tries
        lda #"C"                ; XMODEM-CRC demandé
        jsr ac_put
rl      jsr esc
        bcc r3
        jmp rcan
r3      ldy #150                ; 3 s
        jsr ac_getw
        bcs r4
        jsr error               ; rien : redemande
        bcc r5
        jmp rfail
r5      lda first
        beq r6
        lda #"C"
        bne r7
r6      lda #NAK
r7      jsr ac_put
        jmp rl
r4      cmp #SOH
        beq rblock
        cmp #EOT
        beq reot
        cmp #CAN
        bne rl
        lda #<m_can
        ldy #>m_can
        jsr puts
        jmp rfail
reot    lda #ACK
        jsr ac_put
        jmp rdone

rblock  jsr getb                ; numéro, complément, 128 octets, CRC
        bcc rbad
        sta rblk
        jsr getb
        bcc rbad
        eor rblk
        cmp #$FF
        bne rbad
        lda #0
        sta crc
        sta crc+1
        ldx #0
rb1     jsr getb
        bcc rbad
        sta buf,x
        jsr crcupd
        inx
        cpx #128
        bne rb1
        jsr getb
        bcc rbad
        cmp crc+1
        bne rbad
        jsr getb
        bcc rbad
        cmp crc
        bne rbad
        lda #0
        sta first
        lda rblk
        cmp blk
        beq rnew
        clc                     ; bloc précédent répété : acquitté
        adc #1
        cmp blk
        beq rack
        jmp rcan2               ; synchronisation perdue
rnew    ldx #F_WRITE
        jsr fbd
        cmp #0
        beq rw
        jsr cancel
        lda #<m_dfull
        ldy #>m_dfull
        jsr puts
        jmp rfail
rw      inc blk
        jsr count
rack    lda #0
        sta tries
        lda #ACK
        jsr ac_put
        jmp rl
rbad    jsr purge
        jsr error
        bcc rb2
        jmp rfail
rb2     lda #NAK
        jsr ac_put
        jmp rl

rcan    jsr cancel              ; ESC
        lda #<m_esc
        ldy #>m_esc
        jsr puts
        jmp rfail
rcan2   jsr cancel
        lda #<m_fail
        ldy #>m_fail
        jsr puts
rfail   ldx #F_CLOSE            ; NOM.$$$ fermé puis effacé
        jsr fbd
        ldx #F_DELETE
        jmp fbd

rdone   ldx #F_CLOSE
        jsr fbd
        jsr pdone
        ldx #F_DELETE           ; NOM remplacé par NOM.$$$
        jsr tbd
        cmp #$FE
        bne rd1
        lda #<m_ro
        ldy #>m_ro
        jsr puts
        ldx #F_DELETE
        jmp fbd
rd1     ldx #15
rd2     lda ffcb,x
        sta rfcb,x
        lda tfcb,x
        sta rfcb+16,x
        dex
        bpl rd2
        lda #<rfcb
        ldy #>rfcb
        ldx #F_RENAME
        jsr BDOS
        cmp #0
        beq rd3
        lda #<m_renf
        ldy #>m_renf
        jmp puts
rd3     rts
.)

; ---------------------------------------------------------------------
; send : XFER E
send
.(
        ldx #F_OPEN
        jsr tbd
        cmp #$FF
        bne s1
        lda #<m_nofil
        ldy #>m_nofil
        jmp puts
s1      lda #<m_snd
        ldy #>m_snd
        jsr prname
        lda #<c_put
        ldy #>c_put
        jsr command
        bcc s2
        rts
s2      lda #12                 ; le récepteur a 60 s pour demander
        sta tmo
sw      jsr esc
        bcs scan
        ldy #250
        jsr ac_getw
        bcs sw1
        dec tmo
        bne sw
        lda #<m_norep
        ldy #>m_norep
        jmp puts
sw1     ldx #1
        cmp #"C"
        beq sw2
        dex
        cmp #NAK
        beq sw2
        cmp #CAN
        bne sw
        lda #<m_can
        ldy #>m_can
        jmp puts
sw2     stx crcm
        lda #1
        sta blk
        lda #0
        sta nblk
        sta nblk+1

sl      ldx #F_READ             ; enregistrement suivant
        jsr tbd
        cmp #0
        bne seot
        lda #0
        sta tries
sb      jsr esc
        bcs scan
        jsr sblock
sa      ldy #250                ; réponse : 5 s, deux fois
        jsr ac_getw
        bcs sa1
        ldy #250
        jsr ac_getw
        bcc sbad
sa1     cmp #ACK
        beq sok
        cmp #NAK
        beq sbad
        cmp #CAN
        bne sa                  ; autre octet (« C » en trop) : ignoré
        lda #<m_can
        ldy #>m_can
        jmp puts
sok     inc blk
        jsr count
        jmp sl
sbad    jsr error
        bcc sb
sr      rts
scan    jsr cancel
        lda #<m_esc
        ldy #>m_esc
        jmp puts

seot    lda #0                  ; fin : EOT jusqu'à l'acquit
        sta tries
se1     lda #EOT
        jsr ac_put
        ldy #250
        jsr ac_getw
        bcc se2
        cmp #ACK
        beq se3
se2     jsr error
        bcc se1
        rts
se3     jmp pdone
.)

; sblock : envoie le bloc blk (buf), avec CRC ou somme selon crcm
sblock
.(
        lda #SOH
        jsr ac_put
        lda blk
        jsr ac_put
        lda blk
        eor #$FF
        jsr ac_put
        lda #0
        sta crc
        sta crc+1
        sta sum
        ldx #0
b1      lda buf,x
        jsr ac_put
        pha
        clc
        adc sum
        sta sum
        pla
        jsr crcupd
        inx
        cpx #128
        bne b1
        lda crcm
        beq b2
        lda crc+1
        jsr ac_put
        lda crc
        jmp ac_put
b2      lda sum
        jmp ac_put
.)

; ---------------------------------------------------------------------
; command : envoie « XFER GET » ou « XFER PUT » (A/Y), le nom distant,
;   « T » si /T, CR ; puis attend la réponse du serveur (10 s) :
;   « + » : C=0 ; « - » : message affiché, C=1 ; rien : C=1
command
.(
        sta ptr+1
        sty ptr+2
        jsr purge
        ldx #0
c1      jsr ptr
        beq c2
        jsr ac_put
        inx
        bne c1
c2      ldx #0
c3      lda rname,x
        beq c4
        jsr ac_put
        inx
        bne c3
c4      lda text
        beq c5
        lda #" "
        jsr ac_put
        lda #"T"
        jsr ac_put
c5      lda #13
        jsr ac_put
        lda #2                  ; réponse : 2 x 5 s
        sta tmo
c6      ldy #250
        jsr ac_getw
        bcs c7
        dec tmo
        bne c6
        lda #<m_norep
        ldy #>m_norep
        jsr puts
        sec
        rts
c7      cmp #"+"
        beq c8
        cmp #"-"
        bne c6                  ; autre chose (bannière...) : sauté
        ldy #50                 ; « -A » : fichier absent ; autre : refus
        jsr ac_getw
        sta sum
        jsr purge
        lda #<m_sabs
        ldy #>m_sabs
        ldx sum
        cpx #"A"
        beq c9
        lda #<m_sref
        ldy #>m_sref
c9      jsr puts
        sec
        rts
c8      ldy #50                 ; reste de la ligne « + » : sauté
        jsr ac_getw
        bcc c11
        cmp #10
        bne c8
c11     clc
        rts
.)

; ptr : lit l'octet X de la chaîne de commande (adresse posée en ptr+1)
ptr     lda $FFFF,x
        rts

; getb : octet d'un bloc, 1 s au plus ; C=0 si rien
getb    ldy #50
        jmp ac_getw

; purge : lit et jette jusqu'à 1 s de silence
purge
.(
l       ldy #50
        jsr ac_getw
        bcs l
        rts
.)

; error : une erreur de plus ; C=1 (message affiché) à la dixième
error
.(
        inc tries
        lda tries
        cmp #10
        bcc r
        jsr cancel
        lda #<m_fail
        ldy #>m_fail
        jsr puts
        sec
r       rts
.)

; cancel : CAN trois fois (le correspondant abandonne)
cancel
.(
        ldx #3
l       lda #CAN
        jsr ac_put
        dex
        bne l
        rts
.)

; esc : C=1 si ESC a été tapé
esc
.(
        jsr B_CONST
        cmp #0
        beq no
        jsr B_CONIN
        cmp #27
        beq r
no      clc
r       rts
.)

; crcupd : CRC-16 XMODEM (polynôme $1021, départ 0) mis à jour par A ;
;   garde X
crcupd
.(
        eor crc+1
        sta crc+1
        ldy #8
l       asl crc
        rol crc+1
        bcc n
        lda crc+1
        eor #$10
        sta crc+1
        lda crc
        eor #$21
        sta crc
n       dey
        bne l
        rts
.)

; count : un bloc de plus, affiché (« Bloc n » sur la même ligne)
count
.(
        inc nblk
        bne pblk
        inc nblk+1
.)
pblk
.(
        lda #<m_blk
        ldy #>m_blk
        jsr puts
        jmp pnblk
.)

; pdone : « Bloc n : termine »
pdone
        jsr pblk
        lda #<m_done
        ldy #>m_done
        jmp puts

; pnblk : affiche nblk en décimal (sans zéros de tête)
pnblk
.(
        lda nblk
        sta num
        lda nblk+1
        sta num+1
        ldx #4                  ; 10000, 1000, 100, 10, 1
        ldy #0                  ; Y = 1 dès le premier chiffre écrit
p1      lda #0
        sta sum
p2      lda num
        sec
        sbc p10lo,x
        pha
        lda num+1
        sbc p10hi,x
        bcc p3
        sta num+1
        pla
        sta num
        inc sum
        bne p2
p3      pla
        lda sum
        bne p4
        cpy #0
        bne p4
        cpx #0
        bne p5
p4      ora #"0"
        jsr B_CONOUT
        ldy #1
p5      dex
        bpl p1
        rts
.)
p10lo   .byt <1,<10,<100,<1000,<10000
p10hi   .byt >1,>10,>100,>1000,>10000

; prname : message A/Y puis le nom distant, fin de ligne
prname
        jsr puts
        ldx #0
pn1     lda rname,x
        beq crlf
        jsr B_CONOUT
        inx
        bne pn1
crlf    lda #13
        jsr B_CONOUT
        lda #10
        jmp B_CONOUT

; fbd, tbd : fonction X du BDOS sur ffcb (NOM.$$$) ou tfcb (NOM)
fbd     lda #<ffcb
        ldy #>ffcb
        jmp BDOS
tbd     lda #<tfcb
        ldy #>tfcb
        jmp BDOS

; puts : affiche la chaîne A/Y terminée par « $ »
puts    ldx #F_PRINT
        jmp BDOS

c_get   .asc "XFER GET ",0
c_put   .asc "XFER PUT ",0

#include "acia_inc.s"
#include "xfer.msg"

; données hors du fichier (après la fin du programme)
endp
rblk    = endp                  ; numéro du bloc reçu
tfcb    = endp+1                ; 36 octets : fichier de CP/A
ffcb    = endp+37               ; 36 : NOM.$$$ pendant la réception
rfcb    = endp+73               ; 32 : renommage (ancien, nouveau)
rname   = endp+105              ; 61 : nom distant
buf     = endp+166              ; 128 : un enregistrement
