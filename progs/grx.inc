; =====================================================================
;  grx.inc — bibliothèque d'exécution des programmes traduits par
;  GRAPHER NOM /A (NOM.GRX -> NOM.ASM). Incluse par NOM.ASM, avant
;  hires.inc ; jamais assemblée seule.
;
;  Modèle : la valeur d'une expression est dans g_ev ; l'opérande de
;  gauche d'une opération dans g_et (g_pop le reprend sur la pile des
;  valeurs, où g_push l'a mis). Variables V_A à V_Z (2 octets).
;  Une boucle a 4 octets Bn : compte (REPEAT), ou arrivée et pas (FOR).
;  Les textes (GTEXT, ECHO) et les noms d'images (GLOAD, GSAVE) suivent
;  l'appel dans le code (g_str les y prend).
;  Page zéro : $10-$25. ESC est testé à chaque tour de boucle (NEXT) et
;  par WAIT.
; =====================================================================

g_ev    = $10           ; valeur (2 octets)
g_et    = $12           ; opérande de gauche (2 octets)
g_mt    = $14           ; multiplication, comparaison (2 octets)
g_mr    = $16           ; reste (2 octets)
g_sg    = $18           ; signes de la division (2 octets)
g_seed  = $1A           ; hasard (2 octets)
g_vsp   = $1C           ; pile des valeurs
g_pk    = $1D           ; touche gardée par le test d'ESC
g_sp    = $1E           ; pile du 6502 au lancement
g_gd    = $1F
g_t     = $20           ; adresse du texte suivant l'appel (2 octets)
g_ip    = $22           ; (2 octets)
g_lx    = $24
g_fl    = $25

g_init
.(
        tsx                     ; pile telle qu'au lancement du programme
        inx
        inx
        stx g_sp
        lda SYS_TICKS           ; graine du hasard
        sta g_seed
        lda SYS_TICKS+1
        ora #1
        sta g_seed+1
        lda #0
        sta g_vsp
        sta g_pk
        ldx #51
z       sta g_vars,x
        dex
        bpl z
        jsr h_init
        lda #G_GETMODE          ; lancé en mode SPLIT : on y reste
        jsr h_gfx
        cmp #1
        bne r
        lda #128
        sta h_lines
r       rts
.)

; g_end : fin normale (une image plein écran attend une touche)
g_end
.(
        lda h_lines
        cmp #200
        bne r
        jsr g_getkey
        jsr h_text
r       ldx g_sp
        txs
        rts
.)

; a_fail : erreur ou ESC dans ANIM (anim.inc, inclus seulement si le
;   programme anime) : même arrêt que les autres erreurs
a_fail  = g_stop

; g_stop : message A/Y (0 à la fin), puis fin du programme
g_stop
        pha
        tya
        pha
        lda h_lines             ; pas de console en HIRES plein écran
        cmp #200
        bne gs1
        jsr h_text
gs1     pla
        tay
        pla
        jsr g_puts
        jsr g_crlf
        ldx g_sp
        txs
        rts

; g_brk : ESC arrête ; une autre touche est gardée (WAIT, INKEY, fin)
g_brk
.(
        jsr B_CONST
        beq r
        jsr h_key
        sta g_pk
        cmp #27
        bne r
        lda #<g_m_esc
        ldy #>g_m_esc
        jmp g_stop
r       rts
.)

g_getkey
        lda g_pk
        beq gk1
        ldx #0
        stx g_pk
        rts
gk1     jmp h_key

; ---------------------------------------------------------------------
; Pile des valeurs et opérations (g_et op g_ev -> g_ev)
; ---------------------------------------------------------------------
g_push
.(
        ldy g_vsp
        cpy #24
        bcs deep
        lda g_ev
        sta g_vlo,y
        lda g_ev+1
        sta g_vhi,y
        inc g_vsp
        rts
deep    lda #<g_m_deep
        ldy #>g_m_deep
        jmp g_stop
.)

g_pop   dec g_vsp
        ldy g_vsp
        lda g_vlo,y
        sta g_et
        lda g_vhi,y
        sta g_et+1
        rts

