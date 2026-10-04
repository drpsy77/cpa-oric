; =====================================================================
;  DEBUG.COM — moniteur, désassembleur et pas à pas pour CP/A
;
;  DEBUG NOM [paramètres]   charge NOM.COM en $0500 et NOM.SYM (écrit
;                           par ASM) s'il existe, puis attend les ordres
;
;  Le débogueur s'installe en DBASE ($8400-$9FFF) ; les symboles se
;  placent juste en dessous. Le haut de la TPA est abaissé d'autant
;  (variable système top_cap), les programmes qui le respectent ne
;  l'écrasent pas.
;
;  Le 6502 n'a pas de mode pas à pas : on pose des BRK provisoires sur
;  l'instruction suivante (les deux suites d'un branchement). Le
;  débogueur se branche sur les vecteurs IRQ (BRK), NMI (bouton RESET)
;  et WBOOT (fin du programme). Il travaille sur la pile du programme,
;  sous son pointeur de pile. Ses variables de page zéro ($D0-$DF) sont
;  échangées avec celles du programme à chaque arrêt.
;
;  Commandes (une lettre ; adresses en hexa ou noms de symboles) :
;    R            registres         R A=41, R PC=loop, R C=1 ...
;    L [adr]      désassemble       D [adr]   mémoire hexa et ASCII
;    M adr bb ..  modifie la mémoire
;    G [adr]      exécute           B [adr]   points d'arrêt, B- [adr]
;    T [n]        pas à pas         P [n]     idem, un JSR d'un coup
;    ? expr       valeur et symbole H         aide       Q   quitter
; =====================================================================

#include "cpa.inc"

DBASE   = $8400         ; adresse du débogueur
DEND    = $A000         ; il doit finir avant l'image du mode SPLIT
NBP     = 8             ; points d'arrêt permanents
NLIST   = 12            ; instructions par commande L
IBMAX   = 38

; arrêts
R_BRK   = 0
R_NMI   = 1
R_END   = 2

; page zéro du débogueur (échangée avec celle du programme)
ptr     = $D0
symp    = $D2
val     = $D4
t0      = $D6
t1      = $D8
ip      = $DA           ; position dans la ligne de commande
tmpb    = $DB
cnt     = $DC
kind    = $DE
best    = $DF

; =====================================================================
; Chargeur : recopie le débogueur en DBASE
; =====================================================================
        *= $0500
loader
.(
        lda #<image
        sta $D0
        lda #>image
        sta $D1
        lda #<DBASE
        sta $D2
        lda #>DBASE
        sta $D3
        ldx #>(dend-dstart+255)
        ldy #0
loop    lda ($D0),y
        sta ($D2),y
        iny
        bne loop
        inc $D1
        inc $D3
        dex
        bne loop
        jmp init
.)
image

; =====================================================================
; Le débogueur
; =====================================================================
        *= DBASE
dstart

