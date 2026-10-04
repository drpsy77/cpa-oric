; =====================================================================
;  ASM.COM — assembleur 6502 résident pour CP/A
;
;  ASM NOM            assemble NOM.ASM (ou NOM.ext) et écrit NOM.COM
;
;  Syntaxe compatible avec l'assembleur xa de l'OSDK (sous-ensemble) :
;    étiquette   en colonne 1 (« : » facultatif), sensible à la casse
;    NOM = expr  constante
;    *= expr     adresse d'assemblage ($0500 par défaut)
;    .byt / .byte / .asc  octets et chaînes "..."
;    .word       mots de 16 bits
;    .dsb n[,v]  n octets valant v (0 par défaut)
;    .( et .)    bloc : les étiquettes définies dedans y sont locales
;    #include "FICHIER"   (un niveau)
;    ; commentaire
;  Expressions : nombres décimaux, $hexa, %binaire, "c" ou 'c',
;    * (adresse courante), symboles, ( ), + - * / & | ^ << >>,
;    - unaire, < (octet bas) et > (octet haut) devant l'expression.
;  Les modes page zéro sont choisis quand la valeur est connue avant
;  la ligne et tient sur un octet.
;
;  Deux passes sur le texte source, lu ligne à ligne sur le disque.
;  Table des symboles hachée (128 listes). Le code est produit en
;  mémoire puis écrit d'un bloc si aucune erreur n'a été trouvée.
;  ESC interrompt.
; =====================================================================

#include "cpa.inc"

NBUCK   = 128
MAXSCOPE = 16

; symbole : +0 suivant, +2 bloc, +4 valeur, +6 drapeaux, +7 longueur, +8 nom
S_NEXT  = 0
S_SCOPE = 2
S_VAL   = 4
S_FLAGS = 6
S_LEN   = 7
S_NAME  = 8
F_DEF   = 1             ; défini en passe 1
F_KNOWN = 2             ; valeur connue en passe 1
F_PASS2 = 4             ; déjà passé en passe 2
F_DUP   = 8             ; défini deux fois
F_LABEL = 16            ; étiquette (adresse), pas constante
F_INC   = 32            ; défini dans un fichier inclus

; modes d'adressage (colonnes de mn_ops)
M_IMP   = 0
M_IMM   = 1
M_ZP    = 2
M_ZPX   = 3
M_ZPY   = 4
M_ABS   = 5
M_ABX   = 6
M_ABY   = 7
M_IND   = 8
M_INX   = 9
M_INY   = 10
M_REL   = 11

; erreurs
E_SYN   = 0
E_UNDEF = 1
E_DUP   = 2
E_MODE  = 3
E_RANGE = 4
E_BRANCH = 5
E_MNEM  = 6
E_DIR   = 7
E_P1    = 8
E_INCNF = 9
E_INCNEST = 10
E_BLOCK = 11
E_DIV   = 12
E_PHASE = 13
E_ORG   = 14
E_FWD   = 15
E_BIG   = 16

; --- page zéro ---
lp      = $10           ; position dans la ligne
val     = $12           ; valeur de l'expression
t0      = $14
t1      = $16
t2      = $18
ptr     = $1A
sym     = $1C
pc      = $1E
org     = $20
ocnt   = $22
symtop  = $24
objbase = $26
errs    = $28
scope   = $2A
scnt    = $2C
nmptr   = $2E
lnum    = $30
lbl     = $32
outlim  = $34
cnt     = $36
nsyms   = $38
fillv   = $3A
eknown  = $3C
pass    = $3D
orgset  = $3E
ssp     = $3F
cur     = $40
nmlen   = $41
mnidx   = $42
mode    = $43
linesp  = $44
hash    = $45
lbllen  = $46
tmpb    = $47
nflags  = $48
isequ   = $49
lkx     = $4A
gotc    = $4B
opc     = $4C
errno   = $4D
quote   = $4E
m0      = $4F
m1      = $50
m2      = $51
opc_p   = $52           ; ligne de la table des opcodes
sptr    = $54
opy     = $56
undefl  = $57
lpc     = $58
gop_lp  = $5A
gop_y   = $5C
gop_x   = $5D
gop_c   = $5E
rp      = $61
wy      = $62
inq     = $5F

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
.(
        cld
        lda FCB1+1
        cmp #" "
        bne arg
        lda #<m_usage
        ldy #>m_usage
        jsr puts
        jmp WBOOT
arg     ldx #11                 ; source : FCB1, type ASM par défaut
cp      lda FCB1,x
        sta fcb_src,x
        sta fcb_out,x
        dex
        bpl cp
        lda fcb_src+9
        cmp #" "
        bne hasext
        lda #"A"
        sta fcb_src+9
        lda #"S"
        sta fcb_src+10
        lda #"M"
        sta fcb_src+11
hasext  lda #"C"                ; sortie : NOM.COM
        sta fcb_out+9
        lda #"O"
        sta fcb_out+10
        lda #"M"
        sta fcb_out+11
        lda fcb_src+9           ; NOM.COM ne peut pas être la source
        cmp #"C"
        bne okn
        lda fcb_src+10
        cmp #"O"
        bne okn
        lda fcb_src+11
        cmp #"M"
        bne okn
        lda #<m_usage
        ldy #>m_usage
        jsr puts
        jmp WBOOT
okn     lda #<m_banner
        ldy #>m_banner
        jsr puts
        lda #0
        sta outlim
        lda TPA_TOP+1
        sta outlim+1
        ldx #0                  ; listes de symboles vides
        txa
clb     sta bk_lo,x
        sta bk_hi,x
        inx
        cpx #NBUCK
        bne clb
        lda #<SYMBASE
        sta symtop
        lda #>SYMBASE
        sta symtop+1
        lda #0
        sta errs
        sta errs+1
        sta nsyms
        sta nsyms+1
        lda #<fcb_src           ; le fichier source existe-t-il ?
        ldy #>fcb_src
        jsr open_fcb
        cmp #$FF
        bne found
        lda #<m_nosrc
        ldy #>m_nosrc
        jsr puts
        jmp WBOOT
found   lda #1
        sta pass
        jsr do_pass
        ; objet : au-dessus des symboles, aligné sur une page
        lda #0
        sta objbase
        lda symtop+1
        sta objbase+1
        lda symtop
        beq al
        inc objbase+1
al
        jsr obj_size            ; cnt = taille arrondie à 128
        clc
        lda objbase
        adc cnt
        sta t0
        lda objbase+1
        adc cnt+1
        sta t0+1
        bcs big
        lda outlim
        cmp t0
        lda outlim+1
        sbc t0+1
        bcs fits
big     lda #<m_big
        ldy #>m_big
        jsr puts
        jmp WBOOT
fits    lda objbase             ; efface la zone du code
        sta ptr
        lda objbase+1
        sta ptr+1
        lda cnt
        sta t0
        lda cnt+1
        sta t0+1
clo     lda t0
        ora t0+1
        beq p2
        ldy #0
        tya
        sta (ptr),y
        inc ptr
        bne cl1
        inc ptr+1
cl1     lda t0
        bne cl2
        dec t0+1
cl2     dec t0
        jmp clo
p2      lda #2
        sta pass
        jsr do_pass
        lda errs
        ora errs+1
        beq write
        lda errs
        sta val
        lda errs+1
        sta val+1
        jsr putdec
        lda #<m_errs
        ldy #>m_errs
        jsr puts
        jmp WBOOT
write   jmp write_out
.)

