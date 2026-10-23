; =====================================================================
;  LOGOTR.COM — traduit un programme LOGO (.LOG) d'une langue à l'autre
;
;  LOGOTR NOM [DEST] [/EN|/FR]
;    /EN : du français vers l'anglais ; /FR : de l'anglais vers le
;    français ; sans option : vers la langue de la disquette (D_LANG).
;    Sans DEST : NOM.LOG est remplacé, l'original gardé en NOM.BAK.
;
;  Seules les primitives sont traduites (vocabulaires numérotés de
;  lgtr_tab.s, produits par tools/gen_logo_voc.py avec ceux de
;  LOGO.COM) ; les noms de l'utilisateur (procédures, variables, mots
;  entre guillemets) restent tels quels. Une liste est du code si elle
;  est un argument liste d'instructions (REPETE, SI, EXECUTE,
;  ENSEMBLE : tr_kind) : on y traduit ; les autres listes sont des
;  données, recopiées telles quelles. Avertissements (numéro de ligne) :
;  une liste de données qui commence par une primitive (elle est
;  peut-être exécutée plus tard : DONNE "L [AV 10] puis EXECUTE :L), un
;  nom de l'utilisateur qui est une primitive de la langue d'arrivée.
;  LISTE (instruction et fonction en français) : instruction en début
;  d'instruction devant un mot entre guillemets, sinon fonction.
;
;  Le fichier est lu en entier en mémoire, traduit dans un second
;  tampon, écrit dans NOM.$$$, puis renommé (rien n'est perdu si le
;  disque est plein).
; =====================================================================

#include "cpa.inc"

ip      = $10           ; lecture (texte d'origine)
iend    = $12           ; fin du texte d'origine
op      = $14           ; écriture (texte traduit)
olim    = $16           ; limite du tampon de sortie
line    = $18           ; numéro de ligne (mot)
nwarn   = $1A           ; avertissements (mot)
ntr     = $1C           ; mots traduits (mot)
tp      = $1E           ; parcours d'une table
lev     = $20           ; niveau de liste (0 : la ligne)
bound   = $21           ; 1 : début d'instruction (début de ligne ou de liste de code)
wlen    = $22           ; longueur du mot lu
lower   = $23           ; 1 : le mot était en minuscules
id      = $24           ; numéro de la primitive trouvée
rank    = $25           ; rang du nom (0 : long)
tgt     = $26           ; langue d'arrivée : 0 français, 1 anglais
pour    = $27           ; 1 : le mot suivant est un nom de procédure
same    = $28           ; 1 : pas de DEST (remplace NOM, garde NOM.BAK)
tmp     = $29
num     = $2A           ; nombre à afficher (mot)
stab    = $2C           ; table de la langue de départ
dtab    = $2E           ; table de la langue d'arrivée
depth   = $30           ; profondeur d'une liste de données
p1      = $31           ; pointeur de travail

MAXLEV  = 15

        *= $0500
start
.(
        ldx #0                  ; zone de travail à 0
        txa
z       sta ip,x
        inx
        cpx #$30
        bne z
        lda #D_LANG
        sta tgt
        jsr options
        lda FCB1+1
        cmp #" "+1
        bcs n1
use     lda #<m_use
        ldy #>m_use
        jmp pstop
n1      cmp #"/"
        beq use
        ldx #<sfcb              ; source : FCB1, .LOG par défaut
        ldy #>sfcb
        lda #<FCB1
        jsr setfcb
        lda FCB2+1              ; destination : FCB2 (absente, ou une option)
        cmp #" "+1
        bcc nod
        cmp #"/"
        beq nod
        ldx #<dfcb
        ldy #>dfcb
        lda #<FCB2
        jsr setfcb
        jmp n2
nod     inc same
        ldx #11                 ; DEST = NOM
cd      lda sfcb,x
        sta dfcb,x
        dex
        bpl cd
n2      lda tgt                 ; tables : départ, arrivée
        bne en
        lda #<tr_en
        sta stab
        lda #>tr_en
        sta stab+1
        lda #<tr_fr
        sta dtab
        lda #>tr_fr
        sta dtab+1
        jmp n3
en      lda #<tr_fr
        sta stab
        lda #>tr_fr
        sta stab+1
        lda #<tr_en
        sta dtab
        lda #>tr_en
        sta dtab+1
n3      jsr load
        jsr translate
        jsr save
        jmp report
.)

; options : /EN, /FR dans la ligne de paramètres
options
.(
        ldx #0
o1      cpx TAIL
        bcs r
        lda TAIL+1,x
        inx
        cmp #"/"
        bne o1
        lda TAIL+1,x
        cmp #"E"
        bne o2
        lda #1
        sta tgt
        bne o1
o2      cmp #"F"
        bne o1
        lda #0
        sta tgt
        beq o1
r       rts
.)

; setfcb : FCB de la page de base (A = poids faible, page $04) -> FCB X/Y
;   (lecteur et nom ; type LOG si vide ; le reste à 0)
setfcb
.(
        sta p1
        lda #>FCB1
        sta p1+1
        stx tp
        sty tp+1
        ldy #35
        lda #0
z       sta (tp),y
        dey
        bpl z
        ldy #11
c       lda (p1),y
        sta (tp),y
        dey
        bpl c
        ldy #9
        lda (tp),y
        cmp #" "
        bne r
        ldx #0
t       lda t_log,x
        sta (tp),y
        iny
        inx
        cpx #3
        bne t
r       rts
.)

; load : le fichier source en entier dans buf (^Z exclu) -> iend
load
.(
        lda #<sfcb
        ldy #>sfcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_nf
        ldy #>m_nf
        jmp pstop
ok      lda #<buf
        sta ip
        lda #>buf
        sta ip+1
rd      clc                     ; place pour 128 octets, et autant en sortie
        lda ip+1
        adc #2
        cmp TPA_TOP+1
        bcc fit
        lda #<m_big
        ldy #>m_big
        jmp pstop
fit     lda ip
        ldy ip+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<sfcb
        ldy #>sfcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne eof
        clc
        lda ip
        adc #128
        sta ip
        bcc rd
        inc ip+1
        bne rd
eof     lda #<buf               ; fin : le premier ^Z
        sta iend
        lda #>buf
        sta iend+1
f       lda iend
        cmp ip
        lda iend+1
        sbc ip+1
        bcs fin
        ldy #0
        lda (iend),y
        cmp #$1A
        beq fin
        inc iend
        bne f
        inc iend+1
        bne f
fin     lda iend                ; sortie : après le texte, jusqu'au haut de la TPA
        sta op
        lda iend+1
        clc
        adc #1
        sta op+1
        lda TPA_TOP
        sta olim
        lda TPA_TOP+1
        sec
        sbc #1                  ; (une page pour compléter le dernier enregistrement)
        sta olim+1
        lda op
        sta obuf
        lda op+1
        sta obuf+1
        lda #<buf
        sta ip
        lda #>buf
        sta ip+1
        rts
.)

; ---------------------------------------------------------------------
; Traduction : ip..iend -> op
; ---------------------------------------------------------------------
translate
.(
        lda #1
        sta line
        jsr newline
loop    lda ip
        cmp iend
        lda ip+1
        sbc iend+1
        bcc go
        rts
go      ldy #0
        lda (ip),y
        cmp #13
        bne nc
        jsr copy1
        inc line
        bne nl
        inc line+1
nl      jsr newline
        jmp loop
nc      cmp #" "
        beq cp
        cmp #10
        beq cp
        cmp #9
        bne nsp
cp      jsr copy1
        jmp loop
nsp     cmp #"["
        bne nob
        jsr open_list
        jmp loop
nob     cmp #"]"
        bne noc
        jsr copy1
        lda lev
        beq b0
        dec lev
b0      lda #0
        sta bound
        jmp loop
noc     cmp #$22                ; "mot ou :variable : tels quels
        beq lit
        cmp #":"
        bne nol
lit     jsr copy1
        jsr copy_word
        lda #0
        sta bound
        jmp loop
nol     jsr is_delim
        bcc wd
        jsr copy1               ; ( ) + - * / = < >
        lda #0
        sta bound
        jmp loop
wd      cmp #"0"
        bcc word
        cmp #"9"+1
        bcs word
        jsr copy_word           ; nombre
        lda #0
        sta bound
        jmp loop
word    jsr do_word
        jmp loop
.)

; newline : niveau 0, début d'instruction, rien en attente
newline
.(
        lda #0
        sta lev
        sta pend
        lda #1
        sta code
        sta bound
        lda #0
        sta pour
        rts
.)

; open_list : [ ; liste de code si une primitive en attend une à ce niveau
open_list
.(
        ldx lev
        lda code,x
        beq data
        lda pend,x
        beq data
        dec pend,x
        cpx #MAXLEV
        bcs data
        inc lev
        ldx lev
        lda #1
        sta code,x
        lda #0
        sta pend,x
        lda #1
        sta bound
        jmp copy1
data    lda ip                  ; liste de données : le premier mot
        sta p1                  ;   est-il une primitive ?
        lda ip+1
        sta p1+1
        ldy #1
sk      lda (p1),y
        cmp #" "
        bne s2
        iny
        bne sk
s2      jsr is_delim
        bcs cdat
        cmp #$22
        beq cdat
        cmp #":"
        beq cdat
        tya                     ; le mot dans wbuf
        clc
        adc p1
        sta p1
        bcc s3
        inc p1+1
s3      jsr get_word
        lda stab
        ldy stab+1
        jsr lookup
        bcs cdat
        lda #<m_wdata
        ldy #>m_wdata
        jsr warn
cdat     lda #0                  ; recopie jusqu'au ] qui ferme (ou la ligne)
        sta depth
c1      lda ip
        cmp iend
        lda ip+1
        sbc iend+1
        bcs r
        ldy #0
        lda (ip),y
        cmp #13
        beq r
        cmp #"["
        bne c2
        inc depth
c2      cmp #"]"
        bne c3
        dec depth
c3      jsr copy1
        lda depth
        bne c1
r       lda #0
        sta bound
        rts
.)

; do_word : un mot à la place de code
do_word
.(
        lda ip
        sta p1
        lda ip+1
        sta p1+1
        jsr get_word            ; -> wbuf (majuscules), wlen, lower
        lda pour
        beq np
        lda #0                  ; nom de procédure : tel quel
        sta pour
        jsr check_name
        jmp copyw
np      lda stab
        ldy stab+1
        jsr lookup
        bcc found
        jsr check_name          ; nom de l'utilisateur
copyw   jsr copy_word
        lda #0
        sta bound
        rts
found   lda tgt                 ; nom à double sens (LISTE, du français) :
        beq nd                  ;   instruction en début d'instruction
        lda id                  ;   devant "mot, sinon fonction
        cmp #TR_FR_DP
        bne nd
        lda bound
        beq fn
        ldy wlen
sp      lda (ip),y
        cmp #" "
        bne sp2
        iny
        bne sp
sp2     cmp #$22
        beq nd
fn      lda #TR_FR_DF
        sta id
nd      jsr skip_word           ; le mot d'origine est passé
        jsr put_target
        inc ntr
        bne k
        inc ntr+1
k       lda #0
        sta bound
        lda id
        cmp #TR_POUR
        bne kk
        inc pour
kk      cmp #TR_N+1             ; FIN / END
        bcs r
        tax
        lda tr_kind-1,x
        bmi r                   ; fonction : rien en attente
        and #7                  ; instruction : nombre de listes de code
        tax
        lda nbits,x
        ldx lev
        sta pend,x
r       rts
.)
nbits   .byt 0,1,1,2,1,2,2,3

; check_name : un nom de l'utilisateur (wbuf) est-il une primitive dans la
;   langue d'arrivée ? -> avertissement
check_name
.(
        lda dtab
        ldy dtab+1
        jsr lookup
        bcs r
        lda #<m_wname
        ldy #>m_wname
        jmp warn
r       rts
.)

; get_word : mot en p1 -> wbuf (majuscules, 0 à la fin), wlen ; lower = 1
;   si la première lettre est une minuscule
get_word
.(
        ldy #0
        sty lower
        lda (p1),y
        cmp #"a"
        bcc g
        cmp #"z"+1
        bcs g
        inc lower
g       lda (p1),y
        jsr is_delim
        bcs e
        cmp #$1A
        beq e
        cmp #"a"
        bcc u
        cmp #"z"+1
        bcs u
        and #$DF
u       cpy #31
        bcs n
        sta wbuf,y
n       iny
        bne g
e       sty wlen
        cpy #31
        bcc z
        ldy #31
z       lda #0
        sta wbuf,y
        rts
.)

; is_delim : A délimiteur de mot ? -> C=1
is_delim
.(
        ldx #dl_end-dlims-1
l       cmp dlims,x
        beq y
        dex
        bpl l
        clc
        rts
y       sec
        rts
.)
dlims   .asc " []()+-*/=<>",13,10,9,$1A
dl_end

; lookup : wbuf dans la table A/Y -> C=0, id, rank ; C=1 absent
lookup
.(
        sta tp
        sty tp+1
e       ldy #0
        lda (tp),y
        bne c
        sec
        rts
c       lda (tp),y
        cmp wbuf,y
        bne nx
        cmp #0
        beq f
        iny
        bne c
nx      lda (tp),y              ; jusqu'au 0 du nom
        beq nz
        iny
        bne nx
nz      tya                     ; nom, 0, numéro, rang
        clc
        adc #3
        adc tp
        sta tp
        bcc e
        inc tp+1
        bne e
f       iny
        lda (tp),y
        sta id
        iny
        lda (tp),y
        sta rank
        clc
        rts
.)

; put_target : nom de la primitive id (rang rank, sinon le long) dans la
;   langue d'arrivée -> sortie (en minuscules si lower)
put_target
.(
        lda #0                  ; tmp : 1 = cherche le rang 0
        sta tmp
again   lda dtab
        sta tp
        lda dtab+1
        sta tp+1
e       ldy #0
        lda (tp),y
        bne s
        lda #1                  ; pas ce rang : le nom long
        sta tmp
        bne again
s       iny                     ; au 0 du nom
        lda (tp),y
        bne s
        iny
        lda (tp),y
        cmp id
        bne nx
        iny
        lda tmp
        bne w
        lda (tp),y
        cmp rank
        beq w
        dey
nx      iny                     ; entrée suivante
        iny
        tya
        clc
        adc tp
        sta tp
        bcc e
        inc tp+1
        bne e
w       ldy #0
l       lda (tp),y
        beq r
        ldx lower
        beq o
        cmp #"A"
        bcc o
        cmp #"Z"+1
        bcs o
        ora #$20
o       sty tmp
        jsr put
        ldy tmp
        iny
        bne l
r       rts
.)

; copy1 : un caractère de ip vers op
copy1
.(
        ldy #0
        lda (ip),y
        jsr put
        inc ip
        bne r
        inc ip+1
r       rts
.)

; copy_word : recopie jusqu'au délimiteur suivant
copy_word
.(
l       lda ip
        cmp iend
        lda ip+1
        sbc iend+1
        bcs r
        ldy #0
        lda (ip),y
        jsr is_delim
        bcs r
        jsr copy1
        jmp l
r       rts
.)

; skip_word : passe le mot d'origine (wlen octets)
skip_word
.(
        clc
        lda ip
        adc wlen
        sta ip
        bcc r
        inc ip+1
r       rts
.)

; put : A -> sortie
put
.(
        ldy #0
        sta (op),y
        inc op
        bne c
        inc op+1
c       lda op
        cmp olim
        lda op+1
        sbc olim+1
        bcs full
        rts
full    lda #<m_big
        ldy #>m_big
        jmp pstop
.)

; warn : "L n : message mot" (wbuf)
warn
.(
        pha
        tya
        pha
        inc nwarn
        bne w
        inc nwarn+1
w       lda #<m_line
        ldy #>m_line
        jsr pstr
        lda line
        sta num
        lda line+1
        sta num+1
        jsr pnum
        lda #<m_sep
        ldy #>m_sep
        jsr pstr
        pla
        tay
        pla
        jsr pstr
        lda #<wbuf
        ldy #>wbuf
        jsr pstr
        lda #<m_crlf
        ldy #>m_crlf
        jmp pstr
.)

; ---------------------------------------------------------------------
; Écriture : obuf..op dans NOM.$$$, puis les renommages
; ---------------------------------------------------------------------
save
.(
        ldy #0                  ; ^Z jusqu'à la fin de l'enregistrement
z       lda #$1A
        sta (op),y
        iny
        cpy #128
        bne z
        ldx #11                 ; tfcb : DEST.$$$
c       lda dfcb,x
        sta tfcb,x
        dex
        bpl c
        lda #"$"
        sta tfcb+9
        sta tfcb+10
        sta tfcb+11
        lda #<tfcb
        ldy #>tfcb
        ldx #F_DELETE
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne mk
        lda #<m_dir
        ldy #>m_dir
        jmp pstop
mk      lda obuf
        sta p1
        lda obuf+1
        sta p1+1
wr      lda p1                  ; tant que p1 < op
        cmp op
        lda p1+1
        sbc op+1
        bcs done
        lda p1
        ldy p1+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        bne full
        clc
        lda p1
        adc #128
        sta p1
        bcc wr
        inc p1+1
        bne wr
full    lda #<tfcb
        ldy #>tfcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<tfcb
        ldy #>tfcb
        ldx #F_DELETE
        jsr BDOS
        lda #<m_full
        ldy #>m_full
        jmp pstop
done    lda #<tfcb
        ldy #>tfcb
        ldx #F_CLOSE
        jsr BDOS
        lda same
        beq other
        ldx #11                 ; NOM -> NOM.BAK
b       lda sfcb,x
        sta rfcb,x
        sta rfcb+16,x
        dex
        bpl b
        ldx #2
bk      lda t_bak,x
        sta rfcb+25,x
        dex
        bpl bk
        lda #<rbak              ; l'ancien .BAK d'abord
        ldy #>rbak
        ldx #F_DELETE
        jsr BDOS
        lda #<rfcb
        ldy #>rfcb
        ldx #F_RENAME
        jsr BDOS
        cmp #$FF
        beq ro
        jmp ren
other   lda #<dfcb              ; DEST remplacé
        ldy #>dfcb
        ldx #F_DELETE
        jsr BDOS
ren     ldx #11                 ; $$$ -> DEST
r1      lda tfcb,x
        sta rfcb,x
        lda dfcb,x
        sta rfcb+16,x
        dex
        bpl r1
        lda #<rfcb
        ldy #>rfcb
        ldx #F_RENAME
        jsr BDOS
        cmp #$FF
        beq ro
        rts
ro      lda #<m_ro              ; protégé : le texte reste dans NOM.$$$
        ldy #>m_ro
        jmp pstop
.)

; report : bilan
report
.(
        lda ntr
        sta num
        lda ntr+1
        sta num+1
        jsr pnum
        lda #<m_ntr
        ldy #>m_ntr
        jsr pstr
        lda nwarn
        sta num
        lda nwarn+1
        sta num+1
        jsr pnum
        lda #<m_nwarn
        ldy #>m_nwarn
        jsr pstr
        lda #<m_done
        ldy #>m_done
        jsr pstr
        ldx #1                  ; DEST : nom écrit
n       lda dfcb,x
        cmp #" "
        beq t
        stx tmp
        jsr pchar
        ldx tmp
        inx
        cpx #9
        bne n
t       lda #"."
        jsr pchar
        ldx #9
e       stx tmp
        lda dfcb,x
        jsr pchar
        ldx tmp
        inx
        cpx #12
        bne e
        lda #<m_crlf
        ldy #>m_crlf
        jsr pstr
        rts
.)

; pstop : message A/Y, puis fin
pstop   jsr pstr
        jmp WBOOT

; pstr : chaîne A/Y terminée par 0
pstr
.(
        sta p1
        sty p1+1
        ldy #0
l       lda (p1),y
        beq r
        sty tmp
        jsr pchar
        ldy tmp
        iny
        bne l
r       rts
.)

pchar   ldx #F_CONOUT
        jmp BDOS

; pnum : num (mot) en décimal, sans zéros devant
pnum
.(
        lda #0
        sta tmp                 ; 1 : un chiffre déjà écrit
        ldx #0
d       ldy #"0"
s       lda num
        sec
        sbc dlo,x
        pha
        lda num+1
        sbc dhi,x
        bcc n
        sta num+1
        pla
        sta num
        iny
        bne s
n       pla
        cpy #"0"
        bne w
        lda tmp
        bne w
        cpx #4
        bne nx
w       lda #1
        sta tmp
        tya
        stx p1
        jsr pchar
        ldx p1
nx      inx
        cpx #5
        bne d
        rts
.)
dlo     .byt <10000,<1000,<100,<10,<1
dhi     .byt >10000,>1000,>100,>10,>1

t_log   .asc "LOG"
t_bak   .asc "BAK"

#include "logotr.msg"           ; messages (progs/msg/fr, en)
#include "lgtr_tab.s"         ; vocabulaires numérotés (tools/gen_logo_voc.py)

wbuf    .dsb 32,0
pend    .dsb MAXLEV+1,0         ; par niveau : listes de code attendues
code    .dsb MAXLEV+1,0         ;   1 : niveau de code (0 : données)
obuf    .word 0
sfcb    .dsb 36,0
dfcb    .dsb 36,0
tfcb    .dsb 36,0
rfcb    .dsb 36,0
rbak    = rfcb+16       ; nouveau nom d'un renommage
buf