; variables (début : old_irq ne doit pas finir en $xxFF pour JMP ())
old_irq   .word 0
old_nmi   .word 0
old_wboot .word 0
rPC     .word 0
rA      .byt 0
rX      .byt 0
rY      .byt 0
rP      .byt 0
rS      .byt 0
s0      .byt 0
reason  .byt 0
running .byt 0
ended   .byt 0
stepping .byt 0         ; pas restants
stepover .byt 0         ; 1 = P (JSR d'un coup)
go_after .byt 0         ; 1 = pas technique avant un G
ntmp    .byt 0
tmpa_lo .byt 0,0
tmpa_hi .byt 0,0
tmpsv   .byt 0,0
bp_on   .dsb NBP,0
bp_lo   .dsb NBP,0
bp_hi   .dsb NBP,0
bp_sv   .dsb NBP,0
skip_lo .byt 0          ; point d'arrêt à ne pas poser (sous PC)
skip_hi .byt 0
symlo   .word 0         ; début de la table des symboles
pend    .word 0         ; fin du programme chargé
lnext   .word $0500     ; suite de L
dnext   .word $0500     ; suite de D
nsym    .word 0
zsave   .dsb 16,0       ; page zéro $D0-$DF du programme
nbuf    .dsb 32,0
ntmp2   .byt 0
bpcount .byt 0
ilen    .byt 0
rlen    .byt 0
rn0     .byt 0
rn1     .byt 0

; ---------------------------------------------------------------------
; Démarrage
; ---------------------------------------------------------------------
init
.(
        cld
        tsx                     ; pile du programme : à partir d'ici
        stx s0
        dex                     ; le débogueur travaille en dessous
        dex
        txs
        lda FCB1+1
        cmp #" "
        bne arg
        lda #<m_usage
        ldy #>m_usage
        jsr puts
        jmp WBOOT
arg     ldx #11                 ; NOM.COM et NOM.SYM
cp      lda FCB1,x
        sta fcb_prg,x
        sta fcb_sym,x
        dex
        bpl cp
        lda fcb_prg+9
        cmp #" "
        bne ext
        lda #"C"
        sta fcb_prg+9
        lda #"O"
        sta fcb_prg+10
        lda #"M"
        sta fcb_prg+11
ext     lda #"S"
        sta fcb_sym+9
        lda #"Y"
        sta fcb_sym+10
        lda #"M"
        sta fcb_sym+11
        jsr shift_args
        ; --- programme en $0500 ---
        lda #<fcb_prg
        ldy #>fcb_prg
        jsr open_fcb
        cmp #$FF
        bne pok
        lda #<m_noprog
        ldy #>m_noprog
        jsr puts
        jmp WBOOT
pok     lda #<$0500
        sta ptr
        lda #>$0500
        sta ptr+1
        lda #<fcb_prg
        sta t1
        lda #>fcb_prg
        sta t1+1
        jsr read_all
        bcc lok
        lda #<m_big
        ldy #>m_big
        jsr puts
        jmp WBOOT
lok     lda ptr
        sta pend
        lda ptr+1
        sta pend+1
        jsr load_syms
        ; --- haut de la TPA abaissé ---
        lda symlo+1
        sta TOP_CAP
        cmp TPA_TOP+1
        bcs nocap
        sta TPA_TOP+1
        lda #0
        sta TPA_TOP
nocap   ; --- vecteurs détournés ---
        lda $0201
        sta old_wboot
        lda $0202
        sta old_wboot+1
        lda #<exit_wb
        sta $0201
        lda #>exit_wb
        sta $0202
        lda $0207
        sta old_irq
        lda $0208
        sta old_irq+1
        lda $020A
        sta old_nmi
        lda $020B
        sta old_nmi+1
        sei
        lda #<dbg_irq
        sta $0207
        lda #>dbg_irq
        sta $0208
        lda #<dbg_nmi
        sta $020A
        lda #>dbg_nmi
        sta $020B
        cli
        jsr dis_init
        ; --- registres de départ ---
        jsr reset_regs
        ldx #15                 ; page zéro « du programme »
zs      lda #0
        sta zsave,x
        dex
        bpl zs
        ldx rS
        txs
        lda #<m_banner
        ldy #>m_banner
        jsr puts
        jsr show_loaded
        jsr show_full
        jmp prompt
.)

; reset_regs : PC=$0500, pile avec retour vers prog_rts
reset_regs
        lda #<$0500
        sta rPC
        lda #>$0500
        sta rPC+1
        lda #0
        sta rA
        sta rX
        sta rY
        sta ended
        lda #$20
        sta rP
        ldx s0
        lda #>(prog_rts-1)
        sta $0100,x
        dex
        lda #<(prog_rts-1)
        sta $0100,x
        dex
        stx rS
        rts

; shift_args : les paramètres après NOM deviennent ceux du programme
shift_args
.(
        ldx #1
        ldy TAIL
        beq done
sp1     lda TAIL,x              ; espaces
        cmp #" "
        bne wd
        inx
        dey
        bne sp1
        beq done
wd      lda TAIL,x              ; le nom
        cmp #" "
        beq rest
        inx
        dey
        bne wd
rest    sty TAIL                ; le reste, espace compris
        ldy #1
cp      lda TAIL,x
        sta TAIL,y
        inx
        iny
        cpy #127
        bne cp
done    ldx #15                 ; FCB1 <- FCB2, FCB2 vide
cf      lda FCB2,x
        sta FCB1,x
        dex
        bpl cf
        ldx #15
        lda #" "
cl      sta FCB2,x
        dex
        bne cl
        lda #0
        sta FCB2
        sta FCB1+12
        rts
.)

; open_fcb : A/Y = FCB, octets 12-35 à zéro, ouverture -> A
open_fcb
.(
        sta t0
        sty t0+1
        ldy #12
        lda #0
z       sta (t0),y
        iny
        cpy #36
        bne z
        lda t0
        ldy t0+1
        ldx #F_OPEN
        jmp BDOS
.)

; read_all : lit le fichier t1 en ptr, sans dépasser lim_hi. ptr = fin.
; C=1 si la place manque
read_all
.(
loop    clc
        lda ptr
        adc #128
        sta t0
        lda ptr+1
        adc #0
        sta t0+1
        lda lim_lo              ; ptr + 128 > limite ?
        cmp t0
        lda lim_hi
        sbc t0+1
        bcc full
        ldx #F_SETDMA
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #F_READ
        lda t1
        ldy t1+1
        jsr BDOS
        cmp #0
        bne eof
        lda t0
        sta ptr
        lda t0+1
        sta ptr+1
        jmp loop
eof     jsr dma_def
        clc
        rts
full    jsr dma_def
        sec
        rts
.)
lim_lo  .byt <DBASE
lim_hi  .byt >DBASE

dma_def
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp BDOS

; load_syms : NOM.SYM lu après le programme puis placé sous DBASE
load_syms
.(
        lda #<(DBASE-1)         ; par défaut : table vide
        sta symlo
        lda #>(DBASE-1)
        sta symlo+1
        lda #0
        sta DBASE-1
        sta nsym
        sta nsym+1
        lda #<fcb_sym
        ldy #>fcb_sym
        jsr open_fcb
        cmp #$FF
        bne ok
        rts
ok      lda pend
        sta ptr
        lda pend+1
        sta ptr+1
        lda #<fcb_sym
        sta t1
        lda #>fcb_sym
        sta t1+1
        jsr read_all
        bcc ld
        lda #<m_nosym
        ldy #>m_nosym
        jmp puts
ld      lda pend                ; longueur utile de la table
        sta ptr
        lda pend+1
        sta ptr+1
scan    ldy #0
        lda (ptr),y
        beq end
        clc
        adc #4
        adc ptr
        sta ptr
        bcc s1
        inc ptr+1
s1      inc nsym
        bne scan
        inc nsym+1
        jmp scan
end     inc ptr                 ; ptr = fin (terminateur compris)
        bne e1
        inc ptr+1
e1      sec                     ; cnt = longueur
        lda ptr
        sbc pend
        sta cnt
        lda ptr+1
        sbc pend+1
        sta cnt+1
        sec                     ; symlo = DBASE - longueur
        lda #<DBASE
        sbc cnt
        sta symlo
        sta t0
        lda #>DBASE
        sbc cnt+1
        sta symlo+1
        sta t0+1
        ; copie vers le haut, en partant de la fin (zones qui se chevauchent)
        lda #<DBASE
        sta t0
        lda #>DBASE
        sta t0+1
mv      lda cnt
        ora cnt+1
        beq done
        lda ptr
        bne m1
        dec ptr+1
m1      dec ptr
        lda t0
        bne m2
        dec t0+1
m2      dec t0
        ldy #0
        lda (ptr),y
        sta (t0),y
        lda cnt
        bne m3
        dec cnt+1
m3      dec cnt
        jmp mv
done    rts
.)

show_loaded
.(
        ldx #1                  ; NOM.COM $0500-$xxxx
nm      lda fcb_prg,x
        cmp #" "
        beq dot
        jsr putc
        inx
        cpx #9
        bne nm
dot     lda #<m_com
        ldy #>m_com
        jsr puts
        lda #<$0500
        sta val
        lda #>$0500
        sta val+1
        jsr puthex4n
        lda #"-"
        jsr putc
        lda pend
        sec
        sbc #1
        sta val
        lda pend+1
        sbc #0
        sta val+1
        jsr puthex4n
        jsr crlf
        lda nsym
        sta val
        lda nsym+1
        sta val+1
        jsr putdec
        lda #<m_nsym
        ldy #>m_nsym
        jsr puts
        lda symlo
        sta val
        lda symlo+1
        sta val+1
        jsr puthex4n
        jmp crlf
.)

; ---------------------------------------------------------------------
; Arrêts : BRK, bouton RESET, fin du programme
; ---------------------------------------------------------------------
dbg_irq
.(
        pha
        txa
        pha
        tsx
        lda $0103,x             ; P empilé : B mis par BRK
        and #$10
        bne isbrk
        pla
        tax
        pla
        jmp (old_irq)
isbrk   pla
        sta rX
        pla
        sta rA
        sty rY
        pla
        and #$EF
        ora #$20
        sta rP
        pla                     ; adresse empilée = BRK + 2
        sec
        sbc #2
        sta rPC
        pla
        sbc #0
        sta rPC+1
        tsx
        stx rS
        lda #R_BRK
        sta reason
        jmp trap
.)

dbg_nmi
.(
        pha
        lda running
        bne live
        pla
        rti
live    pla
        sta rA
        stx rX
        sty rY
        pla
        and #$EF
        ora #$20
        sta rP
        pla
        sta rPC
        pla
        sta rPC+1
        tsx
        stx rS
        lda #R_NMI
        sta reason
        jmp trap
.)

; le programme se termine par RTS (vers prog_rts) ou par JMP $0200
prog_rts
exit_wb
        php
        sta rA
        stx rX
        sty rY
        pla
        ora #$20
        sta rP
        tsx
        stx rS
        lda #<$0200
        sta rPC
        lda #>$0200
        sta rPC+1
        lda #R_END
        sta reason
trap
.(
        cld
        lda #0
        sta running
        ldx #15                 ; page zéro du programme mise de côté
zs      lda $D0,x
        sta zsave,x
        dex
        bpl zs
        cli                     ; le clavier marche par interruption
        lda ntmp                ; pas provisoires en cours
        sta ntmp2
        jsr remove_all
        lda #0
        sta ntmp
        lda reason
        cmp #R_END
        bne n1
        lda #<m_end
        ldy #>m_end
        jsr puts
        ldx s0                  ; tout est prêt pour relancer en $0500
        dex
        dex
        txs
        jsr reset_regs
        lda #1
        sta ended
        jmp stop
n1      cmp #R_NMI
        bne n2
        lda #<m_nmi
        ldy #>m_nmi
        jsr puts
        jmp stop
n2      ldx ntmp2               ; BRK : pas provisoire ?
tl      dex
        bmi perm
        lda tmpa_lo,x
        cmp rPC
        bne tl
        lda tmpa_hi,x
        cmp rPC+1
        bne tl
        jmp step_done
perm    ldx #NBP-1              ; point d'arrêt ?
pl      lda bp_on,x
        beq pn
        lda bp_lo,x
        cmp rPC
        bne pn
        lda bp_hi,x
        cmp rPC+1
        beq isbp
pn      dex
        bpl pl
        lda #<m_brk             ; BRK du programme lui-même
        ldy #>m_brk
        jsr puts
        jmp stop
isbp    lda #<m_bp
        ldy #>m_bp
        jsr puts
        txa
        clc
        adc #"1"
        jsr putc
        jsr crlf
stop    lda #0
        sta stepping
        sta go_after
        jsr show_full
        jmp prompt
.)

step_done
.(
        lda go_after            ; pas technique avant G : on repart
        beq st
        lda #0
        sta go_after
        sta skip_hi
        jmp run_free
st      dec stepping
        beq last
        jsr B_CONST             ; ESC arrête la série
        beq more
        jsr B_CONIN
        cmp #$1B
        beq last
more    jsr show_short
        jmp do_step
last    lda #0
        sta stepping
        jsr show_full
        jmp prompt
.)

; ---------------------------------------------------------------------
; Reprise de l'exécution
; ---------------------------------------------------------------------
; resume : rend la main au programme avec ses registres
resume
.(
        sei
        lda #1
        sta running
        ldx #15                 ; sa page zéro
zs      lda zsave,x
        sta $D0,x
        dex
        bpl zs
        ldx rS
        txs
        lda rPC+1
        pha
        lda rPC
        pha
        lda rP
        pha
        ldx rX
        ldy rY
        lda rA
        rti
.)

; run_free : G, tous les points d'arrêt posés (sauf celui sous PC)
run_free
        jsr insert_perm
        jmp resume

; go : G [adr]
go
.(
        lda ended
        beq ok
        jsr reset_regs
        lda #0
        sta ended
ok      lda rPC                 ; point d'arrêt sous PC : un pas d'abord
        sta skip_lo
        lda rPC+1
        sta skip_hi
        jsr bp_at_pc
        bcs direct
        lda #1
        sta go_after
        lda #1
        sta stepping
        lda #0
        sta stepover
        jmp do_step
direct  lda #0
        sta skip_hi             ; rien à sauter
        jmp run_free
.)

; bp_at_pc : C=0 si un point d'arrêt actif est en rPC
bp_at_pc
.(
        ldx #NBP-1
loop    lda bp_on,x
        beq nx
        lda bp_lo,x
        cmp rPC
        bne nx
        lda bp_hi,x
        cmp rPC+1
        bne nx
        clc
        rts
nx      dex
        bpl loop
        sec
        rts
.)

; do_step : exécute une instruction (BRK provisoires sur la suite)
do_step
.(
        lda ended
        beq ok
        jsr reset_regs
        lda #0
        sta ended
ok      lda rPC
        sta skip_lo
        sta t0
        lda rPC+1
        sta skip_hi
        sta t0+1
        lda #0
        sta ntmp
        ldy #0
        lda (t0),y
        sta tmpb                ; opcode
        tax
        lda dis_md,x
        cmp #$FF
        bne known
        lda #<m_badop
        ldy #>m_badop
        jsr puts
        jmp step_stop
known   tax                     ; suite normale : PC + longueur
        lda md_len,x
        clc
        adc t0
        sta t1
        lda t0+1
        adc #0
        sta t1+1
        lda tmpb
        cmp #$00                ; BRK
        bne n0
        lda #<m_brkop
        ldy #>m_brkop
        jsr puts
        jmp step_stop
n0      cmp #$4C                ; JMP adr
        bne n1
        jsr opnd16
        jmp one
n1      cmp #$6C                ; JMP (adr)
        bne n2
        jsr opnd16
        ldy #0
        lda (t1),y
        pha
        inc t1                  ; bogue du 6502 : même page
        lda (t1),y
        sta t1+1
        pla
        sta t1
        jmp one
n2      cmp #$20                ; JSR
        bne n3
        lda stepover
        bne one
        lda t1                  ; garde PC+3 si la cible est hors du programme
        pha
        lda t1+1
        pha
        jsr opnd16
        jsr in_prog
        bcc jin
        pla
        sta t1+1
        pla
        sta t1
        jmp one
jin     pla
        pla
        jmp one
n3      cmp #$60                ; RTS
        bne n4
        ldx rS
        lda $0101,x
        clc
        adc #1
        sta t1
        lda $0102,x
        adc #0
        sta t1+1
        jmp one
n4      cmp #$40                ; RTI
        bne n5
        ldx rS
        lda $0102,x
        sta t1
        lda $0103,x
        sta t1+1
        jmp one
n5      ldx tmpb                ; branchement : deux suites
        lda dis_md,x
        cmp #M_REL
        bne one
        jsr add_tmp
        ldy #1
        lda (t0),y
        bpl pos
        dec t1+1
pos     clc
        adc t1
        sta t1
        bcc one
        inc t1+1
one     jsr add_tmp
        lda ntmp                ; aucune suite dans le programme : on lâche
        bne go1
        lda #<m_free
        ldy #>m_free
        jsr puts
        lda #0
        sta stepping
go1     jsr insert_perm
        jsr insert_tmp
        jmp resume
.)

step_stop
        lda #0
        sta stepping
        sta go_after
        jmp prompt

; opnd16 : t1 = mot à t0+1
opnd16
        ldy #1
        lda (t0),y
        pha
        iny
        lda (t0),y
        sta t1+1
        pla
        sta t1
        rts

; in_prog : C=0 si t1 est dans [$0500, symlo)
in_prog
.(
        lda t1+1
        cmp #$05
        bcc no
        lda t1
        cmp symlo
        lda t1+1
        sbc symlo+1
        bcs no
        clc
        rts
no      sec
        rts
.)

; add_tmp : BRK provisoire en t1 s'il est dans le programme
add_tmp
.(
        jsr in_prog
        bcs r
        ldx ntmp
        cpx #2
        bcs r
        beq r
        lda t1
        sta tmpa_lo,x
        lda t1+1
        sta tmpa_hi,x
        inc ntmp
r       rts
.)

insert_tmp
.(
        ldx #0
loop    cpx ntmp
        beq r
        lda tmpa_lo,x
        sta t0
        lda tmpa_hi,x
        sta t0+1
        ldy #0
        lda (t0),y
        sta tmpsv,x
        tya
        sta (t0),y
        inx
        bne loop
r       rts
.)

insert_perm
.(
        ldx #0
loop    lda bp_on,x
        beq nx
        lda bp_lo,x
        sta t0
        lda bp_hi,x
        sta t0+1
        cmp skip_hi             ; pas celui sous PC
        bne put
        lda t0
        cmp skip_lo
        beq nx
put     ldy #0
        lda (t0),y
        sta bp_sv,x
        tya
        sta (t0),y
        lda #2                  ; posé
        sta bp_on,x
nx      inx
        cpx #NBP
        bne loop
        rts
.)

; remove_all : remet les octets d'origine (provisoires d'abord)
remove_all
.(
        ldx ntmp
tl      dex
        bmi perm
        lda tmpa_lo,x
        sta t0
        lda tmpa_hi,x
        sta t0+1
        ldy #0
        lda tmpsv,x
        sta (t0),y
        jmp tl
perm    ldx #NBP-1
pl      lda bp_on,x
        cmp #2
        bne pn
        lda bp_lo,x
        sta t0
        lda bp_hi,x
        sta t0+1
        ldy #0
        lda bp_sv,x
        sta (t0),y
        lda #1
        sta bp_on,x
pn      dex
        bpl pl
        rts
.)