; obj_size : cnt = octets produits, arrondi au multiple de 128 supérieur
obj_size
        lda ocnt
        sta cnt
        lda ocnt+1
        sta cnt+1
        clc
        lda cnt
        adc #127
        and #$80
        sta t1
        lda cnt+1
        adc #0
        sta t1+1
        lda t1
        sta cnt
        lda t1+1
        sta cnt+1
        rts

; open_fcb : A/Y = FCB, octets 12-35 à zéro, F_OPEN -> A
open_fcb
.(
        sta ptr
        sty ptr+1
        ldy #12
        lda #0
z       sta (ptr),y
        iny
        cpy #36
        bne z
        lda ptr
        ldy ptr+1
        ldx #F_OPEN
        jmp BDOS
.)

; ---------------------------------------------------------------------
; Écriture de NOM.COM
; ---------------------------------------------------------------------
write_out
.(
        jsr obj_size
        lda cnt
        ora cnt+1
        bne some
        lda #<m_empty
        ldy #>m_empty
        jsr puts
        jmp WBOOT
some    ldx #12
        lda #0
z       sta fcb_out,x
        inx
        cpx #36
        bne z
        ldx #F_DELETE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        ldx #12
        lda #0
z2      sta fcb_out,x
        inx
        cpx #36
        bne z2
        ldx #F_MAKE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        cmp #$FF
        bne mk_ok
        jmp full
mk_ok
        lda objbase
        sta ptr
        lda objbase+1
        sta ptr+1
wl      lda cnt
        ora cnt+1
        beq done
        ldx #F_SETDMA
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #F_WRITE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        cmp #0
        beq wr_ok
        jmp full
wr_ok
        clc
        lda ptr
        adc #128
        sta ptr
        bcc w1
        inc ptr+1
w1      sec
        lda cnt
        sbc #128
        sta cnt
        bcs wl
        dec cnt+1
        jmp wl
done    ldx #F_CLOSE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        jsr write_sym
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        ; « NOM.COM $0500-$0A3F, 1344 octets, 87 symboles »
        ldx #1
nm      lda fcb_out,x
        cmp #" "
        beq dot
        jsr putc
        inx
        cpx #9
        bne nm
dot     lda #<m_com
        ldy #>m_com
        jsr puts
        lda org
        sta val
        lda org+1
        sta val+1
        jsr puthex4
        lda #"-"
        jsr putc
        clc                     ; dernière adresse : org + taille - 1
        lda org
        adc ocnt
        sta val
        lda org+1
        adc ocnt+1
        sta val+1
        lda val
        bne la1
        dec val+1
la1     dec val
        jsr puthex4
        lda #<m_comma
        ldy #>m_comma
        jsr puts
        lda ocnt
        sta val
        lda ocnt+1
        sta val+1
        jsr putdec
        lda #<m_bytes
        ldy #>m_bytes
        jsr puts
        lda nsyms
        sta val
        lda nsyms+1
        sta val+1
        jsr putdec
        lda #<m_syms
        ldy #>m_syms
        jsr puts
        jmp WBOOT
full    ldx #F_CLOSE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        lda #<m_dfull
        ldy #>m_dfull
        jsr puts
        jmp WBOOT
.)

; write_sym : NOM.SYM pour DEBUG. Une entrée par symbole :
;   longueur, valeur (2 octets), genre (bit 0 étiquette, bit 1 local,
;   bit 2 fichier inclus), nom
; puis une longueur nulle.
write_sym
.(
        lda #"S"
        sta fcb_out+9
        lda #"Y"
        sta fcb_out+10
        lda #"M"
        sta fcb_out+11
        jsr clr_out
        ldx #F_DELETE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        jsr clr_out
        ldx #F_MAKE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        cmp #$FF
        bne ok
        rts
ok      lda #0
        sta rp
        lda #<SYMBASE
        sta sym
        lda #>SYMBASE
        sta sym+1
loop    lda sym                 ; fin de la table ?
        cmp symtop
        lda sym+1
        sbc symtop+1
        bcs end
        ldy #S_LEN
        lda (sym),y
        sta tmpb
        jsr wput
        ldy #S_VAL
        lda (sym),y
        jsr wput
        iny
        lda (sym),y
        jsr wput
        ldx #0                  ; genre
        ldy #S_FLAGS
        lda (sym),y
        and #F_LABEL
        beq g1
        inx
g1      ldy #S_SCOPE
        lda (sym),y
        iny
        ora (sym),y
        beq g2
        inx
        inx
g2      ldy #S_FLAGS
        lda (sym),y
        and #F_INC
        beq g3
        inx
        inx
        inx
        inx
g3      txa
        jsr wput
        ldy #S_NAME
nm      lda (sym),y
        jsr wput
        iny
        dec tmpb
        bne nm
        tya                     ; entrée suivante
        clc
        adc sym
        sta sym
        bcc loop
        inc sym+1
        bne loop
end     lda #0
        jsr wput
pad     lda rp
        beq close
        lda #0
        jsr wput
        jmp pad
close   ldx #F_CLOSE
        lda #<fcb_out
        ldy #>fcb_out
        jmp BDOS

; wput : octet A dans l'enregistrement, écrit tous les 128 octets
wput    ldx rp
        sta recb0,x
        inx
        stx rp
        cpx #128
        bne wr
        sty wy
        ldx #F_SETDMA
        lda #<recb0
        ldy #>recb0
        jsr BDOS
        ldx #F_WRITE
        lda #<fcb_out
        ldy #>fcb_out
        jsr BDOS
        lda #0
        sta rp
        ldy wy
wr      rts
.)

clr_out
        ldx #12
        lda #0
co1     sta fcb_out,x
        inx
        cpx #36
        bne co1
        rts

; ---------------------------------------------------------------------
; Une passe
; ---------------------------------------------------------------------
do_pass
.(
        lda #<m_pass
        ldy #>m_pass
        jsr puts
        lda pass
        ora #"0"
        jsr putc
        jsr crlf
        lda #$00                ; adresse par défaut $0500
        sta pc
        lda #$05
        sta pc+1
        lda #0
        sta orgset
        sta scnt
        sta scnt+1
        sta scope
        sta scope+1
        sta ssp
        sta sstk_lo
        sta sstk_hi
        sta cur
        sta feof
        sta lnlo
        sta lnhi
        lda #$80
        sta ridx
        lda #0                  ; octets produits
        sta ocnt
        sta ocnt+1
        lda #<fcb_src
        ldy #>fcb_src
        jsr open_fcb
.)
pass_loop
        jsr chk_esc
        jsr getline
        bcs pass_end
        tsx                     ; point de reprise après une erreur
        stx linesp
        jsr do_line
        jmp pass_loop
