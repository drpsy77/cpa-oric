; =====================================================================
;  EXPORT.COM — copie un fichier de CP/A sur la clé USB du LOCI
;
;  EXPORT fic [nom]
;    fic  fichier de CP/A (lecteur facultatif : B:LETTRE.TXT)
;    nom  nom sur la clé, avec un chemin si l'on veut (1:/DOCS/X.TXT,
;         0:X.TXT pour la mémoire interne du LOCI) ; par défaut, le nom
;         de fic tel qu'il a été tapé (minuscules gardées), à la racine
;         de la clé
;  Un fichier du même nom sur la clé est remplacé. Les ^Z ($1A) qui
;  complètent le dernier enregistrement sont retirés (même règle que
;  STAT) : un texte arrive à sa vraie taille. Les fins de ligne restent
;  CR LF. Refuse d'écrire un .DSK (image de disquette, peut-être celle
;  qui est en service).
; =====================================================================

#include "cpa.inc"

w1      = $10           ; position des mots dans args
w2      = $11
fd      = $12
cnt     = $13
tot     = $14           ; 4 octets : octets écrits

        *= $0500
start
.(
        jsr get_args
        ldx #0
        jsr skipsp
        lda args,x
        bne a1
usage   lda #<m_use
        ldy #>m_use
        jmp lputs
a1      stx w1
        jsr skipw
        jsr skipsp
        stx w2
        lda FCB1+1
        cmp #" "
        beq usage
        ldy #11
q       lda FCB1,y
        cmp #"?"
        beq usage               ; pas de jokers
        dey
        bne q

        ; nom sur la clé : le 2e mot, sinon le 1er sans son lecteur
        ldx w2
        lda args,x
        bne cpn
        ldx w1
        lda args+1,x
        cmp #":"
        bne cpn
        inx
        inx
cpn     ldy #0
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

        ; jamais d'image de disquette
        cpy #4
        bcc okn
        lda uname-4,y
        cmp #"."
        bne okn
        lda uname-3,y
        and #$DF
        cmp #"D"
        bne okn
        lda uname-2,y
        and #$DF
        cmp #"S"
        bne okn
        lda uname-1,y
        and #$DF
        cmp #"K"
        bne okn
        lda #<m_dsk
        ldy #>m_dsk
        jmp lputs

okn     jsr mia_chk
        bcc open
        rts

        ; fichier de CP/A
open    ldx #35
        lda #0
z       sta fcb,x
        dex
        bpl z
        ldx #15
c       lda FCB1,x
        sta fcb,x
        dex
        bpl c
        lda #<fcb
        ldy #>fcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne opened
        lda #<m_nf
        ldy #>m_nf
        jmp lputs
opened  lda #0
        sta tot
        sta tot+1
        sta tot+2
        sta tot+3

        ; fichier de la clé, créé ou vidé
        lda #<uname
        ldy #>uname
        ldx #O_WRONLY+O_CREAT+O_TRUNC
        jsr usb_open
        bcc uok
        jmp usb_err
uok     sta fd

        ; lecture avec un enregistrement d'avance : on sait ainsi lequel
        ; est le dernier (ses ^Z sont retirés)
        jsr rd_rec
        bne last0               ; fichier vide
loop    jsr cp_next             ; iobuf <- enregistrement lu
        jsr rd_rec
        bne last
        ldx #128
        jsr wr_buf
        bcc loop
        rts
last    ldx #128                ; dernier : sans ses ^Z
t       lda iobuf-1,x
        cmp #$1A
        bne tl
        dex
        bne t
tl      txa
        beq last0
        jsr wr_buf
        bcc last0
        rts
last0   lda fd
        jsr usb_close
        bcc closed
        jmp usb_err
closed  ldx #3                  ; « 1234 octets copies »
cn      lda tot,x
        sta num,x
        dex
        bpl cn
        lda #0
        jsr pnum
        lda #<m_ok
        ldy #>m_ok
        jmp lputs
.)

; rd_rec : enregistrement suivant de fcb dans rec -> Z=1 si lu
rd_rec
.(
        lda #<rec
        ldy #>rec
        ldx #F_SETDMA
        jsr BDOS
        lda #<fcb
        ldy #>fcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        rts
.)

; cp_next : rec -> iobuf
cp_next
.(
        ldy #127
l       lda rec,y
        sta iobuf,y
        dey
        bpl l
        rts
.)

; wr_buf : écrit X octets de iobuf sur la clé, les ajoute au total
;   -> C=1 si erreur (message affiché, fichier de la clé fermé)
wr_buf
.(
        stx cnt
        lda fd
        jsr usb_write
        bcs err
        cmp cnt
        bne full
        clc
        adc tot
        sta tot
        bcc r
        inc tot+1
        bne r
        inc tot+2
        bne r
        inc tot+3
r       clc
        rts
full    lda #<m_full
        ldy #>m_full
        jsr lputs
        jmp cl
err     jsr usb_err
cl      lda fd
        jsr usb_close
        sec
        rts
.)

m_use   .asc "EXPORT fic [nom] : copie un fichier",13,10
        .asc "sur la cle USB du LOCI",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_dsk   .asc "Refuse : image de disquette (.DSK)",13,10,0
m_full  .asc "Cle USB pleine",13,10,0
m_ok    .asc " octets copies",13,10,0

#include "loci_inc.s"

; tampons, après la fin du programme
uname   = lib_free       ; nom sur la clé (101)
fcb     = lib_free+101
rec     = lib_free+137
