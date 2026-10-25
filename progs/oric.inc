; =====================================================================
;  oric.inc — socle des programmes traduits par GRXASM NOM /O : un
;  programme GRAPHER qui tourne sur un Oric seul (Atmos ou Oric-1), sans
;  CP/A ni BASIC, chargé par CLOAD depuis NOM.TAP. Remplace CPA.INC :
;  il fournit aux bibliothèques (GRX.INC, HIRES.INC, ARR.INC, FIL.INC,
;  SPR.INC, ANIM.INC, inchangées) ce qu'elles demandent au système, avec
;  les routines de CP/A recopiées et aucun appel à la ROM.
;
;  Recopiée par GRXASM avant HIRES.INC (routines utiles seulement,
;  tools/mark_inc.py) ; jamais assemblée seule.
;
;    o_init   en tête du programme (avant G_INIT) : prend la machine
;             (pile, interruptions, VIA, AY, clavier, écran texte) ; le
;             programme reviendra dans o_end
;    o_end    fin (END, fin du texte, erreur) : si la console a du texte,
;             une touche d'abord ; puis la ROM redémarre (comme RESET)
;    BDOS     X = fonction, A/Y = paramètre, comme le BDOS de CP/A, pour
;             les seules fonctions dont les bibliothèques se servent :
;               2  console (texte seulement : lignes 1 à 27)
;               10 saisie d'une ligne (INPUT hors du LORES)
;               15, 20  ouverture et lecture des fichiers inclus dans le
;                  programme par GRXASM (O_FILES, plus bas) ; 16, 26
;               115  mode texte (op 10), mode (op 11 : toujours 0)
;               116  un bip (le bloc est ignoré : rz_bip)
;             autre fonction : A = $FF (écriture : refusée à la traduction)
;    B_CONST, B_CONIN   touche en attente ? attente d'une touche
;    SYS_TICKS, KB_HELD comme sous CP/A (compteur 50 Hz, touche tenue)
;
;  Machine : les vecteurs IRQ et NMI de la ROM ($FFFE, $FFFA) pointent
;  en page 2 ($0244 et $0247 sur l'Atmos, $0228 et $022B sur l'Oric-1) :
;  o_init y écrit ses JMP, à l'adresse que donne la ROM. RESET (NMI), un
;  BRK et la fin du programme redémarrent la ROM (JMP ($FFFC)).
;  Variables en page 2 (hors des vecteurs de la ROM), DMA par défaut en
;  $0480. Page zéro : $E0-$EF (hors interruption), $FA (interruption).
;
;  Fichiers inclus : GRXASM écrit O_FILES dans NOM.ASM, une entrée par
;  fichier lu par LOAD, BLOAD, GLOAD ou ANIM (nom constant, lu sur le
;  disque au moment de la traduction) : nom (8 + 3 caractères), nombre
;  d'enregistrements de 128 octets, puis les enregistrements ; un 0 à la
;  fin de la liste. o_open met dans le FCB (octets 16-18) l'adresse des
;  données et les enregistrements restants. Un nom absent : $FF (FOUND
;  vaut 0, GLOAD et ANIM s'arrêtent sur leur erreur, comme sous CP/A).
;
;  Annotations pour tools/mark_inc.py (gardées par strip_inc.py) :
;    ;>a b   la routine a (d'une autre bibliothèque) a besoin de b : elle
;            appelle BDOS avec le numéro de la fonction que b traite
;    ;&b     les lignes qui suivent appartiennent à la routine b (gardées
;            seulement avec elle) ; ;& seul : fin
; =====================================================================

;>rz_get o_rdl
;>rz_bip o_snd
;>f_ropen o_open
;>f_getb o_read
;>h_load o_open o_read
;>h_zread o_open o_read

; --- noms de CPA.INC dont les bibliothèques se servent ---
F_CONOUT = 2
F_OPEN  = 15
F_CLOSE = 16
F_DELETE = 19
F_READ  = 20
F_WRITE = 21
F_MAKE  = 22
F_RENAME = 23
F_SETDMA = 26
F_RDL   = 10
F_GFX   = 115
F_SND   = 116
G_MODE  = 10
G_GETMODE = 11
G_GSAVE = 12
G_GLOAD = 13
S_NOTE  = 1
SCREEN  = $BB80
DEF_DMA = $0480
TPA_TOP = $020C
SCR_PROG = $020E
CON_CURVIS = $0212
CON_CUREN = $0213
KB_HELD = $0217         ; touche tenue (index dans la matrice) ou $FF
SYS_TICKS = $021B       ; compteur 50 Hz (2 octets)

; --- matériel (comme src/hw.inc) ---
O_ORB   = $0300
O_DDRB  = $0302
O_DDRA  = $0303
O_T1CL  = $0304
O_T1CH  = $0305
O_ACR   = $030B
O_PCR   = $030C
O_IFR   = $030D
O_IER   = $030E
O_ORA   = $030F         ; port A sans poignée de main (bus de l'AY)
O_IDLE  = $DD           ; AY inactif
O_LATCH = $FF           ;   sélection de registre
O_WRITE = $FD           ;   écriture
O_T1    = 19966         ; une trame (312 x 64 cycles) : 50 Hz
O_MODE  = $BFDF         ; dernière case de l'écran : $1A texte, $1E HIRES
O_FONT  = $B500         ; police du mode texte, codes 32 à 127

; --- variables (page 2) ---
o_khd   = $0215         ; tampon du clavier : tête,
o_ktl   = $0216         ;   queue
o_kmod  = $0219         ; bit 0 SHIFT, bit 1 CTRL
o_krep  = $021D         ; délai avant la répétition suivante
o_krow  = $021E
o_caps  = $021F         ; 1 : majuscules (CTRL-T dans la console)
o_cx    = $0220         ; console : colonne (2-39)
o_cy    = $0221         ;   ligne (1-27)
o_used  = $0222         ; 1 : la console a du texte
o_bipd  = $0223         ; durée du bip (1/50 s)
o_kbuf  = $0230         ; 16 octets
; --- page zéro ---
oz_p    = $E0
oz_q    = $E2
oz_d    = $E4           ; DMA
oz_a    = $E6
oz_y    = $E7
oz_mx   = $E8
oz_n    = $E9
oz_x    = $EA
oz_t    = $EB           ; (2 octets)
oz_i    = $FA           ; réservé à l'interruption

; ---------------------------------------------------------------------
; o_init : appelée par la première instruction du programme
; ---------------------------------------------------------------------
o_init
.(
        sei
        cld
        pla                     ; retour dans le programme
        sta oz_t
        pla
        sta oz_t+1
        ldx #$FF                ; pile vide : le programme reviendra
        txs                     ;   dans o_end (g_end, g_stop)
        lda #>(o_end-1)
        pha
        lda #<(o_end-1)
        pha
        lda oz_t+1
        pha
        lda oz_t
        pha
        lda #$7F                ; VIA : plus d'interruptions
        sta O_IER
        lda $FFFE               ; JMP o_irq où la ROM envoie l'IRQ
        sta oz_p
        lda $FFFF
        sta oz_p+1
        lda #<o_irq
        ldx #>o_irq
        jsr v
        lda $FFFA               ; et JMP o_nmi pour la NMI (RESET)
        sta oz_p
        lda $FFFB
        sta oz_p+1
        lda #<o_nmi
        ldx #>o_nmi
        jsr v
        lda #$FF
        sta O_DDRA              ; port A en sortie (bus de l'AY)
        sta KB_HELD
        lda #$F7
        sta O_DDRB              ; PB3 en entrée (clavier)
        lda #$10
        sta O_ORB
        lda #O_IDLE
        sta O_PCR
        lda #$40
        sta O_ACR               ; T1 continu
        ldx #13                 ; AY silencieux, port A en sortie
ay      lda #0
        cpx #7
        bne ay1
        lda #$7F
ay1     jsr o_ay
        dex
        bpl ay
        lda #0
        sta o_khd
        sta o_ktl
        sta o_kmod
        sta o_bipd
        sta SCR_PROG
        sta SYS_TICKS
        sta SYS_TICKS+1
        lda #<DEF_DMA
        sta oz_d
        lda #>DEF_DMA
        sta oz_d+1
        lda #1
        sta o_caps
        jsr o_cls
        lda #$1A                ; texte 50 Hz
        sta O_MODE
        lda #<O_T1
        sta O_T1CL
        lda #>O_T1
        sta O_T1CH              ; le compteur part
        lda #$C0
        sta O_IER               ; interruption de T1
        cli
        rts
v       ldy #0                  ; JMP A/X en (oz_p)
        pha
        lda #$4C
        sta (oz_p),y
        iny
        pla
        sta (oz_p),y
        iny
        txa
        sta (oz_p),y
        rts
.)

; o_end : fin du programme : une touche si la console a du texte, puis la
;   ROM redémarre
o_end
.(
        lda o_used
        beq r
        lda o_khd               ; touches tapées avant : oubliées
        sta o_ktl
        jsr B_CONIN
r       jmp o_nmi
.)

; o_nmi : RESET (et BRK, et la fin) : son coupé, écran texte, ROM
o_nmi
.(
        sei
        lda #$7F
        sta O_IER
        lda #0
        ldx #8
s       jsr o_ay
        inx
        cpx #11
        bne s
        lda #$1A
        sta O_MODE
        jmp ($FFFC)
.)

; o_irq : 50 Hz : compteur, clavier, fin du bip ; BRK : redémarrage
o_irq
.(
        pha
        txa
        pha
        tya
        pha
        tsx
        lda $0104,x             ; P empilé : BRK ?
        and #$10
        bne b
        bit O_IFR
        bvc e
        lda O_T1CL              ; acquitte T1
        inc SYS_TICKS
        bne t
        inc SYS_TICKS+1
t       jsr o_kscan
        lda o_bipd
        beq e
        dec o_bipd
        bne e
        lda #0                  ; fin du bip : volume à 0
        ldx #8
        jsr o_ay
e       pla
        tay
        pla
        tax
        pla
        rti
b       jmp o_nmi
.)

; o_ay : A dans le registre X de l'AY-3-8912 (A et X gardés)
o_ay
        stx O_ORA
        pha
        lda #O_LATCH
        sta O_PCR
        lda #O_IDLE
        sta O_PCR
        pla
        sta O_ORA
        pha
        lda #O_WRITE
        sta O_PCR
        lda #O_IDLE
        sta O_PCR
        pla
        rts

; ---------------------------------------------------------------------
; Clavier (kb_scan de CP/A, sans les menus) : à 50 Hz, sous interruption
; ---------------------------------------------------------------------
; oz_kcol : masque de colonnes A dans le registre 14 de l'AY (déjà choisi)
oz_kcol
        sta O_ORA
        lda #O_WRITE
        sta O_PCR
        lda #O_IDLE
        sta O_PCR
        rts

; oz_krow : ligne X ; Z=0 si une touche est enfoncée (X et Y gardés)
oz_krow
        lda O_ORB
        and #$F8
        sta oz_i
        txa
        ora oz_i
        sta O_ORB
        nop
        nop
        nop
        nop
        lda O_ORB
        and #$08
        rts

o_kscan
.(
        lda #14                 ; registre 14 : port A de l'AY
        sta O_ORA
        lda #O_LATCH
        sta O_PCR
        lda #O_IDLE
        sta O_PCR
        lda #$EF                ; colonne 4 : SHIFT et CTRL
        jsr oz_kcol
        lda #0
        sta o_kmod
        ldx #4                  ; SHIFT gauche
        jsr oz_krow
        beq m1
        inc o_kmod
m1      ldx #7                  ; SHIFT droit
        jsr oz_krow
        beq m2
        lda #1
        sta o_kmod
m2      ldx #2                  ; CTRL
        jsr oz_krow
        beq m3
        lda #2
        ora o_kmod
        sta o_kmod
m3      lda #$10                ; les autres colonnes
        jsr oz_kcol
        ldx #7
rows    jsr oz_krow
        bne got
        dex
        bpl rows
none    lda #$FF
        sta KB_HELD
        rts
got     stx o_krow
        ldy #7
cols    cpy #4
        beq nc
        lda o_kcm,y
        jsr oz_kcol
        ldx o_krow
        jsr oz_krow
        bne gc
nc      dey
        bpl cols
        bmi none                ; rebond : rien de stable
gc      tya
        sta oz_i
        lda o_krow
        asl
        asl
        asl
        ora oz_i                ; ligne * 8 + colonne
        cmp KB_HELD
        beq held
        sta KB_HELD
        lda #25                 ; 0,5 s avant de répéter
        sta o_krep
        bne emit
held    dec o_krep
        bne kd
        lda #3                  ; puis ~16 par seconde
        sta o_krep
emit    ldx KB_HELD
        lda o_kmod
        lsr                     ; C = SHIFT
        lda o_kmn,x
        bcc g1
        lda o_kms,x
g1      bne g2
kd      rts
g2      sta oz_i
        sec                     ; flèches : SHIFT $F0-$F3, CTRL $F4-$F7
        sbc #8
        cmp #4
        bcs na
        tay
        lda o_kmod
        and #3
        beq push
        and #2
        asl
        sty oz_i
        adc oz_i
        adc #$F0
        sta oz_i
        bne push
na      lda o_caps              ; majuscules : la casse des lettres
        beq nk                  ;   s'inverse
        lda oz_i
        and #$DF
        cmp #"A"
        bcc nk
        cmp #"Z"+1
        bcs nk
        lda oz_i
        eor #$20
        sta oz_i
nk      lda o_kmod              ; CTRL : lettre 1-26 (H-K : 28-31),
        and #2                  ;   ESPACE et @ : 0, [ : 27 ; le reste
        beq push                ;   est ignoré
        lda oz_i
        and #$DF
        beq ctl
        cmp #"@"
        bcc kd
        cmp #"["+1
        bcs kd
ctl     and #$1F
        cmp #8
        bcc c2
        cmp #12
        bcs c2
        adc #20
c2      sta oz_i
        cmp #$14                ; CTRL-T : majuscules, dans la console
        bne push                ;   seulement (code 20 en LORES, HIRES)
        lda SCR_PROG
        bne push
        lda O_MODE
        cmp #$1E
        beq push
        lda o_caps
        eor #1
        sta o_caps
        rts
push    ldx o_khd
        lda oz_i
        sta o_kbuf,x
        inx
        txa
        and #15
        cmp o_ktl
        beq pr                  ; tampon plein : touche perdue
        sta o_khd
pr      rts
.)

o_kcm   .byt $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
o_kmn   .byt $37,$6E,$35,$76,$00,$31,$78,$33
        .byt $6A,$74,$72,$66,$00,$1B,$71,$64
        .byt $6D,$36,$62,$34,$00,$7A,$32,$63
        .byt $6B,$39,$3B,$2D,$00,$00,$5C,$27
        .byt $20,$2C,$2E,$0B,$00,$08,$0A,$09
        .byt $75,$69,$6F,$70,$00,$7F,$5D,$5B
        .byt $79,$68,$67,$65,$00,$61,$73,$77
        .byt $38,$6C,$30,$2F,$00,$0D,$00,$3D
o_kms   .byt $26,$4E,$25,$56,$00,$21,$58,$23
        .byt $4A,$54,$52,$46,$00,$1B,$51,$44
        .byt $4D,$5E,$42,$24,$00,$5A,$40,$43
        .byt $4B,$28,$3A,$5F,$00,$00,$7C,$22
        .byt $20,$3C,$3E,$0B,$00,$08,$0A,$09
        .byt $55,$49,$4F,$50,$00,$7F,$7D,$7B
        .byt $59,$48,$47,$45,$00,$41,$53,$57
        .byt $2A,$4C,$29,$3F,$00,$0D,$00,$2B

; B_CONST : A = $FF si une touche attend, 0 sinon (Z en accord)
B_CONST
.(
        lda o_ktl
        cmp o_khd
        beq z
        lda #$FF
        rts
z       lda #0
        rts
.)

; B_CONIN : attend une touche -> A (X et Y gardés)
B_CONIN
.(
w       lda o_ktl
        cmp o_khd
        beq w
        stx oz_x
        ldx o_ktl
        lda o_kbuf,x
        pha
        inx
        txa
        and #15
        sta o_ktl
        ldx oz_x
        pla
        rts
.)

; ---------------------------------------------------------------------
; BDOS : X = fonction, A/Y = paramètre
; ---------------------------------------------------------------------
BDOS
.(
        cpx #F_CONOUT
        bne d1
        jmp o_con
d1      cpx #F_GFX
        bne d2
        jmp o_gfx
d2      cpx #F_SETDMA
        bne d3
        sta oz_d
        sty oz_d+1
        rts
d3      cpx #F_CLOSE
        bne d4
        lda #0
        rts
d4      sta oz_a                ; les autres : table o_ftab (une entrée par
        sty oz_y                ;   routine gardée)
        stx oz_x
        ldy #0
l       lda o_ftab,y
        beq no
        cmp oz_x
        beq go
        iny
        iny
        iny
        bne l
go      lda o_ftab+2,y
        pha
        lda o_ftab+1,y
        pha
        lda oz_a
        ldy oz_y
        rts
no      lda #$FF
        rts
.)

; o_ftab : fonction, adresse - 1 ; les entrées des routines que le
;   programme n'emporte pas ne sont pas recopiées
o_ftab
;&o_rdl
        .byt F_RDL
        .word o_rdl-1
;&o_open
        .byt F_OPEN
        .word o_open-1
;&o_read
        .byt F_READ
        .word o_read-1
;&o_snd
        .byt F_SND
        .word o_snd-1
;&
        .byt 0

; ---------------------------------------------------------------------
; Console (mode texte) : lignes 1 à 27, colonnes 2 à 39
; ---------------------------------------------------------------------
; oz_row : oz_p <- début de la ligne X de l'écran (X et Y gardés)
oz_row
        txa
        pha
        asl
        tax
        lda hz_rows,x
        sta oz_p
        lda hz_rows+1,x
        sta oz_p+1
        pla
        tax
        rts

; o_cls : les 28 lignes effacées (papier noir, encre blanche), curseur en
;   haut de la console ; X gardé
o_cls
.(
        txa
        pha
        ldx #27
l       jsr oz_row
        ldy #0
        lda #$10
        sta (oz_p),y
        iny
        lda #7
        sta (oz_p),y
        lda #" "
        ldy #39
c       sta (oz_p),y
        dey
        cpy #2
        bcs c
        dex
        bpl l
        lda #2
        sta o_cx
        lda #1
        sta o_cy
        lda #0
        sta o_used
        pla
        tax
        rts
.)

; o_con : caractère A : 13 colonne 2, 10 ligne suivante (défilement en
;   bas), 12 écran effacé, 8 recul, 32-126 affiché ; le reste ignoré
o_con
.(
        cmp #13
        bne n1
        lda #2
        sta o_cx
        rts
n1      cmp #10
        beq lf
        cmp #12
        bne n3
        jmp o_cls
n3      cmp #8
        bne n4
        lda o_cx
        cmp #3
        bcc r
        dec o_cx
r       rts
n4      cmp #32
        bcc r
        cmp #127
        bcs r
        pha
        ldx o_cy
        jsr oz_row
        pla
        ldy o_cx
        sta (oz_p),y
        lda #1
        sta o_used
        inc o_cx
        lda o_cx
        cmp #40
        bcc r
        lda #2
        sta o_cx
lf      lda o_cy
        cmp #27
        bcs sc
        inc o_cy
        rts
sc      ldx #1                  ; défilement des lignes 1 à 27
s1      jsr oz_row
        lda oz_p
        sta oz_q
        lda oz_p+1
        sta oz_q+1
        inx
        jsr oz_row
        ldy #39
s2      lda (oz_p),y
        sta (oz_q),y
        dey
        cpy #2
        bcs s2
        cpx #27
        bne s1
        lda #" "
        ldy #39
s3      sta (oz_p),y
        dey
        cpy #2
        bcs s3
        rts
.)

; o_rdl : fonction 10 : ligne saisie dans le tampon A/Y (longueur
;   maximale, longueur lue, caractères) ; 32-126, DEL et flèche gauche
;   effacent, RETURN finit ; pas plus loin que le bord droit
o_rdl
.(
        sta oz_q
        sty oz_q+1
        ldy #0
        lda (oz_q),y
        sta oz_mx
        lda #39                 ; place jusqu'au bord droit
        sec
        sbc o_cx
        cmp oz_mx
        bcs m
        sta oz_mx
m       lda #0
        sta oz_n
k       jsr cur                 ; curseur : la case en vidéo inverse
        jsr B_CONIN
        pha
        jsr cur
        pla
        cmp #13
        beq done
        cmp #127
        beq del
        cmp #8
        beq del
        cmp #32
        bcc k
        cmp #127
        bcs k
        ldy oz_n
        cpy oz_mx
        bcs k
        iny
        iny
        sta (oz_q),y
        inc oz_n
        jsr o_con
        jmp k
del     lda oz_n
        beq k
        dec oz_n
        dec o_cx
        jsr cur0
        lda #" "
        sta (oz_p),y
        jmp k
done    lda oz_n
        ldy #1
        sta (oz_q),y
        rts
cur     jsr cur0
        lda (oz_p),y
        eor #$80
        sta (oz_p),y
        rts
cur0    ldx o_cy
        jsr oz_row
        ldy o_cx
        rts
.)

; ---------------------------------------------------------------------
; Fichiers inclus dans le programme (O_FILES, écrit par GRXASM)
; ---------------------------------------------------------------------
; o_open : fonction 15, FCB A/Y -> A = 0 (octets 16-17 : données, 18 :
;   enregistrements), $FF si le nom (8 + 3) n'est pas dans O_FILES
o_open
.(
        sta oz_q
        sty oz_q+1
        lda #<O_FILES
        sta oz_p
        lda #>O_FILES
        sta oz_p+1
l       ldy #0
        lda (oz_p),y
        beq no
        ldy #11                 ; FCB 1-11 contre l'entrée 0-10
c       lda (oz_q),y
        and #$7F
        dey
        cmp (oz_p),y
        bne nx
        tya
        bne c
        ldy #11                 ; trouvé
        lda (oz_p),y
        ldy #18
        sta (oz_q),y
        clc
        lda oz_p
        adc #12
        ldy #16
        sta (oz_q),y
        lda oz_p+1
        adc #0
        iny
        sta (oz_q),y
        lda #0
        rts
nx      ldy #11                 ; suivant : 12 + 128 x enregistrements
        lda (oz_p),y
        lsr
        pha
        lda #0
        ror
        adc #12
        adc oz_p
        sta oz_p
        pla
        adc oz_p+1
        sta oz_p+1
        jmp l
no      lda #$FF
        rts
.)

; o_read : fonction 20, FCB A/Y : 128 octets vers le DMA -> A = 0 ; 1 à
;   la fin
o_read
.(
        sta oz_q
        sty oz_q+1
        ldy #18
        lda (oz_q),y
        beq eof
        sec
        sbc #1
        sta (oz_q),y
        ldy #16
        lda (oz_q),y
        sta oz_p
        iny
        lda (oz_q),y
        sta oz_p+1
        ldy #127
c       lda (oz_p),y
        sta (oz_d),y
        dey
        bpl c
        clc
        lda oz_p
        adc #128
        ldy #16
        sta (oz_q),y
        lda oz_p+1
        adc #0
        iny
        sta (oz_q),y
        lda #0
        rts
eof     lda #1
        rts
.)

; ---------------------------------------------------------------------
; Modes (fonction 115) et son (fonction 116)
; ---------------------------------------------------------------------
; o_gfx : bloc A/Y : op 11 -> 0 (texte : le SPLIT n'existe pas ici) ;
;   op 10 -> mode texte ; autre op : 1
o_gfx
.(
        sta oz_q
        sty oz_q+1
        ldy #0
        lda (oz_q),y
        cmp #G_GETMODE
        bne m
        lda #0
        rts
m       cmp #G_MODE
        beq o_text
        lda #1
        rts
.)

; o_text : retour au texte : police remise (le HIRES l'a recouverte ;
;   copie gardée par h_init), console effacée, attribut du mode texte,
;   lu par le circuit vidéo avant de continuer (deux tops)
o_text
.(
        lda #<h_fnt
        sta oz_p
        lda #>h_fnt
        sta oz_p+1
        lda #<O_FONT
        sta oz_q
        lda #>O_FONT
        sta oz_q+1
        ldx #3
        ldy #0
c       lda (oz_p),y
        sta (oz_q),y
        iny
        bne c
        inc oz_p+1
        inc oz_q+1
        dex
        bne c
        jsr o_cls
        lda #$1A
        sta O_MODE
        lda SYS_TICKS
        clc
        adc #2
w       cmp SYS_TICKS
        bne w
        lda #0
        rts
.)

; o_snd : fonction 116 : un bip bref (voix A, ~1 kHz, 4/50 s), quel que
;   soit le bloc (seul rz_bip, saisie refusée, s'en sert)
o_snd
.(
        php
        sei
        lda #60
        ldx #0
        jsr o_ay
        lda #0
        inx
        jsr o_ay
        lda #$7E                ; son de la voix A, port A en sortie
        ldx #7
        jsr o_ay
        lda #10
        ldx #8
        jsr o_ay
        lda #4
        sta o_bipd
        plp
        lda #0
        rts
.)
