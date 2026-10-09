; =====================================================================
;  EDIT.COM — éditeur de texte plein écran pour CP/A
;
;  EDIT [fichier]
;
;  Texte en mémoire dans un tampon « à trou » : le texte avant le
;  curseur est en [BUF, gs), le texte après en [ge, BEND), le trou
;  libre entre les deux. Les paragraphes se terminent par CR ($0D) ;
;  sur disque, CR LF et ^Z en fin de fichier (format CP/M).
;  Affichage : 26 lignes de 38 colonnes, coupure entre les mots.
;  Réglages par fichier dans EDIT.CFG (longueur maxi d'un paragraphe,
;  coupure à l'écran, largeur de l'imprimante) : voir apply_cfg.
;
;  Les articles de menu « tapent » un code $81-$90 que l'éditeur
;  traite comme une touche : menus et raccourcis passent par le même
;  aiguillage.
; =====================================================================

#include "cpa.inc"

WIDTH   = 38            ; colonnes de texte
ROWS    = 26            ; lignes de texte (écran lignes 1 à 26)
STROW   = 27            ; ligne d'état
CR      = $0D
LF      = $0A
EOFC    = $1A
; La fin de la zone de texte (bend) et le presse-papiers (clipa) dépendent
; du haut de la TPA : $A400 en mode texte, $9000 lancé depuis le mode SPLIT
; (l'image en $A000-$B3FF est alors préservée et réaffichée en sortant).
CLIPMAX = $1000         ; presse-papiers de 4 Ko ($A400-$B3FF)
MAXIN   = 30            ; longueur maximale d'une saisie
CLMAX   = 40            ; EDIT.CFG : longueur d'une ligne lue

; --- page zéro ---
gs      = $10           ; début du trou
ge      = $12           ; fin du trou
ip      = $14           ; itérateur dans le texte
ip0     = $16
p       = $18           ; position logique (mise en page)
rnext   = $1A
t0      = $1C
t1      = $1E
src     = $20
dst     = $22
cnt     = $24
scr     = $26
top     = $28           ; position logique de la première ligne affichée
curl    = $2A           ; position logique du curseur
len     = $2C           ; longueur du texte
crs     = $2E           ; nombre de CR avant le curseur
mark    = $30
ipsv    = $32
tmpw    = $34
msgp    = $36           ; message à afficher sur la ligne d'état (0 = aucun)
cliplen = $38
nrep    = $3A
rshow   = $3C
li      = $3D
lsp     = $3E
rr      = $3F
crow    = $40
ccol    = $41
goal    = $42
jj      = $43
tmpb    = $44
dirty   = $45
modif   = $46
insm    = $47
wrap    = $48
markset = $49
setgoal = $4A
inlen   = $4B
repall  = $4C
hasname = $4D
toobig  = $4E
spos    = $4F
prevc   = $50
wcount  = $51           ; 2 octets
inword  = $53
rp      = $54
bend    = $56           ; fin de la zone de texte (2 octets)
clipa   = $58           ; presse-papiers (2 octets)
blim    = $5A           ; bend - 128 (2 octets)
wassplit = $5C          ; 1 = lancé depuis le mode SPLIT
cptr    = $5D           ; EDIT.CFG : lecture des réglages intégrés (2 octets)

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
        cld
        ldx #F_GFX              ; lancé depuis le mode SPLIT ?
        lda #<gq_get
        ldy #>gq_get
        jsr BDOS
        sta wassplit
        lda TPA_TOP+1           ; presse-papiers : les 4 derniers Ko de la
        sec                     ; TPA ($A400 en texte, $9000 en SPLIT, plus
        sbc #>CLIPMAX           ; bas sous le débogueur)
        pha
        lda wassplit
        beq memset
        ldx #F_GFX              ; SPLIT : passage en texte plein écran,
        lda #<gq_text           ; tout reste sous l'image ($A000)
        ldy #>gq_text
        jsr BDOS
memset  pla
        tax
        stx clipa+1
        stx bend+1
        dex
        stx blim+1
        lda #0
        sta clipa
        sta bend
        lda #$80
        sta blim
        jsr text_clear
        lda #1
        sta insm
        sta wrap
        lda #0
        sta cliplen
        sta cliplen+1
        sta hasname
        sta msgp+1
        ldx TAIL                ; /L : lancé par EDITE de LOGO
sl      dex
        bmi nol
        lda TAIL+1,x
        cmp #"L"
        bne sl
        lda TAIL,x
        cmp #"/"
        bne sl
        inc retl
        ldx #6                  ; « Quitter » devient « Retour »
rt      lda s_retour,x
        sta it_quit,x
        dex
        bpl rt
nol     lda #<ed_bar
        ldy #>ed_bar
        jsr B_MENUBAR
        ldx #F_CONOUT           ; efface l'écran
        lda #$0C
        jsr BDOS
        lda #$14                ; ligne d'état : papier bleu, encre blanche
        sta SCREEN+STROW*40
        lda #$07
        sta SCREEN+STROW*40+1
        lda FCB1+1              ; fichier donné en paramètre ?
        cmp #" "
        beq noarg
        ldx #11
cpn     lda FCB1,x
        sta fcb_main,x
        dex
        bpl cpn
        lda #1
        sta hasname
        jsr apply_cfg
        jsr load_file
        jmp arg
noarg   jsr apply_cfg           ; sans nom : réglages par défaut
arg   lda #1
        sta dirty
        sta setgoal

; ---------------------------------------------------------------------
; Boucle principale
; ---------------------------------------------------------------------
main
        jsr B_CONST             ; d'autres touches attendent : on
        bne getk                ; n'affiche qu'à la fin de la rafale
        jsr refresh
getk    jsr B_CONIN
        pha
        lda msgp+1              ; une touche efface le message
        beq nomsg
        lda #0
        sta msgp+1
        lda #1
        sta dirty
nomsg   pla
        jsr dispatch
        jmp main

; dispatch : A = touche ou code de menu
dispatch
.(
        cmp #$20
        bcc ctrl
        cmp #$7F
        bcc jchar
        beq del
        cmp #$81
        bcc none
        cmp #$94
        bcs none
        sec
        sbc #$81
        tax
        lda mvec_hi,x
        pha
        lda mvec_lo,x
        pha
        rts
ctrl    tax
        lda cvec_hi,x
        pha
        lda cvec_lo,x
        pha
        rts
jchar   jmp k_char
del     jmp k_del
none    rts
.)

; tables de saut : codes de contrôle $00-$1F, puis codes de menu $81-$93
cvec_lo .byt <(k_none-1),<(k_home-1),<(k_none-1),<(k_pgdn-1),<(k_delr-1),<(k_end-1),<(k_find-1),<(k_next-1)
        .byt <(k_left-1),<(k_right-1),<(k_down-1),<(k_up-1),<(k_insert-1),<(k_cr-1),<(k_long-1),<(k_ins-1)
        .byt <(k_print-1),<(k_top-1),<(k_pgup-1),<(k_save-1),<(k_none-1),<(k_none-1),<(k_none-1),<(k_none-1)
        .byt <(k_none-1),<(k_delpara-1),<(k_bot-1),<(k_esc-1),<(k_none-1),<(k_none-1),<(k_none-1),<(k_none-1)
cvec_hi .byt >(k_none-1),>(k_home-1),>(k_none-1),>(k_pgdn-1),>(k_delr-1),>(k_end-1),>(k_find-1),>(k_next-1)
        .byt >(k_left-1),>(k_right-1),>(k_down-1),>(k_up-1),>(k_insert-1),>(k_cr-1),>(k_long-1),>(k_ins-1)
        .byt >(k_print-1),>(k_top-1),>(k_pgup-1),>(k_save-1),>(k_none-1),>(k_none-1),>(k_none-1),>(k_none-1)
        .byt >(k_none-1),>(k_delpara-1),>(k_bot-1),>(k_esc-1),>(k_none-1),>(k_none-1),>(k_none-1),>(k_none-1)
mvec_lo .byt <(k_new-1),<(k_open-1),<(k_save-1),<(k_saveas-1),<(k_quit-1),<(k_mark-1),<(k_copy-1),<(k_cut-1)
        .byt <(k_paste-1),<(k_delpara-1),<(k_find-1),<(k_next-1),<(k_repl-1),<(k_wrap-1),<(k_ins-1),<(k_stats-1)
        .byt <(k_insert-1),<(k_print-1),<(k_long-1)
mvec_hi .byt >(k_new-1),>(k_open-1),>(k_save-1),>(k_saveas-1),>(k_quit-1),>(k_mark-1),>(k_copy-1),>(k_cut-1)
        .byt >(k_paste-1),>(k_delpara-1),>(k_find-1),>(k_next-1),>(k_repl-1),>(k_wrap-1),>(k_ins-1),>(k_stats-1)
        .byt >(k_insert-1),>(k_print-1),>(k_long-1)

k_none
k_esc
        rts

; ---------------------------------------------------------------------
; Saisie
; ---------------------------------------------------------------------
k_char
.(
        pha
        lda insm
        bne ins
        ; remplacement : on retire d'abord le caractère sous le curseur
        jsr at_text_end
        beq ins
        ldy #0
        lda (ge),y
        cmp #CR
        beq ins
        jsr inc_ge
ins     pla
.)
insert_a                        ; insère A au curseur (C=1 si plein)
.(
        tax
        lda gs
        cmp ge
        bne room
        lda gs+1
        cmp ge+1
        bne room
        lda #<m_full
        ldy #>m_full
        jsr set_msg
        sec
        rts
room    txa
        ldy #0
        sta (gs),y
        cmp #CR
        bne nocr
        inc crs
        bne nocr
        inc crs+1
nocr    inc gs
        bne c1
        inc gs+1
c1      jmp changed
.)

k_cr    lda #CR
        jmp insert_a

k_del                           ; efface à gauche
.(
        jsr at_text_start
        beq r
        lda gs
        bne d1
        dec gs+1
d1      dec gs
        ldy #0
        lda (gs),y
        cmp #CR
        bne kdc
        lda crs
        bne d2
        dec crs+1
d2      dec crs
kdc     jmp changed
r       rts
.)

k_delr                          ; efface sous le curseur
        jsr at_text_end
        beq kd_r
        jsr inc_ge
        jmp changed
kd_r    rts

changed
        lda #1
        sta modif
moved
        lda #1
        sta dirty
        sta setgoal
        clc
        rts

inc_ge
        inc ge
        bne ig1
        inc ge+1
ig1     rts

; Z=1 si le curseur est en fin de texte
at_text_end
        lda ge
        cmp bend
        bne ate
        lda ge+1
        cmp bend+1
ate     rts

; Z=1 si le curseur est au début du texte
at_text_start
        lda gs
        cmp #<BUF
        bne ats
        lda gs+1
        cmp #>BUF
ats     rts

; ---------------------------------------------------------------------
; Déplacements
; ---------------------------------------------------------------------
k_left
        jsr at_text_start
        beq kl_r
        jsr gap_left1
        jmp moved
kl_r    rts

k_right
        jsr at_text_end
        beq kr_r
        jsr gap_right1
        jmp moved
kr_r    rts

k_top
        lda #0
        sta t0
        sta t0+1
        jsr gap_to
        jmp moved

k_bot
        jsr calc_curl_len
        lda len
        sta t0
        lda len+1
        sta t0+1
        jsr gap_to
        jmp moved

k_home
        jsr refresh
        ldx crow
        lda rs_lo,x
        sta t0
        lda rs_hi,x
        sta t0+1
        jsr gap_to
        jmp moved

k_end
        jsr refresh
        ldx crow
        jsr row_maxoff
        jmp goto_off

k_down
.(
        jsr refresh
        ldx crow
        inx
        jsr row_valid
        bcs r
        cpx #ROWS
        bcc ok
        ldx #1                  ; défilement d'une ligne
        jsr top_from_row
        jsr render
        ldx #ROWS-1
ok      jmp goto_goal
r       rts
.)

k_up
.(
        jsr refresh
        ldx crow
        bne ok
        lda top
        ora top+1
        beq r
        jsr top_up
        jsr render
        ldx crow
ok      dex
        jmp goto_goal
r       rts
.)

k_pgdn
.(
        jsr refresh
        lda crow
        sta crow2
        ldx #ROWS-1
        jsr row_valid
        bcs last
        jsr top_from_row
        jsr render
        ldx crow2
        jmp goto_row
last    jmp k_bot
.)

k_pgup
.(
        jsr refresh
        lda crow
        sta crow2
        lda #ROWS-1
        sta tmpb
loop    lda top
        ora top+1
        beq done
        jsr top_up
        dec tmpb
        bne loop
done    jsr render
        ldx crow2
        jmp goto_row
.)

; goto_row : X = ligne écran, va à la colonne « goal » (ou la dernière ligne)
goto_row
.(
loop    jsr row_valid
        bcc goto_goal
        dex
        bpl loop
        rts
.)

; goto_goal : X = ligne écran valide, curseur en min(goal, fin de ligne)
goto_goal
        stx rr
        jsr row_maxoff          ; A = dernier décalage possible
        cmp goal
        bcc goto_off
        lda goal
; goto_off : X = rr = ligne, A = décalage dans la ligne
goto_off
        ldx rr
        clc
        adc rs_lo,x
        sta t0
        lda rs_hi,x
        adc #0
        sta t0+1
        jsr gap_to
        lda #1
        sta dirty
        rts

; row_valid : C=0 si la ligne X contient du texte (X préservé)
row_valid
        lda len+1
        cmp rs_hi,x
        bcc rv_no
        bne rv_ok
        lda len
        cmp rs_lo,x
        bcc rv_no
rv_ok   clc
        rts
rv_no   sec
        rts

; row_maxoff : X = ligne -> A = plus grand décalage du curseur dans la ligne
row_maxoff
.(
        stx rr
        inx
        jsr row_valid           ; la ligne suivante existe ?
        dex
        bcs lastrow
        sec                     ; début(suivante) - début - 1
        lda rs_lo+1,x
        sbc rs_lo,x
        sec
        sbc #1
        rts
lastrow sec                     ; dernière ligne du texte : len - début
        lda len
        sbc rs_lo,x
        rts
.)

; top_from_row : top = début de la ligne écran X
top_from_row
        lda rs_lo,x
        sta top
        lda rs_hi,x
        sta top+1
        rts

; top_up : top recule d'une ligne
top_up
        sec
        lda top
        sbc #1
        sta t0
        lda top+1
        sbc #0
        sta t0+1
        jsr rowstart_of
        lda t0
        sta top
        lda t0+1
        sta top+1
        rts

; ---------------------------------------------------------------------
; Tampon à trou
; ---------------------------------------------------------------------
text_clear
        lda #<BUF
        sta gs
        lda #>BUF
        sta gs+1
        lda bend
        sta ge
        lda bend+1
        sta ge+1
        lda #0
        sta crs
        sta crs+1
        sta top
        sta top+1
        sta modif
        sta markset
        lda #1
        sta dirty
        sta setgoal
        rts

gap_left1                       ; un caractère passe de gauche à droite
.(
        lda gs
        bne gl1
        dec gs+1
gl1     dec gs
        lda ge
        bne gl2
        dec ge+1
gl2     dec ge
        ldy #0
        lda (gs),y
        sta (ge),y
        cmp #CR
        bne r
        lda crs
        bne gl3
        dec crs+1
gl3     dec crs
r       rts
.)

gap_right1                      ; un caractère passe de droite à gauche
.(
        ldy #0
        lda (ge),y
        sta (gs),y
        cmp #CR
        bne gr1
        inc crs
        bne gr1
        inc crs+1
gr1     inc gs
        bne gr2
        inc gs+1
gr2     inc ge
        bne r
        inc ge+1
r       rts
.)

; gap_to : place le curseur à la position logique t0
gap_to
.(
        sec
        lda gs
        sbc #<BUF
        sta t1
        lda gs+1
        sbc #>BUF
        sta t1+1
        lda t0+1
        cmp t1+1
        bcc left
        bne right
        lda t0
        cmp t1
        bcc left
        bne right
        rts
left    sec                     ; cnt = t1 - t0
        lda t1
        sbc t0
        sta cnt
        lda t1+1
        sbc t0+1
        sta cnt+1
ll      jsr gap_left1
        jsr dec_cnt
        bne ll
        rts
right   sec                     ; cnt = t0 - t1
        lda t0
        sbc t1
        sta cnt
        lda t0+1
        sbc t1+1
        sta cnt+1
rl      jsr at_text_end
        beq r
        jsr gap_right1
        jsr dec_cnt
        bne rl
r       rts
.)

; gap_to_keep : comme gap_to, mais cnt est préservé
gap_to_keep
        lda cnt
        pha
        lda cnt+1
        pha
        jsr gap_to
        pla
        sta cnt+1
        pla
        sta cnt
        rts

; dec_cnt : cnt-1, Z=1 si cnt devient nul
dec_cnt
        lda cnt
        bne dc1
        dec cnt+1
dc1     dec cnt
        lda cnt
        ora cnt+1
        rts

; calc_curl_len : curl = position du curseur, len = longueur du texte
calc_curl_len
        sec
        lda gs
        sbc #<BUF
        sta curl
        lda gs+1
        sbc #>BUF
        sta curl+1
        sec
        lda bend
        sbc ge
        sta t1
        lda bend+1
        sbc ge+1
        sta t1+1
        clc
        lda curl
        adc t1
        sta len
        lda curl+1
        adc t1+1
        sta len+1
        rts

; addr_of : position logique t0 -> adresse ip
addr_of
.(
        clc
        lda t0
        adc #<BUF
        sta ip
        lda t0+1
        adc #>BUF
        sta ip+1
        cmp gs+1
        bcc done
        bne gap
        lda ip
        cmp gs
        bcc done
gap     sec
        lda ge
        sbc gs
        sta tmpw
        lda ge+1
        sbc gs+1
        sta tmpw+1
        clc
        lda ip
        adc tmpw
        sta ip
        lda ip+1
        adc tmpw+1
        sta ip+1
done    rts
.)

; it_next : avance ip d'un caractère en sautant le trou
it_next
.(
        inc ip
        bne itn1
        inc ip+1
itn1    lda ip
        cmp gs
        bne r
        lda ip+1
        cmp gs+1
        bne r
        lda ge
        sta ip
        lda ge+1
        sta ip+1
r       rts
.)

; ip_end : Z=1 si ip est en fin de texte
ip_end
        lda ip
        cmp bend
        bne ie
        lda ip+1
        cmp bend+1
ie      rts

; ---------------------------------------------------------------------
; Mise en page
; ---------------------------------------------------------------------
; layout_row : ligne affichée commençant en p
;   -> rshow = caractères affichés, rnext = début de la ligne suivante
;      (len+1 après la dernière ligne), ip0 = adresse du début
layout_row
.(
        lda len+1
        cmp p+1
        bcc inval
        bne valid
        lda len
        cmp p
        bcs valid
inval   lda #0
        sta rshow
        lda p
        sta rnext
        lda p+1
        sta rnext+1
        rts
valid   lda p
        sta t0
        lda p+1
        sta t0+1
        jsr addr_of
        lda ip
        sta ip0
        lda ip+1
        sta ip0+1
        lda #0
        sta li
        lda #$FF
        sta lsp
loop    lda li
        cmp #WIDTH
        beq full
        jsr ip_end
        beq eof
        ldy #0
        lda (ip),y
        cmp #CR
        beq cr
        cmp #" "
        bne nsp
        lda li
        sta lsp
nsp     inc li
        jsr it_next
        jmp loop
eof     lda li
        sta rshow
        clc
        lda len
        adc #1
        sta rnext
        lda len+1
        adc #0
        sta rnext+1
        rts
cr      lda li
        sta rshow
        sec
        bcs addn
full    lda #WIDTH
        ldx wrap
        beq hard
        ldx lsp
        cpx #$FF
        beq hard
        txa
        clc
        adc #1
hard    sta rshow
        clc
addn    lda p
        adc rshow
        sta rnext
        lda p+1
        adc #0
        sta rnext+1
        rts
.)

; rowstart_of : t0 = début de la ligne affichée qui contient la position t0
rowstart_of
.(
        lda t0
        sta t1
        sta p
        lda t0+1
        sta t1+1
        sta p+1
back    lda p                   ; recule jusqu'au début du paragraphe
        ora p+1
        beq fwd
        sec
        lda p
        sbc #1
        sta t0
        lda p+1
        sbc #0
        sta t0+1
        jsr addr_of
        ldy #0
        lda (ip),y
        cmp #CR
        beq fwd
        lda t0
        sta p
        lda t0+1
        sta p+1
        jmp back
fwd     jsr layout_row          ; puis avance ligne par ligne
        lda t1+1
        cmp rnext+1
        bcc found
        bne adv
        lda t1
        cmp rnext
        bcc found
adv     lda rnext
        sta p
        lda rnext+1
        sta p+1
        jmp fwd
found   lda p
        sta t0
        lda p+1
        sta t0+1
        rts
.)

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
; refresh : recadre si besoin et redessine (seulement si dirty)
refresh
.(
        lda dirty
        bne go
        rts
go      lda #0
        sta dirty
        jsr calc_curl_len
        lda curl+1              ; curseur au-dessus de l'écran ?
        cmp top+1
        bcc above
        bne rend
        lda curl
        cmp top
        bcs rend
above   jsr rowstart_curl
        lda t0
        sta top
        lda t0+1
        sta top+1
rend    jsr render
        lda crow
        cmp #$FF
        bne done
        ldx #ROWS               ; juste en dessous : une ligne de défilement
        lda rs_lo,x
        sta p
        lda rs_hi,x
        sta p+1
        jsr layout_row
        lda curl+1
        cmp rnext+1
        bcc one
        bne far
        lda curl
        cmp rnext
        bcs far
one     ldx #1
        jsr top_from_row
        jsr render
        jmp done
far     jsr rowstart_curl       ; loin : curseur sur la dernière ligne
        lda t0
        sta top
        lda t0+1
        sta top+1
        lda #ROWS-1
        sta tmpb
back    lda top
        ora top+1
        beq rend2
        jsr top_up
        dec tmpb
        bne back
rend2   jsr render
done    lda setgoal
        beq r
        lda ccol
        sta goal
        lda #0
        sta setgoal
r       rts
.)

rowstart_curl
        lda curl
        sta t0
        lda curl+1
        sta t0+1
        jmp rowstart_of

; render : dessine les 26 lignes depuis top, calcule crow/ccol
render
.(
        jsr cur_hide
        jsr calc_curl_len
        lda top
        sta p
        lda top+1
        sta p+1
        lda #$FF
        sta crow
        lda #0
        sta rr
row     ldx rr
        lda p
        sta rs_lo,x
        lda p+1
        sta rs_hi,x
        jsr layout_row
        ldx rr
        lda txt_lo,x
        sta scr
        lda txt_hi,x
        sta scr+1
        lda ip0
        sta ip
        lda ip0+1
        sta ip+1
        lda #0
        sta jj
chars   lda jj
        cmp rshow
        bcs fill
        ldy #0
        lda (ip),y
        cmp #" "
        bcc ctl
        cmp #$7F
        bcc ok
ctl     lda #" "
ok      ldy jj
        sta (scr),y
        jsr it_next
        inc jj
        jmp chars
fill    ldy jj
        lda #" "
fl      cpy #WIDTH
        bcs cchk
        sta (scr),y
        iny
        bne fl
cchk    lda crow                ; le curseur est-il dans cette ligne ?
        cmp #$FF
        bne nxt
        lda curl+1
        cmp p+1
        bcc nxt
        bne ge1
        lda curl
        cmp p
        bcc nxt
ge1     lda curl+1
        cmp rnext+1
        bcc in
        bne nxt
        lda curl
        cmp rnext
        bcs nxt
in      lda rr
        sta crow
        sec
        lda curl
        sbc p
        sta ccol
nxt     lda rnext
        sta p
        lda rnext+1
        sta p+1
        inc rr
        lda rr
        cmp #ROWS
        bcs end
        jmp row
end     ldx #ROWS
        lda p
        sta rs_lo,x
        lda p+1
        sta rs_hi,x
        jsr draw_status
        jmp cur_show
.)

; --- curseur du système (variables publiques de la console) ---
cur_hide
        php
        sei
        lda #0
        sta CON_CUREN
        lda CON_CURVIS
        beq chd
        jsr cur_flip
        lda #0
        sta CON_CURVIS
chd     plp
        rts

cur_show
        lda crow
        cmp #$FF
        beq csr
        clc
        adc #1
        sta CON_CURY
        lda ccol
        clc
        adc #2
        sta CON_CURX
        php
        sei
        jsr cur_flip
        lda #1
        sta CON_CURVIS
        sta CON_CUREN
        lda #20
        sta CON_BLINK
        plp
csr     rts

cur_flip
        ldx CON_CURY
        lda scr_lo,x
        sta tmpw
        lda scr_hi,x
        sta tmpw+1
        ldy CON_CURX
        lda (tmpw),y
        eor #$80
        sta (tmpw),y
        rts

; ---------------------------------------------------------------------
; Ligne d'état
; ---------------------------------------------------------------------
st_clear
        ldy #WIDTH-1
        lda #" "
stc     sta stline,y
        dey
        bpl stc
        rts

st_flush
        ldy #WIDTH-1
stf     lda stline,y
        sta SCREEN+STROW*40+2,y
        dey
        bpl stf
        rts

; st_puts : chaîne (src) copiée en stline à partir de Y
st_puts
.(
        sty tmpb
        ldy #0
loop    lda (src),y
        beq end
        sty jj
        ldy tmpb
        cpy #WIDTH
        bcs end
        sta stline,y
        inc tmpb
        ldy jj
        iny
        bne loop
end     ldy tmpb
        rts
.)

; st_num : nombre t1 écrit en stline à partir de Y
st_num
        sty stpos
        jsr utoa
        lda #<numbuf
        sta src
        lda #>numbuf
        sta src+1
        ldy stpos
        jmp st_puts

draw_status
.(
        jsr st_clear
        lda msgp+1
        beq info
        lda msgp
        sta src
        lda msgp+1
        sta src+1
        ldy #0
        jsr st_puts
        jmp st_flush
info    ldy #0
        lda hasname
        bne named
        lda #<m_noname
        sta src
        lda #>m_noname
        sta src+1
        jsr st_puts
        jmp mod
named   ldx #1                  ; NOM.EXT sans les espaces
nm      lda fcb_main,x
        cmp #" "
        beq dot
        sta stline,y
        iny
        inx
        cpx #9
        bne nm
dot     lda fcb_main+9
        cmp #" "
        beq mod
        lda #"."
        sta stline,y
        iny
        ldx #9
ext     lda fcb_main,x
        cmp #" "
        beq mod
        sta stline,y
        iny
        inx
        cpx #12
        bne ext
mod     lda modif
        beq pos
        lda #"*"
        sta stline,y
pos     lda #"L"                ; paragraphe
        sta stline+15
        clc
        lda crs
        adc #1
        sta t1
        lda crs+1
        adc #0
        sta t1+1
        ldy #16
        jsr st_num
        lda #"C"                ; position dans le paragraphe
        sta stline+23
        jsr para_info
        clc
        lda pcol
        adc #1
        sta t1
        lda pcol+1
        adc #0
        sta t1+1
        ldy #24
        jsr st_num
        lda maxi                ; paragraphe plus long que maxi :
        ora maxi+1              ; « C nnn! » en vidéo inverse
        beq lim_ok
        lda maxi+1
        cmp plen+1
        bcc over
        bne lim_ok
        lda maxi
        cmp plen
        bcs lim_ok
over    lda #"!"
        sta stline,y
        iny
        sty tmpb
        ldy #23
inv     lda stline,y
        ora #$80
        sta stline,y
        iny
        cpy tmpb
        bne inv
lim_ok
        ldy #3
        lda insm
        bne ins
mrf     lda m_rfp-1,y
        sta stline+31,y
        dey
        bne mrf
        beq mk
ins     lda m_ins-1,y
        sta stline+31,y
        dey
        bne ins
mk      lda markset
        beq fl
        lda #"M"
        sta stline+36
fl      jmp st_flush
.)

; set_msg : message A/Y affiché jusqu'à la prochaine touche
set_msg
        sta msgp
        sty msgp+1
        lda #1
        sta dirty
        rts

; utoa : t1 (16 bits) -> numbuf, chaîne décimale terminée par 0
utoa
.(
        lda #0
        sta jj                  ; chiffres déjà écrits
        tay
        ldx #0
dig     lda #0
        sta tmpb
sub     sec
        lda t1
        sbc d_lo,x
        pha
        lda t1+1
        sbc d_hi,x
        bcc dn
        sta t1+1
        pla
        sta t1
        inc tmpb
        bne sub
dn      pla
        lda tmpb
        bne put
        lda jj
        beq skip
        lda tmpb
put     ora #"0"
        sta numbuf,y
        iny
        sta jj
skip    inx
        cpx #4
        bne dig
        lda t1
        ora #"0"
        sta numbuf,y
        iny
        lda #0
        sta numbuf,y
        rts
d_lo    .byt <10000,<1000,<100,<10
d_hi    .byt >10000,>1000,>100,>10
.)

; ---------------------------------------------------------------------
; Questions sur la ligne d'état
; ---------------------------------------------------------------------
; ask : question A/Y, saisie dans inbuf/inlen. C=1 si ESC.
ask
.(
        sta askp
        sty askp+1
        lda #0
        sta inlen
        jsr cur_hide
redraw  jsr st_clear
        lda askp
        sta src
        lda askp+1
        sta src+1
        ldy #0
        jsr st_puts
        sty spos
        ldx #0
il      cpx inlen
        beq ieol
        lda inbuf,x
        sta stline,y
        iny
        inx
        bne il
ieol    cpy #WIDTH
        bcs nc
        lda #$A0                ; curseur : espace en vidéo inverse
        sta stline,y
nc      jsr st_flush
key     jsr B_CONIN
        cmp #CR
        beq ok
        cmp #$1B
        beq esc
        cmp #$7F
        beq bs
        cmp #$08
        beq bs
        cmp #" "
        bcc key
        cmp #$7F
        bcs key
        ldx inlen
        cpx #MAXIN
        bcs key
        pha
        txa
        clc
        adc spos
        cmp #WIDTH-1
        pla
        bcs key
        sta inbuf,x
        inc inlen
        jmp redraw
bs      lda inlen
        beq key
        dec inlen
        jmp redraw
ok      lda #1
        sta dirty
        clc
        rts
esc     lda #1
        sta dirty
        sec
        rts
.)

; ask_key : question A/Y, renvoie la touche en majuscule dans A
ask_key
        sta src
        sty src+1
        jsr cur_hide
        jsr st_clear
        ldy #0
        jsr st_puts
        jsr st_flush
        jsr B_CONIN
        jsr upc
        pha
        lda #1
        sta dirty
        pla
        rts

; ask_yn : C=1 si la réponse est O (ou Y)
ask_yn
        jsr ask_key
        cmp #"O"
        beq yn_y
        cmp #"Y"
        beq yn_y
        clc
        rts
yn_y    sec
        rts

; confirm_lose : si le texte est modifié, demande confirmation. C=1 si OK
confirm_lose
        lda modif
        beq cl_ok
        lda #<q_lose
        ldy #>q_lose
        jmp ask_yn
cl_ok   sec
        rts

upc
        cmp #"a"
        bcc up_r
        cmp #"z"+1
        bcs up_r
        and #$DF
up_r    rts

; ---------------------------------------------------------------------
; Options
; ---------------------------------------------------------------------
k_ins
        lda insm
        eor #1
        sta insm
        lda #1
        sta dirty
        rts

k_wrap
.(
        lda wrap
        eor #1
        sta wrap
        jsr relayout
        lda wrap
        beq off
        lda #<m_wron
        ldy #>m_wron
        jmp set_msg
off     lda #<m_wroff
        ldy #>m_wroff
        jmp set_msg
.)

k_stats
.(
        jsr calc_curl_len
        lda #0
        sta wcount
        sta wcount+1
        sta inword
        sta t0
        sta t0+1
        jsr addr_of
loop    jsr ip_end
        beq done
        ldy #0
        lda (ip),y
        cmp #" "+1
        bcc sepr
        lda inword
        bne nx
        inc inword
        inc wcount
        bne nx
        inc wcount+1
        jmp nx
sepr    lda #0
        sta inword
nx      jsr it_next
        jmp loop
done    ; "nnnn car. nnnn mots"
        lda len
        sta t1
        lda len+1
        sta t1+1
        jsr utoa
        ldx #0
        jsr cat_num
        ldy #0
c1      lda m_car,y
        beq c1e
        sta msgbuf,x
        inx
        iny
        bne c1
c1e     stx spos
        lda wcount
        sta t1
        lda wcount+1
        sta t1+1
        jsr utoa
        ldx spos
        jsr cat_num
        ldy #0
c2      lda m_mots,y
        sta msgbuf,x
        beq c2e
        inx
        iny
        bne c2
c2e     stx spos                ; ", max nnn (Lnn)" : plus long paragraphe
        jsr para_scan
        ldx spos
        ldy #0
c3      lda m_max,y
        beq c3e
        sta msgbuf,x
        inx
        iny
        bne c3
c3e     lda pmax
        sta t1
        lda pmax+1
        sta t1+1
        stx spos
        jsr utoa
        ldx spos
        jsr cat_num
        lda #" "
        sta msgbuf,x
        inx
        lda #"("
        sta msgbuf,x
        inx
        lda #"L"
        sta msgbuf,x
        inx
        lda pmaxl
        sta t1
        lda pmaxl+1
        sta t1+1
        stx spos
        jsr utoa
        ldx spos
        jsr cat_num
        lda #")"
        sta msgbuf,x
        inx
        lda #0
        sta msgbuf,x
        lda #<msgbuf
        ldy #>msgbuf
        jmp set_msg
.)

; cat_num : ajoute numbuf à msgbuf en position X
cat_num
        ldy #0
cn1     lda numbuf,y
        beq cn2
        sta msgbuf,x
        inx
        iny
        bne cn1
cn2     rts

; ---------------------------------------------------------------------
; Edition : marque, copier, couper, coller, effacer un paragraphe
; ---------------------------------------------------------------------
k_mark
        jsr calc_curl_len
        lda curl
        sta mark
        lda curl+1
        sta mark+1
        lda #1
        sta markset
        lda #<m_mark
        ldy #>m_mark
        jmp set_msg

; get_range : t0 = début, cnt = longueur du bloc marque..curseur. C=1 si erreur
get_range
.(
        lda markset
        bne ok
        lda #<m_nomark
        ldy #>m_nomark
        jsr set_msg
        sec
        rts
ok      jsr calc_curl_len
        lda mark+1              ; la marque doit rester dans le texte
        cmp len+1
        bcc in
        bne clamp
        lda mark
        cmp len
        bcc in
        beq in
clamp   lda len
        sta mark
        lda len+1
        sta mark+1
in      lda curl+1
        cmp mark+1
        bcc cfirst
        bne mfirst
        lda curl
        cmp mark
        bcc cfirst
mfirst  lda mark
        sta t0
        lda mark+1
        sta t0+1
        sec
        lda curl
        sbc mark
        sta cnt
        lda curl+1
        sbc mark+1
        sta cnt+1
        jmp chk
cfirst  lda curl
        sta t0
        lda curl+1
        sta t0+1
        sec
        lda mark
        sbc curl
        sta cnt
        lda mark+1
        sbc curl+1
        sta cnt+1
chk     lda cnt
        ora cnt+1
        beq empty
        lda cnt+1
        cmp #>CLIPMAX
        bcc fine
        bne big
        lda cnt
        bne big
fine    clc
        rts
big     lda #<m_big
        ldy #>m_big
        jsr set_msg
        sec
        rts
empty   lda #<m_empty
        ldy #>m_empty
        jsr set_msg
        sec
        rts
.)

; clip_from_cursor : copie cnt octets après le curseur dans le presse-papiers
clip_from_cursor
        lda cnt
        sta cliplen
        lda cnt+1
        sta cliplen+1
        lda ge
        sta src
        lda ge+1
        sta src+1
        lda clipa
        sta dst
        lda clipa+1
        sta dst+1
        jmp memcpy

k_copy
.(
        jsr get_range
        bcs r
        lda curl                ; mémorise la position du curseur
        sta mark2
        lda curl+1
        sta mark2+1
        jsr gap_to_keep         ; le bloc commence juste après le curseur
        jsr clip_from_cursor
        lda mark2
        sta t0
        lda mark2+1
        sta t0+1
        jsr gap_to
        lda #<m_copied
        ldy #>m_copied
        jmp set_msg
r       rts
.)

k_cut
.(
        jsr get_range
        bcs r
        jsr gap_to_keep
        lda cnt
        pha
        lda cnt+1
        pha
        jsr clip_from_cursor
        pla
        sta cnt+1
        pla
        sta cnt
        clc                     ; supprime le bloc : le trou l'avale
        lda ge
        adc cnt
        sta ge
        lda ge+1
        adc cnt+1
        sta ge+1
        lda #0
        sta markset
        jmp changed
r       rts
.)

k_paste
.(
        lda cliplen
        ora cliplen+1
        bne some
        lda #<m_clipe
        ldy #>m_clipe
        jmp set_msg
some    sec                     ; place libre = ge - gs
        lda ge
        sbc gs
        sta tmpw
        lda ge+1
        sbc gs+1
        sta tmpw+1
        lda tmpw+1
        cmp cliplen+1
        bcc full
        bne ok
        lda tmpw
        cmp cliplen
        bcc full
ok      lda clipa              ; compte les CR collés
        sta src
        lda clipa+1
        sta src+1
        lda gs
        sta dst
        lda gs+1
        sta dst+1
        lda cliplen
        sta cnt
        lda cliplen+1
        sta cnt+1
        ldy #0
loop    lda (src),y
        sta (dst),y
        cmp #CR
        bne nocr
        inc crs
        bne nocr
        inc crs+1
nocr    inc src
        bne s1
        inc src+1
s1      inc dst
        bne s2
        inc dst+1
s2      jsr dec_cnt
        bne loop
        lda dst
        sta gs
        lda dst+1
        sta gs+1
        jmp changed
full    lda #<m_full
        ldy #>m_full
        jmp set_msg
.)

k_delpara
.(
        jsr calc_curl_len       ; va au début du paragraphe
        lda curl
        sta t0
        lda curl+1
        sta t0+1
back    lda t0
        ora t0+1
        beq go
        sec
        lda t0
        sbc #1
        sta t1
        lda t0+1
        sbc #0
        sta t1+1
        lda t0
        pha
        lda t0+1
        pha
        lda t1
        sta t0
        lda t1+1
        sta t0+1
        jsr addr_of
        pla
        sta t0+1
        pla
        sta t0
        ldy #0
        lda (ip),y
        cmp #CR
        beq go
        lda t1
        sta t0
        lda t1+1
        sta t0+1
        jmp back
go      jsr gap_to
del     jsr at_text_end         ; puis efface jusqu'au CR compris
        beq done
        ldy #0
        lda (ge),y
        pha
        jsr inc_ge
        pla
        cmp #CR
        bne del
done    jmp changed
.)

; memcpy : copie cnt octets de src vers dst (sans recouvrement gênant)
memcpy
.(
        lda cnt
        ora cnt+1
        beq done
        ldy #0
loop    lda (src),y
        sta (dst),y
        inc src
        bne s1
        inc src+1
s1      inc dst
        bne s2
        inc dst+1
s2      jsr dec_cnt
        bne loop
done    rts
.)

; ---------------------------------------------------------------------
; Recherche et remplacement
; ---------------------------------------------------------------------
; read_pattern : demande le texte à chercher (C=1 si annulé)
read_pattern
.(
        lda #<q_find
        ldy #>q_find
        jsr ask
        bcs r
        lda inlen
        beq no
        sta patlen
        ldx #0
cp      lda inbuf,x
        jsr upc
        sta pat,x
        inx
        cpx inlen
        bne cp
        clc
r       rts
no      sec
        rts
.)

; search : cherche pat à partir de la position t0. C=0 trouvé (t0 = position)
search
.(
        lda patlen
        beq nf
        jsr addr_of
        lda t0
        sta p
        lda t0+1
        sta p+1
loop    jsr ip_end
        beq nf
        ldy #0
        lda (ip),y
        jsr upc
        cmp pat
        bne next
        lda ip                  ; compare la suite
        sta ipsv
        lda ip+1
        sta ipsv+1
        ldx #1
cmpl    cpx patlen
        beq match
        jsr it_next
        jsr ip_end
        beq miss
        ldy #0
        lda (ip),y
        jsr upc
        cmp pat,x
        bne miss
        inx
        bne cmpl
miss    lda ipsv
        sta ip
        lda ipsv+1
        sta ip+1
next    jsr it_next
        inc p
        bne loop
        inc p+1
        jmp loop
match   lda p
        sta t0
        lda p+1
        sta t0+1
        clc
        rts
nf      sec
        rts
.)

k_find
        jsr read_pattern
        bcs kf_r
        jsr calc_curl_len
        lda curl
        sta t0
        lda curl+1
        sta t0+1
        jmp find_go
kf_r    rts

k_next
        jsr calc_curl_len
        clc
        lda curl
        adc #1
        sta t0
        lda curl+1
        adc #0
        sta t0+1
find_go
        jsr search
        bcs fg_wrap
        jsr gap_to
        jmp moved
fg_wrap lda #0                  ; pas trouvé : on repart du début
        sta t0
        sta t0+1
        jsr search
        bcs fg_nf
        jsr gap_to
        jsr moved
        lda #<m_wrapped
        ldy #>m_wrapped
        jmp set_msg
fg_nf   lda #<m_notf
        ldy #>m_notf
        jmp set_msg

k_repl
.(
        jsr read_pattern
        bcc g1
        rts
g1      lda #<q_repl
        ldy #>q_repl
        jsr ask
        bcc g2
        rts
g2
        lda inlen
        sta repllen
        ldx #0
cp      cpx inlen
        beq cpd
        lda inbuf,x
        sta repl,x
        inx
        bne cp
cpd     lda #0
        sta repall
        sta nrep
        sta nrep+1
        jsr calc_curl_len
        lda curl
        sta t0
        lda curl+1
        sta t0+1
loop    jsr search
        bcs done
        jsr gap_to
        lda repall
        bne doit
        lda #1
        sta dirty
        jsr refresh
        lda #<q_yn
        ldy #>q_yn
        jsr ask_key
        cmp #$1B
        beq done
        cmp #"T"
        beq all
        cmp #"O"
        beq doit
        cmp #"Y"
        beq doit
        jsr calc_curl_len       ; non : on passe à la suite
        clc
        lda curl
        adc #1
        sta t0
        lda curl+1
        adc #0
        sta t0+1
        jmp loop
all     lda #1
        sta repall
doit    clc                     ; supprime l'occurrence
        lda ge
        adc patlen
        sta ge
        bcc d1
        inc ge+1
d1      ldx #0
ins     cpx repllen
        beq insd
        lda repl,x
        stx jj
        jsr insert_a
        ldx jj
        bcs done
        inx
        bne ins
insd    inc nrep
        bne d2
        inc nrep+1
d2      jsr calc_curl_len
        lda curl
        sta t0
        lda curl+1
        sta t0+1
        jmp loop
done    lda nrep
        sta t1
        lda nrep+1
        sta t1+1
        jsr utoa
        ldx #0
        jsr cat_num
        ldy #0
c1      lda m_nrep,y
        sta msgbuf,x
        beq c1e
        inx
        iny
        bne c1
c1e     lda #1
        sta setgoal
        sta dirty
        lda #<msgbuf
        ldy #>msgbuf
        jmp set_msg
r       rts
.)

; relayout : la mise en page change (coupure) : on recale le haut
relayout
        jsr calc_curl_len
        lda top
        sta t0
        lda top+1
        sta t0+1
        jsr rowstart_of
        lda t0
        sta top
        lda t0+1
        sta top+1
        lda #1
        sta dirty
        rts

; ---------------------------------------------------------------------
; Fichiers
; ---------------------------------------------------------------------
k_new
        jsr confirm_lose
        bcc kn_r
        jsr text_clear
        lda #0
        sta hasname
        jmp apply_cfg
kn_r    rts

k_open
.(
        jsr confirm_lose
        bcc r
        lda #<q_open
        ldy #>q_open
        jsr ask
        bcs r
        jsr parse_name
        bcs bad
        jsr take_name
        jmp load_file
bad     lda #<m_badname
        ldy #>m_badname
        jmp set_msg
r       rts
.)

; k_print : imprime tout le texte (fonction 5 du BDOS, port Centronics).
;   Chaque paragraphe est coupé entre les mots en lignes de prw-1
;   caractères au plus (prw : largeur de l'imprimante, EDIT.CFG) : une
;   imprimante qui passe d'elle-même à la ligne à la dernière colonne ne
;   fait pas de ligne blanche. Un mot plus long qu'une ligne est coupé.
;   ESC arrête (entre deux lignes). Sans imprimante rien ne bloque, mais
;   chaque caractère attend son accusé 2 ms au plus (BIOS LIST)
k_print
.(
        lda #0
        sta t0
        sta t0+1
        jsr addr_of             ; ip : début du texte
        ldx prw
        dex
        stx pmaxc               ; caractères par ligne
line    jsr ip_end
        bne l0
        jmp done
l0      lda ip
        sta ipsv
        lda ip+1
        sta ipsv+1
        lda #0
        sta pn
        lda #$FF
        sta psp
scan    jsr ip_end
        beq last
        ldy #0
        lda (ip),y
        cmp #CR
        beq para
        ldx pn
        cpx pmaxc
        beq full
        cmp #" "
        bne sc1
        stx psp                 ; dernier espace de la ligne
sc1     inc pn
        jsr it_next
        jmp scan
last    lda pn                  ; fin du texte sans CR : fin de ligne
        beq done
        jsr out_n
        jsr crlf_p
        jmp done
para    jsr out_n               ; fin du paragraphe
        jsr it_next             ; (CR)
        jmp eol
full    ldx psp                 ; ligne pleine : coupée au dernier espace,
        cpx #$FF                ; qui n'est pas imprimé
        beq hard
        cpx #0
        beq hard
        stx pn
        jsr out_n
        jsr it_next
        jmp eol
hard    jsr out_n               ; pas d'espace : coupée au caractère
eol     jsr crlf_p
        jsr B_CONST             ; ESC : arrêt
        cmp #0
        beq jline
        jsr B_CONIN
        cmp #27
        beq stop
jline   jmp line
stop    lda #<m_pstop
        ldy #>m_pstop
        jmp set_msg
done    lda #<m_pdone
        ldy #>m_pdone
        jmp set_msg
; out_n : imprime pn caractères depuis ipsv (ip se retrouve après eux)
out_n   lda ipsv
        sta ip
        lda ipsv+1
        sta ip+1
on1     lda pn
        beq on2
        ldy #0
        lda (ip),y
        jsr lst
        jsr it_next
        dec pn
        jmp on1
on2     rts
crlf_p  lda #CR
        jsr lst
        lda #LF
lst     ldx #F_LIST
        jmp BDOS
.)

; ---------------------------------------------------------------------
; Paragraphes : position, longueur, plus long, trop longs
; ---------------------------------------------------------------------
; para_info : pcol = position du curseur dans son paragraphe (0 = début),
;   plen = longueur de ce paragraphe (sans le CR)
para_info
.(
        lda gs                  ; avant le curseur : [BUF, gs), d'un bloc
        sta src
        lda gs+1
        sta src+1
        lda #0
        sta pcol
        sta pcol+1
        ldy #0
back    lda src
        cmp #<BUF
        bne b1
        lda src+1
        cmp #>BUF
        beq fwd
b1      lda src
        bne b2
        dec src+1
b2      dec src
        lda (src),y
        cmp #CR
        beq fwd
        inc pcol
        bne back
        inc pcol+1
        jmp back
fwd     lda pcol                ; après le curseur : [ge, bend)
        sta plen
        lda pcol+1
        sta plen+1
        lda ge
        sta src
        lda ge+1
        sta src+1
f1      lda src
        cmp bend
        bne f2
        lda src+1
        cmp bend+1
        beq done
f2      lda (src),y
        cmp #CR
        beq done
        inc plen
        bne f3
        inc plen+1
f3      inc src
        bne f1
        inc src+1
        jmp f1
done    rts
.)

; para_scan : parcourt tout le texte
;   -> pmax, pmaxl : longueur et numéro (1 = premier) du plus long
;      paragraphe ; lfirst, lnext : position du premier caractère au-delà
;      de maxi dans le premier paragraphe trop long du texte, et dans le
;      premier qui le soit après le curseur ($FFFF : aucun)
para_scan
.(
        jsr calc_curl_len
        lda #0
        sta t0                  ; t0 : position courante
        sta t0+1
        sta pst
        sta pst+1
        sta plen
        sta plen+1
        sta pmax
        sta pmax+1
        sta pmaxl+1
        sta pno+1
        lda #1
        sta pmaxl
        sta pno
        lda #$FF
        sta lfirst
        sta lfirst+1
        sta lnext
        sta lnext+1
        jsr addr_of
loop    jsr ip_end
        beq endp
        ldy #0
        lda (ip),y
        cmp #CR
        beq endp
        inc plen
        bne nx
        inc plen+1
nx      jsr it_next
        inc t0
        bne loop
        inc t0+1
        jmp loop
endp    lda pmax+1              ; plus long ?
        cmp plen+1
        bcc newmax
        bne chk
        lda pmax
        cmp plen
        bcs chk
newmax  lda plen
        sta pmax
        lda plen+1
        sta pmax+1
        lda pno
        sta pmaxl
        lda pno+1
        sta pmaxl+1
chk     lda maxi                ; trop long ?
        ora maxi+1
        beq next
        lda maxi+1
        cmp plen+1
        bcc over
        bne next
        lda maxi
        cmp plen
        bcs next
over    clc                     ; tmpw : premier caractère en trop
        lda pst
        adc maxi
        sta tmpw
        lda pst+1
        adc maxi+1
        sta tmpw+1
        lda lfirst+1
        cmp #$FF
        bne af
        lda tmpw
        sta lfirst
        lda tmpw+1
        sta lfirst+1
af      lda lnext+1             ; après le curseur (strictement) ?
        cmp #$FF
        bne next
        lda curl+1
        cmp tmpw+1
        bcc set
        bne next
        lda curl
        cmp tmpw
        bcs next
set     lda tmpw
        sta lnext
        lda tmpw+1
        sta lnext+1
next    jsr ip_end              ; paragraphe suivant
        beq done
        jsr it_next
        inc t0
        bne n1
        inc t0+1
n1      lda t0
        sta pst
        lda t0+1
        sta pst+1
        lda #0
        sta plen
        sta plen+1
        inc pno
        bne jl
        inc pno+1
jl      jmp loop
done    rts
.)

; k_long : va au premier caractère en trop du paragraphe trop long suivant
;   (au-delà de la longueur maxi du fichier, EDIT.CFG)
k_long
.(
        lda maxi
        ora maxi+1
        bne go
        lda #<m_nolim
        ldy #>m_nolim
        jmp set_msg
go      jsr para_scan
        lda lnext
        sta t0
        lda lnext+1
        sta t0+1
        cmp #$FF
        bne found
        lda lfirst              ; aucun après le curseur : on repart du début
        sta t0
        lda lfirst+1
        sta t0+1
        cmp #$FF
        bne found
        lda #<m_nolong
        ldy #>m_nolong
        jmp set_msg
found   jsr gap_to
        jsr moved
        lda #<m_long
        ldy #>m_long
        jmp set_msg
.)

; ---------------------------------------------------------------------
; Réglages par fichier : EDIT.CFG
; ---------------------------------------------------------------------
; apply_cfg : réglages du document (fcb_main) : maxi (longueur maxi d'un
;   paragraphe, 0 = sans limite), wrap (coupure à l'écran), prw (largeur
;   de l'imprimante). EDIT.CFG est cherché sur le lecteur du document,
;   puis sur A: ; sans lui, réglages intégrés (cfg_def). Une ligne :
;     [d:]nom.ext  maxi  [MOTS|CAR]  [largeur]
;   jokers * et ? ; « ; » : commentaire. La première ligne dont le nom
;   correspond s'applique ; les colonnes absentes gardent leur défaut.
apply_cfg
.(
        lda #0
        sta maxi
        sta maxi+1
        lda #1
        sta wrap
        lda #80
        sta prw
        lda hasname
        beq end
        ldx #F_CURDSK           ; lecteur du document (1 = A:)
        jsr BDOS
        clc
        adc #1
        ldx fcb_main
        beq cur
        txa
cur     sta cdrv
        jsr try_open
        bcc file
        lda cdrv
        cmp #1
        beq def
        lda #1
        jsr try_open
        bcc file
def     lda #<cfg_def
        sta cptr
        lda #>cfg_def
        sta cptr+1
        lda #0
        beq csrc
file    lda #128
        sta cidx
        lda #1
csrc    sta cfile
scan    jsr cfg_line
        bcs dma
        jsr cfg_match
        bcs scan
dma     ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
end     jmp relayout

; try_open : ouvre EDIT.CFG sur le lecteur A (1 = A:). C=1 si absent
try_open
        sta fcb_cfg
        ldx #35
        lda #0
to0     sta fcb_cfg,x
        dex
        cpx #11
        bne to0
to1     lda cfg_name-1,x
        sta fcb_cfg,x
        dex
        bne to1
        ldx #F_OPEN
        lda #<fcb_cfg
        ldy #>fcb_cfg
        jsr BDOS
        cmp #$FF
        beq no
        clc
        rts
no      sec
        rts
.)

; cfg_getc : caractère suivant des réglages (C=1 à la fin)
cfg_getc
.(
        lda cfile
        beq mem
        ldy cidx
        cpy #128
        bcc have
        ldx #F_SETDMA
        lda #<recbuf
        ldy #>recbuf
        jsr BDOS
        ldx #F_READ
        lda #<fcb_cfg
        ldy #>fcb_cfg
        jsr BDOS
        cmp #0
        bne eof
        ldy #0
        sty cidx
have    inc cidx
        lda recbuf,y
        cmp #EOFC
        beq eof
        clc
        rts
mem     ldy #0
        lda (cptr),y
        beq eof
        inc cptr
        bne m1
        inc cptr+1
m1      clc
        rts
eof     lda #0                  ; la suite renvoie aussi « fin »
        sta cfile
        lda #<cfg_end
        sta cptr
        lda #>cfg_end
        sta cptr+1
        sec
        rts
.)

; cfg_line : ligne suivante (non vide) dans cline, terminée par 0. C=1 à la fin
cfg_line
.(
        lda #0
        sta clen
loop    jsr cfg_getc
        bcs eof
        cmp #CR
        beq eol
        cmp #LF
        beq eol
        ldx clen
        cpx #CLMAX
        bcs loop
        sta cline,x
        inc clen
        bne loop
eol     lda clen
        beq loop
done    ldx clen
        lda #0
        sta cline,x
        clc
        rts
eof     lda clen
        bne done
        sec
        rts
.)

; cfg_match : la ligne cline s'applique-t-elle à fcb_main ? Si oui, ses
;   réglages sont pris et C=0 ; sinon C=1
cfg_match
.(
        ldy #0
        jsr skipsp
        beq jno
        cmp #";"
        bne pat0
jno     jmp no
pat0    ldx #11                 ; motif : lecteur (0 : tous) et nom
        lda #" "
cl      sta cpat,x
        dex
        bne cl
        stx cpat
        lda cline+1,y
        cmp #":"
        bne nm
        lda cline,y
        jsr upc
        sec
        sbc #"@"
        sta cpat
        iny
        iny
nm      ldx #1
        lda #9
        sta clim
pc      lda cline,y
        cmp #" "+1
        bcc pend
        iny
        cmp #"."
        bne nd
        ldx #9
        lda #12
        sta clim
        bne pc
nd      cmp #"*"
        bne nst
        lda #"?"
st      cpx clim
        bcs pc
        sta cpat,x
        inx
        bne st
nst     cpx clim
        bcs pc
        jsr upc
        sta cpat,x
        inx
        bne pc
pend    lda cpat
        beq names
        cmp cdrv
        bne no
names   ldx #11
cmpl    lda cpat,x
        cmp #"?"
        beq nx
        lda fcb_main,x
        and #$7F
        cmp cpat,x
        bne no
nx      dex
        bne cmpl
        jsr getnum              ; longueur maxi
        lda t1
        sta maxi
        lda t1+1
        sta maxi+1
        jsr skipsp              ; coupure : MOTS ou CAR
        jsr upc
        cmp #"C"
        bne m
        lda #0
        beq setw
m       cmp #"M"
        bne nn
        lda #1
setw    sta wrap
sk      iny
        lda cline,y
        cmp #" "+1
        bcs sk
nn      jsr getnum              ; largeur de l'imprimante (20 à 255)
        bcs ok
        lda t1+1
        bne ok
        lda t1
        cmp #20
        bcc ok
        sta prw
ok      clc
        rts
no      sec
        rts
.)

; skipsp : saute les espaces de cline à partir de Y ; A = caractère (Z si fin)
skipsp
.(
loop    lda cline,y
        beq r
        cmp #" "+1
        bcs r2
        iny
        bne loop
r2      lda cline,y
r       rts
.)

; getnum : nombre décimal de cline (Y) -> t1. C=1 s'il n'y a pas de chiffre
getnum
.(
        jsr skipsp
        lda #0
        sta t1
        sta t1+1
        sta gnd
loop    lda cline,y
        sec
        sbc #"0"
        cmp #10
        bcs end
        pha
        lda t1                  ; t1 = t1 * 10 + chiffre
        asl
        sta tmpw
        lda t1+1
        rol
        sta tmpw+1
        asl t1
        rol t1+1
        asl t1
        rol t1+1
        asl t1
        rol t1+1
        clc
        lda t1
        adc tmpw
        sta t1
        lda t1+1
        adc tmpw+1
        sta t1+1
        pla
        clc
        adc t1
        sta t1
        bcc g1
        inc t1+1
g1      iny
        inc gnd
        bne loop
end     lda gnd
        beq none
        clc
        rts
none    sec
        rts
.)

cfg_name .asc "EDIT    CFG"
; réglages intégrés, sans EDIT.CFG
cfg_def  .asc "*.LOG 126",CR,"*.BAT 78",CR
cfg_end  .byt 0

; k_insert : insère un fichier texte au curseur (CR LF -> CR, arrêt
; sur ^Z), le curseur se retrouve après le texte inséré
k_insert
.(
        lda #<q_insert
        ldy #>q_insert
        jsr ask
        bcs r
        jsr parse_name
        bcs bad
        ldx #F_OPEN
        lda #<fcb_new
        ldy #>fcb_new
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_nofile
        ldy #>m_nofile
        jmp set_msg
bad     lda #<m_badname
        ldy #>m_badname
        jmp set_msg
r       rts
ok      lda #0
        sta wcount
        sta wcount+1
        sta prevc
        ldx #F_SETDMA
        lda #<recbuf
        ldy #>recbuf
        jsr BDOS
rd      ldx #F_READ
        lda #<fcb_new
        ldy #>fcb_new
        jsr BDOS
        cmp #0
        bne done
        ldy #0
ch      sty rp
        lda recbuf,y
        cmp #EOFC
        beq done
        ldx prevc
        sta prevc
        cmp #LF
        bne put
        cpx #CR                 ; LF après CR : déjà fait
        beq skip
        lda #CR
put     jsr insert_a
        bcs fin                 ; mémoire pleine (message posé)
        inc wcount
        bne skip
        inc wcount+1
skip    ldy rp
        iny
        cpy #128
        bne ch
        jmp rd
done    lda wcount              ; « nnnn car. inseres »
        sta t1
        lda wcount+1
        sta t1+1
        jsr utoa
        ldx #0
c1      lda numbuf,x
        beq c1e
        sta msgbuf,x
        inx
        bne c1
c1e     ldy #0
c2      lda m_inserted,y
        sta msgbuf,x
        beq c2e
        inx
        iny
        bne c2
c2e     lda #<msgbuf
        ldy #>msgbuf
        jsr set_msg
fin     ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS
.)

k_save
        lda hasname
        bne ks_go
        jmp k_saveas
ks_go   jmp save_file

k_saveas
.(
        lda #<q_saveas
        ldy #>q_saveas
        jsr ask
        bcs r
        jsr parse_name
        bcs bad
        jsr take_name
        jmp save_file
bad     lda #<m_badname
        ldy #>m_badname
        jmp set_msg
r       rts
.)

k_quit
.(
        lda retl
        beq q
        lda modif               ; Retour à LOGO : enregistre d'abord
        beq back
        jsr save_file
        lda modif               ; échec (message affiché) : on reste
        beq back
        rts
back    jsr cur_hide
        lda wassplit
        beq ln
        ldx #F_GFX
        lda #<gq_split
        ldy #>gq_split
        jsr BDOS
ln      ldx #0                  ; « LOGO NOM.TYP /R »
        ldy #1
l1      lda s_logo,x
        sta msgbuf,x
        inx
        cpx #5
        bne l1
        lda fcb_main            ; lecteur du document : « B: »
        beq l2
        ora #$40
        sta msgbuf,x
        inx
        lda #":"
        sta msgbuf,x
        inx
l2      lda fcb_main,y
        cmp #" "
        beq l3
        sta msgbuf,x
        inx
l3      iny
        cpy #9
        bne l2
        lda #"."
        sta msgbuf,x
        inx
l4      lda fcb_main,y
        cmp #" "
        beq l5
        sta msgbuf,x
        inx
l5      iny
        cpy #12
        bne l4
        ldy #0
l6      lda s_retr,y
        sta msgbuf,x
        inx
        iny
        cpy #4
        bne l6
        ldx #F_CHAIN
        lda #<msgbuf
        ldy #>msgbuf
        jmp BDOS
q       lda modif
        beq go
        lda #<q_quit
        ldy #>q_quit
        jsr ask_yn
        bcc r
go      jsr cur_hide
        lda wassplit
        beq cls
        ldx #F_GFX              ; retour au mode SPLIT avec l'image intacte
        lda #<gq_split
        ldy #>gq_split
        jsr BDOS
        jmp WBOOT
cls     ldx #F_CONOUT
        lda #$0C
        jsr BDOS
        jmp WBOOT               ; réinstalle la barre de menus du système
r       rts
.)

; take_name : fcb_new devient le nom du document
take_name
        ldx #11
tn1     lda fcb_new,x
        sta fcb_main,x
        dex
        bpl tn1
        lda #1
        sta hasname
        sta dirty
        jmp apply_cfg           ; réglages du nouveau nom

; parse_name : inbuf -> fcb_new ([D:]NOM.EXT en majuscules). C=1 si invalide
parse_name
.(
        ldx #35
        lda #0
z       sta fcb_new,x
        dex
        bpl z
        ldx #11
        lda #" "
sp      sta fcb_new,x
        dex
        bne sp
        ldy #0
        lda inlen
        cmp #2
        bcc nodrv
        lda inbuf+1             ; B: devant le nom : lecteur
        cmp #":"
        bne nodrv
        lda inbuf
        jsr upc
        sec
        sbc #"@"
        sta fcb_new
        ldy #2
nodrv   ldx #1
nm      cpy inlen
        beq done
        lda inbuf,y
        iny
        cmp #"."
        beq ext
        jsr check
        bcs bad
        cpx #9
        bcs nm
        sta fcb_new,x
        inx
        bne nm
ext     ldx #9
ex      cpy inlen
        beq done
        lda inbuf,y
        iny
        jsr check
        bcs bad
        cpx #12
        bcs ex
        sta fcb_new,x
        inx
        bne ex
done    lda fcb_new+1
        cmp #" "
        beq bad
        clc
        rts
bad     sec
        rts
check   jsr upc                 ; caractères interdits dans un nom
        cmp #" "+1
        bcc ck_bad
        cmp #"*"
        beq ck_bad
        cmp #"?"
        beq ck_bad
        cmp #":"
        beq ck_bad
        clc
        rts
ck_bad  sec
        rts
.)

; load_file : charge fcb_main
load_file
.(
        jsr text_clear
        lda #0
        sta toobig
        sta fcb_main+12
        sta fcb_main+32
        ldx #F_OPEN
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #$FF
        bne opened
        lda #<m_newf
        ldy #>m_newf
        jmp set_msg
opened  lda #<BUF               ; lecture brute dans la zone de texte
        sta dst
        lda #>BUF
        sta dst+1
rd      lda dst+1               ; place pour 128 octets ?
        cmp blim+1
        bcc ok
        bne big
        lda dst
        cmp blim
        bcc ok
        beq ok
big     lda #1
        sta toobig
        jmp eof
ok      ldx #F_SETDMA
        lda dst
        ldy dst+1
        jsr BDOS
        ldx #F_READ
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #0
        bne eof
        clc
        lda dst
        adc #128
        sta dst
        bcc rd
        inc dst+1
        jmp rd
eof     ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        ; conversion : CR LF -> CR, LF seul -> CR, arrêt sur ^Z
        lda dst                 ; fin des données brutes
        sta t1
        lda dst+1
        sta t1+1
        lda #<BUF
        sta src
        sta dst
        lda #>BUF
        sta src+1
        sta dst+1
        lda #0
        sta prevc
        ldy #0
cv      lda src
        cmp t1
        bne cv1
        lda src+1
        cmp t1+1
        beq cvd
cv1     lda (src),y
        cmp #EOFC
        beq cvd
        cmp #LF
        bne store
        ldx prevc
        cpx #CR
        beq skip
        lda #CR
store   sta (dst),y
        inc dst
        bne skip
        inc dst+1
skip    lda (src),y
        sta prevc
        inc src
        bne cv
        inc src+1
        jmp cv
cvd     ; le texte [BUF, dst) passe à droite du trou : [BEND-n, BEND)
        sec
        lda dst
        sbc #<BUF
        sta cnt
        lda dst+1
        sbc #>BUF
        sta cnt+1
        sec
        lda bend
        sbc cnt
        sta ge
        lda bend+1
        sbc cnt+1
        sta ge+1
        ; copie à reculons (les zones peuvent se chevaucher)
        lda dst
        sta src
        lda dst+1
        sta src+1
        lda bend
        sta dst
        lda bend+1
        sta dst+1
        lda cnt
        ora cnt+1
        beq mvd
        ldy #0
mv      lda src
        bne m1
        dec src+1
m1      dec src
        lda dst
        bne m2
        dec dst+1
m2      dec dst
        lda (src),y
        sta (dst),y
        jsr dec_cnt
        bne mv
mvd     lda #<BUF
        sta gs
        lda #>BUF
        sta gs+1
        lda toobig
        beq r
        lda #<m_toobig
        ldy #>m_toobig
        jmp set_msg
r       rts
.)

; save_file : écrit dans NOM.$$$, puis remplace NOM.EXT
save_file
.(
        lda fcb_main+13         ; ouvert en lecture seule (R/O) ?
        bpl rw
        lda #<m_ro
        ldy #>m_ro
        jmp set_msg
rw      ldx #11                 ; fichier temporaire NOM.$$$
cp      lda fcb_main,x
        sta fcb_tmp,x
        dex
        bpl cp
        lda #"$"
        sta fcb_tmp+9
        sta fcb_tmp+10
        sta fcb_tmp+11
        jsr clr_tmp
        ldx #F_DELETE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        jsr clr_tmp
        ldx #F_MAKE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        cmp #$FF
        bne made
        lda #<m_dirfull
        ldy #>m_dirfull
        jmp set_msg
made    ldx #F_SETDMA
        lda #<recbuf
        ldy #>recbuf
        jsr BDOS
        lda #0
        sta rp
        sta t0
        sta t0+1
        jsr addr_of
loop    jsr ip_end
        beq last
        ldy #0
        lda (ip),y
        cmp #CR
        bne one
        jsr put
        bcs fail
        lda #LF
one     jsr put
        bcs fail
        jsr it_next
        jmp loop
last    lda rp                  ; complète le dernier enregistrement par ^Z
        beq closef
pad     lda #EOFC
        jsr put
        bcs fail
        lda rp
        bne pad
closef  ldx #F_CLOSE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        ldx #12                 ; remplace l'ancien fichier
z       lda #0
        sta fcb_main,x
        inx
        cpx #36
        bne z
        ldx #F_DELETE
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        ldx #15
rn      lda fcb_tmp,x
        sta fcb_ren,x
        lda fcb_main,x
        sta fcb_ren+16,x
        dex
        bpl rn
        ldx #F_RENAME
        lda #<fcb_ren
        ldy #>fcb_ren
        jsr BDOS
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #0
        sta modif
        lda #<m_saved
        ldy #>m_saved
        jmp set_msg
fail    ldx #F_CLOSE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        jsr clr_tmp
        ldx #F_DELETE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        lda #<m_dfull
        ldy #>m_dfull
        jmp set_msg

; put : ajoute A à l'enregistrement, l'écrit quand il est plein. C=1 si erreur
put     ldx rp
        sta recbuf,x
        inx
        stx rp
        cpx #128
        bne pok
        lda #0
        sta rp
        ldx #F_WRITE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        cmp #0
        bne perr
pok     clc
        rts
perr    sec
        rts
.)

clr_tmp
        ldx #12
        lda #0
ct1     sta fcb_tmp,x
        inx
        cpx #36
        bne ct1
        rts

; ---------------------------------------------------------------------
; Menus de l'éditeur
; ---------------------------------------------------------------------
ed_bar  .byt 4
        .word mn_fic, mn_edi, mn_chr, mn_opt

mn_fic  .byt 7,14
        .asc "Fichier",0
        .asc "Nouveau",0
        .byt MA_TYPE
        .word c_new
        .asc "Ouvrir...",0
        .byt MA_TYPE
        .word c_open
        .asc "Inserer... ^L",0
        .byt MA_TYPE
        .word c_insert
        .asc "Enregistrer ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Enreg. sous...",0
        .byt MA_TYPE
        .word c_saveas
        .asc "Imprimer    ^P",0
        .byt MA_TYPE
        .word c_print
it_quit .asc "Quitter",0
        .byt MA_TYPE
        .word c_quit

mn_edi  .byt 5,15
        .asc "Edition",0
        .asc "Marquer",0
        .byt MA_TYPE
        .word c_mark
        .asc "Copier",0
        .byt MA_TYPE
        .word c_copy
        .asc "Couper",0
        .byt MA_TYPE
        .word c_cut
        .asc "Coller",0
        .byt MA_TYPE
        .word c_paste
        .asc "Eff. paragr. ^Y",0
        .byt MA_TYPE
        .word c_delp

mn_chr  .byt 4,14
        .asc "Chercher",0
        .asc "Chercher... ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Suivant     ^G",0
        .byt MA_TYPE
        .word c_next
        .asc "Remplacer...",0
        .byt MA_TYPE
        .word c_repl
        .asc "Trop long   ^N",0
        .byt MA_TYPE
        .word c_long

mn_opt  .byt 3,14
        .asc "Options",0
        .asc "Coupure mots",0
        .byt MA_TYPE
        .word c_wrap
        .asc "Ins/Rempl. ^O",0
        .byt MA_TYPE
        .word c_ins
        .asc "Statistiques",0
        .byt MA_TYPE
        .word c_stats

gq_get   .byt G_GETMODE,0,0,0,0,0
gq_text  .byt G_MODE,0,0,0,0,0
gq_split .byt G_MODE,2,0,0,0,0
s_retour .asc "Retour "
s_logo   .asc "LOGO "
s_retr   .asc " /R",0

c_new    .byt $81,0
c_open   .byt $82,0
c_save   .byt $83,0
c_saveas .byt $84,0
c_quit   .byt $85,0
c_mark   .byt $86,0
c_copy   .byt $87,0
c_cut    .byt $88,0
c_paste  .byt $89,0
c_delp   .byt $8A,0
c_find   .byt $8B,0
c_next   .byt $8C,0
c_repl   .byt $8D,0
c_wrap   .byt $8E,0
c_ins    .byt $8F,0
c_stats  .byt $90,0
c_insert .byt $91,0
c_print  .byt $92,0
c_long   .byt $93,0

; ---------------------------------------------------------------------
; Messages
; ---------------------------------------------------------------------
m_noname  .asc "(sans nom)",0
m_ins     .asc "INS"
m_rfp     .asc "RFP"
m_full    .asc "Memoire pleine",0
m_mark    .asc "Marque posee",0
m_nomark  .asc "Pas de marque (Edition/Marquer)",0
m_empty   .asc "Bloc vide",0
m_big     .asc "Bloc trop grand (4 Ko max)",0
m_copied  .asc "Bloc copie",0
m_clipe   .asc "Presse-papiers vide",0
m_notf    .asc "Introuvable",0
m_wrapped .asc "Trouve en repartant du debut",0
m_nrep    .asc " remplacement(s)",0
m_car     .asc " car., ",0
m_mots    .asc " mots",0
m_wron    .asc "Coupure entre les mots",0
m_max     .asc ", max ",0
m_nolim   .asc "Pas de longueur maxi (EDIT.CFG)",0
m_nolong  .asc "Aucun paragraphe trop long",0
m_long    .asc "Paragraphe trop long : la suite",0
m_wroff   .asc "Coupure a 38 caracteres",0
m_newf    .asc "Nouveau fichier",0
m_toobig  .asc "Fichier tronque : trop gros",0
m_saved   .asc "Enregistre",0
m_ro      .asc "Fichier protege (R/O)",0
m_dirfull .asc "Repertoire plein",0
m_dfull   .asc "Disque plein : non enregistre",0
m_badname .asc "Nom de fichier incorrect",0
q_lose    .asc "Abandonner les modifs (O/N) ?",0
q_quit    .asc "Texte modifie. Quitter (O/N) ?",0
q_open    .asc "Ouvrir : ",0
q_insert  .asc "Inserer : ",0
m_nofile  .asc "Fichier introuvable",0
m_pdone   .asc "Texte imprime",0
m_pstop   .asc "Impression interrompue",0
m_inserted .asc " car. inseres",0
q_saveas  .asc "Enregistrer sous : ",0
q_find    .asc "Chercher : ",0
q_repl    .asc "Remplacer par : ",0
q_yn      .asc "Remplacer ? O/N/T(ous)/Esc",0

; ---------------------------------------------------------------------
; Tables d'adresses écran
; ---------------------------------------------------------------------
#include "edit_tab.s"

; ---------------------------------------------------------------------
; Variables
; ---------------------------------------------------------------------
retl    .byt 0              ; 1 : lancé par LOGO (EDITE), Quitter = Retour
crow2   .byt 0
stpos   .byt 0
mark2   .word 0
askp    .word 0
patlen  .byt 0
repllen .byt 0
rs_lo   .dsb ROWS+1,0
rs_hi   .dsb ROWS+1,0
inbuf   .dsb MAXIN+2,0
pat     .dsb MAXIN+2,0
repl    .dsb MAXIN+2,0
numbuf  .dsb 8,0
msgbuf  .dsb 48,0
stline  .dsb WIDTH,0
fcb_main .dsb 36,0
fcb_new .dsb 36,0
fcb_tmp .dsb 36,0
fcb_ren .dsb 36,0
recbuf  .dsb 128,0
; réglages du document (EDIT.CFG)
maxi    .word 0         ; longueur maxi d'un paragraphe (0 : sans limite)
prw     .byt 80         ; largeur de l'imprimante
cdrv    .byt 0          ; lecteur du document (1 = A:)
cfile   .byt 0          ; 1 : réglages lus dans EDIT.CFG
cidx    .byt 0
clen    .byt 0
clim    .byt 0
gnd     .byt 0
cpat    .dsb 12,0
cline   .dsb CLMAX+1,0
fcb_cfg .dsb 36,0
; paragraphes
pcol    .word 0
plen    .word 0
pst     .word 0
pno     .word 0
pmax    .word 0
pmaxl   .word 0
lfirst  .word 0
lnext   .word 0
; impression
pmaxc   .byt 0
pn      .byt 0
psp     .byt 0

        .dsb (*+255)/256*256-*,0
BUF                             ; zone de texte : BUF à BEND