g_add   clc
        lda g_et
        adc g_ev
        sta g_ev
        lda g_et+1
        adc g_ev+1
        sta g_ev+1
        rts

g_sub   sec
        lda g_et
        sbc g_ev
        sta g_ev
        lda g_et+1
        sbc g_ev+1
        sta g_ev+1
        rts

g_and   lda g_et
        and g_ev
        sta g_ev
        lda g_et+1
        and g_ev+1
        sta g_ev+1
        rts

g_or    lda g_et
        ora g_ev
        sta g_ev
        lda g_et+1
        ora g_ev+1
        sta g_ev+1
        rts

g_neg   sec
        lda #0
        sbc g_ev
        sta g_ev
        lda #0
        sbc g_ev+1
        sta g_ev+1
        rts

; g_mul : g_ev <- g_et * g_ev (16 bits bas)
g_mul
.(
        lda #0
        sta g_mt
        sta g_mt+1
        ldx #16
loop    lsr g_ev+1
        ror g_ev
        bcc no
        clc
        lda g_mt
        adc g_et
        sta g_mt
        lda g_mt+1
        adc g_et+1
        sta g_mt+1
no      asl g_et
        rol g_et+1
        dex
        bne loop
        lda g_mt
        sta g_ev
        lda g_mt+1
        sta g_ev+1
        rts
.)

; g_udiv : g_et / g_ev (non signés) -> g_et quotient, g_mr reste
g_udiv
.(
        lda #0
        sta g_mr
        sta g_mr+1
        ldx #16
loop    asl g_et
        rol g_et+1
        rol g_mr
        rol g_mr+1
        sec
        lda g_mr
        sbc g_ev
        tay
        lda g_mr+1
        sbc g_ev+1
        bcc no
        sta g_mr+1
        sty g_mr
        inc g_et
no      dex
        bne loop
        rts
.)

; g_div / g_mod : division signée (quotient tronqué vers 0, reste du
;   signe du dividende)
g_mod   jsr g_sdiv
        lda g_mr
        sta g_ev
        lda g_mr+1
        sta g_ev+1
        rts
g_div
g_sdiv
.(
        lda g_ev
        ora g_ev+1
        bne ok
        lda #<g_m_div
        ldy #>g_m_div
        jmp g_stop
ok      lda g_et+1
        sta g_sg
        eor g_ev+1
        sta g_sg+1
        lda g_et+1
        bpl p1
        sec
        lda #0
        sbc g_et
        sta g_et
        lda #0
        sbc g_et+1
        sta g_et+1
p1      lda g_ev+1
        bpl p2
        jsr g_neg
p2      jsr g_udiv
        lda g_et
        sta g_ev
        lda g_et+1
        sta g_ev+1
        bit g_sg+1
        bpl p3
        jsr g_neg
p3      bit g_sg
        bpl r
        sec
        lda #0
        sbc g_mr
        sta g_mr
        lda #0
        sbc g_mr+1
        sta g_mr+1
r       rts
.)

; g_cmp : X = 1 =, 2 <>, 3 <, 4 <=, 5 >, 6 >= ; g_ev <- 1 ou 0
g_cmp
.(
        sec
        lda g_et
        sbc g_ev
        sta g_mt
        lda g_et+1
        sbc g_ev+1
        sta g_mt+1
        ora g_mt                ; (ORA et LDA laissent V)
        sta g_mt
        lda g_mt+1
        bvc nv
        eor #$80
nv      and #$80
        sta g_mt+1              ; $80 si g_et < g_ev
        lda #0
        sta g_ev+1
        cpx #1
        beq eq
        cpx #2
        beq ne
        cpx #3
        beq lt
        cpx #4
        beq le
        cpx #5
        beq gt
        lda g_mt+1              ; >=
        beq yes
        bne no
eq      lda g_mt
        beq yes
        bne no
ne      lda g_mt
        bne yes
        beq no
lt      lda g_mt+1
        bne yes
        beq no
le      lda g_mt+1
        bne yes
        lda g_mt
        beq yes
        bne no
gt      lda g_mt+1
        bne no
        lda g_mt
        bne yes
no      lda #0
        sta g_ev
        rts
yes     lda #1
        sta g_ev
        rts
.)

