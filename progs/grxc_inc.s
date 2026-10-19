;  GRXC_INC.S — GRAPHER et GRXASM : routines communes
;  Lecture du .GRX et des lignes, paramètres $1-$9, mots et table des
;  commandes, analyse des noms, des nombres et des fonctions, calculs
;  sur des constantes, sous-programmes, erreurs et sorties console.
;  Inclus par progs/grapher.s (interpréteur) et progs/grxasm.s
;  (traducteur), jamais assemblé seul. Chaque programme fournit :
;    cadr          adresses des commandes (même ordre que cmds)
;    x_asg, x_aasg affectation d'une variable, d'un élément de tableau
;    an_val        ANIM : nombre de passages présent ; an_none : absent
;    ndim_s        dimensions d'un tableau $ ; to_text ; o_drop
;    ptext, lbuf, rawbuf et les tampons (sfcb, ifcb, word...)

; ---------------------------------------------------------------------
; Chargement du fichier : ptext, terminé par 0 (au premier ^Z)
; (TAB, 9, remplacé par un espace : l'Oric n'a pas de tabulation)
; ---------------------------------------------------------------------
load_text
.(
        lda #<ptext
        sta pe
        lda #>ptext
        sta pe+1
lrd     lda pe+1                ; place pour un enregistrement ?
        cmp #>(PTOP-128)
        bcc ok
        lda #0
        sta word
        lda #<m_big
        ldy #>m_big
        jmp stop_msg
ok      ldx #F_SETDMA
        lda pe
        ldy pe+1
        jsr BDOS
        ldx #F_READ
        lda #<sfcb
        ldy #>sfcb
        jsr BDOS
        cmp #0
        bne eof
        clc
        lda pe
        adc #128
        sta pe
        bcc lrd
        inc pe+1
        jmp lrd
eof     ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        ldy #0
        tya
        sta (pe),y
        lda #<ptext             ; le premier ^Z termine le texte ;
        sta sk                  ; une tabulation devient un espace
        lda #>ptext
        sta sk+1
z       lda (sk),y
        beq r
        cmp #$1A
        beq end
        cmp #9
        bne zn
        lda #" "
        sta (sk),y
zn      inc sk
        bne z
        inc sk+1
        bne z
end     tya
        sta (sk),y
r       rts
.)

; ---------------------------------------------------------------------
; Lignes du texte
; ---------------------------------------------------------------------
; nextl : sk -> début de la ligne suivante (reste sur le 0 final)
nextl
.(
        ldy #0
loop    lda (sk),y
        beq r
        cmp #CR
        beq cr
        cmp #LF
        beq lf
        inc sk
        bne loop
        inc sk+1
        jmp loop
cr      jsr inc_sk
        lda (sk),y
        cmp #LF
        bne r
lf      jsr inc_sk
r       rts
.)

inc_sk  inc sk
        bne isk
        inc sk+1
isk     rts

; read_line : ligne cur -> rawbuf, puis lbuf avec $1-$9 remplacés ; nxt
read_line
.(
        lda #0
        sta word
        ldy #0
loop    lda (cur),y
        beq eol
        cmp #CR
        beq eol
        cmp #LF
        beq eol
        cpy #LMAX
        bcs long
        sta rawbuf,y
        iny
        bne loop
long    lda #<m_long
        ldy #>m_long
        jmp error
eol     lda #0
        sta rawbuf,y
        lda cur
        sta sk
        lda cur+1
        sta sk+1
        jsr nextl
        lda sk
        sta nxt
        lda sk+1
        sta nxt+1
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
        rts
.)

