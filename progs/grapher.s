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
        adc #4                  ; dernière lettre, classe, adresse
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
        jmp assign
cmd     jsr lookup
        bcs bad
        iny
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
        cmp #"&"
        bne or
        lda et
        and ev
        sta ev
        lda et+1
        and ev+1
        sta ev+1
        jmp loop
or      lda et
        ora ev
        sta ev
        lda et+1
        ora ev+1
        sta ev+1
        jmp loop
r       rts
.)

; = <> < <= > >= : 1 si vrai, 0 sinon
e_cmp
.(
        jsr e_sum
        jsr ws
        jsr gch
        ldx #1
        cmp #"="
        beq one
        cmp #"<"
        beq lt
        cmp #">"
        beq gt
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
        pha
        jsr pushv
        jsr ws
        jsr e_sum
        jsr popt
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
        pla
        tax
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
        cmp #"+"
        bne sub
        clc
        lda et
        adc ev
        sta ev
        lda et+1
        adc ev+1
        sta ev+1
        jmp loop
sub     sec
        lda et
        sbc ev
        sta ev
        lda et+1
        sbc ev+1
        sta ev+1
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
        cmp #"*"
        bne div
        jsr mul16
        jmp loop
div     pha
        jsr sdiv
        pla
        cmp #"/"
        beq loop                ; quotient dans ev
        lda mr                  ; %
        sta ev
        lda mr+1
        sta ev+1
        jmp loop
r       rts
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
        jmp close               ; (close redescend edep)
nopar   cmp #"0"
        bcc id
        cmp #"9"+1
        bcs id
        lda #0                  ; nombre décimal
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
id      ldx #0                  ; nom : variable (une lettre) ou fonction
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
        cpx #1
        bne func
        lda kw                  ; variable
        sec
        sbc #"A"
        asl
        tay
        lda vars,y
        sta ev
        lda vars+1,y
        sta ev+1
        rts
func    ldy #0                  ; recherche dans les fonctions
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
        lda fnames+1,y          ; numéro de la fonction
        beq f_rnd
        cmp #1
        beq f_abs
        cmp #2
        beq f_point
        jmp f_inkey
fskip   lda fnames,y            ; nom suivant
        iny
        cmp #" "
        bne fskip
        iny
        jmp fl
bad     jmp e_expr

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
f_point jsr open
        jsr e_or                ; x
        jsr pushv
        jsr ws
        jsr gch
        cmp #","
        bne bad
        inc ex
        jsr e_or                ; y
        jsr close
        jsr popt
        lda h_lines             ; pas d'image : 0
        beq zero
        lda et+1
        ora ev+1
        bne zero
        lda et
        sta h_x1
        lda ev
        sta h_y1
        jsr h_point
        sta ev
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

; arg1 : (expression)
arg1    jsr open
        jsr e_or
        jmp close
open    jsr ws
        jsr gch
        cmp #"("
        bne bad2
        inc ex
        inc edep
        rts
close   jsr ws
        jsr gch
        cmp #")"
        bne bad2
        inc ex
        dec edep
        rts
bad2    jmp e_expr
.)

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
.(
        jsr skipsp
        ldy #0                  ; nom cherché -> cname
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
        lda #T_CALL             ; trouvé : retour à la ligne après CALL
        jsr cs_push
        jsr body
        lda sk                  ; corps : ligne après SUB NOM
        sta nxt
        lda sk+1
        sta nxt+1
        rts
unk     lda #<m_nosub
        ldy #>m_nosub
        jmp error
bad     jmp e_param
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
; adresse ; les plus fréquentes d'abord (la recherche est séquentielle)
; ---------------------------------------------------------------------
cmds
        .asc "NEX"
        .byt "T"|$80,K_NEXT
        .word c_next
        .asc "I"
        .byt "F"|$80,K_IF
        .word c_if
        .asc "ENDI"
        .byt "F"|$80,K_ENDIF
        .word c_endif
        .asc "ELS"
        .byt "E"|$80,K_ELSE
        .word c_else
        .asc "PLO"
        .byt "T"|$80,0
        .word c_plot
        .asc "LIN"
        .byt "E"|$80,0
        .word c_line
        .asc "LE"
        .byt "T"|$80,0
        .word c_let
        .asc "FO"
        .byt "R"|$80,K_LOOP
        .word c_for
        .asc "REPEA"
        .byt "T"|$80,K_LOOP
        .word c_repeat
        .asc "WHIL"
        .byt "E"|$80,K_LOOP
        .word c_while
        .asc "CAL"
        .byt "L"|$80,0
        .word c_call
        .asc "ENDSU"
        .byt "B"|$80,K_ENDS
        .word c_return
        .asc "RETUR"
        .byt "N"|$80,0
        .word c_return
        .asc "SU"
        .byt "B"|$80,K_SUB
        .word c_sub
        .asc "BO"
        .byt "X"|$80,0
        .word c_box
        .asc "FBO"
        .byt "X"|$80,0
        .word c_fbox
        .asc "CIRCL"
        .byt "E"|$80,0
        .word c_circle
        .asc "PE"
        .byt "N"|$80,0
        .word c_pen
        .asc "GTEX"
        .byt "T"|$80,0
        .word c_gtext
        .asc "GNU"
        .byt "M"|$80,0
        .word c_gnum
        .asc "ATT"
        .byt "R"|$80,0
        .word c_attr
        .asc "GCL"
        .byt "S"|$80,0
        .word c_gcls
        .asc "PRIN"
        .byt "T"|$80,0
        .word c_print
        .asc "DELA"
        .byt "Y"|$80,0
        .word c_delay
        .asc "WAI"
        .byt "T"|$80,0
        .word c_wait
        .asc "ECH"
        .byt "O"|$80,0
        .word c_echo
        .asc "HIRE"
        .byt "S"|$80,0
        .word c_hires
        .asc "SPLI"
        .byt "T"|$80,0
        .word c_split
        .asc "TEX"
        .byt "T"|$80,0
        .word c_text
        .asc "GLOA"
        .byt "D"|$80,0
        .word c_gload
        .asc "GSAV"
        .byt "E"|$80,0
        .word c_gsave
        .asc "EN"
        .byt "D"|$80,0
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
rawbuf  = vs_hi+NVS
lbuf    = rawbuf+LMAX+1
ptext   = lbuf+LMAX+1   ; texte du fichier, jusqu'à PTOP
