; =====================================================================
;  COPY.COM — copie de fichiers, jokers admis (comme PIP de CP/M)
;
;  COPY src [dst]
;    src  fichier(s) source, jokers * et ? admis, lecteur facultatif
;    dst  nom de la copie (COPY LETTRE.TXT LETTRE.BAK), ou lecteur seul
;         (COPY *.COM B: garde les noms), ou modèle avec jokers
;         (COPY *.TXT *.BAK : un ? prend le caractère de la source) ;
;         absent : le lecteur courant (COPY B:*.LOG)
;  Les fichiers sont copiés par gros blocs (toute la TPA), à travers
;  le BDOS. Les attributs ne sont pas recopiés (comme PIP) : la copie
;  d'une commande protégée est modifiable. Un fichier de destination
;  protégé (R/O) est laissé tel quel (« protege ») ; les autres
;  fichiers du même nom sont remplacés. ESC entre deux fichiers.
; =====================================================================

#include "cpa.inc"

MAXF    = 128           ; noms retenus au plus

ptr     = $10           ; 2 octets : tampon
cnt     = $12           ; noms trouvés
i       = $13
nrec    = $14           ; 2 octets
eof     = $16
ncp     = $17           ; fichiers copiés
cur     = $18           ; lecteur courant (1 = A:)
lp      = $19           ; 2 octets : liste des noms
sptr    = $1B           ; 2 octets
pch     = $1D
bufpg   = $1E

        *= $0500
start
.(
        lda FCB1+1
        cmp #" "
        bne s1
usage   lda #<m_use
        ldy #>m_use
        jmp puts
s1      ldx #F_CURDSK
        jsr BDOS
        clc
        adc #1
        sta cur
        ldx #11                 ; modèle de destination
c1      lda FCB2,x
        sta dtpl,x
        dex
        bpl c1
        lda dtpl+1
        cmp #" "
        bne named
        lda dtpl                ; ni nom ni lecteur : lecteur courant,
        bne dall                ; à condition que la source ait le sien
        lda FCB1
        beq usage
dall    ldx #11                 ; lecteur seul : mêmes noms
        lda #"?"
q       sta dtpl,x
        dex
        bne q
named   lda dtpl
        bne dd
        lda cur
        sta dtpl
dd      lda FCB1                ; lecteur de la source, résolu
        bne sd
        lda cur
sd      sta sfcb

        lda #>endp              ; tampon : après la liste (128 x 11 =
        clc                     ; 1 408 octets), aligné sur une page
        adc #7
        sta bufpg

        ; noms des fichiers source (premier extent de chacun)
        ldx #11
c2      lda FCB1,x
        sta sfcb+0,x
        dex
        bne c2
        lda #0
        sta sfcb+12
        sta cnt
        lda #<DEF_DMA
        ldy #>DEF_DMA
        ldx #F_SETDMA
        jsr BDOS
        lda #<sfcb
        ldy #>sfcb
        ldx #F_SFIRST
        jsr BDOS
sl      cmp #$FF
        beq listed
        lda cnt
        cmp #MAXF
        bcs nx
        jsr lname
        ldy #1
c3      lda DEF_DMA,y
        and #$7F
        dey
        sta (lp),y
        iny
        iny
        cpy #12
        bne c3
        inc cnt
nx      ldx #F_SNEXT
        jsr BDOS
        jmp sl
listed  lda cnt
        bne go
        lda #<m_none
        ldy #>m_none
        jmp puts

go      lda #0
        sta i
        sta ncp
each    jsr B_CONST             ; ESC : arrêt
        cmp #0
        beq noesc
        jsr B_CONIN
        cmp #27
        beq fin
noesc   jsr one
        bcs fin                 ; erreur grave : on s'arrête
        inc i
        lda i
        cmp cnt
        bne each
fin     lda ncp
        jsr pnum8
        lda #<m_done
        ldy #>m_done
        jmp puts
.)