pass_end
        lda ssp                 ; blocs non refermés
        beq pe_r
        lda #E_BLOCK
        jsr report
pe_r    rts

chk_esc
.(
        jsr B_CONST
        beq r
        jsr B_CONIN
        cmp #$1B
        bne r
        lda #<m_esc
        ldy #>m_esc
        jsr puts
        jmp WBOOT
r       rts
.)

; ---------------------------------------------------------------------
; Erreurs
; ---------------------------------------------------------------------
; error : erreur A sur la ligne courante (affichée en passe 2), puis
; abandon de la ligne
error
        jsr report
        ldx linesp
        txs
        jmp pass_loop

; report : affiche l'erreur A en passe 2
report
.(
        sta errno
        lda pass
        cmp #2
        bne r
        inc errs
        bne e1
        inc errs+1
e1      lda cur                 ; dans un fichier inclus : son nom
        beq main
        lda #"["
        jsr putc
        ldx #1
fn      lda fcb_inc,x
        cmp #" "
        beq fe
        jsr putc
        inx
        cpx #9
        bne fn
fe      lda #"]"
        jsr putc
        lda #" "
        jsr putc
main    lda lnum
        sta val
        lda lnum+1
        sta val+1
        jsr putdec
        lda #<m_colon
        ldy #>m_colon
        jsr puts
        lda errno
        asl
        tax
        lda err_tab,x
        ldy err_tab+1,x
        jsr puts
        jsr crlf
        lda #" "                ; la ligne fautive (début)
        jsr putc
        jsr putc
        ldy #0
ln      lda lbuf,y
        beq le
        cmp #$20
        bcc le
        cmp #$7F
        bcs le
        jsr putc
        iny
        cpy #36
        bne ln
le      jsr crlf
r       rts
.)

; ---------------------------------------------------------------------
; Lecture des fichiers
; ---------------------------------------------------------------------
; getc : caractère suivant du fichier courant. C=1 en fin de fichier
getc
.(
        ldx cur
        lda feof,x
        bne eof
        lda ridx,x
        bpl have
        lda rb_lo,x             ; lit l'enregistrement suivant
        ldy rb_hi,x
        ldx #F_SETDMA
        jsr BDOS
        ldx cur
        lda fcb_lo,x
        ldy fcb_hi,x
        ldx #F_READ
        jsr BDOS
        ldx cur
        cmp #0
        bne seteof
        lda #0
        sta ridx,x
have    lda rb_lo,x
        sta ptr
        lda rb_hi,x
        sta ptr+1
        ldy ridx,x
        lda (ptr),y
        inc ridx,x
        cmp #$1A                ; ^Z ou NUL : fin du texte
        beq seteof
        cmp #0
        beq seteof
        clc
        rts
seteof  lda #1
        sta feof,x
eof     sec
        rts
.)

; getline : ligne suivante dans lbuf (terminée par 0). C=1 : fin du source
; Les caractères d'un même enregistrement sont lus directement (ptr reste
; positionné par getc), getc ne sert qu'à changer d'enregistrement.
getline
.(
gl0     lda #<lbuf
        sta t0
        lda #>lbuf
        sta t0+1
        lda #0
        sta gotc
        sta inq
rd      jsr getc
        bcc proc
        jmp eof
proc    cmp #$3C                ; lettres, chiffres... : rien à vérifier
        bcs nt
        cmp #$0A
        bne nlf
        jmp eol
nlf     cmp #$0D
        beq next
        cmp #9
        bne nq
        lda #" "
nq      cmp #$22                ; guillemets : pas de commentaire dedans
        beq q
        cmp #"'"
        bne nsc
q       ldy inq
        beq qon
        cmp inq
        bne nt
        ldy #0
        sty inq
        beq nt
qon     sta inq
        bne nt
nsc     cmp #";"                ; commentaire : la suite n'est pas gardée
        bne nt
        ldy inq
        bne nt
        jmp skipc
nt      ldy #1
        sty gotc
        ldy t0+1                ; ligne trop longue : la fin est ignorée
        cpy #>(lbuf+1020)
        bcs next
        ldy #0
        sta (t0),y
        inc t0
        bne next
        inc t0+1
next    ldx cur                 ; caractère suivant du même enregistrement
        ldy ridx,x
        bmi rd
        lda (ptr),y
        inc ridx,x
        cmp #$1A
        beq fe
        cmp #0
        bne proc
fe      lda #1
        sta feof,x
        jmp eof
skipc   ldx cur                 ; saute le commentaire jusqu'à LF
        ldy ridx,x
        bmi skr
        lda (ptr),y
        inc ridx,x
        cmp #$0A
        beq eol
        cmp #$1A
        beq fe
        cmp #0
        beq fe
        bne skipc
skr     jsr getc
        bcs eof
        cmp #$0A
        bne skipc
        beq eol
eof     lda gotc
        bne eol
        lda cur                 ; fin du fichier inclus : retour au source
        beq done
        lda #0
        sta cur
        jmp gl0
done    sec
        rts
eol     lda #0
        ldy #0
        sta (t0),y
        ldx cur
        inc lnlo,x
        bne e1
        inc lnhi,x
e1      lda lnlo,x
        sta lnum
        lda lnhi,x
        sta lnum+1
        clc
        rts
.)

; ---------------------------------------------------------------------
; Analyse d'une ligne
; ---------------------------------------------------------------------
nextc
        inc lp
        bne nc1
        inc lp+1
nc1     rts

; skipsp : saute les espaces, A = caractère courant
skipsp
        ldy #0
        lda (lp),y
        cmp #" "
        bne ss1
        jsr nextc
        jmp skipsp
ss1     ora #0                  ; Z=1 en fin de ligne
        rts

peek
        ldy #0
        lda (lp),y
        rts

; endline : rien d'autre qu'un commentaire jusqu'à la fin
endline
        jsr skipsp
        beq el1
        cmp #";"
        beq el1
        lda #E_SYN
        jmp error
el1     rts

; expect : le caractère A doit suivre (après des espaces)
expect
        sta tmpb
        jsr skipsp
        cmp tmpb
        bne ex_e
        jmp nextc
ex_e    lda #E_SYN
        jmp error

; is_end : Z=1 si A est 0 ou « ; »
is_end
        cmp #0
        beq ie1
        cmp #";"
ie1     rts

; idstart : C=0 si A peut commencer un identificateur
idstart
        cmp #"_"
        beq ids_y
        and #$DF
        cmp #"A"
        bcc ids_n
        cmp #"Z"+1
        bcs ids_n
ids_y   clc
        rts
ids_n   sec
        rts

; idchar : C=0 si A peut continuer un identificateur
idchar
        cmp #"0"
        bcc ids_n
        cmp #"9"+1
        bcc ids_y
        jmp idstart