; ---------------------------------------------------------------------
; Affichage de l'état
; ---------------------------------------------------------------------
; show_full : PC=0517 A=41 X=02 Y=FF S=F9
;             P=33  N V - B D I Z C
;                   0 0 1 1 0 0 1 1
;             puis l'instruction suivante
show_full
.(
        lda #<m_pc
        ldy #>m_pc
        jsr puts
        lda rPC
        sta val
        lda rPC+1
        sta val+1
        jsr puthex4n
        jsr regs_axys
        jsr crlf
        lda #<m_p
        ldy #>m_p
        jsr puts
        lda rP
        jsr puthex2
        lda #<m_flags
        ldy #>m_flags
        jsr puts
        lda #<m_pad
        ldy #>m_pad
        jsr puts
        lda rP
        sta tmpb
        ldx #8
bits    lda #"0"
        asl tmpb
        bcc b0
        lda #"1"
b0      jsr putc
        lda #" "
        jsr putc
        dex
        bne bits
        jsr crlf
        jmp show_ins
.)

; show_short : A=41 X=02 Y=FF S=F9 nvdIzC  puis l'instruction
show_short
.(
        jsr regs_axys
        lda #" "
        jsr putc
        lda rP
        sta tmpb
        ldx #0
loop    lda f_mask,x
        beq done
        and tmpb
        beq off
        lda f_up,x
        bne pr
off     lda f_up,x
        ora #$20
pr      jsr putc
        inx
        bne loop
done    jsr crlf
.)
show_ins
        lda rPC
        sta t0
        lda rPC+1
        sta t0+1
        jmp dis_one