; ---------------------------------------------------------------------
; Fonctions
; ---------------------------------------------------------------------
; g_rnd : g_ev <- nombre au hasard de 0 à g_ev - 1 (0 si g_ev <= 0)
g_rnd
.(
        lda g_ev+1
        bmi zero
        ora g_ev
        beq zero
        lda g_seed               ; g_rnd = g_rnd * 5 + 13849
        sta g_et
        lda g_seed+1
        sta g_et+1
        asl g_seed
        rol g_seed+1
        asl g_seed
        rol g_seed+1
        clc
        lda g_seed
        adc g_et
        sta g_seed
        lda g_seed+1
        adc g_et+1
        sta g_seed+1
        clc
        lda g_seed
        adc #<13849
        sta g_seed
        lda g_seed+1
        adc #>13849
        sta g_seed+1
        sta g_et                ; octets échangés
        lda g_seed
        and #$7F
        sta g_et+1
        jsr g_udiv
        lda g_mr
        sta g_ev
        lda g_mr+1
        sta g_ev+1
        rts
zero    lda #0
        sta g_ev
        sta g_ev+1
        rts
.)

g_abs   lda g_ev+1
        bpl ga1
        jmp g_neg
ga1     rts

; g_point : g_et = x, g_ev = y -> 1 si le point est allumé
g_point
.(
        lda h_lines
        beq zero
        lda g_et+1
        ora g_ev+1
        bne zero
        lda h_x1                ; les paramètres en cours sont gardés
        pha
        lda h_y1
        pha
        lda g_et
        sta h_x1
        lda g_ev
        sta h_y1
        jsr h_point
        sta g_ev
        pla
        sta h_y1
        pla
        sta h_x1
        lda #0
        sta g_ev+1
        rts
zero    lda #0
        sta g_ev
        sta g_ev+1
        rts
.)

; g_inkey : touche tapée (0 si aucune), sans attendre
g_inkey
.(
        lda g_pk
        ldx #0
        stx g_pk
        cmp #0
        bne r
        jsr B_CONST
        beq r
        jsr h_key
r       sta g_ev
        lda #0
        sta g_ev+1
        rts
.)

; g_byte : A <- g_ev, qui doit aller de 0 à 255
g_byte
        lda g_ev+1
        bne gb_bad
        lda g_ev
        rts
gb_bad  lda #<g_m_range
        ldy #>g_m_range
        jmp g_stop

; ---------------------------------------------------------------------
; Commandes
; ---------------------------------------------------------------------
g_cls   lda h_lines             ; rien hors du mode HIRES ou SPLIT
        beq gc_r
        jmp h_cls
gc_r    rts

g_print
        lda h_lines
        cmp #200
        beq gp_r
        jsr g_fmt
        lda #<g_num
        ldy #>g_num
        jsr g_puts
        jmp g_crlf
gp_r    rts

g_gnum  jsr g_fmt
        lda #<g_num
        ldy #>g_num
        jmp h_print

; g_str : (à appeler en premier par la routine) g_t <- adresse du texte
;   qui suit l'appel de la routine ; celle-ci reviendra après lui
; g_nm : de même pour un nom d'image (lecteur + 11 caractères, sans 0
;   final : le lecteur courant s'écrit 0)
g_nm    lda #11                 ; dernier octet du nom
        bne g_st0
g_str   lda #0                  ; texte : jusqu'au 0
g_st0
.(
        sta g_ln
        pla                     ; notre retour
        sta g_ip
        pla
        sta g_ip+1
        pla                     ; retour de la routine : texte - 1
        sta g_t
        pla
        sta g_t+1
        inc g_t
        bne t1
        inc g_t+1
t1      ldy g_ln                ; fin du nom, ou du texte
        bne e
l       lda (g_t),y
        beq e
        iny
        bne l
e       tya                     ; retour de la routine : le 0 final
        clc
        adc g_t
        tax
        lda g_t+1
        adc #0
        pha
        txa
        pha
        lda g_ip+1              ; et notre retour
        pha
        lda g_ip
        pha
        rts
.)

g_gtext jsr g_str
        lda g_t
        ldy g_t+1
        jmp h_print

