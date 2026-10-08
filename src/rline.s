; =====================================================================
;  rline.s — lecture d'une ligne éditable (BDOS 10 et prompt A>)
;
;  Tampon de l'appelant au format CP/M, pointé par ZP_PTR :
;  [max][compte][caractères…]. L'édition se fait dans RLB (126 caractères
;  au plus) ; la ligne est recopiée chez l'appelant à la validation.
;
;  Touches :
;    <- / ->        déplacent le curseur dans la ligne ; ce qu'on tape
;                   s'insère à la position du curseur
;    flèche haut    ligne précédente de l'historique, flèche bas : suivante
;    DEL            efface le caractère à gauche du curseur, CTRL-D celui
;                   sous le curseur
;    CTRL-A/CTRL-E  début / fin de la ligne
;    CTRL-X         efface toute la ligne
;    CTRL-C         sur une ligne vide : démarrage à chaud
;    ESC            (disque) complète le nom de fichier qui finit au
;                   curseur ; si plusieurs noms conviennent et que rien ne
;                   peut être ajouté, les affiche puis réécrit la ligne.
;                   Premier mot d'une ligne du CCP (option CPLCMD) :
;                   commandes internes, et programmes .COM / .BAT sans
;                   leur type
;    RETURN         valide (la ligne entre dans l'historique)
;
;  L'historique HIST garde les lignes validées, la plus récente en tête :
;  [long][caractères]…[0]. Il survit au démarrage à chaud. RLB et HIST
;  sont à la fin du jeu de caractères alternatif ($B800-$BB7F), inutilisé
;  en mode texte ; les menus n'en sauvent que le début (moins de 512
;  octets : les plus grands en prennent une centaine). Le curseur est
;  placé en absolu : (rl_sx, rl_sy) est le début de la ligne à l'écran,
;  corrigé des défilements grâce à scr_n.
; =====================================================================

f_readbuf
read_line
.(
        ldy #0
        lda (ZP_PTR),y
        cmp #RLMAX
        bcc m
        lda #RLMAX
m       sta rl_max
        sty rl_pos
        sty rl_cnt
        sty rl_old
        sty rl_hix
        lda lst_echo            ; pas d'écho imprimante pendant l'édition :
        ora #$80                ; la ligne est imprimée par k_ret
        sta lst_echo
        jsr rl_here
key     jsr conin_raw
        ldx #RL_NKEYS-1
find    cmp rl_keys,x
        beq hit
        dex
        bpl find
        cmp #$20                ; caractère imprimable : inséré
        bcc key
        cmp #$7F
        bcs key
        jsr rl_ins
        jmp key
hit     jsr disp
        jmp key
disp    txa
        asl
        tax
        lda rl_vecs+1,x
        pha
        lda rl_vecs,x
        pha
        rts
.)

;       RETURN <-  ->  haut bas DEL ^D  ^A  ^E  ^X  ^C  ^P  (ESC)
rl_keys .byt $0D,$08,$09,$0B,$0A,$7F,$04,$01,$05,$18,$03,$10
#ifdef DISK
        .byt $1B
#endif
RL_NKEYS = * - rl_keys
rl_vecs .word k_ret-1,k_left-1,k_right-1,k_up-1,k_down-1,k_del-1,k_fdel-1
        .word k_home-1,k_end-1,k_kill-1,k_brk-1,k_prt-1
#ifdef DISK
        .word k_cpl-1
#endif

; rl_here : la ligne commence à la position actuelle du curseur
rl_here
        lda cur_x
        sta rl_sx
        lda cur_y
        sta rl_sy
        lda scr_n
        sta rl_sc
        rts

; DEL : retire le caractère à gauche du curseur
k_del
.(
        ldx rl_pos
        beq r
        dec rl_pos
        dec rl_cnt
loop    lda RLB,x
        sta RLB-1,x
        inx
        cpx rl_cnt
        bcc loop
        beq loop
        lda rl_pos
        bpl rl_ref
r       rts
.)

k_kill
        lda #0
        sta rl_cnt
        sta rl_pos
        beq rl_ref