f_mask  .byt $80,$40,$08,$04,$02,$01,0
f_up    .asc "NVDIZC"

regs_axys
        lda #<m_a
        ldy #>m_a
        jsr puts
        lda rA
        jsr puthex2
        lda #<m_x
        ldy #>m_x
        jsr puts
        lda rX
        jsr puthex2
        lda #<m_y
        ldy #>m_y
        jsr puts
        lda rY
        jsr puthex2
        lda #<m_s
        ldy #>m_s
        jsr puts
        lda rS
        jmp puthex2

; ---------------------------------------------------------------------
; Désassembleur
; ---------------------------------------------------------------------
M_IMP   = 0
M_IMM   = 1
M_ZP    = 2
M_ZPX   = 3
M_ZPY   = 4
M_ABS   = 5
M_ABX   = 6
M_ABY   = 7
M_IND   = 8
M_INX   = 9
M_INY   = 10
M_REL   = 11

md_len  .byt 1,2,2,2,2,3,3,3,3,2,2,2

; dis_init : tables opcode -> mnémonique et mode, à partir de mn_ops
dis_init
.(
        ldx #0
        lda #$FF
cl      sta dis_mn,x
        sta dis_md,x
        inx
        bne cl
        lda #<mn_ops
        sta ptr
        lda #>mn_ops
        sta ptr+1
        lda #0
        sta tmpb                ; numéro du mnémonique
mn      ldy #0
md      lda (ptr),y
        cmp #$FF
        beq nx
        tax
        lda tmpb
        sta dis_mn,x
        tya
        sta dis_md,x
nx      iny
        cpy #12
        bne md
        clc
        lda ptr
        adc #12
        sta ptr
        bcc m1
        inc ptr+1
m1      inc tmpb
        lda tmpb
        cmp #NMNEM
        bne mn
        rts
.)

