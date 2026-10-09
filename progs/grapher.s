; =====================================================================
;  GRAPHER.COM — exécute un fichier de commandes graphiques (.GRX)
;
;  GRAPHER NOM [p1 ... p9]
;    NOM.GRX (lecteur facultatif), chargé en mémoire puis exécuté : une
;    commande par ligne, en anglais ; « ; » commence un commentaire ;
;    $1 à $9 sont remplacés par les paramètres (casse d'origine).
;
;  Nombres : entiers de -32768 à 32767 ; variables A à Z (0 au départ).
;  Un paramètre est une expression : 12, X, X+8, (X * 2), RND(240)...
;  Entre plusieurs paramètres l'espace sépare : pas d'espace dans une
;  expression, sauf entre parenthèses. Une expression seule en fin de
;  ligne (LET, IF, WHILE, PRINT) peut contenir des espaces.
;  Opérateurs, du plus fort au plus faible : - (signe) ; * / % ; + - ;
;  = <> < <= > >= (1 si vrai, 0 sinon) ; & | (bit à bit).
;  Fonctions : RND(n) (0 à n-1), ABS(n), POINT(x,y) (1 si allumé),
;  INKEY (touche tapée, 0 si aucune ; n'attend pas).
;
;  Modes      HIRES, SPLIT, TEXT
;  Image      GCLS, PEN m, PLOT x y, LINE x1 y1 x2 y2, BOX / FBOX x1 y1
;             x2 y2, CIRCLE x y r, GTEXT col y texte, GNUM col y n,
;             ATTR col y1 y2 v, GLOAD nom, GSAVE nom   (valeurs 0-255)
;  Calcul     LET V = expr  (ou V = expr)
;  Contrôle   REPEAT n ... NEXT
;             FOR V a b [pas] ... NEXT
;             WHILE expr ... NEXT
;             IF expr ... [ELSE ...] ENDIF
;             SUB NOM ... ENDSUB (RETURN : sortie avant la fin), CALL NOM
;  Divers     WAIT, DELAY n (1/50 s), ECHO texte, PRINT expr, END
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
NCS     = 16            ; profondeur de la pile de contrôle
NVS     = 24            ; pile des valeurs de l'évaluateur
PTOP    = $9F00         ; le texte du fichier reste sous l'image HIRES

; types de la pile de contrôle
T_REP   = 1
T_FOR   = 2
T_WHILE = 3
T_CALL  = 4
T_IF    = 5             ; (traduction seulement)
T_SUB   = 6

; classes des commandes (pour sauter un bloc)
K_LOOP  = 1             ; REPEAT FOR WHILE
K_NEXT  = 2
K_IF    = 3
K_ELSE  = 4
K_ENDIF = 5
K_SUB   = 6
K_ENDS  = 7             ; ENDSUB

lp      = $10           ; pointeur de travail
lx      = $12           ; position dans lbuf
cur     = $13           ; ligne en cours (adresse dans le texte)
nxt     = $15           ; ligne suivante (une boucle la change)
sk      = $17           ; parcours du texte
gv      = $19           ; valeur de travail (2 octets)
gd      = $1B
tbl     = $1C           ; table des commandes (2 octets)
sav_sp  = $1E
pkey    = $1F           ; touche lue entre deux lignes (0 : aucune)
ev      = $20           ; valeur de l'expression (2 octets)
et      = $22           ; opérande de gauche (2 octets)
ex      = $24           ; position dans lbuf pendant une expression
edep    = $25           ; > 0 : les espaces sont permis
csp     = $26           ; pile de contrôle : nombre d'entrées
sdep    = $27           ; profondeur des blocs sautés
smask   = $28           ; classes qui terminent le saut
mt      = $29           ; multiplication / comparaison (2 octets)
mr      = $2B           ; reste (2 octets)
msg_s   = $2D           ; signes de la division (2 octets)
rnd     = $2F           ; générateur pseudo-aléatoire (2 octets)
vix     = $31           ; variable (0-25)
vsp     = $32           ; pile des valeurs
pe      = $33           ; fin du texte chargé (2 octets)
; traduction (/A)
ostr    = $35           ; texte à écrire (2 octets)
kc      = $37           ; 1 : l'expression est la constante kv
kv      = $38           ; (2 octets)
oidx    = $3A           ; position dans obuf
kn      = $3B           ; blocs numérotés (2 octets)
kl      = $3D           ; bloc en cours (2 octets)
ksuf    = $3F           ; suffixe d'étiquette (T, E, X)
cmode   = $40           ; 1 : traduction en assembleur
oopen   = $41           ; 1 : NOM.ASM ouvert
klf     = $42           ; gauche d'une opération : constante ?
lv      = $43           ;   sa valeur (2 octets)
kop     = $45
ksym    = $46           ; destination (3 octets)
koff    = $49
kvar    = $4A
osx     = $4B
osy     = $4C
osv     = $4D
kin     = $4E
kst     = $4F
osa     = $50           ; instruction à écrire (2 octets)

        *= $0500

        tsx
        stx sav_sp
        lda SYS_TICKS           ; graine du hasard
        sta rnd
        lda SYS_TICKS+1
        ora #1
        sta rnd+1
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
opened  jsr load_text
        lda #0
        sta cmode
        sta oopen
        jsr get_params
        lda #0
        sta pkey
        sta csp
        sta word
        ldx #51                 ; variables à 0
z1      sta vars,x
        dex
        bpl z1
        lda #<ptext
        sta cur
        lda #>ptext
        sta cur+1
        lda cmode               ; /A : traduction en assembleur
        beq next
        jmp compile

; ---------------------------------------------------------------------
; Boucle : une ligne, puis sa commande
; ---------------------------------------------------------------------
next    jsr B_CONST             ; ESC : arrêt ; une autre touche est
        beq rd                  ; gardée pour WAIT, INKEY ou la fin
        jsr h_key
        sta pkey
        cmp #27
        bne rd
        lda #<m_esc
        ldy #>m_esc
        jmp stop_msg
rd      ldy #0
        lda (cur),y
        beq eot
        jsr read_line
        jsr exec
        lda nxt
        sta cur
        lda nxt+1
        sta cur+1
        jmp next
eot     lda csp                 ; fin du texte dans une boucle
        beq finish
        lda #0
        sta word
        lda #<m_nonext
        ldy #>m_nonext
        jmp error

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
; Chargement du fichier : ptext, terminé par 0 (au premier ^Z)
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
        lda #<ptext             ; le premier ^Z termine le texte
        sta sk
        lda #>ptext
        sta sk+1
z       lda (sk),y
        beq r
        cmp #$1A
        beq end
        inc sk
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
        jsr sksp                ; /A : traduction
        lda ORIG_LINE,x
        cmp #"/"
        bne par
        lda ORIG_LINE+1,x
        and #$DF
        cmp #"A"
        bne par
        lda ORIG_LINE+2,x
        beq opt
        cmp #" "
        bne par
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
look    ldy #0
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
        adc #6                  ; dernière lettre, classe, deux adresses
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

; skip_to : saute jusqu'à la ligne qui ferme le bloc (classes de smask,
;   au même niveau), à partir de nxt ; nxt = ligne qui la suit
skip_to
.(
        sta smask
        lda nxt
        sta sk
        lda nxt+1
        sta sk+1
        lda #0
        sta sdep
loop    ldy #0
        lda (sk),y
        beq open
        jsr classify
        tax
        lda sdep
        bne nested
        lda bits,x              ; au niveau 0 : fin du saut ?
        and smask
        beq nested
        lda sk
        sta nxt
        lda sk+1
        sta nxt+1
        rts
nested  cpx #K_LOOP
        beq deeper
        cpx #K_IF
        beq deeper
        cpx #K_SUB
        beq deeper
        cpx #K_NEXT
        beq closer
        cpx #K_ENDIF
        beq closer
        cpx #K_ENDS
        bne loop
closer  lda sdep
        beq bad
        dec sdep
        jmp loop
deeper  inc sdep
        jmp loop
open    lda #<m_open
        ldy #>m_open
        jmp error
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
bits    .byt 0,0,4,0,16,32,0,128
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
        cpy #1                  ; une lettre puis = : affectation
        bne cmd
        jsr skipsp
        cmp #"="
        bne cmd
        lda word
        ldy cmode
        bne kas
        jmp assign
kas     jmp k_assign
cmd     jsr lookup
        bcs bad
        lda cmode               ; traduction : la 2e adresse
        beq int
        iny
        iny
int     iny
        lda (tbl),y
        sta lp
        iny
        lda (tbl),y
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

; needgfx : erreur hors du mode HIRES ou SPLIT
needgfx
        lda h_lines
        bne ng_ok
        lda #<m_nogfx
        ldy #>m_nogfx
        jmp error
ng_ok   rts

; getvar : lettre de variable (lbuf, X) -> vix
getvar
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sec
        sbc #"A"
        sta vix
        inx
        lda lbuf,x              ; une seule lettre
        jsr isalpha
        bcc bad
        rts
bad     lda #<m_var
        ldy #>m_var
        jmp error
.)

; setvar : variable vix <- ev
setvar  lda vix
        asl
        tay
        lda ev
        sta vars,y
        lda ev+1
        sta vars+1,y
        rts

; ---------------------------------------------------------------------
; Expressions
; ---------------------------------------------------------------------
; pexpr : un paramètre (lbuf, X) -> ev ; X après lui
pexpr
        lda #0
        beq px
; lexpr : expression jusqu'à la fin de la ligne (espaces permis)
lexpr
        lda #1
px      sta edep
        jsr skipsp
        beq e_param             ; paramètre absent
        cmp #";"
        beq e_param
        stx ex
        lda #0
        sta vsp
        jsr e_or
        ldx ex
        lda lbuf,x              ; l'expression doit finir là
        beq pxok
        cmp #" "
        beq pxok
        cmp #";"
        bne e_expr
pxok    lda edep                ; LET, IF... : rien d'autre ensuite
        beq pxr
        jsr endline
pxr     rts

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

; pushv : ev sur la pile des valeurs ; popt : et <- sommet
pushv
.(
        ldy vsp
        cpy #NVS
        bcs deep
        lda ev
        sta vs_lo,y
        lda ev+1
        sta vs_hi,y
        inc vsp
        rts
deep    jmp e_expr
.)
popt    dec vsp
        ldy vsp
        lda vs_lo,y
        sta et
        lda vs_hi,y
        sta et+1
        rts

; & |
e_or
.(
        jsr e_cmp
loop    jsr ws
        jsr gch
        cmp #"&"
        beq op
        cmp #"|"
        bne r
op      pha
        inc ex
        jsr pushv
        jsr ws
        jsr e_cmp
        jsr popt
        pla
        jsr binop
        jmp loop
r       rts
.)

; e_cmp : = <> < <= > >= (une comparaison au plus)
e_cmp
.(
        jsr e_sum
        jsr relop
        bcs r
        pha
        jsr pushv
        jsr ws
        jsr e_sum
        jsr popt
        pla
        jmp binop
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
        beq gt
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
gt      inc ex
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

; + -
e_sum
.(
        jsr e_term
loop    jsr ws
        jsr gch
        cmp #"+"
        beq op
        cmp #"-"
        bne r
op      pha
        inc ex
        jsr pushv
        jsr ws
        jsr e_term
        jsr popt
        pla
        jsr binop
        jmp loop
r       rts
.)

; * / %
e_term
.(
        jsr e_un
loop    jsr ws
        jsr gch
        cmp #"*"
        beq op
        cmp #"/"
        beq op
        cmp #"%"
        bne r
op      pha
        inc ex
        jsr pushv
        jsr ws
        jsr e_un
        jsr popt
        pla
        jsr binop
        jmp loop
r       rts
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

; signe -
e_un
.(
        jsr ws
        jsr gch
        cmp #"-"
        bne e_prim
        inc ex
        jsr e_un
.)
neg_ev  sec
        lda #0
        sbc ev
        sta ev
        lda #0
        sbc ev+1
        sta ev+1
        rts

; nombre, variable, (expression), fonction
e_prim
.(
        jsr ws
        jsr gch
        cmp #"("
        bne nopar
        inc ex
        inc edep
        jsr e_or
        jmp x_close             ; (x_close redescend edep)
nopar   cmp #"0"
        bcc id
        cmp #"9"+1
        bcs id
        jmp parse_num
id      jsr parse_id
        cpx #1
        bne func
        jmp getv_kw             ; variable
func    jsr find_fn
        cmp #0
        beq f_rnd
        cmp #1
        beq f_abs
        cmp #2
        beq f_point
        jmp f_inkey
f_rnd   jsr arg1
        lda ev+1
        bmi zero
        ora ev
        beq zero
        jsr rand                ; et = hasard (0 à 32767), puis modulo
        jsr udiv
        lda mr
        sta ev
        lda mr+1
        sta ev+1
        rts
zero    lda #0
        sta ev
        sta ev+1
        rts
f_abs   jsr arg1
        lda ev+1
        bpl ar
        jmp neg_ev
ar      rts
f_point jsr x_open
        jsr e_or                ; x
        jsr pushv
        jsr x_comma
        jsr e_or                ; y
        jsr x_close
        jsr popt
        lda h_lines             ; pas d'image : 0
        beq zero
        lda et+1
        ora ev+1
        bne zero
        lda h_x1                ; paramètres de la commande gardés
        pha
        lda h_y1
        pha
        lda et
        sta h_x1
        lda ev
        sta h_y1
        jsr h_point
        sta ev
        pla
        sta h_y1
        pla
        sta h_x1
        lda #0
        sta ev+1
        rts
f_inkey lda pkey                ; touche gardée par le test d'ESC
        ldx #0
        stx pkey
        cmp #0
        bne ik
        jsr B_CONST
        beq ik
        jsr h_key
ik      sta ev
        lda #0
        sta ev+1
        rts
arg1    jsr x_open
        jsr e_or
        jmp x_close
.)

; getv_kw : ev <- variable kw (une lettre)
getv_kw lda kw
        sec
        sbc #"A"
        asl
        tay
        lda vars,y
        sta ev
        lda vars+1,y
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

fnames  .asc "RND ",0,"ABS ",1,"POINT ",2,"INKEY ",3,0

; rand : et <- nombre pseudo-aléatoire de 0 à 32767
;   (rnd = rnd * 5 + 13849 sur 16 bits, puis échange des octets)
rand
        lda rnd
        sta et
        lda rnd+1
        sta et+1
        asl rnd
        rol rnd+1
        asl rnd
        rol rnd+1
        clc
        lda rnd
        adc et
        sta rnd
        lda rnd+1
        adc et+1
        sta rnd+1
        clc
        lda rnd
        adc #<13849
        sta rnd
        lda rnd+1
        adc #>13849
        sta rnd+1
        sta et                  ; octets échangés : le bas varie mieux
        lda rnd
        and #$7F
        sta et+1
        rts

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
        bpl p2
        jsr neg_ev
p2      jsr udiv
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

; getbyte : paramètre de 0 à 255 -> A
getbyte
.(
        jsr pexpr
        lda ev+1
        bne bad
        lda ev
        rts
bad     lda #<m_range
        ldy #>m_range
        jmp error
.)

; p4 : quatre valeurs -> h_x1 h_y1 h_x2 h_y2, fin de ligne
p4      jsr p2
        jsr getbyte
        sta h_x2
        jsr getbyte
        sta h_y2
        jmp endline
; p2 : deux valeurs -> h_x1 h_y1
p2      jsr getbyte
        sta h_x1
        jsr getbyte
        sta h_y1
        rts

; ---------------------------------------------------------------------
; Commandes de dessin et divers
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
        bcc pen_ok
        jmp e_param
pen_ok  pha
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
c_gnum  jsr needgfx             ; GNUM col y n : nombre dans l'image
        jsr p2
        jsr pexpr
        jsr endline
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
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
        jsr pexpr
        jsr endline
        clc                     ; fin = ticks + n
        lda SYS_TICKS
        adc ev
        sta gv
        lda SYS_TICKS+1
        adc ev+1
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
c_print jsr lexpr
        lda h_lines
        cmp #200
        beq cp_r
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr puts
        jmp crlf
cp_r    rts
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
; Calcul et contrôle
; ---------------------------------------------------------------------
c_let   jsr getvar
        jsr skipsp
        cmp #"="
        beq let1
        jmp e_param
let1    lda vix
        clc
        adc #"A"
; assign : variable A (lettre), X sur le « = »
assign  sec
        sbc #"A"
        sta vix
        inx
        jsr lexpr
        jmp setvar

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

; body : l'entrée Y reprend à la ligne qui suit (nxt)
body    lda nxt
        sta cs_pl,y
        lda nxt+1
        sta cs_ph,y
        rts

c_repeat
.(
        jsr pexpr
        jsr endline
        lda ev+1                ; n <= 0 : le bloc est sauté
        bmi skip
        ora ev
        beq skip
        lda #T_REP
        jsr cs_push
        lda ev
        sta cs_al,y
        lda ev+1
        sta cs_ah,y
        jmp body
skip    lda #4                  ; jusqu'au NEXT
        jmp skip_to
.)

c_for
.(
        jsr getvar
        lda vix
        sta fvar
        jsr pexpr               ; départ
        lda fvar
        sta vix
        jsr setvar
        jsr pexpr               ; arrivée
        lda ev
        sta flim
        lda ev+1
        sta flim+1
        lda #1                  ; pas : 1 par défaut
        sta fstep
        lda #0
        sta fstep+1
        jsr skipsp
        beq nostep
        cmp #";"
        beq nostep
        jsr pexpr
        lda ev
        sta fstep
        lda ev+1
        sta fstep+1
        ora ev
        bne nostep
        lda #<m_step
        ldy #>m_step
        jmp error
nostep  jsr endline
        lda #T_FOR
        jsr cs_push
        lda fvar
        sta cs_v,y
        lda flim
        sta cs_al,y
        lda flim+1
        sta cs_ah,y
        lda fstep
        sta cs_bl,y
        lda fstep+1
        sta cs_bh,y
        jsr body
        jsr for_ok              ; déjà au-delà : le bloc est sauté
        bcc r
        dec csp
        lda #4
        jmp skip_to
r       rts
.)

; for_ok : entrée du sommet (FOR) ; C=0 si la variable n'a pas dépassé
;   l'arrivée (pas > 0 : var <= arrivée ; pas < 0 : var >= arrivée)
for_ok
.(
        ldy csp
        dey
        lda cs_v,y
        asl
        tax
        sec                     ; var - arrivée (signé)
        lda vars,x
        sbc cs_al,y
        sta mt
        lda vars+1,x
        sbc cs_ah,y
        sta mt+1
        ora mt                  ; (ORA et LDA laissent V)
        sta gd                  ; 0 : égaux
        lda mt+1
        bvc nv
        eor #$80
nv      sta mt+1                ; bit 7 : var < arrivée
        lda cs_bh,y
        bmi down
        lda gd                  ; pas > 0 : var <= arrivée
        beq ok
        lda mt+1
        bmi ok
        sec
        rts
down    lda mt+1                ; pas < 0 : var >= arrivée
        bpl ok
        sec
        rts
ok      clc
        rts
.)

c_while
.(
        jsr lexpr
        lda ev
        ora ev+1
        beq skip
        lda #T_WHILE
        jsr cs_push
        lda cur                 ; NEXT revient à la ligne du WHILE
        sta cs_pl,y
        lda cur+1
        sta cs_ph,y
        rts
skip    lda #4
        jmp skip_to
.)

c_next
.(
        ldy csp
        beq none
        dey
        lda cs_t,y
        cmp #T_REP
        beq reps
        cmp #T_FOR
        beq for
        cmp #T_WHILE
        beq while
none    lda #<m_nofor
        ldy #>m_nofor
        jmp error
reps    sec                     ; encore une fois ?
        lda cs_al,y
        sbc #1
        sta cs_al,y
        lda cs_ah,y
        sbc #0
        sta cs_ah,y
        ora cs_al,y
        beq pop
again   lda cs_pl,y
        sta nxt
        lda cs_ph,y
        sta nxt+1
        rts
pop     dec csp
        rts
while   dec csp                 ; la ligne du WHILE refait le test
        jmp again
for     lda cs_v,y              ; var += pas
        asl
        tax
        clc
        lda vars,x
        adc cs_bl,y
        sta vars,x
        lda vars+1,x
        adc cs_bh,y
        sta vars+1,x
        bvs pop                 ; dépassement : fin de la boucle
        jsr for_ok
        bcs pop
        ldy csp
        dey
        jmp again
.)

c_if    jsr lexpr
        lda ev
        ora ev+1
        bne if_r
        lda #16+32              ; faux : jusqu'au ELSE ou au ENDIF
        jmp skip_to
if_r    rts

c_else  lda #32                 ; fin de la partie vraie : jusqu'au ENDIF
        jmp skip_to

c_endif rts

c_sub   lda #128                ; rencontrée en chemin : sautée
        jmp skip_to

; ENDSUB / RETURN : retour après le CALL (les boucles ouvertes dans le
;   sous-programme sont abandonnées)
c_return
.(
loop    ldy csp
        beq none
        dey
        sty csp
        lda cs_t,y
        cmp #T_CALL
        bne loop
        lda cs_pl,y
        sta nxt
        lda cs_ph,y
        sta nxt+1
        rts
none    lda #<m_noret
        ldy #>m_noret
        jmp error
.)

; CALL NOM : cherche « SUB NOM » dans tout le texte
c_call
        jsr sub_find
        lda #T_CALL             ; retour à la ligne après CALL
        jsr cs_push
        jsr body
        lda sk                  ; corps : ligne après SUB NOM
        sta nxt
        lda sk+1
        sta nxt+1
        rts

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

; =====================================================================
; Traduction en assembleur (GRAPHER NOM /A -> NOM.ASM)
; =====================================================================
; Chaque ligne devient un commentaire puis son code ; le dessin appelle
; hires.inc, le reste la bibliothèque grx.inc. Une expression est
; compilée avec son état (kc = 1 : constante kv pas encore écrite ;
; kc = 0 : valeur dans g_ev à l'exécution) : les parties constantes
; sont calculées ici.

compile
.(
        jsr o_open
        lda #<h_head1           ; en-tête
        ldy #>h_head1
        jsr os
        jsr o_name
        lda #<h_head2
        ldy #>h_head2
        jsr os
        jsr o_name
        lda #<h_head2b
        ldy #>h_head2b
        jsr os
        jsr o_name
        lda #<h_head3
        ldy #>h_head3
        jsr os
        lda #0
        sta kn
        sta kn+1
        sta csp
kloop   jsr B_CONST             ; ESC : arrêt
        beq krd
        jsr h_key
        cmp #27
        bne krd
        lda #<m_esc
        ldy #>m_esc
        jmp stop_msg
krd     ldy #0
        lda (cur),y
        beq kend
        jsr read_line
        ldx #0                  ; la ligne en commentaire
        jsr skipsp
        beq kx
        lda #";"
        jsr oc
        lda #" "
        jsr oc
        lda #<lbuf
        ldy #>lbuf
        jsr os
        jsr ocrlf
        jsr exec
kx      lda nxt
        sta cur
        lda nxt+1
        sta cur+1
        jmp kloop
kend    lda csp                 ; un bloc n'est pas fermé
        beq ok
        lda #0
        sta word
        lda #<m_open
        ldy #>m_open
        jmp error
ok      lda #<s_jend            ; fin, puis les boucles et les inclusions
        ldy #>s_jend
        jsr oi
        lda #<h_tail1
        ldy #>h_tail1
        jsr os
        lda #0
        sta kl
        sta kl+1
bl      lda kl                  ; B1 à Bn
        cmp kn
        bne bl1
        lda kl+1
        cmp kn+1
        beq bend
bl1     inc kl
        bne bl2
        inc kl+1
bl2     lda #0
        sta ksuf
        lda #"B"
        jsr o_lname
        lda #<s_bdata
        ldy #>s_bdata
        jsr os
        jmp bl
bend    lda #<h_tail2
        ldy #>h_tail2
        jsr os
        jsr o_close
        jsr o_name              ; message : NOM.ASM ecrit
        lda #<m_done
        ldy #>m_done
        jsr puts
        jsr o_name
        jsr crlf
        jmp quit
.)

; o_name : nom du fichier source (sans le type) sur la sortie, ou sur la
;   console après la fermeture du fichier
o_name
.(
        ldx #1
l       lda sfcb,x
        cmp #" "
        beq r
        stx lx
        ldy oopen
        beq con
        jsr oc
        jmp nx
con     jsr putc
nx      ldx lx
        inx
        cpx #9
        bne l
r       rts
.)

; ---------------------------------------------------------------------
; Fichier de sortie
; ---------------------------------------------------------------------
o_open
.(
        ldx #11                 ; NOM.ASM sur le lecteur de NOM.GRX
l       lda sfcb,x
        sta ofcb,x
        dex
        bpl l
        ldx #2
t       lda t_asm,x
        sta ofcb+9,x
        dex
        bpl t
        jsr o_fcb0
        ldx #F_DELETE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        jsr o_fcb0
        ldx #F_MAKE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_full
        ldy #>m_full
        jmp error
ok      lda #1
        sta oopen
        lda #0
        sta oidx
        rts
.)

o_fcb0
.(
        ldy #12
        lda #0
l       sta ofcb,y
        iny
        cpy #36
        bne l
        rts
.)

; oc : un caractère sur la sortie (X et Y gardés)
oc
.(
        stx osx
        sty osy
        ldy oidx
        sta obuf,y
        iny
        sty oidx
        cpy #128
        bne r
        jsr o_flush
r       ldx osx
        ldy osy
        rts
.)

o_flush
.(
        ldx #F_SETDMA
        lda #<obuf
        ldy #>obuf
        jsr BDOS
        ldx #F_WRITE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        pha
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        pla
        bne full
        lda #0
        sta oidx
        rts
full    lda #<m_full
        ldy #>m_full
        jmp error
.)

o_close
.(
        lda oidx                ; dernier enregistrement complété par ^Z
        beq c
l       lda #$1A
        jsr oc
        lda oidx
        bne l
c       ldx #F_CLOSE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        lda #0
        sta oopen
        rts
.)

; o_drop : erreur pendant la traduction : le fichier est effacé
o_drop
.(
        lda oopen
        beq r
        lda #0
        sta oopen
        ldx #F_CLOSE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        jsr o_fcb0
        ldx #F_DELETE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
r       rts
.)

; ---------------------------------------------------------------------
; Écriture du texte assembleur
; ---------------------------------------------------------------------
; os : chaîne A/Y (0 à la fin) ; ocrlf : fin de ligne
os
.(
        sta ostr
        sty ostr+1
        ldy #0
l       lda (ostr),y
        beq r
        jsr oc
        iny
        bne l
r       rts
.)
ocrlf   lda #13
        jsr oc
        lda #10
        jmp oc

; oi : instruction A/Y (« jsr h_line »), en retrait, puis fin de ligne
oi      sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        jmp ocrlf
o_tab   lda #<s_tab
        ldy #>s_tab
        jmp os

; ohex : A en hexadécimal ($xx)
ohex
.(
        pha
        lda #"$"
        jsr oc
        pla
        pha
        lsr
        lsr
        lsr
        lsr
        jsr dig
        pla
        and #$0F
dig     cmp #10
        bcc d
        adc #6
d       adc #"0"
        jmp oc
.)

; oimm : « op #$xx » : A/Y = début (« lda # »), osv = valeur
oimm    sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        lda osv
        jsr ohex
        jmp ocrlf

; odec : kl en décimal (X gardé)
odec
.(
        txa
        pha
        lda kl
        sta gv
        lda kl+1
        sta gv+1
        lda #0
        sta gd
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
        jsr oc
        sta gd
nx      inx
        cpx #4
        bne dig
        lda gv
        ora #"0"
        jsr oc
        pla
        tax
        rts
.)

; o_lab : étiquette A + numéro kl + suffixe ksuf (0 : aucun), en colonne 1
o_lab   jsr o_lname
        jmp ocrlf
o_lname jsr oc
        jsr odec
        lda ksuf
        beq ol_r
        jmp oc
ol_r    rts

; o_jmp : « jmp L<kl><suffixe A> »
o_jmp   sta ksuf
        jsr o_tab
        lda #<s_jmp
        ldy #>s_jmp
        jsr os
        lda #"L"
        jsr o_lname
        jmp ocrlf

; o_label : « L<kl><suffixe A> » en colonne 1
o_label sta ksuf
        lda #"L"
        jmp o_lab

; o_ab : « lda #<Bn » puis « ldy #>Bn »
o_ab    lda #0
        sta ksuf
        jsr o_tab
        lda #<s_ldalo
        ldy #>s_ldalo
        jsr os
        lda #"B"
        jsr o_lname
        jsr ocrlf
        jsr o_tab
        lda #<s_ldyhi
        ldy #>s_ldyhi
        jsr os
        lda #"B"
        jsr o_lname
        jmp ocrlf

; o_skipz : « lda g_ev / ora g_ev+1 / bne *+5 / jmp L<kl><A> » (si nul)
o_skipz pha
        lda #<s_tst
        ldy #>s_tst
        jsr os
        pla
        jmp o_jmp

; ---------------------------------------------------------------------
; Destinations : ksym = « V_x », « Bn » ou un nom fixe ; koff = décalage
; ---------------------------------------------------------------------
; o_sym : nom de la destination, avec +koff
o_sym
.(
        lda ksym
        beq var
        cmp #1
        beq blk
        lda ksym+1              ; nom fixe : adresse en ksym+1/+2
        ldy ksym+2
        jsr os
        jmp off
var     lda #<s_v
        ldy #>s_v
        jsr os
        lda kvar
        clc
        adc #"A"
        jsr oc
        jmp off
blk     lda #0
        sta ksuf
        lda #"B"
        jsr o_lname
off     lda koff
        beq r
        lda #"+"
        jsr oc
        lda koff
        ora #"0"
        jmp oc
r       rts
.)

; o_store : « sta dest » (A/Y = début de l'instruction : « sta »)
o_ins_sym
        sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        jsr o_sym
        jmp ocrlf

; o_st16 : résultat de l'expression (kc/kv ou g_ev) -> destination
;   (16 bits, koff puis koff+1)
o_st16
.(
        lda kc
        beq dyn
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jsr oimm
        jsr sta1
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv+1
        sta osv
        pla
        jsr oimm
        jmp sta2
dyn     lda #<s_ldaev
        ldy #>s_ldaev
        jsr oi
        jsr sta1
        lda #<s_ldaev1
        ldy #>s_ldaev1
        jsr oi
sta2    inc koff
        jsr sta1
        dec koff
        rts
sta1    lda #<s_sta
        ldy #>s_sta
        jmp o_ins_sym
.)

; dest_var / dest_blk / dest_fix : choix de la destination
dest_var
        sta kvar
        lda #0
        sta ksym
        sta koff
        rts
dest_blk
        lda #1
        sta ksym
        lda #0
        sta koff
        rts
dest_fix                        ; A/Y = nom
        sta ksym+1
        sty ksym+2
        lda #2
        sta ksym
        lda #0
        sta koff
        rts

; k_mat : constante en attente -> g_ev (à l'exécution)
k_mat
.(
        lda kc
        beq r
        lda #<s_gev
        ldy #>s_gev
        jsr dest_fix
        jsr o_st16
        lda #0
        sta kc
r       rts
.)

; ---------------------------------------------------------------------
; Expressions
; ---------------------------------------------------------------------
k_pexpr lda #0
        beq kpx
k_lexpr lda #1
kpx     sta edep
        jsr skipsp
        beq k_epar
        cmp #";"
        beq k_epar
        stx ex
        lda #0
        sta vsp
        jsr k_or
        ldx ex
        lda lbuf,x
        beq kpok
        cmp #" "
        beq kpok
        cmp #";"
        bne k_eexp
kpok    lda edep
        beq kpr
        jsr endline
kpr     rts
k_epar  jmp e_param
k_eexp  jmp e_expr

k_or
.(
        jsr k_cmp
loop    jsr ws
        jsr gch
        cmp #"&"
        beq op
        cmp #"|"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_cmp
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_cmp
.(
        jsr k_sum
        jsr relop
        bcs r
        pha
        jsr k_left
        jsr ws
        jsr k_sum
        pla
        jmp k_apply
r       rts
.)

k_sum
.(
        jsr k_term
loop    jsr ws
        jsr gch
        cmp #"+"
        beq op
        cmp #"-"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_term
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_term
.(
        jsr k_un
loop    jsr ws
        jsr gch
        cmp #"*"
        beq op
        cmp #"/"
        beq op
        cmp #"%"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_un
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_un
.(
        jsr ws
        jsr gch
        cmp #"-"
        bne k_prim
        inc ex
        jsr k_un
        lda kc
        beq dyn
        lda kv                  ; constante : opposée ici
        sta ev
        lda kv+1
        sta ev+1
        jsr neg_ev
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        rts
dyn     lda #<s_neg
        ldy #>s_neg
        jmp oi
.)

k_prim
.(
        jsr ws
        jsr gch
        cmp #"("
        bne nopar
        inc ex
        inc edep
        jsr k_or
        jmp x_close
nopar   cmp #"0"
        bcc id
        cmp #"9"+1
        bcs id
        jsr parse_num           ; nombre : constante
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        lda #1
        sta kc
        rts
id      jsr parse_id
        cpx #1
        bne func
        lda kw                  ; variable -> g_ev
        sec
        sbc #"A"
        jsr dest_var
        lda #0
        sta kc
        lda #<s_ldai            ; (o_st16 à l'envers : var -> g_ev)
        jsr ld_var
        rts
func    jsr find_fn
        cmp #0
        beq f_rnd
        cmp #1
        beq f_abs
        cmp #2
        beq f_point
        lda #<s_inkey
        ldy #>s_inkey
        jmp dyn
f_rnd   jsr x_open
        jsr k_or
        jsr x_close
        jsr k_mat
        lda #<s_rnd
        ldy #>s_rnd
        jmp dyn
f_abs   jsr x_open
        jsr k_or
        jsr x_close
        lda kc
        beq ab
        lda kv+1                ; constante : ici
        bpl r
        lda kv
        sta ev
        lda kv+1
        sta ev+1
        jsr neg_ev
        lda ev
        sta kv
        lda ev+1
        sta kv+1
r       rts
ab      lda #<s_abs
        ldy #>s_abs
        jmp oi
f_point jsr x_open
        jsr k_or
        jsr k_mat
        lda #<s_push
        ldy #>s_push
        jsr oi
        jsr x_comma
        jsr k_or
        jsr x_close
        jsr k_mat
        lda #<s_pop
        ldy #>s_pop
        jsr oi
        lda #<s_point
        ldy #>s_point
dyn     jsr oi
        lda #0
        sta kc
        rts
.)

; ld_var : g_ev <- variable kvar (« lda V_x / sta g_ev » ...)
ld_var
.(
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        lda #<s_stev
        ldy #>s_stev
        jsr oi
        inc koff
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        lda #<s_stev1
        ldy #>s_stev1
        jmp oi
.)

; k_left : opérande de gauche gardé (constante ici, valeur sur la pile
;   des valeurs à l'exécution)
k_left
.(
        ldy vsp
        cpy #NVS
        bcs deep
        lda kc
        sta vs_f,y
        lda kv
        sta vs_lo,y
        lda kv+1
        sta vs_hi,y
        inc vsp
        lda kc
        bne r
        lda #<s_push
        ldy #>s_push
        jmp oi
r       rts
deep    jmp e_expr
.)

; k_apply : gauche (k_left) op A droite (kc/kv)
k_apply
.(
        sta kop
        dec vsp
        ldy vsp
        lda vs_f,y
        sta klf
        lda vs_lo,y
        sta lv
        lda vs_hi,y
        sta lv+1
        lda klf
        beq lstk
        lda kc
        beq lcst
        lda lv                  ; deux constantes : calcul ici
        sta et
        lda lv+1
        sta et+1
        lda kv
        sta ev
        lda kv+1
        sta ev+1
        lda kop
        jsr binop
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        rts
lcst    lda #<s_ldai            ; gauche constante -> g_et
        ldy #>s_ldai
        pha
        lda lv
        sta osv
        pla
        jsr oimm
        lda #<s_stet
        ldy #>s_stet
        jsr oi
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda lv+1
        sta osv
        pla
        jsr oimm
        lda #<s_stet1
        ldy #>s_stet1
        jsr oi
        jmp eop
lstk    jsr k_mat               ; gauche sur la pile des valeurs
        lda #<s_pop
        ldy #>s_pop
        jsr oi
eop     lda #0
        sta kc
        lda kop
        bpl ar
        and #$7F                ; comparaison : ldx #n / jsr g_cmp
        sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        lda #<s_cmp
        ldy #>s_cmp
        jmp oi
ar      ldx #0                  ; opération -> sa routine
f       lda ops,x
        beq r
        cmp kop
        beq found
        inx
        inx
        inx
        bne f
found   lda ops+1,x
        ldy ops+2,x
        jmp oi
r       rts
ops     .byt "+"
        .word s_add
        .byt "-"
        .word s_sub
        .byt "*"
        .word s_mul
        .byt "/"
        .word s_div
        .byt "%"
        .word s_mod
        .byt "&"
        .word s_and
        .byt "|"
        .word s_or
        .byt 0
.)

; k_byte : paramètre de 0 à 255 -> A (à l'exécution)
k_byte
.(
        jsr k_pexpr
        lda kc
        beq dyn
        lda kv+1                ; constante : vérifiée ici
        bne bad
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jmp oimm
bad     lda #<m_range
        ldy #>m_range
        jmp error
dyn     lda #<s_byte
        ldy #>s_byte
        jmp oi
.)

; k_p : paramètre de 0 à 255 -> destination fixe A/Y (« h_x1 »)
k_p     pha
        tya
        pha
        jsr k_byte
        pla
        tay
        pla
        jsr dest_fix
        lda #<s_sta
        ldy #>s_sta
        jmp o_ins_sym
k_p2    lda #<s_hx1
        ldy #>s_hx1
        jsr k_p
        lda #<s_hy1
        ldy #>s_hy1
        jmp k_p
k_p4    jsr k_p2
        lda #<s_hx2
        ldy #>s_hx2
        jsr k_p
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jmp endline

; o_text : texte de lbuf (X) jusqu'à la fin, en .byt (guillemets à part)
o_text
.(
        stx lx
        jsr o_tab
        lda #<s_byt
        ldy #>s_byt
        jsr os
        lda #0
        sta kin                 ; dans une chaîne
        sta kst                 ; quelque chose écrit
l       ldx lx
        lda lbuf,x
        beq end
        inc lx
        cmp #34
        beq num
        cmp #" "
        bcc num
        pha
        lda kin
        bne in
        jsr comma
        lda #34
        jsr oc
        lda #1
        sta kin
in      pla
        jsr oc
        jmp l
num     pha
        jsr close
        jsr comma
        pla
        jsr ohex
        jmp l
end     jsr close
        jsr comma
        lda #"0"
        jsr oc
        jmp ocrlf
close   lda kin
        beq cr
        lda #34
        jsr oc
        lda #0
        sta kin
cr      rts
comma   lda kst
        beq kc1
        lda #","
        jmp oc
kc1     lda #1
        sta kst
        rts
.)

; ---------------------------------------------------------------------
; Commandes traduites
; ---------------------------------------------------------------------
k_call0 jsr endline             ; A/Y : instruction seule (« jsr h_full »)
        pla
        tay
        pla
        jmp oi
k_hires lda #<s_hires
        pha
        lda #>s_hires
        pha
        jmp k_call0
k_split lda #<s_split
        pha
        lda #>s_split
        pha
        jmp k_call0
k_text  lda #<s_text
        pha
        lda #>s_text
        pha
        jmp k_call0
k_gcls  lda #<s_gcls
        pha
        lda #>s_gcls
        pha
        jmp k_call0
k_wait  lda #<s_wait
        pha
        lda #>s_wait
        pha
        jmp k_call0
k_end   lda #<s_jend
        pha
        lda #>s_jend
        pha
        jmp k_call0
k_pen   jsr k_pexpr
        lda kc                  ; constante : 0 à 2
        beq kpen1
        lda kv+1
        bne kpen0
        lda kv
        cmp #3
        bcc kpen1
kpen0   jmp e_param
kpen1   ldx #0
        jsr k_rebyte
        lda #<s_pen
        ldy #>s_pen
        jmp oi
k_plot  jsr k_p2
        jsr endline
        lda #<s_plot
        ldy #>s_plot
        jmp oi
k_line  jsr k_p4
        lda #<s_line
        ldy #>s_line
        jmp oi
k_box   jsr k_p4
        lda #<s_box
        ldy #>s_box
        jmp oi
k_fbox  jsr k_p4
        lda #<s_fbox
        ldy #>s_fbox
        jmp oi
k_circle
        jsr k_p2
        lda #<s_hr
        ldy #>s_hr
        jsr k_p
        jsr endline
        lda #<s_circle
        ldy #>s_circle
        jmp oi
k_attr  jsr k_p2
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jsr k_byte
        jsr endline
        lda #<s_attr
        ldy #>s_attr
        jmp oi
k_gtext jsr k_p2                ; le texte suit l'appel
        lda lbuf,x
        beq kgt
        inx
kgt     stx lx
        lda #<s_gtext
        ldy #>s_gtext
        jsr oi
        ldx lx
        jmp o_text
k_echo  jsr skipsp
        stx lx
        lda #<s_echo
        ldy #>s_echo
        jsr oi
        ldx lx
        jmp o_text
k_gnum  jsr k_p2
        jsr k_pexpr
        jsr endline
        jsr k_mat
        lda #<s_gnum
        ldy #>s_gnum
        jmp oi
k_delay jsr k_pexpr
        jsr endline
        jsr k_mat
        lda #<s_delay
        ldy #>s_delay
        jmp oi
k_print jsr k_lexpr
        jsr k_mat
        lda #<s_print
        ldy #>s_print
        jmp oi
k_gload lda #<s_gload
        ldy #>s_gload
        jmp k_img
k_gsave lda #<s_gsave
        ldy #>s_gsave
k_img
.(
        pha
        tya
        pha
        jsr getname             ; le nom (lecteur, 8 + 3) suit l'appel
        pla
        tay
        pla
        jsr oi
        jsr o_tab
        lda #<s_byt
        ldy #>s_byt
        jsr os
        lda ifcb
        jsr ohex
        jsr ocrlf
        jsr o_tab
        lda #<s_asc
        ldy #>s_asc
        jsr os
        ldx #1
l       lda ifcb,x
        jsr oc
        inx
        cpx #12
        bne l
        lda #34
        jsr oc
        jmp ocrlf
.)

; k_rebyte : (après k_pexpr) A <- valeur à l'exécution
k_rebyte
        lda kc
        beq krb1
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jmp oimm
krb1    lda #<s_byte
        ldy #>s_byte
        jmp oi

; affectation : X sur le « = », A = lettre
k_let   jsr getvar
        jsr skipsp
        cmp #"="
        beq klet1
        jmp e_param
klet1   lda vix
        clc
        adc #"A"
k_assign
        sec
        sbc #"A"
        sta vix
        inx
        jsr k_lexpr
        lda vix
        jsr dest_var
        jmp o_st16

; k_newblk : nouveau bloc kl = ++kn, empilé avec le type A
k_newblk
.(
        inc kn
        bne n
        inc kn+1
n       ldy kn
        sty kl
        ldy kn+1
        sty kl+1
        jsr cs_push
        lda kl
        sta cs_al,y
        lda kl+1
        sta cs_ah,y
        lda #0
        sta cs_v,y
        rts
.)

; k_top : sommet de la pile de contrôle -> Y, kl ; type dans A (0 : vide)
k_top
.(
        ldy csp
        beq none
        dey
        lda cs_al,y
        sta kl
        lda cs_ah,y
        sta kl+1
        lda cs_t,y
        rts
none    lda #0
        rts
.)

k_repeat
        lda #T_REP
        jsr k_newblk
        jsr k_pexpr
        jsr endline
        jsr dest_blk
        jsr o_st16
        lda #"T"
        jsr o_label
        jsr o_ab
        lda #<s_rept
        ldy #>s_rept
        jsr oi
        lda #<s_bcc
        ldy #>s_bcc
        jsr oi
        lda #"E"
        jmp o_jmp

k_for
.(
        jsr getvar
        lda vix
        sta fvar
        lda #T_FOR
        jsr k_newblk
        lda fvar
        sta cs_v,y
        jsr k_pexpr             ; départ -> variable
        lda fvar
        jsr dest_var
        jsr o_st16
        jsr k_pexpr             ; arrivée -> Bn
        jsr dest_blk
        jsr o_st16
        lda #1                  ; pas : 1 par défaut
        sta kc
        sta kv
        lda #0
        sta kv+1
        jsr skipsp
        beq step
        cmp #";"
        beq step
        jsr k_pexpr
        lda kc
        beq step
        lda kv
        ora kv+1
        bne step
        lda #<m_step
        ldy #>m_step
        jmp error
step    jsr endline
        jsr dest_blk            ; pas -> Bn+2
        lda #2
        sta koff
        jsr o_st16
        lda #"T"
        jsr o_label
        jsr o_ab
        jsr o_ldxv
        lda #<s_forok
        ldy #>s_forok
        jsr oi
        lda #<s_bcc
        ldy #>s_bcc
        jsr oi
        lda #"E"
        jmp o_jmp
.)

; o_ldxv : « ldx #2*var » (variable de la boucle du sommet)
o_ldxv  ldy csp
        dey
        lda cs_v,y
        asl
        sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jmp oimm

k_while
.(
        lda #T_WHILE
        jsr k_newblk
        lda #"T"
        jsr o_label
        jsr k_lexpr
        lda kc
        beq dyn
        lda kv
        ora kv+1
        bne r                   ; WHILE vrai : rien à tester
        lda #"E"
        jmp o_jmp
dyn     lda #"E"
        jmp o_skipz
r       rts
.)

k_next
.(
        jsr k_top
        cmp #T_REP
        beq ok
        cmp #T_FOR
        beq ok
        cmp #T_WHILE
        beq ok
        lda #<m_nofor
        ldy #>m_nofor
        jmp error
ok      pha
        lda #<s_brk
        ldy #>s_brk
        jsr oi
        pla
        cmp #T_FOR
        bne back
        jsr o_ab
        jsr o_ldxv
        lda #<s_fstep
        ldy #>s_fstep
        jsr oi
        lda #<s_bcs
        ldy #>s_bcs
        jsr oi
back    lda #"T"
        jsr o_jmp
        lda #"E"
        jsr o_label
        dec csp
        rts
.)

k_if
.(
        lda #T_IF
        jsr k_newblk
        jsr k_lexpr
        lda kc
        beq dyn
        lda kv
        ora kv+1
        bne r
        lda #"X"
        jmp o_jmp
dyn     lda #"X"
        jmp o_skipz
r       rts
.)

k_else
.(
        jsr k_top
        cmp #T_IF
        bne bad
        lda cs_v,y
        bne bad
        lda #1
        sta cs_v,y
        lda #"E"
        jsr o_jmp
        lda #"X"
        jmp o_label
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_endif
.(
        jsr k_top
        cmp #T_IF
        bne bad
        lda cs_v,y
        bne e
        lda #"X"
        jsr o_label
e       lda #"E"
        jsr o_label
        dec csp
        rts
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_sub
.(
        jsr getsub              ; nom -> cname
        jsr endline
        lda #T_SUB
        jsr k_newblk
        lda #"E"                ; rencontré en chemin : sauté
        jsr o_jmp
        jsr o_pname
        jmp ocrlf
.)

k_endsub
.(
        jsr k_top
        cmp #T_SUB
        bne bad
        lda #<s_rts
        ldy #>s_rts
        jsr oi
        lda #"E"
        jsr o_label
        dec csp
        rts
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_return
.(
        jsr endline
        ldy csp                 ; dans un SUB ?
l       dey
        bmi bad
        lda cs_t,y
        cmp #T_SUB
        bne l
        lda #<s_rts
        ldy #>s_rts
        jmp oi
bad     lda #<m_noret
        ldy #>m_noret
        jmp error
.)

k_call
        jsr sub_find            ; vérifie que SUB NOM existe
        jsr o_tab
        lda #<s_jsr
        ldy #>s_jsr
        jsr os
        jsr o_pname
        jmp ocrlf

; o_pname : « P_NOM »
o_pname lda #<s_p
        ldy #>s_p
        jsr os
        lda #<cname
        ldy #>cname
        jmp os

; textes de l'assembleur produit
s_tab   .asc "        ",0
s_jmp   .asc "jmp ",0
s_jsr   .asc "jsr ",0
s_jend  .asc "jmp g_end",0
s_ldalo .asc "lda #<",0
s_ldyhi .asc "ldy #>",0
s_ldai  .asc "lda #",0
s_ldxi  .asc "ldx #",0
s_lda   .asc "lda ",0
s_sta   .asc "sta ",0
s_ldaev .asc "lda g_ev",0
s_ldaev1 .asc "lda g_ev+1",0
s_stev  .asc "sta g_ev",0
s_stev1 .asc "sta g_ev+1",0
s_stet  .asc "sta g_et",0
s_stet1 .asc "sta g_et+1",0
s_gev   .asc "g_ev",0
s_v     .asc "V_",0
s_p     .asc "P_",0
s_tst   .asc "        lda g_ev",13,10,"        ora g_ev+1",13,10
        .asc "        bne *+5",13,10,0
s_bcc   .asc "bcc *+5",0
s_bcs   .asc "bcs *+5",0
s_rts   .asc "rts",0
s_byt   .asc ".byt ",0
s_asc   .asc ".asc ",34,0
s_bdata .asc "    .word 0,0",13,10,0
s_hx1   .asc "h_x1",0
s_hy1   .asc "h_y1",0
s_hx2   .asc "h_x2",0
s_hy2   .asc "h_y2",0
s_hr    .asc "h_r",0
s_hires .asc "jsr h_full",0
s_split .asc "jsr h_split",0
s_text  .asc "jsr h_text",0
s_gcls  .asc "jsr g_cls",0
s_wait  .asc "jsr g_wait",0
s_pen   .asc "jsr h_pen",0
s_plot  .asc "jsr h_plot",0
s_line  .asc "jsr h_line",0
s_box   .asc "jsr h_box",0
s_fbox  .asc "jsr h_fbox",0
s_circle .asc "jsr h_circle",0
s_attr  .asc "jsr h_attr",0
s_gtext .asc "jsr g_gtext",0
s_echo  .asc "jsr g_echo",0
s_gnum  .asc "jsr g_gnum",0
s_delay .asc "jsr g_delay",0
s_print .asc "jsr g_print",0
s_gload .asc "jsr g_gload",0
s_gsave .asc "jsr g_gsave",0
s_byte  .asc "jsr g_byte",0
s_push  .asc "jsr g_push",0
s_pop   .asc "jsr g_pop",0
s_neg   .asc "jsr g_neg",0
s_rnd   .asc "jsr g_rnd",0
s_abs   .asc "jsr g_abs",0
s_point .asc "jsr g_point",0
s_inkey .asc "jsr g_inkey",0
s_cmp   .asc "jsr g_cmp",0
s_add   .asc "jsr g_add",0
s_sub   .asc "jsr g_sub",0
s_mul   .asc "jsr g_mul",0
s_div   .asc "jsr g_div",0
s_mod   .asc "jsr g_mod",0
s_and   .asc "jsr g_and",0
s_or    .asc "jsr g_or",0
s_rept  .asc "jsr g_rept",0
s_forok .asc "jsr g_forok",0
s_fstep .asc "jsr g_forstep",0
s_brk   .asc "jsr g_brk",0
h_head1 .asc "; ",0
h_head2 .asc ".ASM : traduit de ",0
h_head2b .asc ".GRX par GRAPHER /A",13,10
        .asc "; ASM ",0
h_head3 .asc " donne le .COM (CPA.INC, GRX.INC et",13,10
        .asc "; HIRES.INC sur le meme lecteur)",13,10
        .asc "#include ",34,"CPA.INC",34,13,10
        .asc "        *= $0500",13,10
        .asc "        jsr g_init",13,10,0
h_tail1 .asc "; boucles : compte, ou arrivee et pas",13,10,0
h_tail2 .asc "#include ",34,"GRX.INC",34,13,10
        .asc "#include ",34,"HIRES.INC",34,13,10,0
t_asm   .asc "ASM"
m_done  .asc ".ASM ecrit : ASM ",0

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

; ---------------------------------------------------------------------
; Table des commandes : nom (dernière lettre avec le bit 7), classe,
; adresse pour l'exécution, adresse pour la traduction ; les plus fréquentes d'abord (la recherche est séquentielle)
; ---------------------------------------------------------------------
cmds
        .asc "NEX"
        .byt "T"|$80,K_NEXT
        .word c_next
        .word k_next
        .asc "I"
        .byt "F"|$80,K_IF
        .word c_if
        .word k_if
        .asc "ENDI"
        .byt "F"|$80,K_ENDIF
        .word c_endif
        .word k_endif
        .asc "ELS"
        .byt "E"|$80,K_ELSE
        .word c_else
        .word k_else
        .asc "PLO"
        .byt "T"|$80,0
        .word c_plot
        .word k_plot
        .asc "LIN"
        .byt "E"|$80,0
        .word c_line
        .word k_line
        .asc "LE"
        .byt "T"|$80,0
        .word c_let
        .word k_let
        .asc "FO"
        .byt "R"|$80,K_LOOP
        .word c_for
        .word k_for
        .asc "REPEA"
        .byt "T"|$80,K_LOOP
        .word c_repeat
        .word k_repeat
        .asc "WHIL"
        .byt "E"|$80,K_LOOP
        .word c_while
        .word k_while
        .asc "CAL"
        .byt "L"|$80,0
        .word c_call
        .word k_call
        .asc "ENDSU"
        .byt "B"|$80,K_ENDS
        .word c_return
        .word k_endsub
        .asc "RETUR"
        .byt "N"|$80,0
        .word c_return
        .word k_return
        .asc "SU"
        .byt "B"|$80,K_SUB
        .word c_sub
        .word k_sub
        .asc "BO"
        .byt "X"|$80,0
        .word c_box
        .word k_box
        .asc "FBO"
        .byt "X"|$80,0
        .word c_fbox
        .word k_fbox
        .asc "CIRCL"
        .byt "E"|$80,0
        .word c_circle
        .word k_circle
        .asc "PE"
        .byt "N"|$80,0
        .word c_pen
        .word k_pen
        .asc "GTEX"
        .byt "T"|$80,0
        .word c_gtext
        .word k_gtext
        .asc "GNU"
        .byt "M"|$80,0
        .word c_gnum
        .word k_gnum
        .asc "ATT"
        .byt "R"|$80,0
        .word c_attr
        .word k_attr
        .asc "GCL"
        .byt "S"|$80,0
        .word c_gcls
        .word k_gcls
        .asc "PRIN"
        .byt "T"|$80,0
        .word c_print
        .word k_print
        .asc "DELA"
        .byt "Y"|$80,0
        .word c_delay
        .word k_delay
        .asc "WAI"
        .byt "T"|$80,0
        .word c_wait
        .word k_wait
        .asc "ECH"
        .byt "O"|$80,0
        .word c_echo
        .word k_echo
        .asc "HIRE"
        .byt "S"|$80,0
        .word c_hires
        .word k_hires
        .asc "SPLI"
        .byt "T"|$80,0
        .word c_split
        .word k_split
        .asc "TEX"
        .byt "T"|$80,0
        .word c_text
        .word k_text
        .asc "GLOA"
        .byt "D"|$80,0
        .word c_gload
        .word k_gload
        .asc "GSAV"
        .byt "E"|$80,0
        .word c_gsave
        .word k_gsave
        .asc "EN"
        .byt "D"|$80,0
        .word c_end
        .word k_end
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
m_big   .asc "Fichier trop gros",0
m_expr  .asc "expression ?",0
m_range .asc "valeur hors de 0-255",0
m_var   .asc "variable ? (A a Z)",0
m_div   .asc "division par zero",0
m_deep  .asc "trop de blocs imbriques",0
m_step  .asc "pas nul",0
m_nofor .asc "NEXT sans boucle",0
m_nonext .asc "NEXT manquant",0
m_open  .asc "bloc non ferme",0
m_struct .asc "fin de bloc en trop",0
m_noret .asc "RETURN sans CALL",0
m_nosub .asc "SUB introuvable",0

sfcb    .dsb 36,0
ifcb    .dsb 36,0
par_lo  .dsb NPAR,0
par_hi  .dsb NPAR,0
par_len .dsb NPAR,0
word    .dsb 9,0
kw      .dsb 9,0
cname   .dsb 9,0
numbuf  .dsb 8,0
fvar    .byt 0
ofcb    .dsb 36,0
flim    .word 0
fstep   .word 0

#include "hires.inc"

; tampons après les tables de hires.inc
vars    = h_free        ; A à Z (2 octets chacune)
cs_t    = vars+52       ; pile de contrôle : type
cs_v    = cs_t+NCS      ;   variable (FOR)
cs_pl   = cs_v+NCS      ;   ligne de reprise
cs_ph   = cs_pl+NCS
cs_al   = cs_ph+NCS     ;   compte (REPEAT) ou arrivée (FOR)
cs_ah   = cs_al+NCS
cs_bl   = cs_ah+NCS     ;   pas (FOR)
cs_bh   = cs_bl+NCS
vs_lo   = cs_bh+NCS     ; pile des valeurs
vs_hi   = vs_lo+NVS
vs_f    = vs_hi+NVS     ; (traduction : gauche constante ?)
obuf    = vs_f+NVS      ; NOM.ASM : enregistrement en cours
rawbuf  = obuf+128
lbuf    = rawbuf+LMAX+1
ptext   = lbuf+LMAX+1   ; texte du fichier, jusqu'à PTOP