; rl_ins : insère le caractère A à la position du curseur
rl_ins
.(
        ldx rl_cnt
        cpx rl_max
        bcs full
        inc rl_cnt
        pha
loop    cpx rl_pos
        beq put
        lda RLB-1,x
        sta RLB,x
        dex
        bne loop
put     pla
        sta RLB,x
        lda rl_pos
        inc rl_pos
        bpl rl_ref
full    rts
.)

; rl_ref : réaffiche la ligne à partir de la position A, efface ce qui
;   dépasse de l'ancienne longueur, puis replace le curseur
rl_ref
.(
        pha
        jsr rl_gotoa
        pla
        tax
txt     cpx rl_cnt
        bcs pad
        lda RLB,x
        jsr conout
        inx
        bne txt
pad     cpx rl_old
        bcs done
        lda #" "
        jsr conout
        inx
        bne pad
done    lda rl_cnt
        sta rl_old
.)
rl_goto
        lda rl_pos
; rl_gotoa : place le curseur sur le caractère A de la ligne
rl_gotoa
.(
        sta rl_t
        php
        sei
        lda cur_vis
        beq hid
        jsr cur_toggle
hid     lda scr_n               ; défilements depuis la dernière fois
        tax
        sec
        sbc rl_sc
        stx rl_sc
        eor #$FF
        sec
        adc rl_sy
        sta rl_sy
        tax
        lda rl_sx
        clc
        adc rl_t
row     cmp #COLS
        bcc ok
        sbc #COLS-FIRST_COL
        inx
        bne row
ok      sta cur_x
        stx cur_y
        jsr show_cursor
        plp
        rts
.)

k_left
        lda rl_pos
        beq kl_r
        dec rl_pos
        bpl rl_goto
k_right
        lda rl_pos
        cmp rl_cnt
        beq kl_r
        inc rl_pos
        bne rl_goto
k_fdel                          ; CTRL-D : comme -> puis DEL
        lda rl_pos
        cmp rl_cnt
        beq kl_r
        inc rl_pos
        jmp k_del
k_home
        lda #0
        beq ke_s
k_end
        lda rl_cnt
ke_s    sta rl_pos
        bpl rl_goto
; CTRL-P : copie de la console à l'imprimante, oui / non (aussi
; l'article Imprimante du menu Systeme) ; voyant P de la barre
k_prt
        lda lst_echo
        eor #1
        sta lst_echo
        jmp draw_flags

k_brk
        lda rl_cnt
        bne kl_r
        jmp wboot
kl_r    rts

; flèches haut et bas : parcours de l'historique
k_up
        lda rl_hix
        jsr hist_find
        bcs kl_r
        inc rl_hix
        bcc hist_load
k_down
        lda rl_hix
        beq kl_r
        dec rl_hix
        bne kd_1
        jmp k_kill              ; revenu en bas : ligne vide
kd_1    sec
        sbc #2
        jsr hist_find
; hist_load : X = position d'une entrée -> devient la ligne en cours
hist_load
.(
        lda HIST,x
        cmp rl_max
        bcc ok
        lda rl_max
ok      sta rl_cnt
        sta rl_pos
        ldy #0
loop    cpy rl_cnt
        beq done
        lda HIST+1,x
        sta RLB,y
        inx
        iny
        bne loop
done    lda #0
        jmp rl_ref
.)

; hist_find : A = rang (0 = la plus récente) -> X = position, C=1 si absente
hist_find
.(
        sta rl_t
        ldx #0
loop    lda HIST,x
        beq no
        dec rl_t
        bmi yes
        stx ZP_T0
        sec
        adc ZP_T0
        tax
        bcc loop
no      sec
        rts
yes     clc
        rts
.)