; dis_one : désassemble l'instruction en t0, t0 avance
dis_one
.(
        jsr label_line
        lda t0
        sta val
        lda t0+1
        sta val+1
        jsr puthex4n
        lda #" "
        jsr putc
        ldy #0
        lda (t0),y
        tax
        lda dis_md,x
        sta kind
        cmp #$FF
        bne ok
        lda #1                  ; octet inconnu
        sta ilen
        bne hx
ok      tax
        lda md_len,x
        sta ilen
hx      ldy #0                  ; les octets, sur 9 colonnes
hb      cpy ilen
        bcs pad
        lda (t0),y
        jsr puthex2
        lda #" "
        jsr putc
        iny
        bne hb
pad     cpy #3
        bcs mnem
        lda #" "
        jsr putc
        jsr putc
        jsr putc
        iny
        bne pad
mnem    lda #" "
        jsr putc
        lda kind
        cmp #$FF
        bne mok
        lda #<m_byt
        ldy #>m_byt
        jsr puts
        ldy #0
        lda (t0),y
        jsr puthex2d
        jmp next
mok     ldy #0                  ; nom du mnémonique : 3 * numéro
        lda (t0),y
        tax
        lda dis_mn,x
        sta tmpb
        asl
        adc tmpb
        tax
        lda mn_names,x
        jsr putc
        lda mn_names+1,x
        jsr putc
        lda mn_names+2,x
        jsr putc
        lda kind
        beq next                ; implicite
        lda #" "
        jsr putc
        ldy #1                  ; opérande
        lda (t0),y
        sta val
        lda #0
        sta val+1
        lda kind
        cmp #M_ABS
        bcc op8
        cmp #M_INX
        bcs op8
        iny
        lda (t0),y
        sta val+1
op8     lda kind
        asl
        tax
        lda opf_tab+1,x
        pha
        lda opf_tab,x
        pha
        rts
next    jsr crlf
        clc
        lda t0
        adc ilen
        sta t0
        bcc r
        inc t0+1
r       rts
.)

opf_tab .word f_none-1, f_imm-1, f_zp-1, f_zpx-1, f_zpy-1, f_abs-1, f_abx-1
        .word f_aby-1, f_ind-1, f_inx-1, f_iny-1, f_rel-1

f_none  jmp dis_end
f_imm   lda #"#"
        jsr putc
        lda val
        jsr puthex2d
        jmp dis_end
f_zp    jsr put_zp
        jmp dis_end
f_zpx   jsr put_zp
        jmp comx
f_zpy   jsr put_zp
        jmp comy
f_abs   jsr put_abs
        jmp dis_end
f_abx   jsr put_abs
comx    lda #<m_cx
        ldy #>m_cx
        jsr puts
        jmp dis_end
f_aby   jsr put_abs
comy    lda #<m_cy
        ldy #>m_cy
        jsr puts
        jmp dis_end
f_ind   lda #"("
        jsr putc
        jsr put_abs
        lda #")"
        jsr putc
        jmp dis_end
f_inx   lda #"("
        jsr putc
        jsr put_zp
        lda #<m_cx
        ldy #>m_cx
        jsr puts
        lda #")"
        jsr putc
        jmp dis_end
f_iny   lda #"("
        jsr putc
        jsr put_zp
        lda #")"
        jsr putc
        jmp comy
f_rel   lda #0                  ; cible = adresse + 2 + déplacement signé
        sta t1+1
        ldy #1
        lda (t0),y
        sta t1
        bpl rp
        dec t1+1
rp      clc
        lda t0
        adc #2
        sta val
        lda t0+1
        adc #0
        sta val+1
        clc
        lda val
        adc t1
        sta val
        lda val+1
        adc t1+1
        sta val+1
        jsr put_abs
dis_end ; retour dans dis_one
        jsr crlf
        clc
        lda t0
        adc ilen
        sta t0
        bcc de1
        inc t0+1
de1     rts

; put_zp / put_abs : symbole de valeur val, sinon $hh / $hhhh
put_zp
        jsr sym_exact
        bcc ps_name
        lda val
        jmp puthex2d
put_abs
        jsr sym_exact
        bcc ps_name
        jsr sym_near
        bcc ps_near
        jmp puthex4d
ps_name jmp put_symname
ps_near jsr put_symname
        lda #"+"
        jsr putc
        lda best                ; décalage
        sta val
        lda #0
        sta val+1
        jmp putdec

; label_line : « nom: » si une étiquette tombe en t0
label_line
.(
        lda t0
        sta val
        lda t0+1
        sta val+1
        jsr sym_label
        bcs r
        jsr put_symname
        lda #":"
        jsr putc
        jsr crlf
r       rts
.)

; ---------------------------------------------------------------------
; Symboles : [longueur][valeur lo][valeur hi][genre][nom]
;   genre : bit 0 étiquette, bit 1 locale, bit 2 fichier inclus.
;   Fin : longueur nulle.
; ---------------------------------------------------------------------
sym_first
        lda symlo
        sta symp
        lda symlo+1
        sta symp+1
        rts

sym_next
        ldy #0
        lda (symp),y
        clc
        adc #4
        adc symp
        sta symp
        bcc sn1
        inc symp+1
sn1     rts

; sym_exact : symbole valant val (rang : étiquette globale, constante
; globale, étiquette locale, constante locale). C=0 trouvé (symp)
sym_exact
.(
        lda #0
        sta best                ; meilleur rang + 1
        jsr sym_first
loop    ldy #0
        lda (symp),y
        beq end
        iny
        lda (symp),y
        cmp val
        bne nx
        iny
        lda (symp),y
        cmp val+1
        bne nx
        iny
        lda (symp),y            ; rang selon le genre
        and #7
        tax
        lda rank,x
        cmp best
        bcc nx
        beq nx
        sta best
        lda symp
        sta cnt
        lda symp+1
        sta cnt+1
nx      jsr sym_next
        jmp loop
end     lda best
        beq no
        lda cnt
        sta symp
        lda cnt+1
        sta symp+1
        clc
        rts
no      sec
        rts
rank    .byt 6,8,2,4,5,7,1,3   ; globale > étiquette > fichier principal
.)

; sym_label : étiquette exactement en val (C=0)
sym_label
.(
        lda #0
        sta best
        jsr sym_first
loop    ldy #0
        lda (symp),y
        beq end
        ldy #3
        lda (symp),y
        and #1
        beq nx
        tax                     ; X=1
        ldy #1
        lda (symp),y
        cmp val
        bne nx
        iny
        lda (symp),y
        cmp val+1
        bne nx
        iny
        lda (symp),y
        and #2                  ; globale d'abord
        bne loc
        lda symp
        sta cnt
        lda symp+1
        sta cnt+1
        jmp found
loc     lda best
        bne nx
        inc best
        lda symp
        sta cnt
        lda symp+1
        sta cnt+1
nx      jsr sym_next
        jmp loop
end     lda best
        beq no
found   lda cnt
        sta symp
        lda cnt+1
        sta symp+1
        clc
        rts
no      sec
        rts
.)

; sym_near : symbole juste avant val (à 31 octets au plus), hors page
; zéro et pile. C=0 trouvé, best = décalage
sym_near
.(
        lda val+1
        cmp #$02
        bcc no
        lda #32
        sta best
        jsr sym_first
loop    ldy #0
        lda (symp),y
        beq end
        sec                     ; d = val - valeur
        ldy #1
        lda val
        sbc (symp),y
        tax
        iny
        lda val+1
        sbc (symp),y
        bne nx                  ; négatif ou trop loin
        cpx best
        bcs nx
        stx best
        lda symp
        sta cnt
        lda symp+1
        sta cnt+1
nx      jsr sym_next
        jmp loop
end     lda best
        cmp #32
        bcs no
        lda cnt
        sta symp
        lda cnt+1
        sta symp+1
        clc
        rts
no      sec
        rts
.)

