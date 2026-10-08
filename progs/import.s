; =====================================================================
;  IMPORT.COM — copie un fichier de la clé USB du LOCI dans CP/A
;
;  IMPORT nom [fic] [/T]
;    nom  nom sur la clé, avec un chemin si l'on veut (1:/DOCS/X.TXT,
;         0:X.TXT pour la mémoire interne du LOCI)
;    fic  fichier de CP/A (lecteur facultatif) ; par défaut, le nom de
;         la clé sans son chemin, coupé à 8 + 3 caractères ; B: seul :
;         ce nom-là, sur le lecteur B:
;    /T   texte : un LF seul (fin de ligne du Mac, de Linux) devient
;         CR LF, la fin de ligne de CP/A
;  Un fichier de CP/A du même nom est remplacé. Le dernier
;  enregistrement est complété par des ^Z ($1A), comme le font EDIT et
;  mkdisk.py. En cas d'erreur, le fichier commencé est effacé.
; =====================================================================

#include "cpa.inc"

w1      = $10           ; position des mots dans args ($FF : absent)
w2      = $11
text    = $12           ; 1 = /T
fd      = $13
rp      = $14           ; position dans rec
last    = $15           ; dernier octet lu (pour /T)
n       = $16           ; octets dans iobuf
i       = $17
pp      = $18           ; 2 octets : nom à analyser
tot     = $1A           ; 4 octets : octets écrits
drv     = $1E           ; lecteur donné seul (B:), 0 sinon

        *= $0500
