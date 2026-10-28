; =====================================================================
;  MKTAP.COM — fabrique un fichier .TAP pour l'Oric sous BASIC (CLOAD)
;
;  MKTAP NOM fic adr[,lg] [/R] [fic adr[,lg] [/R]]...
;  MKTAP NOM prog.BAS [/R] [fic adr[,lg] [/R]]...
;    NOM     fichier écrit (type .TAP par défaut), lecteur facultatif
;    fic     un bloc par fichier, chargé en adr (hexadécimal, $ admis),
;            nommé d'après le fichier sans son type ; 8 fichiers au plus
;    lg      longueur (hexadécimal) ; absente : celle du fichier, moins
;            les ^Z ($1A) qui complètent son dernier enregistrement
;            (règle de STAT et d'EXPORT) ; donnée : jusqu'à la taille
;            brute du fichier (enregistrements entiers), pour des
;            données qui finissent vraiment par $1A
;    /R      ce bloc est lancé après le chargement (une seule fois) :
;            seul bloc : marque de démarrage automatique ; plusieurs :
;            un chargeur BASIC est mis en tête (nommé NOM, lancé tout
;            seul) : 10 CLOAD"":CLOAD"":...:CALL#adr
;    .BAS    programme BASIC en texte (un seul, sans adresse) : codé
;            comme le ferait la ROM 1.1 (codebas), chargé en $0501 ;
;            /R : il est lancé (RUN) à la fin du chargement
;  Contrôles avant d'écrire : blocs dans $0500-$BFFF, sans chevauchement
;  (chargeur compris), longueur non nulle et pas plus grande que le
;  fichier, bloc /R en $0503 au plus tôt (la ROM met $00 en $0500-$0502
;  avant de le lancer). Le dernier enregistrement du .TAP est complété par des ^Z,
;  que EXPORT retire (un octet 0 est ajouté d'abord si le dernier octet
;  utile vaut $1A). Format : docs/oric-basic.md § 1. Même résultat que
;  tools/mktap.py (sur le PC).
; =====================================================================

#include "cpa.inc"

MAXB    = 8             ; blocs au plus
T_CLOAD = $B6           ; mots-clés du BASIC (ROM 1.1)
T_CALL  = $BF
T_DATA  = $91
T_REM   = $9D
T_PRINT = $BA
BASIC   = $0501         ; début d'un programme BASIC
BASMAX  = $97FF         ; fin d'un programme BASIC au plus (sous HIMEM)

fp      = $10           ; 2 octets : FCB en cours
sp      = $12           ; 2 octets : chaîne affichée
val     = $14           ; 2 octets : nombre lu
nd      = $16           ; chiffres lus
nb      = $17           ; nombre de blocs
ib      = $18           ; bloc en cours
aut     = $19           ; bloc /R ($FF : aucun)
opos    = $1A           ; position dans obuf
nrec    = $1B           ; 2 octets
k       = $1D           ; 2 octets : octets restant à copier, taille
ipos    = $1F           ; position dans ibuf
lastb   = $20           ; dernier octet écrit
jb      = $21           ; second bloc (chevauchement)
nall    = $22           ; blocs + chargeur
lpos    = $23           ; longueur du chargeur
pch     = $24           ; chiffre déjà écrit (hexa sans zéros de tête)
sp0     = $25           ; pile au départ
pa      = $26           ; 2 octets : comparaisons
pb      = $28           ; 2 octets
px      = $2A           ; X gardé par putb
bas     = $2B           ; bloc .BAS ($FF : aucun)
pw      = $2C           ; 2 octets : ligne codée suivante (pbuf...)
po      = $2E           ; 2 octets : texte codé de la ligne en cours
num     = $30           ; 2 octets : numéro de la ligne
nxt     = $32           ; 2 octets : plus petit numéro admis ensuite
slen    = $34           ; longueur de la ligne de texte (sbuf)
sovf    = $35           ; $80 : ligne de plus de 255 caractères
eof     = $36           ; $80 : fin du .BAS
dmode   = $37           ; $80 : dans un DATA
kp      = $38           ; 2 octets : mot-clé comparé
tok     = $3A           ; code du mot-clé comparé
sx      = $3B           ; début du mot comparé dans sbuf
sy      = $3C           ; Y gardé
clen    = $3D           ; octets codés de la ligne

        *= $0500
start
.(
        tsx
        stx sp0
        ldx #1
        jsr skipsp
        lda TAIL,x
        bne s1
usage   lda #<m_use
        ldy #>m_use
        jmp puts
badname lda #<m_name
        ldy #>m_name
        jmp fail
badadr  lda #<m_adr
        ldy #>m_adr
        jmp fail
s1      lda #<ofcb
        sta fp
        lda #>ofcb
        sta fp+1
        jsr pname
        bcs badname
        lda ofcb+9              ; type .TAP par défaut
        cmp #" "
        bne e1
        lda #"T"
        sta ofcb+9
        lda #"A"
        sta ofcb+10
        lda #"P"
        sta ofcb+11
e1      lda #0
        sta nb
        lda #$FF
        sta aut
        sta bas
loop    jsr skipsp
        lda TAIL,x
        bne l0
        jmp parsed
l0      lda nb
        cmp #MAXB
        bcc l1
        lda #<m_many
        ldy #>m_many
        jmp fail
l1      sta ib
        jsr setfp
        jsr pname
        bcs badname
        jsr isbas
        bne notbas
        jmp isb
bada    jmp badadr
notbas  jsr gethex
        bcs bada
        ldy nb
        lda val
        sta adrl,y
        lda val+1
        sta adrh,y
        lda #0
        sta lenl,y
        sta lenh,y
        lda TAIL,x
        cmp #","
        bne nolen
        inx
        jsr gethex
        bcs bada
        lda val
        ora val+1
        beq bada
        ldy nb
        lda val
        sta lenl,y
        lda val+1
        sta lenh,y
nolen   jsr skipsp
        lda TAIL,x
        cmp #"/"
        bne next
        lda TAIL+1,x
        and #$DF
        cmp #"R"
        bne jusage
        lda TAIL+2,x
        beq r1
        cmp #" "
        beq r1
jusage  jmp usage
r1      lda aut
        bmi r2
        lda #<m_two
        ldy #>m_two
        jmp fail
r2      lda nb
        sta aut
        inx
        inx
next    inc nb
        jmp loop
parsed  lda nb
        beq jusage
        jsr check
        jsr loader
        jsr overlap
        jsr write
        lda #<ofcb
        sta fp
        lda #>ofcb
        sta fp+1
        jsr pfull
        lda #<m_done
        ldy #>m_done
        jmp puts
isb     lda bas                 ; .BAS : un seul, sans adresse
        bmi b1
        lda #<m_one
        ldy #>m_one
        jmp fail
b1      lda nb
        sta bas
        stx sy
        jsr gethex
        bcs b2
        lda #<m_basa
        ldy #>m_basa
        jmp fail
b2      ldx sy
        ldy nb
        lda #<BASIC
        sta adrl,y
        lda #>BASIC
        sta adrh,y
        jmp nolen
.)

; fail : message A/Y puis retour au CCP (pile du départ)
fail    jsr puts
quit    ldx sp0
        txs
        rts

; failn : nom du fichier fp puis message A/Y, retour au CCP
failn
.(
        pha
        tya
        pha
        jsr pfull
        pla
        tay
        pla
        jmp fail
.)

; ---------------------------------------------------------------------
; check : pour chaque bloc, taille du fichier, longueur, fin, plage
check
.(
        lda #0
        sta ib
c1      jsr setfp
        jsr fopen
        cmp #$FF
        bne o1
        lda #<m_abs
        ldy #>m_abs
        jmp failn
o1      lda ib
        cmp bas
        bne o2
        jsr codebas             ; longueur : celle du programme codé
        ldy ib
        jmp fin
o2      lda fp
        ldy fp+1
        ldx #F_FSIZE
        jsr BDOS
        ldy #FCB_R0
        lda (fp),y
        sta nrec
        iny
        lda (fp),y
        sta nrec+1
        iny
        lda (fp),y
        bne big                 ; 32 Mo : hors de toute plage
        lda nrec+1              ; 512 enregistrements (64 Ko) ou plus
        cmp #2
        bcc small
big     jmp range
small
        lda nrec
        ora nrec+1
        beq void
        lda nrec                ; dernier enregistrement : R0-R1 = nrec - 1
        bne d1
        dec nrec+1
d1      dec nrec
        ldy #FCB_R0
        lda nrec
        sta (fp),y
        iny
        lda nrec+1
        sta (fp),y
        jsr dmai
        lda fp
        ldy fp+1
        ldx #F_RREAD
        jsr BDOS
        cmp #0
        beq rd
        lda #<m_rerr
        ldy #>m_rerr
        jmp failn
rd      ldy #127                ; ^Z de remplissage retirés
z1      lda ibuf,y
        cmp #$1A
        bne z2
        dey
        bpl z1
z2      iny                     ; Y = octets utiles du dernier
        lda nrec+1              ; k = (nrec - 1) x 128 + Y
        lsr
        lda nrec
        ror
        sta k+1
        lda #0
        ror
        sta k
        clc                     ; pb : taille brute (nrec x 128), plafond
        adc #128                ; d'une longueur donnée
        sta pb
        lda k+1
        adc #0
        sta pb+1
        tya
        clc
        adc k
        sta k
        bcc z3
        inc k+1
z3      lda k
        ora k+1
        bne nv
void    lda #<m_void
        ldy #>m_void
        jmp failn
nv      ldy ib
        lda lenl,y              ; longueur donnée : pas plus que le fichier
        ora lenh,y
        beq tsize
        lda pb
        cmp lenl,y
        lda pb+1
        sbc lenh,y
        bcs fin
        lda #<m_short
        ldy #>m_short
        jmp failn
tsize   lda k
        sta lenl,y
        lda k+1
        sta lenh,y
fin     lda lenl,y              ; fin = adr + (lg - 1), lg >= 1
        sec
        sbc #1
        sta pa
        lda lenh,y
        sbc #0
        sta pa+1
        lda adrl,y
        clc
        adc pa
        sta endl,y
        lda adrh,y
        adc pa+1
        sta endh,y
        bcs range               ; au-delà de $FFFF
        lda adrh,y              ; plage $0500-$BFFF
        cmp #$05
        bcc range
        lda endh,y
        cmp #$C0
        bcs range
        cpy bas                 ; .BAS : sa propre limite
        beq bl
        cpy aut                 ; bloc /R : $0503 au plus tôt
        bne nr
        lda adrh,y
        cmp #$05
        bne nr
        lda adrl,y
        cmp #3
        bcc low
nr      inc ib
        lda ib
        cmp nb
        beq r
        jmp c1
bl      lda endh,y              ; programme BASIC : sous HIMEM
        cmp #>BASMAX+1
        bcc nr
big2    lda #<m_big
        ldy #>m_big
        jmp failn
range   lda #<m_range
        ldy #>m_range
        jmp failn
low     lda #<m_rlow
        ldy #>m_rlow
        jmp failn
r       rts
.)

; ---------------------------------------------------------------------
; loader : avec /R (pas sur le .BAS) et plusieurs blocs, programme
;   BASIC dans lbuf : 10 CLOAD"":CLOAD"":...:CALL#adr ; sa plage devient
;   le bloc nb
loader
.(
        lda nb
        sta nall
        lda aut
        bmi r
        cmp bas
        beq r
        lda nb
        cmp #2
        bcc r
        lda bas                 ; chargeur et .BAS : tous deux en $0501
        bmi go
        lda #<m_rbas
        ldy #>m_rbas
        jmp fail
r       rts
go
        ldy #2
        lda #10                 ; ligne 10
        sta lbuf,y
        iny
        lda #0
        sta lbuf,y
        iny
        ldx nb
c       lda #T_CLOAD
        sta lbuf,y
        iny
        lda #$22                ; guillemets
        sta lbuf,y
        iny
        sta lbuf,y
        iny
        lda #":"
        sta lbuf,y
        iny
        dex
        bne c
        lda #T_CALL
        sta lbuf,y
        iny
        lda #"#"
        sta lbuf,y
        iny
        sty lpos
        ldx aut
        lda adrl,x
        sta val
        lda adrh,x
        sta val+1
        lda #0
        sta pch
        lda val+1               ; chiffres sans les zéros de tête
        jsr lhex
        lda val
        jsr lhex
        ldy lpos
        lda #0                  ; fin de la ligne
        sta lbuf,y
        iny
        tya                     ; lien : adresse de la fin du programme
        clc
        adc #<BASIC
        sta lbuf
        lda #>BASIC
        adc #0
        sta lbuf+1
        lda #0                  ; fin du programme (0 0), plus un octet :
        sta lbuf,y              ; la ROM prend la fin du bloc pour le
        iny                     ; début des variables
        sta lbuf,y
        iny
        sta lbuf,y
        iny
        sty lpos
        ldx nb                  ; plage du chargeur : bloc nb,
        lda #<BASIC             ; $0501 à $0500 + longueur (Y)
        sta adrl,x
        lda #>BASIC
        sta adrh,x
        sta endh,x
        tya
        sta endl,x
        inc nall
        rts
.)

; lhex : octet A en deux chiffres dans lbuf (lpos), sans zéros de tête
lhex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr d
        pla
        and #$0F
d       ora pch
        bne w
        rts
w       and #$0F
        tax
        lda hexd,x
        ldy lpos
        sta lbuf,y
        inc lpos
        lda #$10
        sta pch
        rts
.)

