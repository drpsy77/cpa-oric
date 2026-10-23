; =====================================================================
;  GRAPHER.COM — exécute un fichier de commandes graphiques (.GRX)
;
;  GRAPHER NOM [p1 ... p9]
;  GRAPHER NOM /A [p1 ... p9] : passe la main à GRXASM.COM (traduction en
;    assembleur) par CHAIN
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
;  INKEY (touche, 0 si aucune ; n'attend pas, sans délai de répétition),
;  LEN(A$).
;  Tableaux   DIM A(n) A(n,m) A$(n) A$(n,m) : entiers, octets ($), indices
;             0 à n-1 ; A(i) A(i,j) M$(l,c) éléments ; A$, M$(l) chaînes
;             (jusqu'au premier 0) : =, comparaisons, LEN, PRINT, INPUT ;
;             FILL A v ; INPUT V (entier). Routines : arr.inc.
;
;  Modes      HIRES, SPLIT, TEXT, LORES (écran texte 40 x 28 au programme)
;  LORES      CLS, LOCATE col lig, CHAR col lig code, SPC n [x], TAB n,
;             SCRN(col,lig) ; ECHO et PRINT au curseur, sans déborder de
;             la ligne ; ECHO seul : colonne 0 de la ligne suivante
;  Touches    GET V (attend une touche), WAIT, INKEY
;  Sprites    SPRITES n, SPOOL T [ALT], SSHOW k S$ n col lig [ALT],
;             SHIDE k (LORES ; fichiers .SPR lus par BLOAD) : spr.inc
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
;  ESC entre deux lignes arrête. En fin de fichier, HIRES et LORES rendent
;  aussitôt la console (attendre : WAIT ou GET dans le programme) ; une
;  image SPLIT reste au-dessus du prompt.
;  Le dessin passe par hires.inc (pas par la fonction 115 du BDOS).
; =====================================================================


#include "cpa.inc"
#include "grxd_inc.s"

        *= $0500

        tsx
        stx sav_sp
        lda FCB1+1              ; sans nom : mode d'emploi
        cmp #" "
        bne named
        ldx #F_PRINT
        lda #<m_use
        ldy #>m_use
        jmp BDOS
named   ldx #NBUF               ; tampons à 0
        lda #0
z1      sta bufs-1,x
        dex
        bne z1
        lda #<vars              ; variables à 0 (8 pages : déborde sur le
        sta lp                  ;   texte, pas encore chargé)
        lda #>vars
        sta lp+1
        ldx #8
        ldy #0
        tya
z2      sta (lp),y
        iny
        bne z2
        inc lp+1
        dex
        bne z2
        sta cmode
        jsr get_params
        lda cmode               ; /A, /C : la traduction est faite par GRXASM
        beq interp
        jmp to_grxasm
interp  sta ihk
        sta pkey
        sta csp
        sta word
        lda SYS_TICKS           ; graine du hasard : le compteur 50 Hz,
        sta rnd                 ;   jamais nulle, puis 4 tours pour que
        lda SYS_TICKS+1         ;   deux lancements proches divergent
        sta rnd+1
        lda #$5A
        sta rnd+2
        lda #$A5
        sta rnd+3
        ldx #4
seedw   jsr rand
        dex
        bne seedw
        jsr h_init
        lda #G_GETMODE          ; lancé en mode SPLIT : on y reste
        jsr h_gfx
        cmp #1
        bne nosplit
        lda #128
        sta h_lines
nosplit jsr open_grx
        jsr load_text
        lda pe                  ; images .HIZ et animations : après le texte
        sta h_zbuf
        lda pe+1
        sta h_zbuf+1
        lda #1                  ; tableaux : indices vérifiés (interprété)
        sta r_chk
        jsr r_init
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
        jmp r_esc
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

; fin normale : HIRES et LORES rendent la console (sans attendre)
finish  jsr to_text
        ldx sav_sp
        txs
        rts

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

; needgfx : erreur hors du mode HIRES ou SPLIT
needgfx
        lda h_lines
        bne ng_ok
        lda #<m_nogfx
        ldy #>m_nogfx
        jmp error
ng_ok   rts

; setvar : variable vix, vc <- ev
setvar  jsr vaddr
setv_p  ldy #0                  ; (variable d'adresse vptr)
        lda ev
        sta (vptr),y
        iny
        lda ev+1
        sta (vptr),y
        rts

; vaddr : adresse de la variable vix, vc -> vptr
;   vars + 2 * (26 * vc + vix) : A à Z, puis AA à ZA, AB à ZB... puis A0..
vaddr
.(
        lda #0
        sta vptr+1
        lda vc                  ; vc * 13 (468 au plus)
        asl
        adc vc                  ; * 3 (C=0 : 108 au plus)
        asl                     ; * 6
        asl                     ; * 12
        rol vptr+1
        adc vc                  ; * 13 (C=0 après le rol)
        bcc a1
        inc vptr+1
a1      asl                     ; * 26
        rol vptr+1
        adc vix                 ; + vix (C=0)
        bcc a2
        inc vptr+1
a2      asl                     ; * 2
        rol vptr+1
        adc #<vars              ; (C=0)
        sta vptr
        lda vptr+1
        adc #>vars
        sta vptr+1
        rts
.)

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
        beq px_ep               ; paramètre absent
        cmp #";"
        beq px_ep
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
        bne px_ee
pxok    lda edep                ; LET, IF... : rien d'autre ensuite
        beq pxr
        jsr endline
pxr     rts
px_ep   jmp e_param
px_ee   jmp e_expr

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
        jsr is_str              ; deux chaînes comparées ?
        bcc str
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
str     jsr p_str
        jsr r_save
        jsr ws
        jsr relop
        bcs bad
        and #$7F
        pha
        jsr ws
        jsr p_str
        pla
        tax
        jmp r_cmp               ; -> ev : 1 ou 0
bad     jmp e_strc
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

; signe -
e_un
.(
        jsr ws
        jsr gch
        cmp #"-"
        bne e_prim
        inc ex
        jsr e_un
        jmp neg_ev
.)

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
nopar   cmp #34                 ; une chaîne dans un calcul
        beq strc
        cmp #"0"
        bcc id
        cmp #"9"+1
        bcs id
        jmp parse_num
id      jsr parse_id
        cpx #3
        bcs func
        cpx #1
        bne v2
        jsr gch                 ; A( ou A$( : un élément de tableau
        cmp #"("
        beq ael
        cmp #"$"
        beq bel
v2      jmp getv_kw             ; variable
ael     lda kw
        ldx #0
        jmp a_get
bel     inc ex
        jsr gch
        cmp #"("
        bne strc                ; A$ : une chaîne
        lda kw
        ldx #1
        jmp a_get
strc    jmp e_strc
func    jsr find_fn
        cmp #0
        beq f_rnd
        cmp #1
        beq f_abs
        cmp #2
        beq f_point
        cmp #4
        bne fik
        jmp f_scrn
fik     cmp #5
        bne fik2
        jsr x_open              ; LEN(chaîne)
        jsr p_str
        jsr x_close
        jmp r_len
fik2    cmp #6
        bne fik3
        jmp f_fnd               ; FOUND (fil.inc)
fik3    cmp #7
        bne fik4
        jmp f_tile
fik4    jmp f_inkey
f_rnd   jsr arg1
        lda ev+1
        bmi zero
        ora ev
        beq zero
        jsr rand                ; et = hasard (0 à 32767)
        lda ev+1                ; n < 256 : (graine * n) / 65536, sans
        bne fr_big                ;   division (bits hauts de la graine)
        sta mt
        ldx #8
fr_l    lsr ev
        bcc fr_n
        pha
        clc
        lda mt
        adc rnd+2
        sta mt
        pla
        adc rnd+3
fr_n    ror
        ror mt
        dex
        bne fr_l
        sta ev
        rts
fr_big  jsr udiv                ; sinon : reste de la division
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
f_scrn  jsr x_open              ; SCRN(col,lig) : octet de la case
        jsr e_or
        jsr pushv
        jsr x_comma
        jsr e_or
        jsr x_close
        jsr popt
        jsr needlo
        lda et+1
        ora ev+1
        bne fs_lim
        lda et
        cmp #40
        bcs fs_lim
        lda ev
        cmp #28
        bcs fs_lim
        lda h_x1                ; paramètres de la commande gardés
        pha
        lda h_y1
        pha
        lda et
        sta h_x1
        lda ev
        sta h_y1
        jsr h_scrn
        sta ev
        pla
        sta h_y1
        pla
        sta h_x1
        lda #0
        sta ev+1
        rts
fs_lim  jmp e_lim
f_inkey lda pkey                ; touche gardée par le test d'ESC
        ldx #0
        stx pkey
ikv     sta ev                  ; puis le tampon, vidé (pas de retard
        jsr B_CONST             ; dû à la répétition) ; ESC arrête
        beq ike
        jsr h_key
        cmp #27
        bne ikv
        jmp r_esc
ike     lda KB_HELD
        ldx ev
        beq ikh
        sta ihi                 ; touche neuve : on retient sa place
        stx ihk
        bne ik
ikh     cmp #$FF                ; rien de neuf : la même touche encore
        beq ik                  ; enfoncée ? (sans délai de répétition)
        cmp ihi
        bne ik
        ldx ihk
        stx ev
ik      lda #0
        sta ev+1
        rts
arg1    jsr x_open
        jsr e_or
        jmp x_close
.)

; getv_kw : ev <- variable lue par parse_id (kw, X = longueur)
getv_kw jsr kw_var
        jsr vaddr
getv_p  ldy #0                  ; (variable d'adresse vptr)
        lda (vptr),y
        sta ev
        iny
        lda (vptr),y
        sta ev+1
        rts

; rand : et <- nombre pseudo-aléatoire de 0 à 32767 (X conservé)
;   xorshift 32 bits (8, 9, 23) : x ^= x << 8 ; x ^= x >> 9 ;
;   x ^= x << 23 ; période 2^32 - 1. Le résultat est le mot haut
;   (rnd+2, rnd+3), le mieux mélangé.
rand
        lda rnd+3               ; x ^= x << 8 : chaque octet reçoit
        eor rnd+2               ;   celui du dessous (du haut vers le bas)
        sta rnd+3
        lda rnd+2
        eor rnd+1
        sta rnd+2
        lda rnd+1
        eor rnd
        sta rnd+1
        lda rnd+2               ; x ^= x >> 9 : octet du dessus décalé
        lsr                     ;   d'un bit (du bas vers le haut)
        lda rnd+1
        ror
        eor rnd
        sta rnd
        lda rnd+3
        lsr
        lda rnd+2
        ror
        eor rnd+1
        sta rnd+1
        lda rnd+3
        lsr
        eor rnd+2
        sta rnd+2
        lda rnd+1               ; x ^= x << 23 : les 9 bits du bas
        lsr                     ;   montent en haut
        lda rnd
        ror
        eor rnd+3
        sta rnd+3
        lda #0
        ror
        eor rnd+2
        sta rnd+2
        sta et
        lda rnd+3
        and #$7F
        sta et+1
        rts

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
        jmp r_esc
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
        lda h_lo
        bne lo
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
lo      jsr skipsp              ; LORES : au curseur, sans déborder
        bne lo1
        jmp h_lnl               ; ECHO seul : ligne suivante, colonne 0
lo1     cmp #34
        bne lo3
        inx                     ; entre guillemets : tel quel, espaces
lo2     lda lbuf,x              ; compris
        beq r
        cmp #34
        beq r
        jsr h_lput
        inx
        bne lo2
lo3     lda lbuf,x
        beq r
        jsr h_lput
        inx
        bne lo3
        rts
.)
c_print stx ex                  ; une chaîne ?
        lda #1
        sta edep
        lda #0
        sta vsp
        jsr is_str
        bcs cpn
        jsr str_only
        bcs cpn
        jsr p_str
        ldx ex
        jsr endline
        jmp r_print
cpn     ldx ex
        jsr lexpr
        lda h_lo
        beq cp_c
        jsr fmtnum              ; LORES : au curseur, sans passer à la ligne
        lda #<numbuf
        ldy #>numbuf
        jmp h_lstr
cp_c    lda h_lines
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

; ---------------------------------------------------------------------
; LORES : l'écran texte au programme
; ---------------------------------------------------------------------
; needlo : erreur hors du LORES
needlo  lda h_lo
        bne nl_ok
        lda #<m_nolo
        ldy #>m_nolo
        jmp error
nl_ok   rts

; colrow : deux valeurs -> h_x1 (colonne 0-39) h_y1 (ligne 0-27)
colrow  jsr getbyte
        sta h_x1
        jsr getbyte
        sta h_y1
        lda h_x1
        cmp #40
        bcs e_lim
        lda h_y1
        cmp #28
        bcs e_lim
        rts
e_lim   lda #<m_lim
        ldy #>m_lim
        jmp error

c_lores jsr endline
        jmp h_lores
c_cls   jsr endline
        lda h_lo
        beq cls_c
        jmp h_lcls              ; LORES : attribut 16 partout
cls_c   lda h_lines             ; sinon : la console (pas en HIRES)
        cmp #200
        beq cls_r
        lda #12
        jmp putc
cls_r   rts
c_locate
        jsr needlo
        jsr colrow
        jsr endline
        jmp h_loc
c_char  jsr needlo
        jsr colrow
        jsr getbyte
        pha
        jsr endline
        pla
        jmp h_chr
c_spc
.(
        jsr needlo
        jsr getbyte             ; nombre
        pha
        jsr skipsp
        beq dflt
        cmp #";"
        beq dflt
        jsr getbyte             ; octet écrit
        .byt $2C                ; (BIT abs : saute lda #32)
dflt    lda #32
        sta gd
        jsr endline
        pla
        ldx gd
        jmp h_lspc
.)
c_tab   jsr needlo
        jsr getbyte
        pha
        jsr endline
        pla
        jmp h_ltab

; PRINTV, ECHOV, SPCV : comme PRINT, ECHO, SPC, le curseur descend
c_printv
        jsr needlo
        jsr h_lvon
        jsr c_print
        jmp h_lvoff
c_echov jsr needlo
        jsr h_lvon
        jsr c_echo
        jmp h_lvoff
c_spcv  jsr h_lvon
        jsr c_spc
        jmp h_lvoff

; needscr : LORES, HIRES ou SPLIT (pas la console)
needscr lda h_lines
        bne ns_ok
        jmp needlo
ns_ok   rts

; SCROLH n, SCROLV n [c1 l1 c2 l2 [x]], ROTH n, ROTV n [c1 l1 c2 l2]
c_scrolh
        lda #0
        .byt $2C                ; (BIT abs : saute l'instruction suivante)
c_scrolv
        lda #1
        .byt $2C
c_roth  lda #2
        .byt $2C
c_rotv  lda #3
.(
        pha
        jsr needscr
        jsr r_sdef              ; tout l'écran, remplissage par défaut
        jsr pexpr
        lda ev
        sta r_sn
        lda ev+1
        sta r_sn+1
        jsr skipsp
        beq e
        cmp #";"
        beq e
        jsr p2
        jsr getbyte
        sta h_x2
        jsr getbyte
        sta h_y2
        cmp h_y1                ; y1 <= y2 < lignes, x1 <= x2 < 40
        bcc lim
        jsr r_rows
        sta gd
        lda h_y2
        cmp gd
        bcs lim
        lda h_x2
        cmp #40
        bcs lim
        cmp h_x1
        bcc lim
        pla
        pha
        and #2
        bne e                   ; rotation : pas d'octet de remplissage
        jsr skipsp
        beq e
        cmp #";"
        beq e
        jsr getbyte
        sta r_sf
e       jsr endline
        pla
        jmp r_scrl
lim     jmp e_lim
.)

; PASTE T$(l,c) col lig larg haut : rectangle du tableau vers l'écran ;
;   GRAB : de l'écran vers le tableau
c_paste lda #0
        .byt $2C
c_grab  lda #1
.(
        pha
        jsr needscr
        jmp go
bad     jmp e_param
lim     jmp e_lim
go      jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda lbuf,x
        cmp #"$"
        bne bad
        inx
        stx ex
        lda #0
        sta vsp
        sta edep
        jsr x_open              ; indices -> flim, fstep
        jsr e_or
        lda ev
        sta flim
        lda ev+1
        sta flim+1
        jsr x_comma
        jsr e_or
        lda ev
        sta fstep
        lda ev+1
        sta fstep+1
        jsr x_close
        ldx ex
        lda lbuf,x
        cmp #" "
        bne bad
        jsr p2                  ; coin à l'écran
        jsr getbyte             ; largeur, hauteur : au moins 1, dans
        sta h_x2                ;   l'écran
        jsr getbyte
        sta h_y2
        jsr endline
        lda h_x2
        beq lim
        clc
        adc h_x1
        cmp #41
        bcs lim
        lda h_y2
        beq lim
        clc
        adc h_y1
        bcs lim
        sta gd
        jsr r_rows
        cmp gd
        bcc lim
        ldx h_y2                ; coin opposé dans le tableau : vérifié
        dex                     ;   par r_ea2
        txa
        clc
        adc flim
        sta et
        lda flim+1
        adc #0
        sta et+1
        ldx h_x2
        dex
        txa
        clc
        adc fstep
        sta ev
        lda fstep+1
        adc #0
        sta ev+1
        jsr pg_ea
        lda flim                ; coin de départ
        sta et
        lda flim+1
        sta et+1
        lda fstep
        sta ev
        lda fstep+1
        sta ev+1
        jsr pg_ea
        ldy #4                  ; octets par ligne du tableau
        lda (r_dp),y
        sta r_bst
        iny
        lda (r_dp),y
        sta r_bst+1
        lda r_sa
        sta hs
        lda r_sa+1
        sta hs+1
        pla
        jmp r_blit
pg_ea   lda aal
        ldx #1
        jsr desc_of
        jmp r_ea2
.)
c_get
.(
        jsr getvar              ; GET V : attend une touche, code dans V
        jsr endline
        jsr getkey
        cmp #27
        bne k
        jmp r_esc
k       sta ev
        lda #0
        sta ev+1
        jmp setvar
.)

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
spl     lda h_lo                ; depuis le LORES : la console d'abord
        beq spl1
        jsr h_text
spl1    lda #128                ; GLOAD du système : il passe en SPLIT
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

; ANIM nom [n] : animation .ANI en plein écran (n passages ; 0 ou
;   rien : jusqu'à une touche ; ESC arrête le programme)
c_anim
.(
        jsr animarg
        lda h_lines
        bne md
        jsr h_full              ; depuis le texte : plein écran
        jmp pl
md      cmp #200
        beq pl
        lda #<a_mh              ; pas en SPLIT
        ldy #>a_mh
        jmp error
pl      lda #<ifcb
        ldy #>ifcb
        ldx gd
        jsr a_play
        bcs er
        cmp #27
        bne r
        jmp r_esc
er      jsr a_msg
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

; ---------------------------------------------------------------------
; Tableaux et chaînes (palier B ; les routines sont dans arr.inc)
; ---------------------------------------------------------------------

; dsel : A = lettre, X = sorte -> A/Y = descripteur, X = octets par élément
dsel    stx gd
        jsr desc_of
        pha
        lda gd
        eor #1
        clc
        adc #1
        tax
        pla
        rts

; ndim_s : A = lettre -> A = dimensions de son tableau $ (0 : pas
;   réservé) : d'après le descripteur
ndim_s
.(
        ldx #1
        jsr desc_of
        sta gv
        sty gv+1
        ldy #7
        lda (gv),y
        rts
.)

; p_str : chaîne en ex -> chaîne courante (r_sa, r_sc)
p_str
.(
        jsr is_str
        bcs bad
        jsr gch
        cmp #34
        bne var
        inc ex                  ; texte entre guillemets : dans lbuf
        lda ex
        clc
        adc #<lbuf
        sta r_sa
        lda #>lbuf
        adc #0
        sta r_sa+1
        ldx #0
l       jsr gch
        beq bad                 ; pas de guillemet final
        inc ex
        cmp #34
        beq e
        inx
        bne l
e       stx r_sc
        rts
var     jsr isalpha
        pha
        inc ex                  ; la lettre et le $
        inc ex
        jsr gch
        cmp #"("
        beq row
        pla
        ldx #1
        jsr desc_of
        jmp r_whole
row     jsr x_open
        jsr e_or                ; ev = ligne
        jsr x_close
        pla
        ldx #1
        jsr desc_of
        jmp r_row
bad     jmp e_strc
.)

; a_get : élément du tableau (lettre A, X = 0 entiers / 1 $), indices
;   en ex -> ev
a_get
.(
        pha
        txa
        pha
        jsr x_open
        jsr e_or
        jsr ws
        jsr gch
        cmp #","
        beq two
        jsr x_close
        pla
        tax
        pla
        cpx #0
        beq one
        pha                     ; M$(i) d'un tableau à deux dimensions :
        jsr ndim_s              ;   une ligne, donc une chaîne
        cmp #2
        bne o1
        jmp e_strc
o1      pla
        ldx #1
one     jsr desc_of
        jmp r_get1
two     inc ex
        jsr pushv
        jsr e_or
        jsr x_close
        jsr popt
        pla
        tax
        pla
        jsr desc_of
        jmp r_get2
.)

; arr_assign : A(i[,j]) = expr, M$(l,c) = expr, A$ = chaîne,
;   M$(l) = chaîne (X sur le « ( » ou le « $ »)
arr_assign
.(
        stx ex
        lda #0
        sta vsp
        sta edep
        sta aak
        lda word
        sta aal
        jsr gch
        cmp #"$"
        bne t1
        inc ex
        inc aak
t1      jsr gch
        cmp #"("
        beq idx
        lda aal                 ; A$ = chaîne
        ldx #1
        jsr desc_of
        jsr r_whole
        jmp sas
idx     jsr x_open
        jsr e_or
        jsr ws
        jsr gch
        cmp #","
        beq two
        jsr x_close
        lda aak
        beq one
        lda aal
        jsr ndim_s
        cmp #2
        bne one
        lda aal                 ; M$(l) = chaîne
        ldx #1
        jsr desc_of
        jsr r_row
        jmp sas
one     lda aal
        ldx aak
        jsr desc_of
        jsr r_ea1
        jmp elt
two     inc ex
        jsr pushv
        jsr e_or
        jsr x_close
        jsr popt
        lda aal
        ldx aak
        jsr desc_of
        jsr r_ea2
elt     lda r_sa+1              ; adresse de l'élément gardée
        pha
        lda r_sa
        pha
        jsr aeq
        jsr lexpr               ; valeur -> ev
        pla
        sta et
        pla
        sta et+1
        lda aak
        bne b
        jmp r_stw
b       jmp r_stb
sas     jsr r_save              ; destination gardée
        jsr aeq
        jsr p_str               ; source
        ldx ex
        jsr endline
        jsr r_swap
        jmp r_copy
.)

; DIM A(n) B$(n,m)... : tableaux réservés (indices de 0 à n-1)
c_dim
.(
        jsr skipsp
        beq bad
item    jsr isalpha
        bcs bad
        sta aal
        inx
        lda #0
        sta aak
        lda lbuf,x
        cmp #"$"
        bne i1
        inx
        inc aak
i1      stx ex
        lda #0
        sta vsp
        sta edep
        jsr x_open
        jsr e_or
        jsr ws
        jsr gch
        cmp #","
        beq two
        jsr x_close
        lda aal
        ldx aak
        jsr dsel
        jsr r_dim1
        jmp nx
two     inc ex
        jsr pushv
        jsr e_or
        jsr x_close
        jsr popt
        lda aal
        ldx aak
        jsr dsel
        jsr r_dim2
nx      ldx ex
        lda lbuf,x
        beq r
        cmp #" "
        bne bad
        jsr skipsp
        beq r
        cmp #";"
        bne item
r       rts
bad     jmp e_param
.)

; FILL A v / FILL A$ v : tout le tableau à v
c_fill
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda #0
        sta aak
        lda lbuf,x
        cmp #"$"
        bne f1
        inx
        inc aak
f1      lda lbuf,x
        cmp #" "
        bne bad
        jsr pexpr
        jsr endline
        lda aal
        ldx aak
        jsr desc_of
        jmp r_fill
bad     jmp e_param
.)

; INPUT V (entier) ou INPUT A$ / INPUT M$(l) (chaîne)
c_input
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        lda lbuf+1,x
        cmp #"$"
        beq str
        jsr getvar
        jsr endline
        jsr r_ninput            ; -> ev
        jmp setvar
str     stx ex
        lda #1
        sta edep
        lda #0
        sta vsp
        jsr p_str
        ldx ex
        jsr endline
        jmp r_input
bad     jmp e_param
.)

; r_esc : ESC pendant une saisie (arr.inc)
r_esc   lda #<m_esc
        ldy #>m_esc
        jmp stop_msg

; ---------------------------------------------------------------------
; Calcul et contrôle
; ---------------------------------------------------------------------
c_let   jsr getvar
        jsr skipsp
        cmp #"="
        beq assign
        jmp e_param
; assign : variable vix, vc ; X sur le « = »
assign  jsr vaddr               ; (l'expression change vix, vc et vptr)
        lda vptr
        pha
        lda vptr+1
        pha
        inx
        jsr lexpr
        pla
        sta vptr+1
        pla
        sta vptr
        jmp setv_p

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
        jsr vaddr
        lda vptr
        sta fvar
        lda vptr+1
        sta fvar+1
        jsr pexpr               ; départ
        jsr fv_ptr
        jsr setv_p
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
        lda fvar+1
        sta cs_vh,y
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
        jsr cs_var
        sec                     ; var - arrivée (signé)
        lda gv
        sbc cs_al,y
        sta mt
        lda gv+1
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

; cs_var : gv <- variable de la boucle de l'entrée Y (vptr ; Y gardé)
cs_var  lda cs_v,y
        sta vptr
        lda cs_vh,y
        sta vptr+1
        sty gd
        ldy #0
        lda (vptr),y
        sta gv
        iny
        lda (vptr),y
        sta gv+1
        ldy gd
        rts

; fv_ptr : vptr <- fvar (variable du FOR en cours)
fv_ptr  lda fvar
        sta vptr
        lda fvar+1
        sta vptr+1
        rts

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
for     jsr cs_var              ; var += pas
        clc
        lda gv
        adc cs_bl,y
        sta ev
        lda gv+1
        adc cs_bh,y
        sta ev+1
        php
        jsr setv_p              ; (vptr de cs_var)
        plp
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

; to_text : quitte le HIRES plein écran ou le LORES (console rendue) ;
;   l'historique des lignes est vidé si le jeu secondaire a servi aux
;   sprites (il l'a recouvert)
to_text lda s_hst
        beq tt_0
        lda #0
        sta S_HIST
tt_0    lda h_lo
        bne tt_t
        lda h_lines
        cmp #200
        bne tt_r
tt_t    jmp h_text
tt_r    rts

; getkey : touche gardée par le test d'ESC, sinon attend une touche
getkey  lda pkey
        beq gk
        ldx #0
        stx pkey
        rts
gk      jmp h_key
t_img   .asc "IMG"
t_hir   .asc "HIR"

; ---------------------------------------------------------------------
; /A : CHAIN « GRXASM » suivi de la ligne d'origine sans son premier mot
;   (GRXASM ignore /A) ; la ligne de CHAIN fait 78 caractères au plus
; ---------------------------------------------------------------------
to_grxasm
.(
        ldy #5
c       lda t_gxa,y
        sta rawbuf,y
        dey
        bpl c
        ldx #0
s       lda ORIG_LINE,x         ; espaces, puis le premier mot
        cmp #" "
        bne w
        inx
        bne s
w       lda ORIG_LINE,x
        beq e
        cmp #" "
        beq e
        inx
        bne w
e       ldy #6
cp      lda ORIG_LINE,x
        sta rawbuf,y
        beq go
        inx
        iny
        cpy #79
        bcc cp
        ldx #F_PRINT
        lda #<m_chain
        ldy #>m_chain
        jmp BDOS
go      lda #<rawbuf
        ldy #>rawbuf
        ldx #F_CHAIN
        jmp BDOS
.)

; SAVE, LOAD, BSAVE, BLOAD : tableau ou SCREEN, puis nom (fil.inc)
c_save  lda #0
        beq c_file
c_load  lda #1
        bne c_file
c_bsave lda #2
        bne c_file
c_bload lda #3
c_file
.(
        pha
        jsr f_arg               ; aal, aak (2 : SCREEN)
        jsr getname             ; -> ifcb, rien d'autre ensuite
        pla
        tax
        lda aak
        cmp #2
        bne ar
        cpx #2                  ; SCREEN : BSAVE et BLOAD seulement
        bcc bad
        inx
        inx
        jmp f_go
ar      stx gd
        lda aal
        ldx aak
        jsr desc_of
        ldx gd
        jmp f_go
bad     jmp e_param
.)

; ---------------------------------------------------------------------
; Sprites (spr.inc)
; ---------------------------------------------------------------------
; SPRITES n : n emplacements
c_sprites
        jsr pexpr
        jsr endline
        jmp s_res
; SPOOL T [ALT] : le tableau d'entiers T devient le tas du jeu
c_spool jsr intarg
        jsr altopt
        sta gd
        lda aal
        ldx #0
        jsr desc_of
        ldx gd
        jmp s_pool
; SSHOW k S$ n col lig [ALT]
c_sshow jsr needlo
        jsr getbyte
        sta s_k
        jsr sprarg
        jsr getbyte
        sta s_n
        jsr getbyte
        sta s_col
        jsr getbyte
        sta s_lig
        jsr altopt
        sta gd
        lda aal
        ldx #1
        jsr desc_of
        ldx gd
        jmp s_show
; SHIDE k
c_shide jsr needlo
        jsr getbyte
        pha
        jsr endline
        pla
        jmp s_hide

; ---------------------------------------------------------------------
; Tuiles (spr.inc)
; ---------------------------------------------------------------------
; TILE(x,y) : numéro de la tuile sous le caractère du monde
f_tile  jsr x_open
        jsr e_or
        jsr pushv
        jsr x_comma
        jsr e_or
        jsr x_close
        jsr popt
        jmp t_get               ; (r_i = et, r_j = ev)
; TILESET D$ larg haut [K$]
c_tileset
        jsr sprarg
        jsr getbyte
        sta t_w
        jsr getbyte
        sta t_h
        jsr skipsp
        beq ts_no
        cmp #";"
        beq ts_no
        stx ex
        lda #0
        sta edep
        jsr p_str               ; K$ : chaîne courante
        ldx ex
        jsr endline
        lda #1
        .byt $2C                ; (BIT abs : saute lda #0)
ts_no   lda #0
        sta gd
        lda aal
        ldx #1
        jsr desc_of
        ldx gd
        jmp t_set
; TMAP T$ X Y col lig larg haut
c_tmap  jsr needlo
        jsr sprarg
        jsr pexpr
        lda ev
        sta t_x
        lda ev+1
        sta t_x+1
        jsr pexpr
        lda ev
        sta t_y
        lda ev+1
        sta t_y+1
        jsr p2
        jsr getbyte
        sta h_x2
        jsr getbyte
        sta h_y2
        jsr endline
        lda aal
        ldx #1
        jsr desc_of
        jmp t_map
; TFONT S$ code [ALT]
c_tfont jsr needlo
        jsr sprarg
        jsr getbyte
        sta t_c
        jsr altopt
        sta gd
        lda aal
        ldx #1
        jsr desc_of
        ldx gd
        jmp t_font

; affectations ; ANIM
x_asg   = assign
x_aasg  = arr_assign
an_val  jsr getbyte             ; ANIM nom n : passages dans gd
        sta gd
        jmp endline
an_none
o_drop  rts                     ; (pas de fichier de sortie)

#include "grapher.msg"         ; messages (progs/msg/fr, en)
#include "grxc.msg"            ; messages de grxc_inc.s
t_gxa   .asc "GRXASM"

#include "grxc_inc.s"

; adresses des commandes, dans l'ordre de la table cmds (grxc_inc.s) : exécution
cadr
        .word c_next     ; NEXT
        .word c_if       ; IF
        .word c_endif    ; ENDIF
        .word c_else     ; ELSE
        .word c_locate   ; LOCATE
        .word c_char     ; CHAR
        .word c_sshow    ; SSHOW
        .word c_shide    ; SHIDE
        .word c_plot     ; PLOT
        .word c_line     ; LINE
        .word c_let      ; LET
        .word c_for      ; FOR
        .word c_repeat   ; REPEAT
        .word c_while    ; WHILE
        .word c_call     ; CALL
        .word c_return   ; ENDSUB
        .word c_return   ; RETURN
        .word c_sub      ; SUB
        .word c_box      ; BOX
        .word c_fbox     ; FBOX
        .word c_circle   ; CIRCLE
        .word c_pen      ; PEN
        .word c_gtext    ; GTEXT
        .word c_gnum     ; GNUM
        .word c_attr     ; ATTR
        .word c_gcls     ; GCLS
        .word c_print    ; PRINT
        .word c_delay    ; DELAY
        .word c_wait     ; WAIT
        .word c_echo     ; ECHO
        .word c_hires    ; HIRES
        .word c_split    ; SPLIT
        .word c_text     ; TEXT
        .word c_gload    ; GLOAD
        .word c_anim     ; ANIM
        .word c_gsave    ; GSAVE
        .word c_end      ; END
        .word c_spc      ; SPC
        .word c_tab      ; TAB
        .word c_get      ; GET
        .word c_cls      ; CLS
        .word c_lores    ; LORES
        .word c_dim      ; DIM
        .word c_fill     ; FILL
        .word c_input    ; INPUT
        .word c_save     ; SAVE
        .word c_load     ; LOAD
        .word c_bsave    ; BSAVE
        .word c_bload    ; BLOAD
        .word c_sprites  ; SPRITES
        .word c_spool    ; SPOOL
        .word c_paste    ; PASTE
        .word c_grab     ; GRAB
        .word c_scrolh   ; SCROLH
        .word c_scrolv   ; SCROLV
        .word c_roth     ; ROTH
        .word c_rotv     ; ROTV
        .word c_printv   ; PRINTV
        .word c_echov    ; ECHOV
        .word c_spcv     ; SPCV
        .word c_tileset  ; TILESET
        .word c_tmap     ; TMAP
        .word c_tfont    ; TFONT

a_fail  = error         ; (anim.inc : pour les programmes traduits)
r_fail  = error         ; arr.inc : erreurs, valeurs (ev, et)
r_i     = et
r_j     = ev
#include "anim.inc"
#include "anim.msg"
#include "arr.inc"
#include "arr.msg"
f_fcb   = ifcb          ; fil.inc : fichier de données, nombres
f_fmt   = fmtnum
f_nbuf  = numbuf
f_mlo   = m_nolo
f_mful  = m_full
f_mro   = m_ro
f_mdir  = m_dirf
#include "fil.inc"
#include "fil.msg"
#include "spr.inc"
#include "spr.msg"
#include "hires.inc"

; tampons après les tables de hires.inc, mis à 0 au lancement (bufs à
;   fstep+1), puis les variables (vars, VSIZE octets)
bufs    = h_free
sfcb    = bufs          ; .GRX
ifcb    = sfcb+36       ; image, animation
par_lo  = ifcb+36       ; paramètres $1-$9 : adresse et longueur
par_hi  = par_lo+NPAR
par_len = par_hi+NPAR
word    = par_len+NPAR  ; commande en cours
kw      = word+9        ; mot cherché dans la table
cname   = kw+9          ; nom de sous-programme
numbuf  = cname+9       ; nombre écrit
fvar    = numbuf+8  ; FOR : adresse de la variable (2 octets)
aal     = fvar+2        ; tableau en cours : lettre
aak     = aal+1         ;   et sorte (0 entiers, 1 $)
s_hst   = aak+1         ; 1 : jeu secondaire redessiné (spr.inc)
flim    = s_hst+1       ; FOR : arrivée
fstep   = flim+2        ;   et pas
NBUF    = fstep+2-bufs
cs_t    = fstep+2       ; pile de contrôle : type
cs_v    = cs_t+NCS      ;   adresse de la variable (FOR)
cs_vh   = cs_v+NCS
cs_pl   = cs_vh+NCS     ;   ligne de reprise
cs_ph   = cs_pl+NCS
cs_al   = cs_ph+NCS     ;   compte (REPEAT) ou arrivée (FOR)
cs_ah   = cs_al+NCS
cs_bl   = cs_ah+NCS     ;   pas (FOR)
cs_bh   = cs_bl+NCS
vs_lo   = cs_bh+NCS     ; pile des valeurs
vs_hi   = vs_lo+NVS
rawbuf  = vs_hi+NVS     ; ligne lue
lbuf    = rawbuf+LMAX+1 ;   puis $1-$9 remplacés
vars    = lbuf+LMAX+1   ; variables : 26 * 37 de 2 octets (vaddr)
VSIZE   = 1924
ptext   = vars+VSIZE    ; texte du fichier, jusqu'à PTOP