; get_ident : identificateur en lp -> nmptr, nmlen ; lp après
get_ident
.(
        lda lp
        sta nmptr
        lda lp+1
        sta nmptr+1
        lda #0
        sta nmlen
loop    jsr peek
        jsr idchar
        bcs done
        jsr nextc
        inc nmlen
        bne loop
done    rts
.)

do_line
.(
        lda #0
        sta undefl
        sta gop_lp+1            ; plus d'opérateur en cache
        lda pc                  ; * = adresse du début de l'instruction
        sta lpc
        lda pc+1
        sta lpc+1
        lda #<lbuf
        sta lp
        lda #>lbuf
        sta lp+1
        jsr peek
        jsr is_end
        bne rep_go
        jmp r
rep_go
        cmp #"#"
        bne np
        jmp preproc
np      cmp #" "
        beq body
        cmp #"."
        beq body
        cmp #"*"
        beq body
        jsr idstart             ; étiquette en colonne 1
        bcc lab
        lda #E_SYN
        jmp error
lab     jsr get_ident
        lda nmptr
        sta lbl
        lda nmptr+1
        sta lbl+1
        lda nmlen
        sta lbllen
        jsr skipsp
        cmp #":"
        bne nocol
        jsr nextc
        jsr skipsp
nocol   cmp #"="
        bne deflab
        jsr nextc               ; NOM = expression
        jsr expr
        jsr endline
        lda #1
        sta isequ
        jmp define
deflab  lda pc
        sta val
        lda pc+1
        sta val+1
        lda #1
        sta eknown
        lda #0
        sta isequ
        jsr define
body    jsr skipsp
        jsr is_end
        beq r
        cmp #"#"
        bne nopp
        jmp preproc
nopp
        cmp #"."
        bne nd
        jmp directive
nd      cmp #"*"
        bne mn
        jsr nextc               ; *= expression
        lda #"="
        jsr expect
        jsr expr
        jsr need_known
        jsr endline
        jmp set_org
mn      jmp instruction
r       rts
.)

; need_known : la valeur doit être connue dès la passe 1
need_known
        lda eknown
        bne nk1
        lda #E_P1
        jmp error
nk1     rts

set_org
.(
        lda orgset
        bne set
        lda val
        sta org
        lda val+1
        sta org+1
        lda #1
        sta orgset
set
go      lda val                 ; comme xa : le code suivant est mis à la
        sta pc                  ; suite dans le fichier, assemblé pour la
        lda val+1               ; nouvelle adresse
        sta pc+1
        rts
.)

; ---------------------------------------------------------------------
; Directives
; ---------------------------------------------------------------------
preproc
.(
        jsr nextc
        ldx #0                  ; le mot doit être « include »
cmpw    jsr peek
        ora #$20
        cmp w_include,x
        beq inc_ok
        jmp bad
inc_ok
        jsr nextc
        inx
        cpx #7
        bne cmpw
        lda #$22
        jsr expect
        ldx #11                 ; nom de fichier -> fcb_inc
        lda #" "
cl      sta fcb_inc,x
        dex
        bne cl
        stx fcb_inc
        ldx #1
nm      jsr peek
        beq bad
        cmp #$22
        beq endn
        jsr nextc
        cmp #"."
        beq ext
        cpx #9
        bcs nm
        jsr upcase
        sta fcb_inc,x
        inx
        bne nm
ext     ldx #9
ex      jsr peek
        beq bad
        cmp #$22
        beq endn
        jsr nextc
        cpx #12
        bcs ex
        jsr upcase
        sta fcb_inc,x
        inx
        bne ex
endn    jsr nextc
        jsr endline
        lda cur
        beq one
        lda #E_INCNEST
        jmp error
one     lda #<fcb_inc
        ldy #>fcb_inc
        jsr open_fcb
        cmp #$FF
        bne ok
        lda #E_INCNF
        jmp error
ok      lda #1
        sta cur
        lda #$80
        sta ridx+1
        lda #0
        sta feof+1
        sta lnlo+1
        sta lnhi+1
        rts
bad     lda #E_DIR
        jmp error
.)

upcase
        cmp #"a"
        bcc uc1
        cmp #"z"+1
        bcs uc1
        and #$DF
uc1     rts

directive
.(
        jsr nextc
        jsr peek
        cmp #"("
        bne nopen
        jsr nextc               ; .( : nouveau bloc
        ldx ssp
        inx
        cpx #MAXSCOPE
        bcc sok
        lda #E_BLOCK
        jmp error
sok     stx ssp
        inc scnt
        bne s1
        inc scnt+1
s1      lda scnt
        sta sstk_lo,x
        sta scope
        lda scnt+1
        sta sstk_hi,x
        sta scope+1
        jmp endline
nopen   cmp #")"
        bne word
        jsr nextc               ; .) : fin du bloc
        ldx ssp
        bne pop
        lda #E_BLOCK
        jmp error
pop     dex
        stx ssp
        lda sstk_lo,x
        sta scope
        lda sstk_hi,x
        sta scope+1
        jmp endline
word    ldx #0                  ; mot de la directive en majuscules
wl      jsr peek
        jsr idstart
        bcs we
        jsr peek
        jsr upcase
        cpx #6
        bcs wn
        sta dword,x
        inx
wn      jsr nextc
        jmp wl
we      lda #0
        sta dword,x
        ldx #0                  ; recherche dans la table
look    lda dir_tab,x
        beq unk
        ldy #0
cmp1    lda dir_tab,x
        cmp dword,y
        bne skip
        inx
        iny
        cmp #0
        bne cmp1
        lda dir_tab+1,x         ; adresse du traitement
        pha
        lda dir_tab,x
        pha
        rts
skip    lda dir_tab,x           ; entrée suivante
        inx
        cmp #0
        bne skip
        inx
        inx
        jmp look
unk     lda #E_DIR
        jmp error
.)

dir_tab .asc "BYT",0
        .word d_byt-1
        .asc "BYTE",0
        .word d_byt-1
        .asc "ASC",0
        .word d_byt-1
        .asc "TEXT",0
        .word d_byt-1
        .asc "WORD",0
        .word d_word-1
        .asc "DSB",0
        .word d_dsb-1
        .byt 0

; .byt / .asc : liste d'expressions et de chaînes
d_byt
.(
loop    jsr skipsp
        cmp #$22
        beq str
        cmp #"'"
        beq str
num     jsr expr
        jsr chk_byte
        lda val
        jsr emit
next    jsr skipsp
        cmp #","
        bne end
        jsr nextc
        jmp loop
end     jmp endline
str     sta quote
        lda lp                  ; début de la chaîne
        sta t2
        lda lp+1
        sta t2+1
        jsr nextc
sl      jsr peek
        bne s2
        lda #E_SYN
        jmp error
s2      jsr nextc
        cmp quote
        bne sl
        jsr skipsp              ; suivie d'un opérateur : c'est une expression
        jsr is_end
        beq emits
        cmp #","
        beq emits
        lda t2
        sta lp
        lda t2+1
        sta lp+1
        jmp num
emits   lda lp                  ; émet les caractères entre les guillemets
        sta t1
        lda lp+1
        sta t1+1
        lda t2
        sta lp
        lda t2+1
        sta lp+1
        jsr nextc
el      jsr peek
        cmp quote
        beq ee
        jsr emit
        jsr nextc
        jmp el
ee      lda t1
        sta lp
        lda t1+1
        sta lp+1
        jmp next
.)