g_echo  jsr g_str
        lda h_lines
        cmp #200
        beq ge_r
        lda g_t
        ldy g_t+1
        jsr g_puts
        jmp g_crlf
ge_r    rts

g_wait
.(
        jsr g_getkey
        cmp #27
        bne r
        lda #<g_m_esc
        ldy #>g_m_esc
        jmp g_stop
r       rts
.)

; g_delay : g_ev cinquantièmes de seconde
g_delay
.(
        clc
        lda SYS_TICKS
        adc g_ev
        sta g_mt
        lda SYS_TICKS+1
        adc g_ev+1
        sta g_mt+1
w       sec
        lda SYS_TICKS
        sbc g_mt
        lda SYS_TICKS+1
        sbc g_mt+1
        bmi w
        rts
.)

; g_gload / g_gsave : nom (lecteur, 8 + 3 caractères) après l'appel ;
;   type vide : .HIR en HIRES, .IMG en SPLIT ; depuis le mode texte,
;   GLOAD choisit le mode d'après le type (HIR par défaut)
g_gload
.(
        jsr g_nm
        jsr g_fcb
        lda h_lines
        bne mode
        jsr g_isimg
        beq spl
        jsr h_full
        jmp ld
spl     lda #128
        sta h_lines
        jmp ld
mode    jsr g_deftype
ld      lda #<g_fcbuf
        ldy #>g_fcbuf
        jsr h_load
        cmp #0
        beq r
        lda #G_GETMODE          ; SPLIT sans image : on est resté en texte
        jsr h_gfx
        cmp #0
        bne nf
        sta h_lines
nf      lda #<g_m_noimg
        ldy #>g_m_noimg
        jmp g_stop
r       rts
.)

g_gsave
.(
        jsr g_nm
        jsr g_fcb
        lda h_lines
        beq r
        jsr g_deftype
        lda #<g_fcbuf
        ldy #>g_fcbuf
        jsr h_save
        cmp #0
        beq r
        lda #<g_m_full
        ldy #>g_m_full
        jmp g_stop
r       rts
.)

; g_fcb : 12 octets du texte (g_t) -> g_fcbuf, le reste à 0
g_fcb
.(
        ldy #0
l       lda (g_t),y
        sta g_fcbuf,y
        iny
        cpy #12
        bne l
        lda #0
z       sta g_fcbuf,y
        iny
        cpy #36
        bne z
        rts
.)

g_deftype
.(
        lda g_fcbuf+9
        cmp #" "
        bne r
        ldx #2
        ldy #2
        lda h_lines
        cmp #200
        bne l
        ldy #5
l       lda g_timg,y
        sta g_fcbuf+9,x
        dey
        dex
        bpl l
r       rts
.)

; g_isimg : Z=1 si le type est IMG (type vide : HIR, mis ici)
g_isimg
.(
        lda g_fcbuf+9
        cmp #" "
        bne t
        ldx #2
d       lda g_thir,x
        sta g_fcbuf+9,x
        dex
        bpl d
t       ldx #2
l       lda g_fcbuf+9,x
        cmp g_timg,x
        bne r
        dex
        bpl l
        lda #0
r       rts
.)

; ---------------------------------------------------------------------
; Boucles
; ---------------------------------------------------------------------
; g_rept : A/Y = compte (REPEAT) ; C=1 s'il est <= 0, sinon il diminue
;   de 1 et C=0
g_rept
.(
        sta g_t
        sty g_t+1
        ldy #1
        lda (g_t),y
        bmi end
        dey
        ora (g_t),y
        beq end
        lda (g_t),y             ; compte - 1
        sec
        sbc #1
        sta (g_t),y
        iny
        lda (g_t),y
        sbc #0
        sta (g_t),y
        clc
        rts
end     sec
        rts
.)

