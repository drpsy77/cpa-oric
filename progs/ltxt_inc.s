; =====================================================================
;  ltxt_inc.s — mots et listes de LOGO (inclus par logo.s)
;
;  Un mot (T_WORD) ou une liste (T_LIST) est un texte rangé dans le tas :
;  contenu de la valeur = adresse (2 octets), longueur (2 octets). Une
;  liste est le texte de ses éléments séparés par une espace, sans les
;  crochets extérieurs ; une sous-liste est un groupe [...] (une seule
;  espace entre les éléments, aucune après [ ni avant ]).
;
;  Le tas descend de memtop ; hp est son bas. Les procédures montent de
;  procbase à pend. Quand la place manque, gc compacte le tas : les textes
;  encore désignés montent contre memtop, l'un après l'autre en partant du
;  plus haut (à la manière du BASIC Microsoft).
;
;  Règles qui rendent le compactage sûr :
;  - chaque texte a son bloc : un résultat est toujours une copie, jamais
;    un morceau d'un autre texte (deux valeurs peuvent désigner le même
;    bloc entier, jamais une partie) ;
;  - seules comptent les valeurs des variables, des arguments (argv, type 0
;    hors d'un appel) et de la pile de valeurs ; val et lv n'en font pas
;    partie. Une primitive qui réserve de la place (halloc) met d'abord ses
;    textes sur la pile de valeurs, et relit leurs adresses après.
; =====================================================================

; ---------------------------------------------------------------------
; Réservation et compactage
; ---------------------------------------------------------------------
; halloc : hptr = bloc de hn octets ; compacte si besoin ; erreur si plein
halloc
.(
        jsr try
        bcc ok
        jsr hcompact
        jsr try
        bcc ok
        lda #0
        sta clen
        lda #<e_mem
        ldy #>e_mem
        jmp error
ok      rts
try     sec
        lda hp
        sbc hn
        sta hptr
        lda hp+1
        sbc hn+1
        sta hptr+1
        bcc no
        lda hptr+1              ; au moins une page au-dessus des procédures
        cmp pend+1
        beq no
        bcc no
        lda hptr
        sta hp
        lda hptr+1
        sta hp+1
        clc
        rts
no      sec
        rts
.)

; hcompact : compacte le tas contre memtop
hcompact
.(
        lda memtop
        sta gtop
        lda memtop+1
        sta gtop+1
        lda hp
        sta glim
        lda hp+1
        sta glim+1
loop    lda #0                  ; le plus haut des textes pas encore montés
        sta gfnd
        lda #<cb_max
        sta cbv
        lda #>cb_max
        sta cbv+1
        jsr dscan
        lda gfnd
        beq done
        sec                     ; il va juste sous gtop
        lda gtop
        sbc glen
        sta gdst
        lda gtop+1
        sbc glen+1
        sta gdst+1
        jsr gmove
        lda #<cb_upd            ; toutes les valeurs qui le désignent
        sta cbv
        lda #>cb_upd
        sta cbv+1
        jsr dscan
        lda gdst
        sta gtop
        lda gdst+1
        sta gtop+1
        jmp loop
done    lda gtop
        sta hp
        lda gtop+1
        sta hp+1
        rts
.)

; dscan : appelle (cbv) pour chaque valeur rangée ; dp -> octet de type
dscan
.(
        lda #16
        sta dstr
        lda #<gl_v
        ldx #>gl_v
        ldy ngl
        jsr reg
        lda #<lo_v
        ldx #>lo_v
        ldy nloc
        jsr reg
        lda #VAL_SIZE
        sta dstr
        lda #<argv
        ldx #>argv
        ldy #MAXPAR
        jsr reg
        sec                     ; pile de valeurs : (vsp - vstack) / 6
        lda vsp
        sbc #<vstack
        ldy #0
d6      cmp #VAL_SIZE
        bcc d7
        sbc #VAL_SIZE
        iny
        bne d6
d7      lda #<vstack
        ldx #>vstack
reg     sta dp
        stx dp+1
        sty dcnt
rl      lda dcnt
        beq rr
        jsr callcb
        clc
        lda dp
        adc dstr
        sta dp
        bcc rn
        inc dp+1
rn      dec dcnt
        jmp rl
rr      rts
callcb  jmp (cbv)
.)

; cb_max : retient le texte non monté (glim <= adresse < gtop) le plus haut
cb_max
.(
        ldy #0
        lda (dp),y
        cmp #T_WORD
        bcc r
        ldy #3                  ; longueur nulle : pas de bloc
        lda (dp),y
        iny
        ora (dp),y
        beq r
        ldy #1                  ; adresse >= glim ?
        lda (dp),y
        cmp glim
        iny
        lda (dp),y
        sbc glim+1
        bcc r
        ldy #1                  ; adresse < gtop ?
        lda (dp),y
        cmp gtop
        iny
        lda (dp),y
        sbc gtop+1
        bcs r
        lda gfnd
        beq take
        ldy #1                  ; plus haute que gbest ?
        lda gbest
        cmp (dp),y
        iny
        lda gbest+1
        sbc (dp),y
        bcs r
take    ldy #1
        lda (dp),y
        sta gbest
        iny
        lda (dp),y
        sta gbest+1
        iny
        lda (dp),y
        sta glen
        iny
        lda (dp),y
        sta glen+1
        lda #1
        sta gfnd
r       rts
.)

; cb_upd : une valeur qui désigne gbest désigne maintenant gdst
cb_upd
.(
        ldy #0
        lda (dp),y
        cmp #T_WORD
        bcc r
        ldy #1
        lda (dp),y
        cmp gbest
        bne r
        iny
        lda (dp),y
        cmp gbest+1
        bne r
        lda gdst+1
        sta (dp),y
        dey
        lda gdst
        sta (dp),y
r       rts
.)

; gmove : copie glen octets de gbest vers gdst (gdst >= gbest), par le haut
gmove
.(
        clc
        lda gbest
        adc glen
        sta ts
        lda gbest+1
        adc glen+1
        sta ts+1
        clc
        lda gdst
        adc glen
        sta td
        lda gdst+1
        adc glen+1
        sta td+1
        lda glen
        sta tl
        lda glen+1
        sta tl+1
l       lda tl
        ora tl+1
        beq r
        lda ts
        bne a1
        dec ts+1
a1      dec ts
        lda td
        bne a2
        dec td+1
a2      dec td
        ldy #0
        lda (ts),y
        sta (td),y
        lda tl
        bne a3
        dec tl+1
a3      dec tl
        jmp l
r       rts
.)

; ---------------------------------------------------------------------
; Copies
; ---------------------------------------------------------------------
; cpy_out : copie tl octets de ts vers td ; td avance d'autant
cpy_out
.(
l       lda tl
        ora tl+1
        beq r
        ldy #0
        lda (ts),y
        jsr emit
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

; emit : écrit A en td, td avance
emit
.(
        ldy #0
        sta (td),y
        inc td
        bne r
        inc td+1
r       rts
.)

; mk_text : valeur courante = copie dans le tas du texte ts, tl (hors du
;   tas), de type A
mk_text
        pha
        lda tl
        sta hn
        lda tl+1
        sta hn+1
        jsr halloc
        lda hptr
        sta td
        lda hptr+1
        sta td+1
        jsr cpy_out
        pla
; set_txt : valeur courante = texte de type A, en hptr, de longueur hn
set_txt
        sta vt
        lda hptr
        sta val
        lda hptr+1
        sta val+1
        lda hn
        sta val+2
        lda hn+1
        sta val+3
        rts

; txt_v : ts, tl = texte de la valeur courante
txt_v   lda val
        sta ts
        lda val+1
        sta ts+1
        lda val+2
        sta tl
        lda val+3
        sta tl+1
        rts

; ---------------------------------------------------------------------
; Littéraux
; ---------------------------------------------------------------------
; lit_word : "MOT (jeton tnam, tlen) -> mot
lit_word
        lda tnam
        sta ts
        lda tnam+1
        sta ts+1
        lda tlen
        sta tl
        lda #0
        sta tl+1
        lda #T_WORD
        jsr mk_text
        jmp advance

; lit_list : [ ... ] (lstart..lend, déjà passé par need_list) -> liste,
;   espaces normalisés
lit_list
        lda #0                  ; 1er passage : longueur
        sta nwr
        jsr norm
        lda tl
        sta hn
        lda tl+1
        sta hn+1
        jsr halloc
        lda hptr
        sta td
        lda hptr+1
        sta td+1
        lda #1                  ; 2e passage : écriture
        sta nwr
        jsr norm
        lda #T_LIST
        jmp set_txt

; norm : parcourt lstart..lend ; tl = longueur normalisée ; écrit en td
;   si nwr <> 0. Les blancs deviennent une espace, sauf au début, à la fin,
;   après [ et avant ].
norm
.(
        lda lstart
        sta ts
        lda lstart+1
        sta ts+1
        lda #0
        sta tl
        sta tl+1
        sta npend               ; un blanc attend
        lda #"["
        sta nlast               ; comme après un [ : pas d'espace au début
l       lda ts
        cmp lend
        bne go
        lda ts+1
        cmp lend+1
        beq r
go      ldy #0
        lda (ts),y
        cmp #" "+1
        bcs ch
        lda #1
        sta npend
        bne nx
ch      cmp #"]"
        beq put
        ldx npend
        beq put
        ldx nlast
        cpx #"["
        beq put
        pha
        lda #" "
        jsr out
        pla
put     sta nlast
        jsr out
        lda #0
        sta npend
nx      inc ts
        bne l
        inc ts+1
        jmp l
r       rts
out     inc tl
        bne o1
        inc tl+1
o1      ldx nwr
        beq o2
        jmp emit
o2      rts
.)

; ---------------------------------------------------------------------
; Conversions entre nombres et textes
; ---------------------------------------------------------------------
; as_text : un nombre devient un mot (son écriture par ECRIS)
as_text
.(
        lda vt
        cmp #T_WORD
        bcs r
        lda #0
        sta ncap
        lda #$80                ; putc écrit dans nbuf
        sta capf
        jsr put_val
        lda #0
        sta capf
        lda #<nbuf
        sta ts
        lda #>nbuf
        sta ts+1
        lda ncap
        sta tl
        lda #0
        sta tl+1
        lda #T_WORD
        jmp mk_text
r       rts
.)

; try_num : C=0 si la valeur courante est un nombre ou un mot qui en a
;   l'écriture (il devient alors ce nombre) ; C=1 sinon
try_num
.(
        lda vt
        cmp #T_DEC+1
        bcs t1
        jmp ok
t1      cmp #T_WORD
        bne no1
        lda val+3
        bne no1
        lda val+2               ; 1 à 30 caractères
        beq no1
        cmp #31
        bcc t2
no1     jmp no
t2      sta nlen
        jsr txt_v               ; copie dans nbuf, 0 à la fin
        ldy #0
c       lda (ts),y
        sta nbuf,y
        iny
        cpy nlen
        bne c
        lda #0
        sta nbuf,y
        ldx #0                  ; signe
        lda nbuf
        cmp #"-"
        bne s1
        inx
s1      lda nbuf,x              ; un chiffre doit suivre
        sec
        sbc #"0"
        cmp #10
        bcs no
        txa
        pha
        clc
        adc #<nbuf
        sta fpt
        lda #>nbuf
        adc #0
        sta fpt+1
        jsr fp_parse            ; FAC ; Y = caractères lus
        pla
        sta nlast
        tya
        clc
        adc nlast
        cmp nlen
        bne no                  ; tout le mot doit être lu
        lda nbuf
        cmp #"-"
        bne s2
        jsr fp_neg
s2      ldy #0                  ; sans point ni E : un entier, s'il tient
d       lda nbuf,y
        cmp #"."
        beq flt
        cmp #"E"
        beq flt
        iny
        cpy nlen
        bne d
        jsr fp_toint
        bcs flt
        sta val
        sty val+1
        lda #T_INT
        sta vt
ok      clc
        rts
flt     jsr fac_val
        clc
        rts
no      sec
        rts
.)

; swap_l : échange la valeur courante et la valeur de gauche
swap_l
.(
        ldx #4
l       lda val,x
        ldy lv,x
        sta lv,x
        tya
        sta val,x
        dex
        bpl l
        lda vt
        ldy lvt
        sta lvt
        sty vt
        rts
.)

; equal : A = 1 si la valeur de gauche et la valeur courante sont égales
;   (deux nombres, ou deux textes du même type et identiques), 0 sinon
equal
.(
        jsr swap_l
        jsr try_num
        php
        jsr swap_l
        plp
        bcs txt
        jsr try_num             ; gauche nombre : droite aussi ?
        bcs ne
        jsr compare
        cmp #0
        bne ne
eq      lda #1
        rts
ne      lda #0
        rts
txt     lda vt                  ; gauche texte : même type et même texte
        cmp lvt
        bne ne
        lda val+2
        cmp lv+2
        bne ne
        lda val+3
        cmp lv+3
        bne ne
        jsr txt_v
        lda lv
        sta td
        lda lv+1
        sta td+1
        jsr memeq
        beq eq
        bne ne
.)

; memeq : Z=1 si les tl octets en ts et en td sont égaux
memeq
.(
l       lda tl
        ora tl+1
        beq r
        ldy #0
        lda (ts),y
        cmp (td),y
        bne r
        inc ts
        bne a1
        inc ts+1
a1      inc td
        bne a2
        inc td+1
a2      lda tl
        bne a3
        dec tl+1
a3      dec tl
        jmp l
r       rts
.)

; ---------------------------------------------------------------------
; Éléments d'une liste (es, en : début et longueur d'un élément ;
; parcours de sp à se)
; ---------------------------------------------------------------------
; sc_init : parcours du texte ts, tl
sc_init lda ts
        sta scp
        lda ts+1
        sta scp+1
        clc
        lda ts
        adc tl
        sta sce
        lda ts+1
        adc tl+1
        sta sce+1
        rts

; sc_end : C=1 si le parcours est fini (sp >= se)
sc_end  lda scp+1
        cmp sce+1
        bne se1
        lda scp
        cmp sce
se1     rts

; el_next : élément suivant -> es, en ; sp passe l'espace qui le suit
el_next
.(
        lda scp
        sta els
        lda scp+1
        sta els+1
        ldx #0                  ; profondeur des crochets
l       jsr sc_end
        bcs end
        ldy #0
        lda (scp),y
        cmp #"["
        bne n1
        inx
        bne nx
n1      cmp #"]"
        bne n2
        dex
        jmp nx
n2      cmp #" "
        bne nx
        cpx #0
        beq end
nx      inc scp
        bne l
        inc scp+1
        jmp l
end     sec
        lda scp
        sbc els
        sta eln
        lda scp+1
        sbc els+1
        sta eln+1
        jsr sc_end              ; saute l'espace
        bcs r
        inc scp
        bne r
        inc scp+1
r       rts
.)

; el_kind : élément es, en -> A = T_LIST (es, en sans les crochets) ou
;   T_WORD
el_kind
.(
        ldy #0
        lda (els),y
        cmp #"["
        bne w
        inc els
        bne a1
        inc els+1
a1      sec
        lda eln
        sbc #2
        sta eln
        bcs a2
        dec eln+1
a2      lda #T_LIST
        rts
w       lda #T_WORD
        rts
.)

; ---------------------------------------------------------------------
; Arguments des fonctions de texte
; ---------------------------------------------------------------------
; arg1r : un argument, tel quel
arg1r   jsr advance
        jmp sum
; arg1t : un argument, en texte, empilé
arg1t   jsr advance
        jsr sum
        jsr as_text
        jmp vpush
; arg2t : deux arguments, en texte, empilés (a dessous, b dessus)
arg2t   jsr arg1t
        jsr sum
        jsr as_text
        jmp vpush

; ld_s : sa (A = 12 : a) ou sb (A = 6 : b, le haut) = valeur à vsp - A
ld_sa   lda #12
        ldx #0
        beq lds
ld_sb   lda #6
        ldx #5
lds     sta tmp
        sec
        lda vsp
        sbc tmp
        sta tmp
        lda vsp+1
        sbc #0
        sta tmp+1
        ldy #0
lds1    lda (tmp),y
        sta s_t,x
        inx
        iny
        cpy #5
        bne lds1
        rts

; vdrop : retire A octets de la pile de valeurs
vdrop   sta tmp
        sec
        lda vsp
        sbc tmp
        sta vsp
        bcs vd1
        dec vsp+1
vd1     rts

; top_txt : ts, tl = texte de la valeur du haut de la pile (b)
top_txt jsr ld_sb
        lda s_t+6
        sta ts
        lda s_t+7
        sta ts+1
        lda s_t+8
        sta tl
        lda s_t+9
        sta tl+1
        rts

; take : valeur courante = copie de en octets pris à l'écart eo du texte du
;   haut de la pile (qui est retiré), de type A
take
        pha
        lda eln
        sta hn
        lda eln+1
        sta hn+1
        jsr halloc              ; le texte a pu bouger : on le relit
        jsr top_txt
        clc
        lda ts
        adc elo
        sta ts
        lda ts+1
        adc elo+1
        sta ts+1
        lda eln
        sta tl
        lda eln+1
        sta tl+1
        lda hptr
        sta td
        lda hptr+1
        sta td+1
        jsr cpy_out
        lda #6
        jsr vdrop
        pla
        jmp set_txt

; e_vide : erreur pour un mot ou une liste vide
err_empty
        lda #<e_empty
        ldy #>e_empty
        bne terr
err_word
        lda #<e_word
        ldy #>e_word
terr    ldx #0
        stx clen
        jmp error

; ---------------------------------------------------------------------
; Fonctions
; ---------------------------------------------------------------------
; PREMIER x
f_premier
.(
        jsr arg1t
        jsr top_txt
        lda tl
        ora tl+1
        beq e
        lda #0
        sta elo
        sta elo+1
        lda s_t+5
        cmp #T_LIST
        beq lst
        lda #1
        sta eln
        lda #0
        sta eln+1
        lda #T_WORD
        jmp take
lst     jsr sc_init
        jsr el_next
        jmp el_take
e       jmp err_empty
.)

; el_take : prend l'élément es, en du texte du haut de la pile
el_take jsr el_kind
        pha
        sec                     ; écart depuis le début du texte
        lda els
        sbc ts
        sta elo
        lda els+1
        sbc ts+1
        sta elo+1
        pla
        jmp take

; DERNIER x
f_dernier
.(
        jsr arg1t
        jsr top_txt
        lda tl
        ora tl+1
        beq e
        lda s_t+5
        cmp #T_LIST
        beq lst
        sec                     ; dernier caractère
        lda tl
        sbc #1
        sta elo
        lda tl+1
        sbc #0
        sta elo+1
        lda #1
        sta eln
        lda #0
        sta eln+1
        lda #T_WORD
        jmp take
lst     jsr sc_init
l       jsr el_next
        jsr sc_end
        bcc l
        jmp el_take
e       jmp err_empty
.)

; SAUFPREMIER x
f_sp
.(
        jsr arg1t
        jsr top_txt
        lda tl
        ora tl+1
        beq e
        lda s_t+5
        cmp #T_LIST
        beq lst
        lda #1                  ; mot : à partir du 2e caractère
        sta elo
        lda #0
        sta elo+1
        sec
        lda tl
        sbc #1
        sta eln
        lda tl+1
        sbc #0
        sta eln+1
        lda #T_WORD
        jmp take
lst     jsr sc_init             ; liste : après le premier élément
        jsr el_next
        sec
        lda scp
        sbc ts
        sta elo
        lda scp+1
        sbc ts+1
        sta elo+1
        sec
        lda sce
        sbc scp
        sta eln
        lda sce+1
        sbc scp+1
        sta eln+1
        lda #T_LIST
        jmp take
e       jmp err_empty
.)

; SAUFDERNIER x
f_sd
.(
        jsr arg1t
        jsr top_txt
        lda tl
        ora tl+1
        beq e
        lda #0
        sta elo
        sta elo+1
        lda s_t+5
        cmp #T_LIST
        beq lst
        sec                     ; mot : sans le dernier caractère
        lda tl
        sbc #1
        sta eln
        lda tl+1
        sbc #0
        sta eln+1
        lda #T_WORD
        jmp take
lst     jsr sc_init             ; liste : jusqu'avant le dernier élément
l       jsr el_next
        jsr sc_end
        bcc l
        sec                     ; longueur = début du dernier - 1 (ou 0)
        lda els
        sbc ts
        sta eln
        lda els+1
        sbc ts+1
        sta eln+1
        ora eln
        beq z
        lda eln
        bne a1
        dec eln+1
a1      dec eln
z       lda #T_LIST
        jmp take
e       jmp err_empty
.)

; ITEM n x
f_item
.(
        jsr advance
        jsr sum
        jsr to_int
        jsr vpush               ; n (entier : le tas ne le voit pas)
        jsr sum
        jsr as_text
        jsr vpush
        jsr ld_sa               ; n dans s_t+1..2
        lda s_t+2               ; n doit être 1..255
        bne e
        lda s_t+1
        beq e
        sta tmp2
        jsr top_txt
        lda s_t+5
        cmp #T_LIST
        beq lst
        lda tl+1                ; mot : n <= longueur
        bne w1
        lda tl
        cmp tmp2
        bcc e
w1      ldx tmp2
        dex
        stx elo
        lda #0
        sta elo+1
        sta eln+1
        lda #1
        sta eln
        lda #T_WORD
        jsr take
        jmp drop
lst     jsr sc_init
l       jsr sc_end
        bcs e
        jsr el_next
        dec tmp2
        bne l
        jsr el_take
drop    lda #6                  ; retire n
        jmp vdrop
e       jmp err_empty
.)

; COMPTE x : nombre de caractères d'un mot, d'éléments d'une liste
f_compte
.(
        jsr arg1t
        jsr top_txt
        lda #6
        jsr vdrop
        lda s_t+5
        cmp #T_LIST
        beq lst
        lda tl
        ldx tl+1
        jmp ret
lst     jsr sc_init
        lda #0
        sta elo
        sta elo+1
l       jsr sc_end
        bcs n
        jsr el_next
        inc elo
        bne l
        inc elo+1
        jmp l
n       lda elo
        ldx elo+1
ret     sta val
        stx val+1
        lda #T_INT
        sta vt
        rts
.)

; VIDE? x : 1 si le mot ou la liste est vide
f_videp
.(
        jsr arg1t
        lda #6
        jsr vdrop
        lda val+2
        ora val+3
        beq one
        jmp ret0
one     jmp ret1
.)

; MOT? x, LISTE? x, NOMBRE? x
f_motp
        jsr arg1r
        lda vt
        cmp #T_LIST
        beq ret0
        bne ret1
f_listep
        jsr arg1r
        lda vt
        cmp #T_LIST
        beq ret1
        bne ret0
f_nombrep
        jsr arg1r
        jsr try_num
        bcc ret1
ret0    lda #0
        beq retb
ret1    lda #1
retb    sta val
        lda #0
        sta val+1
        lda #T_INT
        sta vt
        rts

; MEMBRE? a b : 1 si a est un élément de la liste b (ou un caractère du
;   mot b)
f_membrep
.(
        jsr arg2t
        jsr ld_sa
        jsr top_txt             ; b ; sa dans s_t..s_t+4
        lda #12
        jsr vdrop
        lda s_t+5
        cmp #T_LIST
        beq lst
        lda s_t                 ; mot : a doit être un caractère
        cmp #T_WORD
        bne ret0
        lda s_t+4
        bne ret0
        lda s_t+3
        cmp #1
        bne ret0
        lda s_t+1
        sta td
        lda s_t+2
        sta td+1
        ldy #0
        lda (td),y
        sta nlast
wl      lda tl
        ora tl+1
        beq ret0
        ldy #0
        lda (ts),y
        cmp nlast
        beq ret1
        inc ts
        bne w2
        inc ts+1
w2      lda tl
        bne w3
        dec tl+1
w3      dec tl
        jmp wl
lst     jsr sc_init
l       jsr sc_end
        bcs ret0
        jsr el_next
        lda s_t                 ; a liste : l'élément doit être une liste
        cmp #T_LIST
        bne cw
        ldy #0
        lda (els),y
        cmp #"["
        bne l
        jsr el_kind
cw      lda eln                  ; même longueur, mêmes octets
        cmp s_t+3
        bne l
        lda eln+1
        cmp s_t+4
        bne l
        lda els
        sta ts
        lda els+1
        sta ts+1
        lda s_t+1
        sta td
        lda s_t+2
        sta td+1
        lda eln
        sta tl
        lda eln+1
        sta tl+1
        lda scp                  ; memeq déplace ts : on garde sp, se
        pha
        lda scp+1
        pha
        jsr memeq
        pla
        sta scp+1
        pla
        sta scp
        lda tl                  ; tl = 0 : tout était égal
        ora tl+1
        bne nxt
        jmp ret1
nxt     jmp l
.)

; MOT a b, PHRASE a b, LISTE a b
f_mot   jsr arg2t
        lda #0                  ; ni crochets ni espace
        sta bw
        sta bsp
        lda #T_WORD
        sta brt
        jsr ld_sa
        jsr ld_sb
        lda s_t
        cmp #T_WORD
        bne fm_e
        lda s_t+5
        cmp #T_WORD
        bne fm_e
        jmp build2
fm_e    jmp err_word
f_phrase
        jsr arg2t
        lda #0                  ; contenus, espace si les deux ne sont pas vides
        sta bw
        lda #1
        sta bsp
        lda #T_LIST
        sta brt
        jmp build2
f_liste jsr arg2t
        lda #1                  ; listes entre crochets, espace toujours
        sta bw
        lda #2
        sta bsp
        lda #T_LIST
        sta brt
        jmp build2

; build2 : résultat (type brt) = a, b, avec crochets autour d'une liste si
;   bw, une espace entre (bsp : 0 jamais, 1 si les deux non vides,
;   2 toujours) ; retire a et b de la pile
build2
.(
        jsr ld_sa
        jsr ld_sb
        jsr plen_a              ; hn = longueur de a (+ crochets)
        lda tl
        sta hn
        lda tl+1
        sta hn+1
        jsr plen_b
        lda #0                  ; espace ?
        sta bsp2
        lda bsp
        beq s0
        cmp #2
        beq s1
        lda hn
        ora hn+1
        beq s0
        lda tl
        ora tl+1
        beq s0
s1      inc bsp2
s0      clc
        lda hn
        adc tl
        sta hn
        lda hn+1
        adc tl+1
        sta hn+1
        clc
        lda hn
        adc bsp2
        sta hn
        bcc a1
        inc hn+1
a1      jsr halloc
        lda hptr
        sta td
        lda hptr+1
        sta td+1
        jsr ld_sa               ; relus : le tas a pu bouger
        jsr ld_sb
        ldx #0
        jsr part
        lda bsp2
        beq nsp
        lda #" "
        jsr emit
nsp     ldx #5
        jsr part
        lda #12
        jsr vdrop
        lda brt
        jmp set_txt
.)

; plen_a, plen_b : tl = longueur de la partie a ou b (+ 2 pour les crochets)
plen_a  ldx #0
        beq plen
plen_b  ldx #5
plen    lda s_t+3,x
        sta tl
        lda s_t+4,x
        sta tl+1
        jsr pwrap
        bcc pl1
        clc
        lda tl
        adc #2
        sta tl
        bcc pl1
        inc tl+1
pl1     rts

; pwrap : C=1 si la partie X (0 : a, 5 : b) va entre crochets
pwrap   lda bw
        beq pw0
        lda s_t,x
        cmp #T_LIST
        beq pw1
pw0     clc
        rts
pw1     sec
        rts

; part : écrit la partie X (0 : a, 5 : b) en td
part
.(
        jsr pwrap
        php
        bcc n1
        lda #"["
        jsr emit
n1      lda s_t+1,x
        sta ts
        lda s_t+2,x
        sta ts+1
        lda s_t+3,x
        sta tl
        lda s_t+4,x
        sta tl+1
        jsr cpy_out
        plp
        bcc r
        lda #"]"
        jsr emit
r       rts
.)

; ---------------------------------------------------------------------
; EXECUTE x : exécute une liste (ou un mot) comme des instructions. Le
; texte est copié dans xstack (hors du tas : le compactage ne le déplace
; pas pendant qu'il s'exécute).
; ---------------------------------------------------------------------
p_exec
.(
        jsr eval
        jsr as_text
        jsr txt_v
        clc                     ; place dans xstack ?
        lda xsp
        adc tl
        sta tmp
        lda xsp+1
        adc tl+1
        sta tmp+1
        lda tmp
        cmp #<xstack_end
        lda tmp+1
        sbc #>xstack_end
        bcc ok
        lda #0
        sta clen
        lda #<e_mem
        ldy #>e_mem
        jmp error
ok      lda xsp                 ; contexte : liste = la copie, compteur =
        sta lstart              ; ancien xsp
        sta td
        sta cnt
        lda xsp+1
        sta lstart+1
        sta td+1
        sta cnt+1
        jsr cpy_out
        lda td
        sta lend
        sta xsp
        lda td+1
        sta lend+1
        sta xsp+1
        lda #FR_EXEC
        jmp push_frame
.)