; chk_byte : en passe 2, la valeur doit tenir sur un octet (-128..255)
chk_byte
.(
        lda pass
        cmp #2
        bne ok
        lda val+1
        beq ok
        cmp #$FF
        bne bad
        lda val
        bmi ok
bad     lda #E_RANGE
        jmp error
ok      rts
.)

d_word
.(
loop    jsr expr
        lda val
        jsr emit
        lda val+1
        jsr emit
        jsr skipsp
        cmp #","
        bne end
        jsr nextc
        jmp loop
end     jmp endline
.)

d_dsb
.(
        jsr expr
        jsr need_known
        lda val
        sta cnt
        lda val+1
        sta cnt+1
        lda #0
        sta fillv
        jsr skipsp
        cmp #","
        bne go
        jsr nextc
        jsr expr
        lda val
        sta fillv
go      jsr endline
loop    lda cnt
        ora cnt+1
        beq done
        lda fillv
        jsr emit
        lda cnt
        bne d1
        dec cnt+1
d1      dec cnt
        jmp loop
done    rts
.)

; ---------------------------------------------------------------------
; Production du code
; ---------------------------------------------------------------------
; emit : octet A à l'adresse pc (rangé en passe 2), pc+1
emit
.(
        pha
        lda orgset
        bne o1
        lda pc
        sta org
        lda pc+1
        sta org+1
        lda #1
        sta orgset
o1      lda pass
        cmp #2
        bne skip
        clc                     ; ptr = objbase + octets déjà produits
        lda ocnt
        adc objbase
        sta ptr
        lda ocnt+1
        adc objbase+1
        sta ptr+1
        cmp outlim+1
        bcs big
        pla
        ldy #0
        sta (ptr),y
        jmp einc
big     pla
        lda #E_BIG
        jmp error
skip    pla
einc    inc pc
        bne e2
        inc pc+1
e2      inc ocnt
        bne e3
        inc ocnt+1
e3      rts
.)

