; =====================================================================
;  EDSPRITE.COM — éditeur de sprites et de caractères (fichiers .SPR)
;
;  EDSPRITE [nom]
;
;  Dessine les fichiers .SPR de GRAPHER (docs/grapher.md § 10.1) :
;  genre 0, sprites (dessin et silhouette), genre 1, tuiles ou
;  caractères (dessin seul). Spécification : docs/editeur-sprites.md.
;
;  Écran : grille de saisie (colonnes 3-26, lignes 2-25 : un point du
;  sprite par case, 24 x 24 points visibles), liste des sprites
;  (colonnes 28-39, lignes 1-16), aperçu en taille réelle (lignes
;  20-25), ou à la place les octets en hexadécimal (^H), ligne d'état
;  (ligne 27). Les 12 caractères de la grille (3 états x traits de
;  limite) redessinent des codes de la police standard qu'aucun texte
;  n'affiche ; l'aperçu prend les codes 64-80 du jeu secondaire
;  (attribut 9 en colonne 27), plus bas que les menus déroulants. Le
;  démarrage à chaud rend la police ; l'historique des lignes, recouvert
;  par le jeu secondaire, est vidé en sortant.
;
;  Fichier entier en mémoire, de BUF à BUF + fsize ; un sprite : en-tête
;  de 8 octets (largeur, hauteur, 0, 0, nom de 4 caractères), puis ses
;  cases (16 octets : dessin, silhouette ; 8 en genre 1), ligne par ligne.
;  Enregistrement par NOM.$$$ (comme EDIT).
; =====================================================================

#include "cpa.inc"