; one : copie du fichier i -> C=1 si l'on doit s'arrêter
one
.(
        lda i
        jsr lname
        ldx #35                 ; deux FCB vides, lecteurs résolus
        lda #0
z       sta sfcb+1,x
        sta dfcb,x
        dex
        bpl z
        lda dtpl
        sta dfcb
        ldy #10
n       lda (lp),y
        sta sfcb+1,y
        tax
        lda dtpl+1,y            ; ? : caractère de la source
        cmp #"?"
        bne lit
        txa
lit     sta dfcb+1,y
        dey
        bpl n
        jsr pname               ; « NOM.EXT » (source)
        lda sfcb                ; même lecteur et même nom : refusé
        cmp dfcb
        bne diff
        ldy #11
s       lda sfcb,y
        cmp dfcb,y
        bne diff
        dey
        bne s
        lda #<m_same
        ldy #>m_same
        jmp msg_ok
diff    lda #<dfcb
        ldy #>dfcb
        ldx #F_DELETE
        jsr BDOS
        cmp #$FE                ; destination protégée : laissée
        bne del
        lda #<m_ro
        ldy #>m_ro
        jmp msg_ok
del     lda #<sfcb
        ldy #>sfcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne opened
        lda #<m_rerr
        ldy #>m_rerr
        jmp msg_ok
opened  lda #0
        sta sfcb+32
        lda #<dfcb
        ldy #>dfcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne made
        lda #<m_dir
        ldy #>m_dir
        jmp msg_stop
made    jsr fcopy
        bcc ok
        lda #<dfcb              ; disque plein : copie partielle effacée
        ldy #>dfcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<dfcb
        ldy #>dfcb
        ldx #F_DELETE
        jsr BDOS
        lda #<m_full
        ldy #>m_full
        jmp msg_stop
ok      lda #<dfcb
        ldy #>dfcb
        ldx #F_CLOSE
        jsr BDOS
        inc ncp
        jsr crlf
        clc
        rts
.)

; msg_ok : message A/Y, on continue ; msg_stop : message, on s'arrête
msg_ok  jsr puts
        clc
        rts
msg_stop
        jsr puts
        sec
        rts

; fcopy : sfcb -> dfcb, par gros blocs -> C=1 si écriture impossible
fcopy
.(
again   lda #0
        sta ptr
        lda bufpg
        sta ptr+1
        lda #0
        sta nrec
        sta nrec+1
        sta eof
rd      lda ptr+1               ; lit autant d'enregistrements que possible
        cmp TPA_TOP+1
        bcs wr
        lda ptr
        ldy ptr+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<sfcb
        ldy #>sfcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne at_eof
        jsr next_ptr
        inc nrec
        bne rd
        inc nrec+1
        bne rd
at_eof  lda #1
        sta eof
wr      lda #0                  ; puis les écrit
        sta ptr
        lda bufpg
        sta ptr+1
wl      lda nrec
        ora nrec+1
        beq written
        lda ptr
        ldy ptr+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<dfcb
        ldy #>dfcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        beq wok
        sec
        rts
wok     jsr next_ptr
        lda nrec
        bne d1
        dec nrec+1
d1      dec nrec
        jmp wl
written lda eof
        beq again
        clc
        rts
.)

next_ptr
.(
        lda ptr
        eor #$80
        sta ptr
        bne r
        inc ptr+1
r       rts
.)

; lname : lp <- liste + 11 x A
lname
.(
        tax
        lda #<list
        sta lp
        lda #>list
        sta lp+1
        cpx #0
        beq r
l       lda lp
        clc
        adc #11
        sta lp
        bcc n
        inc lp+1
n       dex
        bne l
r       rts
.)

; pname : nom de sfcb (B:NOM.EXT)
pname
.(
        lda sfcb
        clc
        adc #"A"-1
        jsr putc
        lda #":"
        jsr putc
        ldx #1
l1      lda sfcb,x
        cmp #" "
        beq ex
        jsr putc
        inx
        cpx #9
        bne l1
ex      lda sfcb+9
        cmp #" "
        beq r
        lda #"."
        jsr putc
        ldx #9
l2      lda sfcb,x
        cmp #" "
        beq r
        jsr putc
        inx
        cpx #12
        bne l2
r       rts
.)

; pnum8 : A (0-255) en décimal
pnum8
.(
        ldx #0
        stx pch
        ldy #2
d       ldx #0
s       cmp p10,y
        bcc o
        sbc p10,y
        inx
        bne s
o       pha
        txa
        bne pr
        lda pch
        bne pr
        cpy #0
        bne nx
pr      txa
        ora #"0"
        jsr putc
        inc pch
nx      pla
        dey
        bpl d
        rts
.)
p10     .byt 1,10,100

putc
.(
        sta sptr+1
        pha
        txa
        pha
        tya
        pha
        lda sptr+1
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
        sta lp
        sty lp+1
        ldy #0
l       lda (lp),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

m_use   .asc "COPY src [dst] : copie (jokers admis)",13,10
        .asc "COPY *.COM B:   COPY B:*.LOG",13,10
        .asc "COPY *.TXT *.BAK",13,10,0
m_none  .asc "Aucun fichier",13,10,0
m_same  .asc " : meme fichier",13,10,0
m_ro    .asc " : fichier protege",13,10,0
m_rerr  .asc " : illisible",13,10,0
m_dir   .asc 13,10,"Repertoire plein",13,10,0
m_full  .asc 13,10,"Disque plein",13,10,0
m_done  .asc " fichier(s) copie(s)",13,10,0

dtpl    .dsb 12,0       ; modèle de destination
sfcb    .dsb 36,0
dfcb    .dsb 36,0
endp
list    = endp          ; noms (11 octets chacun), puis tampon
