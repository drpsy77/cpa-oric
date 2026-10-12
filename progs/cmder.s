; =====================================================================
;  CMDER.COM — gestionnaire de fichiers en plein écran (version 1)
;
;  CMDER [d:][afn]    liste du lecteur d: (courant par défaut), filtre
;                     afn déjà posé (CMDER B:*.COM)
;
;  Une disquette, en plein écran : liste triable (ordre du répertoire,
;  nom, type, taille), filtre, marquage, et les opérations Voir,
;  Copier, Déplacer, Renommer, Effacer, Attributs, tailles exactes.
;  Les opérations portent sur les fichiers marqués, ou sur le fichier
;  sous le curseur s'il n'y a aucune marque.
;
;  Copie avec un seul lecteur (destination = le lecteur de la liste,
;  sans autre nom) : les fichiers passent par un tampon (le reste de la
;  TPA), et les disquettes SOURCE et DESTINATION sont demandées tour à
;  tour. Avant d'écrire, CMDER vérifie une empreinte du répertoire de
;  chaque disquette (somme de contrôle de ses entrées), pour ne jamais
;  écrire sur la mauvaise. Le tampon du BDOS est vidé (fonction 13)
;  avant chaque échange ; un fichier en cours est fermé (point d'étape)
;  avant de quitter la destination, puis repris au retour.
;
;  Écran : ligne 0 barre de menus (FUNCT), 1 en-tête, 2 titres des
;  colonnes, 3-24 liste (22 fichiers), 25 informations, 26 messages et
;  questions, 27 aide. Les menus « tapent » un code $81-$98 traité comme
;  une touche (comme EDIT). Spécification : docs/spec-cmder.md.
; =====================================================================

#include "cpa.inc"

NMAX    = 128           ; entrées du répertoire au plus
ESZ     = 24            ; taille d'une entrée de la table
E_ATTR  = 11            ; bit 7 : R/O, bit 6 : SYS
E_RECS  = 12            ; enregistrements (2 octets)
E_BLKS  = 14            ; blocs de 2 Ko
E_RANK  = 15            ; rang dans le répertoire (ordre sur le disque)
E_SIZE  = 16            ; taille affichée (3 octets)
E_FLAG  = 19
E_GEN   = 20            ; genre (index dans gname)
FL_MARK = 1
FL_EXACT = 2            ; taille exacte (^Z retirés) connue
FL_DEL  = 4             ; original à effacer (Déplacer)
FL_SKIP = 8             ; fichier sauté pendant une copie
NBLK    = 168           ; blocs de données (comme STAT)
W       = 37            ; colonnes utilisées (2 à 38)
R_HDR   = 1
R_COL   = 2
R_LIST  = 3
NROWS   = 22
R_INFO  = 25
R_MSG   = 26
R_HELP  = 27
MAXIN   = 20            ; longueur d'une saisie
NCH     = 32            ; tranches dans le tampon de copie

; --- page zéro ---
ep      = $10           ; entrée de la table (2)
ep2     = $12           ; seconde entrée (comparaisons) (2)
scr     = $14           ; écran (2)
sp      = $16           ; chaîne (2)
bp      = $18           ; tampon de copie (2)
pp      = $1A           ; modèle de nom (2)
num     = $1C           ; nombre (3)
t0      = $1F
t1      = $20
t2      = $21
vi      = $22           ; boucles
vj      = $23
vk      = $24
cnt     = $25           ; entrées dans la table
nvis    = $26           ; entrées visibles
cur     = $27           ; curseur (index visible)
top     = $28           ; première ligne affichée
drv     = $29           ; lecteur de la liste (1 = A:)
skey    = $2A           ; tri : 1 disque, 2 nom, 3 type, 4 taille
srev    = $2B           ; 1 = ordre inverse
hides   = $2C           ; 1 = fichiers SYS cachés
nmark   = $2D
used    = $2E           ; blocs occupés
dok     = $2F           ; 1 = lecteur lisible
msgp    = $30           ; message de la ligne 26 (2 ; poids fort 0 = aucun)
inlen   = $32
lx      = $33           ; position dans lbuf
ly      = $34
dlen    = $35
nz      = $36
inv     = $37           ; $80 = ligne du curseur
sepf    = $38           ; 1 = espace des milliers
nrec    = $39           ; (2)
ci      = $3B           ; tranche en cours
vx      = $3C           ; Voir : colonne, ligne
vy      = $3D
vrec    = $3E           ; Voir : index dans l'enregistrement
vquit   = $3F
addf    = $40           ; 1 = dir_fp remplit la table
fp0     = $41           ; empreinte (3)
fps     = $44           ; empreinte de la source (3)
fpd     = $47           ; empreinte de la destination (3)
fpok    = $4A
havd    = $4B
retry   = $4C
cei     = $4D           ; entrée sous le curseur (rebuild_keep)
keepc   = $4E           ; 0 = curname à retrouver
nmk     = $4F
ntg     = $50           ; fichiers visés
rd_k    = $51           ; copie : fichier en lecture
rd_open = $52
wr_open = $53
stopf   = $54
ncp     = $55
nro     = $56
nerr    = $57
rall    = $58           ; 1 = remplacer tout
cur_in  = $59           ; un seul lecteur : 0 source en place, 1 destination
single  = $5A
mvf     = $5B           ; 1 = Déplacer
named   = $5C           ; 1 = la copie a un autre nom (cname)
cdst    = $5D           ; lecteur de destination (1 = A:)
nch     = $5E
first   = $5F
askp    = $60           ; (2)
errm    = $62           ; message d'arrêt (2 ; poids fort 0 = aucun)
tot     = $64           ; total des marques (3)
pfl     = $67           ; parse : bit 0 lecteur, 1 nom, 2 jokers, 3 point
kk      = $68
rel     = $69
bufpg   = $6A           ; première page du tampon de copie
wasx    = $6B

        *= $0500

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
start
.(
        cld
        ldx #F_GFX              ; lancé depuis le mode SPLIT : texte
        lda #<gq_get
        ldy #>gq_get
        jsr BDOS
        cmp #0
        beq txt
        ldx #F_GFX
        lda #<gq_text
        ldy #>gq_text
        jsr BDOS
txt     lda FCB1                ; lecteur donné, sinon le courant
        bne hasd
        ldx #F_CURDSK
        jsr BDOS
        clc
        adc #1
hasd    sta drv
        ldx #10                 ; filtre donné (CMDER B:*.COM), sinon tout
        lda FCB1+1
        cmp #" "
        bne pf
        lda #"?"
fa      sta fpat,x
        dex
        bpl fa
        bmi fdone
pf      lda FCB1+1,x
        sta fpat,x
        dex
        bpl pf
fdone   lda #>bufs              ; tampon de copie : page suivant la table
        clc
        adc #1
        sta bufpg
        lda #2                  ; tri par nom
        sta skey
        lda #0
        sta srev
        sta hides
        sta msgp+1
        lda #<bar
        ldy #>bar
        jsr B_MENUBAR
        ldx #F_CONOUT           ; efface l'écran
        lda #$0C
        jsr BDOS
        jsr cur_off
        jsr reload
.)
main
        jsr B_CONST             ; d'autres touches attendent : on
        bne getk                ; n'affiche qu'à la fin de la rafale
        jsr draw
getk    jsr B_CONIN
        sta kk
        lda #0                  ; une touche efface le message
        sta msgp+1
        lda kk
        jsr dispatch
        jmp main

; dispatch : A = touche ou code de menu
dispatch
.(
        cmp #"a"
        bcc nu
        cmp #"z"+1
        bcs nu
        and #$DF
nu      ldx #0
lp      ldy ktab,x
        beq end
        cmp ktab,x
        beq go
        inx
        inx
        inx
        bne lp
go      lda ktab+2,x
        pha
        lda ktab+1,x
        pha
        rts
end     cmp #"A"
        bcc rt
        cmp #"Z"+1
        bcs rt
        jmp k_jump
rt      rts
.)

; touche, adresse - 1
ktab    .byt 11
        .word k_up-1
        .byt 10
        .word k_down-1
        .byt 8
        .word k_pgup-1
        .byt 9
        .word k_pgdn-1
        .byt "<"
        .word k_first-1
        .byt ">"
        .word k_last-1
        .byt " "
        .word k_mark-1
        .byt "+"
        .word k_plus-1
        .byt "-"
        .word k_minus-1
        .byt "*"
        .word k_inv-1
        .byt "1"
        .word k_s1-1
        .byt "2"
        .word k_s2-1
        .byt "3"
        .word k_s3-1
        .byt "4"
        .word k_s4-1
        .byt "/"
        .word k_filter-1
        .byt 13
        .word k_view-1
        .byt $7F
        .word k_del-1
        .byt 3
        .word k_copy-1
        .byt 4
        .word k_move-1
        .byt 14
        .word k_ren-1
        .byt 1
        .word k_attr-1
        .byt "?"
        .word k_info-1
        .byt 5
        .word k_exact-1
        .byt 12
        .word k_drive-1
        .byt 18
        .word k_reload-1
        .byt 27
        .word k_quit-1
        .byt $81
        .word k_view-1
        .byt $82
        .word k_copy-1
        .byt $83
        .word k_move-1
        .byt $84
        .word k_ren-1
        .byt $85
        .word k_del-1
        .byt $86
        .word k_attr-1
        .byt $87
        .word k_info-1
        .byt $88
        .word k_drive-1
        .byt $89
        .word k_reload-1
        .byt $8A
        .word k_quit-1
        .byt $8B
        .word k_mark-1
        .byt $8C
        .word k_plus-1
        .byt $8D
        .word k_minus-1
        .byt $8E
        .word k_inv-1
        .byt $8F
        .word k_all-1
        .byt $90
        .word k_nomark-1
        .byt $91
        .word k_s1-1
        .byt $92
        .word k_s2-1
        .byt $93
        .word k_s3-1
        .byt $94
        .word k_s4-1
        .byt $95
        .word k_filter-1
        .byt $96
        .word k_nofilt-1
        .byt $97
        .word k_sys-1
        .byt $98
        .word k_exact-1
        .byt 0

; ---------------------------------------------------------------------
; Déplacements
; ---------------------------------------------------------------------
k_up
        lda cur
        beq ku_r
        dec cur
        jmp clamp
ku_r    rts

k_down
        ldx cur
        inx
        cpx nvis
        bcs kd_r
        stx cur
        jmp clamp
kd_r    rts

k_first
        lda #0
        sta cur
        jmp clamp

k_last
        ldx nvis
        beq kl_r
        dex
        stx cur
        jmp clamp
kl_r    rts

k_pgup
.(
        lda cur
        sec
        sbc top
        sta rel
        lda cur
        sec
        sbc #NROWS
        bcs ok
        lda #0
ok      jmp set_rel
.)

k_pgdn
.(
        lda nvis
        beq rt
        lda cur
        sec
        sbc top
        sta rel
        lda cur
        clc
        adc #NROWS
        bcs last
        cmp nvis
        bcc ok
last    ldx nvis
        dex
        txa
ok      jmp set_rel
rt      rts
.)

; set_rel : curseur = A, à la même ligne de l'écran (rel) si possible
set_rel
.(
        sta cur
        sec
        sbc rel
        bcs t1ok
        lda #0
t1ok    sta top
        lda nvis                ; pas de lignes vides en bas
        cmp #NROWS+1
        bcc cl
        sec
        sbc #NROWS
        cmp top
        bcs cl
        sta top
cl      jmp clamp
.)

; k_jump : A = lettre ; fichier suivant dont le nom commence par elle
k_jump
.(
        sta t0
        lda nvis
        beq rt
        lda cur
        sta t1
lp      inc t1
        lda t1
        cmp nvis
        bcc c
        lda #0
        sta t1
c       lda t1
        cmp cur
        beq rt
        jsr vis_ptr
        ldy #0
        lda (ep),y
        cmp t0
        bne lp
        lda t1
        sta cur
        jmp clamp
rt      rts
.)

; clamp : curseur dans la liste, et visible
clamp
.(
        lda nvis
        beq z
        lda cur
        cmp nvis
        bcc c1
        ldx nvis
        dex
        stx cur
c1      lda cur
        cmp top
        bcs c2
        sta top
c2      lda top
        clc
        adc #NROWS
        cmp cur
        beq dn
        bcs rt
dn      lda cur
        sec
        sbc #NROWS-1
        sta top
rt      rts
z       lda #0
        sta cur
        sta top
        rts
.)

; ---------------------------------------------------------------------
; Marquage
; ---------------------------------------------------------------------
k_mark
        lda nvis
        beq km_r
        lda cur
        jsr vis_ptr
        ldy #E_FLAG
        lda (ep),y
        eor #FL_MARK
        sta (ep),y
        jmp k_down
km_r    rts

k_all   lda #1
        .byt $2C
k_nomark
        lda #0
        .byt $2C
k_inv   lda #2
        sta t2                  ; 0 ôte, 1 marque, 2 inverse
.(
        lda #0
        sta vi
lp      lda vi
        cmp nvis
        beq rt
        jsr vis_ptr
        jsr mark_op
        inc vi
        bne lp
rt      rts
.)

; mark_op : marque de l'entrée ep selon t2 (0 ôte, 1 pose, 2 inverse)
mark_op
.(
        ldy #E_FLAG
        lda (ep),y
        ldx t2
        beq off
        dex
        beq on
        eor #FL_MARK
        jmp st
off     and #$FF-FL_MARK
        jmp st
on      ora #FL_MARK
st      sta (ep),y
        rts
.)

k_plus  lda #1
        ldx #<m_markq
        ldy #>m_markq
        bne kpm
k_minus lda #0
        ldx #<m_unmq
        ldy #>m_unmq
kpm
.(
        sta t2
        stx askp
        sty askp+1
        lda #"*"                ; proposé : *.*
        sta inbuf
        sta inbuf+2
        lda #"."
        sta inbuf+1
        lda #3
        sta inlen
        lda askp
        ldy askp+1
        jsr ask
        bcs rt
        jsr parse_pat
        bcs rt
        lda #<pfcb+1
        sta pp
        lda #>pfcb+1
        sta pp+1
        lda #0
        sta vi
lp      lda vi
        cmp nvis
        beq rt
        jsr vis_ptr
        jsr match
        bne nx
        jsr mark_op
nx      inc vi
        bne lp
rt      rts
.)

; parse_pat : saisie -> modèle en pfcb+1 (vide : tout ; sans point :
; type quelconque). C=1 si incorrect (message posé)
parse_pat
.(
        jsr parse
        bcs bad
        lda pfl
        and #2
        bne hn
        ldx #8                  ; rien : *.*
        lda #"?"
q1      sta pfcb,x
        dex
        bne q1
hn      lda pfl
        and #8
        bne ok
        ldx #11                 ; sans point : type quelconque
        lda #"?"
q2      sta pfcb,x
        dex
        cpx #8
        bne q2
ok      clc
        rts
bad     jmp bad_name
.)

bad_name
        lda #<m_bad
        ldy #>m_bad
        jsr set_msg
        sec
        rts

; ---------------------------------------------------------------------
; Tri et filtre
; ---------------------------------------------------------------------
k_s1    lda #1
        .byt $2C
k_s2    lda #2
        .byt $2C
k_s3    lda #3
        .byt $2C
k_s4    lda #4
.(
        cmp skey
        bne nw
        lda srev                ; même tri : ordre inverse
        eor #1
        sta srev
        jmp rebuild_keep
nw      sta skey
        lda #0
        sta srev
        jmp rebuild_keep
.)

k_filter
.(
        lda #0
        sta lx
        lda #<fpat
        ldy #>fpat
        jsr lb_pat              ; filtre actuel proposé
        jsr lb_to_in
        lda #<m_filtq
        ldy #>m_filtq
        jsr ask
        bcs rt
        jsr parse_pat
        bcs rt
        ldx #10
cp      lda pfcb+1,x
        sta fpat,x
        dex
        bpl cp
        lda pfl                 ; B:*.COM : change aussi de lecteur
        and #1
        beq kp
        lda pfcb
        sta drv
        jmp reload
kp      jmp rebuild_keep
rt      rts
.)

k_nofilt
.(
        ldx #10
        lda #"?"
q       sta fpat,x
        dex
        bpl q
        jmp rebuild_keep
.)

k_sys
.(
        lda hides
        eor #1
        sta hides
        ldx #10                 ; libellé du menu
        tay
        beq show
cp1     lda s_show,x
        sta it_sys,x
        dex
        bpl cp1
        jmp rebuild_keep
show
cp2     lda s_hide,x
        sta it_sys,x
        dex
        bpl cp2
        jmp rebuild_keep
.)

; rebuild_keep : liste visible refaite, curseur gardé sur le même fichier
rebuild_keep
.(
        lda #$FF
        sta cei
        lda nvis
        beq n
        ldx cur
        lda vis,x
        sta cei
n       jsr rebuild
        lda cei
        bmi rt
        jsr find_vis
rt      jmp clamp
.)

; find_vis : A = index de la table -> cur (s'il est visible)
find_vis
.(
        ldx #0
lp      cpx nvis
        beq rt
        cmp vis,x
        beq fy
        inx
        bne lp
fy      stx cur
rt      rts
.)

; rebuild : liste visible (filtre, SYS cachés) puis tri ; les fichiers
; cachés perdent leur marque
rebuild
.(
        lda #<fpat
        sta pp
        lda #>fpat
        sta pp+1
        lda #0
        sta nvis
        sta vi
lp      lda vi
        cmp cnt
        beq srt
        jsr ent_ptr
        jsr match
        bne hide
        lda hides
        beq show
        ldy #E_ATTR
        lda (ep),y
        and #$40
        bne hide
show    ldx nvis
        lda vi
        sta vis,x
        inc nvis
        jmp nx
hide    ldy #E_FLAG
        lda (ep),y
        and #$FF-FL_MARK
        sta (ep),y
nx      inc vi
        bne lp
srt     jsr sort
        jmp clamp
.)

; match : Z=1 si le nom de l'entrée ep correspond au modèle (pp, 11 o.)
match
.(
        ldy #10
lp      lda (pp),y
        cmp #"?"
        beq nx
        cmp (ep),y
        bne rt
nx      dey
        bpl lp
        lda #0
rt      rts
.)

; sort : tri par insertion de vis[0..nvis-1]
sort
.(
        lda #1
        sta vi
outer   lda vi
        cmp nvis
        bcs rt
        tax
        lda vis,x
        sta vk                  ; élément à placer
        stx vj
inner   ldx vj
        beq put
        lda vis-1,x
        jsr ent_ptr
        lda ep
        sta ep2
        lda ep+1
        sta ep2+1
        lda vk
        jsr ent_ptr
        jsr cmp_ent
        bcc put
        ldx vj
        lda vis-1,x
        sta vis,x
        dec vj
        jmp inner
put     ldx vj
        lda vk
        sta vis,x
        inc vi
        bne outer
rt      rts
.)

; cmp_ent : C=1 si l'entrée ep2 doit venir après l'entrée ep
cmp_ent
.(
        ldx skey
        lda okey-1,x
        sta t0                  ; début des octets de la clé
        lda nprim-1,x
        sta t1                  ; octets de la clé principale
        ldx t0
lp      ldy otab,x
        bmi eq
        lda (ep2),y
        cmp (ep),y
        bne df
        inx
        bne lp
eq      clc
        rts
df      lda #0                  ; A = 1 si ep2 > ep
        rol
        sta t2
        txa                     ; ordre inverse : clé principale seulement
        sec                     ; (à égalité, les noms restent de A à Z)
        sbc t0
        cmp t1
        lda t2
        bcs nr
        eor srev
nr      lsr
        rts
.)
nprim   .byt 1,11,3,3
okey    .byt o1-otab,o2-otab,o3-otab,o4-otab
otab
o1      .byt E_RANK,$FF
o2      .byt 0,1,2,3,4,5,6,7,8,9,10,$FF
o3      .byt 8,9,10,0,1,2,3,4,5,6,7,$FF
o4      .byt E_SIZE+2,E_SIZE+1,E_SIZE,0,1,2,3,4,5,6,7,8,9,10,$FF

; ---------------------------------------------------------------------
; Table des fichiers
; ---------------------------------------------------------------------
; ent_ptr : A = index -> ep = ftab + 24 * A (Y conservé)
ent_ptr
        sta ep
        lda #0
        sta ep+1
        asl ep
        rol ep+1
        asl ep
        rol ep+1
        asl ep
        rol ep+1                ; x 8
        lda ep
        ldx ep+1
        asl ep
        rol ep+1                ; x 16
        clc
        adc ep
        sta ep
        txa
        adc ep+1
        sta ep+1                ; x 24
        lda ep
        clc
        adc #<ftab
        sta ep
        lda ep+1
        adc #>ftab
        sta ep+1
        rts

; vis_ptr : A = index visible -> ep
vis_ptr
        tax
        lda vis,x
        jmp ent_ptr

; reload : lit le répertoire, curseur en haut
reload
        lda #0
        sta cur
        sta top
        jsr load_dir
        jmp rebuild

; reload_keep : relit le répertoire en gardant les marques et le
; curseur (par les noms)
reload_keep
.(
        lda #$FF
        sta keepc
        lda nvis
        beq nc
        lda cur
        jsr vis_ptr
        ldy #10
c       lda (ep),y
        sta curname,y
        dey
        bpl c
        lda #0
        sta keepc
nc
.)
reload_marks
.(
        lda #<bufs              ; noms marqués -> bufs (11 octets chacun)
        sta bp
        lda #>bufs
        sta bp+1
        lda #0
        sta nmk
        sta vi
lp      lda vi
        cmp cnt
        beq ld
        jsr ent_ptr
        ldy #E_FLAG
        lda (ep),y
        and #FL_MARK
        beq nx
        ldy #10
c       lda (ep),y
        sta (bp),y
        dey
        bpl c
        jsr bp_add11
        inc nmk
nx      inc vi
        bne lp
ld      jsr load_dir
        lda #<bufs
        sta pp
        lda #>bufs
        sta pp+1
        lda #0
        sta vj
rm      lda vj
        cmp nmk
        beq rb
        jsr find_name
        bcs rn
        jsr ent_ptr
        ldy #E_FLAG
        lda (ep),y
        ora #FL_MARK
        sta (ep),y
rn      lda pp
        clc
        adc #11
        sta pp
        bcc r1
        inc pp+1
r1      inc vj
        bne rm
rb      jsr rebuild
        lda keepc
        bne rt
        lda #<curname
        sta pp
        lda #>curname
        sta pp+1
        jsr find_name
        bcs rt
        jsr find_vis
rt      jmp clamp
.)

bp_add11
        lda bp
        clc
        adc #11
        sta bp
        bcc ba_r
        inc bp+1
ba_r    rts

bp_add128
        lda bp
        eor #$80
        sta bp
        bne bb_r
        inc bp+1
bb_r    rts

; find_name : nom de 11 octets en (pp) -> C=0, A = index s'il existe
find_name
.(
        lda #0
        sta vk
lp      lda vk
        cmp cnt
        beq nf
        jsr ent_ptr
        ldy #10
c       lda (ep),y
        cmp (pp),y
        bne nx
        dey
        bpl c
        lda vk
        clc
        rts
nx      inc vk
        bne lp
nf      sec
        rts
.)

; load_dir : table des fichiers du lecteur drv
load_dir
.(
        lda #0
        sta cnt
        sta used
        lda #1
        sta addf
        lda drv
        jsr dir_fp
        lda #0
        sta addf
        rol                     ; C=1 : illisible
        eor #1
        sta dok
        lda #0                  ; tailles (enreg. x 128) et genres
        sta vi
lp      lda vi
        cmp cnt
        beq rt
        jsr ent_ptr
        ldy #E_RECS+1
        lda (ep),y
        lsr
        ldy #E_SIZE+2
        sta (ep),y
        ldy #E_RECS
        lda (ep),y
        ror
        ldy #E_SIZE+1
        sta (ep),y
        lda #0
        ror
        ldy #E_SIZE
        sta (ep),y
        jsr genre
        inc vi
        bne lp
rt      rts
.)

; dir_fp : A = lecteur (1-4). Parcourt le répertoire (fonctions 17/18,
; tous les extents) : empreinte fp0-fp2 (sommes de contrôle et nombre
; d'entrées) ; si addf, remplit la table. C=1 si le lecteur est illisible
dir_fp
.(
        sta tfcb
        sta wasx
        jsr set_dma0
        ldx #12
        lda #"?"
q       sta tfcb,x
        dex
        bne q
        lda #0
        sta fp0
        sta fp0+1
        sta fp0+2
        ldx #F_SFIRST
        jsr bdos_t
lp      cmp #$FF
        beq d
        inc fp0+2
        ldy #31
s       lda DEF_DMA,y
        clc
        adc fp0
        sta fp0
        clc
        adc fp0+1
        sta fp0+1
        dey
        bpl s
        lda addf
        beq nx
        jsr add_ent
nx      ldx #F_SNEXT
        jsr bdos_t
        jmp lp
d       lda wasx
.)
; drv_read : A = lecteur (1-4) -> C=0 s'il a été lu (fonction 24)
drv_read
.(
        tax
        lda #0
        sec
m       rol
        dex
        bne m
        sta t0
        ldx #F_LOGIN
        jsr BDOS
        and t0
        beq no
        clc
        rts
no      sec
        rts
.)

; add_ent : entrée du répertoire (DMA) ajoutée à la table, ou fusionnée
; avec le fichier du même nom (un gros fichier a plusieurs entrées)
add_ent
.(
        lda #0                  ; blocs de l'entrée
        sta t1
        ldy #16
bl      lda DEF_DMA,y
        beq nb
        inc t1
nb      iny
        cpy #32
        bne bl
        lda used
        clc
        adc t1
        sta used
        lda #0
        sta vk
look    lda vk
        cmp cnt
        beq new
        jsr ent_ptr
        ldy #0
c1      lda (ep),y
        eor DEF_DMA+1,y
        and #$7F
        bne nxt
        iny
        cpy #11
        bne c1
        jmp upd
nxt     inc vk
        bne look
new     lda cnt
        cmp #NMAX
        bcc room
        rts
room    jsr ent_ptr
        ldy #ESZ-1
        lda #0
z       sta (ep),y
        dey
        bpl z
        ldy #10
cn      lda DEF_DMA+1,y
        and #$7F
        sta (ep),y
        dey
        bpl cn
        lda DEF_DMA+10          ; SYS -> bit 6
        and #$80
        lsr
        sta t0
        lda DEF_DMA+9           ; R/O -> bit 7
        and #$80
        ora t0
        ldy #E_ATTR
        sta (ep),y
        lda cnt
        ldy #E_RANK
        sta (ep),y
        inc cnt
upd     ldy #E_BLKS
        lda (ep),y
        clc
        adc t1
        sta (ep),y
        lda DEF_DMA+12          ; EX * 128 + RC, le plus grand
        lsr
        sta t2
        lda #0
        ror
        clc
        adc DEF_DMA+15
        sta t0
        bcc n1
        inc t2
n1      ldy #E_RECS
        lda t0
        cmp (ep),y
        iny
        lda t2
        sbc (ep),y
        bcc rt
        lda t2
        sta (ep),y
        dey
        lda t0
        sta (ep),y
rt      rts
.)

; genre : d'après le type du fichier ep
genre
.(
        ldx #0
lp      lda gext,x
        beq none
        ldy #8
        cmp (ep),y
        bne nx
        lda gext+1,x
        iny
        cmp (ep),y
        bne nx
        lda gext+2,x
        iny
        cmp (ep),y
        bne nx
        lda gext+3,x
        jmp st
nx      inx
        inx
        inx
        inx
        bne lp
none    lda #0
st      ldy #E_GEN
        sta (ep),y
        rts
.)

gext    .asc "COM",1,"BAT",2,"GRX",3,"LOG",4,"ASM",5,"INC",5,"TXT",6
        .asc "DOC",6,"CFG",7,"HIR",8,"IMG",8,"HIZ",8,"ANI",9,"SYM",10
        .asc "$$$",11,"DSK",12
        .byt 0
gname   .asc "       Prog   Script Grapher"
        .asc "Logo   Source Texte  Config "
        .asc "Image  Anim   Symb.  Tempo  Disque "

; count_marks : nmark et tot (total des tailles) des fichiers visibles
count_marks
.(
        lda #0
        sta nmark
        sta tot
        sta tot+1
        sta tot+2
        sta vi
lp      lda vi
        cmp nvis
        beq rt
        jsr vis_ptr
        ldy #E_FLAG
        lda (ep),y
        and #FL_MARK
        beq nx
        inc nmark
        clc
        ldy #E_SIZE
        lda (ep),y
        adc tot
        sta tot
        iny
        lda (ep),y
        adc tot+1
        sta tot+1
        iny
        lda (ep),y
        adc tot+2
        sta tot+2
nx      inc vi
        bne lp
rt      rts
.)

; targets : tg = fichiers visés (marqués, sinon celui du curseur).
; C=1 s'il n'y en a aucun
targets
.(
        lda #0
        sta ntg
        sta vi
lp      lda vi
        cmp nvis
        beq d
        tax
        lda vis,x
        sta vk
        jsr ent_ptr
        ldy #E_FLAG
        lda (ep),y
        and #FL_MARK
        beq nx
        ldx ntg
        lda vk
        sta tg,x
        inc ntg
nx      inc vi
        bne lp
d       lda ntg
        bne ok
        lda nvis
        beq none
        ldx cur
        lda vis,x
        sta tg
        inc ntg
ok      clc
        rts
none    lda #<m_none
        ldy #>m_none
        jsr set_msg
        sec
        rts
.)

; ent_fcb : FCB tfcb (vide) pour le fichier ep sur le lecteur drv
ent_fcb
.(
        ldx #35
        lda #0
z       sta tfcb,x
        dex
        bpl z
        lda drv
        sta tfcb
        ldy #10
c       lda (ep),y
        sta tfcb+1,y
        dey
        bpl c
        rts
.)

bdos_t  lda #<tfcb
        ldy #>tfcb
        jmp BDOS
bdos_s  lda #<sfcb
        ldy #>sfcb
        jmp BDOS
bdos_d  lda #<dfcb
        ldy #>dfcb
        jmp BDOS

set_dma0
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS

; esc_chk : C=1 si ESC a été tapé
esc_chk
.(
        jsr B_CONST
        cmp #0
        beq no
        jsr B_CONIN
        cmp #27
        beq es
no      clc
        rts
es      sec
        rts
.)

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
draw
        jsr draw_hdr
        jsr draw_col
        jsr draw_list
        jsr draw_info
        jsr draw_msg
        jmp draw_help

; ligne 1 : « A: *.*         22/40 fic 126K libre »
draw_hdr
.(
        jsr lb_clear
        lda drv
        clc
        adc #"A"-1
        sta lbuf
        lda #":"
        sta lbuf+1
        lda #3
        sta lx
        lda dok
        bne ok
        lda #<m_nodrv
        ldy #>m_nodrv
        jsr lb_str
        jmp out
ok      lda #<fpat
        ldy #>fpat
        jsr lb_pat
        lda #0
        sta sepf
        jsr num_cnt
        ldy #21
        jsr lb_numr
        lda nvis
        cmp cnt
        beq nf
        ldy lx
        lda #"/"
        sta lbuf,y
        dey
        lda nvis
        sta num
        jsr lb_numr
nf      lda #22
        sta lx
        lda #<m_fic
        ldy #>m_fic
        jsr lb_str
        lda #NBLK               ; place libre, en Ko
        sec
        sbc used
        bcs fr
        lda #0
fr      asl
        sta num
        lda #0
        rol
        sta num+1
        lda #0
        sta num+2
        ldy #29
        jsr lb_numr
        lda #30
        sta lx
        lda #<m_lib
        ldy #>m_lib
        jsr lb_str
out     ldx #R_HDR
        jmp put_line0
.)

num_cnt lda cnt
num8    sta num
        lda #0
        sta num+1
        sta num+2
        rts

; ligne 2 : titres des colonnes, sens du tri
draw_col
.(
        jsr lb_clear
        lda #<m_cols
        ldy #>m_cols
        jsr lb_str
        ldx skey
        ldy spos-1,x
        lda #"+"
        ldx srev
        beq up
        lda #"-"
up      sta lbuf,y
        ldx #R_COL
        jmp put_line0
.)
spos    .byt 29,5,14,22

; lignes 3 à 24 : la liste
draw_list
.(
        lda #0
        sta vk
lp      lda vk
        cmp #NROWS
        beq rt
        jsr lb_clear
        lda #0
        sta inv
        lda top
        clc
        adc vk
        cmp nvis
        bcs emp
        cmp cur
        bne nc
        ldx #$80
        stx inv
nc      jsr vis_ptr
        jsr fmt_ent
emp     lda vk
        clc
        adc #R_LIST
        tax
        jsr put_line
        inc vk
        bne lp
rt      rts
.)

; fmt_ent : ligne de l'entrée ep dans lbuf
; « * NOM      TYP  TAILLE RS   N GENRE  »
fmt_ent
.(
        ldy #E_FLAG
        lda (ep),y
        and #FL_MARK
        beq nm
        lda #"*"
        sta lbuf
nm      ldy #0
c1      lda (ep),y
        sta lbuf+2,y
        iny
        cpy #8
        bne c1
c2      lda (ep),y
        sta lbuf+3,y
        iny
        cpy #11
        bne c2
        ldy #E_SIZE
        lda (ep),y
        sta num
        iny
        lda (ep),y
        sta num+1
        iny
        lda (ep),y
        sta num+2
        lda #1
        sta sepf
        ldy #21
        jsr lb_numr
        ldy #E_ATTR
        lda (ep),y
        bpl nro1
        ldx #"R"
        stx lbuf+23
nro1    asl
        bpl nsy1
        ldx #"S"
        stx lbuf+24
nsy1    ldy #E_RANK
        lda (ep),y
        clc
        adc #1
        jsr num8
        lda #0
        sta sepf
        ldy #28
        jsr lb_numr
        ldy #E_GEN
        lda (ep),y
        sta t0
        asl
        asl
        asl
        sec
        sbc t0
        tax
        ldy #0
g       lda gname,x
        sta lbuf+30,y
        inx
        iny
        cpy #7
        bne g
        rts
.)

; ligne 25 : fichier sous le curseur, ou total des marques
draw_info
.(
        jsr lb_clear
        jsr count_marks
        lda nmark
        beq one
        jsr num8
        lda #0
        sta sepf
        jsr lb_numl
        lda #<m_marks
        ldy #>m_marks
        jsr lb_str
        lda tot
        sta num
        lda tot+1
        sta num+1
        lda tot+2
        sta num+2
        lda #1
        sta sepf
        jsr lb_numl
        lda #<m_oct
        ldy #>m_oct
        jsr lb_str
        jmp out
one     lda nvis
        beq none
        lda cur
        jsr vis_ptr
        lda ep
        ldy ep+1
        jsr lb_pat
        lda #<m_sep
        ldy #>m_sep
        jsr lb_str
        ldy #E_RECS
        lda (ep),y
        sta num
        iny
        lda (ep),y
        sta num+1
        lda #0
        sta num+2
        sta sepf
        jsr lb_numl
        lda #<m_enr
        ldy #>m_enr
        jsr lb_str
        ldy #E_BLKS
        lda (ep),y
        jsr num8
        jsr lb_numl
        lda #<m_blk
        ldy #>m_blk
        jsr lb_str
        jmp out
none    lda #<m_none
        ldy #>m_none
        jsr lb_str
out     ldx #R_INFO
        jmp put_line0
.)

; ligne 26 : message
draw_msg
.(
        jsr lb_clear
        lda msgp+1
        beq e
        lda msgp
        ldy msgp+1
        jsr lb_str
e       ldx #R_MSG
        jmp put_line0
.)

; ligne 27 : aide
draw_help
        jsr lb_clear
        lda #<m_help
        ldy #>m_help
        jsr lb_str
        ldx #R_HELP
        jmp put_line0

; set_msg : message A/Y pour la ligne 26
set_msg
        sta msgp
        sty msgp+1
        rts

; show_now : message A/Y affiché tout de suite
show_now
        jsr set_msg
        jmp draw_msg

; clr_area : efface les lignes 1 à 27
clr_area
.(
        jsr lb_clear
        ldx #1
lp      stx vk
        jsr put_line0
        ldx vk
        inx
        cpx #28
        bne lp
        rts
.)

; ---------------------------------------------------------------------
; Ligne de travail lbuf (37 colonnes)
; ---------------------------------------------------------------------
lb_clear
.(
        ldx #W-1
        lda #" "
lp      sta lbuf,x
        dex
        bpl lp
        lda #0
        sta lx
        rts
.)

; put_line0 / put_line : lbuf -> ligne X de l'écran, colonnes 2-38
; (put_line : chaque octet ORé avec inv, $80 = vidéo inverse)
put_line0
        lda #0
        sta inv
put_line
.(
        jsr row_addr
        ldy #0
lp      lda lbuf,y
        ora inv
        iny
        iny
        sta (scr),y
        dey
        cpy #W
        bne lp
        rts
.)

; row_addr : X = ligne -> scr = adresse de sa colonne 0
row_addr
        txa
        asl
        asl
        asl
        sta scr
        lda #0
        sta scr+1
        lda scr
        asl
        rol scr+1
        asl
        rol scr+1
        clc
        adc scr
        sta scr
        lda scr+1
        adc #0
        sta scr+1
        lda scr
        clc
        adc #<SCREEN
        sta scr
        lda scr+1
        adc #>SCREEN
        sta scr+1
        rts

; lb_chr : A en lbuf[lx], lx+1 (A, X, Y conservés)
lb_chr
.(
        sty ly
        ldy lx
        cpy #W
        bcs rt
        sta lbuf,y
        inc lx
rt      ldy ly
        rts
.)

; lb_str : chaîne A/Y (0 à la fin) à partir de lx
lb_str
.(
        sta sp
        sty sp+1
        ldy #0
lp      lda (sp),y
        beq rt
        jsr lb_chr
        iny
        bne lp
rt      rts
.)

; lb_pat : nom de 11 octets en A/Y -> « NOM.EXT » à partir de lx
; (une fin de partie faite de ? s'écrit *)
lb_pat
.(
        sta sp
        sty sp+1
        ldy #0
        ldx #8
        jsr part
        ldy #8
        lda (sp),y
        cmp #" "
        beq rt
        lda #"."
        jsr lb_chr
        ldy #8
        ldx #11
        jmp part
part    stx t0
pl      cpy t0
        beq rt
        sty t1
qq      lda (sp),y
        cmp #"?"
        bne nq
        iny
        cpy t0
        bne qq
        lda #"*"
        jmp lb_chr
nq      ldy t1
        lda (sp),y
        cmp #" "
        beq rt
        jsr lb_chr
        iny
        bne pl
rt      rts
.)

; lb_to_msg : lbuf[0..lx) devient le message (mbuf)
lb_to_msg
.(
        ldx #0
lp      cpx lx
        beq z
        lda lbuf,x
        sta mbuf,x
        inx
        bne lp
z       lda #0
        sta mbuf,x
        lda #<mbuf
        ldy #>mbuf
        jmp set_msg
.)

; lb_to_in : lbuf[0..lx) devient le texte proposé d'une saisie
lb_to_in
.(
        ldx #0
lp      cpx lx
        beq z
        lda lbuf,x
        sta inbuf,x
        inx
        bne lp
z       stx inlen
        rts
.)

; ---------------------------------------------------------------------
; Nombres
; ---------------------------------------------------------------------
; utoa : num (24 bits, < 1 000 000) -> chiffres dans dbuf, dlen
utoa
.(
        ldx #0
        stx dlen
        stx nz
pw      lda #0
        sta t0
sub     lda num
        sec
        sbc p0,x
        sta t1
        lda num+1
        sbc p1,x
        sta t2
        lda num+2
        sbc p2,x
        bcc out
        sta num+2
        lda t2
        sta num+1
        lda t1
        sta num
        inc t0
        bne sub
out     lda t0
        ora nz
        bne dig
        cpx #5
        bne skip
dig     lda t0
        ora #"0"
        ldy dlen
        sta dbuf,y
        inc dlen
        sta nz
skip    inx
        cpx #6
        bne pw
        rts
.)
p0      .byt $A0,$10,$E8,$64,$0A,$01
p1      .byt $86,$27,$03,$00,$00,$00
p2      .byt $01,$00,$00,$00,$00,$00

; lb_numr : num cadré à droite, dernier chiffre en colonne Y ; lx =
; colonne à gauche du nombre ; sepf : espace entre les milliers
lb_numr
.(
        sty lx
        jsr utoa
        ldx dlen
        lda #0
        sta t0
lp      dex
        bmi rt
        lda t0
        cmp #3
        bne nd
        lda sepf
        beq nd
        lda #" "
        ldy lx
        sta lbuf,y
        dec lx
        lda #0
        sta t0
nd      lda dbuf,x
        ldy lx
        sta lbuf,y
        dec lx
        inc t0
        jmp lp
rt      rts
.)

; lb_numl : num à partir de lx ; sepf : espace entre les milliers
lb_numl
.(
        jsr utoa
        ldx #0
lp      cpx dlen
        beq rt
        txa
        beq d
        lda sepf
        beq d
        stx t0
        lda dlen
        sec
        sbc t0
        cmp #3
        beq spc
        cmp #6
        bne d
spc     lda #" "
        jsr lb_chr
d       lda dbuf,x
        jsr lb_chr
        inx
        bne lp
rt      rts
.)

; ---------------------------------------------------------------------
; Questions (ligne 26)
; ---------------------------------------------------------------------
; ask : question A/Y, texte proposé dans inbuf/inlen ; RETURN valide,
; ESC (C=1) abandonne
ask
.(
        sta askp
        sty askp+1
red     jsr lb_clear
        lda askp
        ldy askp+1
        jsr lb_str
        ldx #0
il      cpx inlen
        beq eol
        lda inbuf,x
        jsr lb_chr
        inx
        bne il
eol     lda #$A0                ; curseur : espace en vidéo inverse
        jsr lb_chr
        ldx #R_MSG
        jsr put_line0
key     jsr B_CONIN
        cmp #13
        beq ok
        cmp #27
        beq esc
        cmp #$7F
        beq bs
        cmp #8
        beq bs
        cmp #" "
        bcc key
        cmp #$7F
        bcs key
        ldx inlen
        cpx #MAXIN
        bcs key
        sta inbuf,x
        inc inlen
        jmp red
bs      lda inlen
        beq key
        dec inlen
        jmp red
ok      clc
        rts
esc     sec
        rts
.)

; ask_key : question A/Y, touche en majuscule dans A
ask_key
        jsr show_now
        jsr B_CONIN
        jmp upc

; ask_yn : question A/Y, C=1 si O (ou Y)
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

upc
.(
        cmp #"a"
        bcc rt
        cmp #"z"+1
        bcs rt
        and #$DF
rt      rts
.)

; ---------------------------------------------------------------------
; parse : inbuf/inlen -> pfcb (lecteur, nom 8, type 3, * en ?) ;
; pfl : bit 0 lecteur, 1 nom, 2 jokers, 3 point. C=1 si incorrect
; ---------------------------------------------------------------------
parse
.(
        ldx #11
        lda #" "
f       sta pfcb,x
        dex
        bne f
        lda #0
        sta pfcb
        sta pfl
        ldy #0
sp1     cpy inlen               ; espaces de tête
        beq end
        lda inbuf,y
        cmp #" "
        bne s1
        iny
        bne sp1
s1      iny                     ; « X: » ?
        cpy inlen
        bcs nod
        lda inbuf,y
        cmp #":"
        bne nod
        dey
        lda inbuf,y
        jsr upc
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        sta pfcb
        lda #1
        sta pfl
        iny
        iny
        jmp nm
nod     dey
nm      ldx #1
        lda #9
        sta t0
        jsr field
        bcs bad
        cpy inlen
        beq end
        lda inbuf,y
        cmp #"."
        bne end
        lda pfl
        ora #8
        sta pfl
        iny
        ldx #9
        lda #12
        sta t0
        jsr field
        bcs bad
end     cpy inlen               ; espaces de fin seulement
        beq fin
        lda inbuf,y
        cmp #" "
        bne bad
        iny
        bne end
fin     lda pfcb+1
        cmp #" "
        beq ok
        lda pfl
        ora #2
        sta pfl
ok      clc
        rts
bad     sec
        rts
.)

; field : caractères de inbuf (Y) -> pfcb (X) jusqu'à t0 (exclu)
field
.(
lp      cpy inlen
        beq ok
        lda inbuf,y
        cmp #"."
        beq ok
        cmp #" "
        beq ok
        jsr upc
        cmp #"*"
        bne nst
        lda pfl
        ora #4
        sta pfl
        lda #"?"
st      cpx t0
        bcs st2
        sta pfcb,x
        inx
        bne st
st2     iny
        jmp lp
nst     cpx t0
        bcs bad
        cmp #"?"
        bne nq
        pha
        lda pfl
        ora #4
        sta pfl
        pla
nq      jsr valid
        bcs bad
        sta pfcb,x
        inx
        iny
        jmp lp
ok      clc
        rts
bad     sec
        rts
.)

; valid : C=1 si A ne peut pas figurer dans un nom
valid
.(
        cmp #" "+1
        bcc no
        cmp #$7F
        bcs no
        stx t1
        ldx #8
lp      cmp badc,x
        beq no1
        dex
        bpl lp
        ldx t1
        clc
        rts
no1     ldx t1
no      sec
        rts
.)
badc    .asc ":;,<>=[]|"

; ---------------------------------------------------------------------
; Voir : le texte du fichier, par pages
; ---------------------------------------------------------------------
k_view
.(
        lda nvis
        bne go
        rts
go      lda cur
        jsr vis_ptr
        jsr ent_fcb
        jsr set_dma0
        ldx #F_OPEN
        jsr bdos_t
        cmp #$FF
        bne op
        lda #<m_rerr
        ldy #>m_rerr
        jmp set_msg
op      jsr clr_area
        lda #0
        sta vx
        sta vy
        sta vquit
        lda #128
        sta vrec
nx      lda vquit
        bne quit
        lda vrec
        bpl have
        jsr set_dma0
        ldx #F_READ
        jsr bdos_t
        cmp #0
        bne eof
        sta vrec
have    ldx vrec
        inc vrec
        lda DEF_DMA,x
        cmp #$1A
        beq eof
        cmp #13
        beq nl
        cmp #10
        beq nx
        cmp #9
        bne nt
        lda #" "
nt      cmp #" "
        bcc dot
        cmp #$7F
        bcc ok
dot     lda #"."
ok      jsr vput
        jmp nx
nl      jsr vnl
        jmp nx
eof     lda #<m_vend
        ldy #>m_vend
        jsr vprompt
quit    jmp clr_area
.)

; vput : A écrit en (vx, vy) ; passe à la ligne après 37 colonnes
vput
.(
        pha
        lda vx
        cmp #W
        bcc w
        jsr vnl
w       pla
        ldx vquit
        bne rt
        pha
        ldx vy
        inx
        jsr row_addr
        lda vx
        clc
        adc #2
        tay
        pla
        sta (scr),y
        inc vx
rt      rts
.)

; vnl : ligne suivante ; page pleine : attente (ESC : vquit)
vnl
.(
        lda #0
        sta vx
        inc vy
        lda vy
        cmp #26
        bcc rt
        lda #<m_vmore
        ldy #>m_vmore
        jsr vprompt
        cmp #27
        bne c
        sta vquit
        rts
c       jsr clr_area
        lda #0
        sta vy
rt      rts
.)

; vprompt : texte A/Y en ligne 27, attend une touche (dans A)
vprompt
        pha
        tya
        pha
        jsr lb_clear
        pla
        tay
        pla
        jsr lb_str
        ldx #R_HELP
        jsr put_line0
        jmp B_CONIN

; ---------------------------------------------------------------------
; Effacer
; ---------------------------------------------------------------------
k_del
.(
        jsr targets
        bcs rt
        lda #<m_era
        ldy #>m_era
        jsr lb_what
        lda #<m_yn
        ldy #>m_yn
        jsr lb_str
        jsr lb_to_msg
        lda #<mbuf
        ldy #>mbuf
        jsr ask_yn
        bcc no
        lda #0
        sta ncp
        sta nro
        sta nerr
        sta vi
lp      lda vi
        cmp ntg
        beq done
        tax
        lda tg,x
        jsr ent_ptr
        jsr ent_fcb
        ldx #F_DELETE
        jsr bdos_t
        cmp #$FE
        bne d1
        inc nro
        jmp nx
d1      cmp #$FF
        beq nx
        inc ncp
nx      inc vi
        bne lp
done    jsr reload_keep
        lda #<m_erased
        ldy #>m_erased
        jmp report
no      lda #0
        sta msgp+1
rt      rts
.)

; lb_what : « verbe NOM.EXT » ou « verbe n fichiers » dans lbuf
lb_what
.(
        pha
        tya
        pha
        jsr lb_clear
        pla
        tay
        pla
        jsr lb_str
        lda ntg
        cmp #1
        bne many
        lda tg
        jsr ent_ptr
        lda ep
        ldy ep+1
        jmp lb_pat
many    jsr num8
        lda #0
        sta sepf
        jsr lb_numl
        lda #<m_nfic
        ldy #>m_nfic
        jmp lb_str
.)

; report : « n <A/Y>[, n protege(s)][, n illisible(s)] » en message
report
.(
        pha
        tya
        pha
        jsr lb_clear
        lda #0
        sta sepf
        lda ncp
        jsr num8
        jsr lb_numl
        pla
        tay
        pla
        jsr lb_str
        lda nro
        beq n1
        jsr num8
        jsr comma
        jsr lb_numl
        lda #<m_prot
        ldy #>m_prot
        jsr lb_str
n1      lda nerr
        beq n2
        jsr num8
        jsr comma
        jsr lb_numl
        lda #<m_illis
        ldy #>m_illis
        jsr lb_str
n2      jmp lb_to_msg
comma   lda #","
        jsr lb_chr
        lda #" "
        jmp lb_chr
.)

; ---------------------------------------------------------------------
; Renommer
; ---------------------------------------------------------------------
k_ren
.(
        jsr targets
        bcs rt
        lda ntg
        cmp #1
        beq one
        lda #<m_one1
        ldy #>m_one1
        jmp set_msg
one     lda tg
        jsr ent_ptr
        jsr lb_clear            ; nom actuel proposé
        lda ep
        ldy ep+1
        jsr lb_pat
        jsr lb_to_in
        lda #<m_newn
        ldy #>m_newn
        jsr ask
        bcs rt
        jsr parse
        bcs bad
        lda pfl
        and #4
        bne bad
        lda pfl
        and #2
        beq bad
        lda pfcb
        beq sd
        cmp drv
        beq sd
        lda #<m_samedrv
        ldy #>m_samedrv
        jmp set_msg
sd      ldx #10
cp      lda pfcb+1,x
        sta cname,x
        dex
        bpl cp
        jmp do_rename
bad     jmp bad_name
rt      rts
.)

; do_rename : le fichier tg[0] prend le nom cname (même lecteur)
do_rename
.(
        lda tg
        jsr ent_ptr
        ldy #10                 ; même nom : rien à faire
s       lda (ep),y
        cmp cname,y
        bne diff
        dey
        bpl s
        rts
diff    ldy #E_ATTR
        lda (ep),y
        bpl rw
        lda #<m_ro
        ldy #>m_ro
        jmp set_msg
rw      jsr ent_fcb             ; le nouveau nom existe-t-il ?
        ldx #10
c1      lda cname,x
        sta tfcb+1,x
        dex
        bpl c1
        jsr set_dma0
        ldx #F_SFIRST
        jsr bdos_t
        cmp #$FF
        beq free
        lda #<m_taken
        ldy #>m_taken
        jmp set_msg
free    jsr ent_fcb             ; ancien nom en +0, nouveau en +16
        lda drv
        sta tfcb+16
        ldx #10
c2      lda cname,x
        sta tfcb+17,x
        dex
        bpl c2
        ldx #F_RENAME
        jsr bdos_t
        cmp #$FE
        bne ok
        lda #<m_ro
        ldy #>m_ro
        jmp set_msg
ok      ldx #10                 ; le curseur suit le fichier
c3      lda cname,x
        sta curname,x
        dex
        bpl c3
        lda #0
        sta keepc
        jsr reload_marks
        lda #<m_renok
        ldy #>m_renok
        jmp set_msg
.)

; ---------------------------------------------------------------------
; Attributs
; ---------------------------------------------------------------------
k_attr
.(
        jsr targets
        bcc jf1
        jmp rt
jf1
        lda tg                  ; attributs du premier fichier proposés
        jsr ent_ptr
        lda #0
        sta inlen
        ldy #E_ATTR
        lda (ep),y
        sta t2
        bpl nr
        lda #"R"
        jsr addin
nr      lda t2
        asl
        bpl ns
        lda #"S"
        jsr addin
ns      lda #<m_attq
        ldy #>m_attq
        jsr ask
        bcs rt
        lda #0
        sta t2
        ldx #0
lp      cpx inlen
        beq go
        lda inbuf,x
        jsr upc
        cmp #" "
        beq nx
        cmp #"R"
        bne s
        lda #$80
        bne set
s       cmp #"S"
        bne bad
        lda #$40
set     ora t2
        sta t2
nx      inx
        bne lp
bad     lda #<m_attbad
        ldy #>m_attbad
        jmp set_msg
go      lda #0
        sta vi
al      lda vi
        cmp ntg
        beq done
        tax
        lda tg,x
        jsr ent_ptr
        jsr ent_fcb
        lda t2
        and #$80
        ora tfcb+9
        sta tfcb+9
        lda t2
        asl
        and #$80
        ora tfcb+10
        sta tfcb+10
        ldx #F_ATTRIB
        jsr bdos_t
        inc vi
        bne al
done    jsr reload_keep
        lda #<m_attok
        ldy #>m_attok
        jmp set_msg
rt      rts
addin   ldx inlen
        sta inbuf,x
        inc inlen
        rts
.)

; ---------------------------------------------------------------------
; Tailles exactes
; ---------------------------------------------------------------------
; k_info : taille exacte, enregistrements et blocs du fichier courant
k_info
.(
        lda nvis
        beq rt
        lda cur
        jsr vis_ptr
        jsr exact
        jsr lb_clear
        lda ep
        ldy ep+1
        jsr lb_pat
        lda #<m_sep
        ldy #>m_sep
        jsr lb_str
        ldy #E_SIZE
        lda (ep),y
        sta num
        iny
        lda (ep),y
        sta num+1
        iny
        lda (ep),y
        sta num+2
        lda #1
        sta sepf
        jsr lb_numl
        lda #<m_oct
        ldy #>m_oct
        jsr lb_str
        lda #","
        jsr lb_chr
        ldy #E_BLKS
        lda (ep),y
        jsr num8
        lda #" "
        jsr lb_chr
        jsr lb_numl
        lda #<m_blk
        ldy #>m_blk
        jsr lb_str
        jmp lb_to_msg
rt      rts
.)

; k_exact : tailles exactes de tous les fichiers (ESC arrête)
k_exact
.(
        lda #<m_wait
        ldy #>m_wait
        jsr show_now
        lda #0
        sta vi
lp      lda vi
        cmp cnt
        beq done
        jsr esc_chk
        bcs done
        lda vi
        jsr ent_ptr
        jsr exact
        inc vi
        bne lp
done    jsr rebuild_keep
        lda #<m_exok
        ldy #>m_exok
        jmp set_msg
.)

; exact : taille exacte de l'entrée ep (règle de STAT : les ^Z du dernier
; enregistrement sont retirés) ; ep conservé
exact
.(
        ldy #E_FLAG
        lda (ep),y
        and #FL_EXACT
        bne rt
        ldy #E_RECS
        lda (ep),y
        sta nrec
        iny
        lda (ep),y
        sta nrec+1
        ora nrec
        beq zero
        jsr ent_fcb
        jsr set_dma0
        ldx #F_OPEN
        jsr bdos_t
        cmp #$FF
        beq rt
        lda nrec                ; dernier enregistrement : recs - 1
        sec
        sbc #1
        sta tfcb+FCB_R0
        sta num+1
        lda nrec+1
        sbc #0
        sta tfcb+FCB_R0+1
        sta num+2
        lda #0
        sta num
        lsr num+2               ; (recs - 1) x 128
        ror num+1
        ror num
        ldx #F_RREAD
        jsr bdos_t
        ldy #128                ; illisible : enregistrement entier
        cmp #0
        bne add
        ldy #127
tz      lda DEF_DMA,y
        cmp #$1A
        bne last
        dey
        bpl tz
last    iny
add     tya
        clc
        adc num
        sta num
        bcc st
        inc num+1
        bne st
        inc num+2
st      ldy #E_SIZE
        lda num
        sta (ep),y
        iny
        lda num+1
        sta (ep),y
        iny
        lda num+2
        sta (ep),y
zero    ldy #E_FLAG
        lda (ep),y
        ora #FL_EXACT
        sta (ep),y
rt      rts
.)

; ---------------------------------------------------------------------
; Lecteur, relecture, fin
; ---------------------------------------------------------------------
k_drive
.(
        lda drv
        clc
        adc #"A"-1
        sta inbuf
        lda #":"
        sta inbuf+1
        lda #2
        sta inlen
        lda #<m_drvq
        ldy #>m_drvq
        jsr ask
        bcs rt
        ldx #0
sk      cpx inlen
        beq rt
        lda inbuf,x
        inx
        cmp #" "
        beq sk
        jsr upc
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        sta drv
        jmp reload
bad     lda #<m_drvbad
        ldy #>m_drvbad
        jmp set_msg
rt      rts
.)

k_reload
        ldx #F_RESET            ; disquette changée : tout est relu
        jsr BDOS
        jmp reload_keep

k_quit
        ldx #F_CONOUT
        lda #$0C
        jsr BDOS
        jmp WBOOT               ; réinstalle la barre de menus du système

; cur_off : curseur de la console éteint
cur_off
.(
        php
        sei
        lda #0
        sta CON_CUREN
        lda CON_CURVIS
        beq rt
        ldx CON_CURY
        jsr row_addr
        ldy CON_CURX
        lda (scr),y
        eor #$80
        sta (scr),y
        lda #0
        sta CON_CURVIS
rt      plp
        rts
.)

; ---------------------------------------------------------------------
; Copier, Déplacer
; ---------------------------------------------------------------------
k_copy  lda #0
        .byt $2C
k_move  lda #1
        sta mvf
.(
        jsr targets
        bcc jf2
        jmp rt
jf2
        lda mvf
        beq c0
        lda #0                  ; Déplacer : originaux protégés refusés
        sta vi
ro      lda vi
        cmp ntg
        beq c0
        tax
        lda tg,x
        jsr ent_ptr
        ldy #E_ATTR
        lda (ep),y
        bpl rnx
        lda #<m_roorig
        ldy #>m_roorig
        jmp set_msg
rnx     inc vi
        bne ro
c0      lda #<m_cop             ; « Copier n fichiers vers : »
        ldy #>m_cop
        ldx mvf
        beq c1
        lda #<m_mov
        ldy #>m_mov
c1      jsr lb_what
        lda #<m_to
        ldy #>m_to
        jsr lb_str
        jsr lb_to_msg
        lda #0
        sta inlen
        lda #<mbuf
        ldy #>mbuf
        jsr ask
        bcc jf3
        jmp rt
jf3
        lda inlen
        bne jf4
        jmp rt
jf4
        jsr parse
        bcc jf5
        jmp bad
jf5
        lda pfl
        and #4
        beq jf6
        jmp bad
jf6
        lda pfcb
        bne hd
        lda drv
hd      sta cdst
        lda #0
        sta named
        lda pfl
        and #2
        beq nn
        lda ntg                 ; un nom : un seul fichier
        cmp #1
        beq one
        lda #<m_one
        ldy #>m_one
        jmp set_msg
one     lda tg
        jsr ent_ptr
        ldx #10
        ldy #10
cn      lda pfcb+1,x
        sta cname,x
        cmp (ep),y
        beq sm
        inc named               ; autre nom que la source
sm      dey
        dex
        bpl cn
nn      lda cdst
        cmp drv
        bne two
        lda named
        bne dup
        lda #1                  ; même lecteur, même nom : un seul
        sta single              ; lecteur, avec échanges
        jmp run
dup     lda mvf                 ; même lecteur, autre nom
        beq two0
        jmp do_rename           ; Déplacer = renommer
two     lda cdst                ; autre lecteur : lisible ?
        jsr dir_fp
        bcc two0
        lda #<m_nodst
        ldy #>m_nodst
        jmp set_msg
two0    lda #0
        sta single
run     jsr copy_run
        jsr reload_keep
        lda errm+1
        beq rpt
        lda errm
        ldy errm+1
        jmp set_msg
rpt     lda #<m_copied
        ldy #>m_copied
        ldx mvf
        beq rp
        lda #<m_moved
        ldy #>m_moved
rp      jmp report
bad     jmp bad_name
rt      rts
.)

; copy_run : copie des fichiers tg vers cdst (nom cname si named), en
; tranches : lecture de la source dans le tampon, puis écriture
copy_run
.(
        lda #0
        sta rd_k
        sta rd_open
        sta wr_open
        sta stopf
        sta ncp
        sta nro
        sta nerr
        sta rall
        sta cur_in
        sta havd
        sta errm+1
        sta vi
cl      lda vi                  ; drapeaux de copie remis à zéro
        cmp ntg
        beq c2
        tax
        lda tg,x
        jsr ent_ptr
        ldy #E_FLAG
        lda (ep),y
        and #FL_MARK+FL_EXACT
        sta (ep),y
        inc vi
        bne cl
c2      lda single
        beq lp
        ldx #F_RESET            ; tampon du BDOS écrit avant les échanges
        jsr BDOS
        lda drv
        jsr dir_fp              ; empreinte de la source, en place
        jsr fp_to_s
lp      jsr need_src
        bcs abort
        jsr do_pending
        lda stopf
        bne fin
        lda rd_k
        cmp ntg
        bcs fin
        jsr fill
        lda nch
        beq lp
        jsr need_dst
        bcs abort
        jsr flush_ch
        lda single
        beq lp
        ldx #F_RESET            ; écritures faites : tampon vidé, puis
        jsr BDOS                ; nouvelle empreinte de la destination
        lda drv
        jsr dir_fp
        jsr fp_to_d
        jmp lp
abort   inc stopf
        lda wr_open             ; un fichier reste incomplet
        beq fin
        jsr lb_clear
        lda #<dfcb+1
        ldy #>dfcb+1
        jsr lb_pat
        lda #<m_incpl
        ldy #>m_incpl
        jsr lb_str
        jsr lb_to_msg
        lda #<mbuf
        sta errm
        lda #>mbuf
        sta errm+1
fin     rts
.)

; need_src / need_dst : un seul lecteur : demande la disquette voulue
; (empreinte vérifiée). C=1 si ESC
need_src
.(
        lda single
        beq ok
        lda cur_in
        beq ok
        lda #0
        sta retry
again   lda #<m_isrc
        ldy #>m_isrc
        jsr ask_swap
        bcs rt
        lda fpok
        beq bad
        jsr cmp_s
        bne bad
        lda #0
        sta cur_in
ok      clc
rt      rts
bad     inc retry
        jmp again
.)

need_dst
.(
        lda single
        beq ok
        lda cur_in
        bne ok
        lda #0
        sta retry
again   lda #<m_idst
        ldy #>m_idst
        jsr ask_swap
        bcs rt
        lda fpok
        beq bad
        jsr cmp_s               ; la source n'est pas une destination
        beq bad
        lda havd
        beq new
        jsr cmp_d
        bne bad
        beq got
new     jsr fp_to_d
        inc havd
got     lda #1
        sta cur_in
ok      clc
rt      rts
bad     inc retry
        jmp again
.)

; ask_swap : « [Non ! ]<A/Y>X:, une touche » ; puis BDOS remis à zéro et
; empreinte du répertoire (fpok = 0 si illisible). C=1 si ESC
ask_swap
.(
        pha
        tya
        pha
        jsr lb_clear
        lda retry
        beq n
        lda #<m_non
        ldy #>m_non
        jsr lb_str
n       pla
        tay
        pla
        jsr lb_str
        lda drv
        clc
        adc #"A"-1
        jsr lb_chr
        lda #":"
        jsr lb_chr
        lda #<m_key
        ldy #>m_key
        jsr lb_str
        jsr lb_to_msg
        lda #<mbuf
        ldy #>mbuf
        jsr ask_key
        cmp #27
        beq esc
        lda #<m_rdir
        ldy #>m_rdir
        jsr show_now
        ldx #F_RESET
        jsr BDOS
        lda drv
        jsr dir_fp
        lda #0
        rol
        eor #1
        sta fpok
        clc
        rts
esc     lda #<m_esc
        sta errm
        lda #>m_esc
        sta errm+1
        sec
        rts
.)

fp_to_s
        ldx #2
fs1     lda fp0,x
        sta fps,x
        dex
        bpl fs1
        rts
fp_to_d
        ldx #2
fd1     lda fp0,x
        sta fpd,x
        dex
        bpl fd1
        rts
; cmp_s / cmp_d : Z=1 si l'empreinte fp0 est celle de la source / dest.
cmp_s
        ldx #2
cs1     lda fp0,x
        cmp fps,x
        bne cs2
        dex
        bpl cs1
        lda #0                  ; Z=1 : identiques
cs2     rts
cmp_d
        ldx #2
cd1     lda fp0,x
        cmp fpd,x
        bne cd2
        dex
        bpl cd1
        lda #0                  ; Z=1 : identiques
cd2     rts

; do_pending : Déplacer : originaux des fichiers copiés effacés
do_pending
.(
        lda #0
        sta t2
        sta vi
lp      lda vi
        cmp ntg
        beq d
        tax
        lda tg,x
        jsr ent_ptr
        ldy #E_FLAG
        lda (ep),y
        and #FL_DEL
        beq nx
        lda (ep),y
        and #$FF-FL_DEL
        sta (ep),y
        jsr ent_fcb
        ldx #F_DELETE
        jsr bdos_t
        inc t2
nx      inc vi
        bne lp
d       lda single
        beq rt
        lda t2
        beq rt
        ldx #F_RESET            ; la source a changé : nouvelle empreinte
        jsr BDOS
        lda drv
        jsr dir_fp
        jsr fp_to_s
rt      rts
.)

; fill : remplit le tampon avec la suite des fichiers à lire (tranches)
fill
.(
        lda #0
        sta nch
        sta bp
        lda bufpg
        sta bp+1
lp      lda rd_k
        cmp ntg
        bcc jf7
        jmp rt
jf7
        lda nch
        cmp #NCH
        bcc jf8
        jmp rt
jf8
        lda bp+1
        cmp TPA_TOP+1
        bcc jf9
        jmp rt
jf9
        ldx rd_k
        lda tg,x
        jsr ent_ptr
        lda rd_open
        bne rd
        jsr ent_fcb             ; ouverture du fichier suivant
        ldx #35
cp      lda tfcb,x
        sta sfcb,x
        dex
        bpl cp
        jsr set_dma0
        ldx #F_OPEN
        jsr bdos_s
        cmp #$FF
        bne op
        ldy #E_FLAG             ; illisible : sauté
        lda (ep),y
        ora #FL_SKIP
        sta (ep),y
        inc nerr
        inc rd_k
        jmp lp
op      lda #0
        sta sfcb+32
        lda #1
        sta rd_open
        sta first
rd      ldx nch                 ; nouvelle tranche
        lda rd_k
        sta ch_k,x
        lda #0
        sta ch_nl,x
        sta ch_nh,x
        lda first
        sta ch_f,x
        lda #0
        sta first
rl      lda bp+1
        cmp TPA_TOP+1
        bcs full
        lda bp
        ldy bp+1
        ldx #F_SETDMA
        jsr BDOS
        ldx #F_READ
        jsr bdos_s
        cmp #0
        bne eof
        jsr bp_add128
        ldx nch
        inc ch_nl,x
        bne rl
        inc ch_nh,x
        jmp rl
eof     ldx nch                 ; fin du fichier
        lda ch_f,x
        ora #2
        sta ch_f,x
        inc nch
        lda #0
        sta rd_open
        inc rd_k
        jmp lp
full    inc nch
rt      rts
.)

; flush_ch : écrit les tranches du tampon
flush_ch
.(
        lda #0
        sta ci
        sta bp
        lda bufpg
        sta bp+1
lp      lda ci
        cmp nch
        bne go
        jmp end
go      tax
        lda ch_k,x
        tax
        lda tg,x
        jsr ent_ptr
        ldx ci
        lda ch_f,x
        and #1
        beq cont
        jsr esc_chk             ; début d'un fichier : ESC ?
        bcc ne
        lda #<m_esc
        ldy #>m_esc
        jmp stop
ne      jsr open_dst
        lda stopf
        bne end
        bcc cont
        ldy #E_FLAG             ; sauté (protégé, ou non remplacé)
        lda (ep),y
        ora #FL_SKIP
        sta (ep),y
cont    ldy #E_FLAG
        lda (ep),y
        and #FL_SKIP
        bne adv
        jsr wr_chunk
        bcc wok
        jsr kill_dst            ; disque plein : copie partielle effacée
        lda #<m_full
        ldy #>m_full
        jmp stop
wok     ldx ci
        lda ch_f,x
        and #2
        beq ckp
        jsr end_dst
        jmp nx
ckp     ldx #F_CLOSE            ; point d'étape : le fichier continue
        jsr bdos_d
        jmp nx
adv     jsr adv_chunk
nx      inc ci
        jmp lp
stop    sta errm
        sty errm+1
        inc stopf
end     lda stopf
        beq rt
        lda wr_open
        beq rt
        jmp kill_dst
rt      rts
.)

; open_dst : crée la copie du fichier ep (dfcb). C=1 : fichier sauté ;
; stopf : arrêt (ESC, répertoire plein)
open_dst
.(
        ldx #35
        lda #0
z       sta dfcb,x
        dex
        bpl z
        lda cdst
        sta dfcb
        ldy #10
c       lda (ep),y
        ldx named
        beq nn
        lda cname,y
nn      sta dfcb+1,y
        dey
        bpl c
        jsr lb_clear            ; progression
        lda #<m_cpy
        ldy #>m_cpy
        jsr lb_str
        jsr dname
        jsr lb_to_msg
        jsr draw_msg
        jsr set_dma0            ; le nom existe-t-il ?
        ldx #F_SFIRST
        jsr bdos_d
        cmp #$FF
        beq make
        lda DEF_DMA+9
        bpl rw
        inc nro                 ; protégé : laissé tel quel
        sec
        rts
rw      lda rall
        bne del
        jsr lb_clear
        lda #<m_repl
        ldy #>m_repl
        jsr lb_str
        jsr dname
        lda #<m_ynt
        ldy #>m_ynt
        jsr lb_str
        jsr lb_to_msg
        lda #<mbuf
        ldy #>mbuf
        jsr ask_key
        cmp #27
        beq esc
        cmp #"T"
        bne o
        sta rall                ; T : tous les suivants
        beq del                 ; (Z=1 depuis cmp)
o       cmp #"O"
        beq del
        cmp #"Y"
        beq del
        sec                     ; non : sauté
        rts
esc     lda #<m_esc
        ldy #>m_esc
        jmp halt
del     ldx #F_DELETE
        jsr bdos_d
make    ldx #F_MAKE
        jsr bdos_d
        cmp #$FF
        bne ok
        lda #<m_dirf
        ldy #>m_dirf
halt    sta errm
        sty errm+1
        inc stopf
        sec
        rts
ok      lda #0
        sta dfcb+32
        lda #1
        sta wr_open
        clc
        rts
dname   lda #<dfcb+1
        ldy #>dfcb+1
        jmp lb_pat
.)

; wr_chunk : écrit la tranche ci (bp avance) ; C=1 si disque plein
wr_chunk
.(
        ldx ci
        lda ch_nl,x
        sta nrec
        lda ch_nh,x
        sta nrec+1
lp      lda nrec
        ora nrec+1
        beq ok
        lda bp
        ldy bp+1
        ldx #F_SETDMA
        jsr BDOS
        ldx #F_WRITE
        jsr bdos_d
        cmp #0
        bne err
        jsr bp_add128
        lda nrec
        bne d
        dec nrec+1
d       dec nrec
        jmp lp
ok      clc
        rts
err     sec
        rts
.)

; adv_chunk : bp passe la tranche ci (fichier sauté)
adv_chunk
        ldx ci
        lda ch_nh,x
        lsr
        lda ch_nl,x
        ror
        pha
        lda #0
        ror
        clc
        adc bp
        sta bp
        pla
        adc bp+1
        sta bp+1
        rts

; end_dst : copie terminée : fermée, attributs de l'original posés
end_dst
.(
        ldx #F_CLOSE
        jsr bdos_d
        lda #0
        sta wr_open
        ldy #E_ATTR
        lda (ep),y
        beq na
        sta t2
        and #$80
        ora dfcb+9
        sta dfcb+9
        lda t2
        asl
        and #$80
        ora dfcb+10
        sta dfcb+10
        ldx #F_ATTRIB
        jsr bdos_d
na      inc ncp
        ldy #E_FLAG
        lda (ep),y
        and #$FF-FL_MARK
        ldx mvf
        beq st
        ora #FL_DEL
st      sta (ep),y
        rts
.)

; kill_dst : copie incomplète fermée puis effacée
kill_dst
        ldx #F_CLOSE
        jsr bdos_d
        ldx #F_DELETE
        jsr bdos_d
        lda #0
        sta wr_open
        rts

; ---------------------------------------------------------------------
; Menus
; ---------------------------------------------------------------------
gq_get  .byt G_GETMODE,0,0,0,0,0
gq_text .byt G_MODE,0,0,0,0,0

bar     .byt 4
        .word mn_f, mn_m, mn_t, mn_v

mn_f    .byt 10,16
        .asc "Fichier",0
        .asc "Voir         RET",0
        .byt MA_TYPE
        .word c81
        .asc "Copier...     ^C",0
        .byt MA_TYPE
        .word c82
        .asc "Deplacer...   ^D",0
        .byt MA_TYPE
        .word c83
        .asc "Renommer...   ^N",0
        .byt MA_TYPE
        .word c84
        .asc "Effacer      DEL",0
        .byt MA_TYPE
        .word c85
        .asc "Attributs...  ^A",0
        .byt MA_TYPE
        .word c86
        .asc "Infos          ?",0
        .byt MA_TYPE
        .word c87
        .asc "Lecteur...    ^L",0
        .byt MA_TYPE
        .word c88
        .asc "Relire        ^R",0
        .byt MA_TYPE
        .word c89
        .asc "Quitter      ESC",0
        .byt MA_TYPE
        .word c8a

mn_m    .byt 6,14
        .asc "Marque",0
        .asc "Marquer    ESP",0
        .byt MA_TYPE
        .word c8b
        .asc "Marquer...   +",0
        .byt MA_TYPE
        .word c8c
        .asc "Oter...      -",0
        .byt MA_TYPE
        .word c8d
        .asc "Inverser     *",0
        .byt MA_TYPE
        .word c8e
        .asc "Tout",0
        .byt MA_TYPE
        .word c8f
        .asc "Rien",0
        .byt MA_TYPE
        .word c90

mn_t    .byt 4,14
        .asc "Trier",0
        .asc "Ordre disque 1",0
        .byt MA_TYPE
        .word c91
        .asc "Nom          2",0
        .byt MA_TYPE
        .word c92
        .asc "Type         3",0
        .byt MA_TYPE
        .word c93
        .asc "Taille       4",0
        .byt MA_TYPE
        .word c94

mn_v    .byt 4,16
        .asc "Vue",0
        .asc "Filtrer...     /",0
        .byt MA_TYPE
        .word c95
        .asc "Sans filtre",0
        .byt MA_TYPE
        .word c96
it_sys  .asc "Cacher SYS ",0
        .byt MA_TYPE
        .word c97
        .asc "Taille exacte ^E",0
        .byt MA_TYPE
        .word c98

s_hide  .asc "Cacher SYS "
s_show  .asc "Montrer SYS"

c81     .byt $81,0
c82     .byt $82,0
c83     .byt $83,0
c84     .byt $84,0
c85     .byt $85,0
c86     .byt $86,0
c87     .byt $87,0
c88     .byt $88,0
c89     .byt $89,0
c8a     .byt $8A,0
c8b     .byt $8B,0
c8c     .byt $8C,0
c8d     .byt $8D,0
c8e     .byt $8E,0
c8f     .byt $8F,0
c90     .byt $90,0
c91     .byt $91,0
c92     .byt $92,0
c93     .byt $93,0
c94     .byt $94,0
c95     .byt $95,0
c96     .byt $96,0
c97     .byt $97,0
c98     .byt $98,0

; ---------------------------------------------------------------------
; Messages (37 colonnes au plus, sans accents)
; ---------------------------------------------------------------------
m_cols  .asc "  NOM      TYP  TAILLE RS   N GENRE",0
m_help  .asc "FUNCT menus  ESP marque  ESC fin",0
m_nodrv .asc "lecteur absent ou illisible",0
m_fic   .asc " fic",0
m_lib   .asc "K libre",0
m_marks .asc " marque(s) : ",0
m_oct   .asc " o",0
m_sep   .asc " : ",0
m_enr   .asc " enr., ",0
m_blk   .asc " bloc(s)",0
m_none  .asc "Aucun fichier",0
m_vmore .asc "-- ESP : suite, ESC : retour --",0
m_vend  .asc "-- Fin du fichier : une touche --",0
m_rerr  .asc "Fichier illisible",0
m_era   .asc "Effacer ",0
m_cop   .asc "Copier ",0
m_mov   .asc "Deplacer ",0
m_nfic  .asc " fichiers",0
m_yn    .asc " (O/N) ?",0
m_ynt   .asc " (O/N/T) ?",0
m_to    .asc " vers : ",0
m_erased .asc " efface(s)",0
m_copied .asc " copie(s)",0
m_moved .asc " deplace(s)",0
m_prot  .asc " protege(s)",0
m_illis .asc " illisible(s)",0
m_bad   .asc "Nom incorrect",0
m_one   .asc "Un nom : un seul fichier",0
m_one1  .asc "Un seul fichier a la fois",0
m_nodst .asc "Destination illisible",0
m_dirf  .asc "Repertoire plein",0
m_full  .asc "Disque plein : copie effacee",0
m_repl  .asc "Remplacer ",0
m_isrc  .asc "SOURCE en ",0
m_idst  .asc "DESTINATION en ",0
m_key   .asc ", une touche",0
m_non   .asc "Non ! ",0
m_rdir  .asc "Lecture du repertoire...",0
m_cpy   .asc "Copie : ",0
m_incpl .asc " incomplet",0
m_esc   .asc "Interrompu",0
m_newn  .asc "Nouveau nom : ",0
m_taken .asc "Nom deja pris",0
m_ro    .asc "Fichier protege (R/O)",0
m_roorig .asc "Original protege (R/O)",0
m_renok .asc "Renomme",0
m_samedrv .asc "Meme lecteur seulement",0
m_attq  .asc "Attributs (R S) : ",0
m_attbad .asc "R et S seulement",0
m_attok .asc "Attributs changes",0
m_markq .asc "Marquer : ",0
m_unmq  .asc "Oter : ",0
m_filtq .asc "Filtre : ",0
m_drvq  .asc "Lecteur (A-D) : ",0
m_drvbad .asc "Lecteur A a D",0
m_wait  .asc "Tailles exactes... (ESC arrete)",0
m_exok  .asc "Tailles exactes",0

; ---------------------------------------------------------------------
; Zones de travail (après le programme, non chargées)
; ---------------------------------------------------------------------
endp
lbuf    = endp                  ; ligne de travail (40)
inbuf   = lbuf+40               ; saisie (24)
mbuf    = inbuf+24              ; message construit (40)
dbuf    = mbuf+40               ; chiffres (8)
tfcb    = dbuf+8                ; FCB de travail (36)
sfcb    = tfcb+36               ; FCB source (36)
dfcb    = sfcb+36               ; FCB destination (36)
fpat    = dfcb+36               ; filtre (11)
pfcb    = fpat+11               ; nom analysé (12)
cname   = pfcb+12               ; autre nom de la copie (11)
curname = cname+11              ; fichier du curseur (11)
vis     = curname+11            ; liste visible (128)
tg      = vis+128               ; fichiers visés (128)
ch_k    = tg+128                ; tranches : fichier, enreg., drapeaux
ch_nl   = ch_k+NCH
ch_nh   = ch_nl+NCH
ch_f    = ch_nh+NCH
ftab    = ch_f+NCH              ; table des fichiers (128 x 24)
bufs    = ftab+NMAX*ESZ         ; noms marqués (relecture), tampon de copie