put_symname
.(
        ldy #0
        lda (symp),y
        sta tmpb
        ldy #4
loop    lda (symp),y
        jsr putc
        iny
        dec tmpb
        bne loop
        rts
.)

; sym_byname : nom nbuf (longueur cnt) -> val. Sans tenir compte de la
; casse, les symboles globaux d'abord. C=0 trouvé
sym_byname
.(
        lda #0
        sta kind                ; 0 : globaux, 2 : locaux
pass    jsr sym_first
loop    ldy #0
        lda (symp),y
        beq endp
        cmp cnt
        bne nx
        ldy #3
        lda (symp),y
        and #2
        cmp kind
        bne nx
        ldx #0
        ldy #4
cmpn    lda (symp),y
        jsr upcase
        sta tmpb
        lda nbuf,x
        jsr upcase
        cmp tmpb
        bne nx
        iny
        inx
        cpx cnt
        bne cmpn
        ldy #1
        lda (symp),y
        sta val
        iny
        lda (symp),y
        sta val+1
        clc
        rts
nx      jsr sym_next
        jmp loop
endp    lda kind
        bne no
        lda #2
        sta kind
        bne pass
no      sec
        rts
.)

upcase
        cmp #"a"
        bcc uc1
        cmp #"z"+1
        bcs uc1
        and #$DF
uc1     rts

; ---------------------------------------------------------------------
; Ligne de commande
; ---------------------------------------------------------------------
prompt
.(
        ldx rS                  ; pile : sous celle du programme
        txs
        cli
        jsr crlf_if
        lda #"-"
        jsr putc
        lda #IBMAX
        sta ibuf
        ldx #10
        lda #<ibuf
        ldy #>ibuf
        jsr BDOS
        jsr crlf
        ldx ibuf+1              ; fin de ligne
        lda #0
        sta ibuf+2,x
        lda #0
        sta ip
        jsr skipsp
        beq prompt
        jsr upcase
        sta tmpb
        ldx #0
look    lda cmd_keys,x
        beq bad
        cmp tmpb
        beq found
        inx
        bne look
bad     lda #<m_what
        ldy #>m_what
        jsr puts
        jmp prompt
found   inc ip
        txa
        asl
        tax
        lda cmd_vec+1,x
        pha
        lda cmd_vec,x
        pha
        rts
.)

cmd_keys .asc "RLDMGTPB?HQ",0
cmd_vec  .word c_reg-1, c_list-1, c_dump-1, c_mem-1, c_go-1, c_trace-1
         .word c_proc-1, c_bp-1, c_eval-1, c_help-1, c_quit-1

; skipsp : saute les espaces ; A = caractère (Z=1 en fin), tmpb = A
skipsp
.(
loop    ldx ip
        lda ibuf+2,x
        cmp #" "
        bne r
        inc ip
        bne loop
r       sta tmpb
        ora #0
        rts
.)

; get_expr : terme [+|- terme]... -> val. C=1 s'il n'y a rien
get_expr
.(
        jsr skipsp
        bne some
        sec
        rts
some    jsr term
        bcs bad
loop    jsr skipsp
        cmp #"+"
        beq plus
        cmp #"-"
        bne done
        inc ip
        lda val
        pha
        lda val+1
        pha
        jsr term
        bcs bad2
        pla
        sta t1+1
        pla
        sta t1
        sec
        lda t1
        sbc val
        sta val
        lda t1+1
        sbc val+1
        sta val+1
        jmp loop
plus    inc ip
        lda val
        pha
        lda val+1
        pha
        jsr term
        bcs bad2
        pla
        sta t1+1
        pla
        sta t1
        clc
        lda t1
        adc val
        sta val
        lda t1+1
        adc val+1
        sta val+1
        jmp loop
done    clc
        rts
bad2    pla
        pla
bad     jmp syntax
.)

; term : $hexa, #décimal, symbole, ou hexa
term
.(
        jsr skipsp
        cmp #"$"
        bne t1x
        inc ip
        jmp hexnum
t1x     cmp #"#"
        bne t2
        inc ip
        jmp decnum
t2      jsr word                ; mot -> nbuf, cnt
        bcs no
        jsr sym_byname
        bcc ok
        jmp hexword             ; pas un symbole : hexa ?
ok      clc
        rts
no      sec
        rts
.)

; word : lettres, chiffres, _ -> nbuf (8 au plus), cnt. C=1 si vide
word
.(
        lda #0
        sta cnt
        sta cnt+1               ; longueur réelle
loop    ldx ip
        lda ibuf+2,x
        jsr idchar
        bcs end
        ldx cnt
        cpx #31
        bcs sk
        sta nbuf,x
        inc cnt
sk      inc cnt+1
        inc ip
        jmp loop
end     lda cnt+1
        cmp #32                 ; nom trop long pour nbuf : jamais trouvé
        bcc ok
        lda #0
        sta cnt
ok      lda cnt+1
        beq none
        clc
        rts
none    sec
        rts
.)

idchar
.(
        cmp #"_"
        beq y
        cmp #"0"
        bcc n
        cmp #"9"+1
        bcc y
        pha
        and #$DF
        cmp #"A"
        bcc n1
        cmp #"Z"+1
        bcs n1
        pla
y       clc
        rts
n1      pla
n       sec
        rts
.)

; hexword : nbuf (cnt caractères) lu en hexa
hexword
.(
        lda cnt
        beq bad
        lda #0
        sta val
        sta val+1
        ldx #0
loop    lda nbuf,x
        jsr hexval
        bcs bad
        jsr shift4
        inx
        cpx cnt
        bne loop
        clc
        rts
bad     lda #<m_nosymb
        ldy #>m_nosymb
        jsr puts
        jmp prompt
.)

shift4
        asl val
        rol val+1
        asl val
        rol val+1
        asl val
        rol val+1
        asl val
        rol val+1
        ora val
        sta val
        rts

hexnum
.(
        lda #0
        sta val
        sta val+1
        sta cnt
loop    ldx ip
        lda ibuf+2,x
        jsr hexval
        bcs end
        jsr shift4
        inc cnt
        inc ip
        bne loop
end     lda cnt
        beq bad
        clc
        rts
bad     sec
        rts
.)