; RETURN : curseur en fin de ligne, ligne rendue à l'appelant et ajoutée
;   à l'historique
k_ret
.(
        pla                     ; quitte read_line directement
        pla
        jsr k_end
        lda lst_echo            ; fin de l'édition ; CTRL-P : la ligne
        and #1                  ; finale à l'imprimante
        sta lst_echo
        beq np
        ldx #0
lp      cpx rl_cnt
        beq np
        lda RLB,x
        jsr bios_list
        inx
        bne lp
np
        ldx rl_cnt
        txa
        ldy #1
        sta (ZP_PTR),y
        tay
        iny
cp      dex
        bmi hist_add
        lda RLB,x
        sta (ZP_PTR),y
        dey
        bne cp
.)
; hist_add : ajoute la ligne en tête de l'historique (sauf vide ou
;   identique à la plus récente)
hist_add
.(
        ldx rl_cnt
        beq end
        cpx HIST
        bne new
same    lda HIST,x
        cmp RLB-1,x
        bne new
        dex
        bne same
end     rts
new     lda #>HIST              ; décale tout de long+1 octets
        sta ZP_PTR2+1           ; (<HIST + RLMAX + 1 < 256 : pas de retenue)
        lda rl_cnt
        sec
        adc #<HIST
        sta ZP_PTR2
        lda #254
        sec
        sbc rl_cnt
        tay
sh      lda HIST,y
        sta (ZP_PTR2),y
        dey
        cpy #$FF
        bne sh
        ldx rl_cnt              ; recopie la ligne en tête
        stx HIST
cp      lda RLB-1,x
        sta HIST,x
        dex
        bne cp
tr      lda HIST,x              ; X = 0 : la dernière entrée qui
        beq end                 ; dépasse est coupée
        stx rl_t
        sec
        adc rl_t
        bcs cut
        tax
        bne tr
cut     ldx rl_t
        lda #0
        sta HIST,x
        rts
.)

#ifdef DISK
; ---------------------------------------------------------------------
; ESC : complétion du nom de fichier qui finit au curseur
; ---------------------------------------------------------------------
k_cpl
.(
        ldx rl_pos              ; début du mot : après un espace ou ':'
        inx
ws      dex
        beq wsd
        lda RLB-1,x
        cmp #" "
        beq wsd
        cmp #":"
        bne ws
wsd     stx cp_ws
#ifdef CPLCMD
        ldy #0                  ; premier mot d'une ligne du CCP ? (pas
        txa                     ; dans LOGO ni DEBUG)
        bne cf
        lda ZP_PTR
        cmp #<CMDBUF
        bne cf
        lda ZP_PTR+1
        cmp #>CMDBUF
        bne cf
        iny
cf      sty cp_first
#endif
        lda cur_drv             ; « B:NOM » : répertoire de B:
        ldy RLB-1,x
        cpy #":"
        bne drv
        lda RLB-2,x
        and #$DF
        sec
        sbc #"A"
drv     jsr drv_select
        bcs r
        lda #0
        sta cp_n
        sta cp_mode
        jsr cp_scan             ; noms qui commencent par le mot
        lda cp_n
        beq r
        cmp #1                  ; un seul : nom complet suivi d'un espace
        bne several
        ldx cp_cl
        lda #" "
        sta cp_com,x
        inc cp_cl
several lda rl_pos
        sec
        sbc cp_ws               ; longueur du mot tapé
        cmp cp_cl
        bcs list                ; rien à ajouter
        tax
ins     lda cp_com,x
        ldy caps                ; sans majuscules : complète en minuscules
        bne ic
        cmp #"A"
        bcc ic
        cmp #"Z"+1
        bcs ic
        ora #$20
ic      stx cp_ws               ; (cp_ws ne sert plus)
        jsr rl_ins
        ldx cp_ws
        inx
        cpx cp_cl
        bcc ins
r       rts
list    lda cp_n                ; plusieurs noms : on les montre
        cmp #2
        bcc r
        lda rl_cnt
        jsr rl_gotoa            ; curseur en fin de ligne
        ldx rl_sy               ; recopie le prompt depuis l'écran
        lda line_lo,x
        sta ZP_PTR2
        lda line_hi,x
        sta ZP_PTR2+1
        ldx #0
        ldy #FIRST_COL
pr      cpy rl_sx
        bcs prd
        cpx #15
        bcs prd
        lda (ZP_PTR2),y
        and #$7F
        sta rl_pr,x
        inx
        iny
        bne pr
prd     stx cp_pl
        jsr crlf
        dec cp_mode             ; bit 7 : affichage
        jsr cp_scan
        lda cp_col
        beq pp0
        jsr crlf
pp0     ldx #0
pp      cpx cp_pl
        beq ppd
        lda rl_pr,x
        jsr conout
        inx
        bne pp