; ---------------------------------------------------------------------
; overlap : deux plages qui se chevauchent -> erreur
overlap
.(
        ldx #1
        stx ib
c1      lda #0
        sta jb
c2      ldx ib                  ; début(ib) <= fin(jb) ?
        ldy jb
        lda endl,y
        cmp adrl,x
        lda endh,y
        sbc adrh,x
        bcc no
        lda endl,x              ; et début(jb) <= fin(ib) ?
        cmp adrl,y
        lda endh,x
        sbc adrh,y
        bcc no
        jsr setfpn              ; « NOM : chevauche AUTRE »
        jsr pfull
        lda #<m_over
        ldy #>m_over
        jsr puts
        lda jb
        sta ib
        jsr setfpn
        jsr pfull
        jsr crlf
        jmp quit
no      inc jb
        lda jb
        cmp ib
        bne c2
        inc ib
        lda ib
        cmp nall
        bcc c1
        rts
.)

; ---------------------------------------------------------------------
; write : écrit le .TAP
write
.(
        lda #<ofcb
        sta fp
        lda #>ofcb
        sta fp+1
        jsr zfcb
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        cmp #$FE
        bne w1
        lda #<m_ro
        ldy #>m_ro
        jmp failn
w1      lda #<ofcb
        ldy #>ofcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne w2
        lda #<m_dir
        ldy #>m_dir
        jmp fail
w2      lda #0
        sta opos
        sta lastb
        lda nall                ; chargeur BASIC : type 0, lancé
        cmp nb
        beq blocs
        ldx nb
        stx ib
        lda #0
        ldy #$80
        jsr header
        ldx #0
p       lda lbuf,x
        jsr putb
        inx
        cpx lpos
        bne p
        jsr sumline
blocs   lda #0
        sta ib
b1      jsr setfp
        ldy #0                  ; démarrage automatique : seul bloc /R
        lda nall
        cmp nb
        bne b2
        lda ib
        cmp aut
        bne b2
        ldy #$80
b2      lda #$80                ; type : code machine, ou BASIC
        ldx ib
        cpx bas
        bne b4
        lda #0
b4      jsr header
        ldx ib                  ; .BAS : le programme codé (pbuf)
        cpx bas
        bne b5
        jsr pbas
        jmp cpd
b5      jsr setfp
        jsr fopen               ; relu depuis le début
        cmp #$FF
        bne b3
        jsr tclose
        lda #<m_rerr
        ldy #>m_rerr
        jmp failn
b3      ldx ib
        lda lenl,x
        sta k
        lda lenh,x
        sta k+1
        lda #128
        sta ipos
cp      lda k
        ora k+1
        beq cpd
        lda ipos
        bpl cp1
        jsr dmai
        lda fp
        ldy fp+1
        ldx #F_READ
        jsr BDOS
        lda #0
        sta ipos
cp1     ldx ipos
        lda ibuf,x
        jsr putb
        inc ipos
        lda k
        bne cp2
        dec k+1
cp2     dec k
        jmp cp
cpd     jsr sumline
        inc ib
        lda ib
        cmp nb
        beq b6
        jmp b1
b6      lda lastb               ; un ^Z utile ne doit pas être pris
        cmp #$1A                ; pour du remplissage
        bne pad
        lda #0
        jsr putb
pad     lda opos
        beq cl
        lda #$1A
        jsr putb
        jmp pad
cl      lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jmp BDOS
.)