decnum
.(
        lda #0
        sta val
        sta val+1
        sta cnt
loop    ldx ip
        lda ibuf+2,x
        cmp #"0"
        bcc end
        cmp #"9"+1
        bcs end
        and #$0F
        pha
        asl val                 ; val = val * 10 + chiffre
        rol val+1
        lda val
        sta t1
        lda val+1
        sta t1+1
        asl val
        rol val+1
        asl val
        rol val+1
        clc
        lda val
        adc t1
        sta val
        lda val+1
        adc t1+1
        sta val+1
        pla
        clc
        adc val
        sta val
        bcc nc
        inc val+1
nc      inc cnt
        inc ip
        bne loop
end     lda cnt
        beq bad
        clc
        rts
bad     sec
        rts
.)

hexval
.(
        cmp #"0"
        bcc bad
        cmp #"9"+1
        bcc dig
        and #$DF
        cmp #"A"
        bcc bad
        cmp #"F"+1
        bcs bad
        sbc #"A"-11
        clc
        rts
dig     sbc #"0"-1
        clc
        rts
bad     sec
        rts
.)

syntax
        lda #<m_syntax
        ldy #>m_syntax
        jsr puts
        jmp prompt

; expect_end : rien d'autre sur la ligne
expect_end
        jsr skipsp
        bne syntax
        rts

; ---------------------------------------------------------------------
; Commandes
; ---------------------------------------------------------------------
; R [reg=valeur]
c_reg
.(
        jsr skipsp
        bne set
        jsr show_full
        jmp prompt
set     jsr word                ; nom du registre ou de l'indicateur
        bcs bad
        lda cnt
        sta rlen
        lda nbuf
        sta rn0
        lda nbuf+1
        sta rn1
        lda #"="
        jsr expect_char
        jsr get_expr
        bcs bad
        jsr expect_end
        lda rlen
        cmp #2
        bne one
        lda rn0                 ; PC ou SP
        jsr upcase
        sta tmpb
        lda rn1
        jsr upcase
        cmp #"C"
        bne nsp
        lda tmpb
        cmp #"P"
        bne bad
        lda val
        sta rPC
        lda val+1
        sta rPC+1
        jmp ok
nsp     cmp #"P"
        bne bad
        lda tmpb
        cmp #"S"
        bne bad
        lda val
        sta rS
        jmp ok
one     cmp #1
        bne bad
        lda rn0
        jsr upcase
        ldx #0
rl      cmp r_names,x
        beq reg
        inx
        cpx #5
        bne rl
        ldx #0                  ; un indicateur : N V D I Z C
fl      cmp f_up,x
        beq flag
        inx
        cpx #6
        bne fl
bad     jmp syntax
reg     lda val
        sta rA,x
        jmp ok
flag    lda f_mask,x
        ldy val
        beq clr
        ora rP
        sta rP
        jmp ok
clr     eor #$FF
        and rP
        sta rP
ok      jsr show_full
        jmp prompt
.)
r_names .asc "AXYPS"

expect_char
        sta tmpb+0
        pha
        jsr skipsp
        pla
        cmp tmpb
        bne ec_bad
        inc ip
        rts
ec_bad  jmp syntax

; L [adr] : désassemble
c_list
.(
        jsr get_expr
        bcs cont
        lda val
        sta lnext
        lda val+1
        sta lnext+1
cont    jsr expect_end
        lda lnext
        sta t0
        lda lnext+1
        sta t0+1
        lda #NLIST
        sta kind+0
loop    lda kind
        pha
        jsr dis_one
        pla
        sta kind
        dec kind
        bne loop
        lda t0
        sta lnext
        lda t0+1
        sta lnext+1
        jmp prompt
.)

; D [adr] : 8 lignes de 8 octets
c_dump
.(
        jsr get_expr
        bcs cont
        lda val
        sta dnext
        lda val+1
        sta dnext+1
cont    jsr expect_end
        lda dnext
        sta t0
        lda dnext+1
        sta t0+1
        lda #8
        sta kind
line    lda t0
        sta val
        lda t0+1
        sta val+1
        jsr puthex4n
        lda #" "
        jsr putc
        ldy #0
hx      lda (t0),y
        jsr puthex2
        lda #" "
        jsr putc
        iny
        cpy #8
        bne hx
        ldy #0
asc     lda (t0),y
        cmp #$20
        bcc dot
        cmp #$7F
        bcc pr
dot     lda #"."
pr      jsr putc
        iny
        cpy #8
        bne asc
        jsr crlf
        clc
        lda t0
        adc #8
        sta t0
        bcc nc
        inc t0+1
nc      dec kind
        bne line
        lda t0
        sta dnext
        lda t0+1
        sta dnext+1
        jmp prompt
.)

; M adr bb bb ... : écrit des octets
c_mem
.(
        jsr get_expr
        bcs bad
        lda val
        sta t0
        lda val+1
        sta t0+1
loop    jsr get_expr
        bcs done
        ldy #0
        lda val
        sta (t0),y
        inc t0
        bne loop
        inc t0+1
        jmp loop
done    jmp prompt
bad     jmp syntax
.)

; G [adr]
c_go
.(
        jsr get_expr
        bcs cont
        lda val
        sta rPC
        lda val+1
        sta rPC+1
        lda #0                  ; nouvelle adresse : on repart sans recharger
        sta ended
cont    jsr expect_end
        jmp go
.)

; T [n] / P [n]
c_trace
        lda #0
        beq tr_go
c_proc
        lda #1
tr_go
.(
        sta stepover
        jsr get_expr
        bcc n
        lda #1
        sta val
n       jsr expect_end
        lda val
        bne ok
        lda #1
ok      sta stepping
        lda #0
        sta go_after
        jmp do_step
.)

; B : liste ; B adr : pose ; B- [adr] : enlève (tous sans adresse)
c_bp
.(
        jsr skipsp
        cmp #"-"
        beq del
        jsr get_expr
        bcs list
        jsr expect_end
        ldx #0                  ; déjà posé ?
f1      lda bp_on,x
        beq f1n
        lda bp_lo,x
        cmp val
        bne f1n
        lda bp_hi,x
        cmp val+1
        beq list
f1n     inx
        cpx #NBP
        bne f1
        ldx #0                  ; place libre
f2      lda bp_on,x
        beq put
        inx
        cpx #NBP
        bne f2
        lda #<m_bpfull
        ldy #>m_bpfull
        jsr puts
        jmp prompt
put     lda val
        sta bp_lo,x
        lda val+1
        sta bp_hi,x
        lda #1
        sta bp_on,x
        jmp list
del     inc ip
        jsr get_expr
        bcs all
        jsr expect_end
        ldx #NBP-1
d1      lda bp_on,x
        beq d1n
        lda bp_lo,x
        cmp val
        bne d1n
        lda bp_hi,x
        cmp val+1
        bne d1n
        lda #0
        sta bp_on,x
d1n     dex
        bpl d1
        jmp list
all     ldx #NBP-1
        lda #0
d2      sta bp_on,x
        dex
        bpl d2
list    ldx #0
        stx bpcount
l1      lda bp_on,x
        beq l1n
        inc bpcount
        txa
        pha
        clc
        adc #"1"
        jsr putc
        lda #" "
        jsr putc
        pla
        pha
        tax
        lda bp_lo,x
        sta val
        lda bp_hi,x
        sta val+1
        jsr puthex4n
        lda #" "
        jsr putc
        jsr put_where
        jsr crlf
        pla
        tax
l1n     inx
        cpx #NBP
        bne l1
        lda bpcount
        bne done
        lda #<m_nobp
        ldy #>m_nobp
        jsr puts
done    jmp prompt
.)