ppd     jsr rl_here             ; la ligne recommence ici
        lda #0
        sta rl_old
        jmp rl_ref
.)

; cp_scan : parcourt le répertoire. Pour chaque fichier (premier extent)
;   dont le nom commence par le mot RLB[cp_ws..rl_pos-1] :
;   cp_mode bit 7 = 0 : compte (cp_n) et réduit le préfixe commun
;   (cp_com, cp_cl) ; = 1 : affiche le nom comme DIR (3 par ligne)
cp_scan
.(
        lda #0
        sta dir_i
        sta cp_col
loop    jsr dir_get
        bcs end
        jsr one
        inc dir_i
        lda dir_i
        cmp #DIR_ENT
        bcc loop
end
#ifdef CPLCMD
        lda cp_first            ; premier mot : aussi les commandes internes
        beq r0
        lda #0
        sta cp_ti
tl      ldx cp_ti               ; une entrée : nom (dernier caractère avec
        lda cmd_table,x         ; le bit 7), adresse ; 0 à la fin
        beq r0
        ldy #0
tc      lda cmd_table,x
        and #$7F
        sta cp_txt,y
        iny
        lda cmd_table,x
        inx
        asl
        bcc tc
        lda #0
        sta cp_txt,y
        inx                     ; adresse
        inx
        stx cp_ti
        jsr cp_cand
        jmp tl
r0
#endif
rone    rts
one     ldy #0
        lda (ZP_DIRP),y         ; utilisateur 0 ($E5 = libre)
        bne rone
        ldy #FCB_EX
        lda (ZP_DIRP),y         ; premier extent seulement
        lsr
        bne rone
        ldy #1                  ; nom -> cp_txt : « NOM.TYP »,0
        ldx #0
fn      lda (ZP_DIRP),y
        and #$7F
        cmp #" "
        beq fs
        sta cp_txt,x
        inx
fs      iny
        cpy #9
        bne fn2
#ifdef CPLCMD
        lda cp_first            ; premier mot : .COM et .BAT seulement,
        beq typ                 ; nommés sans leur type
        jsr cp_cmdty
        bcs rone
        bcc fz
typ
#endif
        lda (ZP_DIRP),y
        and #$7F
        cmp #" "
        beq fz                  ; pas de type
        lda #"."
        sta cp_txt,x
        inx
fn2     cpy #12
        bne fn
fz      lda #0
        sta cp_txt,x
cp_cand ldx cp_ws               ; commence par le mot tapé ?
        ldy #0
cw      cpx rl_pos
        beq ok
        lda RLB,x
        cmp #"a"
        bcc cu
        and #$DF
cu      cmp cp_txt,y
        bne r
        inx
        iny
        bne cw
ok      bit cp_mode
        bmi prt
        ldy #$FF                ; préfixe commun
cm      iny
        lda cp_txt,y
        ldx cp_n
        beq cs
        cpy cp_cl
        bcs cd
        cmp cp_com,y
        beq cm
        bne cd
cs      sta cp_com,y            ; premier nom : recopié (avec le 0)
        tax
        bne cm
cd      sty cp_cl
        inc cp_n
r       rts
prt     ldy #0
p1      lda cp_txt,y
        beq p2
        jsr conout
        iny
        bne p1
p2      lda #" "
        cpy #12
        bcs p3
        jsr conout
        iny
        bne p2
p3      inc cp_col
        ldx cp_col
        cpx #3
        beq pw                  ; 3e colonne : retour à la ligne automatique
        jmp conout
pw      lda #0
        sta cp_col
        rts
.)

#ifdef CPLCMD
; cp_cmdty : C=0 si l'entrée ZP_DIRP est de type COM ou BAT (X gardé)
cp_cmdty
.(
        ldy #9
c1      lda (ZP_DIRP),y
        and #$7F
        cmp type_tab-9,y        ; « COM »
        bne b
        iny
        cpy #12
        bne c1
        clc
        rts
b       ldy #9
c2      lda (ZP_DIRP),y
        and #$7F
        cmp type_tab-6,y        ; « BAT »
        bne no
        iny
        cpy #12
        bne c2
        clc
        rts
no      sec
        rts
.)
#endif
#endif
