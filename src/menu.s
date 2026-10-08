; =====================================================================
;  menu.s — menus déroulants de CP/A
;
;  Moteur réécrit d'après le projet « Menus » de Pierre Garnier
;  (https://github.com/drpsy77/Menus) : barre de menus sur la ligne
;  d'état, ouverture par FUNCT, flèches pour naviguer, ENTER pour
;  valider, ESC pour sortir, zone d'écran sauvegardée et restaurée,
;  mêmes couleurs, même format de table.
;
;  Format d'une barre de menus :
;     .byt nombre_de_menus
;     .word menu1, menu2, ...           (8 menus au plus)
;  Format d'un menu (celui du projet Menus, plus une action par article) :
;     .byt nombre_d_articles, largeur   (largeur = plus long libellé)
;     .asc "Titre",0
;     .asc "Article",0 : .byt type : .word argument     (pour chaque article)
;  Types d'action :
;     MA_TYPE (1) : « tape » la chaîne pointée (terminée par 0) au clavier
;     MA_CALL (2) : appelle la routine (JSR) une fois le menu refermé
;
;  Le menu s'ouvre depuis toute lecture clavier (BIOS CONIN, BDOS 1, 6, 10),
;  donc aussi bien au prompt A> que dans un programme.
;  Un programme peut installer sa propre barre : JSR $C02D avec A/Y = barre.
; =====================================================================

MENU_KEY    = $80       ; code produit par l'appui sur FUNCT
MA_TYPE     = 1
MA_CALL     = 2

MC_BAR      = 3         ; encre des titres (jaune)
MC_HI       = 6         ; encre du titre sélectionné (cyan)
MC_ITEM     = $84       ; attribut d'un article (vidéo inverse)
MC_ISEL     = $81       ; attribut de l'article sélectionné
SAVEBUF     = $B800     ; jeu de caractères alternatif, inutilisé en mode texte

ZP_M1       = $EA       ; menu courant
ZP_M2       = $EC       ; libellé / action
ZP_M3       = $EE       ; écran
ZP_M4       = ZP_DSK    ; tampon de sauvegarde (le pilote disque est inactif ici)

; ---------------------------------------------------------------------
; menu_install : installe la barre A/Y et la dessine
; ---------------------------------------------------------------------
menu_install
.(
        sta ZP_M1
        sty ZP_M1+1
        ldy #0
        lda (ZP_M1),y
        cmp #9
        bcc ok
        lda #8
ok      sta m_cnt
        ldx #0
        iny
cp      cpx m_cnt
        beq pos
        lda (ZP_M1),y
        sta m_lo,x
        iny
        lda (ZP_M1),y
        sta m_hi,x
        iny
        inx
        bne cp
pos     lda #2                  ; colonne du premier titre
        sta m_tmp
        ldx #0
        stx m_cur
loop    cpx m_cnt
        beq done
        lda m_tmp
        sta m_x,x
        stx m_k
        jsr menu_get
        ldy #2
len     lda (ZP_M1),y
        beq endt
        iny
        bne len
endt    tya                     ; colonne suivante = x + longueur + 1
        sec
        sbc #1
        clc
        adc m_tmp
        sta m_tmp
        ldx m_k
        inx
        bne loop
done    jmp bar_draw
.)

; menu_get : X = n° de menu -> ZP_M1
menu_get
        lda m_lo,x
        sta ZP_M1
        lda m_hi,x
        sta ZP_M1+1
        rts

; ---------------------------------------------------------------------
; bar_draw : dessine la barre (ligne 0)
; ---------------------------------------------------------------------
bar_draw
.(
        ldy #0
        lda #ATTR_TEXT50
        sta (ZP_BAR),y
        lda #" "
        ldy #COLS-1
clr     sta (ZP_BAR),y
        dey
        bne clr
        lda #2
        sta m_tmp
        ldx #0
loop    cpx m_cnt
        beq end
        stx m_k
        ldy m_x,x
        lda #MC_BAR
        cpx m_cur
        bne nohi
        ldx m_act
        beq nohi
        lda #MC_HI
nohi    dey                     ; attribut devant le titre
        sta (ZP_BAR),y
        ldx m_k
        jsr menu_get
        lda m_x,x
        sta m_tmp
        ldy #2
tl      lda (ZP_M1),y
        beq tdone
        sty m_ti
        ldy m_tmp
        sta (ZP_BAR),y
        inc m_tmp
        ldy m_ti
        iny
        bne tl
tdone   ldx m_k
        inx
        bne loop
end     ldy m_tmp
        lda #ATTR_INK7
        sta (ZP_BAR),y
        ldy #34
        sta (ZP_BAR),y
        jmp draw_flags
.)

; ---------------------------------------------------------------------
; Articles
; ---------------------------------------------------------------------
; item_get : m_k = n° d'article (1..n) du menu ZP_M1 -> ZP_M2 = libellé
item_get
.(
        lda ZP_M1
        clc
        adc #2
        sta ZP_M2
        lda ZP_M1+1
        adc #0
        sta ZP_M2+1
        jsr skip_str            ; saute le titre
        ldx m_k
loop    dex
        beq done
        jsr skip_str            ; libellé
        lda ZP_M2               ; + 3 octets d'action
        clc
        adc #3
        sta ZP_M2
        bcc loop
        inc ZP_M2+1
        bne loop
done    rts
.)

; skip_str : ZP_M2 avance après la chaîne terminée par 0
skip_str
.(
        ldy #0
loop    lda (ZP_M2),y
        beq z
        iny
        bne loop
z       iny
        tya
        clc
        adc ZP_M2
        sta ZP_M2
        bcc r
        inc ZP_M2+1
r       rts
.)

; drop_geom : dimensions du menu déroulant m_cur
drop_geom
.(
        ldx m_cur
        jsr menu_get
        ldy #0
        lda (ZP_M1),y
        sta m_n
        clc
        adc bar_row
        sta m_last
        iny
        lda (ZP_M1),y
        sta m_w
        clc
        adc #2                  ; attribut devant + attribut de fin
        sta m_tot
        lda m_x,x
        sec
        sbc #1
        sta m_left
        clc
        adc m_tot
        cmp #COLS+1
        bcc ok
        lda #COLS
        sec
        sbc m_tot
        sta m_left
ok      rts
.)

; row_ptr : X = ligne -> ZP_M3 = adresse écran de la colonne m_left
row_ptr
        lda line_lo,x
        clc
        adc m_left
        sta ZP_M3
        lda line_hi,x
        adc #0
        sta ZP_M3+1
        rts

; drop_copy : C=0 sauvegarde l'écran sous le menu, C=1 le restaure
drop_copy
.(
        ror m_tmp               ; bit 7 = sens
        lda #<SAVEBUF
        sta ZP_M4
        lda #>SAVEBUF
        sta ZP_M4+1
        ldx bar_row
        inx
row     jsr row_ptr
        ldy #0
cell    bit m_tmp
        bmi rest
        lda (ZP_M3),y
        sta (ZP_M4),y
        jmp nxt
rest    lda (ZP_M4),y
        sta (ZP_M3),y
nxt     iny
        cpy m_tot
        bne cell
        tya
        clc
        adc ZP_M4
        sta ZP_M4
        bcc nc
        inc ZP_M4+1
nc      inx
        cpx m_last
        bcc row
        beq row
        rts
.)

; draw_item : dessine l'article m_k (sélectionné si m_k = m_item)
draw_item
.(
        lda m_k                 ; ligne écran = barre + n° d'article
        clc
        adc bar_row
        tax
        jsr row_ptr
        ldy #0
        lda #MC_ITEM
        ldx m_k
        cpx m_item
        bne attr
        lda #MC_ISEL
attr    sta (ZP_M3),y
        ldx m_cur
        jsr menu_get
        jsr item_get
        lda #0
        sta m_tmp
        sta m_end
loop    lda m_tmp
        cmp m_w
        beq fin
        tay
        lda m_end
        bne sp
        lda (ZP_M2),y
        bne ch
        inc m_end
sp      lda #" "
ch      ora #$80
        iny
        sta (ZP_M3),y
        inc m_tmp
        jmp loop
fin     iny                     ; attribut de fin : encre normale
        lda cur_ink
        sta (ZP_M3),y
        rts
.)

drop_open
.(
        jsr drop_geom
        clc
        jsr drop_copy
        lda #1
        sta m_open
        sta m_k
loop    jsr draw_item
        inc m_k
        lda m_k
        cmp m_n
        bcc loop
        beq loop
        rts
.)

drop_close
        lda m_open
        beq dc_r
        sec
        jsr drop_copy
        lda #0
        sta m_open
dc_r    rts

; select : passe la sélection à l'article A
select
        pha
        lda m_item
        sta m_k
        pla
        sta m_item
        jsr draw_item           ; l'ancien redevient normal
        lda m_item
        sta m_k
        jmp draw_item

; switch : passe au menu A en gardant le menu déroulé s'il l'était
switch
        pha
        lda m_open
        sta m_end
        jsr drop_close
        pla
        sta m_cur
        jsr bar_draw
        lda m_end
        beq sw_r
        lda #1
        sta m_item
        jmp drop_open
sw_r    rts

; ---------------------------------------------------------------------
; menu_run : appelé par CONIN quand FUNCT a été pressée
; ---------------------------------------------------------------------
menu_run
.(
        txa
        pha
        tya
        pha
        lda m_act
        bne busy
        lda m_cnt
        bne start
busy    jmp out
start   jsr cur_off
        lda #1
        sta m_act
        lda #0
        sta m_open
        sta m_item
        jsr bar_draw

key     jsr conin_key
        ldx #6
find    cmp keys,x
        beq found
        dex
        bpl find
        bmi key
found   lda kvec_hi,x
        pha
        lda kvec_lo,x
        pha
        rts                     ; saut vers le traitement de la touche
keys    .byt $0A,$0B,$08,$09,$0D,$1B,MENU_KEY
kvec_lo .byt <(down-1),<(up-1),<(left-1),<(right-1),<(enter-1),<(quit-1),<(quit-1)
kvec_hi .byt >(down-1),>(up-1),>(left-1),>(right-1),>(enter-1),>(quit-1),>(quit-1)

down    lda m_open
        bne d1
open    lda #1
        sta m_item
        jsr drop_open
        jmp key
dkey    jmp key
d1      lda m_item
        cmp m_n
        bcs dkey
        adc #1
        jsr select
        jmp key

up      lda m_open
        beq dkey
        lda m_item
        cmp #1
        bne u1
        jsr drop_close          ; comme dans Menus : remonter au-dessus
        lda #0                  ; du premier article referme le menu
        sta m_item
        jmp key
u1      sec
        sbc #1
        jsr select
        jmp key

left    lda m_cur
        beq dkey
        sec
        sbc #1
        jsr switch
        jmp key

right   ldx m_cur
        inx
        cpx m_cnt
        bcs dkey
        txa
        jsr switch
        jmp key

enter   lda m_open
        beq open
        ; récupère l'action de l'article
        lda m_item
        sta m_k
        ldx m_cur
        jsr menu_get
        jsr item_get
        jsr skip_str
        ldy #0
        lda (ZP_M2),y
        sta m_type
        iny
        lda (ZP_M2),y
        sta m_arg
        iny
        lda (ZP_M2),y
        sta m_arg+1
        jsr leave
        lda m_type
        cmp #MA_TYPE
        bne call
        lda m_arg
        sta ZP_M2
        lda m_arg+1
        sta ZP_M2+1
        jsr kb_inject
        jmp out
call    cmp #MA_CALL
        bne out
        jsr do_call
        jmp out

quit    jsr leave
out     pla
        tay
        pla
        tax
        rts

leave   jsr drop_close
        lda #0
        sta m_act
        jsr bar_draw
        jmp cur_on
.)

do_call
        jmp (m_arg)

; ---------------------------------------------------------------------
; Curseur et clavier
; ---------------------------------------------------------------------
cur_off
        php
        sei
        lda cur_vis
        beq co_1
        jsr cur_toggle
co_1    lda cur_en
        sta m_savcur
        lda #0
        sta cur_en
        plp
        rts

cur_on
        php
        sei
        lda m_savcur
        sta cur_en
        jsr show_cursor
        plp
        rts

; kb_inject : ajoute la chaîne ZP_M2 (terminée par 0) au tampon clavier
kb_inject
.(
        php
        sei
        ldy #0
loop    lda (ZP_M2),y
        beq end
        ldx kb_head
        sta kb_buf,x
        inx
        txa
        and #KB_MASK
        cmp kb_tail
        beq end                 ; tampon plein
        sta kb_head
        iny
        bne loop
end     plp
        rts
.)

; ---------------------------------------------------------------------
; Actions du menu système
; ---------------------------------------------------------------------
m_ink
.(
        lda cur_ink
loop    clc
        adc #1
        and #7
        cmp cur_paper           ; jamais l'encre de la couleur du papier
        beq loop
        sta cur_ink
        jmp apply_colors
.)

m_paper
.(
        lda cur_paper
loop    clc
        adc #1
        and #7
        cmp cur_ink
        beq loop
        sta cur_paper
.)
; apply_colors : réécrit papier et encre en tête de chaque ligne
apply_colors
.(
        ldx con_first
loop    lda line_lo,x
        sta ZP_M3
        lda line_hi,x
        sta ZP_M3+1
        ldy #0
        lda cur_paper
        ora #$10
        sta (ZP_M3),y
        iny
        lda cur_ink
        sta (ZP_M3),y
        inx
        cpx #LAST_ROW+1
        bne loop
        rts
.)

m_caps
        lda caps
        eor #1
        sta caps
        jmp draw_flags

m_kfast
        lda #12
        ldx #2
        bne m_kset
m_knorm
        lda #25
        ldx #3
        bne m_kset
m_kslow
        lda #40
        ldx #6
m_kset  sta kb_delay
        stx kb_rate
        rts

m_reboot
        jmp wboot

#ifdef DISK
; m_drive : tape « X: » pour passer au lecteur suivant (A B C D A...)
m_drive
        ldx cur_drv
        inx
        txa
        and #NDRV-1
        clc
        adc #"A"
        sta ty_drv+1            ; (le système est en RAM)
        lda #<ty_drv
        sta ZP_M2
        lda #>ty_drv
        sta ZP_M2+1
        jmp kb_inject
ty_drv  .byt $18
        .asc "A:",13,0
#endif

; ---------------------------------------------------------------------
; Barre de menus du système
; ---------------------------------------------------------------------
sys_bar
#ifdef DISK
        .byt 4
        .word mn_sys, mn_fic, mn_ecr, mn_clv
#else
        .byt 3
        .word mn_sys, mn_ecr, mn_clv
#endif

#ifdef DISK
mn_sys  .byt 6,15
#else
mn_sys  .byt 5,10
#endif
        .asc "Systeme",0
        .asc "Version",0
        .byt MA_TYPE
        .word ty_ver
        .asc "Aide",0
        .byt MA_TYPE
        .word ty_help
        .asc "Memoire",0
        .byt MA_TYPE
        .word ty_mem
        .asc "Imprimante",0
        .byt MA_CALL
        .word k_prt
#ifdef DISK
        .asc "Lecteur suivant",0
        .byt MA_CALL
        .word m_drive
#endif
        .asc "Redemarrer",0
        .byt MA_CALL
        .word m_reboot

#ifdef DISK
mn_fic  .byt 5,11
        .asc "Fichiers",0
        .asc "Catalogue",0
        .byt MA_TYPE
        .word ty_dir
        .asc "Afficher...",0
        .byt MA_TYPE
        .word ty_type
        .asc "Copier...",0
        .byt MA_TYPE
        .word ty_copy
        .asc "Renommer...",0
        .byt MA_TYPE
        .word ty_ren
        .asc "Effacer...",0
        .byt MA_TYPE
        .word ty_era
#endif

mn_ecr  .byt 6,10
        .asc "Ecran",0
        .asc "Mode SPLIT",0
        .byt MA_TYPE
        .word ty_split
        .asc "Mode texte",0
        .byt MA_TYPE
        .word ty_text
        .asc "Effacer",0
        .byt MA_TYPE
        .word ty_cls
        .asc "Encre",0
        .byt MA_CALL
        .word m_ink
        .asc "Papier",0
        .byt MA_CALL
        .word m_paper
        .asc "Majuscules",0
        .byt MA_CALL
        .word m_caps

mn_clv  .byt 3,6
        .asc "Clavier",0
        .asc "Rapide",0
        .byt MA_CALL
        .word m_kfast
        .asc "Normal",0
        .byt MA_CALL
        .word m_knorm
        .asc "Lent",0
        .byt MA_CALL
        .word m_kslow

; Commandes tapées pour l'utilisateur ($18 = CTRL-X efface la ligne en cours ;
; sans retour chariot final, il complète lui-même la commande)
ty_ver  .byt $18
        .asc "VER",13,0
ty_help .byt $18
        .asc "HELP",13,0
ty_mem  .byt $18
#ifdef DISK
        .asc "HELP MEM",13,0
#else
        .asc "MEM",13,0
#endif
ty_split .byt $18
        .asc "SPLIT",13,0
ty_text .byt $18
        .asc "TEXT",13,0
ty_cls  .byt $18
        .asc "CLS",13,0
#ifdef DISK
ty_dir  .byt $18
        .asc "DIR",13,0
ty_type .byt $18
        .asc "TYPE ",0
ty_copy .byt $18
        .asc "COPY ",0
ty_ren  .byt $18
        .asc "REN ",0
ty_era  .byt $18
        .asc "ERA ",0
#endif