STROW   = 27            ; ligne d'état
WIDTH   = 38
MAXIN   = 14
CR      = $0D
ESC     = $1B
GROW    = 2             ; première ligne de la grille
GCOL    = 3             ; première colonne de la grille
PCOL    = 28            ; panneau de droite
LROWS   = 12            ; lignes de la liste (2-13)
PROW    = 20            ; aperçu : lignes 20-25, colonnes 28-33
STDF    = $B400         ; police standard (code * 8)
ALTF    = $B800         ; jeu secondaire
PC0     = 64            ; aperçu : codes 64-79 (cases), 80 (décor)
PCD     = 80
HIST    = $BA80         ; historique des lignes du système : ses 8 premiers
                        ;   octets (code PCD de l'aperçu) gardés en hsave
MAXSPR  = 264           ; un sprite de 4 x 4 : 8 + 16 x 16

; --- page zéro ---
t0      = $10
t1      = $12
src     = $14
dst     = $16
ptr     = $18
scr     = $1A
msgp    = $1C           ; message de la ligne d'état (octet haut 0 : aucun)
askp    = $1E
cnt     = $20
spp     = $22           ; sprite courant
base    = $24           ; sprite lu par pix_get (spp, ou la copie d'annulation)
len     = $26
fsize   = $28           ; taille du fichier en mémoire
cap     = $2A           ; fin de la mémoire utilisable
cur     = $2C           ; numéro du sprite courant
sw      = $2D           ; largeur, hauteur en caractères
sh      = $2E
cs      = $2F           ; octets par case (16 ou 8)
px      = $30           ; curseur (point)
py      = $31
gtop    = $32           ; première ligne de caractères affichée
zone    = $33           ; 0 saisie, 1 sélection
ltop    = $34           ; premier sprite de la liste
hexm    = $35           ; 1 : octets en hexadécimal
decor   = $36
pen     = $37           ; 1 : crayon
lastst  = $38           ; dernier état posé (0 plein, 1 masque, 2 transparent)
modif   = $39
genre   = $3A
hasname = $3B
inlen   = $3C
spos    = $3D
tmpb    = $3E
jj      = $3F
rr      = $40
cx      = $41
cy      = $42
gx      = $43           ; point lu ou écrit par pix_get / pix_set
gy      = $44
ww      = $45           ; largeur, hauteur en points
hh      = $46
dd      = $47           ; octets lus (dessin, silhouette)
ss      = $48
curon   = $49           ; 1 : curseur affiché (vidéo inverse)
blk     = $4A           ; prochain clignotement (2 octets)
undok   = $4C           ; 1 : annulation possible (sprite undoi)
undoi   = $4D
clipk   = $4E           ; presse-papiers : 0 vide, 1 sprite, 2 case
wassplit = $4F
kk      = $50
aa      = $51
bb      = $52
nw      = $53           ; nouvelle taille
nh      = $54
mm      = $55           ; mode S (0) / M (1) du sprite affiché
vv      = $56
ptr2    = $57           ; 2 octets
fsl     = $59           ; taille lue au chargement (2 octets)
d0      = $5B           ; draw_grid : octets de la case, bit du point
sx1     = $5C
bm      = $5D

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
.(
        cld
        lda #0
        ldx #$4F-$10
z       sta $10,x
        dex
        bpl z
        ldx #0
z2      sta mflag,x
        inx
        bne z2
        lda #1
        sta decor               ; décor : damier
        jsr blk_now
        lda TPA_TOP+1           ; mémoire jusqu'au haut de la TPA, moins
        sec                     ;   une page (le dernier enregistrement
        sbc #1                  ;   est complété au-delà de fsize)
        sta cap+1
        lda FCB1+1
        cmp #" "
        beq noname
        ldx #11
cp      lda FCB1,x
        sta fcb_main,x
        dex
        bpl cp
        jsr def_ext
        lda #1
        sta hasname
        jsr load_file
        bcc gfx
        cmp #1                  ; 1 : introuvable -> nouveau fichier
        beq nf
        lda #<m_bad
        ldy #>m_bad
        jmp fatal
nf      lda #0
        jsr new_file
        lda #<m_new
        ldy #>m_new
        jsr set_msg
        jmp gfx
noname  lda #0
        jsr new_file
gfx     ldx #F_GFX              ; lancé depuis le mode SPLIT ?
        lda #<gq_get
        ldy #>gq_get
        jsr BDOS
        sta wassplit
        beq txt
        ldx #F_GFX
        lda #<gq_text
        ldy #>gq_text
        jsr BDOS
txt     lda #<SCREEN            ; adresses des lignes de l'écran
        sta t0
        lda #>SCREEN
        sta t0+1
        ldx #0
tl      lda t0
        sta row_lo,x
        lda t0+1
        sta row_hi,x
        clc
        lda t0
        adc #40
        sta t0
        bcc tl1
        inc t0+1
tl1     inx
        cpx #28
        bne tl
        lda #<es_bar
        ldy #>es_bar
        jsr B_MENUBAR
        ldx #F_CONOUT           ; efface l'écran
        lda #$0C
        jsr BDOS
        jsr cur_hide
        lda #$14                ; ligne d'état : papier bleu, encre blanche
        sta SCREEN+STROW*40
        lda #$07
        sta SCREEN+STROW*40+1
        ldx #7                  ; début de l'historique, recouvert par
hs      lda HIST,x              ;   le décor de l'aperçu (code PCD)
        sta hsave,x
        dex
        bpl hs
        jsr glyphs
        lda #0
        jsr sel
        jmp main
.)

; def_ext : type vide -> SPR
def_ext
.(
        lda fcb_main+9
        cmp #" "
        bne r
        ldx #2
l       lda t_spr,x
        sta fcb_main+9,x
        dex
        bpl l
r       rts
.)
t_spr   .asc "SPR"

fatal   ldx #F_PRINT
        jsr BDOS
        jmp WBOOT

; ---------------------------------------------------------------------
; Boucle principale
; ---------------------------------------------------------------------
main
        jsr render
wait    jsr B_CONST
        bne getk
        jsr blink
        jmp wait
getk    jsr cur_off
        jsr B_CONIN
        ldx #0                  ; une touche efface le message
        stx msgp+1
        jsr dispatch
        jsr B_CONST             ; d'autres touches attendent : on
        bne getk                ;   n'affiche qu'à la fin de la rafale
        jmp main

; dispatch : A = touche ou code de menu ($81-$A0)
dispatch
.(
        cmp #$F0
        bcs arr
        cmp #$81
        bcs menu
        cmp #$7F
        beq del
        cmp #$20
        bcs ch
        tax                     ; codes de contrôle 0-31
        lda cv_lo,x
        sta t0
        lda cv_hi,x
        sta t0+1
        jmp (t0)
arr     and #$07                ; SHIFT ou CTRL + flèche ($F0-$F7)
        tax
        lda av_lo,x
        sta t0
        lda av_hi,x
        sta t0+1
        jmp (t0)
menu    cmp #$A2
        bcs none
        sec
        sbc #$81
        tax
        lda mv_lo,x
        sta t0
        lda mv_hi,x
        sta t0+1
        jmp (t0)
del     lda zone
        bne none
        lda #2                  ; DEL : point transparent (genre 1 : vide)
        jmp k_state
ch      jsr upc
        ldx zone
        bne chl
        cmp #" "
        beq sp
        cmp #"M"
        beq km
        cmp #"P"
        beq kp
none    rts
sp      lda #0                  ; ESPACE : plein / transparent
        jmp k_toggle
km      lda #1                  ; M : masque / transparent
        jmp k_toggle
kp      lda pen
        eor #1
        sta pen
        beq none
        jsr save_undo
        jmp put_last
chl     cmp #"S"                ; sélection : S, M
        beq ks
        cmp #"M"
        bne none
        lda #1
        .byt $2C
ks      lda #0
        jmp set_sm
.)

k_none  rts

; codes 0-31 : ^C copier, 8-11 flèches, RETURN, ^N ^O ^Q ^S ^V ^X ^Z,
; ESC, 28 ^H hexa, 29 ^I zone
cv_lo   .byt <k_none,<k_none,<k_none,<k_copy,<k_none,<k_none,<k_none,<k_none
        .byt <k_left,<k_right,<k_down,<k_up,<k_none,<k_ret,<k_newf,<k_open
        .byt <k_none,<k_quit,<k_none,<k_save,<k_none,<k_none,<k_paste,<k_none
        .byt <k_cut,<k_none,<k_undo,<k_esc,<k_hex,<k_zone,<k_none,<k_none
cv_hi   .byt >k_none,>k_none,>k_none,>k_copy,>k_none,>k_none,>k_none,>k_none
        .byt >k_left,>k_right,>k_down,>k_up,>k_none,>k_ret,>k_newf,>k_open
        .byt >k_none,>k_quit,>k_none,>k_save,>k_none,>k_none,>k_paste,>k_none
        .byt >k_cut,>k_none,>k_undo,>k_esc,>k_hex,>k_zone,>k_none,>k_none
; SHIFT + gauche droite bas haut, CTRL + gauche droite bas haut
av_lo   .byt <k_sleft,<k_sright,<k_sdown,<k_sup,<k_prev,<k_next,<k_last,<k_first
av_hi   .byt >k_sleft,>k_sright,>k_sdown,>k_sup,>k_prev,>k_next,>k_last,>k_first
; menus ($81-$A1), dans l'ordre des articles (Détourer, $A1, ajouté à la fin)
mv_lo   .byt <k_newf,<k_open,<k_save,<k_saveas,<k_quit
        .byt <k_undo,<k_cut,<k_copy,<k_paste,<k_erase
        .byt <k_snew,<k_sdup,<k_sdel,<k_sren,<k_ssize,<k_sfwd,<k_sback,<k_zsel,<k_zedit
        .byt <k_inv,<k_mirh,<k_mirv,<k_rot,<k_shl,<k_shr,<k_shu,<k_shd,<k_sil,<k_font
        .byt <k_hex,<k_decor,<k_anim,<k_detour
mv_hi   .byt >k_newf,>k_open,>k_save,>k_saveas,>k_quit
        .byt >k_undo,>k_cut,>k_copy,>k_paste,>k_erase
        .byt >k_snew,>k_sdup,>k_sdel,>k_sren,>k_ssize,>k_sfwd,>k_sback,>k_zsel,>k_zedit
        .byt >k_inv,>k_mirh,>k_mirv,>k_rot,>k_shl,>k_shr,>k_shu,>k_shd,>k_sil,>k_font
        .byt >k_hex,>k_decor,>k_anim,>k_detour

; ---------------------------------------------------------------------
; Sprite courant
; ---------------------------------------------------------------------
; nspr : A = nombre de sprites
nspr    lda BUF+4
        rts

; spr_ptr : A = numéro -> ptr = son en-tête
spr_ptr
.(
        sta kk
        lda #<(BUF+8)
        sta ptr
        lda #>(BUF+8)
        sta ptr+1
l       lda kk
        beq r
        jsr spr_len
        clc
        lda ptr
        adc len
        sta ptr
        lda ptr+1
        adc len+1
        sta ptr+1
        dec kk
        jmp l
r       rts
.)

; spr_len : len = taille du sprite en ptr (8 + cases)
spr_len
.(
        ldy #0
        lda (ptr),y             ; largeur * hauteur
        tax
        iny
        lda #0
m       clc
        adc (ptr),y
        dex
        bne m
        asl                     ; (1 à 16) * octets par case
        asl
        asl
        sta len
        lda #0
        sta len+1
        lda cs
        cmp #16
        bne c8
        asl len
        rol len+1
c8      clc
        lda len
        adc #8
        sta len
        bcc r
        inc len+1
r       rts
.)

; sel : A = numéro du sprite courant ; spp, taille, curseur gardé dedans
sel
.(
        sta cur
        jsr spr_ptr
        lda ptr
        sta spp
        lda ptr+1
        sta spp+1
        ldy #0
        lda (spp),y
        sta sw
        iny
        lda (spp),y
        sta sh
        ldx sw                  ; points : 6 x largeur, 8 x hauteur
        lda #0
w       clc
        adc #6
        dex
        bne w
        sta ww
        lda sh
        asl
        asl
        asl
        sta hh
        lda px
        cmp ww
        bcc p1
        ldx ww
        dex
        stx px
p1      lda py
        cmp hh
        bcc p2
        ldx hh
        dex
        stx py
p2      ldx cur
        lda mflag,x
        sta mm
        jsr fix_top
        jmp fix_list
.)

; fix_top : la ligne de caractères du curseur est affichée (3 à la fois)
fix_top
.(
        lda py
        lsr
        lsr
        lsr
        cmp gtop
        bcs ab
        sta gtop
        rts
ab      sec
        sbc #2
        bcc r
        beq r
        cmp gtop
        bcc r
        sta gtop
r       lda sh                  ; jamais de ligne vide en bas s'il y en a
        sec                     ;   plus haut
        sbc #3
        bcs b
        lda #0
b       cmp gtop
        bcs r2
        sta gtop
r2      rts
.)

; fix_list : le sprite courant est dans la liste affichée
fix_list
.(
        lda cur
        cmp ltop
        bcs ab
        sta ltop
        rts
ab      sec
        sbc #LROWS-1
        bcc r
        cmp ltop
        bcc r
        sta ltop
r       rts
.)

; ---------------------------------------------------------------------
; Points
; ---------------------------------------------------------------------
; pix_addr : point (gx, gy) du sprite en base -> ptr = sa case, Y = ligne
;   dans la case, A = masque du bit
pix_addr
.(
        ldx gx                  ; colonne de caractère, point dans la case
        lda div6,x
        sta cx
        lda gy
        lsr
        lsr
        lsr
        tax                     ; case = ligne * largeur + colonne
        lda cx
        cpx #0
        beq m
l       clc
        adc sw
        dex
        bne l
m       tax                     ; décalage = case * cs (+ 8)
        lda #8
        sta ptr
        lda #0
        sta ptr+1
        cpx #0
        beq d
l2      clc
        lda ptr
        adc cs
        sta ptr
        bcc l3
        inc ptr+1
l3      dex
        bne l2
d       clc
        lda ptr
        adc base
        sta ptr
        lda ptr+1
        adc base+1
        sta ptr+1
        lda gy
        and #7
        tay
        ldx gx
        lda bitm,x
        rts
.)

; pix_get : (gx, gy) de base -> dd, ss (0 ou 1)
pix_get
.(
        jsr pix_addr
        sta tmpb
        ldx #0
        lda (ptr),y
        and tmpb
        beq d
        inx
d       stx dd
        ldx #0
        lda genre
        bne s
        tya
        clc
        adc #8
        tay
        lda (ptr),y
        and tmpb
        beq s
        inx
s       stx ss
        rts
.)

; pix_set : (gx, gy) du sprite courant <- dd, ss
pix_set
.(
        lda spp
        sta base
        lda spp+1
        sta base+1
        jsr pix_addr
        sta tmpb
        eor #$FF
        sta jj
        lda (ptr),y
        and jj
        ldx dd
        beq d
        ora tmpb
d       sta (ptr),y
        lda genre
        bne r
        tya
        clc
        adc #8
        tay
        lda (ptr),y
        and jj
        ldx ss
        beq s
        ora tmpb
s       sta (ptr),y
r       rts
.)

; state : dd, ss -> A = état affiché (0 plein, 1 vide/masque, 2 grisé)
state
.(
        lda genre
        beq g0
        lda dd                  ; genre 1 : plein ou vide
        eor #1
        rts
g0      lda mm
        bne m
        lda dd                  ; S : plein, masque, transparent
        bne p
        lda ss
        bne v
t       lda #2
        rts
m       lda dd                  ; M : la silhouette pleine
        ora ss
        beq t
p       lda #0
        rts
v       lda #1
        rts
.)

; ---------------------------------------------------------------------
; Saisie d'un point
; ---------------------------------------------------------------------
; k_toggle : A = 0 (ESPACE : plein) ou 1 (M : masque) ; le point déjà
;   dans cet état redevient transparent
k_toggle
.(
        sta aa
        lda mm                  ; mode M : M comme ESPACE (la silhouette)
        beq m0
        lda #0
        sta aa
m0      lda zone
        bne r
        lda genre               ; genre 1 : pas de masque, ESPACE plein/vide
        beq g0
        lda aa
        bne nomask
g0      jsr cur_pix
        jsr state
        cmp aa
        bne set
        lda #2
        .byt $2C
set     lda aa
        jmp k_state
nomask  lda #<m_nomask
        ldy #>m_nomask
        jmp set_msg
r       rts
.)

; cur_pix : point du curseur -> dd, ss
cur_pix lda px
        sta gx
        lda py
        sta gy
        lda spp
        sta base
        lda spp+1
        sta base+1
        jmp pix_get

; k_state : A = état (0 plein, 1 masque, 2 transparent) au point du curseur
k_state
        sta lastst
        lda zone
        bne ks_r
        jsr save_undo
put_last
        lda zone
        bne ks_r
        lda px
        sta gx
        lda py
        sta gy
        ldx lastst
        lda mm                  ; mode M : plein et masque = silhouette
        beq ks_s
        cpx #2
        beq ks_s
        ldx #1
ks_s    lda genre
        beq ks_g0
        lda #0                  ; genre 1 : plein, ou vide
        sta ss
        cpx #0
        bne ks_v
        lda #1
ks_v    sta dd
        jmp ks_w
ks_g0   lda st_d,x
        sta dd
        lda st_s,x
        sta ss
ks_w    jsr pix_set
        lda #1
        sta modif
ks_r    rts
st_d    .byt 1,0,0
st_s    .byt 1,1,0

; ---------------------------------------------------------------------
; Déplacements
; ---------------------------------------------------------------------
k_left
.(
        lda zone
        bne r
        lda px
        beq r
        dec px
        jmp moved
r       rts
.)
k_right
.(
        lda zone
        bne r
        ldx px
        inx
        cpx ww
        bcs r
        stx px
        jmp moved
r       rts
.)
k_up
.(
        lda zone
        beq g
        lda cur                 ; sélection : sprite précédent
        beq r
        sec
        sbc #1
        jmp sel
g       lda py
        beq r
        dec py
        jmp moved
r       rts
.)
k_down
.(
        lda zone
        beq g
        ldx cur                 ; sélection : sprite suivant
        inx
        txa
        cmp BUF+4
        bcs r
        jmp sel
g       ldx py
        inx
        cpx hh
        bcs r
        stx py
        jmp moved
r       rts
.)
; SHIFT + flèche : au bord du caractère, puis au caractère suivant
k_sleft
.(
        lda zone
        bne r
        ldx px
        beq r
        lda mod6,x
        bne b
        txa
        sec
        sbc #6
        sta px
        jmp moved
b       txa
        sec
        sbc mod6,x
        sta px
        jmp moved
r       rts
.)
k_sright
.(
        lda zone
        bne r
        ldx px
        lda mod6,x
        cmp #5
        bne b
        txa
        clc
        adc #6
        .byt $2C
b       lda end6,x
        cmp ww
        bcs r
        sta px
        jmp moved
r       rts
.)
k_sup
.(
        lda zone
        beq g
        lda cur                 ; sélection : page précédente
        sec
        sbc #LROWS
        bcs s
        lda #0
s       jmp sel
g       lda py
        beq r
        and #7
        bne b
        lda py
        sec
        sbc #8
        sta py
        jmp moved
b       lda py
        and #$F8
        sta py
        jmp moved
r       rts
.)
k_sdown
.(
        lda zone
        beq g
        lda cur                 ; sélection : page suivante
        clc
        adc #LROWS
        bcs l
        cmp BUF+4
        bcc s
l       ldx BUF+4
        dex
        txa
s       jmp sel
g       lda py
        and #7
        cmp #7
        bne b
        lda py
        clc
        adc #8
        .byt $2C
b       lda py
        ora #7
        cmp hh
        bcs r
        sta py
        jmp moved
r       rts
.)
k_prev
.(
        lda cur
        beq r
        sec
        sbc #1
        jmp sel
r       rts
.)
k_next
.(
        ldx cur
        inx
        cpx BUF+4
        bcs r
        txa
        jmp sel
r       rts
.)
k_first lda #0
        jmp sel
k_last  ldx BUF+4
        dex
        txa
        jmp sel

moved   jsr fix_top
        lda pen                 ; crayon : le point reçoit le dernier état
        beq mv_r
        jsr save_undo
        jmp put_last
mv_r    rts

k_ret   lda #0                  ; RETURN (sélection) : à la saisie
        sta zone
        rts
k_esc   lda #0                  ; ESC : crayon levé
        sta pen
        rts
k_zone  lda zone
        eor #1
        sta zone
        rts
k_zsel  lda #1
        sta zone
        rts
k_zedit lda #0
        sta zone
        rts
k_hex   lda hexm
        eor #1
        sta hexm
        rts

; set_sm : A = 0 (S) ou 1 (M) pour le sprite courant
set_sm
.(
        ldx genre
        bne no
        ldx cur
        sta mflag,x
        sta mm
        rts
no      lda #<m_nomask
        ldy #>m_nomask
        jmp set_msg
.)

; ---------------------------------------------------------------------
; Annulation (un niveau, le dessin du sprite courant)
; ---------------------------------------------------------------------
; save_undo : copie du sprite courant dans undobuf
save_undo
        lda spp
        sta src
        lda spp+1
        sta src+1
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        lda #<undobuf
        sta ptr
        lda #>undobuf
        sta ptr+1
        jsr copy_to
        lda cur
        sta undoi
        lda #1
        sta undok
        rts

; k_undo : échange le sprite et sa copie (^Z de nouveau rétablit)
k_undo
.(
        lda undok
        beq no
        lda undoi
        cmp cur
        bne no
        ldy #0                  ; même taille ? (largeur, hauteur)
        lda (spp),y
        cmp undobuf
        bne no
        iny
        lda (spp),y
        cmp undobuf+1
        bne no
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        lda spp
        sta src
        lda spp+1
        sta src+1
        lda #<undobuf
        sta dst
        lda #>undobuf
        sta dst+1
        ldy #0
l       lda len
        ora len+1
        beq ok
        lda (src),y
        pha
        lda (dst),y
        sta (src),y
        pla
        sta (dst),y
        inc src
        bne s1
        inc src+1
s1      inc dst
        bne s2
        inc dst+1
s2      lda len
        bne s3
        dec len+1
s3      dec len
        jmp l
ok      lda #1
        sta modif
        rts
no      lda #<m_noundo
        ldy #>m_noundo
        jmp set_msg
.)

; ---------------------------------------------------------------------
; Mémoire : insertion et retrait d'octets dans le fichier
; ---------------------------------------------------------------------
; mem_ins : len octets libres en ptr (le reste remonte). C=1 : pas de place
mem_ins
.(
        clc
        lda fsize
        adc len
        sta t0
        lda fsize+1
        adc len+1
        sta t0+1
        clc                     ; BUF + fsize + len < cap ?
        lda t0
        adc #<BUF
        sta t1
        lda t0+1
        adc #>BUF
        cmp cap+1
        bcc ok
        lda #<m_mem
        ldy #>m_mem
        jsr set_msg
        sec
        rts
ok      lda #<BUF               ; src = fin actuelle, dst = fin + len
        clc
        adc fsize
        sta src
        lda #>BUF
        adc fsize+1
        sta src+1
        clc
        lda src
        adc len
        sta dst
        lda src+1
        adc len+1
        sta dst+1
        sec                     ; cnt = fin - ptr
        lda src
        sbc ptr
        sta cnt
        lda src+1
        sbc ptr+1
        sta cnt+1
        ldy #0
l       lda cnt
        ora cnt+1
        beq e
        lda src
        bne s1
        dec src+1
s1      dec src
        lda dst
        bne s2
        dec dst+1
s2      dec dst
        lda (src),y
        sta (dst),y
        lda cnt
        bne s3
        dec cnt+1
s3      dec cnt
        jmp l
e       lda t0
        sta fsize
        lda t0+1
        sta fsize+1
        clc
        rts
.)

; mem_del : retire len octets en ptr (le reste descend)
mem_del
.(
        clc
        lda ptr
        adc len
        sta src
        lda ptr+1
        adc len+1
        sta src+1
        lda ptr
        sta dst
        lda ptr+1
        sta dst+1
        sec                     ; cnt = BUF + fsize - src
        lda #<BUF
        adc fsize               ; (C=1 : + 1, corrigé ci-dessous)
        sta cnt
        lda #>BUF
        adc fsize+1
        sta cnt+1
        lda cnt
        bne c1
        dec cnt+1
c1      dec cnt
        sec
        lda cnt
        sbc src
        sta cnt
        lda cnt+1
        sbc src+1
        sta cnt+1
        ldy #0
l       lda cnt
        ora cnt+1
        beq e
        lda (src),y
        sta (dst),y
        inc src
        bne s1
        inc src+1
s1      inc dst
        bne s2
        inc dst+1
s2      lda cnt
        bne s3
        dec cnt+1
s3      dec cnt
        jmp l
e       sec
        lda fsize
        sbc len
        sta fsize
        lda fsize+1
        sbc len+1
        sta fsize+1
        rts
.)

; copy_to : len octets de src vers ptr
copy_to
.(
        lda ptr
        sta dst
        lda ptr+1
        sta dst+1
        lda len
        sta cnt
        lda len+1
        sta cnt+1
        ldy #0
l       lda cnt
        ora cnt+1
        beq r
        lda (src),y
        sta (dst),y
        inc src
        bne s1
        inc src+1
s1      inc dst
        bne s2
        inc dst+1
s2      lda cnt
        bne s3
        dec cnt+1
s3      dec cnt
        jmp l
r       rts
.)

; after_cur : ptr = juste après le sprite courant
after_cur
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        clc
        lda ptr
        adc len
        sta ptr
        lda ptr+1
        adc len+1
        sta ptr+1
        rts

; ins_after : insère le sprite en src (taille d'après son en-tête) après le
;   courant, qui devient celui-là. C=1 : pas fait (message posé)
ins_after
.(
        lda BUF+4
        cmp #255
        bne ab
        lda #<m_full
        ldy #>m_full
        jsr set_msg
        sec
        rts
ab      lda src                 ; taille du nouveau
        sta ptr
        lda src+1
        sta ptr+1
        jsr spr_len
        lda len
        pha
        lda len+1
        pha
        jsr after_cur
        pla
        sta len+1
        pla
        sta len
        lda src
        pha
        lda src+1
        pha
        jsr mem_ins
        pla
        sta src+1
        pla
        sta src
        bcs r
        jsr copy_to
        inc BUF+4
        ldx cur                 ; drapeaux S/M : un cran plus loin
        inx
        txa
        jsr flag_ins
        lda #1
        sta modif
        lda #0
        sta undok
        ldx cur
        inx
        txa
        jsr sel
        clc
r       rts
.)

; flag_ins : A = rang inséré (mflag décalé, nouveau à S)
flag_ins
.(
        sta kk
        ldx #254
l       cpx kk
        bcc e
        lda mflag,x
        sta mflag+1,x
        dex
        cpx #$FF
        bne l
e       ldx kk
        lda #0
        sta mflag,x
        rts
.)

; del_cur : retire le sprite courant (il en reste au moins un)
del_cur
.(
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        jsr mem_del
        dec BUF+4
        ldx cur
l       lda mflag+1,x
        sta mflag,x
        inx
        bne l
        lda #1
        sta modif
        lda #0
        sta undok
        lda cur
        cmp BUF+4
        bcc s
        ldx BUF+4
        dex
        txa
s       jmp sel
.)

; cur_to_tmp : copie du sprite courant dans tmpspr
cur_to_tmp
.(
        lda spp
        sta src
        lda spp+1
        sta src+1
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        lda #<tmpspr
        sta ptr
        lda #>tmpspr
        sta ptr+1
        jmp copy_to
.)

; ---------------------------------------------------------------------
; Menu Edit
; ---------------------------------------------------------------------
k_copy
.(
        lda zone
        beq cell
        jsr cur_to_tmp          ; sélection : le sprite entier
        ldx #0
l       lda tmpspr,x
        sta clipbuf,x
        inx
        bne l
l2      lda tmpspr+256,x
        sta clipbuf+256,x
        inx
        cpx #8
        bne l2
        lda #1
        sta clipk
        lda #<m_copied
        ldy #>m_copied
        jmp set_msg
cell    jsr cell_ptr            ; saisie : la case du curseur
        ldy #0
c       lda (ptr),y
        sta clipbuf,y
        iny
        cpy cs
        bne c
        lda #2
        sta clipk
        lda #<m_copied
        ldy #>m_copied
        jmp set_msg
.)

; cell_ptr : ptr = case du curseur dans le sprite courant
cell_ptr
        lda px
        sta gx
        lda py
        and #$F8
        sta gy
        lda spp
        sta base
        lda spp+1
        sta base+1
        jmp pix_addr

k_cut
.(
        jsr k_copy
        lda zone
        beq cell
        lda BUF+4               ; sélection : retire le sprite (sauf le
        cmp #2                  ;   dernier)
        bcc r
        jmp del_cur
cell    jmp clr_cell
r       rts
.)

k_erase
.(
        lda zone
        beq cell
        jsr save_undo           ; sélection : efface tout le dessin
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        ldy #8
        lda #0
l       sta (spp),y
        iny
        cpy len
        bne l
        lda len+1               ; 4 x 4 : 264 octets
        beq r
        inc spp+1
        ldy #0
l2      sta (spp),y
        iny
        cpy #8
        bne l2
        dec spp+1
r       lda #1
        sta modif
        rts
cell    jmp clr_cell
.)

clr_cell
.(
        jsr save_undo
        jsr cell_ptr
        ldy #0
        lda #0
l       sta (ptr),y
        iny
        cpy cs
        bne l
        lda #1
        sta modif
        rts
.)

k_paste
.(
        lda zone
        beq cell
        lda clipk               ; sélection : un sprite après le courant
        cmp #1
        bne empty
        lda #<clipbuf
        sta src
        lda #>clipbuf
        sta src+1
        jmp ins_after
cell    lda clipk
        cmp #2
        bne empty
        jsr save_undo
        jsr cell_ptr
        ldy #0
c       lda clipbuf,y
        sta (ptr),y
        iny
        cpy cs
        bne c
        lda #1
        sta modif
        rts
empty   lda #<m_noclip
        ldy #>m_noclip
        jmp set_msg
.)

; ---------------------------------------------------------------------
; Menu Sprite
; ---------------------------------------------------------------------
; k_snew : nouveau sprite (taille, nom) après le courant
k_snew
.(
        jsr ask_size
        bcs r
        jsr ask_name
        bcs r
        lda nw
        sta tmpspr
        lda nh
        sta tmpspr+1
        lda #0
        sta tmpspr+2
        sta tmpspr+3
        ldx #3
n       lda inbuf+16,x
        sta tmpspr+4,x
        dex
        bpl n
        ldx #0                  ; cases vides
        lda #0
z       sta tmpspr+8,x
        inx
        bne z
        ldx #0
z2      sta tmpspr+256,x
        inx
        cpx #8
        bne z2
        lda #<tmpspr
        sta src
        lda #>tmpspr
        sta src+1
        jmp ins_after
r       rts
.)

; k_sdup : copie du sprite courant juste après lui (le dernier chiffre
;   du nom augmente : HER1 -> HER2)
k_sdup
.(
        jsr cur_to_tmp
        lda tmpspr+7
        cmp #"0"
        bcc i
        cmp #"9"
        bcs i
        inc tmpspr+7
i       lda #<tmpspr
        sta src
        lda #>tmpspr
        sta src+1
        jmp ins_after
.)

k_sdel
.(
        lda BUF+4
        cmp #2
        bcc last
        lda #<q_del
        ldy #>q_del
        jsr ask_yn
        bcc r
        jmp del_cur
last    lda #<m_last
        ldy #>m_last
        jmp set_msg
r       rts
.)

k_sren
.(
        jsr ask_name
        bcs r
        ldy #4
        ldx #0
l       lda inbuf+16,x
        sta (spp),y
        iny
        inx
        cpx #4
        bne l
        lda #1
        sta modif
r       rts
.)

; k_ssize : nouvelle taille ; le dessin garde son coin haut-gauche
k_ssize
.(
        jsr ask_size
        bcc go
        rts
go      ldx #0                  ; tmpspr : en-tête, cases vides
        lda #0
z       sta tmpspr,x
        inx
        bne z
z2      sta tmpspr+256,x
        inx
        cpx #8
        bne z2
        ldy #7
h       lda (spp),y
        sta tmpspr,y
        dey
        bpl h
        lda nw
        sta tmpspr
        lda nh
        sta tmpspr+1
        lda #0                  ; cases communes recopiées
        sta cy
ly      lda cy
        cmp nh
        bcs cp
        cmp sh
        bcs cp
        lda #0
        sta cx
lx      lda cx
        cmp nw
        bcs ny
        cmp sw
        bcs ny
        lda cy                  ; source : spp + 8 + (cy*sw+cx)*cs
        ldx sw
        jsr cell_off
        clc
        adc spp
        sta src
        txa
        adc spp+1
        sta src+1
        lda cy                  ; destination : tmpspr + 8 + (cy*nw+cx)*cs
        ldx nw
        jsr cell_off
        clc
        adc #<tmpspr
        sta dst
        txa
        adc #>tmpspr
        sta dst+1
        ldy #0
c       lda (src),y
        sta (dst),y
        iny
        cpy cs
        bne c
        inc cx
        jmp lx
ny      inc cy
        jmp ly
cp      lda #<tmpspr            ; le nouveau inséré devant l'ancien (rien
        sta ptr                 ;   n'est perdu s'il manque de place),
        lda #>tmpspr            ;   puis l'ancien retiré
        sta ptr+1
        jsr spr_len
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr mem_ins
        bcs bad
        lda #<tmpspr
        sta src
        lda #>tmpspr
        sta src+1
        jsr copy_to
        lda dst                 ; (dst : juste après le nouveau)
        sta ptr
        lda dst+1
        sta ptr+1
        jsr spr_len
        jsr mem_del
        lda #1
        sta modif
        lda #0
        sta undok
        lda cur
        jmp sel
bad     lda cur
        jmp sel
r       rts
.)

; cell_off : A = ligne de caractère, X = largeur, cx = colonne -> A/X =
;   décalage de la case (8 + (ligne * largeur + colonne) * cs)
cell_off
.(
        stx tmpb
        tax
        lda cx
        cpx #0
        beq m
l       clc
        adc tmpb
        dex
        bne l
m       tax
        lda #8
        sta t1
        lda #0
        sta t1+1
        cpx #0
        beq e
l2      clc
        lda t1
        adc cs
        sta t1
        bcc l3
        inc t1+1
l3      dex
        bne l2
e       lda t1
        ldx t1+1
        rts
.)

; k_sfwd / k_sback : le sprite courant avance ou recule d'un rang
k_sfwd
.(
        ldx cur
        inx
        cpx BUF+4
        bcs r
        lda cur                 ; drapeaux échangés
        tax
        lda mflag,x
        pha
        lda mflag+1,x
        sta mflag,x
        pla
        sta mflag+1,x
        jsr cur_to_tmp          ; retiré, puis remis après le suivant
        jsr del_raw
        lda cur
        jsr sel
        jsr after_cur
        jsr ins_raw
        ldx cur
        inx
        txa
        jmp sel
r       rts
.)
k_sback
.(
        lda cur
        beq r
        tax
        lda mflag,x
        pha
        lda mflag-1,x
        sta mflag,x
        pla
        sta mflag-1,x
        jsr cur_to_tmp          ; retiré, puis remis avant le précédent
        jsr del_raw
        ldx cur
        dex
        txa
        jsr sel
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr ins_raw
        lda cur
        jmp sel
r       rts
.)
; del_raw : retire le sprite courant (sans toucher à son rang ni aux
;   drapeaux) ; ins_raw : tmpspr inséré en ptr
del_raw
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr spr_len
        jsr mem_del
        lda #1
        sta modif
        lda #0
        sta undok
        rts
ins_raw
        lda ptr
        pha
        lda ptr+1
        pha
        lda #<tmpspr
        sta ptr
        lda #>tmpspr
        sta ptr+1
        jsr spr_len
        pla
        sta ptr+1
        pla
        sta ptr
        jsr mem_ins             ; (la place vient d'être rendue)
        lda #<tmpspr
        sta src
        lda #>tmpspr
        sta src+1
        jmp copy_to

; ---------------------------------------------------------------------
; Menu Dessin
; ---------------------------------------------------------------------
; xform : chaque point (gx, gy) reçoit celui de la copie d'annulation en
;   (sx, sy) calculé par la routine xf (A = sorte)
xform
.(
        sta vv
        jsr save_undo
        lda #<undobuf
        sta base
        lda #>undobuf
        sta base+1
        lda #0
        sta py2
ly      lda #0
        sta px2
lx      jsr xsrc                ; source dans gx, gy
        lda #<undobuf
        sta base
        lda #>undobuf
        sta base+1
        jsr pix_get
        lda px2
        sta gx
        lda py2
        sta gy
        jsr pix_set
        inc px2
        lda px2
        cmp ww
        bcc lx
        inc py2
        lda py2
        cmp hh
        bcc ly
        lda #1
        sta modif
        rts
.)

; xsrc : (px2, py2) -> source (gx, gy) selon vv : 0 miroir horizontal,
;   1 vertical, 2 quart de tour, 3-6 décalage gauche, droite, haut, bas
xsrc
.(
        lda px2
        sta gx
        lda py2
        sta gy
        ldx vv
        bne v1
        lda ww                  ; miroir horizontal : W-1-x
        sec
        sbc #1
        sbc px2
        sta gx
        rts
v1      dex
        bne v2
        lda hh                  ; miroir vertical : H-1-y
        sec
        sbc #1
        sbc py2
        sta gy
        rts
v2      dex
        bne v3
        lda py2                 ; quart de tour (carré) : (y, W-1-x)
        sta gx
        lda ww
        sec
        sbc #1
        sbc px2
        sta gy
        rts
v3      dex
        bne v4
        ldx px2                 ; décaler à gauche : x+1 (fait le tour)
        inx
        cpx ww
        bcc s3
        ldx #0
s3      stx gx
        rts
v4      dex
        bne v5
        ldx px2                 ; à droite : x-1
        bne s4
        ldx ww
s4      dex
        stx gx
        rts
v5      dex
        bne v6
        ldx py2                 ; en haut : y+1
        inx
        cpx hh
        bcc s5
        ldx #0
s5      stx gy
        rts
v6      ldx py2                 ; en bas : y-1
        bne s6
        ldx hh
s6      dex
        stx gy
        rts
.)

k_mirh  lda #0
        jmp xform
k_mirv  lda #1
        jmp xform
k_rot
.(
        lda ww                  ; carré en points seulement : 4 x 3
        cmp hh
        bne no
        lda #2
        jmp xform
no      lda #<m_rot
        ldy #>m_rot
        jmp set_msg
.)
k_shl   lda #3
        jmp xform
k_shr   lda #4
        jmp xform
k_shu   lda #5
        jmp xform
k_shd   lda #6
        jmp xform

; k_inv : le dessin inversé (genre 0 : la silhouette garde les points
;   allumés)
k_inv                           ; plein <-> masque (genre 1 : vide) ;
.(                              ;   le transparent reste
        jsr save_undo
        jsr cells
l       ldy #0
b       lda (ptr),y
        eor #$3F
        ldx genre
        bne n
        pha
        tya
        clc
        adc #8
        tay
        pla
        and (ptr),y             ; seulement dans la silhouette
        pha
        tya
        sec
        sbc #8
        tay
        pla
n       sta (ptr),y
        iny
        cpy #8
        bne b
        jsr next_cell
        bne l
        lda #1
        sta modif
        rts
.)

; k_sil : silhouette = dessin
k_sil
.(
        lda genre
        bne no
        jsr save_undo
        jsr cells
l       ldy #0
b       lda (ptr),y
        pha
        tya
        clc
        adc #8
        tay
        pla
        sta (ptr),y
        tya
        sec
        sbc #7
        tay
        cpy #8
        bne b
        jsr next_cell
        bne l
        lda #1
        sta modif
        rts
no      lda #<m_nomask
        ldy #>m_nomask
        jmp set_msg
.)

; cells : ptr = première case, cnt = nombre de cases ; next_cell : case
;   suivante, Z=1 après la dernière
cells
        lda spp
        clc
        adc #8
        sta ptr
        lda spp+1
        adc #0
        sta ptr+1
        lda sw
        ldx sh
        dex
        beq ce1
        sta tmpb
ce0     clc
        adc tmpb
        dex
        bne ce0
ce1     sta cnt
        rts
next_cell
        clc
        lda ptr
        adc cs
        sta ptr
        bcc nce
        inc ptr+1
nce     dec cnt
        rts

; k_font : dessins pris dans la police standard (codes consécutifs à
;   partir de celui demandé, une case chacun ; genre 0 : silhouette =
;   dessin)
k_font
.(
        lda #<q_code
        ldy #>q_code
        jsr ask
        bcs r
        jsr parse_num
        bcs bad
        cmp #32
        bcc bad
        cmp #128
        bcs bad
        sta kk
        jsr save_undo
        jsr cells
l       lda kk                  ; adresse du dessin : STDF + code * 8,
        jsr glyph_src           ;   ou la copie d'origine (codes pris
        ldy #0                  ;   par la grille)
c       lda (src),y
        sta (ptr),y
        ldx genre
        bne n
        pha
        tya
        clc
        adc #8
        tay
        pla
        sta (ptr),y
        tya
        sec
        sbc #8
        tay
n       iny
        cpy #8
        bne c
        inc kk
        lda kk
        cmp #128
        bcs e
        jsr next_cell
        bne l
e       lda #1
        sta modif
r       rts
bad     lda #<m_badnum
        ldy #>m_badnum
        jmp set_msg
.)

; glyph_src : A = code -> src = son dessin d'origine
glyph_src
.(
        ldx #11
l       cmp gcodes,x
        beq own
        dex
        bpl l
        sta src                 ; STDF + code * 8
        lda #0
        sta src+1
        asl src
        rol src+1
        asl src
        rol src+1
        asl src
        rol src+1
        clc
        lda src+1
        adc #>STDF
        sta src+1
        rts
own     txa                     ; gsave + rang * 8
        asl
        asl
        asl
        clc
        adc #<gsave
        sta src
        lda #>gsave
        adc #0
        sta src+1
        rts
.)

; ---------------------------------------------------------------------
; Menu Vue
; ---------------------------------------------------------------------
k_decor
.(
        ldx decor
        inx
        cpx #4
        bcc s
        ldx #0
s       stx decor
        txa                     ; nom du décor
        asl
        tax
        lda dnames,x
        ldy dnames+1,x
        jmp set_msg
.)

; k_anim : fait défiler dans l'aperçu les sprites de même taille dont le
;   nom commence pareil (sans les chiffres de la fin) ; une touche arrête
k_anim
.(
        jsr set_endp
        lda hexm
        beq a0
        lda #0
        sta hexm
        jsr render
a0      ldy #7                  ; préfixe : le nom sans ses chiffres finaux
p       lda (spp),y
        cmp #"0"
        bcc pe
        cmp #"9"+1
        bcs pe
        dey
        cpy #4
        bne p
pe      sty aa                  ; dernier octet du préfixe (3 à 7)
        ldx #0                  ; liste des sprites semblables
        stx gx
        lda #<(BUF+8)
        sta ptr2
        lda #>(BUF+8)
        sta ptr2+1
s       lda ptr2
        sta ptr
        lda ptr2+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        cmp sw
        bne nx
        iny
        lda (ptr),y
        cmp sh
        bne nx
        ldy #4
c       cpy aa
        beq c2
        bcs ok
c2      lda (ptr),y
        cmp (spp),y
        bne nx
        iny
        jmp c
ok      lda ptr                 ; gardé : son adresse
        ldx gx
        sta alist_lo,x
        lda ptr+1
        sta alist_hi,x
        inc gx
nx      jsr spr_len
        clc
        lda ptr2
        adc len
        sta ptr2
        lda ptr2+1
        adc len+1
        sta ptr2+1
        lda ptr2+1              ; fin du fichier ?
        cmp endp+1
        bcc s
        bne go
        lda ptr2
        cmp endp
        bcc s
go      lda #0
        sta cy
fr      ldx cy                  ; image suivante
        lda alist_lo,x
        sta ptr
        lda alist_hi,x
        sta ptr+1
        jsr prev_of
        lda SYS_TICKS
        clc
        adc #12
        sta jj
w       jsr B_CONST
        bne stop
        lda SYS_TICKS
        cmp jj
        bne w
        inc cy
        lda cy
        cmp gx
        bcc fr
        lda #0
        sta cy
        jmp fr
stop    jsr B_CONIN             ; la touche est prise
        rts
.)

; k_detour : chaque point transparent qui touche un point plein (8
;   voisins) devient masque : le sprite gagne un contour noir (genre 0)
k_detour
.(
        lda genre
        beq g
        lda #<m_nomask
        ldy #>m_nomask
        jmp set_msg
g       jsr save_undo
        lda #0
        sta py2
ly      lda #0
        sta px2
lx      lda #<undobuf           ; lu dans la copie, écrit dans le sprite
        sta base
        lda #>undobuf
        sta base+1
        lda px2
        sta gx
        lda py2
        sta gy
        jsr pix_get
        lda dd
        ora ss
        bne nx                  ; pas transparent
        lda #$FF                ; voisins : dy, dx de -1 à 1
        sta aa
vy      lda #$FF
        sta bb
vx      clc
        lda px2
        adc bb
        sta gx
        cmp ww                  ; -1 donne $FF : hors du sprite
        bcs vn
        clc
        lda py2
        adc aa
        sta gy
        cmp hh
        bcs vn
        jsr pix_get
        lda dd
        bne hit
vn      inc bb
        lda bb
        cmp #2
        bne vx
        inc aa
        lda aa
        cmp #2
        bne vy
        jmp nx
hit     lda px2
        sta gx
        lda py2
        sta gy
        lda #0
        sta dd
        lda #1
        sta ss
        jsr pix_set
nx      inc px2
        lda px2
        cmp ww
        bcs ny
        jmp lx
ny      inc py2
        lda py2
        cmp hh
        bcs fin
        jmp ly
fin     lda #1
        sta modif
        rts
.)

; endp : fin du fichier (BUF + fsize), pour k_anim
set_endp
        clc
        lda #<BUF
        adc fsize
        sta endp
        lda #>BUF
        adc fsize+1
        sta endp+1
        rts

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
render
        jsr set_endp
        jsr draw_grid
        lda hexm
        beq r1
        jsr draw_hex
        jmp draw_status
r1      jsr draw_list
        lda spp
        sta ptr
        lda spp+1
        sta ptr+1
        jsr prev_of
        jmp draw_status

; draw_grid : en-tête (ligne 1), numéros, grille ; une case lue par
;   caractère et par ligne de points, puis ses 6 points
draw_grid
.(
        ldx #1
        jsr row_ptr
        ldy #2
        lda #" "
        sta (scr),y
        ldx #0
h       lda ghead,x
        iny
        sta (scr),y
        inx
        cpx #24
        bne h
        lda #0
        sta rr                  ; ligne de la grille 0-23
lr      lda rr
        clc
        adc #GROW
        tax
        jsr row_ptr
        lda gtop                ; gy = gtop * 8 + rr
        asl
        asl
        asl
        clc
        adc rr
        sta gy
        ldx #" "                ; numéro de la ligne de caractères
        and #7
        cmp #3
        bne nl
        lda gy
        cmp hh
        bcs nl
        lsr
        lsr
        lsr
        clc
        adc #"1"
        tax
nl      txa
        ldy #2
        sta (scr),y
        lda #GCOL
        sta spos                ; colonne de l'écran
        lda #0
        sta cx
lc      lda cx                  ; dans le sprite ?
        cmp sw
        bcs blank
        lda gy
        cmp hh
        bcs blank
        lsr
        lsr
        lsr
        ldx sw
        jsr cell_off            ; A/X = décalage de la case
        clc
        adc spp
        sta ptr
        txa
        adc spp+1
        sta ptr+1
        lda gy
        and #7
        tay
        lda (ptr),y
        sta d0
        lda #0
        ldx genre
        bne s0
        tya
        clc
        adc #8
        tay
        lda (ptr),y
s0      sta sx1
        lda #$20
        sta bm                  ; bit du point
        lda #0
        sta kk                  ; point 0-5
lp      ldx #0
        lda d0
        and bm
        beq p1
        inx
p1      stx dd
        ldx #0
        lda sx1
        and bm
        beq p2
        inx
p2      stx ss
        jsr state
        asl                     ; état * 4 + traits
        asl
        ldx kk
        cpx #5
        bne x1
        ora #1
x1      tax
        lda gy
        and #7
        cmp #7
        txa
        bcc x2
        ora #2
x2      tax
        lda gcodes,x
        ldy spos
        sta (scr),y
        inc spos
        lsr bm
        inc kk
        lda kk
        cmp #6
        bne lp
        jmp nc
blank   ldy spos                ; hors du sprite : 6 blancs
        ldx #6
        lda #" "
b       sta (scr),y
        iny
        dex
        bne b
        sty spos
nc      inc cx
        lda cx
        cmp #4
        beq nr
        jmp lc
nr      inc rr
        lda rr
        cmp #24
        beq e
        jmp lr
e       rts
.)

; row_ptr : X = ligne -> scr
row_ptr lda row_lo,x
        sta scr
        lda row_hi,x
        sta scr+1
        rts

; pclear : colonnes 27-39 de la ligne X en blanc ; Y = PCOL au retour
pclear
        jsr row_ptr
        ldy #27
        lda #" "
pc1     sta (scr),y
        iny
        cpy #40
        bne pc1
        ldy #PCOL
        rts

; pputs : chaîne A/Y (0 à la fin) écrite en (scr), à partir de la colonne
;   spos ; 12 caractères au plus
pputs
.(
        sta src
        sty src+1
        ldy #0
l       lda (src),y
        beq r
        sty jj
        pha
        lda spos
        clc
        adc jj
        tay
        pla
        cpy #40
        bcs r
        sta (scr),y
        ldy jj
        iny
        bne l
r       rts
.)

; draw_list : nom du fichier, sprites, rang, genre, titre de l'aperçu
draw_list
.(
        ldx #1                  ; ligne 1 : NOM.EXT
        jsr pclear
        lda hasname
        bne nm
        lda #<m_noname
        ldy #>m_noname
        ldx #PCOL
        stx spos
        jsr pputs
        jmp lst
nm      ldx #1
n1      lda fcb_main,x
        and #$7F
        cmp #" "
        beq dot
        sta (scr),y
        iny
        inx
        cpx #9
        bne n1
dot     lda #"."
        sta (scr),y
        iny
        ldx #9
n2      lda fcb_main,x
        and #$7F
        cmp #" "
        beq lst
        sta (scr),y
        iny
        inx
        cpx #12
        bne n2
lst     lda ltop                ; lignes 2-13 : les sprites
        sta kk
        jsr spr_ptr
        lda #0
        sta rr
lr      lda rr
        clc
        adc #2
        tax
        jsr pclear
        lda kk
        cmp BUF+4
        bcc e0
        jmp nx
e0      ldx #" "                ; « >NOM. lxh S »
        lda kk
        cmp cur
        bne e1
        ldx #">"
e1      stx ent
        ldy #4
e2      lda (ptr),y
        sta ent-3,y
        iny
        cpy #8
        bne e2
        lda #" "
        sta ent+5
        sta ent+9
        sta ent+10
        lda #"x"
        sta ent+7
        ldy #0
        lda (ptr),y
        ora #"0"
        sta ent+6
        iny
        lda (ptr),y
        ora #"0"
        sta ent+8
        lda genre               ; S ou M (genre 0)
        bne e3
        ldx kk
        lda #"S"
        ldy mflag,x
        beq e4
        lda #"M"
e4      sta ent+10
e3      lda #0                  ; vidéo inverse : le courant, dans la
        sta tmpb                ;   sélection
        lda kk
        cmp cur
        bne e5
        lda zone
        beq e5
        lda #$80
        sta tmpb
e5      ldx #0
        ldy #PCOL
e6      lda ent,x
        ora tmpb
        sta (scr),y
        iny
        inx
        cpx #11
        bne e6
        jsr spr_len
        clc
        lda ptr
        adc len
        sta ptr
        lda ptr+1
        adc len+1
        sta ptr+1
        inc kk
nx      inc rr
        lda rr
        cmp #LROWS
        beq lend
        jmp lr
lend
        ldx #14
        jsr pclear
        ldx #15                 ; ligne 15 : rang / nombre
        jsr pclear
        ldx cur
        inx
        txa
        jsr pdec
        lda #"/"
        sta (scr),y
        iny
        lda BUF+4
        jsr pdec
        ldx #16                 ; ligne 16 : genre
        jsr pclear
        ldx #PCOL
        stx spos
        lda genre
        asl
        tax
        lda gnames,x
        ldy gnames+1,x
        jsr pputs
        ldx #17
        jsr pclear
        ldx #18                 ; ligne 18 : titre de l'aperçu
        jsr pclear
        ldx #PCOL
        stx spos
        lda #<m_real
        ldy #>m_real
        jsr pputs
        ldx #19
        jmp pclear
.)

; pdec : A (0-255) en décimal en (scr),y ; Y avance
pdec
.(
        ldx #0
        stx aa
        ldx #"0"-1
        sec
h       inx
        sbc #100
        bcs h
        adc #100
        cpx #"0"
        beq t
        pha
        txa
        sta (scr),y
        iny
        inc aa
        pla
t       ldx #"0"-1
        sec
d       inx
        sbc #10
        bcs d
        adc #10+"0"
        pha
        cpx #"0"
        bne o
        lda aa
        beq u
o       txa
        sta (scr),y
        iny
u       pla
        sta (scr),y
        iny
        rts
.)

; prev_of : aperçu du sprite en ptr (lignes 20-25, colonnes 28-33)
prev_of
.(
        ldy #0
        lda (ptr),y
        sta nw
        iny
        lda (ptr),y
        sta nh
        lda decor               ; le décor : code PCD
        asl
        asl
        asl
        tax
        ldy #0
d       lda dpat,x
        sta ALTF+PCD*8,y
        inx
        iny
        cpy #8
        bne d
        lda ptr                 ; cases du sprite : codes PC0...
        clc
        adc #8
        sta src
        lda ptr+1
        adc #0
        sta src+1
        lda #<(ALTF+PC0*8)
        sta dst
        lda #>(ALTF+PC0*8)
        sta dst+1
        lda decor               ; motif du décor, pour composer
        asl
        asl
        asl
        sta vv
        lda nw                  ; nombre de cases
        ldx nh
        dex
        beq c1
        sta tmpb
c0      clc
        adc tmpb
        dex
        bne c0
c1      sta cnt
        ldx cur                 ; mode du sprite affiché (k_anim : le
        lda mflag,x             ;   courant sert pour tous)
        sta mm
cl      ldy #0
rw      ldx genre
        bne g1
        tya                     ; dessin, silhouette
        pha
        lda (src),y
        sta dd
        tya
        clc
        adc #8
        tay
        lda (src),y
        sta ss
        pla
        tay
        tya
        clc
        adc vv
        tax
        lda mm
        bne mk
        lda ss                  ; S : (décor AND NOT silhouette) OR dessin
        eor #$FF
        and dpat,x
        ora dd
        jmp st
mk      lda dpat,x              ; M : décor OR silhouette OR dessin
        ora ss
        ora dd
        jmp st
g1      lda (src),y             ; genre 1 : le dessin seul
st      sta (dst),y
        iny
        cpy #8
        bne rw
        clc                     ; case suivante
        lda src
        adc cs
        sta src
        bcc s1
        inc src+1
s1      clc
        lda dst
        adc #8
        sta dst
        bcc s2
        inc dst+1
s2      dec cnt
        bne cl
        lda #6                  ; marges autour du sprite, en 6 x 6
        sec
        sbc nw
        lsr
        sta aa                  ; colonne de départ dans l'aperçu
        lda #6
        sec
        sbc nh
        lsr
        sta bb                  ; ligne de départ
        lda #0
        sta rr
        sta kk                  ; code suivant du sprite
lr      lda rr
        clc
        adc #PROW
        tax
        jsr row_ptr
        ldy #27
        lda #9                  ; jeu secondaire jusqu'à la colonne 33
        sta (scr),y
        lda #0
        sta cx
lc      lda genre               ; tuiles : le motif répété partout,
        beq lsp                 ;   case (cx mod nw, rr mod nh)
        lda rr
m1      cmp nh
        bcc m2
        sbc nh
        jmp m1
m2      tax
        lda cx
m3      cmp nw
        bcc m4
        sbc nw
        jmp m3
m4      cpx #0
        beq m6
m5      clc
        adc nw
        dex
        bne m5
m6      clc
        adc #PC0
        jmp pt
lsp     lda rr                  ; dans le sprite ?
        sec
        sbc bb
        bcc dc0
        cmp nh
        bcs dc0
        lda cx
        sec
        sbc aa
        bcc dc0
        cmp nw
        bcs dc0
        lda kk
        clc
        adc #PC0
        inc kk
        .byt $2C
dc0     lda #PCD
pt      pha
        lda cx
        clc
        adc #PCOL
        tay
        pla
        sta (scr),y
        inc cx
        lda cx
        cmp #6
        bne lc
        ldy #34                 ; retour au jeu standard
        lda #8
        sta (scr),y
        lda #" "
e       iny
        cpy #40
        bcs n
        sta (scr),y
        bne e
n       inc rr
        lda rr
        cmp #6
        beq x
        jmp lr
x       rts
.)

; draw_hex : en face de chaque ligne de points, ses octets (dessin en S,
;   silhouette en M)
draw_hex
.(
        ldx #1
        jsr pclear
        ldx #PCOL
        stx spos
        lda #<m_codes
        ldy #>m_codes
        jsr pputs
        ldy spos
        iny
        iny
        iny
        iny
        iny
        iny
        lda genre
        bne g
        lda #"S"
        ldx mm
        beq s
        lda #"M"
s       sta (scr),y
g       lda #0
        sta rr
lr      lda rr
        clc
        adc #GROW
        tax
        jsr pclear
        lda gtop
        asl
        asl
        asl
        clc
        adc rr
        sta gy
        cmp hh
        bcs nx
        lda #0
        sta cx
lc      lda cx                  ; octet de la case (cx, ligne)
        asl
        sta aa
        asl
        asl
        asl
        sta gx                  ; (cx * 6 : 8 n'importe, div6 le ramène)
        lda cx
        asl
        clc
        adc cx
        asl
        sta gx
        lda spp
        sta base
        lda spp+1
        sta base+1
        jsr pix_addr
        lda mm
        beq d
        tya
        clc
        adc #8
        tay
d       lda (ptr),y
        pha
        lda aa
        clc
        adc #PCOL
        tay
        pla
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda hexd,x
        sta (scr),y
        iny
        pla
        and #$0F
        tax
        lda hexd,x
        sta (scr),y
        inc cx
        lda cx
        cmp sw
        bne lc
nx      inc rr
        lda rr
        cmp #24
        bne lr
        rts
.)

; ---------------------------------------------------------------------
; Curseur (vidéo inverse, clignotant)
; ---------------------------------------------------------------------
cur_cell
        lda py
        sec
        sbc gtop
        sbc gtop
        sbc gtop
        sbc gtop
        sbc gtop
        sbc gtop
        sbc gtop
        sbc gtop
        clc
        adc #GROW
        tax
        jsr row_ptr
        lda px
        clc
        adc #GCOL
        tay
        rts

blink
.(
        lda zone
        bne r
        sec
        lda SYS_TICKS
        sbc blk
        lda SYS_TICKS+1
        sbc blk+1
        bmi r
        clc
        lda SYS_TICKS
        adc #15
        sta blk
        lda SYS_TICKS+1
        adc #0
        sta blk+1
        jsr cur_cell
        lda (scr),y
        eor #$80
        sta (scr),y
        lda curon
        eor #1
        sta curon
r       rts
.)

cur_off
.(
        lda curon
        beq r
        jsr cur_cell
        lda (scr),y
        eor #$80
        sta (scr),y
        lda #0
        sta curon
        jmp blk_now             ; réapparaît aussitôt après la touche
r       rts
.)

; blk_now : prochain clignotement tout de suite (échéance = l'heure
;   courante ; 0 ne va pas : SYS_TICKS passé $8000, la différence
;   serait négative pendant 11 minutes)
blk_now
        php
        sei
        lda SYS_TICKS
        sta blk
        lda SYS_TICKS+1
        sta blk+1
        plp
        rts

cur_hide
.(
        php
        sei
        lda #0
        sta CON_CUREN
        lda CON_CURVIS
        beq r
        ldx CON_CURY
        lda row_lo,x
        sta t0
        lda row_hi,x
        sta t0+1
        ldy CON_CURX
        lda (t0),y
        eor #$80
        sta (t0),y
        lda #0
        sta CON_CURVIS
r       plp
        rts
.)

; ---------------------------------------------------------------------
; Caractères de la grille : 3 états x (sans trait, à droite, en bas, les
; deux), dans la police standard ; dessins d'origine gardés (gsave)
; ---------------------------------------------------------------------
glyphs
.(
        ldx #0
l       stx kk
        lda gcodes,x            ; adresse dans la police
        jsr gaddr
        ldx kk                  ; copie d'origine
        txa
        asl
        asl
        asl
        tax
        ldy #0
s       lda (dst),y
        sta gsave,x
        inx
        iny
        cpy #8
        bne s
        ldx kk                  ; état et traits
        txa
        lsr
        lsr
        sta aa                  ; 0 plein, 1 vide, 2 grisé
        txa
        and #3
        sta bb                  ; bit 0 : à droite, bit 1 : en bas
        ldy #0
r       ldx aa
        lda #$3F
        cpx #0
        beq p
        lda #0
        cpx #1
        beq p
        tya                     ; grisé : damier clair
        and #3
        tax
        lda gris,x
p       sta tmpb
        lda bb                  ; trait à droite : bit 0 ; plein : éteint
        and #1
        beq nb
        lda tmpb
        ldx aa
        bne o1
        and #$3E
        .byt $2C
o1      ora #$01
        sta tmpb
nb      lda bb                  ; trait en bas : ligne 7
        and #2
        beq nr
        cpy #7
        bne nr
        lda #$3F
        ldx aa
        bne o2
        lda #0
o2      sta tmpb
nr      lda tmpb
        sta (dst),y
        iny
        cpy #8
        bne r
        ldx kk
        inx
        cpx #12
        bne l
        rts
.)
gris    .byt $2A,$00,$15,$00

; gaddr : A = code -> dst = STDF + code * 8
gaddr   sta dst
        lda #0
        sta dst+1
        asl dst
        rol dst+1
        asl dst
        rol dst+1
        asl dst
        rol dst+1
        clc
        lda dst+1
        adc #>STDF
        sta dst+1
        rts

; ---------------------------------------------------------------------
; Ligne d'état
; ---------------------------------------------------------------------
; draw_hint : ligne au-dessus de l'état, les touches de la zone
draw_hint
.(
        ldx #0                  ; sélection
        lda zone
        bne s
        ldx #2                  ; saisie, sprites
        lda genre
        beq s
        ldx #4                  ;   tuiles
s       lda hints,x
        sta src
        lda hints+1,x
        sta src+1
        ldy #0
c       lda (src),y
        beq f
        sta SCREEN+(STROW-1)*40+2,y
        iny
        cpy #WIDTH
        bcc c
        rts
f       lda #" "
        sta SCREEN+(STROW-1)*40+2,y
        iny
        cpy #WIDTH
        bcc f
        rts
.)

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
l       lda (src),y
        beq e
        sty jj
        ldy tmpb
        cpy #WIDTH
        bcs e
        sta stline,y
        inc tmpb
        ldy jj
        iny
        bne l
e       ldy tmpb
        rts
.)

; st_dec : A (0-99) en décimal en stline,y
st_dec
.(
        ldx #"0"-1
        sec
d       inx
        sbc #10
        bcs d
        adc #10+"0"
        cpx #"0"
        beq u
        pha
        txa
        sta stline,y
        iny
        pla
u       sta stline,y
        iny
        rts
.)

set_msg
        sta msgp
        sty msgp+1
        rts

; draw_status : message, ou position, case, état, crayon, zone, *
draw_status
.(
        jsr draw_hint
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
info    lda zone
        beq ed
        lda #<m_zsel            ; sélection : aide
        sta src
        lda #>m_zsel
        sta src+1
        ldy #0
        jsr st_puts
        jmp mo
ed      ldy #0                  ; x 7 y 12
        lda #"x"
        sta stline,y
        iny
        lda px
        jsr st_dec
        iny
        lda #"y"
        sta stline,y
        iny
        lda py
        jsr st_dec
        iny
        lda #<m_car             ; car 1,1
        sta src
        lda #>m_car
        sta src+1
        jsr st_puts
        ldx px
        lda div6,x
        clc
        adc #"1"
        sta stline,y
        iny
        lda #","
        sta stline,y
        iny
        lda py
        lsr
        lsr
        lsr
        clc
        adc #"1"
        sta stline,y
        iny
        iny
        sty spos                ; état du point
        jsr cur_pix
        jsr state
        asl
        tax
        lda genre
        bne sg1
        lda snames,x
        sta src
        lda snames+1,x
        sta src+1
        jmp sg2
sg1     lda snames1,x
        sta src
        lda snames1+1,x
        sta src+1
sg2
        ldy spos
        jsr st_puts
        iny
        lda pen
        beq mo
        lda #<m_pen
        sta src
        lda #>m_pen
        sta src+1
        jsr st_puts
mo      lda modif
        beq f
        lda #"*"
        sta stline+WIDTH-1
f       jmp st_flush
.)

; ---------------------------------------------------------------------
; Questions sur la ligne d'état
; ---------------------------------------------------------------------
; ask : question A/Y, saisie dans inbuf/inlen (majuscules). C=1 si ESC.
ask
.(
        sta askp
        sty askp+1
        lda #0
        sta inlen
rd      jsr st_clear
        lda askp
        sta src
        lda askp+1
        sta src+1
        ldy #0
        jsr st_puts
        sty spos
        ldx #0
il      cpx inlen
        beq ie
        lda inbuf,x
        sta stline,y
        iny
        inx
        bne il
ie      cpy #WIDTH
        bcs nc
        lda #$A0                ; curseur : espace en vidéo inverse
        sta stline,y
nc      jsr st_flush
key     jsr B_CONIN
        cmp #CR
        beq ok
        cmp #ESC
        beq esc
        cmp #$7F
        beq bs
        cmp #$08
        beq bs
        cmp #" "
        bcc key
        cmp #$7F
        bcs key
        jsr upc
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
        jmp rd
bs      lda inlen
        beq key
        dec inlen
        jmp rd
ok      ldx inlen
        lda #0
        sta inbuf,x
        clc
        rts
esc     sec
        rts
.)

; ask_yn : question A/Y, C=1 si la réponse est oui
ask_yn
.(
        sta src
        sty src+1
        jsr st_clear
        ldy #0
        jsr st_puts
        jsr st_flush
        jsr B_CONIN
        jsr upc
        cmp #K_YES
        beq y
        cmp #"Y"
        beq y
        clc
        rts
y       sec
        rts
.)

upc
        cmp #"a"
        bcc up_r
        cmp #"z"+1
        bcs up_r
        and #$DF
up_r    rts

; parse_num : inbuf -> A (0-255), C=1 si invalide
parse_num
.(
        lda #0
        sta tmpb
        ldx #0
        lda inbuf
        beq bad
l       lda inbuf,x
        beq ok
        sec
        sbc #"0"
        cmp #10
        bcs bad
        sta jj
        lda tmpb                ; * 10 + chiffre
        cmp #26
        bcs bad
        asl
        sta aa
        asl
        asl
        clc
        adc aa
        clc
        adc jj
        bcs bad
        sta tmpb
        inx
        bne l
ok      lda tmpb
        clc
        rts
bad     sec
        rts
.)

; ask_size : « 2x3 » -> nw, nh (1-4). C=1 si annulé
ask_size
.(
        lda #<q_size
        ldy #>q_size
        jsr ask
        bcs r
        lda inbuf
        sec
        sbc #"1"
        cmp #4
        bcs bad
        adc #1
        sta nw
        lda inbuf+1
        cmp #"X"
        bne bad
        lda inbuf+2
        sec
        sbc #"1"
        cmp #4
        bcs bad
        adc #1
        sta nh
        lda inbuf+3
        bne bad
        clc
r       rts
bad     lda #<m_badsize
        ldy #>m_badsize
        jsr set_msg
        sec
        rts
.)

; ask_name : 1 à 4 lettres ou chiffres -> inbuf+16..19 (espaces au bout)
ask_name
.(
        lda #<q_name
        ldy #>q_name
        jsr ask
        bcs r
        lda inlen
        beq bad
        cmp #5
        bcs bad
        ldx #0
l       lda inbuf,x
        beq pad
        cmp #"0"
        bcc bad
        cmp #"9"+1
        bcc ok
        cmp #"A"
        bcc bad
        cmp #"Z"+1
        bcs bad
ok      sta inbuf+16,x
        inx
        cpx #4
        bne l
        clc
        rts
pad     lda #" "
p       sta inbuf+16,x
        inx
        cpx #4
        bne p
        clc
r       rts
bad     lda #<m_badname
        ldy #>m_badname
        jsr set_msg
        sec
        rts
.)

; ---------------------------------------------------------------------
; Fichiers
; ---------------------------------------------------------------------
; new_file : A = genre ; un sprite vide (sprites : 2 x 2 SP01 ; tuiles :
;   1 x 1 CAR1)
new_file
.(
        sta genre
        tax
        lda #16
        cpx #0
        beq g
        lda #8
g       sta cs
        ldx #7
h       lda nhead,x
        sta BUF,x
        dex
        bpl h
        lda genre
        sta BUF+5
        ldx #7
s       lda nspr0,x
        ldy genre
        beq s1
        lda nspr1,x
s1      sta BUF+8,x
        dex
        bpl s
        ldx #0                  ; cases vides
        txa
z       sta BUF+16,x
        inx
        bne z
        lda #<(BUF+8)
        sta ptr
        lda #>(BUF+8)
        sta ptr+1
        jsr spr_len
        clc
        lda len
        adc #8
        sta fsize
        lda len+1
        adc #0
        sta fsize+1
        ldx #0
        txa
f       sta mflag,x
        inx
        bne f
        lda #0
        sta modif
        sta undok
        sta cur
        sta ltop
        sta gtop
        sta px
        sta py
        rts
.)
nhead   .asc "SPR",1,1,0,0,0
nspr0   .byt 2,2,0,0
        .asc "SP01"
nspr1   .byt 1,1,0,0
        .asc "CAR1"

; load_file : fcb_main -> BUF. C=0 : chargé ; C=1, A=1 : introuvable,
;   A=2 : pas un fichier .SPR (ou trop gros)
load_file
.(
        ldx #12
        lda #0
z       sta fcb_main,x
        inx
        cpx #36
        bne z
        ldx #F_OPEN
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #$FF
        bne op
        lda #1
        sec
        rts
op      lda #<BUF
        sta ptr
        lda #>BUF
        sta ptr+1
rd      lda ptr+1               ; place pour 128 octets ?
        cmp cap+1
        bcc ok
        jmp bad
ok      ldx #F_SETDMA
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #F_READ
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #0
        bne eof
        clc
        lda ptr
        adc #128
        sta ptr
        bcc rd
        inc ptr+1
        jmp rd
eof     jsr dma_def
        jmp chk
bad0    jmp bad
chk
        sec                     ; taille lue
        lda ptr
        sbc #<BUF
        sta fsl
        lda ptr+1
        sbc #>BUF
        sta fsl+1
        ldx #2                  ; en-tête : SPR, version 1, 1-255, genre
h       lda BUF,x
        cmp nhead,x
        bne bad0
        dex
        bpl h
        lda BUF+3
        cmp #1
        bne bad0
        lda BUF+4
        beq bad0
        lda BUF+5
        cmp #2
        bcs bad
        sta genre
        tax
        lda #16
        cpx #0
        beq g
        lda #8
g       sta cs
        lda #<(BUF+8)           ; les sprites, tailles 1-4, dans le fichier
        sta ptr
        lda #>(BUF+8)
        sta ptr+1
        lda BUF+4
        sta jj
sp      ldy #0
        lda (ptr),y
        sec
        sbc #1
        cmp #4
        bcs bad
        iny
        lda (ptr),y
        sec
        sbc #1
        cmp #4
        bcs bad
        jsr spr_len
        clc
        lda ptr
        adc len
        sta ptr
        lda ptr+1
        adc len+1
        sta ptr+1
        sec                     ; dans ce qui a été lu ?
        lda ptr
        sbc #<BUF
        sta fsize
        lda ptr+1
        sbc #>BUF
        sta fsize+1
        lda fsl
        cmp fsize
        lda fsl+1
        sbc fsize+1
        bcc bad
        dec jj
        bne sp
        lda #0
        sta modif
        sta undok
        sta cur
        sta ltop
        sta gtop
        sta px
        sta py
        ldx #0
        txa
f       sta mflag,x
        inx
        bne f
        clc
        rts
bad     jsr dma_def
        lda #2
        sec
        rts
.)

dma_def ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS

; save_file : écrit NOM.$$$ (BUF, complété par des 0 jusqu'à 128), puis
;   remplace NOM.SPR (comme EDIT)
save_file
.(
        clc                     ; zéros après la fin
        lda #<BUF
        adc fsize
        sta ptr
        lda #>BUF
        adc fsize+1
        sta ptr+1
        ldy #0
        tya
z       sta (ptr),y
        iny
        bpl z
        ldx #11                 ; fichier temporaire NOM.$$$
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
made    lda #<BUF
        sta ptr
        lda #>BUF
        sta ptr+1
        lda fsize               ; enregistrements : (fsize + 127) / 128
        clc
        adc #127
        sta cnt
        lda fsize+1
        adc #0
        sta cnt+1
        asl cnt
        rol cnt+1
        lda cnt+1
        sta cnt
wr      lda cnt
        beq closef
        ldx #F_SETDMA
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #F_WRITE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        cmp #0
        bne fail
        clc
        lda ptr
        adc #128
        sta ptr
        bcc w1
        inc ptr+1
w1      dec cnt
        jmp wr
closef  jsr dma_def
        ldx #F_CLOSE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        cmp #$FF
        beq fail
        ldx #12                 ; remplace l'ancien fichier
        lda #0
z2      sta fcb_main,x
        inx
        cpx #36
        bne z2
        ldx #F_DELETE
        lda #<fcb_main
        ldy #>fcb_main
        jsr BDOS
        cmp #$FE                ; protégé : gardé, NOM.$$$ effacé
        bne del_ok
        lda #<m_ro
        ldy #>m_ro
        bne abort
del_ok  ldx #15
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
        cmp #0
        beq ren_ok
        lda #<m_renf            ; (erreur disque : le fichier reste dans
        ldy #>m_renf            ;   NOM.$$$, qu'on ne perd pas)
        jmp set_msg
ren_ok  lda #0
        sta modif
        lda #<m_saved
        ldy #>m_saved
        jmp set_msg
fail    jsr dma_def
        lda #<m_dfull
        ldy #>m_dfull
abort   pha                     ; NOM.$$$ fermé puis effacé, message A/Y
        tya
        pha
        ldx #F_CLOSE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        jsr clr_tmp
        ldx #F_DELETE
        lda #<fcb_tmp
        ldy #>fcb_tmp
        jsr BDOS
        pla
        tay
        pla
        jmp set_msg
.)

clr_tmp
        ldx #12
        lda #0
ct1     sta fcb_tmp,x
        inx
        cpx #36
        bne ct1
        rts

; parse_name : inbuf -> fcb_new ([D:]NOM[.EXT], type SPR par défaut).
;   C=1 si invalide
parse_name
.(
        ldx #35
        lda #0
z       sta fcb_new,x
        dex
        bpl z
        ldx #11
        lda #" "
s       sta fcb_new,x
        dex
        bne s
        ldy #0
        lda inlen
        cmp #2
        bcc nod
        lda inbuf+1
        cmp #":"
        bne nod
        lda inbuf
        sec
        sbc #"@"
        beq bad
        cmp #5
        bcs bad
        sta fcb_new
        ldy #2
nod     ldx #1
nm      cpy inlen
        beq done
        lda inbuf,y
        iny
        cmp #"."
        beq ext
        jsr chk
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
        jsr chk
        bcs bad
        cpx #12
        bcs ex
        sta fcb_new,x
        inx
        bne ex
done    lda fcb_new+1
        cmp #" "
        beq bad
        lda fcb_new+9
        cmp #" "
        bne r
        ldx #2
t       lda t_spr,x
        sta fcb_new+9,x
        dex
        bpl t
r       clc
        rts
bad     sec
        rts
chk     cmp #" "+1
        bcc ck_b
        cmp #"*"
        beq ck_b
        cmp #"?"
        beq ck_b
        cmp #":"
        beq ck_b
        clc
        rts
ck_b    sec
        rts
.)

; ---------------------------------------------------------------------
; Menu Fichier
; ---------------------------------------------------------------------
; k_newf : nouveau fichier (genre demandé)
k_newf
.(
        jsr keep_ok
        bcc r
        lda #<q_genre
        ldy #>q_genre
        jsr ask_yn2
        bcs r
        jsr new_file
        lda #0
        sta hasname
        lda #0
        jsr sel
r       rts
.)

; ask_yn2 : question A/Y ; S -> A = 0, T -> A = 1, C=0 ; autre : C=1
ask_yn2
.(
        sta src
        sty src+1
        jsr st_clear
        ldy #0
        jsr st_puts
        jsr st_flush
        jsr B_CONIN
        jsr upc
        cmp #K_SPR
        beq s
        cmp #K_TIL
        beq t
        sec
        rts
s       lda #0
        clc
        rts
t       lda #1
        clc
        rts
.)

; keep_ok : C=1 si l'on peut abandonner le fichier en cours
keep_ok
        lda modif
        bne ko1
        sec
        rts
ko1     lda #<q_lose
        ldy #>q_lose
        jmp ask_yn

k_open
.(
        jsr keep_ok
        bcc r
        lda #<q_open
        ldy #>q_open
        jsr ask
        bcs r
        jsr parse_name
        bcs bad
        ldx #11
c       lda fcb_new,x
        sta fcb_main,x
        dex
        bpl c
        lda #1
        sta hasname
        jsr load_file
        bcc ok
        pha                     ; échec : fichier neuf, même nom
        lda #0
        jsr new_file
        pla
        cmp #1
        beq nf
        lda #<m_bad2
        ldy #>m_bad2
        jsr set_msg
        jmp ok
nf      lda #<m_new
        ldy #>m_new
        jsr set_msg
ok      lda #0
        jmp sel
bad     lda #<m_badfn
        ldy #>m_badfn
        jmp set_msg
r       rts
.)

k_save
        lda hasname
        bne ks1
        jmp k_saveas
ks1     jmp save_file

k_saveas
.(
        lda #<q_saveas
        ldy #>q_saveas
        jsr ask
        bcs r
        jsr parse_name
        bcs bad
        ldx #F_SETDMA           ; existe déjà ?
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        ldx #F_SFIRST
        lda #<fcb_new
        ldy #>fcb_new
        jsr BDOS
        cmp #$FF
        beq go
        lda #<q_repl
        ldy #>q_repl
        jsr ask_yn
        bcc r
go      ldx #11
c       lda fcb_new,x
        sta fcb_main,x
        dex
        bpl c
        lda #1
        sta hasname
        jmp save_file
bad     lda #<m_badfn
        ldy #>m_badfn
        jmp set_msg
r       rts
.)

k_quit
.(
        lda modif
        beq go
        lda #<q_quit
        ldy #>q_quit
        jsr ask_yn
        bcc r
go      ldx #7                  ; historique rendu
hr      lda hsave,x
        sta HIST,x
        dex
        bpl hr
        lda wassplit
        beq cls
        ldx #F_GFX              ; retour au mode SPLIT, image intacte
        lda #<gq_split
        ldy #>gq_split
        jsr BDOS
        jmp WBOOT
cls     ldx #F_CONOUT
        lda #$0C
        jsr BDOS
        jmp WBOOT               ; police et barre de menus du système
r       rts
.)

; ---------------------------------------------------------------------
; Menus
; ---------------------------------------------------------------------
es_bar  .byt 5
        .word mn_fic, mn_edi, mn_spr, mn_des, mn_vue

#include "edsprite.msg"        ; menus et messages (progs/msg/fr, en)

c_81    .byt $81,0
c_82    .byt $82,0
c_83    .byt $83,0
c_84    .byt $84,0
c_85    .byt $85,0
c_86    .byt $86,0
c_87    .byt $87,0
c_88    .byt $88,0
c_89    .byt $89,0
c_8a    .byt $8A,0
c_8b    .byt $8B,0
c_8c    .byt $8C,0
c_8d    .byt $8D,0
c_8e    .byt $8E,0
c_8f    .byt $8F,0
c_90    .byt $90,0
c_91    .byt $91,0
c_92    .byt $92,0
c_93    .byt $93,0
c_94    .byt $94,0
c_95    .byt $95,0
c_96    .byt $96,0
c_97    .byt $97,0
c_98    .byt $98,0
c_99    .byt $99,0
c_9a    .byt $9A,0
c_9b    .byt $9B,0
c_9c    .byt $9C,0
c_9d    .byt $9D,0
c_9e    .byt $9E,0
c_9f    .byt $9F,0
c_a0    .byt $A0,0
c_a1    .byt $A1,0

gq_get   .byt G_GETMODE,0,0,0,0,0
gq_text  .byt G_MODE,0,0,0,0,0
gq_split .byt G_MODE,2,0,0,0,0

; ---------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------
hexd    .asc "0123456789ABCDEF"
ghead   .asc "  1  :  2  :  3  :  4  :"
; codes de la grille : plein, vide, grisé ; chacun sans trait, trait à
; droite, en bas, les deux
gcodes  .byt 64,93,123,126, 91,95,124,127, 92,96,125,35
; décors de l'aperçu : vide, damier, briques, herbe
dpat    .byt 0,0,0,0,0,0,0,0
        .byt $2A,$00,$15,$00,$2A,$00,$15,$00
        .byt $3F,$04,$04,$04,$3F,$20,$20,$20
        .byt $00,$08,$2A,$1C,$00,$01,$15,$0E
; colonne de caractère (x / 6), point dans le caractère (x mod 6), dernier
; point du caractère, masque du point (bit 5 à gauche)
div6    .byt 0,0,0,0,0,0,1,1,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,3
mod6    .byt 0,1,2,3,4,5,0,1,2,3,4,5,0,1,2,3,4,5,0,1,2,3,4,5
end6    .byt 5,5,5,5,5,5,11,11,11,11,11,11,17,17,17,17,17,17,23,23,23,23,23,23
bitm    .byt $20,$10,$08,$04,$02,$01,$20,$10,$08,$04,$02,$01
        .byt $20,$10,$08,$04,$02,$01,$20,$10,$08,$04,$02,$01

; ---------------------------------------------------------------------
; Variables et tampons, après le programme (pas dans le fichier .COM)
; ---------------------------------------------------------------------
fin_prog
px2     = fin_prog
py2     = px2+1
endp    = py2+1         ; 2 octets
ent     = endp+2        ; 11 octets
row_lo  = ent+11
row_hi  = row_lo+28
inbuf   = row_hi+28     ; 24 octets
stline  = inbuf+24
fcb_main = stline+WIDTH
fcb_tmp = fcb_main+36
fcb_new = fcb_tmp+36
fcb_ren = fcb_new+36    ; 32 octets
gsave   = fcb_ren+32    ; 96 octets
alist_lo = gsave+96
alist_hi = alist_lo+256
mflag   = alist_hi+256  ; 257 octets
undobuf = mflag+257
clipbuf = undobuf+MAXSPR
tmpspr  = clipbuf+MAXSPR
hsave   = tmpspr+MAXSPR ; 8 octets
BUF     = (hsave+8+255)/256*256   ; le fichier : BUF à BUF+fsize
