; =====================================================================
;  GRAPHER.COM — exécute un fichier de commandes graphiques (.GRX)
;
;  GRAPHER NOM [p1 ... p9]
;    NOM.GRX (lecteur facultatif) : une commande par ligne, en anglais,
;    paramètres en décimal (0 à 255) ; « ; » commence un commentaire ;
;    $1 à $9 sont remplacés par les paramètres (casse d'origine).
;
;  Modes      HIRES          plein écran 240 x 200, image effacée
;             SPLIT          240 x 128, console dessous, image effacée
;             TEXT           retour au mode texte
;  Image      GCLS           efface
;             PEN m          0 efface, 1 trace, 2 inverse
;             PLOT x y
;             LINE x1 y1 x2 y2
;             BOX x1 y1 x2 y2, FBOX x1 y1 x2 y2 (plein)
;             CIRCLE x y r
;             GTEXT col y texte   (col 0-39, y en points)
;             ATTR col y1 y2 v    (encre 0-7, papier 16-23)
;             GLOAD nom      .HIR en HIRES, .IMG en SPLIT ; depuis le mode
;                            texte, le type choisit le mode (HIR par défaut)
;             GSAVE nom      même format que le mode
;  Divers     WAIT           attend une touche (ESC arrête)
;             DELAY n        attend n/50 s (0 à 65535)
;             ECHO texte     affiche le texte (rien en HIRES : pas de
;                            console sous une image plein écran)
;             END            fin du fichier
;  ESC entre deux lignes arrête. En fin de fichier, une image HIRES reste
;  affichée jusqu'à une touche, puis retour au texte ; une image SPLIT
;  reste au-dessus du prompt.
;  Le dessin passe par hires.inc (pas par la fonction 115 du BDOS).
; =====================================================================

#include "cpa.inc"

LMAX    = 126           ; longueur d'une ligne du fichier
CR      = 13
LF      = 10
NPAR    = 9

lp      = $10           ; pointeur de travail
lx      = $12           ; position dans lbuf
lnum    = $13           ; numéro de ligne (2 octets)
ridx    = $15           ; position dans rbuf (128 : à lire)
reof    = $16
gv      = $17           ; nombre lu (2 octets)
gd      = $19           ; chiffres lus
tbl     = $1A           ; table des commandes (2 octets)
sav_sp  = $1C
pkey    = $1D           ; touche lue entre deux lignes (0 : aucune)

        *= $0500

        tsx
        stx sav_sp
        jsr h_init
        lda #G_GETMODE          ; lancé en mode SPLIT : on y reste
        jsr h_gfx
        cmp #1
        bne nosplit
        lda #128
        sta h_lines
nosplit lda FCB1+1
        cmp #" "
        bne named
        ldx #F_PRINT
        lda #<m_use
        ldy #>m_use
        jmp BDOS
named   ldx #11
c1      lda FCB1,x
        sta sfcb,x
        dex
        bpl c1
        lda sfcb+9
        cmp #" "
        bne typed
        ldx #2
c2      lda t_grx,x
        sta sfcb+9,x
        dex
        bpl c2
typed   ldy #12
        lda #0
c3      sta sfcb,y
        iny
        cpy #36
        bne c3
        ldx #F_OPEN
        lda #<sfcb
        ldy #>sfcb
        jsr BDOS
        cmp #$FF
        bne opened
        ldx #F_PRINT
        lda #<m_nogrx
        ldy #>m_nogrx
        jmp BDOS
opened  jsr get_params
        lda #128
        sta ridx
        lda #0
        sta reof
        sta lnum
        sta lnum+1
        sta pkey

; ---------------------------------------------------------------------
; Boucle : une ligne, puis sa commande
; ---------------------------------------------------------------------
next    jsr B_CONST             ; ESC : arrêt ; une autre touche est
        beq rd                  ; gardée pour WAIT ou la fin
        jsr h_key
        sta pkey
        cmp #27
        bne rd
        lda #<m_esc
        ldy #>m_esc
        jmp stop_msg
rd      inc lnum
        bne rd1
        inc lnum+1
rd1     jsr read_line
        bcs finish
        jsr exec
        jmp next

; fin normale : une image plein écran attend une touche
finish  lda h_lines
        cmp #200
        bne bye
        jsr getkey
        jsr h_text
bye     ldx sav_sp
        txs
        rts

; ---------------------------------------------------------------------
; Lecture d'une ligne : rawbuf, puis lbuf avec $1-$9 remplacés
; ---------------------------------------------------------------------
read_line
.(
        lda #0
        sta word
        ldx #0
loop    stx lx
        jsr getc
        ldx lx
        bcs eof
        cmp #LF
        beq loop
        cmp #CR
        beq eol
        cpx #LMAX
        bcs long
        sta rawbuf,x
        inx
        bne loop
eof     cpx #0
        bne eol
        sec
        rts
long    lda #<m_long
        ldy #>m_long
        jmp error
eol     lda #0
        sta rawbuf,x
        ldx #0                  ; remplacement des paramètres
        ldy #0
cp      lda rawbuf,x
        beq done
        cmp #"$"
        bne put
        lda rawbuf+1,x
        sec
        sbc #"1"
        cmp #NPAR
        bcs dollar
        inx
        inx
        stx lx
        tax                     ; paramètre numéro X
        lda par_lo,x
        sta lp
        lda par_hi,x
        sta lp+1
        lda par_len,x
        tax
        beq pend
        sty gd
        ldy #0
pc      lda (lp),y
        sty gv
        ldy gd
        cpy #LMAX
        bcs long
        sta lbuf,y
        inc gd
        ldy gv
        iny
        dex
        bne pc
        ldy gd
pend    ldx lx
        jmp cp
dollar  lda #"$"
put     cpy #LMAX
        bcs long
        sta lbuf,y
        iny
        inx
        bne cp
done    lda #0
        sta lbuf,y
        clc
        rts
.)

; getc : caractère suivant du fichier (C=1 à la fin, ^Z compris)
getc
.(
        lda reof
        bne end
        ldy ridx
        cpy #128
        bcc have
        ldx #F_SETDMA
        lda #<rbuf
        ldy #>rbuf
        jsr BDOS
        ldx #F_READ
        lda #<sfcb
        ldy #>sfcb
        jsr BDOS
        pha
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        pla
        bne eof
        ldy #0
        sty ridx
have    inc ridx
        lda rbuf,y
        cmp #$1A
        beq eof
        clc
        rts
eof     lda #1
        sta reof
end     sec
        rts
.)

; get_params : $1-$9 dans la ligne de commande (casse d'origine) : après
;   le nom du programme et celui du fichier
get_params
.(
        ldx #0
        jsr skipw               ; GRAPHER
        jsr skipw               ; NOM
        ldy #0
loop    jsr sksp
        lda ORIG_LINE,x
        beq done
        txa
        clc
        adc #<ORIG_LINE
        sta par_lo,y
        lda #>ORIG_LINE
        adc #0
        sta par_hi,y
        lda #0
        sta par_len,y
len     lda ORIG_LINE,x
        beq lend
        cmp #" "
        beq lend
        inx
        lda par_len,y
        clc
        adc #1
        sta par_len,y
        jmp len
lend    iny
        cpy #NPAR
        bne loop
done    rts
skipw   jsr sksp
sw      lda ORIG_LINE,x
        beq sr
        cmp #" "
        beq sr
        inx
        bne sw
sr      rts
sksp    lda ORIG_LINE,x
        cmp #" "
        bne ss
        inx
        bne sksp
ss      rts
.)

; ---------------------------------------------------------------------
; Exécution d'une ligne
; ---------------------------------------------------------------------
exec
.(
        ldx #0
        jsr skipsp
        beq r                   ; ligne vide
        cmp #";"
        beq r
        ldy #0                  ; mot de commande, en majuscules
w       lda lbuf,x
        cmp #" "+1
        bcc wend
        cmp #"a"
        bcc up
        cmp #"z"+1
        bcs up
        and #$DF
up      cpy #8
        bcs bad
        sta word,y
        iny
        inx
        bne w
wend    lda #0
        sta word,y
        stx lx
        lda #<cmds              ; recherche dans la table
        sta tbl
        lda #>cmds
        sta tbl+1
look    ldy #0
        lda (tbl),y
        beq bad
cmpc    lda (tbl),y
        and #$7F
        cmp word,y
        bne skip
        lda (tbl),y
        bmi found
        iny
        bne cmpc
found   lda word+1,y            ; le mot doit finir là
        bne skip2
        iny
        lda (tbl),y
        sta lp
        iny
        lda (tbl),y
        sta lp+1
        ldx lx
        jmp (lp)
skip2   ldy #0
skip    lda (tbl),y             ; entrée suivante
        bmi sk1
        iny
        bne skip
sk1     iny
        iny
        iny
        tya
        clc
        adc tbl
        sta tbl
        bcc look
        inc tbl+1
        bne look
bad     lda #<m_unk
        ldy #>m_unk
        jmp error
r       rts
.)

; skipsp : saute les espaces de lbuf (X) ; A = caractère, Z=1 en fin
skipsp
.(
loop    lda lbuf,x
        cmp #" "
        bne r
        inx
        bne loop
r       cmp #0
        rts
.)

; getnum : nombre décimal (lbuf, X) -> gv (16 bits) ; erreur s'il manque
getnum
.(
        jsr skipsp
        lda #0
        sta gv
        sta gv+1
        sta gd
loop    lda lbuf,x
        sec
        sbc #"0"
        cmp #10
        bcs end
        pha
        lda gv+1                ; gv * 10 (débordement : erreur)
        cmp #>6554
        bcs big
        lda gv
        asl
        sta lp
        lda gv+1
        rol
        sta lp+1
        asl gv
        rol gv+1
        asl gv
        rol gv+1
        asl gv
        rol gv+1
        clc
        lda gv
        adc lp
        sta gv
        lda gv+1
        adc lp+1
        sta gv+1
        pla
        clc
        adc gv
        sta gv
        bcc nc
        inc gv+1
        beq bad
nc      inc gd
        inx
        bne loop
big     pla
        jmp bad
end     lda gd
        beq bad
        lda lbuf,x              ; un nombre finit par un espace
        beq ok
        cmp #" "
        beq ok
        cmp #";"
        bne bad
ok      lda gv
        rts
bad     jmp e_param
.)

; getbyte : nombre de 0 à 255 -> A
getbyte
        jsr getnum
        lda gv+1
        bne e_param
        lda gv
        rts

; endline : rien d'autre sur la ligne (un commentaire est permis)
endline
        jsr skipsp
        beq el_ok
        cmp #";"
        bne e_param
el_ok   rts

e_param lda #<m_param
        ldy #>m_param
        jmp error

; needgfx : erreur hors du mode HIRES ou SPLIT
needgfx
        lda h_lines
        bne ng_ok
        lda #<m_nogfx
        ldy #>m_nogfx
        jmp error
ng_ok   rts

; p4 : quatre nombres -> h_x1 h_y1 h_x2 h_y2, fin de ligne
p4      jsr p2
        jsr getbyte
        sta h_x2
        jsr getbyte
        sta h_y2
        jmp endline
; p2 : deux nombres -> h_x1 h_y1
p2      jsr getbyte
        sta h_x1
        jsr getbyte
        sta h_y1
        rts

; ---------------------------------------------------------------------
; Commandes
; ---------------------------------------------------------------------
c_hires jsr endline
        jmp h_full
c_split jsr endline
        jmp h_split
c_text  jsr endline
        jmp h_text
c_gcls  jsr endline
        jsr needgfx
        jmp h_cls
c_pen   jsr getbyte
        cmp #3
        bcs e_param
        pha
        jsr endline
        pla
        jmp h_pen
c_plot  jsr needgfx
        jsr p2
        jsr endline
        jmp h_plot
c_line  jsr needgfx
        jsr p4
        jmp h_line
c_box   jsr needgfx
        jsr p4
        jmp h_box
c_fbox  jsr needgfx
        jsr p4
        jmp h_fbox
c_circle
        jsr needgfx
        jsr p2
        jsr getbyte
        sta h_r
        jsr endline
        jmp h_circle
c_gtext jsr needgfx             ; le reste de la ligne (après un espace)
        jsr p2
        lda lbuf,x
        beq gt
        inx
gt      txa
        clc
        adc #<lbuf
        pha
        lda #>lbuf
        adc #0
        tay
        pla
        jmp h_print
c_attr  jsr needgfx
        jsr p2
        jsr getbyte
        sta h_y2
        jsr getbyte
        pha
        jsr endline
        pla
        jmp h_attr
c_wait  jsr endline
        jsr getkey
        cmp #27
        bne cw_r
        lda #<m_esc
        ldy #>m_esc
        jmp stop_msg
cw_r    rts
c_delay
.(
        jsr getnum
        jsr endline
        clc                     ; fin = ticks + n
        lda SYS_TICKS
        adc gv
        sta gv
        lda SYS_TICKS+1
        adc gv+1
        sta gv+1
w       sec                     ; jusqu'à ce que ticks - fin >= 0
        lda SYS_TICKS
        sbc gv
        lda SYS_TICKS+1
        sbc gv+1
        bmi w
        rts
.)
c_echo
.(
        lda h_lines             ; pas de console en HIRES plein écran
        cmp #200
        beq r
        jsr skipsp
loop    lda lbuf,x
        beq end
        stx lx
        ldx #F_CONOUT
        jsr BDOS
        ldx lx
        inx
        bne loop
end     jsr crlf
r       rts
.)
c_end   jsr endline
        ldx sav_sp              ; comme en fin de fichier
        txs
        jmp finish

; GLOAD / GSAVE nom
c_gload
.(
        jsr getname
        lda h_lines
        bne mode                ; déjà en HIRES ou en SPLIT
        jsr is_img              ; mode texte : le type choisit le mode
        beq spl
        jsr h_full
        jmp ld
spl     lda #128                ; GLOAD du système : il passe en SPLIT
        sta h_lines
        jmp ld
mode    jsr deftype
ld      lda #<ifcb
        ldy #>ifcb
        jsr h_load
        cmp #0
        beq r
        lda h_lines             ; image absente : en SPLIT sans image, on
        cmp #128                ; reste en texte pour le message
        bne nf
        lda #G_GETMODE
        jsr h_gfx
        cmp #0
        bne nf
        sta h_lines
nf      lda #<m_noimg
        ldy #>m_noimg
        jmp error
r       rts
.)

c_gsave
.(
        jsr needgfx
        jsr getname
        jsr deftype
        lda #<ifcb
        ldy #>ifcb
        jsr h_save
        cmp #0
        beq r
        lda #<m_full
        ldy #>m_full
        jmp error
r       rts
.)

; getname : [d:]nom[.ext] de lbuf (X) -> ifcb ; erreur s'il manque
getname
.(
        jsr skipsp
        beq bad
        ldy #11
        lda #" "
cl      sta ifcb,y
        dey
        bne cl
        sty ifcb
        lda lbuf+1,x
        cmp #":"
        bne nm
        lda lbuf,x
        jsr upc
        sec
        sbc #"@"
        sta ifcb
        inx
        inx
nm      ldy #1
        lda #9
        sta gd
n1      lda lbuf,x
        cmp #" "+1
        bcc end
        inx
        cmp #"."
        bne n2
        ldy #9
        lda #12
        sta gd
        bne n1
n2      cpy gd
        bcs n1
        jsr upc
        sta ifcb,y
        iny
        bne n1
end     lda ifcb+1
        cmp #" "
        beq bad
        jmp endline
bad     jmp e_param
.)

; deftype : type par défaut selon le mode (HIR en plein écran, IMG en SPLIT)
deftype
.(
        lda ifcb+9
        cmp #" "
        bne r
        ldx #2
        ldy #2
        lda h_lines
        cmp #200
        bne l
        ldy #5
l       lda t_img,y
        sta ifcb+9,x
        dey
        dex
        bpl l
r       rts
.)

; is_img : Z=1 si le type de ifcb est IMG (type vide : HIR, mis ici)
is_img
.(
        lda ifcb+9
        cmp #" "
        bne t
        ldx #2
d       lda t_hir,x
        sta ifcb+9,x
        dex
        bpl d
t       ldx #2
l       lda ifcb+9,x
        cmp t_img,x
        bne r
        dex
        bpl l
        lda #0
r       rts
.)

upc     cmp #"a"
        bcc upr
        cmp #"z"+1
        bcs upr
        and #$DF
upr     rts

; ---------------------------------------------------------------------
; Erreurs et arrêt
; ---------------------------------------------------------------------
; error : « L n COMMANDE : message » puis fin
error
        pha
        tya
        pha
        jsr to_text
        lda #"L"
        jsr putc
        lda #" "
        jsr putc
        jsr put_lnum
        lda word                ; la commande en cause
        beq e_msg
        lda #" "
        jsr putc
        lda #<word
        ldy #>word
        jsr puts
e_msg   lda #" "
        jsr putc
        lda #":"
        jsr putc
        lda #" "
        jsr putc
        pla
        tay
        pla
        jsr puts
        jsr crlf
        jmp quit

; stop_msg : message A/Y puis fin (ESC)
stop_msg
        pha
        tya
        pha
        jsr to_text
        pla
        tay
        pla
        jsr puts
        jsr crlf
quit    ldx sav_sp
        txs
        rts

; to_text : quitte le HIRES plein écran avant d'écrire sur la console
to_text lda h_lines
        cmp #200
        bne tt_r
        jmp h_text
tt_r    rts

; getkey : touche gardée par le test d'ESC, sinon attend une touche
getkey  lda pkey
        beq gk
        ldx #0
        stx pkey
        rts
gk      jmp h_key

putc    ldx #F_CONOUT
        jmp BDOS
crlf    lda #13
        jsr putc
        lda #10
        jmp putc

; puts : chaîne A/Y terminée par 0
puts
.(
        sta lp
        sty lp+1
        ldy #0
loop    lda (lp),y
        beq r
        sty gd
        jsr putc
        ldy gd
        iny
        bne loop
r       rts
.)

; put_lnum : numéro de ligne en décimal
put_lnum
.(
        lda lnum
        sta gv
        lda lnum+1
        sta gv+1
        lda #0
        sta gd                  ; chiffres écrits
        ldx #0
dig     ldy #0
sub     sec
        lda gv
        sbc d_lo,x
        pha
        lda gv+1
        sbc d_hi,x
        bcc dn
        sta gv+1
        pla
        sta gv
        iny
        bne sub
dn      pla
        tya
        bne show
        lda gd
        beq nx
        tya
show    ora #"0"
        stx lx
        jsr putc
        ldx lx
        sta gd
nx      inx
        cpx #4
        bne dig
        lda gv
        ora #"0"
        jmp putc
d_lo    .byt <10000,<1000,<100,<10
d_hi    .byt >10000,>1000,>100,>10
.)

; ---------------------------------------------------------------------
; Table des commandes : nom (dernière lettre avec le bit 7), adresse
; ---------------------------------------------------------------------
cmds
        .asc "HIRE"
        .byt "S"|$80
        .word c_hires
        .asc "SPLI"
        .byt "T"|$80
        .word c_split
        .asc "TEX"
        .byt "T"|$80
        .word c_text
        .asc "GCL"
        .byt "S"|$80
        .word c_gcls
        .asc "PE"
        .byt "N"|$80
        .word c_pen
        .asc "PLO"
        .byt "T"|$80
        .word c_plot
        .asc "LIN"
        .byt "E"|$80
        .word c_line
        .asc "BO"
        .byt "X"|$80
        .word c_box
        .asc "FBO"
        .byt "X"|$80
        .word c_fbox
        .asc "CIRCL"
        .byt "E"|$80
        .word c_circle
        .asc "GTEX"
        .byt "T"|$80
        .word c_gtext
        .asc "ATT"
        .byt "R"|$80
        .word c_attr
        .asc "GLOA"
        .byt "D"|$80
        .word c_gload
        .asc "GSAV"
        .byt "E"|$80
        .word c_gsave
        .asc "WAI"
        .byt "T"|$80
        .word c_wait
        .asc "DELA"
        .byt "Y"|$80
        .word c_delay
        .asc "ECH"
        .byt "O"|$80
        .word c_echo
        .asc "EN"
        .byt "D"|$80
        .word c_end
        .byt 0

t_grx   .asc "GRX"
t_img   .asc "IMG"
t_hir   .asc "HIR"
m_use   .asc "GRAPHER NOM [p1..p9] : execute",13,10
        .asc "NOM.GRX (commandes graphiques).",13,10,"$"
m_nogrx .asc "Fichier introuvable",13,10,"$"
m_unk   .asc "commande inconnue",0
m_param .asc "parametres ?",0
m_long  .asc "ligne de plus de 126 car.",0
m_nogfx .asc "HIRES ou SPLIT d'abord",0
m_noimg .asc "image introuvable",0
m_full  .asc "disque plein",0
m_esc   .asc "Interrompu",0

sfcb    .dsb 36,0
ifcb    .dsb 36,0
par_lo  .dsb NPAR,0
par_hi  .dsb NPAR,0
par_len .dsb NPAR,0
word    .dsb 9,0

#include "hires.inc"

rbuf    = h_free
rawbuf  = rbuf+128
lbuf    = rawbuf+LMAX+1