; get_params : $1-$9 dans la ligne de commande (casse d'origine) : après
;   le nom du programme et celui du fichier
get_params
.(
        ldx #0
        jsr skipw               ; GRAPHER
        jsr skipw               ; NOM
        jsr sksp                ; /A : traduction (cmode 1) ;
        lda ORIG_LINE,x         ; /C : traduction et ASM (cmode 2)
        cmp #"/"
        bne par
        lda ORIG_LINE+2,x
        beq opt0
        cmp #" "
        bne par
opt0    lda ORIG_LINE+1,x
        and #$DF
        cmp #"A"
        beq opt
        cmp #"C"
        bne par
        inc cmode
opt     inx
        inx
        inc cmode
par     ldy #0
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
; Mots et table des commandes
; ---------------------------------------------------------------------
; isalpha : C=0 si A est une lettre (A est mis en majuscule)
isalpha
.(
        cmp #"a"
        bcc up
        cmp #"z"+1
        bcs up
        and #$DF
up      cmp #"A"
        bcc no
        cmp #"Z"+1
        bcs no
        clc
        rts
no      sec
        rts
.)

; lookup : kw (terminé par 0) dans la table -> C=0, tbl = entrée,
;   Y = position de la classe ; C=1 si inconnu
lookup
.(
        lda #<cmds
        sta tbl
        lda #>cmds
        sta tbl+1
        lda #$FF
        sta cnum
look    inc cnum
        ldy #0
        lda (tbl),y
        beq no
cmpc    lda (tbl),y
        and #$7F
        cmp kw,y
        bne skip
        lda (tbl),y
        bmi found
        iny
        bne cmpc
found   lda kw+1,y              ; le mot doit finir là
        bne skip0
        iny
        clc
        rts
skip0   ldy #0
skip    lda (tbl),y             ; entrée suivante
        bmi sk1
        iny
        bne skip
sk1     tya
        clc
        adc #2                  ; dernière lettre, classe
        adc tbl
        sta tbl
        bcc look
        inc tbl+1
        bne look
no      sec
        rts
.)

; classify : classe de la ligne sk (0 : autre), sk passe à la suivante
classify
.(
        ldy #0
sp      lda (sk),y
        cmp #" "
        bne w0
        iny
        bne sp
w0      ldx #0
w       lda (sk),y
        jsr isalpha
        bcs wend
        cpx #8
        bcs other
        sta kw,x
        inx
        iny
        bne w
wend    cpx #0
        beq other
        lda #0
        sta kw,x
        jsr lookup
        bcs other
        lda (tbl),y
        pha
        jsr nextl
        pla
        rts
other   jsr nextl
        lda #0
        rts
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
        ldy #0                  ; mot de commande (lettres), en majuscules
w       lda lbuf,x
        jsr isalpha
        bcs wend
        cpy #8
        bcs bad
        sta word,y
        sta kw,y
        iny
        inx
        bne w
wend    lda #0
        sta word,y
        sta kw,y
        cpy #0
        beq bad
        stx lx
        cpy #3                  ; une ou deux lettres : variable ?
        bcs cmd
        txa                     ; ex = début du nom
        sty ex
        sec
        sbc ex
        sta ex
        cpy #1
        bne two
        lda lbuf,x              ; une lettre puis ( ou $ : un tableau
        cmp #"("
        beq kar
        cmp #"$"
        beq kar
        bne asg
two     jsr lookup              ; IF
        bcc found
asg     ldx ex
        jsr getvar
        jsr skipsp
        cmp #"="
        bne cmd
        jmp x_asg               ; affectation (propre à chaque programme) :
                                ;   vix, vc, X sur le « = »
kar     jmp x_aasg
cmd     jsr lookup
        bcs bad
found
        lda cnum                ; adresse : table cadr du programme
        asl
        tay
        lda cadr,y
        sta lp
        lda cadr+1,y
        sta lp+1
        ldx lx
        jmp (lp)
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


; getvar : variable en lbuf, X -> vix, vc ; X après elle. Une lettre,
;   suivie ou non d'une lettre ou d'un chiffre (A, AX, A1) ; IF est
;   réservé
getvar
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sec
        sbc #"A"
        sta vix
        lda #0
        sta vc
        inx
        lda lbuf,x
        jsr isalpha
        bcs dig
        sbc #"A"-2              ; (C=0) lettre : 1-26
        sta vc
        jsr not_if
        jmp nx
dig     jsr isdig
        bcs end
        sbc #"0"-28             ; (C=0) chiffre : 27-36
        sta vc
nx      inx
end     lda lbuf,x              ; rien d'autre collé au nom
        jsr isalpha
        bcc bad
        jsr isdig
        bcc bad
        rts
bad     jmp v_bad
.)
v_bad   lda #<m_var
        ldy #>m_var
        jmp error

; isdig : C=0 si A est un chiffre
isdig   cmp #"0"
        bcc nd
        cmp #"9"+1
        bcs nd
        clc
        rts
nd      sec
        rts

; not_if : erreur si la variable vix, vc est IF (mot réservé)
not_if  lda vix
        cmp #"I"-"A"
        bne ni
        lda vc
        cmp #"F"-"A"+1
        beq v_bad
ni      rts

; kw_var : variable lue par parse_id (kw, X = 1 ou 2 lettres), suivie en
;   ex d'un chiffre ou non -> vix, vc ; ex après elle
kw_var
.(
        lda kw
        sec
        sbc #"A"
        sta vix
        lda #0
        sta vc
        cpx #1
        beq one
        lda kw+1
        sec
        sbc #"A"-1              ; lettre : 1-26
        sta vc
        jsr not_if
        jmp chk
one     jsr gch
        jsr isdig
        bcs chk
        sbc #"0"-28             ; (C=0) chiffre : 27-36
        sta vc
        inc ex
chk     jsr gch                 ; ni ( ni $ ni chiffre collé au nom
        cmp #"("
        beq bad
        cmp #"$"
        beq bad
        jsr isdig
        bcc bad
        rts
bad     jmp e_expr
.)

e_expr  lda #<m_expr
        ldy #>m_expr
        jmp error

; gch : A = lbuf[ex] ; ws : espaces sautés si edep > 0
gch     ldy ex
        lda lbuf,y
        rts
ws
.(
        lda edep
        beq r
loop    jsr gch
        cmp #" "
        bne r
        inc ex
        bne loop
r       rts
.)

; relop : opérateur de comparaison en ex ? -> C=0, A = $81 à $86
;   (= <> < <= > >=) et ex après lui ; C=1 sinon
relop
.(
        jsr ws
        jsr gch
        ldx #1
        cmp #"="
        beq one
        cmp #"<"
        beq lt
        cmp #">"
        beq rgt
        sec
        rts
lt      inc ex
        jsr gch
        ldx #2
        cmp #">"
        beq one
        ldx #4
        cmp #"="
        beq one
        ldx #3
        bne go
rgt     inc ex
        jsr gch
        ldx #6
        cmp #"="
        beq one
        ldx #5
        bne go
one     inc ex
go      txa
        ora #$80
        clc
        rts
.)

; binop : ev <- et (op A) ev ; A = + - * / % & | ou $81-$86 (comparaisons)
binop
.(
        cmp #$80
        bcs b_cmp
        cmp #"+"
        beq b_add
        cmp #"-"
        beq b_sub
        cmp #"*"
        beq b_mul
        cmp #"&"
        beq b_and
        cmp #"|"
        beq b_or
        pha                     ; / %
        jsr sdiv
        pla
        cmp #"/"
        beq r
        lda mr
        sta ev
        lda mr+1
        sta ev+1
r       rts
b_mul   jmp mul16
b_cmp   and #$7F
        tax
        jmp cmpval
b_add   clc
        lda et
        adc ev
        sta ev
        lda et+1
        adc ev+1
        sta ev+1
        rts
b_sub   sec
        lda et
        sbc ev
        sta ev
        lda et+1
        sbc ev+1
        sta ev+1
        rts
b_and   lda et
        and ev
        sta ev
        lda et+1
        and ev+1
        sta ev+1
        rts
b_or    lda et
        ora ev
        sta ev
        lda et+1
        ora ev+1
        sta ev+1
        rts
.)

; cmpval : X = 1 =, 2 <>, 3 <, 4 <=, 5 >, 6 >= ; ev <- (et ? ev), 1 ou 0
cmpval
.(
        sec                     ; et - ev, signé
        lda et
        sbc ev
        sta mt
        lda et+1
        sbc ev+1
        sta mt+1
        ora mt                  ; (ORA et LDA laissent V)
        sta mt                  ; mt = 0 si égaux
        lda mt+1
        bvc nv
        eor #$80
nv      and #$80
        sta mt+1                ; $80 si et < ev
        lda #0
        sta ev+1
        cpx #1
        beq c_eq
        cpx #2
        beq c_ne
        cpx #3
        beq c_lt
        cpx #4
        beq c_le
        cpx #5
        beq c_gt
        lda mt+1                ; >= : pas <
        beq yes
        bne no
c_eq    lda mt
        beq yes
        bne no
c_ne    lda mt
        bne yes
        beq no
c_lt    lda mt+1
        bne yes
        beq no
c_le    lda mt+1
        bne yes
        lda mt
        beq yes
        bne no
c_gt    lda mt+1
        bne no
        lda mt
        bne yes
no      lda #0
        sta ev
        rts
yes     lda #1
        sta ev
        rts
.)
neg_ev  sec
        lda #0
        sbc ev
        sta ev
        lda #0
        sbc ev+1
        sta ev+1
        rts

; parse_num : nombre décimal en ex -> ev (32767 au plus)
parse_num
.(
        lda #0
        sta ev
        sta ev+1
num     jsr gch
        sec
        sbc #"0"
        cmp #10
        bcs nend
        pha
        lda ev+1                ; 3328 * 10 et plus : trop grand
        cmp #$0D
        bcs big0
        lda ev                  ; ev * 10
        sta et
        lda ev+1
        sta et+1
        asl ev
        rol ev+1
        asl ev
        rol ev+1
        clc
        lda ev
        adc et
        sta ev
        lda ev+1
        adc et+1
        sta ev+1
        asl ev
        rol ev+1
        pla
        clc
        adc ev
        sta ev
        bcc n1
        inc ev+1
n1      lda ev+1                ; 32767 au plus
        bmi big
        inc ex
        jmp num
nend    rts
big0    pla
big     jmp e_expr
.)

; parse_id : nom en ex (lettres, 6 au plus) -> kw, X = longueur
parse_id
.(
        ldx #0
idl     jsr gch
        jsr isalpha
        bcs idend
        cpx #6
        bcs bad
        sta kw,x
        inx
        inc ex
        bne idl
idend   cpx #0
        beq bad
        lda #0
        sta kw,x
        rts
bad     jmp e_expr
.)

; find_fn : kw parmi les fonctions -> A = numéro (0 RND, 1 ABS, 2 POINT,
;   3 INKEY) ; erreur sinon
find_fn
.(
        ldy #0
fl      ldx #0
fc      lda fnames,y
        beq bad
        cmp kw,x
        bne fskip
        iny
        inx
        lda kw,x
        bne fc
        lda fnames,y            ; même longueur ?
        cmp #" "
        bne fskip
        lda fnames+1,y
        rts
fskip   lda fnames,y            ; nom suivant
        iny
        cmp #" "
        bne fskip
        iny
        jmp fl
bad     jmp e_expr
.)

; x_open / x_close / x_comma : ( ) , attendus en ex
x_open  jsr ws
        jsr gch
        cmp #"("
        bne x_bad
        inc ex
        inc edep
        rts
x_close jsr ws
        jsr gch
        cmp #")"
        bne x_bad
        inc ex
        dec edep
        rts
x_comma jsr ws
        jsr gch
        cmp #","
        bne x_bad
        inc ex
        rts
x_bad   jmp e_expr

fnames  .asc "RND ",0,"ABS ",1,"POINT ",2,"INKEY ",3,"SCRN ",4,"LEN ",5,"FOUND ",6,"TILE ",7,0

; mul16 : ev <- et * ev (16 bits bas)
mul16
.(
        lda #0
        sta mt
        sta mt+1
        ldx #16
loop    lsr ev+1
        ror ev
        bcc no
        clc
        lda mt
        adc et
        sta mt
        lda mt+1
        adc et+1
        sta mt+1
no      asl et
        rol et+1
        dex
        bne loop
        lda mt
        sta ev
        lda mt+1
        sta ev+1
        rts
.)

; udiv : et / ev (non signés) -> et quotient, mr reste
udiv
.(
        lda #0
        sta mr
        sta mr+1
        ldx #16
loop    asl et
        rol et+1
        rol mr
        rol mr+1
        sec
        lda mr
        sbc ev
        tay
        lda mr+1
        sbc ev+1
        bcc no
        sta mr+1
        sty mr
        inc et
no      dex
        bne loop
        rts
.)

; sdiv : et / ev signés -> ev quotient, mr reste (signe du dividende)
sdiv
.(
        lda ev
        ora ev+1
        bne ok
        lda #<m_div
        ldy #>m_div
        jmp error
ok      lda et+1
        sta msg_s               ; bit 7 : signe du dividende
        eor ev+1
        sta msg_s+1             ; bit 7 : signe du quotient
        lda et+1
        bpl p1
        sec
        lda #0
        sbc et
        sta et
        lda #0
        sbc et+1
        sta et+1
p1      lda ev+1
        bpl sp2
        jsr neg_ev
sp2     jsr udiv
        lda et
        sta ev
        lda et+1
        sta ev+1
        bit msg_s+1
        bpl p3
        jsr neg_ev
p3      bit msg_s
        bpl r
        sec
        lda #0
        sbc mr
        sta mr
        lda #0
        sbc mr+1
        sta mr+1
r       rts
.)

; animarg : nom (type ANI par défaut) -> ifcb, passages -> gd ; pour
;   la traduction, le code des passages est écrit (A à l'exécution)
animarg
.(
        jsr getnm
        lda ifcb+9
        cmp #" "
        bne ty
        ldy #2
tc      lda t_ani,y
        sta ifcb+9,y
        dey
        bpl tc
ty      lda #0
        sta gd
        jsr skipsp
        beq none
        cmp #";"
        beq none
        jmp an_val              ; passages (propre à chaque programme)
none    jmp an_none
.)

; getname : [d:]nom[.ext] de lbuf (X) -> ifcb ; erreur s'il manque ;
;   rien d'autre ensuite (getnm : X après le nom, la suite est permise)
getname jsr getnm
        jmp endline
getnm
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
        rts
bad     jmp e_param
.)

upc     cmp #"a"
        bcc upr
        cmp #"z"+1
        bcs upr
        and #$DF
upr     rts

; is_str : une chaîne en ex ? (texte entre guillemets, A$, ou M$(i) d'un
;   tableau à deux dimensions) -> C=0 ; C=1 sinon ; ex ne bouge pas
is_str
.(
        jsr ws
        jsr gch
        cmp #34
        beq yes
        jsr isalpha
        bcs no
        sta gd
        iny
        lda lbuf,y
        cmp #"$"
        bne no
        iny
        lda lbuf,y
        cmp #"("
        bne yes                 ; A$ sans indice
        ldx #0                  ; M$(...) : une virgule au premier niveau
s       iny                     ;   -> un élément
        lda lbuf,y
        beq no
        cmp #"("
        bne s1
        inx
        bne s
s1      cmp #")"
        bne s2
        dex
        bmi e
        jmp s
s2      cmp #","
        bne s
        cpx #0
        bne s
        beq no
e       lda gd                  ; un seul indice : une ligne si le
        jsr ndim_s              ;   tableau a deux dimensions
        cmp #2
        bne no
yes     clc
        rts
no      sec
        rts
.)

; str_only : la chaîne en ex va-t-elle jusqu'au bout de la ligne ? (PRINT
;   A$ affiche la chaîne, PRINT A$ = B$ la comparaison) -> C=0 si oui
str_only
.(
        ldy ex
        lda lbuf,y
        cmp #34
        bne v
q       iny                     ; texte : jusqu'au guillemet final
        lda lbuf,y
        beq no
        cmp #34
        bne q
        iny
        jmp e
v       iny                     ; lettre, $, puis (...) éventuel
        iny
        lda lbuf,y
        cmp #"("
        bne e
        ldx #0
p       iny
        lda lbuf,y
        beq no
        cmp #"("
        bne p1
        inx
        bne p
p1      cmp #")"
        bne p
        dex
        bpl p
        iny
e       lda lbuf,y              ; ensuite : rien (ou un commentaire)
        beq yes
        cmp #";"
        beq yes
        cmp #" "
        bne no
        iny
        bne e
no      sec
        rts
yes     clc
        rts
.)

e_strc  lda #<m_strc
        ldy #>m_strc
        jmp error
; aeq : « = » attendu en ex -> X après lui (espaces permis)
aeq
.(
        lda #1
        sta edep
        jsr ws
        jsr gch
        cmp #"="
        bne bad
        inc ex
        ldx ex
        rts
bad     jmp e_param
.)

; cs_push : nouvelle entrée de type A -> Y = son numéro
cs_push
.(
        ldy csp
        cpy #NCS
        bcs deep
        sta cs_t,y
        inc csp
        rts
deep    lda #<m_deep
        ldy #>m_deep
        jmp error
.)

; getsub : nom (lettres, chiffres, 8 au plus) en lbuf (X) -> cname
getsub
.(
        jsr skipsp
        ldy #0
n       lda lbuf,x
        jsr isalpha
        bcc ok
        cmp #"0"
        bcc nend
        cmp #"9"+1
        bcs nend
ok      cpy #8
        bcs nend
        sta cname,y
        iny
        inx
        bne n
nend    cpy #0
        beq bad
        lda #0
        sta cname,y
        rts
bad     jmp e_param
.)

; sub_find : nom en lbuf (X) ; sk <- ligne qui suit « SUB NOM »
sub_find
.(
        jsr getsub
        jsr endline
        lda #<ptext
        sta sk
        lda #>ptext
        sta sk+1
line    ldy #0
        lda (sk),y
        beq unk
        lda sk                  ; début de la ligne
        sta lp
        lda sk+1
        sta lp+1
        jsr classify            ; sk passe à la ligne suivante
        cmp #K_SUB
        bne line
        ldy #0                  ; après SUB : le nom
s1      lda (lp),y
        cmp #" "
        bne s2
        iny
        bne s1
s2      iny                     ; S U B
        iny
        iny
s3      lda (lp),y
        cmp #" "
        bne s4
        iny
        bne s3
s4      ldx #0
cmpn    lda (lp),y
        jsr isalpha
        bcc cc1
        cmp #"0"
        bcc cend
        cmp #"9"+1
        bcs cend
cc1     cmp cname,x
        bne line
        iny
        inx
        bne cmpn
cend    lda cname,x
        bne line
        rts
unk     lda #<m_nosub
        ldy #>m_nosub
        jmp error
.)

; fmtnum : ev (signé) -> numbuf, chaîne décimale terminée par 0
fmtnum
.(
        ldy #0
        lda ev+1
        bpl pos
        jsr neg_ev
        lda #"-"
        sta numbuf
        iny
pos     sty gd
        lda #0
        sta lx                  ; un chiffre écrit
        ldx #0
dig     ldy #0
sub     sec
        lda ev
        sbc d_lo,x
        pha
        lda ev+1
        sbc d_hi,x
        bcc dn
        sta ev+1
        pla
        sta ev
        iny
        bne sub
dn      pla
        tya
        bne show
        lda lx
        beq nx
        tya
show    ora #"0"
        ldy gd
        sta numbuf,y
        inc gd
        sta lx
nx      inx
        cpx #4
        bne dig
        lda ev
        ora #"0"
        ldy gd
        sta numbuf,y
        iny
        lda #0
        sta numbuf,y
        rts
.)
d_lo    .byt <10000,<1000,<100,<10
d_hi    .byt >10000,>1000,>100,>10

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
quit    jsr o_drop
        ldx sav_sp
        txs
        rts

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

; put_lnum : numéro de la ligne en cours (compté depuis le début)
put_lnum
.(
        lda #<ptext
        sta sk
        lda #>ptext
        sta sk+1
        lda #1
        sta ev
        lda #0
        sta ev+1
loop    lda sk+1                ; tant que sk < cur
        cmp cur+1
        bcc adv
        bne done
        lda sk
        cmp cur
        bcs done
adv     ldy #0
        lda (sk),y
        beq done
        jsr nextl
        inc ev
        bne loop
        inc ev+1
        jmp loop
done    jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jmp puts
.)

t_grx   .asc "GRX"
t_ani   .asc "ANI"
m_nogrx .asc "Fichier introuvable",13,10,"$"
m_unk   .asc "commande inconnue",0
m_param .asc "parametres ?",0
m_long  .asc "ligne de plus de 126 car.",0
m_full  .asc "disque plein",0
m_esc   .asc "Interrompu",0
m_big   .asc "Fichier trop gros",0
m_expr  .asc "expression ?",0
m_range .asc "valeur hors de 0-255",0
m_var   .asc "variable ? (A, AB ou A1)",0
m_div   .asc "division par zero",0
m_deep  .asc "trop de blocs imbriques",0
m_step  .asc "pas nul",0
m_nofor .asc "NEXT sans boucle",0
m_open  .asc "bloc non ferme",0
m_struct .asc "fin de bloc en trop",0
m_noret .asc "RETURN sans CALL",0
m_nosub .asc "SUB introuvable",0
m_strc  .asc "chaine dans un calcul",0

; desc_of : A = lettre, X = 0 (entiers) ou 1 ($) -> A/Y = descripteur
desc_of
.(
        sec
        sbc #"A"
        asl
        asl
        asl
        ldy #0
        cpx #0
        beq da
        clc
        adc #208
        bcc da
        iny
da      clc
        adc #<R_DESC
        pha
        tya
        adc #>R_DESC
        tay
        pla
        rts
.)

; ---------------------------------------------------------------------
; f_arg : SAVE, LOAD, BSAVE, BLOAD : tableau (lettre, $ facultatif) ou
;   SCREEN, suivi d'un espace (lbuf, X) -> aal, aak (0 entiers, 1 $,
;   2 SCREEN) ; X sur l'espace
; ---------------------------------------------------------------------
f_arg
.(
        jsr skipsp
        stx gd
        ldy #0
s       lda lbuf,x
        and #$DF
        cmp t_scr,y
        bne ar
        inx
        iny
        cpy #6
        bne s
        lda #2
        bne k
ar      ldx gd
        lda lbuf,x
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda lbuf,x
        cmp #"$"
        bne k0
        inx
        lda #1
        .byt $2C                ; (BIT abs : saute lda #0)
k0      lda #0
k       sta aak
        lda lbuf,x
        cmp #" "
        bne bad
        rts
bad     jmp e_param
.)
t_scr   .asc "SCREEN"

; ---------------------------------------------------------------------
; Sprites : arguments de SPOOL et SSHOW
; ---------------------------------------------------------------------
; intarg : tableau d'entiers (une lettre) en lbuf (X) -> aal ; X après
intarg
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda lbuf,x
        beq ok
        cmp #" "
        beq ok
        cmp #";"
        bne bad
ok      rts
bad     jmp e_param
.)

; sprarg : tableau $ (lettre, $) suivi d'un espace -> aal
sprarg
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda lbuf,x
        cmp #"$"
        bne bad
        inx
        lda lbuf,x
        cmp #" "
        bne bad
        rts
bad     jmp e_param
.)

; altopt : « ALT » facultatif, puis fin de ligne -> A = 1 (jeu
;   secondaire), 0 sinon
altopt
.(
        jsr skipsp
        beq no
        cmp #";"
        beq no
        ldy #0
l       lda lbuf,x
        and #$DF
        cmp t_alt,y
        bne bad
        inx
        iny
        cpy #3
        bne l
        jsr endline
        lda #1
        rts
no      lda #0
        rts
bad     jmp e_param
.)
t_alt   .asc "ALT"

; ---------------------------------------------------------------------
; open_grx : FCB1 -> sfcb (type GRX par défaut), fichier ouvert ; s'il
;   est absent : message, puis fin du programme
; ---------------------------------------------------------------------
open_grx
.(
        ldx #11
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
        bne r
        ldx #F_PRINT
        lda #<m_nogrx
        ldy #>m_nogrx
        jsr BDOS
        jmp quit
r       rts
.)

; ---------------------------------------------------------------------
; Table des commandes : nom (dernière lettre avec le bit 7) et classe ;
; les plus fréquentes d'abord (la recherche est séquentielle). L'adresse
; de la commande n est le mot n de la table cadr de chaque programme
; (exécution dans grapher.s, traduction dans grxasm.s) : même ordre.
; ---------------------------------------------------------------------
cmds
        .asc "NEX"
        .byt "T"|$80,K_NEXT
        .asc "I"
        .byt "F"|$80,K_IF
        .asc "ENDI"
        .byt "F"|$80,K_ENDIF
        .asc "ELS"
        .byt "E"|$80,K_ELSE
        .asc "LOCAT"
        .byt "E"|$80,0
        .asc "CHA"
        .byt "R"|$80,0
        .asc "SSHO"
        .byt "W"|$80,0
        .asc "SHID"
        .byt "E"|$80,0
        .asc "PLO"
        .byt "T"|$80,0
        .asc "LIN"
        .byt "E"|$80,0
        .asc "LE"
        .byt "T"|$80,0
        .asc "FO"
        .byt "R"|$80,K_LOOP
        .asc "REPEA"
        .byt "T"|$80,K_LOOP
        .asc "WHIL"
        .byt "E"|$80,K_LOOP
        .asc "CAL"
        .byt "L"|$80,0
        .asc "ENDSU"
        .byt "B"|$80,K_ENDS
        .asc "RETUR"
        .byt "N"|$80,0
        .asc "SU"
        .byt "B"|$80,K_SUB
        .asc "BO"
        .byt "X"|$80,0
        .asc "FBO"
        .byt "X"|$80,0
        .asc "CIRCL"
        .byt "E"|$80,0
        .asc "PE"
        .byt "N"|$80,0
        .asc "GTEX"
        .byt "T"|$80,0
        .asc "GNU"
        .byt "M"|$80,0
        .asc "ATT"
        .byt "R"|$80,0
        .asc "GCL"
        .byt "S"|$80,0
        .asc "PRIN"
        .byt "T"|$80,0
        .asc "DELA"
        .byt "Y"|$80,0
        .asc "WAI"
        .byt "T"|$80,0
        .asc "ECH"
        .byt "O"|$80,0
        .asc "HIRE"
        .byt "S"|$80,0
        .asc "SPLI"
        .byt "T"|$80,0
        .asc "TEX"
        .byt "T"|$80,0
        .asc "GLOA"
        .byt "D"|$80,0
        .asc "ANI"
        .byt "M"|$80,0
        .asc "GSAV"
        .byt "E"|$80,0
        .asc "EN"
        .byt "D"|$80,0
        .asc "SP"
        .byt "C"|$80,0
        .asc "TA"
        .byt "B"|$80,0
        .asc "GE"
        .byt "T"|$80,0
        .asc "CL"
        .byt "S"|$80,0
        .asc "LORE"
        .byt "S"|$80,0
        .asc "DI"
        .byt "M"|$80,0
        .asc "FIL"
        .byt "L"|$80,0
        .asc "INPU"
        .byt "T"|$80,0
        .asc "SAV"
        .byt "E"|$80,0
        .asc "LOA"
        .byt "D"|$80,0
        .asc "BSAV"
        .byt "E"|$80,0
        .asc "BLOA"
        .byt "D"|$80,0
        .asc "SPRITE"
        .byt "S"|$80,0
        .asc "SPOO"
        .byt "L"|$80,0
        .asc "PAST"
        .byt "E"|$80,0
        .asc "GRA"
        .byt "B"|$80,0
        .asc "SCROL"
        .byt "H"|$80,0
        .asc "SCROL"
        .byt "V"|$80,0
        .asc "ROT"
        .byt "H"|$80,0
        .asc "ROT"
        .byt "V"|$80,0
        .asc "PRINT"
        .byt "V"|$80,0
        .asc "ECHO"
        .byt "V"|$80,0
        .asc "SPC"
        .byt "V"|$80,0
        .asc "TILESE"
        .byt "T"|$80,0
        .asc "TMA"
        .byt "P"|$80,0
        .asc "TFON"
        .byt "T"|$80,0
        .byt 0