; ---------------------------------------------------------------------
; Instructions
; ---------------------------------------------------------------------
instruction
.(
        ldy #0                  ; trois lettres
        lda (lp),y
        jsr upcase
        sta m0
        iny
        lda (lp),y
        jsr upcase
        sta m1
        iny
        lda (lp),y
        jsr upcase
        sta m2
        iny
        lda (lp),y              ; suivies d'un séparateur
        cmp #" "
        beq msep
        jsr is_end
        beq msep
bad     lda #E_MNEM
        jmp error
msep    lda m0                  ; premier mnémonique de cette lettre
        sec
        sbc #"A"
        cmp #26
        bcs bad
        tax
        lda mn_first,x
        cmp #$FF
        beq bad
        tax
        sta tmpb                ; Y = 3 * X
        asl
        adc tmpb
        tay
look    lda mn_names,y
        cmp m0
        bne bad
        lda mn_names+1,y
        cmp m1
        bne nx
        lda mn_names+2,y
        cmp m2
        beq found
nx      iny
        iny
        iny
        inx
        cpx #NMNEM
        bne look
        beq bad
found   stx mnidx
        lda #0                  ; ligne de la table des opcodes : 12*X
        sta t0+1
        txa
        asl
        asl
        sta t0                  ; 4X
        asl                     ; 8X
        rol t0+1
        adc t0
        sta t0                  ; 12X (X < 56 : pas de retenue au-delà)
        lda t0+1
        adc #0
        sta t0+1
        clc
        lda t0
        adc #<mn_ops
        sta opc_p
        lda t0+1
        adc #>mn_ops
        sta opc_p+1
        lda lp                  ; après le mnémonique
        clc
        adc #3
        sta lp
        bcc a1
        inc lp+1
a1      jsr skipsp
        jsr is_end
        bne a2
        jmp m_imp
a2      cmp #"#"
        bne a3
        jsr nextc
        jsr expr
        lda #M_IMM
        jmp gen_op
a3      cmp #"("
        bne a4
        jmp paren
a4      and #$DF                ; A seul : accumulateur
        cmp #"A"
        bne gen
        ldy #1
        lda (lp),y
        cmp #" "
        beq acc
        jsr is_end
        bne gen
acc     jsr nextc
        jsr endline
        jmp m_imp
gen     jsr expr
        jsr skipsp
        cmp #","
        bne absm
        jsr nextc
        jsr skipsp
        and #$DF
        cmp #"X"
        beq abx
        cmp #"Y"
        beq aby
        lda #E_MODE
        jmp error
abx     jsr nextc
        jsr endline
        lda #M_ABX
        jmp gen_op
aby     jsr nextc
        jsr endline
        lda #M_ABY
        jmp gen_op
absm    jsr endline
        lda #M_ABS
        jmp gen_op
paren   lda lp                  ; ( : indirect, ou expression entre parenthèses
        sta t2
        lda lp+1
        sta t2+1
        jsr nextc
        jsr expr
        jsr skipsp
        cmp #","
        bne close
        jsr nextc               ; (zp,X)
        jsr skipsp
        and #$DF
        cmp #"X"
        bne reparse
        jsr nextc
        lda #")"
        jsr expect
        jsr endline
        lda #M_INX
        jmp gen_op
close   cmp #")"
        bne reparse
        jsr nextc
        jsr skipsp
        cmp #","
        bne nocom
        ldy #1                  ; (zp),Y
        lda (lp),y
        and #$DF
        cmp #"Y"
        bne reparse
        jsr nextc
        jsr nextc
        jsr endline
        lda #M_INY
        jmp gen_op
nocom   jsr is_end              ; (adr) : seulement JMP
        bne reparse
        lda mnidx
        cmp #MN_JMP
        bne reparse
        lda #M_IND
        jmp gen_op
reparse lda t2
        sta lp
        lda t2+1
        sta lp+1
        jmp gen
.)

m_imp
        lda #M_IMP
        jsr slot
        cmp #$FF
        bne mi1
        lda #E_MODE
        jmp error
mi1     jmp emit

; slot : opcode du mode A pour le mnémonique courant ($FF si absent)
slot
        tay
        lda (opc_p),y
        rts

; gen_op : choisit l'opcode pour le mode A et émet l'instruction
gen_op
.(
        sta mode
        cmp #M_ABS
        beq zabs
        cmp #M_ABX
        beq zabx
        cmp #M_ABY
        beq zaby
        jmp fixed
zabs    lda #M_REL              ; branchement ?
        jsr slot
        cmp #$FF
        beq z1
        jmp branch
z1      lda #M_ZP
        bne try
zabx    lda #M_ZPX
        bne try
zaby    lda #M_ZPY
try     sta tmpb                ; mode page zéro correspondant
        jsr slot
        cmp #$FF
        beq nozp
        lda eknown              ; connu et < 256 : page zéro
        beq abs_or
        lda val+1
        bne abs_or
usezp   lda tmpb
        sta mode
        jmp fixed
abs_or  lda mode                ; sinon version absolue si elle existe
        jsr slot
        cmp #$FF
        beq usezp
        jmp fixed
nozp    lda mode
.)
fixed
.(
        lda mode
        jsr slot
        cmp #$FF
        bne ok
        lda #E_MODE
        jmp error
ok      sta opc
        lda mode                ; taille de l'opérande
        cmp #M_IMP
        beq one
        cmp #M_ABS
        beq three
        cmp #M_ABX
        beq three
        cmp #M_ABY
        beq three
        cmp #M_IND
        beq three
        lda mode                ; un octet : contrôle de la valeur
        cmp #M_IMM
        bne zp
        jsr chk_byte
        jmp two
zp      lda pass
        cmp #2
        bne two
        lda val+1
        beq two
        lda #E_RANGE
        jmp error
two     lda opc
        jsr emit
        lda val
        jmp emit
three   lda opc
        jsr emit
        lda val
        jsr emit
        lda val+1
        jmp emit
one     lda opc
        jmp emit
.)

branch
.(
        sta opc
        lda pass
        cmp #2
        bne go
        lda undefl              ; cible inconnue : déjà signalé
        bne go
        clc                     ; déplacement = cible - (pc + 2)
        lda pc
        adc #2
        sta t0
        lda pc+1
        adc #0
        sta t0+1
        sec
        lda val
        sbc t0
        sta val
        lda val+1
        sbc t0+1
        sta val+1
        beq pos                 ; 0..127 ou -128..-1
        cmp #$FF
        bne far
        lda val
        bmi go
far     lda #E_BRANCH
        jmp error
pos     lda val
        bmi far
go      lda opc
        jsr emit
        lda val
        jmp emit
.)

; ---------------------------------------------------------------------
; Symboles
; ---------------------------------------------------------------------
; hash_name : hash = (somme des caractères + longueur) & 127
hash_name
.(
        lda nmlen
        ldy #0
loop    cpy nmlen
        beq done
        clc
        adc (nmptr),y
        iny
        bne loop
done    and #NBUCK-1
        sta hash
        rts
.)

; find : cherche nmptr/nmlen dans le bloc t2. C=0 trouvé (sym)
find
.(
        ldx hash
        lda bk_lo,x
        sta sym
        lda bk_hi,x
        sta sym+1
loop    lda sym
        ora sym+1
        beq nf
        ldy #S_LEN
        lda (sym),y
        cmp nmlen
        bne next
        ldy #S_SCOPE
        lda (sym),y
        cmp t2
        bne next
        iny
        lda (sym),y
        cmp t2+1
        bne next
        clc
        lda sym
        adc #S_NAME
        sta ptr
        lda sym+1
        adc #0
        sta ptr+1
        ldy #0
cmpn    cpy nmlen
        beq yes
        lda (ptr),y
        cmp (nmptr),y
        bne next
        iny
        bne cmpn
yes     clc
        rts
next    ldy #S_NEXT
        lda (sym),y
        tax
        iny
        lda (sym),y
        sta sym+1
        stx sym
        jmp loop
nf      sec
        rts
.)

; lookup : cherche le nom du bloc courant vers l'extérieur
lookup
.(
        jsr hash_name
        ldx ssp
loop    stx lkx
        lda sstk_lo,x
        sta t2
        lda sstk_hi,x
        sta t2+1
        jsr find
        bcc r
        ldx lkx
        dex
        bpl loop
        sec
r       rts
.)

; define : définit lbl = val (étiquette, ou constante si isequ)
define
.(
        lda lbl
        sta nmptr
        lda lbl+1
        sta nmptr+1
        lda lbllen
        sta nmlen
        jsr hash_name
        lda scope
        sta t2
        lda scope+1
        sta t2+1
        jsr find
        bcc fnd
        lda pass
        cmp #2
        beq phase
        lda eknown
        asl
        ora #F_DEF
        ldx isequ
        bne cst
        ora #F_LABEL
cst     ldx cur
        beq notinc
        ora #F_INC
notinc  sta nflags
        jmp create
fnd     lda pass
        cmp #2
        beq d2
        ldy #S_FLAGS            ; passe 1 : déjà défini
        lda (sym),y
        ora #F_DUP
        sta (sym),y
        rts
d2      ldy #S_FLAGS
        lda (sym),y
        and #F_DUP
        beq d3
        lda #E_DUP
        jmp error
d3      lda isequ
        bne setv
        ldy #S_VAL              ; étiquette : même adresse qu'en passe 1
        lda (sym),y
        cmp val
        bne phase
        iny
        lda (sym),y
        cmp val+1
        bne phase
        beq mark
setv    ldy #S_VAL
        lda val
        sta (sym),y
        iny
        lda val+1
        sta (sym),y
mark    ldy #S_FLAGS
        lda (sym),y
        ora #F_PASS2
        sta (sym),y
        rts
phase   lda errs                ; une erreur plus haut suffit à l'expliquer
        ora errs+1
        bne ph1
        lda #E_PHASE
        jmp error
ph1     rts
.)

; create : nouveau symbole (nmptr, nmlen, bloc t2, val, nflags)
create
.(
        clc                     ; place : symtop + 8 + longueur
        lda symtop
        adc #S_NAME
        sta t0
        lda symtop+1
        adc #0
        sta t0+1
        clc
        lda t0
        adc nmlen
        sta t0
        bcc c1
        inc t0+1
c1      lda t0+1
        clc
        adc #1                  ; garde une page pour le code
        cmp outlim+1
        bcc ok
        lda #<m_symfull
        ldy #>m_symfull
        jsr puts
        jmp WBOOT
ok      lda symtop
        sta sym
        lda symtop+1
        sta sym+1
        ldx hash
        ldy #S_NEXT
        lda bk_lo,x
        sta (sym),y
        iny
        lda bk_hi,x
        sta (sym),y
        iny
        lda t2
        sta (sym),y
        iny
        lda t2+1
        sta (sym),y
        iny
        lda val
        sta (sym),y
        iny
        lda val+1
        sta (sym),y
        iny
        lda nflags
        sta (sym),y
        iny
        lda nmlen
        sta (sym),y
        clc
        lda sym
        adc #S_NAME
        sta ptr
        lda sym+1
        adc #0
        sta ptr+1
        ldy #0
cp      cpy nmlen
        beq done
        lda (nmptr),y
        sta (ptr),y
        iny
        bne cp
done    lda sym
        sta bk_lo,x
        lda sym+1
        sta bk_hi,x
        lda t0
        sta symtop
        lda t0+1
        sta symtop+1
        inc nsyms
        bne r
        inc nsyms+1
r       rts
.)

; ---------------------------------------------------------------------
; Expressions
; ---------------------------------------------------------------------
; expr : évalue l'expression en lp -> val ; eknown = 1 si connue
expr
        lda #1
        sta eknown
expr_sub
.(
        jsr skipsp
        cmp #"<"
        bne nlo
        jsr nextc
        lda #0
        jsr ev_level
        lda #0
        sta val+1
        rts
nlo     cmp #">"
        bne nhi
        jsr nextc
        lda #0
        jsr ev_level
        lda val+1
        sta val
        lda #0
        sta val+1
        rts
nhi     lda #0
        jmp ev_level
.)

; ev_level : niveau de priorité A (0 = |, 1 = ^, 2 = &, 3 = << >>,
; 4 = + -, 5 = * /, 6 = unaire)
ev_level
.(
        cmp #6
        bcc bin
        jmp unary
bin     pha
        clc
        adc #1
        jsr ev_level
loop    jsr skipsp
        jsr getop               ; Y = opérateur, X = longueur
        bcs done
        lda op_prec,y
        sta tmpb
        pla
        pha
        cmp tmpb
        bne done
sk      jsr nextc
        dex
        bne sk
        tya
        pha
        lda val
        pha
        lda val+1
        pha
        tsx
        lda $0104,x             ; niveau
        clc
        adc #1
        jsr ev_level
        pla
        sta t1+1
        pla
        sta t1
        pla
        jsr apply
        jmp loop
done    pla
        rts
.)

; getop : opérateur binaire en lp ? C=0, Y = numéro, X = longueur
getop
.(
        lda lp                  ; déjà analysé à cette position ?
        cmp gop_lp
        bne new
        lda lp+1
        cmp gop_lp+1
        bne new
        ldy gop_y
        ldx gop_x
        lda gop_c
        lsr
        rts
new     jsr do_getop
        sty gop_y
        stx gop_x
        lda #0
        rol
        sta gop_c
        lda lp
        sta gop_lp
        lda lp+1
        sta gop_lp+1
        lda gop_c
        lsr
        rts
.)
do_getop
.(
        jsr peek
        ldx #1
        ldy #0
        cmp #"|"
        beq ok
        iny
        cmp #"^"
        beq ok
        iny
        cmp #"&"
        beq ok
        iny
        cmp #"<"
        beq dbl
        iny
        cmp #">"
        beq dbl
        iny
        cmp #"+"
        beq ok
        iny
        cmp #"-"
        beq ok
        iny
        cmp #"*"
        beq ok
        iny
        cmp #"/"
        beq ok
none    sec
        rts
dbl     sta tmpb                ; << ou >>
        sty opy
        ldy #1
        lda (lp),y
        ldy opy
        cmp tmpb
        bne none
        ldx #2
ok      clc
        rts
.)

op_prec .byt 0,1,2,3,3,4,4,5,5

; apply : val = t1 (op A) val
apply
        asl
        tax
        lda ap_tab+1,x
        pha
        lda ap_tab,x
        pha
        rts
ap_tab  .word ap_or-1, ap_xor-1, ap_and-1, ap_shl-1, ap_shr-1
        .word ap_add-1, ap_sub-1, ap_mul-1, ap_div-1

ap_or   lda t1
        ora val
        sta val
        lda t1+1
        ora val+1
        sta val+1
        rts
ap_xor  lda t1
        eor val
        sta val
        lda t1+1
        eor val+1
        sta val+1
        rts
ap_and  lda t1
        and val
        sta val
        lda t1+1
        and val+1
        sta val+1
        rts
ap_shl
.(
        lda val
        and #15
        tax
        beq done
loop    asl t1
        rol t1+1
        dex
        bne loop
done    jmp t1val
.)
ap_shr
.(
        lda val
        and #15
        tax
        beq done
loop    lsr t1+1
        ror t1
        dex
        bne loop
done    jmp t1val
.)
ap_add  clc
        lda t1
        adc val
        sta val
        lda t1+1
        adc val+1
        sta val+1
        rts
ap_sub  sec
        lda t1
        sbc val
        sta val
        lda t1+1
        sbc val+1
        sta val+1
        rts
ap_mul
.(
        lda #0
        sta t0
        sta t0+1
        ldx #16
loop    lsr val+1
        ror val
        bcc no
        clc
        lda t0
        adc t1
        sta t0
        lda t0+1
        adc t1+1
        sta t0+1
no      asl t1
        rol t1+1
        dex
        bne loop
        lda t0
        sta val
        lda t0+1
        sta val+1
        rts
.)
ap_div
.(
        lda val
        ora val+1
        bne ok
        lda eknown              ; valeur pas encore connue : 0
        beq t1val0
        lda #E_DIV
        jmp error
ok      lda #0
        sta t0
        sta t0+1
        ldx #16
loop    asl t1
        rol t1+1
        rol t0
        rol t0+1
        sec
        lda t0
        sbc val
        tay
        lda t0+1
        sbc val+1
        bcc no
        sta t0+1
        sty t0
        inc t1
no      dex
        bne loop
.)
t1val   lda t1
        sta val
        lda t1+1
        sta val+1
        rts
t1val0  lda #0
        sta val
        sta val+1
        rts

unary
.(
        jsr skipsp
        cmp #"-"
        bne u1
        jsr nextc
        jsr unary
        sec
        lda #0
        sbc val
        sta val
        lda #0
        sbc val+1
        sta val+1
        rts
u1      cmp #"+"
        bne primary
        jsr nextc
        jmp unary
.)

primary
.(
        jsr skipsp
        cmp #"("
        bne p1
        jsr nextc
        jsr expr_sub
        lda #")"
        jmp expect
p1      cmp #"$"
        bne p2
        jsr nextc
        jmp hexnum
p2      cmp #"%"
        bne p3
        jsr nextc
        jmp binnum
p3      cmp #$22
        beq chr
        cmp #"'"
        bne p4
chr     sta quote               ; caractère entre guillemets
        jsr nextc
        jsr peek
        beq bad
        sta val
        lda #0
        sta val+1
        jsr nextc
        jsr peek
        cmp quote
        bne bad
        jmp nextc
p4      cmp #"*"
        bne p5
        jsr nextc               ; * : adresse courante
        lda lpc
        sta val
        lda lpc+1
        sta val+1
        rts
p5      cmp #"0"
        bcc p6
        cmp #"9"+1
        bcs p6
        jmp decnum
p6      jsr idstart
        bcs bad
        jmp symref
bad     lda #E_SYN
        jmp error
.)

; hexval : A = chiffre hexa -> 0-15, C=0 ; C=1 sinon
hexval
.(
        cmp #"0"
        bcc bad
        cmp #"9"+1
        bcc dig
        and #$DF
        cmp #"A"
        bcc bad
        cmp #"F"+1
        bcs bad
        sbc #"A"-11
        clc
        rts
dig     sbc #"0"-1
        clc
        rts
bad     sec
        rts
.)

hexnum
.(
        lda #0
        sta val
        sta val+1
        sta tmpb
loop    jsr peek
        jsr hexval
        bcs end
        ldx #4
sh      asl val
        rol val+1
        dex
        bne sh
        ora val
        sta val
        inc tmpb
        jsr nextc
        jmp loop
end     lda tmpb
        beq bad
        rts
bad     lda #E_SYN
        jmp error
.)

binnum
.(
        lda #0
        sta val
        sta val+1
        sta tmpb
loop    jsr peek
        cmp #"0"
        beq dig
        cmp #"1"
        bne end
dig     lsr                     ; C = chiffre
        rol val
        rol val+1
        inc tmpb
        jsr nextc
        jmp loop
end     lda tmpb
        beq bad
        rts
bad     lda #E_SYN
        jmp error
.)

decnum
.(
        lda #0
        sta val
        sta val+1
loop    jsr peek
        cmp #"0"
        bcc end
        cmp #"9"+1
        bcs end
        sec
        sbc #"0"
        pha
        asl val                 ; val = val * 10 + chiffre
        rol val+1
        lda val
        sta t1
        lda val+1
        sta t1+1
        asl val
        rol val+1
        asl val
        rol val+1
        clc
        lda val
        adc t1
        sta val
        lda val+1
        adc t1+1
        sta val+1
        pla
        clc
        adc val
        sta val
        bcc nx
        inc val+1
nx      jsr nextc
        jmp loop
end     rts
.)

symref
.(
        jsr get_ident
        jsr lookup
        bcc found
        lda pass
        cmp #2
        bne p1u
        lda #E_UNDEF            ; signalée, la ligne continue avec 0
        sta undefl
        jsr report
p1u     lda #0                  ; passe 1 : pas encore défini
        sta val
        sta val+1
        sta eknown
        rts
found   ldy #S_VAL
        lda (sym),y
        sta val
        iny
        lda (sym),y
        sta val+1
        ldy #S_FLAGS
        lda (sym),y
        sta tmpb
        lda pass
        cmp #2
        beq p2
        lda tmpb
        and #F_KNOWN
        bne r
        lda #0
        sta eknown
r       rts
p2      lda tmpb                ; connu « avant cette ligne » comme en passe 1
        and #F_KNOWN+F_PASS2
        cmp #F_KNOWN+F_PASS2
        beq r
        lda #0
        sta eknown
        lda tmpb
        and #F_KNOWN+F_PASS2
        bne r
        lda #E_FWD
        jmp report
.)

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
putc
        pha
        txa
        pha
        tya
        pha
        tsx
        lda $0103,x
        jsr B_CONOUT
        pla
        tay
        pla
        tax
        pla
        rts

puts
.(
        sta sptr
        sty sptr+1
        ldy #0
loop    lda (sptr),y
        beq done
        jsr putc
        iny
        bne loop
        inc sptr+1
        bne loop
done    rts
.)

crlf
        lda #13
        jsr putc
        lda #10
        jmp putc

puthex4
        lda #"$"
        jsr putc
        lda val+1
        jsr puthex2
        lda val
puthex2
        pha
        lsr
        lsr
        lsr
        lsr
        jsr ph1
        pla
        and #15
ph1     tax
        lda hexdigits,x
        jmp putc

; putdec : val en décimal, sans zéros de tête
putdec
.(
        lda #0
        sta tmpb
        ldx #0
dig     ldy #0
sub     lda val
        sec
        sbc d_lo,x
        pha
        lda val+1
        sbc d_hi,x
        bcc dn
        sta val+1
        pla
        sta val
        iny
        bne sub
dn      pla
        tya
        bne pr
        lda tmpb
        beq skip
        tya
pr      ora #"0"
        jsr putc
        lda #1
        sta tmpb
skip    inx
        cpx #4
        bne dig
        lda val
        ora #"0"
        jmp putc
d_lo    .byt <10000,<1000,<100,<10
d_hi    .byt >10000,>1000,>100,>10
.)

; ---------------------------------------------------------------------
; Données
; ---------------------------------------------------------------------
#include "asm_tab.s"

hexdigits .asc "0123456789ABCDEF"
w_include .asc "include"

; état des deux fichiers (0 = source, 1 = fichier inclus)
ridx    .byt $80,$80
feof    .byt 0,0
lnlo    .byt 0,0
lnhi    .byt 0,0
fcb_lo  .byt <fcb_src,<fcb_inc
fcb_hi  .byt >fcb_src,>fcb_inc
rb_lo   .byt <recb0,<recb1
rb_hi   .byt >recb0,>recb1

err_tab .word e_syn, e_undef, e_dup, e_mode, e_range, e_branch, e_mnem
        .word e_dir, e_p1, e_incnf, e_incnest, e_block, e_div, e_phase
        .word e_org, e_fwd, e_big

e_syn     .asc "Syntaxe",0
e_undef   .asc "Symbole inconnu",0
e_dup     .asc "Symbole deja defini",0
e_mode    .asc "Mode d'adressage impossible",0
e_range   .asc "Valeur trop grande",0
e_branch  .asc "Branchement trop loin",0
e_mnem    .asc "Instruction inconnue",0
e_dir     .asc "Directive inconnue",0
e_p1      .asc "Valeur inconnue a ce stade",0
e_incnf   .asc "Fichier inclus introuvable",0
e_incnest .asc "Un seul niveau d'inclusion",0
e_block   .asc "Blocs .( .) mal appaires",0
e_div     .asc "Division par zero",0
e_phase   .asc "Erreur de phase",0
e_org     .asc "Adresse",0
e_fwd     .asc "Reference en avant trop complexe",0
e_big     .asc "Code trop gros",0

m_usage   .asc "Usage : ASM NOM   (NOM.ASM -> NOM.COM)",13,10,0
m_banner  .asc "ASM CP/A 1.0",13,10,0
m_nosrc   .asc "Source introuvable",13,10,0
m_pass    .asc "Passe ",0
m_big     .asc "Programme trop gros pour la memoire",13,10,0
m_errs    .asc " erreur(s) : rien n'est ecrit.",13,10,0
m_empty   .asc "Aucun code produit.",13,10,0
m_com     .asc ".COM ",0
m_comma   .asc " : ",0
m_bytes   .asc " octets",13,10,0
m_syms    .asc " symboles (.SYM)",13,10,0
m_dfull   .asc "Disque plein",13,10,0
m_esc     .asc "Interrompu",13,10,0
m_colon   .asc " : ",0
m_symfull .asc "Table des symboles pleine",13,10,0

; ---------------------------------------------------------------------
; Zones de travail (hors du fichier .COM)
; ---------------------------------------------------------------------
endcode
bk_lo   = endcode
bk_hi   = bk_lo+NBUCK
lbuf    = bk_hi+NBUCK           ; ligne source (1022 caractères au plus)
recb0   = lbuf+1280
recb1   = recb0+128
fcb_src = recb1+128
fcb_inc = fcb_src+36
fcb_out = fcb_inc+36
sstk_lo = fcb_out+36
sstk_hi = sstk_lo+MAXSCOPE
dword   = sstk_hi+MAXSCOPE
SYMBASE = dword+8