; put_where : symbole de val (exact ou proche)
put_where
.(
        lda val
        pha
        lda val+1
        pha
        jsr sym_exact
        bcc nm
        jsr sym_near
        bcc nr
        pla
        pla
        rts
nm      pla
        pla
        jmp put_symname
nr      jsr put_symname
        lda #"+"
        jsr putc
        pla
        pla
        lda best
        sta val
        lda #0
        sta val+1
        jmp putdec
.)

; ? expr : valeur en hexa, en décimal, et symbole
c_eval
.(
        jsr get_expr
        bcs bad
        jsr expect_end
        jsr puthex4d
        lda #<m_eq
        ldy #>m_eq
        jsr puts
        lda val
        pha
        lda val+1
        pha
        jsr putdec
        pla
        sta val+1
        pla
        sta val
        lda #" "
        jsr putc
        jsr put_where
        jsr crlf
        jmp prompt
bad     jmp syntax
.)

c_help
        lda #<m_help
        ldy #>m_help
        jsr puts
        jmp prompt

; Q : rend les vecteurs et revient au système
c_quit
        sei
        lda old_wboot
        sta $0201
        lda old_wboot+1
        sta $0202
        lda old_irq
        sta $0207
        lda old_irq+1
        sta $0208
        lda old_nmi
        sta $020A
        lda old_nmi+1
        sta $020B
        lda #0
        sta TOP_CAP
        cli
        jmp WBOOT

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------
putc
        pha
        txa
        pha
        tya
        pha
        tsx
        lda $0103,x
        jsr B_CONOUT
        pla
        tay
        pla
        tax
        pla
        rts

puts
.(
        sta ptr
        sty ptr+1
        ldy #0
loop    lda (ptr),y
        beq done
        jsr putc
        iny
        bne loop
        inc ptr+1
        bne loop
done    rts
.)

crlf
        lda #13
        jsr putc
        lda #10
        jmp putc

; crlf_if : retour à la ligne si le curseur n'est pas en début de ligne
crlf_if
        lda CON_CURX
        cmp #2
        beq ci1
        jmp crlf
ci1     rts

puthex4d                        ; $hhhh
        lda #"$"
        jsr putc
puthex4n                        ; hhhh
        lda val+1
        jsr puthex2
        lda val
        jmp puthex2
puthex2d                        ; $hh
        pha
        lda #"$"
        jsr putc
        pla
puthex2
        pha
        lsr
        lsr
        lsr
        lsr
        jsr ph1
        pla
        and #15
ph1     stx tmpb
        tax
        lda hexdigits,x
        ldx tmpb
        jmp putc

putdec
.(
        lda #0
        sta kind+0
        ldx #0
dig     ldy #0
sub     lda val
        sec
        sbc d_lo,x
        pha
        lda val+1
        sbc d_hi,x
        bcc dn
        sta val+1
        pla
        sta val
        iny
        bne sub
dn      pla
        tya
        bne pr
        lda kind
        beq skip
        tya
pr      ora #"0"
        jsr putc
        lda #1
        sta kind
skip    inx
        cpx #4
        bne dig
        lda val
        ora #"0"
        jmp putc
d_lo    .byt <10000,<1000,<100,<10
d_hi    .byt >10000,>1000,>100,>10
.)

; ---------------------------------------------------------------------
; Données
; ---------------------------------------------------------------------
#include "asm_tab.s"

hexdigits .asc "0123456789ABCDEF"

m_usage   .asc "Usage : DEBUG NOM [parametres]",13,10,0
m_banner  .asc "DEBUG CP/A 1.0 - H pour l'aide",13,10,0
m_noprog  .asc "Programme introuvable",13,10,0
m_big     .asc "Programme trop gros",13,10,0
m_nosym   .asc "Symboles ignores : pas de place",13,10,0
m_com     .asc ".COM ",0
m_nsym    .asc " symboles en ",0
m_end     .asc "Programme termine (G relance en 0500).",13,10,0
m_nmi     .asc "*RESET*",13,10,0
m_brk     .asc "BRK dans le programme",13,10,0
m_bp      .asc "Point d'arret ",0
m_badop   .asc "Opcode inconnu",13,10,0
m_brkop   .asc "BRK : utiliser G",13,10,0
m_free    .asc "Hors du programme : execution libre",13,10,0
m_pc      .asc "PC=",0
m_a       .asc " A=",0
m_x       .asc " X=",0
m_y       .asc " Y=",0
m_s       .asc " S=",0
m_p       .asc "P=",0
m_flags   .asc "  N V - B D I Z C",13,10,0
m_pad     .asc "      ",0
m_3sp     .asc "   ",0
m_byt     .asc ".BYT ",0
m_cx      .asc ",X",0
m_cy      .asc ",Y",0
m_what    .asc "? (H pour l'aide)",13,10,0
m_syntax  .asc "Syntaxe ?",13,10,0
m_nosymb  .asc "Symbole inconnu",13,10,0
m_bpfull  .asc "8 points d'arret au plus",13,10,0
m_nobp    .asc "Aucun point d'arret",13,10,0
m_eq      .asc " = ",0
m_help    .asc "R [reg=v]  registres (A X Y S PC,",13,10
          .asc "           indicateurs N V D I Z C)",13,10
          .asc "L [adr]    desassemble",13,10
          .asc "D [adr]    memoire",13,10
          .asc "M adr bb.. modifie la memoire",13,10
          .asc "G [adr]    execute",13,10
          .asc "T [n]      pas a pas",13,10
          .asc "P [n]      pas a pas, JSR d'un coup",13,10
          .asc "B [adr]    points d'arret, B- [adr]",13,10
          .asc "? expr     valeur (nom, $hex, #dec)",13,10
          .asc "Q          quitter",13,10
          .asc "RESET arrete le programme.",13,10
          .asc "Indicateurs : N negatif, V debordement,",13,10
          .asc "B BRK, D decimal, I IRQ masquees,",13,10
          .asc "Z zero, C retenue.",13,10,0

dend
; zones de travail (hors du fichier)
dis_mn  = dend
dis_md  = dis_mn+256
ibuf    = dis_md+256
fcb_prg = ibuf+IBMAX+3
fcb_sym = fcb_prg+36
dtop    = fcb_sym+36