start
.(
        jsr get_args
        lda #$FF
        sta w1
        sta w2
        lda #0
        sta text
        ldx #0
word    jsr skipsp
        lda args,x
        beq parsed
        cmp #"/"
        bne name
        lda args+1,x            ; option
        and #$DF
        cmp #"T"
        bne usage
        lda args+2,x
        beq opt
        cmp #" "
        bne usage
opt     lda #1
        sta text
        bne next
name    lda w1
        cmp #$FF
        bne n2
        stx w1
        jmp next
n2      lda w2
        cmp #$FF
        bne usage
        stx w2
next    jsr skipw
        jmp word
usage   lda #<m_use
        ldy #>m_use
        jmp lputs

parsed  lda w1
        cmp #$FF
        beq usage
        tax                     ; nom sur la clé
        ldy #0
cl      lda args,x
        beq ce
        cmp #" "
        beq ce
        sta uname,y
        inx
        iny
        cpy #100
        bne cl
ce      lda #0
        sta uname,y

        ; nom de CP/A : le 2e mot, sinon le nom de la clé sans son
        ; chemin (sur le lecteur donné si le 2e mot n'est que B:)
        lda #0
        sta drv
        ldx w2
        cpx #$FF
        beq deflt
        lda args+1,x
        cmp #":"
        bne named
        lda args+2,x
        jsr endc
        bne named
        lda args,x
        jsr upc
        sec
        sbc #"A"-1
        sta drv
        beq badn
        cmp #5
        bcc deflt
badn    lda #<m_name
        ldy #>m_name
        jmp lputs
named   txa
        clc
        adc #<args
        sta pp
        lda #>args
        adc #0
        sta pp+1
        jmp parse
deflt   lda #<uname
        sta pp
        lda #>uname
        sta pp+1
        ldy #0
bn      lda uname,y
        beq parse
        iny
        cmp #"/"
        beq slash
        cmp #":"
        bne bn
slash   tya                     ; après le dernier / ou :
        clc
        adc #<uname
        sta pp
        lda #>uname
        adc #0
        sta pp+1
        jmp bn
parse   jsr pname
        bcs badn
        lda drv
        beq pok
        sta fcb

pok     jsr mia_chk
        bcc open
        rts
open    lda #<uname
        ldy #>uname
        ldx #O_RDONLY
        jsr usb_open
        bcc uok
        jmp usb_err
uok     sta fd

        ; fichier de CP/A : effacé puis créé
        lda #<fcb
        ldy #>fcb
        ldx #F_DELETE
        jsr BDOS
        cmp #$FE                ; fichier protégé (R/O) : laissé
        bne del
        lda #<m_ro
        ldy #>m_ro
        jsr lputs
        jmp ucl
del     lda #<fcb
        ldy #>fcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne made
        lda #<m_dir
        ldy #>m_dir
        jsr lputs
        jmp ucl
made    lda #<rec
        ldy #>rec
        ldx #F_SETDMA
        jsr BDOS
        lda #0
        sta rp
        sta last
        sta tot
        sta tot+1
        sta tot+2
        sta tot+3

rd      lda fd                  ; 128 octets de la clé
        jsr usb_read
        bcc rok
        jsr usb_err
        jmp fail
rok     sta n
        beq eof
        ldy #0
byte    cpy n
        beq rd
        sty i
        lda iobuf,y
        ldx text
        beq put
        cmp #10
        bne put
        ldx last                ; LF seul -> CR LF
        cpx #13
        beq put
        lda #13
        jsr putb
        bcs full
        lda #10
put     sta last
        jsr putb
        bcs full
        ldy i
        iny
        bne byte

eof     lda rp                  ; dernier enregistrement, complété de ^Z
        beq done
        ldy rp
        lda #$1A
z       sta rec,y
        iny
        bpl z
        jsr wr_rec
        bcs full
done    lda #<fcb
        ldy #>fcb
        ldx #F_CLOSE
        jsr BDOS
        lda fd
        jsr usb_close
        jsr pfcb                ; « NOM.TXT : 1234 octets »
        lda #<m_sep
        ldy #>m_sep
        jsr lputs
        ldx #3
cn      lda tot,x
        sta num,x
        dex
        bpl cn
        lda #0
        jsr pnum
        lda #<m_ok
        ldy #>m_ok
        jmp lputs

full    lda #<m_full
        ldy #>m_full
        jsr lputs
fail    lda #<fcb               ; fichier commencé : effacé
        ldy #>fcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<fcb
        ldy #>fcb
        ldx #F_DELETE
        jsr BDOS
ucl     lda fd
        jmp usb_close
.)

; putb : ajoute A à rec, écrit l'enregistrement s'il est plein -> C=1 si
;   le disque est plein
putb
.(
        ldx rp
        sta rec,x
        inc tot
        bne t
        inc tot+1
        bne t
        inc tot+2
        bne t
        inc tot+3
t       inx
        stx rp
        bpl ok
        jmp wr_rec
ok      clc
        rts
.)

; wr_rec : écrit rec (enregistrement suivant) -> C=1 si erreur
wr_rec
.(
        lda #0
        sta rp
        lda #<fcb
        ldy #>fcb
        ldx #F_WRITE
        jsr BDOS
        cmp #1                  ; 0 : écrit
        rts
.)

; pname : nom de CP/A en (pp) (fin : 0 ou espace) -> fcb ; lecteur
;   facultatif ; nom et type coupés à 8 et 3 caractères ; C=1 si invalide
pname
.(
        ldx #35
        lda #0
z       sta fcb,x
        dex
        bpl z
        ldx #10
        lda #" "
s       sta fcb+1,x
        dex
        bpl s
        ldy #1
        lda (pp),y
        cmp #":"
        bne nod
        dey
        lda (pp),y
        jsr upc
        sec
        sbc #"A"-1              ; A: = 1 ... D: = 4
        beq bad
        cmp #5
        bcs bad
        sta fcb
        ldy #2
        bne nm
nod     ldy #0
nm      ldx #0
n1      lda (pp),y
        jsr endc
        beq nend
        cmp #"."
        beq dot
        jsr okc
        bcs bad
        cpx #8
        bcs n2                  ; au-delà de 8 : ignoré
        sta fcb+1,x
n2      inx
        iny
        bne n1
dot     cpx #0
        beq bad
        iny
        ldx #0
e1      lda (pp),y
        jsr endc
        beq ok
        jsr okc
        bcs bad
        cpx #3
        bcs e2
        sta fcb+9,x
e2      inx
        iny
        bne e1
nend    cpx #0
        beq bad
ok      clc
        rts
bad     sec
        rts
.)

; endc : Z=1 si A est 0 ou une espace
endc
.(
        cmp #0
        beq r
        cmp #" "
r       rts
.)

; upc : A en majuscule
upc
.(
        cmp #"a"
        bcc r
        cmp #"z"+1
        bcs r
        and #$DF
r       rts
.)

; okc : A (mis en majuscule) admis dans un nom de CP/A ? C=1 sinon
okc
.(
        jsr upc
        stx lt1
        cmp #"!"
        bcc bad
        cmp #$7F
        bcs bad
        ldx #14
l       cmp badc,x
        beq bad
        dex
        bpl l
        ldx lt1
        clc
        rts
bad     sec
        rts
.)

; pfcb : affiche le nom du fcb (B:NOM.TXT)
pfcb
.(
        lda fcb
        beq nm
        clc
        adc #"A"-1
        jsr lputc
        lda #":"
        jsr lputc
nm      ldx #1
l1      lda fcb,x
        cmp #" "
        beq ex
        jsr lputc
        inx
        cpx #9
        bne l1
ex      lda fcb+9
        cmp #" "
        beq r
        lda #"."
        jsr lputc
        ldx #9
l2      lda fcb,x
        cmp #" "
        beq r
        jsr lputc
        inx
        cpx #12
        bne l2
r       rts
.)

badc    .asc "*?.,;:<>=[]|/",$5C,$22

m_use   .asc "IMPORT nom [fic] [/T] : copie un",13,10
        .asc "fichier de la cle USB du LOCI",13,10
        .asc "/T : texte, LF seul -> CR LF",13,10,0
m_name  .asc "Nom CP/A invalide : IMPORT nom fic",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_ro    .asc "Fichier protege (SET fic RW)",13,10,0
m_full  .asc "Disque plein",13,10,0
m_sep   .asc " : ",0
m_ok    .asc " octets",13,10,0

#include "loci_inc.s"

; tampons, après la fin du programme
uname   = lib_free       ; nom sur la clé (101)
fcb     = lib_free+101
rec     = lib_free+137