; header : en-tête du bloc ib (A = type, Y = démarrage) ; nom : fp
header
.(
        pha
        tya
        pha
        ldx #4
s       lda #$16
        jsr putb
        dex
        bne s
        lda #$24
        jsr putb
        lda #0
        jsr putb
        jsr putb
        pla
        tax
        pla
        jsr putb                ; type
        txa
        jsr putb                ; démarrage
        ldx ib
        lda endh,x
        jsr putb
        lda endl,x
        jsr putb
        lda adrh,x
        jsr putb
        lda adrl,x
        jsr putb
        lda #0
        jsr putb
        jsr setfpn
        ldy #1
n       lda (fp),y
        cmp #" "
        beq e
        jsr putb
        iny
        cpy #9
        bne n
e       lda #0
        jmp putb
.)

; putb : octet A dans le .TAP (registres gardés)
putb
.(
        sta lastb
        stx px
        ldx opos
        sta obuf,x
        inx
        stx opos
        ldx px
        bit opos                ; 128 : enregistrement plein
        bmi fl
        rts
fl      pha
        txa
        pha
        tya
        pha
        lda #<obuf
        ldy #>obuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<ofcb
        ldy #>ofcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        beq ok
        jsr tclose              ; disque plein : .TAP effacé
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        lda #<m_full
        ldy #>m_full
        jmp fail
ok      lda #0
        sta opos
        pla
        tay
        pla
        tax
        pla
        rts
.)

