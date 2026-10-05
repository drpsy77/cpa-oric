; =====================================================================
;  LOGO.COM — Logo en français pour CP/A (mode SPLIT)
;
;  La tortue dessine dans l'image (240 x 128) ; on tape les commandes
;  sous l'image. Nombres entiers (16 bits signés) et décimaux « à la Oric »
;  (5 octets, fp_inc.s) : un calcul passe en décimal quand il le faut.
;
;  Valeurs typées : une valeur occupe 6 octets, un octet de type (T_INT,
;  T_DEC ; mot et liste prévus) et 5 octets de contenu.
;  La valeur courante est dans vt/val ; l'évaluateur range les valeurs
;  intermédiaires sur une pile de valeurs (vstack), pas sur la pile du
;  6502. Variables et paramètres gardent une valeur complète.
;
;  Commandes : AVANCE/AV, RECULE/RE, DROITE/DR, GAUCHE/GA, LEVECRAYON/LC,
;  BAISSECRAYON/BC, GOMME, INVERSE, CACHETORTUE/CT, MONTRETORTUE/MT,
;  VIDEECRAN/VE, NETTOIE, ORIGINE, FIXECAP, FIXEXY, ECRANTEXTE, ECRANMIXTE,
;  REPETE, SI, STOP, RENDS,
;  ECRIS/EC, DONNE, ATTENDS, POUR...FIN, SAUVE, CHARGE, EDITE, TITRES, LISTE,
;  OUBLIE, OUBLIETOUT, AIDE, QUITTE/AUREVOIR
;  Opérations : + - * / ( ) = < > HASARD CAP XCOR YCOR LISCAR TOUCHE?
;  LISLISTE LISMOT ASCII CAR
;  ENT ARRONDI ABS QUOTIENT RESTE
;
;  L'interpréteur lit directement le texte (lignes tapées, corps des
;  procédures). Les listes [ ] et les procédures s'exécutent grâce à une
;  pile de contextes en mémoire : pas de récursion sur la pile du 6502,
;  ce qui permet des procédures récursives profondes. Une procédure
;  appelée dans une expression (fonction, RENDS) fait tourner une boucle
;  d'exécution depuis l'évaluateur : la pile du 6502 des expressions en
;  attente est alors rangée dans une zone à part (spill, call_func).
; =====================================================================

#include "cpa.inc"