; g_forok : A/Y = arrivée, pas ; X = variable (0 à 50) ; C=1 si elle a
;   dépassé l'arrivée (pas > 0 : var > arrivée ; pas < 0 : var < arrivée)
g_forok
.(
        sta g_t
        sty g_t+1
        ldy #2                  ; pas nul : erreur
        lda (g_t),y
        iny
        ora (g_t),y
        bne ok
        lda #<g_m_step
        ldy #>g_m_step
        jmp g_stop
ok      sec                     ; var - arrivée (signé)
        ldy #0
        lda g_vars,x
        sbc (g_t),y
        sta g_mt
        iny
        lda g_vars+1,x
        sbc (g_t),y
        sta g_mt+1
        ora g_mt
        sta g_gd                ; 0 : égaux
        lda g_mt+1
        bvc nv
        eor #$80
nv      sta g_mt+1              ; bit 7 : var < arrivée
        ldy #3
        lda (g_t),y
        bmi down
        lda g_gd
        beq in
        lda g_mt+1
        bmi in
        sec
        rts
down    lda g_mt+1
        bpl in
        sec
        rts
in      clc
        rts
.)

; g_forstep : var X += pas (A/Y) ; C=1 en cas de dépassement (fin)
g_forstep
.(
        sta g_t
        sty g_t+1
        ldy #2
        clc
        lda g_vars,x
        adc (g_t),y
        sta g_vars,x
        iny
        lda g_vars+1,x
        adc (g_t),y
        sta g_vars+1,x
        clc
        bvc r
        sec
r       rts
.)

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
g_putc  ldx #F_CONOUT
        jmp BDOS
g_crlf  lda #13
        jsr g_putc
        lda #10
        jmp g_putc

g_puts
.(
        sta g_ip
        sty g_ip+1
        ldy #0
loop    lda (g_ip),y
        beq r
        sty g_gd
        jsr g_putc
        ldy g_gd
        iny
        bne loop
r       rts
.)

; g_fmt : g_ev (signé) -> g_num, en décimal
g_fmt
.(
        ldy #0
        lda g_ev+1
        bpl pos
        jsr g_neg
        lda #"-"
        sta g_num
        iny
pos     sty g_gd
        lda #0
        sta g_lx
        ldx #0
dig     ldy #0
sub     sec
        lda g_ev
        sbc g_dlo,x
        pha
        lda g_ev+1
        sbc g_dhi,x
        bcc dn
        sta g_ev+1
        pla
        sta g_ev
        iny
        bne sub
dn      pla
        tya
        bne show
        lda g_lx
        beq nx
        tya
show    ora #"0"
        ldy g_gd
        sta g_num,y
        inc g_gd
        sta g_lx
nx      inx
        cpx #4
        bne dig
        lda g_ev
        ora #"0"
        ldy g_gd
        sta g_num,y
        iny
        lda #0
        sta g_num,y
        rts
.)
g_dlo   .byt <10000,<1000,<100,<10
g_dhi   .byt >10000,>1000,>100,>10

g_timg  .asc "IMG"
g_thir  .asc "HIR"
g_m_esc   .asc "Interrompu",0
g_m_div   .asc "Erreur : division par zero",0
g_m_range .asc "Erreur : valeur hors de 0-255",0
g_m_step  .asc "Erreur : pas nul",0
g_m_deep  .asc "Erreur : expression trop longue",0
g_m_noimg .asc "Erreur : image introuvable",0
g_m_full  .asc "Erreur : disque plein",0

g_num   .dsb 8,0
g_fcbuf .dsb 36,0
g_ln    .byt 0
g_vlo   .dsb 24,0
g_vhi   .dsb 24,0
g_vars  .dsb 52,0
V_A     = g_vars
V_B     = g_vars+2
V_C     = g_vars+4
V_D     = g_vars+6
V_E     = g_vars+8
V_F     = g_vars+10
V_G     = g_vars+12
V_H     = g_vars+14
V_I     = g_vars+16
V_J     = g_vars+18
V_K     = g_vars+20
V_L     = g_vars+22
V_M     = g_vars+24
V_N     = g_vars+26
V_O     = g_vars+28
V_P     = g_vars+30
V_Q     = g_vars+32
V_R     = g_vars+34
V_S     = g_vars+36
V_T     = g_vars+38
V_U     = g_vars+40
V_V     = g_vars+42
V_W     = g_vars+44
V_X     = g_vars+46
V_Y     = g_vars+48
V_Z     = g_vars+50