tclose  lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jmp BDOS

; sumline : « NOM      AAAA-BBBB » du bloc ib (chargeur : « BASIC »)
sumline
.(
        jsr setfpn
        ldy #1
n       lda (fp),y
        jsr putc
        iny
        cpy #9
        bne n
        lda #" "
        jsr putc
        ldx ib
        lda adrh,x
        jsr phex
        lda adrl,x
        jsr phex
        lda #"-"
        jsr putc
        lda endh,x
        jsr phex
        lda endl,x
        jsr phex
        cpx bas
        beq sb
        cpx nb
        bne sa
sb      lda #<m_bas
        ldy #>m_bas
        jsr puts
sa      cpx aut
        bne e
        lda #<m_run
        ldy #>m_run
        jsr puts
e       jmp crlf
.)

; ---------------------------------------------------------------------
; isbas : Z=1 si le FCB fp est de type .BAS (X gardé)
isbas
.(
        ldy #9
        lda (fp),y
        cmp #"B"
        bne r
        iny
        lda (fp),y
        cmp #"A"
        bne r
        iny
        lda (fp),y
        cmp #"S"
r       rts
.)

; ---------------------------------------------------------------------
; codebas : code le .BAS (fp, ouvert) dans pbuf comme la ROM 1.1 ;
;   lenl/lenh du bloc ib <- longueur du programme (fin 0 0, plus un
;   octet : la ROM en fait le début des variables). Erreurs : numéro
;   absent ou trop grand, ordre, ligne trop longue, caractère de code
;   $80 ou plus hors texte, plus de place ; avertissement : ligne de
;   plus de 78 caractères. Même codage que tools/mktap.py (code_bas).
codebas
.(
        lda #0
        sta eof
        sta nxt
        sta nxt+1
        lda #128                ; enregistrement à lire
        sta ipos
        lda #<pbuf
        sta pw
        lda #>pbuf
        sta pw+1
line    lda pw+1                ; place pour une ligne (260 octets) et
        clc                     ; la fin du programme
        adc #2
        cmp TPA_TOP+1
        bcc l0
        jmp nomem
l0      jsr rdline
        bcc l1
        jmp eofb
l1      ldx #0                  ; espaces de tête
sk      cpx slen
        beq line                ; ligne vide (ou d'espaces)
        lda sbuf,x
        cmp #" "
        bne n0
        inx
        bne sk
n0      lda #0                  ; numéro : chiffres, espaces admis
        sta num                 ; (comme Txt2Int de la ROM)
        sta num+1
        sta nd
n1      cpx slen
        beq n4
        lda sbuf,x
        cmp #" "
        beq n3
        sec
        sbc #"0"
        cmp #10
        bcs n4
        ldy num+1               ; 6400 ou plus : un chiffre de trop
        cpy #$19
        bcs badnum
        pha
        lda num                 ; num x 10 + chiffre
        asl
        rol num+1
        sta pa
        ldy num+1
        asl
        rol num+1
        asl
        rol num+1
        adc pa
        sta num
        tya
        adc num+1
        sta num+1
        pla
        clc
        adc num
        sta num
        bcc n2
        inc num+1
n2      inc nd
n3      inx
        bne n1
n4      lda nd
        bne n5
badnum  lda #<m_aft             ; « apres N : numero invalide »
        ldy #>m_aft
        jsr puts
        lda nxt                 ; N : la ligne précédente (0 au début)
        sec
        sbc #1
        sta val
        lda nxt+1
        sbc #0
        sta val+1
        bcs bn1
        lda #0
        sta val
        sta val+1
bn1     jsr pdec
        lda #<m_num
        ldy #>m_num
        jmp fail
n5      bit sovf
        bpl n6
        lda #<m_long
        ldy #>m_long
        jmp lfail
n6      cpx slen                ; numéro seul : rien
        bne n7
        jmp line
n7      lda num                 ; numéros croissants
        cmp nxt
        lda num+1
        sbc nxt+1
        bcs n8
        lda #<m_ord
        ldy #>m_ord
        jmp lfail
n8      lda slen                ; plus que l'éditeur de l'Oric
        cmp #79
        bcc n9
        stx sx
        jsr lnum
        lda #<m_78
        ldy #>m_78
        jsr puts
        ldx sx
n9      lda pw                  ; texte codé en pw + 4
        clc
        adc #4
        sta po
        lda pw+1
        adc #0
        sta po+1
        jsr crunch
        cpy #251                ; 250 octets codés au plus
        bcc c1
        lda #<m_long
        ldy #>m_long
        jmp lfail
c1      lda #0                  ; fin de la ligne
        sta (po),y
        iny
        tya                     ; pw <- po + Y (ligne suivante)
        clc
        adc po
        sta po
        lda po+1
        adc #0
        sta po+1
        ldy #0                  ; lien : son adresse sous BASIC,
        lda po                  ; $0501 + (po - pbuf)
        sec
        sbc #<pbuf
        php
        clc
        adc #<BASIC
        sta (pw),y
        lda po+1
        adc #>BASIC
        plp
        sbc #>pbuf
        iny
        sta (pw),y
        iny
        lda num                 ; numéro
        sta (pw),y
        iny
        lda num+1
        sta (pw),y
        lda po
        sta pw
        lda po+1
        sta pw+1
        lda num                 ; numéro suivant au moins num + 1
        clc
        adc #1
        sta nxt
        lda num+1
        adc #0
        sta nxt+1
        jmp line
eofb    ldy #2                  ; fin : 0 0, plus un octet
        lda #0
e1      sta (pw),y
        dey
        bpl e1
        lda pw                  ; longueur = pw + 3 - pbuf
        clc
        adc #3
        sta pa
        lda pw+1
        adc #0
        sta pa+1
        ldy ib
        lda pa
        sec
        sbc #<pbuf
        sta lenl,y
        lda pa+1
        sbc #>pbuf
        sta lenh,y
        bne r
        lda lenl,y
        cmp #4
        bcs r
        lda #<m_void            ; aucune ligne
        ldy #>m_void
        jmp failn
nomem   lda #<m_big
        ldy #>m_big
        jmp failn
r       rts
.)

; lfail : « ligne N : » message A/Y, retour au CCP
lfail
.(
        pha
        tya
        pha
        jsr lnum
        pla
        tay
        pla
        jmp fail
.)

; lnum : « ligne N » (num)
lnum    lda #<m_lig
        ldy #>m_lig
        jsr puts
        lda num
        sta val
        lda num+1
        sta val+1
        ; puis pdec

; pdec : val en décimal, sans zéros de tête (val détruit)
pdec
.(
        lda #0
        sta pch
        ldx #4
c       ldy #0                  ; chiffre : soustractions de 10^X
s       lda val
        sec
        sbc dl,x
        pha
        lda val+1
        sbc dh,x
        bcc d
        sta val+1
        pla
        sta val
        iny
        bne s
d       pla
        tya
        bne w
        cpx #0
        beq w
        lda pch
        beq n
w       tya
        ora #"0"
        jsr putc
        lda #1
        sta pch
n       dex
        bpl c
        rts
dl      .byt <1,<10,<100,<1000,<10000
dh      .byt >1,>10,>100,>1000,>10000
.)

; ---------------------------------------------------------------------
; rdline : ligne de texte suivante du .BAS -> sbuf (slen caractères,
;   0 après), sans les caractères de contrôle ; sovf : plus de 255.
;   C=1 : fin du fichier, plus de ligne
rdline
.(
        lda #0
        sta slen
        sta sovf
        bit eof
        bmi e
l       jsr getch
        bcs f
        cmp #13
        beq r
        cmp #10
        beq r
        cmp #" "
        bcc l
        ldy slen
        cpy #255
        bcs o
        sta sbuf,y
        inc slen
        bne l
o       lda #$80
        sta sovf
        bne l
f       lda slen                ; dernière ligne sans fin de ligne
        ora sovf
        bne r
e       sec
        rts
r       ldy slen
        lda #0
        sta sbuf,y
        clc
        rts
.)

; getch : caractère suivant du .BAS -> A ; C=1 : fin (^Z ou fin du
;   fichier)
getch
.(
        bit eof
        bmi e
        lda ipos
        bpl g
        jsr dmai
        lda fp
        ldy fp+1
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne f
        sta ipos
g       ldx ipos
        inc ipos
        lda ibuf,x
        cmp #$1A
        beq f
        clc
        rts
f       lda #$80
        sta eof
e       sec
        rts
.)

; ---------------------------------------------------------------------
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
        lda #<m_car
        ldy #>m_car
        jmp lfail
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

; pbas : le programme codé (pbuf, lenl/lenh du bloc ib) dans le .TAP
pbas
.(
        lda #<pbuf
        sta pa
        lda #>pbuf
        sta pa+1
        ldx ib
        lda lenl,x
        sta k
        lda lenh,x
        sta k+1
        ldy #0
l       lda k
        ora k+1
        beq r
        lda (pa),y
        jsr putb
        inc pa
        bne d
        inc pa+1
d       lda k
        bne d2
        dec k+1
d2      dec k
        jmp l
r       rts
.)

; ---------------------------------------------------------------------
; setfp : fp <- FCB du bloc ib (bfcb + 36 x ib) ; X et Y gardés
setfp
.(
        pha
        txa
        pha
        lda #<bfcb
        sta fp
        lda #>bfcb
        sta fp+1
        ldx ib
        beq r
l       lda fp
        clc
        adc #36
        sta fp
        bcc n
        inc fp+1
n       dex
        bne l
r       pla
        tax
        pla
        rts
.)

; setfpn : comme setfp, mais le bloc nb (chargeur) est ofcb
setfpn
.(
        lda ib
        cmp nb
        bne setfp
        lda #<ofcb
        sta fp
        lda #>ofcb
        sta fp+1
        rts
.)

; zfcb : octets 12-35 du FCB fp à zéro
zfcb
.(
        ldy #12
        lda #0
l       sta (fp),y
        iny
        cpy #36
        bne l
        rts
.)

; fopen : ouvre le FCB fp depuis le début -> A ($FF : absent)
fopen   jsr zfcb
        lda fp
        ldy fp+1
        ldx #F_OPEN
        jmp BDOS

dmai    lda #<ibuf
        ldy #>ibuf
        ldx #F_SETDMA
        jmp BDOS

; ---------------------------------------------------------------------
; pname : nom en TAIL,X -> FCB fp (lecteur, nom, type ; 12-35 à zéro)
;   C=1 : nom vide ou invalide (jokers)
pname
.(
        ldy #0
        lda #0
        sta (fp),y
        iny
        lda #" "
b       sta (fp),y
        iny
        cpy #12
        bne b
        jsr zfcb
        lda TAIL+1,x            ; lecteur
        cmp #":"
        bne nm
        lda TAIL,x
        and #$DF
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        ldy #0
        sta (fp),y
        inx
        inx
nm      ldy #1
n1      jsr nchr
        bcs n2
        cmp #"."
        beq ty
        cpy #9
        bcs n3
        sta (fp),y
        iny
n3      inx
        bne n1
ty      inx
        ldy #9
t1      jsr nchr
        bcs n2
        cmp #"."
        beq bad
        cpy #12
        bcs t2
        sta (fp),y
        iny
t2      inx
        bne t1
n2      ldy #1                  ; nom vide : refusé
        lda (fp),y
        cmp #" "
        beq bad
        clc
        rts
bad     sec
        rts
.)

; nchr : caractère TAIL,X du nom en majuscule -> C=1 en fin de nom
;   (espace, virgule, fin) ; jokers et « : » : erreur (pile rendue)
nchr
.(
        lda TAIL,x
        beq e
        cmp #" "
        beq e
        cmp #","
        beq e
        cmp #"/"
        beq e
        cmp #"*"
        beq bad
        cmp #"?"
        beq bad
        cmp #":"
        beq bad
        cmp #"a"
        bcc r
        cmp #"z"+1
        bcs r
        and #$DF
r       clc
        rts
e       sec
        rts
bad     lda #<m_name
        ldy #>m_name
        jmp fail
.)

skipsp
.(
l       lda TAIL,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)

; gethex : nombre hexadécimal en TAIL,X (espaces sautés, $ admis,
;   4 chiffres au plus) -> C=0 : val, X sur l'espace, la virgule ou la
;   fin qui le suit ; C=1 : pas de nombre
gethex
.(
        jsr skipsp
        lda #0
        sta val
        sta val+1
        sta nd
        lda TAIL,x
        cmp #"$"
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
        cmp #5
        bcs no
        lda TAIL,x
        beq yes
        cmp #" "
        beq yes
        cmp #","
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

; ---------------------------------------------------------------------
; pfull : nom du FCB fp (B:NOM.EXT si le lecteur est donné)
pfull
.(
        ldy #0
        lda (fp),y
        beq nm
        clc
        adc #"A"-1
        jsr putc
        lda #":"
        jsr putc
nm      ldy #1
l1      lda (fp),y
        cmp #" "
        beq ex
        jsr putc
        iny
        cpy #9
        bne l1
ex      ldy #9
        lda (fp),y
        cmp #" "
        beq r
        lda #"."
        jsr putc
l2      lda (fp),y
        cmp #" "
        beq r
        jsr putc
        iny
        cpy #12
        bne l2
r       rts
.)

; phex : A en deux chiffres hexadécimaux (X et Y gardés)
phex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr d
        pla
        and #$0F
d       stx pb
        tax
        lda hexd,x
        ldx pb
        jmp putc
.)
hexd    .asc "0123456789ABCDEF"

putc
.(
        sta pa
        pha
        txa
        pha
        tya
        pha
        lda pa
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts
.)
crlf    lda #13
        jsr putc
        lda #10
        jmp putc
puts
.(
        sta sp
        sty sp+1
        ldy #0
l       lda (sp),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

#include "mktap.msg"
#include "bas_tab.s"

adrl    .dsb MAXB+1,0   ; plages des blocs (indice MAXB : chargeur)
adrh    .dsb MAXB+1,0
endl    .dsb MAXB+1,0
endh    .dsb MAXB+1,0
lenl    .dsb MAXB,0
lenh    .dsb MAXB,0
ofcb    .dsb 36,0       ; le .TAP
endp
bfcb    = endp          ; FCB des blocs (36 x 8)
ibuf    = bfcb+36*MAXB  ; enregistrement lu
obuf    = ibuf+128      ; enregistrement à écrire
lbuf    = obuf+128      ; chargeur BASIC (50 octets au plus)
sbuf    = lbuf+50       ; ligne de texte du .BAS (255 caractères, 0)
pbuf    = sbuf+256      ; programme BASIC codé