; --- page zéro ---
tp      = $10           ; position de lecture
tend    = $12           ; fin du texte en cours
tokst   = $14           ; début du jeton courant
tnam    = $16           ; nom du jeton (mot, :var, "mot)
tlen    = $18
ttype   = $19
tnum    = $1A           ; valeur d'un nombre / caractère d'un opérateur
p1      = $1C
p2      = $1E
p3      = $20
tmp     = $24
tmp2    = $26
fsp     = $28           ; pile de contextes
fbase   = $2A
nloc    = $2C           ; variables locales
ngl     = $2D           ; variables globales
ma      = $2E
mb      = $30
mr      = $32           ; 4 octets
tx      = $36           ; position de la tortue : 3 octets (1/256, bas, haut)
ty      = $39
head    = $3C           ; cap en degrés (0 = haut, sens horaire), + headf
x0      = $3E           ; coordonnées écran 16 bits signées
y0      = $40
x1      = $42
y1      = $44
pdown   = $46
pmode   = $47
tvis    = $48
stopf   = $49
defmode = $4A
pend    = $4B           ; fin de la zone des procédures
memtop  = $4D
lsx     = $4F
lsy     = $50
lerr    = $51
le2     = $53
ldx_    = $55
ldy_    = $57
ridx    = $59
reof    = $5A
nargs   = $5B
sign    = $5C
rnd     = $5D
savsp   = $5F
cname   = $60           ; nom de la commande en cours (adresse, longueur)
clen    = $62
tdrawn  = $63
fmark   = $64
ang     = $67
wp      = $69           ; écriture d'une procédure
rstart  = $6B
lstart  = $6D
lend    = $6F
cnt     = $71
hdr     = $73
hend    = $75
pcount  = $77
val     = $78           ; valeur courante : contenu (5 octets)
vt      = $7D           ; et son type (T_INT...)
lvt     = $7E           ; valeur de gauche d'une opération : type
lv      = $7F           ;   et contenu (5 octets)
vsp     = $84           ; pile de valeurs (2 octets)
pkey    = $86           ; touche lue par check_esc, gardée pour LISCAR
opc     = $87           ; opérateur en cours
nst     = $88           ; début du nombre lu (2 octets)
tnt     = $8A           ; type du nombre lu : T_INT (tnum) ou T_DEC (tnf)
tnf     = $8B           ; nombre décimal lu (5 octets)
FP_ZP   = $90           ; page zéro de fp_inc.s ($90-$BF)
sf      = $22           ; sinm : fraction de l'angle (1/256 de degré)
sd      = $23           ; mul_ds : signe du résultat
sone    = $0F           ; sinm : 1 si |sinus| = 1
hp      = $00           ; bas du tas des textes (2 octets)
hn      = $02           ; halloc : taille demandée (2)
hptr    = $04           ;   bloc obtenu (2)
gtop    = $06           ; gc : haut de la partie compactée (2)
glim    = $08           ;   bas du tas avant compactage (2)
gbest   = $0A           ;   texte choisi (2)
glen    = $0C           ;   et sa longueur (2)
gfnd    = $0E           ;   1 si un texte a été trouvé
dp      = $D0           ; dscan : valeur visitée (2)
dcnt    = $D2
dstr    = $D3
gdst    = $D4           ; gc : nouvelle adresse du texte (2)
cbv     = $D6           ; dscan : routine appelée (2)
ts      = $D8           ; texte source (2)
tl      = $DA           ; longueur (2)
td      = $DC           ; destination (2)
capf    = $DE           ; bit 7 : putc écrit dans nbuf
ncap    = $DF           ;   nombre de caractères écrits
scp     = $2E           ; parcours d'une liste (ma) : position
sce     = $30           ;   fin (mb)
els     = $32           ;   début de l'élément (mr)
eln     = $34           ;   longueur de l'élément (mr+2)
elo     = $20           ;   écart depuis le début du texte (p3)
headf   = $C0           ; fraction du cap (1/256 de degré)
angf    = $C1           ; fraction de l'angle ang
dst3    = $C2           ; distance en virgule fixe (1/256, bas, haut)
fxv     = $C5           ; nombre en virgule fixe (1/256, bas, haut)
gx      = $C8           ; FIXEXY : x en virgule fixe (3 octets)
mp      = $CB           ; produit de mul_ds (5 octets, jusqu'à $CF)

TK_END  = 0
TK_NUM  = 1
TK_WORD = 2
TK_VAR  = 3
TK_QUOTE = 4
TK_LBR  = 5
TK_RBR  = 6
TK_OP   = 7

FR_SIZE = 12            ; contexte : type, retour(2), fin(2), début liste(2),
FR_REP  = 1             ;   fin liste(2), compteur(2), marque des locales
FR_LIST = 2
FR_PROC = 3
FR_EXEC = 4             ; EXECUTE : compteur = xsp à rendre
FR_FUNC = 5             ; procédure appelée dans une expression (RENDS)
                        ;   FR_PROC et FR_FUNC : compteur = enregistrement
VAR_SIZE = 16           ; variable : nom (10 octets), valeur (6)
NAMELEN = 10
VAL_SIZE = 6            ; valeur : type (1), contenu (5)
VS_N    = 40            ; profondeur de la pile de valeurs
T_INT   = 1             ; entier 16 bits signé (contenu : 2 octets)
T_DEC   = 2             ; décimal « à la Oric » (5 octets, fp_inc.s)
T_WORD  = 3             ; mot : adresse et longueur d'un texte du tas
T_LIST  = 4             ; liste : idem (éléments séparés par une espace)
MAXLOC  = 100
MAXGL   = 32
MAXPAR  = 8

CR      = $0D
LF      = $0A

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
.(
        cld
        ldx #F_GFX              ; il faut le mode SPLIT
        lda #<gq_get
        ldy #>gq_get
        jsr BDOS
        bne ok
        ldx #F_GFX
        lda #<gq_split
        ldy #>gq_split
        jsr BDOS
ok      lda #<procbase
        sta pend
        lda #>procbase
        sta pend+1
        lda TPA_TOP
        sta memtop
        sta hp                  ; tas des textes vide
        lda TPA_TOP+1
        sta memtop+1
        sta hp+1
        lda #0
        sta capf
        sta tmode
        sta autold
        sta nloc
        sta ngl
        sta defmode
        sta stopf
        sta tdrawn
        lda SYS_TICKS
        sta rnd
        ora #1
        sta rnd+1
        lda #1
        sta tvis
        sta pdown
        sta pmode
        jsr set_pen
        jsr home
        lda #<lg_bar
        ldy #>lg_bar
        jsr B_MENUBAR
        lda #<m_banner
        ldy #>m_banner
        jsr puts
        jsr args                ; LOGO NOM : charge NOM.LOG ; /R : retour d'EDIT
.)
repl
        tsx                     ; point de reprise en cas d'erreur
        stx savsp
        jsr reset_frames
        lda tvis
        beq rp1
        jsr turtle_show
rp1     lda #<m_prompt
        ldy #>m_prompt
        ldx defmode
        beq rp2
        lda #<m_prompt2
        ldy #>m_prompt2
rp2     jsr puts
        lda #0                  ; touche non lue par le programme : oubliée
        sta pkey
        lda autold              ; ligne préparée au démarrage (CHARGE) ?
        beq rp3
        jsr auto_line
        jmp rp4
rp3     lda #126
        sta lbuf
        ldx #10
        lda #<lbuf
        ldy #>lbuf
        jsr BDOS
rp4     jsr crlf
        jsr turtle_hide
        ldx lbuf+1
        lda #0
        sta lbuf+2,x
        lda #<(lbuf+2)
        sta p1
        lda #>(lbuf+2)
        sta p1+1
        jsr do_line
        jmp repl

reset_frames
        lda #<frames
        sta fsp
        sta fbase
        lda #>frames
        sta fsp+1
        sta fbase+1
        lda #<vstack
        sta vsp
        lda #>vstack
        sta vsp+1
        lda #<xstack
        sta xsp
        lda #>xstack
        sta xsp+1
        lda #<spill             ; aucune fonction en cours
        sta ssp
        lda #>spill
        sta ssp+1
        rts

; error : message A/Y, retour au prompt
error
        pha
        tya
        pha
        jsr crlf_if
        pla
        tay
        pla
        jsr puts
        lda clen
        beq er1
        lda #" "
        jsr putc
        jsr put_cname
er1     jsr crlf
        lda defmode             ; définition en cours abandonnée
        beq er2
        lda #0
        sta defmode
er2     lda #0
        sta nloc
        sta stopf
        ldx savsp
        txs
        jmp repl

; ---------------------------------------------------------------------
; Traitement d'une ligne (p1 -> texte terminé par 0)
; ---------------------------------------------------------------------
do_line
.(
        jsr upper_line
        lda defmode
        beq notdef
        ; en définition : FIN termine, sinon la ligne s'ajoute
        jsr first_word
        lda #<w_fin
        ldy #>w_fin
        jsr word_is
        bne add
        jmp def_end
add     jmp def_add
notdef  jsr first_word
        lda #<w_pour
        ldy #>w_pour
        jsr word_is
        bne exec
        jmp def_start
exec    ; exécution : le texte va de p1 à la fin de la ligne
        lda p1
        sta tp
        lda p1+1
        sta tp+1
        jsr strend
        lda #0
        sta clen
        jsr advance
        jmp run
.)

; strend : tend = fin de la chaîne p1
strend
.(
        ldy #0
loop    lda (p1),y
        beq done
        iny
        bne loop
done    tya
        clc
        adc p1
        sta tend
        lda p1+1
        adc #0
        sta tend+1
        rts
.)

upper_line
.(
        ldy #0
loop    lda (p1),y
        beq done
        cmp #"a"
        bcc nx
        cmp #"z"+1
        bcs nx
        and #$DF
        sta (p1),y
nx      iny
        bne loop
done    rts
.)

; first_word : premier mot de la ligne p1 -> tnam/tlen
first_word
.(
        lda p1
        sta tp
        lda p1+1
        sta tp+1
        jsr strend
        jsr advance
        lda ttype
        cmp #TK_WORD
        beq r
        lda #0
        sta tlen
r       rts
.)

; word_is : Z=1 si le jeton (tnam/tlen) vaut la chaîne A/Y
word_is
.(
        sta p3
        sty p3+1
        ldy #0
loop    cpy tlen
        beq endw
        lda (p3),y
        beq no
        cmp (tnam),y
        bne no
        iny
        bne loop
endw    lda (p3),y              ; la chaîne doit finir aussi
        rts
no      lda #1
        rts
.)

; ---------------------------------------------------------------------
; Lecture des jetons
; ---------------------------------------------------------------------
inc_tp
        inc tp
        bne itp
        inc tp+1
itp     rts

; at_end : C=1 si tp >= tend
at_end
        lda tp+1
        cmp tend+1
        bne ae1
        lda tp
        cmp tend
ae1     rts

advance
.(
skip    jsr at_end
        bcs end
        ldy #0
        lda (tp),y
        cmp #" "+1
        bcs nonws
        jsr inc_tp
        jmp skip
end     lda tp
        sta tokst
        lda tp+1
        sta tokst+1
        lda #TK_END
        sta ttype
        rts
nonws   ldx tp
        stx tokst
        ldx tp+1
        stx tokst+1
        cmp #"["
        bne n1
        lda #TK_LBR
        bne single
n1      cmp #"]"
        bne n2
        lda #TK_RBR
        bne single
n2      jsr is_op
        bne n3
        cmp #"-"
        bne isop
        jsr neg_literal         ; « -5 » précédé d'un blanc : nombre négatif
        bcs isop0
        rts
isop0   lda #"-"
isop    sta tnum
        lda #TK_OP
single  sta ttype
        jmp inc_tp
n3      cmp #":"
        bne n4
        jsr inc_tp
        jsr scan_word
        lda #TK_VAR
        sta ttype
        rts
n4      cmp #$22
        bne n5
        jsr inc_tp
        jsr scan_qword
        lda #TK_QUOTE
        sta ttype
        rts
n5      cmp #"0"
        bcc word
        cmp #"9"+1
        bcs word
        jmp scan_num
word    jsr scan_word
        lda #TK_WORD
        sta ttype
        rts
.)

; neg_literal : tp sur un « - » ; si un chiffre suit et qu'un blanc (ou [ ou ()
;   précède, lit le nombre négatif (C=0), sinon C=1
neg_literal
.(
        ldy #1
        lda (tp),y
        cmp #"0"
        bcc no
        cmp #"9"+1
        bcs no
        sec
        lda tp
        sbc #1
        sta tmp
        lda tp+1
        sbc #0
        sta tmp+1
        ldy #0
        lda (tmp),y
        cmp #" "+1
        bcc yes
        cmp #"["
        beq yes
        cmp #"("
        bne no
yes     jsr inc_tp
        jsr scan_num
        lda tnt
        cmp #T_INT
        bne d
        sec
        lda #0
        sbc tnum
        sta tnum
        lda #0
        sbc tnum+1
        sta tnum+1
        clc
        rts
d       lda tnf                 ; décimal : bit de signe (sauf zéro)
        beq r
        lda tnf+1
        eor #$80
        sta tnf+1
r       clc
        rts
no      sec
        rts
.)

; scan_num : lit un nombre en tp -> jeton TK_NUM. Entier (tnt = T_INT,
;   tnum) s'il tient sur 16 bits sans point ni exposant ; sinon décimal
;   (tnt = T_DEC, tnf : 5 octets), lu par fp_parse
scan_num
.(
        lda tp                  ; début du nombre
        sta nst
        lda tp+1
        sta nst+1
        lda #0
        sta tnum
        sta tnum+1
num     jsr at_end
        bcs ndone
        ldy #0
        lda (tp),y
        cmp #"."
        beq flt
        cmp #"E"
        beq ex
        sec
        sbc #"0"
        cmp #10
        bcs ndone
        pha
        lda tnum+1              ; plus de 3276 (ou 3276 puis 8, 9) :
        cmp #>3276              ; ne tient plus sur 16 bits
        bcc ok
        bne big
        lda tnum
        cmp #<3276
        bcc ok
        bne big
        pla
        pha
        cmp #8
        bcs big
ok      lda tnum                ; tnum = tnum * 10 + chiffre
        sta tmp
        lda tnum+1
        sta tmp+1
        asl tnum
        rol tnum+1
        asl tnum
        rol tnum+1
        clc
        lda tnum
        adc tmp
        sta tnum
        lda tnum+1
        adc tmp+1
        sta tnum+1
        asl tnum
        rol tnum+1
        pla
        clc
        adc tnum
        sta tnum
        bcc nn
        inc tnum+1
nn      jsr inc_tp
        jmp num
big     pla
flt     jmp scan_dec
ex      ldy #1                  ; E, [+ -], chiffre : exposant
        lda (tp),y
        cmp #"+"
        beq e1
        cmp #"-"
        bne e2
e1      iny
e2      lda (tp),y
        sec
        sbc #"0"
        cmp #10
        bcc flt
ndone   lda #T_INT
        sta tnt
        lda #TK_NUM
        sta ttype
        rts
.)

; scan_dec : relit le nombre depuis nst avec fp_parse -> tnf
scan_dec
        lda nst
        sta fpt
        lda nst+1
        sta fpt+1
        jsr fp_parse            ; FAC ; Y = caractères lus
        tya
        clc
        adc nst
        sta tp
        lda nst+1
        adc #0
        sta tp+1
        lda #<tnf
        sta fpt
        lda #>tnf
        sta fpt+1
        jsr fp_stfac
        lda #T_DEC
        sta tnt
        lda #TK_NUM
        sta ttype
        rts

; scan_word : tnam = tp, avance tant que le caractère fait partie d'un mot
scan_word
.(
        lda tp
        sta tnam
        lda tp+1
        sta tnam+1
        lda #0
        sta tlen
loop    jsr at_end
        bcs done
        ldy #0
        lda (tp),y
        cmp #" "+1
        bcc done
        cmp #"["
        beq done
        cmp #"]"
        beq done
        cmp #":"
        beq done
        cmp #$22
        beq done
        jsr is_op
        beq done
        inc tlen
        jsr inc_tp
        jmp loop
done    rts
.)

; scan_qword : mot après un guillemet : jusqu'à un blanc, [ ou ] (il peut
;   contenir - + . etc. : "-3.5 est un mot)
scan_qword
.(
        lda tp
        sta tnam
        lda tp+1
        sta tnam+1
        lda #0
        sta tlen
loop    jsr at_end
        bcs done
        ldy #0
        lda (tp),y
        cmp #" "+1
        bcc done
        cmp #"["
        beq done
        cmp #"]"
        beq done
        inc tlen
        jsr inc_tp
        jmp loop
done    rts
.)

; is_op : Z=1 si A est un opérateur (A préservé)
is_op
.(
        ldx #8
loop    cmp ops,x
        beq r
        dex
        bpl loop
        ldx #1                  ; Z=0
r       rts
ops     .asc "+-*/=<>()"
.)

; ---------------------------------------------------------------------
; Boucle d'exécution
; ---------------------------------------------------------------------
run
.(
loop    lda stopf
        beq ns
        jsr do_stop
ns      lda ttype
        bne instr
        lda fsp                 ; fin du texte en cours
        cmp fbase
        bne pop
        lda fsp+1
        cmp fbase+1
        bne pop
        rts
pop     jsr frame_end
        jmp loop
instr   jsr check_esc
        jsr instruction
        jmp loop
.)

; frame_end : la liste ou la procédure en cours est terminée
frame_end
.(
        jsr top_frame           ; p1 = contexte du dessus
        ldy #0
        lda (p1),y
        cmp #FR_REP
        bne pop
        ldy #9                  ; REPETE : compteur - 1
        lda (p1),y
        sec
        sbc #1
        sta (p1),y
        iny
        lda (p1),y
        sbc #0
        sta (p1),y
        dey
        ora (p1),y
        beq pop
        ldy #5                  ; recommence la liste
        lda (p1),y
        sta tp
        iny
        lda (p1),y
        sta tp+1
        iny
        lda (p1),y
        sta tend
        iny
        lda (p1),y
        sta tend+1
        jmp advance
pop     jmp pop_frame
.)

; top_frame : p1 = fsp - FR_SIZE
top_frame
        sec
        lda fsp
        sbc #FR_SIZE
        sta p1
        lda fsp+1
        sbc #0
        sta p1+1
        rts

; pop_frame : retire le contexte du dessus et reprend la suite
;   (une fonction qui arrive à sa fin sans RENDS est une erreur)
pop_frame
        jsr top_frame
        ldy #0
        lda (p1),y
        cmp #FR_FUNC
        bne pop_p1
        lda #<e_noret
        ldy #>e_noret
        jmp fr_error
; pop_p1 : retire le contexte p1 (le dessus)
pop_p1
        jsr x_rest
        ldy #0
        lda (p1),y
        cmp #FR_PROC            ; FR_PROC et FR_FUNC : les locales
        beq pf0                 ; disparaissent
        cmp #FR_FUNC
        bne pf1
pf0     ldy #11
        lda (p1),y
        sta nloc
pf1     ldy #1
        lda (p1),y
        sta tp
        iny
        lda (p1),y
        sta tp+1
        iny
        lda (p1),y
        sta tend
        iny
        lda (p1),y
        sta tend+1
        lda p1
        sta fsp
        lda p1+1
        sta fsp+1
        jmp advance

; x_rest : si le contexte p1 est un EXECUTE, xsp reprend sa valeur d'avant
x_rest
.(
        ldy #0
        lda (p1),y
        cmp #FR_EXEC
        bne r
        ldy #9
        lda (p1),y
        sta xsp
        iny
        lda (p1),y
        sta xsp+1
r       rts
.)

; push_frame : A = type ; cnt = compteur ; lstart/lend = texte à exécuter
;   le jeton courant (tokst) est la suite à reprendre
push_frame
.(
        pha
        lda fsp+1               ; place ?
        cmp #>frames_end
        bcc ok
        lda fsp
        cmp #<frames_end
        bcc ok
        pla
        lda #<e_deep
        ldy #>e_deep
        jmp error
ok      pla
        ldy #0
        sta (fsp),y
        iny
        lda tokst
        sta (fsp),y
        iny
        lda tokst+1
        sta (fsp),y
        iny
        lda tend
        sta (fsp),y
        iny
        lda tend+1
        sta (fsp),y
        iny
        lda lstart
        sta (fsp),y
        iny
        lda lstart+1
        sta (fsp),y
        iny
        lda lend
        sta (fsp),y
        iny
        lda lend+1
        sta (fsp),y
        iny
        lda cnt
        sta (fsp),y
        iny
        lda cnt+1
        sta (fsp),y
        iny
        lda fmark
        sta (fsp),y
        clc
        lda fsp
        adc #FR_SIZE
        sta fsp
        bcc s1
        inc fsp+1
s1      lda lstart
        sta tp
        lda lstart+1
        sta tp+1
        lda lend
        sta tend
        lda lend+1
        sta tend+1
        jmp advance
.)

; do_stop : STOP sort de la procédure en cours
do_stop
.(
        lda #0
        sta stopf
loop    lda fsp
        cmp fbase
        bne more
        lda fsp+1
        cmp fbase+1
        bne more
        lda #TK_END             ; niveau supérieur : on arrête tout
        sta ttype
        rts
more    jsr top_frame
        ldy #0
        lda (p1),y
        cmp #FR_PROC
        beq pop
        cmp #FR_FUNC            ; STOP dans une fonction : erreur
        bne drop
pop     jmp pop_frame
drop    jsr x_rest
        lda p1
        sta fsp
        lda p1+1
        sta fsp+1
        jmp loop
.)

; check_esc : ESC interrompt l'exécution
;   (une autre touche est gardée dans pkey pour LISCAR et TOUCHE?)
check_esc
        jsr B_CONST
        beq ce_r
        jsr B_CONIN
        cmp #$1B
        beq esc_err
        sta pkey
        rts
esc_err lda #0
        sta clen
        lda #<e_esc
        ldy #>e_esc
        jmp error
ce_r    rts

; ---------------------------------------------------------------------
; Une instruction
; ---------------------------------------------------------------------
instruction
.(
        lda ttype
        cmp #TK_WORD
        beq word
        lda #0
        sta clen
        lda #<e_what
        ldy #>e_what
        jmp error
word    lda tnam                ; mémorise le nom de la commande
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        lda #<prims             ; primitive ?
        ldy #>prims
        jsr lookup
        bcs user
        jsr advance             ; consomme le nom ; le jeton suivant est le 1er argument
        jmp (p3)
user    jmp call_proc
.)

; lookup : cherche le mot tnam/tlen dans la table A/Y (nom, 0, adresse ;
;   0 à la fin). C=0 trouvé, p3 = adresse ; C=1 sinon
lookup
.(
        sta p2
        sty p2+1
find    ldy #0
        lda (p2),y
        beq no
        lda p2
        ldy p2+1
        jsr word_is
        beq found
        ldy #0                  ; entrée suivante : nom, 0, adresse
skip    lda (p2),y
        beq sk2
        iny
        bne skip
sk2     tya
        clc
        adc #3
        adc p2
        sta p2
        bcc find
        inc p2+1
        bne find
found   ldy #0
fz      lda (p2),y
        beq fa
        iny
        bne fz
fa      iny
        lda (p2),y
        sta p3
        iny
        lda (p2),y
        sta p3+1
        clc
        rts
no      sec
        rts
.)

; ---------------------------------------------------------------------
; Expressions (résultat dans vt/val)
;   Deux entiers donnent un entier tant que le résultat tient sur 16 bits ;
;   sinon, ou dès qu'un décimal s'en mêle, le calcul se fait en décimal
;   (fp_inc.s). / donne un décimal si la division ne tombe pas juste.
; ---------------------------------------------------------------------
eval
.(
        jsr sum
        lda ttype
        cmp #TK_OP
        bne r
        lda tnum
        cmp #"="
        beq cmpop
        cmp #"<"
        beq cmpop
        cmp #">"
        bne r
cmpop   pha
        jsr vpush
        jsr advance
        jsr sum
        jsr vpop_l              ; lv = gauche, val = droite
        pla
        cmp #"="
        bne ord
        jsr equal               ; = : nombres ou textes
        bne true
        beq false
ord     pha
        jsr need_num2
        jsr compare             ; A = $FF (<), 0 (=), 1 (>)
        tax
        pla
        cmp #"<"
        beq lt0
        jmp gt
lt0     cpx #$FF
        beq true
false   lda #0
        beq set
true    lda #1
set     sta val
        lda #0
        sta val+1
        lda #T_INT
        sta vt
r       rts
lt      cmp #"<"
        bne gt
        cpx #$FF
        beq true
        bne false
gt      cpx #1
        beq true
        bne false
.)

; compare : A = $FF si gauche < droite, 0 si égales, 1 si gauche > droite
compare
.(
        jsr both_int
        bcs flt
        lda lv
        sta tmp
        lda lv+1
        sta tmp+1
        lda tmp
        cmp val
        bne ne
        lda tmp+1
        cmp val+1
        bne ne
        lda #0
        rts
ne      jsr cmp_s               ; N=1 si tmp < val
        bmi lt
        lda #1
        rts
lt      lda #$FF
        rts
flt     jsr load2               ; ARG = gauche, FAC = droite
        jmp fp_cmp
.)

; cmp_s : N=1 si tmp < val (signé)
cmp_s
        sec
        lda tmp
        sbc val
        lda tmp+1
        sbc val+1
        bvc cs1
        eor #$80
cs1     rts

sum
.(
        jsr term
loop    lda ttype
        cmp #TK_OP
        bne r
        lda tnum
        cmp #"+"
        beq op
        cmp #"-"
        bne r
op      pha
        jsr vpush
        jsr advance
        jsr term
        jsr vpop_l
        jsr need_num2
        pla
        sta opc
        jsr both_int
        bcs flt
        lda opc
        cmp #"+"
        bne minus
        clc
        lda lv
        adc val
        tax
        lda lv+1
        adc val+1
        bvs flt                 ; débordement : en décimal
        sta val+1
        stx val
        jmp loop
minus   sec
        lda lv
        sbc val
        tax
        lda lv+1
        sbc val+1
        bvs flt
        sta val+1
        stx val
        jmp loop
flt     jsr load2
        lda opc
        cmp #"+"
        beq ad
        jsr fp_sub
        jmp st
ad      jsr fp_add
st      jsr fac_val
        jmp loop
r       rts
.)

term
.(
        jsr unary
loop    lda ttype
        cmp #TK_OP
        bne r
        lda tnum
        cmp #"*"
        beq op
        cmp #"/"
        bne r
op      pha
        jsr vpush
        jsr advance
        jsr unary
        jsr vpop_l
        jsr need_num2
        pla
        sta opc
        jsr both_int
        bcs flt
        lda opc
        cmp #"*"
        bne divi
        jsr ld_mamb
        jsr smul                ; mr = produit sur 32 bits
        lda mr+1                ; tient sur 16 bits si mr+2 et mr+3
        and #$80                ; prolongent le signe
        beq p0
        lda #$FF
p0      cmp mr+2
        bne big
        cmp mr+3
        bne big
        lda mr
        sta val
        lda mr+1
        sta val+1
        jmp loop
big     jsr i32_fac             ; produit exact, en décimal
        jsr fac_val
        jmp loop
divi    jsr idiv                ; division entière exacte ?
        bcs flt
        jmp loop
flt     jsr load2
        lda opc
        cmp #"*"
        beq mu
        jsr fp_div
        jmp st
mu      jsr fp_mul
st      jsr fac_val
        jmp loop
r       rts
.)

; ld_mamb : ma = gauche (lv), mb = droite (val)
ld_mamb
        lda lv
        sta ma
        lda lv+1
        sta ma+1
        lda val
        sta mb
        lda val+1
        sta mb+1
        rts

; idiv : val = lv / val (entiers) si la division tombe juste ; C=1 sinon
;   (val inchangée), ou si le diviseur est nul, ou pour -32768 / -1
idiv
.(
        lda val
        ora val+1
        beq no
        lda val
        sta tmp2
        lda val+1
        sta tmp2+1
        jsr ld_mamb
        jsr sdiv
        lda mr+2                ; reste
        ora mr+3
        bne back
        lda sign                ; quotient positif mais bit 15 à 1
        bmi ok
        lda val+1
        bmi back
ok      clc
        rts
back    lda tmp2
        sta val
        lda tmp2+1
        sta val+1
no      sec
        rts
.)

; i32_fac : FAC = mr (entier signé de 32 bits, octet bas en mr)
i32_fac
.(
        ldx #3
c       lda mr,x
        sta ft,x
        dex
        bpl c
        lda ft+3
        bpl pos
        sec
        ldx #0
        ldy #4
n       lda #0
        sbc ft,x
        sta ft,x
        inx
        dey
        bne n
        jsr fp_u32tof
        jmp fp_neg
pos     jmp fp_u32tof
.)

unary
.(
        lda ttype
        cmp #TK_OP
        bne prim
        lda tnum
        cmp #"-"
        bne prim
        jsr advance
        jsr unary
        jmp negate
prim    jmp primary
.)

; negate : val = -val (entier ou décimal ; -(-32768) devient décimal)
negate
.(
        jsr need_num
        lda vt
        cmp #T_INT
        bne d
        lda val+1
        cmp #$80
        bne neg_val
        lda val
        bne neg_val
        ldy val+1               ; -32768 -> 32768 décimal
        jsr fp_itof
        jsr fp_neg
        jmp fac_val
d       lda val                 ; décimal : bit de signe (sauf zéro)
        beq r
        lda val+1
        eor #$80
        sta val+1
r       rts
.)

neg_val
        sec
        lda #0
        sbc val
        sta val
        lda #0
        sbc val+1
        sta val+1
        rts

primary
.(
        lda ttype
        cmp #TK_NUM
        bne n1
        lda tnt
        cmp #T_INT
        bne flt
        lda tnum
        sta val
        lda tnum+1
        sta val+1
        jmp int_adv
flt     ldx #4                  ; nombre décimal du texte
c       lda tnf,x
        sta val,x
        dex
        bpl c
        lda #T_DEC
        sta vt
        jmp advance
n1      cmp #TK_VAR
        bne nq
        jsr get_var
        jmp advance
nq      cmp #TK_QUOTE
        bne nl
        jmp lit_word
nl      cmp #TK_LBR
        bne n2
        jsr need_list
        jmp lit_list
pbad    jmp bad
n2      cmp #TK_OP
        bne n3
        lda tnum
        cmp #"("
        bne pbad
        jsr advance
        jsr eval
        lda ttype
        cmp #TK_OP
        bne pbad
        lda tnum
        cmp #")"
        bne pbad
        jmp advance
n3      cmp #TK_WORD
        bne pbad
        lda #<funcs             ; fonction ?
        ldy #>funcs
        jsr lookup
        bcs unk
        jmp (p3)
unk     lda cname               ; procédure de l'utilisateur : fonction
        pha                     ; (le nom de la commande en cours est
        lda cname+1             ; gardé pour ses messages)
        pha
        lda clen
        pha
        lda tnam
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        jmp call_func
bad     lda #0
        sta clen
        lda #<e_value
        ldy #>e_value
        jmp error
.)

; ---------------------------------------------------------------------
; Fonctions (le jeton courant est leur nom)
; ---------------------------------------------------------------------
f_hasard
        jsr arg1
        jsr to_int
        jmp random

f_cap   lda headf
        sta fxv
        lda head
        sta fxv+1
        lda head+1
        sta fxv+2
        jmp cor
f_xcor  ldx #2
xc      lda tx,x
        sta fxv,x
        dex
        bpl xc
        bmi cor
f_ycor  ldx #2
yc      lda ty,x
        sta fxv,x
        dex
        bpl yc
cor     jsr fix_val
        jmp advance
; int_adv : la valeur courante est un entier ; passe au jeton suivant
int_adv lda #T_INT
        sta vt
        jmp advance

; LISCAR : attend une touche et rend le caractère (mot d'un caractère) ;
;   ESC interrompt
f_liscar
.(
        lda pkey                ; touche déjà lue par check_esc ?
        bne have
        jsr B_CONIN
        cmp #$1B
        bne have
        jmp esc_err
have    ldx #0
        stx pkey
        jsr char_word
        jmp advance
.)

; char_word : valeur courante = mot fait du caractère A
char_word
        sta nbuf
        lda #<nbuf
        sta ts
        lda #>nbuf
        sta ts+1
        lda #1
        sta tl
        lda #0
        sta tl+1
        lda #T_WORD
        jmp mk_text

; ASCII x : code du premier caractère ; CAR n : mot du caractère de code n
f_ascii
.(
        jsr arg1t
        jsr top_txt
        lda #6
        jsr vdrop
        lda tl
        ora tl+1
        bne ok
        jmp err_empty
ok      ldy #0
        lda (ts),y
        sta val
        sty val+1
        lda #T_INT
        sta vt
        rts
.)
f_car
        jsr arg1
        jsr to_int
        lda val
        jmp char_word

; LISLISTE : lit une ligne au clavier -> liste ; LISMOT : -> mot (sans les
;   blancs du début et de la fin). La ligne passe en majuscules.
f_lisliste
        jsr read_ll
        jsr lit_list
        jmp advance
f_lismot
.(
        jsr read_ll
b1      lda lstart              ; blancs du début
        cmp lend
        beq w
        ldy #0
        lda (lstart),y
        cmp #" "+1
        bcs b2
        inc lstart
        bne b1
        inc lstart+1
        jmp b1
b2      ldy #0                  ; blancs de la fin (lstart < lend ici)
        lda lend
        bne b3
        dec lend+1
b3      dec lend
        lda (lend),y
        cmp #" "+1
        bcc b2
        inc lend
        bne w
        inc lend+1
w       sec
        lda lend
        sbc lstart
        sta tl
        lda #0
        sta tl+1
        lda lstart
        sta ts
        lda lstart+1
        sta ts+1
        lda #T_WORD
        jsr mk_text
        jmp advance
.)

; read_ll : lit une ligne (BDOS 10) dans llbuf, en majuscules ;
;   lstart, lend = la ligne
read_ll
.(
        lda #0                  ; une touche tapée avant ne compte pas
        sta pkey
        lda #126
        sta llbuf
        ldx #10
        lda #<llbuf
        ldy #>llbuf
        jsr BDOS
        jsr crlf
        lda #<(llbuf+2)
        sta lstart
        lda #>(llbuf+2)
        sta lstart+1
        clc
        lda lstart
        adc llbuf+1
        sta lend
        lda lstart+1
        adc #0
        sta lend+1
        ldx llbuf+1             ; majuscules
        beq r
up      lda llbuf+1,x
        cmp #"a"
        bcc n
        cmp #"z"+1
        bcs n
        and #$DF
        sta llbuf+1,x
n       dex
        bne up
r       rts
.)

; TOUCHE? : 1 si une touche attend d'être lue par LISCAR, 0 sinon
f_touche
.(
        jsr check_esc           ; lit la touche qui attend (ESC interrompt)
        ldx #0
        lda pkey
        beq z
        inx
z       stx val
        lda #0
        sta val+1
        jmp int_adv
.)

; ENT x : partie entière (vers zéro) ; ARRONDI x : entier le plus proche
f_ent
        jsr arg1
        lda vt
        cmp #T_INT
        beq fe_r
        jsr val_fac
        jsr fp_trunc
        jmp fac_val
f_arrondi
        jsr arg1
        lda vt
        cmp #T_INT
        beq fe_r
        jsr val_fac
        jsr fp_rnd
        jmp fac_val
fe_r    rts

; ABS x
f_abs
.(
        jsr arg1
        lda vt
        cmp #T_INT
        bne d
        lda val+1
        bpl r
        jmp negate
d       lda val+1
        and #$7F
        sta val+1
r       rts
.)

; QUOTIENT a b : division entière (vers zéro)
f_quotient
.(
        jsr arg2
        jsr both_int
        bcs d
        lda val
        ora val+1
        beq d                   ; division par zéro : message de fp_div
        lda val
        sta tmp2
        lda val+1
        sta tmp2+1
        jsr ld_mamb
        jsr sdiv
        lda sign                ; -32768 / -1 : en décimal
        bmi r
        lda val+1
        bpl r
        lda tmp2
        sta val
        lda tmp2+1
        sta val+1
d       jsr load2
        jsr fp_div
        jsr fp_trunc
        jmp fac_val
r       rts
.)

; RESTE a b : a - b * QUOTIENT a b (du signe de a)
f_reste
.(
        jsr arg2
        jsr both_int
        bcs d
        lda val
        ora val+1
        beq d
        jsr ld_mamb
        jsr sdiv                ; reste (valeur absolue) en mr+2
        lda mr+2
        sta val
        lda mr+3
        sta val+1
        lda lv+1
        bpl r
        jmp neg_val
d       jsr load2               ; q = ENT (a / b)
        jsr fp_div
        jsr fp_trunc
        jsr fp_toarg
        jsr val_fac             ; q * b
        jsr fp_mul
        jsr fp_toarg
        jsr lv_fac              ; a - q * b
        jsr fp_swap
        jsr fp_sub
        jmp fac_val
r       rts
.)

;RACINE, EXP, LN, SIN, COS, ARCTAN (angles en degrés) : résultat décimal
f_racine
        lda #<fp_sqrt
        ldy #>fp_sqrt
        bne fmath
f_exp   lda #<fp_exp
        ldy #>fp_exp
        bne fmath
f_ln    lda #<fp_ln
        ldy #>fp_ln
        bne fmath
f_sin   lda #<fp_sind
        ldy #>fp_sind
        bne fmath
f_cos   lda #<fp_cosd
        ldy #>fp_cosd
        bne fmath
f_atn   lda #<fp_atnd
        ldy #>fp_atnd
fmath   pha                     ; routine de fp_inc.s, gardée sur la pile :
        tya                     ; l'argument peut appeler une autre fonction
        pha
        jsr arg1
        jsr val_fac
        pla
        sta p3+1
        pla
        sta p3
        jsr fm_call
        jmp fac_val
fm_call jmp (p3)

; arg1 : lit l'argument d'une fonction ; arg2 : ses deux arguments (lv, val)
arg1    jsr advance
        jsr sum
        jmp need_num
arg2    jsr advance
        jsr sum
        jsr vpush
        jsr sum
        jsr vpop_l
        jmp need_num2

; ---------------------------------------------------------------------
; Valeurs typées
; ---------------------------------------------------------------------
; eval_int : évalue une expression et la ramène à un entier (arrondi)
eval_int
        jsr eval
; to_int : la valeur courante devient un entier (un décimal est arrondi ;
;   erreur s'il dépasse -32768..32767)
to_int
.(
        jsr need_num
        lda vt
        cmp #T_INT
        beq r
        jsr val_fac
        jsr fp_toint
        bcs big
        sta val
        sty val+1
        lda #T_INT
        sta vt
r       rts
big     jmp fp_err_big
.)
; eval_fix : évalue un nombre et le met en virgule fixe dans fxv
;   (1/256, bas, haut ; arrondi au 1/256 ; erreur hors de -32768..32767)
eval_fix
.(
        jsr eval
        jsr need_num
        lda vt
        cmp #T_INT
        bne d
        lda #0
        sta fxv
        lda val
        sta fxv+1
        lda val+1
        sta fxv+2
        rts
d       jsr val_fac
        lda fe
        beq z
        clc                     ; * 256
        adc #8
        bcs big
        sta fe
        jsr fp_rnd
        lda fe
        beq z
        cmp #128+24             ; |x| >= 2^23 : trop grand
        bcs big
        jsr fp_tou32
        lda fm+3
        sta fxv
        lda fm+2
        sta fxv+1
        lda fm+1
        sta fxv+2
        lda fsg
        bpl r
        jmp neg_fx
z       lda #0
        sta fxv
        sta fxv+1
        sta fxv+2
r       rts
big     jmp fp_err_big
.)

; neg_fx : fxv = -fxv
neg_fx
.(
        sec
        ldx #0
        ldy #3
l       lda #0
        sbc fxv,x
        sta fxv,x
        inx
        dey
        bne l
        rts
.)

; fix_val : valeur courante = fxv ; entier s'il n'a pas de fraction, sinon
;   décimal arrondi à 2 décimales (la précision est de 1/256)
fix_val
.(
        lda fxv
        bne d
        lda fxv+1
        sta val
        lda fxv+2
        sta val+1
        lda #T_INT
        sta vt
        rts
d       ldx #2                  ; mr = fxv étendu à 32 bits
c       lda fxv,x
        sta mr,x
        dex
        bpl c
        lda fxv+2
        and #$80
        beq p
        lda #$FF
p       sta mr+3
        jsr i32_fac             ; en 1/256
        jsr fp_toarg
        ldx #2
        jsr fp_ldpow            ; * 100
        jsr fp_mul
        lda fe
        sec
        sbc #8                  ; / 256
        sta fe
        jsr fp_rnd
        jsr fp_toarg
        ldx #2
        jsr fp_ldpow
        jsr fp_div              ; / 100
        jmp fac_val
.)

; truth : A <> 0 si la valeur courante (nombre) n'est pas nulle
truth
.(
        jsr need_num
        lda vt
        cmp #T_INT
        bne d
        lda val
        ora val+1
        rts
d       lda val                 ; exposant d'un décimal : 0 pour zéro
        rts
.)
; need_num : la valeur courante doit être un nombre (entier ou décimal)
need_num
        jsr try_num
        bcs not_num
        rts
; need_num2 : la valeur de gauche (lvt) et la valeur courante aussi
need_num2
        lda lvt
        cmp #T_DEC+1
        bcc need_num
        jsr swap_l
        jsr try_num
        php
        jsr swap_l
        plp
        bcc need_num
not_num lda #0
        sta clen
        lda #<e_notnum
        ldy #>e_notnum
        jmp error

; vpush : empile la valeur courante (vt, val) sur la pile de valeurs
vpush
.(
        lda vsp
        cmp #<vstack_end
        lda vsp+1
        sbc #>vstack_end
        bcc ok
        lda #0
        sta clen
        lda #<e_deep
        ldy #>e_deep
        jmp error
ok      ldy #0
        lda vt
        sta (vsp),y
cp      lda val,y
        iny
        sta (vsp),y
        cpy #VAL_SIZE-1
        bne cp
        clc
        lda vsp
        adc #VAL_SIZE
        sta vsp
        bcc r
        inc vsp+1
r       rts
.)

; vpop_l : dépile une valeur dans lvt, lv
vpop_l
.(
        sec
        lda vsp
        sbc #VAL_SIZE
        sta vsp
        bcs n
        dec vsp+1
n       ldy #0
        lda (vsp),y
        sta lvt
cp      iny
        lda (vsp),y
        sta lvt,y
        cpy #VAL_SIZE-1
        bne cp
        rts
.)

; st_val : range la valeur courante dans l'entrée de variable p2
st_val
.(
        ldy #NAMELEN
        lda vt
        sta (p2),y
        ldx #0
l       iny
        lda val,x
        sta (p2),y
        inx
        cpx #VAL_SIZE-1
        bne l
        rts
.)

; ld_val : valeur courante = valeur de l'entrée de variable p2
ld_val
.(
        ldy #NAMELEN
        lda (p2),y
        sta vt
        ldx #0
l       iny
        lda (p2),y
        sta val,x
        inx
        cpx #VAL_SIZE-1
        bne l
        rts
.)

; put_val : affiche la valeur courante
put_val
.(
        lda vt
        cmp #T_INT
        bne d
        jmp put_num
d       cmp #T_DEC
        bne t
        jsr val_fac
        jmp fp_print
t       jsr txt_v               ; mot ou liste : ses caractères
l       lda tl
        ora tl+1
        beq r
        ldy #0
        lda (ts),y
        jsr putc
        inc ts
        bne a1
        inc ts+1
a1      lda tl
        bne a2
        dec tl+1
a2      dec tl
        jmp l
r       rts
.)

; both_int : C=0 si la valeur de gauche et la valeur courante sont entières
both_int
.(
        lda lvt
        cmp #T_INT
        bne n
        lda vt
        cmp #T_INT
        bne n
        clc
        rts
n       sec
        rts
.)

; val_fac : FAC = valeur courante ; lv_fac : FAC = valeur de gauche
val_fac
.(
        lda vt
        cmp #T_INT
        bne d
        lda val
        ldy val+1
        jmp fp_itof
d       lda #<val
        sta fpt
        lda #>val
        sta fpt+1
        jmp fp_ldfac
.)
lv_fac
.(
        lda lvt
        cmp #T_INT
        bne d
        lda lv
        ldy lv+1
        jmp fp_itof
d       lda #<lv
        sta fpt
        lda #>lv
        sta fpt+1
        jmp fp_ldfac
.)
; load2 : ARG = valeur de gauche, FAC = valeur courante
load2   jsr lv_fac
        jsr fp_toarg
        jmp val_fac
; fac_val : valeur courante = FAC (décimal)
fac_val lda #<val
        sta fpt
        lda #>val
        sta fpt+1
        jsr fp_stfac
        lda #T_DEC
        sta vt
        rts

; fp_err_big, fp_err_div : erreurs de fp_inc.s
fp_err_big
        lda #<e_big
        ldy #>e_big
        bne fpe
fp_err_div
        lda #<e_div
        ldy #>e_div
        bne fpe
fp_err_dom
        lda #<e_dom
        ldy #>e_dom
fpe     ldx #0
        stx clen
        jmp error

; random : val = nombre au hasard entre 0 et val-1
random
.(
        lda val
        ora val+1
        beq r
        lda rnd                 ; générateur xorshift 16 bits
        asl
        lda rnd+1
        rol
        eor rnd
        sta rnd
        lda rnd+1
        lsr
        eor rnd
        sta rnd+1
        lda rnd
        eor SYS_TICKS
        sta ma
        lda rnd+1
        and #$7F
        sta ma+1
        lda val
        sta mb
        lda val+1
        sta mb+1
        jsr udivmod             ; reste dans mr+2
        lda mr+2
        sta val
        lda mr+3
        sta val+1
r       rts
.)

; ---------------------------------------------------------------------
; Arithmétique
; ---------------------------------------------------------------------
; smul : mr (32 bits) = ma * mb (signés)
smul
.(
        lda ma+1
        eor mb+1
        sta sign
        lda ma+1
        bpl a_ok
        sec
        lda #0
        sbc ma
        sta ma
        lda #0
        sbc ma+1
        sta ma+1
a_ok    lda mb+1
        bpl b_ok
        sec
        lda #0
        sbc mb
        sta mb
        lda #0
        sbc mb+1
        sta mb+1
b_ok    lda #0
        sta mr
        sta mr+1
        sta mr+2
        sta mr+3
        ldx #16
loop    lsr mb+1
        ror mb
        bcc nadd
        clc
        lda mr+2
        adc ma
        sta mr+2
        lda mr+3
        adc ma+1
        sta mr+3
nadd    ror mr+3
        ror mr+2
        ror mr+1
        ror mr
        dex
        bne loop
        lda sign
        bpl r
        sec
        ldx #0
        ldy #4
neg     lda #0
        sbc mr,x
        sta mr,x
        inx
        dey
        bne neg
r       rts
.)

; udivmod : ma / mb (non signés) -> quotient ma, reste mr+2
udivmod
.(
        lda #0
        sta mr+2
        sta mr+3
        ldx #16
loop    asl ma
        rol ma+1
        rol mr+2
        rol mr+3
        sec
        lda mr+2
        sbc mb
        tay
        lda mr+3
        sbc mb+1
        bcc no
        sta mr+3
        sty mr+2
        inc ma
no      dex
        bne loop
        rts
.)

; sdiv : val = ma / mb (signés)
sdiv
.(
        lda mb
        ora mb+1
        bne ok
        lda #0
        sta clen
        lda #<e_div
        ldy #>e_div
        jmp error
ok      lda ma+1
        eor mb+1
        sta sign
        lda ma+1
        bpl a1
        sec
        lda #0
        sbc ma
        sta ma
        lda #0
        sbc ma+1
        sta ma+1
a1      lda mb+1
        bpl b1
        sec
        lda #0
        sbc mb
        sta mb
        lda #0
        sbc mb+1
        sta mb+1
b1      jsr udivmod
        lda ma
        sta val
        lda ma+1
        sta val+1
        lda sign
        bpl r
        jmp neg_val
r       rts
.)

; ---------------------------------------------------------------------
; Variables
; ---------------------------------------------------------------------
; find_var : cherche le nom tnam/tlen ; C=0 trouvé, p2 -> entrée
find_var
.(
        ldx nloc                ; locales, de la plus récente à la plus ancienne
lloop   dex
        bmi glob
        txa
        pha
        lda #<locals
        ldy #>locals
        jsr entry_addr
        pla
        tax
        jsr name_eq
        bne lloop
        clc
        rts
glob    ldx ngl
gloop   dex
        bmi nf
        txa
        pha
        lda #<globals
        ldy #>globals
        jsr entry_addr
        pla
        tax
        jsr name_eq
        bne gloop
        clc
        rts
nf      sec
        rts
.)

; entry_addr : p2 = A/Y + X * 12
entry_addr
        sta p2
        sty p2+1
        txa
        beq ea_r
ea1     clc
        lda p2
        adc #VAR_SIZE
        sta p2
        bcc ea2
        inc p2+1
ea2     dex
        bne ea1
ea_r    rts

; name_eq : Z=1 si l'entrée p2 a le nom tnam/tlen (10 caractères au plus)
name_eq
.(
        ldy #0
loop    cpy #NAMELEN
        beq yes
        cpy tlen
        beq endn
        lda (tnam),y
        cmp (p2),y
        bne no
        iny
        bne loop
endn    lda (p2),y              ; le nom de l'entrée doit finir
        rts
yes     lda #0
        rts
no      lda #1
        rts
.)

; set_name : copie tnam/tlen dans l'entrée p2 (complété par des 0)
set_name
.(
        ldy #0
loop    cpy tlen
        bcs pad
        lda (tnam),y
        sta (p2),y
        iny
        cpy #NAMELEN
        bne loop
        rts
pad     lda #0
p1l     sta (p2),y
        iny
        cpy #NAMELEN
        bne p1l
        rts
.)

get_var
.(
        jsr find_var
        bcs nf
        jmp ld_val
nf      lda tnam
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        lda #<e_novar
        ldy #>e_novar
        jmp error
.)

; ---------------------------------------------------------------------
; Primitives
; ---------------------------------------------------------------------
need_list                       ; liste [ ... ] -> lstart, lend
.(
        lda ttype
        cmp #TK_LBR
        beq ok
        lda #<e_list
        ldy #>e_list
        jmp error
ok      lda tp                  ; tp est juste après le [
        sta lstart
        lda tp+1
        sta lstart+1
        ldx #0                  ; profondeur
loop    jsr at_end
        bcs bad
        ldy #0
        lda (tp),y
        cmp #"["
        bne n1
        inx
n1      cmp #"]"
        bne nx
        dex
        bmi found
nx      jsr inc_tp
        jmp loop
found   lda tp
        sta lend
        lda tp+1
        sta lend+1
        jsr inc_tp
        jmp advance
bad     lda #<e_bracket
        ldy #>e_bracket
        jmp error
.)

p_av    jsr need_img
        jsr eval_fix
        jmp move
p_re    jsr need_img
        jsr eval_fix
        jsr neg_fx
        jmp move
p_dr    jsr need_img
        jsr eval_fix
        jmp turn
p_ga    jsr need_img
        jsr eval_fix
        jsr neg_fx
        jmp turn
p_lc    lda #0
        sta pdown
        rts
p_bc    lda #1
pen_set sta pmode
        lda #1
        sta pdown
        jmp set_pen
p_gomme lda #0
        beq pen_set
p_inv   lda #2
        bne pen_set
p_ct    lda #0
        sta tvis
        rts
p_mt    lda #1
        sta tvis
        rts
p_ve    jsr need_img
        jsr gfx_cls
        jmp home
p_net   jsr need_img
        jmp gfx_cls
p_orig  jsr need_img
        ldx #2
        lda #0
po1     sta gx,x
        sta fxv,x
        dex
        bpl po1
        jmp goto_xy0
p_fcap  jsr need_img
        jsr eval_fix
        lda #0
        sta head
        sta head+1
        sta headf
        jmp turn
p_fxy   jsr need_img
        jsr eval_fix
        ldx #2                  ; x sur la pile : l'évaluation de y peut
pfx1    lda fxv,x               ; appeler une fonction qui fait FIXEXY
        pha
        dex
        bpl pfx1
        jsr eval_fix
        ldx #0
pfx2    pla                     ; gx = x, fxv = y
        sta gx,x
        inx
        cpx #3
        bne pfx2
        jmp goto_xy0

p_repete
.(
        jsr eval_int
        lda val
        sta cnt
        lda val+1
        sta cnt+1
        jsr need_list
        lda cnt+1
        bmi r
        ora cnt
        beq r
        lda #FR_REP
        jmp push_frame
r       rts
.)

p_si
.(
        jsr eval
        jsr truth
        sta tmp2                ; condition
        jsr need_list
        lda lstart
        sta p3
        lda lstart+1
        sta p3+1
        lda lend
        sta tmp
        lda lend+1
        sta tmp+1
        lda #0
        sta tmp2+1              ; pas de liste « sinon »
        lda ttype
        cmp #TK_LBR
        bne one
        jsr need_list
        inc tmp2+1
one     lda tmp2
        beq else
        lda p3
        sta lstart
        lda p3+1
        sta lstart+1
        lda tmp
        sta lend
        lda tmp+1
        sta lend+1
        jmp go
else    lda tmp2+1
        beq r
go      lda #FR_LIST
        jmp push_frame
r       rts
.)

p_stop  lda #1
        sta stopf
        rts

p_ecris
        jsr eval
        jsr put_val
        jmp crlf

p_donne
.(
        lda ttype
        cmp #TK_QUOTE
        beq ok
        lda #<e_quote
        ldy #>e_quote
        jmp error
ok      lda tnam                ; garde le nom sur la pile : l'évaluation
        pha                     ; se sert de p3 (word_is)
        lda tnam+1
        pha
        lda tlen
        pha
        jsr advance
        jsr eval
        pla
        sta pcount
        pla
        sta p3+1
        pla
        sta p3
        lda tnam
        pha
        lda tnam+1
        pha
        lda tlen
        pha
        lda p3
        sta tnam
        lda p3+1
        sta tnam+1
        lda pcount
        sta tlen
        jsr find_var
        bcc set
        ldx ngl                 ; nouvelle variable globale
        cpx #MAXGL
        bcc room
        lda #<e_mem
        ldy #>e_mem
        jmp error
room    lda #<globals
        ldy #>globals
        jsr entry_addr
        inc ngl
        jsr set_name
set     jsr st_val
        pla
        sta tlen
        pla
        sta tnam+1
        pla
        sta tnam
        rts
.)

p_attends
.(
        jsr eval_int
        lda SYS_TICKS
        sta tmp
        lda SYS_TICKS+1
        sta tmp+1
loop    jsr check_esc
        sec
        lda SYS_TICKS
        sbc tmp
        sta tmp2
        lda SYS_TICKS+1
        sbc tmp+1
        cmp val+1
        bcc loop
        bne r
        lda tmp2
        cmp val
        bcc loop
r       rts
.)

; NOTE n d : joue la note n (1-96, 37 = do central, 0 = silence) pendant
; d cinquantièmes de seconde, sur la voix 0, et attend la fin
p_note
        jsr eval_int
        lda val
        pha
        jsr eval_int
        pla
        sta gblk+2
        lda #S_NOTE
        sta gblk
        jmp sn_go
; BRUIT d : bruit blanc pendant d cinquantièmes de seconde
p_bruit
        jsr eval_int
        lda #S_NOISE
        sta gblk
        lda #8                  ; période du bruit
        sta gblk+2
sn_go   lda #12                 ; volume
        sta gblk+3
        lda #0
        sta gblk+1              ; voix 0
        lda val+1               ; durée : 255 au plus
        beq sn_d1
        lda #255
        sta val
sn_d1   lda val
        beq sn_r                ; durée nulle : rien
        sta gblk+4
        jsr snd
sn_wait jsr check_esc           ; attend la fin, ESC interrompt
        lda #S_STATUS
        sta gblk
        jsr snd
        and #1
        bne sn_wait
sn_r    rts

p_silence
        lda #S_SILENCE
        sta gblk
snd     ldx #F_SND
        lda #<gblk
        ldy #>gblk
        jmp BDOS

p_pour  lda #<e_pour
        ldy #>e_pour
        jmp error

p_quitte
        jsr turtle_hide
        jmp WBOOT

; ECRANTEXTE : écran texte de 26 lignes, sans image ni tortue (les
;   primitives de la tortue y donnent une erreur) ; l'image reste en
;   mémoire. ECRANMIXTE : retour au mode SPLIT avec l'image d'avant.
;   La zone des procédures et des textes ne change pas ($A000 au plus).
p_etexte
        lda tmode
        bne em_r
        jsr turtle_hide
        lda #<gq_text
        ldy #>gq_text
        ldx #1
em_set  stx tmode
        ldx #F_GFX
        jsr BDOS
        lda #<lg_bar            ; le changement de mode remet la barre
        ldy #>lg_bar            ; du système
        jmp B_MENUBAR
em_r    rts
p_emixte
        lda tmode
        beq em_r
        lda #<gq_keep
        ldy #>gq_keep
        ldx #0
        beq em_set

; ---------------------------------------------------------------------
; EDITE "NOM : enregistre les procédures dans NOM.LOG, range l'état de
;   LOGO dans LOGO.$$$ et passe la main à EDIT (BDOS 47, CHAIN) par
;   « EDIT NOM.LOG /L ». L'article « Retour » d'EDIT relance
;   « LOGO NOM.LOG /R » : LOGO reprend son état et recharge NOM.LOG.
;   Etat : page zéro, variables globales, tas des textes, mode d'écran ;
;   l'image reste en place (EDIT la garde quand il part du mode SPLIT).
; ---------------------------------------------------------------------
p_edite
        jsr p_sauve             ; NOM.LOG ; le nom reste dans fcb
        ldx #0                  ; fbuf = "EDIT NOM.LOG /L"
        ldy #0
ed1     lda s_edit,y
        sta fbuf,x
        inx
        iny
        cpy #5
        bne ed1
        jsr fcb_text
        ldy #0
ed2     lda s_retl,y
        sta fbuf,x
        inx
        iny
        cpy #4
        bne ed2
        jsr save_state
        lda tmode               ; EDIT doit partir du mode SPLIT pour
        beq ed3                 ; garder l'image
        lda #<gq_keep
        ldy #>gq_keep
        ldx #F_GFX
        jsr BDOS
ed3     lda #<fbuf
        ldy #>fbuf
        ldx #F_CHAIN
        jmp BDOS

; fcb_text : écrit le nom de fcb (NOM.TYP, sans blancs) en fbuf+X
fcb_text
        ldy #1
ft1     lda fcb,y
        cmp #" "
        beq ft2
        sta fbuf,x
        inx
ft2     iny
        cpy #9
        bne ft1
        lda fcb,y               ; type vide : pas de point
        cmp #" "
        beq ft5
        lda #"."
        sta fbuf,x
        inx
ft3     lda fcb,y
        cmp #" "
        beq ft4
        sta fbuf,x
        inx
ft4     iny
        cpy #12
        bne ft3
ft5     rts

; st_fcb : fcb = LOGO.$$$
st_fcb
        ldx #35
        lda #0
sf1     sta fcb,x
        dex
        bpl sf1
        ldx #10
sf2     lda s_state,x
        sta fcb+1,x
        dex
        bpl sf2
        rts

; heap_recs : p1 = début des enregistrements du tas (hp arrondi à 128),
;   cnt = leur nombre ((memtop - p1) / 128 ; memtop est un début de page)
heap_recs
        lda hp
        and #$80
        sta p1
        lda hp+1
        sta p1+1
        sec                     ; (memtop - p1) / 128, p1 bas = 0 ou $80
        lda memtop+1
        sbc p1+1
        asl
        sta cnt
        lda p1
        beq hr1
        dec cnt
hr1     rts

; save_state : écrit LOGO.$$$ (en-tête, variables globales, tas, page
;   zéro). Erreur disque : message et retour au prompt
save_state
        jsr st_fcb
        ldx #F_DELETE
        jsr bdos_fcb
        ldx #F_MAKE
        jsr bdos_fcb
        cmp #$FF
        bne ss0
        jmp ss_err
ss0     ldx #127                ; en-tête : "LGS1", hp, memtop, tmode
        lda #0
ss1     sta recbuf,x
        dex
        bpl ss1
        ldx #3
ss2     lda s_magic,x
        sta recbuf,x
        dex
        bpl ss2
        lda hp
        sta recbuf+4
        lda hp+1
        sta recbuf+5
        lda memtop
        sta recbuf+6
        lda memtop+1
        sta recbuf+7
        lda tmode
        sta recbuf+8
        lda #<recbuf
        ldy #>recbuf
        ldx #1
        jsr w_recs
        lda #<globals
        ldy #>globals
        ldx #MAXGL*VAR_SIZE/128
        jsr w_recs
        jsr heap_recs
        lda p1
        ldy p1+1
        ldx cnt
        jsr w_recs
        lda #0                  ; page zéro en dernier
        tay
        ldx #2
        jsr w_recs
        ldx #F_CLOSE
        jsr bdos_fcb
        jmp dma_def

; w_recs : écrit X enregistrements depuis A/Y
w_recs
        clc
        bcc rw_recs
; r_recs : lit X enregistrements vers A/Y (C=1 : fichier trop court)
r_recs
        sec
rw_recs
.(
        sta p1
        sty p1+1
        stx cnt
        ror rwop                ; bit 7 : lecture
loop    lda cnt
        beq r
        ldx #F_SETDMA
        lda p1
        ldy p1+1
        jsr BDOS
        ldx #F_WRITE
        bit rwop
        bpl w
        ldx #F_READ
w       jsr bdos_fcb
        cmp #0
        bne bad
        clc
        lda p1
        adc #128
        sta p1
        bcc nx
        inc p1+1
nx      dec cnt
        jmp loop
r       clc
        rts
bad     bit rwop                ; lecture : fin de fichier, C=1
        bpl ss_err
        sec
        rts
.)
ss_err  jsr dma_def
        lda #0
        sta clen
        lda #<e_disk
        ldy #>e_disk
        jmp error

dma_def ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS

; args : paramètres de LOGO. « LOGO NOM » prépare la ligne CHARGE "NOM ;
;   avec /R (retour d'EDIT), l'état rangé par EDITE est repris d'abord
args
.(
        lda FCB1+1
        cmp #" "
        beq r
        ldx #0                  ; fbuf = CHARGE "NOM (pour le prompt)
cl      lda s_charge,x
        sta fbuf,x
        inx
        cpx #8
        bne cl
        ldy #11                 ; nom de FCB1 dans fcb
nm      lda FCB1,y
        sta fcb,y
        dey
        bpl nm
        jsr fcb_text
        lda #0
        sta fbuf,x
        lda #1
        sta autold
        ldx TAIL                ; /R dans les paramètres ?
sl      dex
        bmi r
        lda TAIL+1,x
        cmp #"R"
        bne sl
        lda TAIL,x
        cmp #"/"
        bne sl
        jmp load_state
r       rts
.)

; load_state : reprend l'état de LOGO.$$$ (sinon, LOGO repart à neuf)
load_state
.(
        jmp ls0
jl      jmp lost                ; (branchements trop longs)
ls0     jsr st_fcb
        ldx #F_OPEN
        jsr bdos_fcb
        cmp #$FF
        beq jl
        lda #<recbuf
        ldy #>recbuf
        ldx #1
        jsr r_recs
        bcs jl
        ldx #3                  ; même LOGO, même haut de mémoire ?
mg      lda recbuf,x
        cmp s_magic,x
        bne jl
        dex
        bpl mg
        lda recbuf+6
        cmp memtop
        bne jl
        lda recbuf+7
        cmp memtop+1
        bne jl
        lda recbuf+8            ; mode d'écran
        pha
        lda recbuf+4            ; tas : à partir de hp arrondi à 128
        and #$80
        sta tmp
        lda recbuf+5
        sta tmp+1
        lda #<globals
        ldy #>globals
        ldx #MAXGL*VAR_SIZE/128
        jsr r_recs
        bcs lost1
        lda hp                  ; heap_recs avec le hp rangé
        pha
        lda hp+1
        pha
        lda tmp
        sta hp
        lda tmp+1
        sta hp+1
        jsr heap_recs
        pla
        sta hp+1
        pla
        sta hp
        lda p1
        ldy p1+1
        ldx cnt
        jsr r_recs
        bcs lost1
        lda #<lbuf              ; page zéro : dans lbuf et llbuf, recopiée
        ldy #>lbuf              ; d'un coup à la fin
        ldx #1
        jsr r_recs
        bcs lost1
        lda #<llbuf
        ldy #>llbuf
        ldx #1
        jsr r_recs
        bcs lost1
        ldx #F_DELETE
        jsr bdos_fcb
        jsr dma_def
        ldx #127
z1      lda lbuf,x
        sta $00,x
        dex
        bpl z1
        ldx #$DF-$80            ; $80-$DF
z2      lda llbuf,x
        sta $80,x
        dex
        bpl z2
        lda #<procbase          ; les procédures reviennent par CHARGE
        sta pend
        lda #>procbase
        sta pend+1
        lda #0
        sta nloc
        sta defmode
        sta stopf
        sta capf
        sta tdrawn
        sta pkey
        lda #1                  ; (le CHARGE préparé par args)
        sta autold
        jsr set_pen
        pla
        beq r
        jmp p_etexte
lost1   pla
lost    jsr dma_def
        lda #<m_lost
        ldy #>m_lost
        jmp puts
r       rts
.)

; auto_line : la ligne préparée (fbuf) devient la ligne tapée
auto_line
.(
        lda #0
        sta autold
        ldx #0
cp      lda fbuf,x
        sta lbuf+2,x
        beq e
        jsr putc
        inx
        bne cp
e       stx lbuf+1
        rts
.)

; need_img : erreur si l'écran est en mode texte
need_img
        lda tmode
        bne ni_err
        rts
ni_err  lda #<e_text
        ldy #>e_text
        jmp error

p_aide  lda #<m_aide
        ldy #>m_aide
        jmp puts

; ---------------------------------------------------------------------
; Tortue
; ---------------------------------------------------------------------
home
        lda #0
        ldx #2
h1      sta tx,x
        sta ty,x
        dex
        bpl h1
        sta head
        sta head+1
        sta headf
        rts

; turn : cap += fxv (degrés en virgule fixe), ramené dans 0..359,996
turn
.(
        clc
        lda headf
        adc fxv
        sta headf
        lda head
        adc fxv+1
        sta head
        lda head+1
        adc fxv+2
        sta head+1
neg     lda head+1              ; négatif : + 360
        bpl pos
        clc
        lda head
        adc #<360
        sta head
        lda head+1
        adc #>360
        sta head+1
        jmp neg
pos     lda head+1              ; >= 360 : - 360
        cmp #>360
        bcc r
        bne sub
        lda head
        cmp #<360
        bcc r
sub     sec
        lda head
        sbc #<360
        sta head
        lda head+1
        sbc #>360
        sta head+1
        jmp pos
r       rts
.)

; sinm : sinus de l'angle A/X + angf / 256 (entier 0..359), en grandeur et
;   signe : val = 65536 * |sin| (16 bits), sone = 1 si |sin| = 1 (val = 0),
;   sign = 1 si négatif. Entre deux degrés, la table est interpolée.
sinm
.(
        sta tmp
        stx tmp+1
        lda angf
        sta sf
        lda #0
        sta sign
        sta sone
        lda tmp+1               ; >= 180 : -sin(a - 180)
        bne big
        lda tmp
        cmp #180
        bcc q12
big     sec
        lda tmp
        sbc #180
        sta tmp
        lda tmp+1
        sbc #0
        sta tmp+1
        inc sign
q12     lda tmp                 ; 0..179 (+ fraction)
        cmp #90
        bcc look
        bne mir
        lda sf                  ; 90 tout rond : sinus = 1
        beq one
mir     lda sf                  ; au-delà de 90 : sin(180 - a)
        beq m0
        lda #179                ; avec fraction : 179 - a, 256 - f
        sec
        sbc tmp
        sta tmp
        lda #0
        sec
        sbc sf
        sta sf
        jmp look
m0      lda #180
        sec
        sbc tmp
        sta tmp
        cmp #90
        beq one
look    ldx tmp
        lda sin_lo,x
        sta val
        lda sin_hi,x
        sta val+1
        lda sf
        beq r
        sec                     ; écart avec le degré suivant (modulo
        lda sin_lo+1,x          ; 65536 : la valeur 0 de 90 vaut 65536)
        sbc sin_lo,x
        sta mp
        lda sin_hi+1,x
        sbc sin_hi,x
        sta mp+1
        jsr mulf                ; * f / 256 -> A (bas), X (haut)
        clc
        adc val
        sta val
        txa
        adc val+1
        sta val+1
        bcc r
one     lda #0                  ; |sin| = 1
        sta val
        sta val+1
        inc sone
r       rts
.)

; mulf : A (bas), X (haut) = (mp..mp+1 * sf + 128) / 256 (sf est détruit)
mulf
.(
        lda #0
        sta mr
        sta mr+1
        sta mr+2
        ldy #8
l       asl mr
        rol mr+1
        rol mr+2
        asl sf
        bcc n
        clc
        lda mr
        adc mp
        sta mr
        lda mr+1
        adc mp+1
        sta mr+1
        bcc n
        inc mr+2
n       dey
        bne l
        lda mr
        cmp #$80
        lda mr+1
        adc #0
        pha
        lda mr+2
        adc #0
        tax
        pla
        rts
.)

; norm_ang : ramène A/X (angle 16 bits >= 0) dans 0..359 -> A/X
norm_ang
.(
        sta tmp
        stx tmp+1
loop    lda tmp+1
        cmp #>360
        bcc r
        bne sub
        lda tmp
        cmp #<360
        bcc r
sub     sec
        lda tmp
        sbc #<360
        sta tmp
        lda tmp+1
        sbc #>360
        sta tmp+1
        jmp loop
r       lda tmp
        ldx tmp+1
        rts
.)

; delta : distance dst3 dans la direction ang (+ angf)
;   -> dxv, dyv (3 octets, 1/256)
delta
.(
        lda ang                 ; dx = dist * sin(ang)
        ldx ang+1
        jsr sinm
        jsr mul_ds
        ldx #2
dl1     lda mp+2,x
        sta dxv,x
        dex
        bpl dl1
        clc                     ; dy = dist * cos(ang) = dist * sin(ang + 90)
        lda ang
        adc #90
        tay
        lda ang+1
        adc #0
        tax
        tya
        jsr norm_ang
        jsr sinm
        jsr mul_ds
        ldx #2
dl2     lda mp+2,x
        sta dyv,x
        dex
        bpl dl2
        rts
.)

; mul_ds : mp+2..mp+4 = dst3 * sinus (résultat de sinm), arrondi au 1/256
mul_ds
.(
        lda sign                ; signe du résultat dans sd (bit 7)
        beq s0
        lda #$80
s0      eor dst3+2
        sta sd
        ldx #2                  ; |dst3| -> mr
c       lda dst3,x
        sta mr,x
        dex
        bpl c
        lda dst3+2
        bpl pa
        sec
        ldx #0
        ldy #3
na      lda #0
        sbc mr,x
        sta mr,x
        inx
        dey
        bne na
pa      lda sone                ; sinus = 1 : la distance elle-même
        beq mul
        ldx #2
c1      lda mr,x
        sta mp+2,x
        dex
        bpl c1
        bmi sg
mul     lda val
        sta mb
        lda val+1
        sta mb+1
        lda #0
        sta mp+2
        sta mp+3
        sta mp+4
        ldy #16
l       lsr mb+1
        ror mb
        bcc n
        clc
        lda mp+2
        adc mr
        sta mp+2
        lda mp+3
        adc mr+1
        sta mp+3
        lda mp+4
        adc mr+2
        sta mp+4
n       ror mp+4
        ror mp+3
        ror mp+2
        ror mp+1
        ror mp
        dey
        bne l
        lda mp+1                ; arrondi au 1/256
        cmp #$80
        lda mp+2
        adc #0
        sta mp+2
        lda mp+3
        adc #0
        sta mp+3
        lda mp+4
        adc #0
        sta mp+4
sg      lda sd
        bpl r
        sec
        ldx #0
        ldy #3
ng      lda #0
        sbc mp+2,x
        sta mp+2,x
        inx
        dey
        bne ng
r       rts
.)

; scr_of : position (tx/ty ou px/py 24 bits) -> x0/y0 écran
;   p_x/p_y : adresses des 3 octets dans posbuf
scr_pos
        ldx #2                  ; posx/posy -> x1, y1 (coordonnées écran)
sp1     lda posx,x
        sta tmp3,x
        dex
        bpl sp1
        jsr round24             ; tmp3 -> A (bas) / X (haut)
        clc
        adc #120
        sta x1
        txa
        adc #0
        sta x1+1
        ldx #2
sp2     lda posy,x
        sta tmp3,x
        dex
        bpl sp2
        jsr round24
        sta tmp
        stx tmp+1
        sec
        lda #64
        sbc tmp
        sta y1
        lda #0
        sbc tmp+1
        sta y1+1
        rts

; round24 : tmp3 (1/256, bas, haut) arrondi -> A/X
round24
        lda tmp3
        cmp #$80
        lda tmp3+1
        adc #0
        pha
        lda tmp3+2
        adc #0
        tax
        pla
        rts

; move : avance de fxv pas (virgule fixe)
move
.(
        ldx #2
d3      lda fxv,x
        sta dst3,x
        dex
        bpl d3
        lda head
        sta ang
        lda head+1
        sta ang+1
        lda headf
        sta angf
        jsr delta
        jsr pos_from_t          ; point de départ
        jsr scr_pos
        jsr x1_to_x0
        clc                     ; nouvelle position
        ldx #0
        ldy #3
ax      lda tx,x
        adc dxv,x
        sta tx,x
        inx
        dey
        bne ax
        bvs big
        clc
        ldx #0
        ldy #3
ay      lda ty,x
        adc dyv,x
        sta ty,x
        inx
        dey
        bne ay
        bvs big                 ; hors de -32768..32767
        jsr pos_from_t
        jsr scr_pos
        lda pdown
        beq r
        jmp seg
r       rts
big     jmp fp_err_big
.)

pos_from_t
        ldx #2
pft     lda tx,x
        sta posx,x
        lda ty,x
        sta posy,x
        dex
        bpl pft
        rts

x1_to_x0
        lda x1
        sta x0
        lda x1+1
        sta x0+1
        lda y1
        sta y0
        lda y1+1
        sta y0+1
        rts

; goto_xy0 : va en (gx, fxv) = (x, y) en traçant si le crayon est baissé
goto_xy0
.(
        jsr pos_from_t
        jsr scr_pos
        jsr x1_to_x0
        ldx #2
c       lda gx,x
        sta tx,x
        lda fxv,x
        sta ty,x
        dex
        bpl c
        jsr pos_from_t
        jsr scr_pos
        lda pdown
        beq r
        jmp seg
r       rts
.)

; seg : trait de (x0, y0) à (x1, y1), découpé aux bords de l'image
seg
.(
        jsr in_range
        bcs slow
        lda #G_LINE             ; entièrement visible : primitive LINE
        sta gblk
        lda x0
        sta gblk+1
        lda y0
        sta gblk+2
        lda x1
        sta gblk+3
        lda y1
        sta gblk+4
        jmp gfx
slow    ; Bresenham sur 16 bits, un point à la fois
        lda x0
        sta ldx_
        lda x0+1
        sta ldx_+1
        lda y0
        sta ldy_
        lda y0+1
        sta ldy_+1
        ; dx = |x1 - x0|, sx
        lda #1
        sta lsx
        sec
        lda x1
        sbc x0
        sta tmp
        lda x1+1
        sbc x0+1
        sta tmp+1
        bpl dxp
        lda #$FF
        sta lsx
        jsr neg_tmp
dxp     ; dy = -|y1 - y0|, sy
        lda #1
        sta lsy
        sec
        lda y1
        sbc y0
        sta tmp2
        lda y1+1
        sbc y0+1
        sta tmp2+1
        bmi dyn
        sec                     ; dy positif : on le rend négatif
        lda #0
        sbc tmp2
        sta tmp2
        lda #0
        sbc tmp2+1
        sta tmp2+1
        jmp dyd
dyn     lda #$FF
        sta lsy
dyd     clc                     ; err = dx + dy
        lda tmp
        adc tmp2
        sta lerr
        lda tmp+1
        adc tmp2+1
        sta lerr+1
loop    jsr plot_l
        lda ldx_
        cmp x1
        bne cont
        lda ldx_+1
        cmp x1+1
        bne cont
        lda ldy_
        cmp y1
        bne cont
        lda ldy_+1
        cmp y1+1
        beq done
cont    lda lerr
        asl
        sta le2
        lda lerr+1
        rol
        sta le2+1
        sec                     ; e2 >= dy ?
        lda le2
        sbc tmp2
        lda le2+1
        sbc tmp2+1
        bmi nox
        clc
        lda lerr
        adc tmp2
        sta lerr
        lda lerr+1
        adc tmp2+1
        sta lerr+1
        lda lsx
        jsr step_x
nox     sec                     ; e2 <= dx ?
        lda tmp
        sbc le2
        lda tmp+1
        sbc le2+1
        bmi loop
        clc
        lda lerr
        adc tmp
        sta lerr
        lda lerr+1
        adc tmp+1
        sta lerr+1
        lda lsy
        jsr step_y
        jmp loop
done    rts

step_x  bmi sxm
        inc ldx_
        bne sxr
        inc ldx_+1
sxr     rts
sxm     lda ldx_
        bne sx1
        dec ldx_+1
sx1     dec ldx_
        rts
step_y  bmi sym
        inc ldy_
        bne syr
        inc ldy_+1
syr     rts
sym     lda ldy_
        bne sy1
        dec ldy_+1
sy1     dec ldy_
        rts
.)

neg_tmp
        sec
        lda #0
        sbc tmp
        sta tmp
        lda #0
        sbc tmp+1
        sta tmp+1
        rts

; plot_l : point (ldx_, ldy_) s'il est dans l'image
plot_l
.(
        lda ldx_+1
        ora ldy_+1
        bne r
        lda ldx_
        cmp #240
        bcs r
        lda ldy_
        cmp #128
        bcs r
        lda #G_PLOT
        sta gblk
        lda ldx_
        sta gblk+1
        lda ldy_
        sta gblk+2
        jmp gfx
r       rts
.)

; in_range : C=0 si (x0,y0) et (x1,y1) sont dans l'image
in_range
.(
        lda x0+1
        ora y0+1
        ora x1+1
        ora y1+1
        bne no
        lda x0
        cmp #240
        bcs no
        lda x1
        cmp #240
        bcs no
        lda y0
        cmp #128
        bcs no
        lda y1
        cmp #128
no      rts
.)

; --- dessin de la tortue (triangle en mode inverse) ---
turtle_show
        lda tdrawn
        ora tmode               ; pas de tortue en écran texte
        bne ts_r
        jsr turtle_draw
        lda #1
        sta tdrawn
ts_r    rts

turtle_hide
        lda tdrawn
        beq th_r
        jsr turtle_draw
        lda #0
        sta tdrawn
th_r    rts

turtle_draw
        lda #2
        jsr set_pen_a
        lda #7                  ; pointe
        ldx #0
        jsr corner
        jsr x1_to_x0
        jsr save_tip
        lda #5                  ; arrière gauche
        ldx #150
        jsr corner
        jsr seg_xor
        jsr x1_to_x0
        lda #5                  ; arrière droit
        ldx #210
        jsr corner
        jsr seg_xor
        jsr x1_to_x0
        jsr load_tip
        jsr seg_xor
        lda pmode
        jmp set_pen_a

; corner : point à la distance A, angle cap + X -> x1, y1
corner
        sta dst3+1
        lda #0
        sta dst3
        sta dst3+2
        lda headf
        sta angf
        txa
        clc
        adc head
        tay
        lda head+1
        adc #0
        tax
        tya
        jsr norm_ang
        sta ang
        stx ang+1
        jsr delta
        clc
        ldx #0
        ldy #3
cx      lda tx,x
        adc dxv,x
        sta posx,x
        inx
        dey
        bne cx
        clc
        ldx #0
        ldy #3
cy      lda ty,x
        adc dyv,x
        sta posy,x
        inx
        dey
        bne cy
        jmp scr_pos

save_tip
        ldx #3
sti     lda x0,x
        sta tipxy,x
        dex
        bpl sti
        rts
load_tip
        ldx #3
ltp     lda tipxy,x
        sta x1,x
        dex
        bpl ltp
        rts

seg_xor
        jsr in_range            ; la tortue n'est dessinée qu'entièrement visible
        bcs sx_r
        jmp seg
sx_r    rts

; ---------------------------------------------------------------------
; Graphisme (BDOS 115)
; ---------------------------------------------------------------------
gfx     ldx #F_GFX
        lda #<gblk
        ldy #>gblk
        jmp BDOS

gfx_cls lda #0
        sta tdrawn
        lda #G_CLS
        sta gblk
        jmp gfx

set_pen lda pmode
set_pen_a
        sta gblk+1
        lda #G_PEN
        sta gblk
        jmp gfx

; ---------------------------------------------------------------------
; Procédures
; ---------------------------------------------------------------------
; Zone [procbase, pend) : enregistrements [longueur (2)][texte]
; Texte : "POUR NOM :A :B" CR lignes... CR "FIN"

; def_start : ligne p1 commençant par POUR
def_start
.(
        jsr advance             ; nom après POUR
        lda ttype
        cmp #TK_WORD
        beq ok
        lda #0
        sta clen
        lda #<e_name
        ldy #>e_name
        jmp error
ok      lda pend                ; l'enregistrement commence en pend
        sta rstart
        lda pend+1
        sta rstart+1
        clc
        lda pend
        adc #2
        sta wp
        lda pend+1
        adc #0
        sta wp+1
        lda #1
        sta defmode
        jmp def_add             ; la ligne d'en-tête est la première ligne
.)

; def_add : ajoute la ligne p1 (puis CR) à la procédure en cours
def_add
.(
        ldy #0
loop    lda (p1),y
        beq eol
        jsr wbyte
        iny
        bne loop
eol     lda #CR
        jmp wbyte
.)

; wbyte : écrit A en wp (vérifie la place). Y préservé
wbyte
.(
        pha
        lda wp+1
        cmp hp+1
        bcc ok
        txa                     ; compacte le tas et réessaie
        pha
        tya
        pha
        jsr hcompact
        pla
        tay
        pla
        tax
        lda wp+1
        cmp hp+1
        bcc ok
        pla
        lda #0
        sta clen
        lda #<e_mem
        ldy #>e_mem
        jmp error
ok      pla
        sty tmp
        ldy #0
        sta (wp),y
        ldy tmp
        inc wp
        bne r
        inc wp+1
r       rts
.)

; def_end : FIN reçu
def_end
.(
        lda #"F"
        jsr wbyte
        lda #"I"
        jsr wbyte
        lda #"N"
        jsr wbyte
        sec                     ; longueur du texte
        lda wp
        sbc rstart
        sta tmp
        lda wp+1
        sbc rstart+1
        sta tmp+1
        sec
        lda tmp
        sbc #2
        ldy #0
        sta (rstart),y
        lda tmp+1
        sbc #0
        iny
        sta (rstart),y
        lda wp
        sta pend
        lda wp+1
        sta pend+1
        lda #0
        sta defmode
        ; nom de la nouvelle procédure
        lda rstart
        sta hdr
        lda rstart+1
        sta hdr+1
        jsr rec_name            ; tnam/tlen
        lda tnam
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        ; une ancienne version porte-t-elle le même nom ?
        lda #<procbase
        sta hdr
        lda #>procbase
        sta hdr+1
look    lda hdr
        cmp rstart
        bne chk
        lda hdr+1
        cmp rstart+1
        beq done
chk     jsr rec_name_cmp
        bne next
        jsr rec_delete
        jmp done
next    jsr rec_next
        jmp look
done    jsr put_cname
        lda #<m_defined
        ldy #>m_defined
        jmp puts
.)

; rec_name : nom de l'enregistrement hdr -> tnam/tlen
rec_name
.(
        clc                     ; texte en hdr+2, "POUR" puis espaces
        lda hdr
        adc #2
        sta tp
        lda hdr+1
        adc #0
        sta tp+1
        lda tp
        clc
        adc #200
        sta tend
        lda tp+1
        adc #0
        sta tend+1
        jsr advance             ; POUR
        jmp advance             ; nom
.)

; rec_name_cmp : Z=1 si l'enregistrement hdr s'appelle cname/clen
rec_name_cmp
.(
        jsr rec_name
        lda tlen
        cmp clen
        bne r
        ldy #0
loop    cpy tlen
        beq r
        lda (tnam),y
        cmp (cname),y
        bne r
        iny
        bne loop
r       rts
.)

; rec_next : hdr = enregistrement suivant
rec_next
        ldy #0
        lda (hdr),y
        clc
        adc #2
        sta tmp
        iny
        lda (hdr),y
        adc #0
        sta tmp+1
        clc
        lda hdr
        adc tmp
        sta hdr
        lda hdr+1
        adc tmp+1
        sta hdr+1
        rts

; rec_end : hend = fin de l'enregistrement hdr
rec_end
        lda hdr
        pha
        lda hdr+1
        pha
        jsr rec_next
        lda hdr
        sta hend
        lda hdr+1
        sta hend+1
        pla
        sta hdr+1
        pla
        sta hdr
        rts

; rec_delete : supprime l'enregistrement hdr (les suivants descendent)
rec_delete
.(
        jsr rec_end
        lda hend                ; src = hend, dst = hdr, jusqu'à pend
        sta p2
        lda hend+1
        sta p2+1
        lda hdr
        sta p3
        lda hdr+1
        sta p3+1
        ldy #0
loop    lda p2
        cmp pend
        bne cp
        lda p2+1
        cmp pend+1
        beq done
cp      lda (p2),y
        sta (p3),y
        inc p2
        bne c1
        inc p2+1
c1      inc p3
        bne loop
        inc p3+1
        jmp loop
done    lda p3
        sta pend
        lda p3+1
        sta pend+1
        rts
.)

; find_proc : cherche cname/clen ; C=0 trouvé (hdr)
find_proc
.(
        lda tp                  ; rec_name utilise l'analyseur : on le préserve
        pha
        lda tp+1
        pha
        lda tend
        pha
        lda tend+1
        pha
        lda #<procbase
        sta hdr
        lda #>procbase
        sta hdr+1
loop    lda hdr
        cmp pend
        bne chk
        lda hdr+1
        cmp pend+1
        beq nf
chk     jsr rec_name_cmp
        beq found
        jsr rec_next
        jmp loop
nf      sec
        bcs out
found   clc
out     pla
        sta tend+1
        pla
        sta tend
        pla
        sta tp+1
        pla
        sta tp
        rts
.)

; call_proc : appel d'une procédure de l'utilisateur en instruction
;   (le jeton courant est son nom ; cname/clen le désignent)
call_proc
        lda #FR_PROC
        pha
        jsr proc_setup
        pla
        jmp push_frame

; call_func : appel d'une procédure dans une expression (primary, qui a
;   empilé le cname de l'appelant). Le corps tourne dans une boucle run
;   à part ; RENDS la quitte et revient à l'appelant de primary avec la
;   valeur dans vt/val. La pile du 6502, de savsp au sommet (expressions
;   en attente), est rangée dans spill : chaque niveau repart de savsp,
;   la profondeur n'est limitée que par spill, les contextes et la pile
;   de valeurs.
call_func
.(
        lda #FR_FUNC
        pha
        jsr proc_setup
        pla
        jsr push_frame
        tsx                     ; longueur à ranger : savsp - S
        stx tmp
        sec
        lda savsp
        sbc tmp
        sta tmp+1
        lda ssp                 ; p2 = début, p1 = octet de longueur
        sta p2
        clc
        adc tmp+1
        sta p1
        lda ssp+1
        sta p2+1
        adc #0
        sta p1+1
        lda p1
        cmp #<(spill_end-1)
        lda p1+1
        sbc #>(spill_end-1)
        bcc ok
        lda #0
        sta clen
        lda #<e_deep
        ldy #>e_deep
        jmp error
ok      ldy #0
        ldx tmp
cp      lda $0101,x
        sta (p2),y
        inx
        iny
        cpy tmp+1
        bne cp
        tya
        sta (p2),y
        clc
        lda p1
        adc #1
        sta ssp
        lda p1+1
        adc #0
        sta ssp+1
        ldx savsp
        txs
        jmp run                 ; ne revient que par RENDS (ou une erreur)
.)

; RENDS x : termine la fonction en cours en rendant x
p_rends
.(
        jsr eval
loop    lda fsp                 ; dépile jusqu'au contexte de la fonction
        cmp fbase
        bne more
        lda fsp+1
        cmp fbase+1
        bne more
        lda #0
        sta clen
        lda #<e_rtop
        ldy #>e_rtop
        jmp error
more    jsr top_frame
        ldy #0
        lda (p1),y
        cmp #FR_FUNC
        beq out
        cmp #FR_PROC            ; procédure appelée en instruction
        bne drop
        lda #<e_unused
        ldy #>e_unused
        jmp fr_error
drop    jsr x_rest
        lda p1
        sta fsp
        lda p1+1
        sta fsp+1
        jmp loop
out     jsr pop_p1              ; locales rendues, suite de l'expression
        sec                     ; reprend la pile du 6502 rangée par
        lda ssp                 ; call_func
        sbc #1
        sta p2
        lda ssp+1
        sbc #0
        sta p2+1
        ldy #0
        lda (p2),y
        sta tmp+1
        sec
        lda p2
        sbc tmp+1
        sta p2
        sta ssp
        lda p2+1
        sbc #0
        sta p2+1
        sta ssp+1
        sec
        lda savsp
        sbc tmp+1
        tax
        txs
        ldy #0
cb      lda (p2),y
        sta $0101,x
        inx
        iny
        cpy tmp+1
        bne cb
        pla                     ; nom de la commande de l'appelant
        sta clen
        pla
        sta cname+1
        pla
        sta cname
        rts
.)

; fr_error : erreur A/Y suivie du nom de la procédure du contexte p1
fr_error
        pha
        tya
        pha
        ldy #9
        lda (p1),y
        sta hdr
        iny
        lda (p1),y
        sta hdr+1
        jsr rec_name
        lda tnam
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        pla
        tay
        pla
        jmp error

; proc_setup : prépare l'appel de la procédure cname/clen (le jeton
;   courant est son nom) : évalue les arguments, crée les locales ;
;   lstart/lend = corps, cnt = enregistrement, fmark = locales d'avant.
;   Les arguments passent par la pile de valeurs : leur évaluation peut
;   appeler une fonction, qui se sert aussi de hdr, parn, pcount...
proc_setup
.(
        jsr find_proc           ; tp est juste après le nom (préservé)
        bcc found
        lda #<e_unknown
        ldy #>e_unknown
        jmp error
found   jsr advance             ; jeton suivant : le premier argument
        jsr hdr_params          ; pcount
        lda hdr
        pha
        lda hdr+1
        pha
        lda pcount
        pha
        tax
ev      txa                     ; X = arguments restant à évaluer
        beq evd
        pha
        jsr eval
        jsr vpush
        pla
        tax
        dex
        jmp ev
evd     pla
        sta pcount
        pla
        sta hdr+1
        pla
        sta hdr
        jsr hdr_params          ; parn, parl, bodyst de cette procédure
        lda nloc
        sta fmark
        clc
        adc pcount
        cmp #MAXLOC+1
        bcc room
        lda #<e_deep
        ldy #>e_deep
        jmp error
room    lda pcount              ; tmp2 = vsp - pcount * 6 : 1er argument
        asl
        sta tmp
        asl
        adc tmp
        sta tmp
        sec
        lda vsp
        sbc tmp
        sta vsp
        sta tmp2
        lda vsp+1
        sbc #0
        sta vsp+1
        sta tmp2+1
        ldx #0                  ; crée les variables locales
bl      cpx pcount
        beq body
        txa
        pha
        lda parn_lo,x
        sta tnam
        lda parn_hi,x
        sta tnam+1
        lda parl,x
        sta tlen
        ldx nloc
        lda #<locals
        ldy #>locals
        jsr entry_addr
        jsr set_name
        clc
        lda p2
        adc #NAMELEN
        sta p2
        bcc bv
        inc p2+1
bv      ldy #VAL_SIZE-1         ; valeur : de la pile de valeurs
bc      lda (tmp2),y
        sta (p2),y
        dey
        bpl bc
        clc
        lda tmp2
        adc #VAL_SIZE
        sta tmp2
        bcc bn
        inc tmp2+1
bn      inc nloc
        pla
        tax
        inx
        bne bl
body    jsr rec_end             ; corps : de bodyst à hend - 3 ("FIN")
        lda bodyst
        sta lstart
        lda bodyst+1
        sta lstart+1
        sec
        lda hend
        sbc #3
        sta lend
        lda hend+1
        sbc #0
        sta lend+1
        lda hdr
        sta cnt
        lda hdr+1
        sta cnt+1
        rts
.)

; hdr_params : lit les paramètres de l'en-tête hdr
hdr_params
.(
        lda #0
        sta pcount
        clc
        lda hdr
        adc #2
        sta p2
        lda hdr+1
        adc #0
        sta p2+1
        ldy #0                  ; saute POUR et le nom : jusqu'au 2e mot
        jsr skipsp
        jsr skipword
        jsr skipsp
        jsr skipword
loop    jsr skipsp
        lda (p2),y
        cmp #":"
        bne eol
        iny
        ldx pcount
        cpx #MAXPAR
        bcs eol
        tya
        clc
        adc p2
        sta parn_lo,x
        lda p2+1
        adc #0
        sta parn_hi,x
        sty tmp
        jsr skipword
        tya
        sec
        sbc tmp
        sta parl,x
        inc pcount
        jmp loop
eol     lda (p2),y              ; corps : après le CR de l'en-tête
        cmp #CR
        beq gotcr
        iny
        bne eol
gotcr   iny
        tya
        clc
        adc p2
        sta bodyst
        lda p2+1
        adc #0
        sta bodyst+1
        rts
skipsp  lda (p2),y
        cmp #" "
        bne ss_r
        iny
        bne skipsp
ss_r    rts
skipword
        lda (p2),y
        cmp #" "+1
        bcc sw_r
        cmp #":"
        beq sw_c
        iny
        bne skipword
sw_r    rts
sw_c    cpy tmp                 ; le « : » d'un nom de paramètre
        rts
.)

p_titres
.(
        lda tokst
        sta ld_tok
        lda tokst+1
        sta ld_tok+1
        lda #<procbase
        sta hdr
        lda #>procbase
        sta hdr+1
loop    lda hdr
        cmp pend
        bne one
        lda hdr+1
        cmp pend+1
        beq done
one     lda tp
        pha
        lda tp+1
        pha
        lda tend
        pha
        lda tend+1
        pha
        jsr rec_name
        jsr put_tok
        lda #" "
        jsr putc
        pla
        sta tend+1
        pla
        sta tend
        pla
        sta tp+1
        pla
        sta tp
        jsr rec_next
        jmp loop
done    jsr crlf_if
        lda ld_tok              ; rec_name a utilisé l'analyseur
        sta tp
        lda ld_tok+1
        sta tp+1
        jmp advance
.)

; quoted_proc : "NOM -> hdr (C=1 si absent)
quoted_proc
.(
        lda ttype
        cmp #TK_QUOTE
        beq ok
        lda #<e_quote
        ldy #>e_quote
        jmp error
ok      lda tnam
        sta cname
        lda tnam+1
        sta cname+1
        lda tlen
        sta clen
        jsr advance
        lda tokst
        pha
        lda tokst+1
        pha
        jsr find_proc
        pla
        sta tokst+1
        pla
        sta tokst
        rts
.)

restore_tok                     ; reprend l'analyse au jeton courant
        lda tokst
        sta tp
        lda tokst+1
        sta tp+1
        jmp advance

p_liste
.(
        jsr quoted_proc
        bcs nf
        jsr rec_end
        clc
        lda hdr
        adc #2
        sta p2
        lda hdr+1
        adc #0
        sta p2+1
loop    lda p2
        cmp hend
        bne pc
        lda p2+1
        cmp hend+1
        beq done
pc      ldy #0
        lda (p2),y
        cmp #CR
        bne put
        jsr crlf
        jmp nx
put     jsr putc
nx      inc p2
        bne loop
        inc p2+1
        jmp loop
done    jsr crlf
        lda #0
        sta clen
        jmp restore_tok
nf      lda #<e_unknown
        ldy #>e_unknown
        jmp error
.)

p_oublie
.(
        jsr quoted_proc
        bcs nf
        jsr rec_delete
        lda #0
        sta clen
        jmp restore_tok
nf      lda #<e_unknown
        ldy #>e_unknown
        jmp error
.)

p_oubtout
        lda #<procbase
        sta pend
        lda #>procbase
        sta pend+1
        lda #0
        sta ngl
        rts

; ---------------------------------------------------------------------
; Fichiers : SAUVE "NOM et CHARGE "NOM  (extension .LOG par défaut)
; ---------------------------------------------------------------------
; make_fcb : "NOM -> fcb
make_fcb
.(
        lda ttype
        cmp #TK_QUOTE
        beq ok
        lda #<e_quote
        ldy #>e_quote
        jmp error
ok      lda #0
        sta fcbext
        ldx #35
z       sta fcb,x
        dex
        bpl z
        ldx #11
        lda #" "
sp      sta fcb,x
        dex
        bne sp
        lda #"L"
        sta fcb+9
        lda #"O"
        sta fcb+10
        lda #"G"
        sta fcb+11
        ldy #0
        ldx #1
nm      cpy tlen
        beq done
        lda (tnam),y
        iny
        cmp #"."
        beq ext
        cpx #9
        bcs nm
        sta fcb,x
        inx
        bne nm
ext     ldx #9
        stx fcbext
        lda #" "
        sta fcb+9
        sta fcb+10
        sta fcb+11
ex      cpy tlen
        beq done
        lda (tnam),y
        iny
        cpx #12
        bcs ex
        sta fcb,x
        inx
        bne ex
done    jmp advance
.)

bdos_fcb
        lda #<fcb
        ldy #>fcb
        jmp BDOS

p_sauve
.(
        jsr make_fcb
        ldx #F_DELETE
        jsr bdos_fcb
        ldx #F_MAKE
        jsr bdos_fcb
        cmp #$FF
        bne ok
        lda #0
        sta clen
        lda #<e_disk
        ldy #>e_disk
        jmp error
ok      ldx #F_SETDMA
        lda #<recbuf
        ldy #>recbuf
        jsr BDOS
        lda #0
        sta ridx
        lda #<procbase
        sta p2
        lda #>procbase
        sta p2+1
rec     lda p2                  ; chaque enregistrement
        cmp pend
        bne one
        lda p2+1
        cmp pend+1
        beq fin
one     ldy #0                  ; longueur
        lda (p2),y
        sta cnt
        iny
        lda (p2),y
        sta cnt+1
        clc
        lda p2
        adc #2
        sta p2
        bcc ch
        inc p2+1
ch      lda cnt
        ora cnt+1
        beq endrec
        ldy #0
        lda (p2),y
        cmp #CR
        bne put
        jsr wput
        lda #LF
put     jsr wput
        inc p2
        bne c1
        inc p2+1
c1      lda cnt
        bne c2
        dec cnt+1
c2      dec cnt
        jmp ch
endrec  lda #CR                 ; après FIN : fin de ligne et ligne vide
        jsr wput
        lda #LF
        jsr wput
        lda #CR
        jsr wput
        lda #LF
        jsr wput
        jmp rec
fin     lda ridx                ; complète par des ^Z
        beq cl
pad     lda #$1A
        jsr wput
        lda ridx
        bne pad
cl      ldx #F_CLOSE
        jsr bdos_fcb
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #<m_saved
        ldy #>m_saved
        jmp puts
.)

; wput : ajoute A à l'enregistrement, l'écrit quand il est plein
wput
.(
        ldx ridx
        sta recbuf,x
        inx
        stx ridx
        cpx #128
        bne r
        lda #0
        sta ridx
        ldx #F_WRITE
        jsr bdos_fcb
        cmp #0
        beq r
        lda #0
        sta clen
        lda #<e_disk
        ldy #>e_disk
        jmp error
r       rts
.)

; SAUVEIMAGE "NOM / CHARGEIMAGE "NOM : l'image du mode SPLIT (.IMG)
p_simage
        lda #G_GSAVE
        bne img_op
p_cimage
        lda #G_GLOAD
img_op
.(
        pha
        jsr need_img
        jsr make_fcb
        pla
        sta gblk
        lda fcbext              ; sans type : le système prend .IMG
        bne keep
        lda #" "
        sta fcb+9
        sta fcb+10
        sta fcb+11
keep    lda #<fcb
        sta gblk+1
        lda #>fcb
        sta gblk+2
        jsr turtle_hide         ; la tortue n'est pas dans l'image
        jsr gfx
        cmp #0
        beq ok
        cmp #1
        bne bad
        lda #<e_nofile
        ldy #>e_nofile
        jmp error
bad     lda #<e_disk
        ldy #>e_disk
        jmp error
ok      rts
.)

p_charge
.(
        jsr make_fcb
        lda tokst               ; reprise après le chargement
        sta ld_tok
        lda tokst+1
        sta ld_tok+1
        lda tend
        sta ld_end
        lda tend+1
        sta ld_end+1
        lda fbase
        sta ld_fb
        lda fbase+1
        sta ld_fb+1
        ldx #F_OPEN
        jsr bdos_fcb
        cmp #$FF
        bne ok
        lda #0
        sta clen
        lda #<e_nofile
        ldy #>e_nofile
        jmp error
ok      lda #128
        sta ridx
        lda #0
        sta reof
line    ldx #0                  ; assemble une ligne dans fbuf
gc      jsr getc
        bcs eof
        cmp #LF
        beq gc
        cmp #CR
        beq eol
        cpx #126
        bcs gc
        sta fbuf,x
        inx
        bne gc
eol     lda #0
        sta fbuf,x
        jsr ld_line
        jmp line
eof     cpx #0                  ; dernière ligne sans CR
        beq done
        lda #0
        sta fbuf,x
        jsr ld_line
done    ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #<m_loaded
        ldy #>m_loaded
        jsr puts
        lda ld_tok              ; reprend la ligne qui contenait CHARGE
        sta tp
        lda ld_tok+1
        sta tp+1
        lda ld_end
        sta tend
        lda ld_end+1
        sta tend+1
        lda ld_fb
        sta fbase
        lda ld_fb+1
        sta fbase+1
        lda #0
        sta clen
        jmp advance

; ld_line : traite une ligne du fichier comme une ligne tapée
ld_line lda #<fbuf
        sta p1
        lda #>fbuf
        sta p1+1
        lda fsp                 ; les commandes du fichier s'exécutent
        sta fbase               ; au-dessus des contextes en cours
        lda fsp+1
        sta fbase+1
        jsr do_line
        lda ld_fb
        sta fbase
        lda ld_fb+1
        sta fbase+1
        rts
.)

; getc : caractère suivant du fichier (C=1 en fin de fichier)
getc
.(
        lda reof
        bne end
        ldy ridx
        cpy #128
        bcc have
        txa
        pha
        ldx #F_SETDMA
        lda #<recbuf
        ldy #>recbuf
        jsr BDOS
        ldx #F_READ
        jsr bdos_fcb
        tay
        pla
        tax
        tya
        bne seteof
        ldy #0
        sty ridx
have    lda recbuf,y
        inc ridx
        cmp #$1A
        beq seteof
        clc
        rts
seteof  lda #1
        sta reof
end     sec
        rts
.)

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
putc    bit capf
        bmi pcap
        pha
        txa
        pha
        tya
        pha
        tsx
        lda $0103,x
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts

pcap    sty capy                ; as_text : le caractère va dans nbuf
        ldy ncap
        sta nbuf,y
        inc ncap
        ldy capy
        rts

puts
.(
        sta p3
        sty p3+1
        ldy #0
loop    lda (p3),y
        beq r
        jsr putc
        iny
        bne loop
r       rts
.)

crlf    lda #CR
        jsr putc
        lda #LF
        jmp putc

; crlf_if : nouvelle ligne si le curseur n'est pas en début de ligne
crlf_if lda CON_CURX
        cmp #2
        beq ci_r
        jmp crlf
ci_r    rts

put_tok                         ; affiche le mot tnam/tlen
        ldy #0
pt1     cpy tlen
        beq pt2
        lda (tnam),y
        jsr putc
        iny
        bne pt1
pt2     rts

put_cname
        ldy #0
pc1     cpy clen
        beq pc2
        lda (cname),y
        jsr putc
        iny
        bne pc1
pc2     rts

; put_num : affiche val (signé)
put_num
.(
        lda val+1
        bpl pos
        lda #"-"
        jsr putc
        jsr neg_val
pos     lda #0
        sta tmp2                ; chiffres écrits
        ldx #0
dig     ldy #0
sub     sec
        lda val
        sbc dec_lo,x
        pha
        lda val+1
        sbc dec_hi,x
        bcc dn
        sta val+1
        pla
        sta val
        iny
        bne sub
dn      pla
        tya
        bne show
        lda tmp2
        beq nx
        tya
show    ora #"0"
        jsr putc
        sta tmp2
nx      inx
        cpx #4
        bne dig
        lda val
        ora #"0"
        jmp putc
dec_lo  .byt <10000,<1000,<100,<10
dec_hi  .byt >10000,>1000,>100,>10
.)

; ---------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------
; nombres décimaux (FP_ZP, putc, fp_err_big et fp_err_div sont définis ici)
#include "fp_inc.s"
; mots et listes
#include "ltxt_inc.s"

prims
        .asc "RENDS",0
        .word p_rends
        .asc "EXECUTE",0
        .word p_exec
        .asc "EXEC",0
        .word p_exec
        .asc "AVANCE",0
        .word p_av
        .asc "AV",0
        .word p_av
        .asc "RECULE",0
        .word p_re
        .asc "RE",0
        .word p_re
        .asc "DROITE",0
        .word p_dr
        .asc "DR",0
        .word p_dr
        .asc "GAUCHE",0
        .word p_ga
        .asc "GA",0
        .word p_ga
        .asc "LEVECRAYON",0
        .word p_lc
        .asc "LC",0
        .word p_lc
        .asc "BAISSECRAYON",0
        .word p_bc
        .asc "BC",0
        .word p_bc
        .asc "GOMME",0
        .word p_gomme
        .asc "INVERSE",0
        .word p_inv
        .asc "CACHETORTUE",0
        .word p_ct
        .asc "CT",0
        .word p_ct
        .asc "MONTRETORTUE",0
        .word p_mt
        .asc "MT",0
        .word p_mt
        .asc "ECRANTEXTE",0
        .word p_etexte
        .asc "EDITE",0
        .word p_edite
        .asc "ECRANMIXTE",0
        .word p_emixte
        .asc "VIDEECRAN",0
        .word p_ve
        .asc "VE",0
        .word p_ve
        .asc "NETTOIE",0
        .word p_net
        .asc "ORIGINE",0
        .word p_orig
        .asc "FIXECAP",0
        .word p_fcap
        .asc "FIXEXY",0
        .word p_fxy
        .asc "REPETE",0
        .word p_repete
        .asc "SI",0
        .word p_si
        .asc "STOP",0
        .word p_stop
        .asc "ECRIS",0
        .word p_ecris
        .asc "EC",0
        .word p_ecris
        .asc "DONNE",0
        .word p_donne
        .asc "ATTENDS",0
        .word p_attends
        .asc "NOTE",0
        .word p_note
        .asc "BRUIT",0
        .word p_bruit
        .asc "SILENCE",0
        .word p_silence
        .asc "POUR",0
        .word p_pour
        .asc "SAUVE",0
        .word p_sauve
        .asc "CHARGE",0
        .word p_charge
        .asc "SAUVEIMAGE",0
        .word p_simage
        .asc "CHARGEIMAGE",0
        .word p_cimage
        .asc "TITRES",0
        .word p_titres
        .asc "LISTE",0
        .word p_liste
        .asc "OUBLIE",0
        .word p_oublie
        .asc "OUBLIETOUT",0
        .word p_oubtout
        .asc "AIDE",0
        .word p_aide
        .asc "QUITTE",0
        .word p_quitte
        .asc "AUREVOIR",0
        .word p_quitte
        .byt 0

w_pour   .asc "POUR",0
w_fin    .asc "FIN",0
funcs   .asc "HASARD",0
        .word f_hasard
        .asc "CAP",0
        .word f_cap
        .asc "XCOR",0
        .word f_xcor
        .asc "YCOR",0
        .word f_ycor
        .asc "RACINE",0
        .word f_racine
        .asc "EXP",0
        .word f_exp
        .asc "LN",0
        .word f_ln
        .asc "SIN",0
        .word f_sin
        .asc "COS",0
        .word f_cos
        .asc "ARCTAN",0
        .word f_atn
        .asc "LISLISTE",0
        .word f_lisliste
        .asc "LL",0
        .word f_lisliste
        .asc "LISMOT",0
        .word f_lismot
        .asc "ASCII",0
        .word f_ascii
        .asc "CAR",0
        .word f_car
        .asc "LISCAR",0
        .word f_liscar
        .asc "TOUCHE?",0
        .word f_touche
        .asc "ENT",0
        .word f_ent
        .asc "ARRONDI",0
        .word f_arrondi
        .asc "ABS",0
        .word f_abs
        .asc "QUOTIENT",0
        .word f_quotient
        .asc "RESTE",0
        .word f_reste
        .asc "MOT",0
        .word f_mot
        .asc "PHRASE",0
        .word f_phrase
        .asc "PH",0
        .word f_phrase
        .asc "LISTE",0
        .word f_liste
        .asc "PREMIER",0
        .word f_premier
        .asc "PR",0
        .word f_premier
        .asc "DERNIER",0
        .word f_dernier
        .asc "DER",0
        .word f_dernier
        .asc "SAUFPREMIER",0
        .word f_sp
        .asc "SP",0
        .word f_sp
        .asc "SAUFDERNIER",0
        .word f_sd
        .asc "SD",0
        .word f_sd
        .asc "ITEM",0
        .word f_item
        .asc "COMPTE",0
        .word f_compte
        .asc "VIDE?",0
        .word f_videp
        .asc "MOT?",0
        .word f_motp
        .asc "LISTE?",0
        .word f_listep
        .asc "NOMBRE?",0
        .word f_nombrep
        .asc "MEMBRE?",0
        .word f_membrep
        .byt 0

gq_get   .byt G_GETMODE,0,0,0,0,0
gq_split .byt G_MODE,1,0,0,0,0
gq_text  .byt G_MODE,0,0,0,0,0
s_edit   .asc "EDIT "
s_retl   .asc " /L",0
s_charge .asc "CHARGE ",$22
s_state  .asc "LOGO    $$$"
s_magic  .asc "LGS1"
gq_keep  .byt G_MODE,2,0,0,0,0

; barre de menus : les articles tapent des commandes
lg_bar  .byt 3
        .word mn_fic, mn_tor, mn_aid
mn_fic  .byt 8,12
        .asc "Fichier",0
        .asc "Charger...",0
        .byt MA_TYPE
        .word ty_charge
        .asc "Sauver...",0
        .byt MA_TYPE
        .word ty_sauve
        .asc "Editer...",0
        .byt MA_TYPE
        .word ty_edite
        .asc "Charger img.",0
        .byt MA_TYPE
        .word ty_cimg
        .asc "Sauver img.",0
        .byt MA_TYPE
        .word ty_simg
        .asc "Titres",0
        .byt MA_TYPE
        .word ty_titres
        .asc "Tout oubli",0
        .byt MA_TYPE
        .word ty_oubtout
        .asc "Quitter",0
        .byt MA_TYPE
        .word ty_quitte
mn_tor  .byt 7,12
        .asc "Tortue",0
        .asc "Efface ecran",0
        .byt MA_TYPE
        .word ty_ve
        .asc "Origine",0
        .byt MA_TYPE
        .word ty_orig
        .asc "Cache",0
        .byt MA_TYPE
        .word ty_ct
        .asc "Montre",0
        .byt MA_TYPE
        .word ty_mt
        .asc "Leve crayon",0
        .byt MA_TYPE
        .word ty_lc
        .asc "Ecran texte",0
        .byt MA_TYPE
        .word ty_etxt
        .asc "Ecran mixte",0
        .byt MA_TYPE
        .word ty_emix
mn_aid  .byt 1,10
        .asc "Aide",0
        .asc "Primitives",0
        .byt MA_TYPE
        .word ty_aide

ty_charge .byt $18
          .asc "CHARGE ",$22,0
ty_sauve  .byt $18
          .asc "SAUVE ",$22,0
ty_edite  .byt $18
          .asc "EDITE ",$22,0
ty_cimg   .byt $18
          .asc "CHARGEIMAGE ",$22,0
ty_simg   .byt $18
          .asc "SAUVEIMAGE ",$22,0
ty_titres .byt $18
          .asc "TITRES",13,0
ty_oubtout .byt $18
          .asc "OUBLIETOUT",13,0
ty_quitte .byt $18
          .asc "QUITTE",13,0
ty_ve     .byt $18
          .asc "VE",13,0
ty_orig   .byt $18
          .asc "ORIGINE",13,0
ty_ct     .byt $18
          .asc "CT",13,0
ty_mt     .byt $18
          .asc "MT",13,0
ty_etxt   .byt $18
          .asc "ECRANTEXTE",13,0
ty_emix   .byt $18
          .asc "ECRANMIXTE",13,0
ty_lc     .byt $18
          .asc "LC",13,0
ty_aide   .byt $18
          .asc "AIDE",13,0

m_banner  .asc "LOGO CP/A - tapez AIDE",13,10,0
m_prompt  .asc "? ",0
m_prompt2 .asc "> ",0
m_defined .asc " defini.",13,10,0
m_saved   .asc "Sauve.",13,10,0
m_loaded  .asc "Charge.",13,10,0
m_aide    .asc "AV RE DR GA n  LC BC GOMME INVERSE",13,10
          .asc "CT MT VE NETTOIE ORIGINE",13,10
          .asc "ECRANTEXTE  ECRANMIXTE",13,10
          .asc "FIXECAP n  FIXEXY x y  ATTENDS n",13,10
          .asc "NOTE n d (37 = do)  BRUIT d  SILENCE",13,10
          .asc "REPETE n [..]  SI c [..] [..]  STOP",13,10
          .asc "POUR NOM :A ... FIN  DONNE ",$22,"X n",13,10
          .asc "ECRIS n/",$22,"mot/[..]  HASARD CAP",13,10
          .asc "XCOR YCOR  + - * / ( ) = < >",13,10
          .asc "LISLISTE LISMOT LISCAR TOUCHE?",13,10
          .asc "ASCII x  CAR n",13,10
          .asc "ENT ARRONDI ABS  QUOTIENT RESTE",13,10
          .asc "Decimaux : 3.14  1.5E-7  7 / 2",13,10
          .asc "RACINE SIN COS ARCTAN LN EXP",13,10
          .asc "MOT PHRASE LISTE PREMIER DERNIER",13,10
          .asc "SAUFPREMIER SAUFDERNIER ITEM",13,10
          .asc "COMPTE VIDE? MOT? NOMBRE? LISTE?",13,10
          .asc "MEMBRE?  EXECUTE [..]  RENDS x",13,10
          .asc "SAUVE/CHARGE/EDITE ",$22,"NOM  TITRES",13,10
          .asc "SAUVEIMAGE/CHARGEIMAGE ",$22,"NOM",13,10
          .asc "LISTE/OUBLIE ",$22,"NOM  OUBLIETOUT",13,10
          .asc "ESC interrompt  QUITTE",13,10,0
e_what    .asc "Que faire de cela ?",0
e_unknown .asc "Je ne connais pas",0
e_value   .asc "Il manque une valeur",0
e_novar   .asc "Pas de valeur pour",0
e_div     .asc "Division par zero",0
e_notnum  .asc "Il faut un nombre",0
e_big     .asc "Nombre trop grand",0
e_dom     .asc "Calcul impossible",0
e_empty   .asc "Mot ou liste vide",0
e_word    .asc "Il faut un mot",0
e_list    .asc "Il faut une liste [ ] apres",0
e_bracket .asc "Il manque un ] apres",0
e_deep    .asc "Trop de niveaux",0
e_mem     .asc "Memoire pleine",0
e_esc     .asc "Interrompu",0
e_quote   .asc "Il faut un nom avec ",$22," apres",0
e_pour    .asc "POUR seulement au debut d'une ligne",0
e_name    .asc "Il faut un nom apres POUR",0
e_disk    .asc "Erreur disque",0
e_nofile  .asc "Fichier introuvable",0
e_noret   .asc "Rien n'a ete rendu par",0
e_unused  .asc "Que faire de ce que rend",0
e_rtop    .asc "RENDS seulement dans une procedure",0
e_text    .asc "Impossible en ecran texte :",0
m_lost    .asc "Etat de LOGO.$$$ perdu",13,10,0

#include "logo_tab.s"

; ---------------------------------------------------------------------
; Variables
; ---------------------------------------------------------------------
; (les zones de travail ne sont pas dans le fichier .COM : simples adresses)
vars_base
gblk    = vars_base+0
dxv     = gblk+6
dyv     = dxv+3
posx    = dyv+3
posy    = posx+3
tmp3    = posy+3
tipxy   = tmp3+3
bodyst  = tipxy+4
ld_tok  = bodyst+2
ld_end  = ld_tok+2
ld_fb   = ld_end+2
ssp     = ld_fb+2       ; haut de la zone de débordement de la pile (2)
tmode   = ssp+2         ; 1 en écran texte (ECRANTEXTE)
autold  = tmode+1       ; 1 : la ligne de fbuf sera exécutée au prompt
rwop    = autold+1      ; r_recs / w_recs : bit 7 = lecture
parn_lo = rwop+1
parn_hi = parn_lo+MAXPAR
parl    = parn_hi+MAXPAR
fcb     = parl+MAXPAR
fcbext  = fcb+36        ; 1 = le nom donné a un type
recbuf  = fcbext+1
lbuf    = recbuf+128
fbuf    = lbuf+130
globals = fbuf+130
locals  = globals+MAXGL*VAR_SIZE
frames  = locals+MAXLOC*VAR_SIZE
frames_end= frames+120*FR_SIZE
vstack  = frames_end    ; pile de valeurs de l'évaluateur
vstack_end= vstack+VS_N*VAL_SIZE
gl_v    = globals+NAMELEN       ; valeur de la 1re variable globale
lo_v    = locals+NAMELEN        ;   et locale
s_t     = vstack_end    ; deux valeurs de la pile lues par ld_sa, ld_sb (10)
nbuf    = s_t+10        ; nombre écrit en texte, mot lu comme nombre (32)
nlen    = nbuf+32
nlast   = nlen+1
npend   = nlast+1
nwr     = npend+1
bw      = nwr+1         ; build2 : crochets autour des listes
bsp     = bw+1          ;   mode de l'espace
bsp2    = bsp+1         ;   1 si espace
brt     = bsp2+1        ;   type du résultat
capy    = brt+1
xsp     = capy+1        ; haut de la pile d'EXECUTE (2)
xstack  = xsp+2         ; textes en cours d'EXECUTE
xstack_end= xstack+512
llbuf   = xstack_end    ; ligne lue par LISLISTE, LISMOT (128)
spill   = llbuf+128     ; pile du 6502 des expressions en attente d'une
spill_end = spill+640   ;   fonction (RENDS)
procbase = (spill_end+255)/256*256   ; procédures, puis le tas des textes

