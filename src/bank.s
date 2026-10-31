; =====================================================================
;  bank.s — banques de la fenêtre (win.s) : chargeur de CPA.BNK et
;           appel d'une routine de banque
;
;  La fenêtre $F7C0-$F9FF reçoit une banque à la fois : PUT (dans
;  l'image du système, et dans CPA.BNK pour être rechargé) ou IMG
;  (img.s : GSAVE, GLOAD, SAVE, chargée de CPA.BNK quand elle sert).
;  win_id dit laquelle est là (0 : aucune, après un chargement manqué).
;  CPA.BNK est cherché comme un programme (lecteur courant ou du script,
;  puis A: à D:) ; sa signature doit être celle du système (bnk_sig,
;  posée par tools/mkbnk.py) : une banque d'une autre version est refusée.
;
;  Format de CPA.BNK (enregistrements de 128 octets) : enregistrement 0 =
;  signature (2 octets) ; la banque de bit b de win_id occupe les 5
;  enregistrements 5b-4 à 5b (PUT : 1-5, IMG : 6-10), soit la fenêtre
;  entière WIN-WIN_END (576 octets) et un demi-enregistrement de bourrage.
;  Chaque enregistrement est lu dans BNK_BUF (fin du tampon de PUT :
;  pendant un prêt, ce qui reste à écrire du tampon, moins de 128 octets,
;  est en tête), puis recopié dans la fenêtre, sans rien écrire au-delà
;  de WIN_END.
; =====================================================================

bnk_sig .word 0                 ; signature du système (tools/mkbnk.py)

; Points d'entrée de la banque IMG (img.s)
g_gsave_r                       ; BDOS 115 op 12
        ldx #<g_gsave
        ldy #>g_gsave
        bne img_call
g_gload_r                       ; BDOS 115 op 13
        ldx #<g_gload
        ldy #>g_gload
        bne img_call
cmd_save                        ; SAVE n fichier
        ldx #<i_save
        ldy #>i_save
        bne img_call
cmd_gsave                       ; GSAVE fichier
        ldx #<i_gsave
        ldy #>i_gsave
        bne img_call
cmd_gload                       ; GLOAD fichier
        ldx #<i_gload
        ldy #>i_gload
img_call
        lda #WIN_IMG
        ; continue sur win_call

; win_call : appelle la routine X/Y (bas, haut) de la banque A (bit de
;   win_id), chargée d'abord si elle n'est pas dans la fenêtre. Pendant
;   un PUT (prêt de la fenêtre) : tampon écrit, copie suspendue, banque
;   chargée, routine, PUT rechargé, copie rendue ; ce que la routine
;   affiche n'est pas copié. Rend le A de la routine, ou $FF si la banque
;   n'a pas pu être chargée (message affiché).
win_call
.(
        stx bk_ent
        sty bk_ent+1
        sta bk_id
        and win_id
        bne go
        lda put_on
        sta bk_put
        beq ld
        bit put_pend            ; le tampon de PUT est écrit avant le prêt
        bpl np
        jsr W_FLUSH
np      lda #0
        sta put_on
ld      lda bk_id
        jsr bnk_load
        bcs back
        jsr go
        pha
        jsr back
        pla
        rts
back    lda bk_put              ; PUT engagé (copie en cours, ou fichier à
        ora put_lost            ; refermer après un disque plein) : rechargé
        beq nr
        lda win_id
        lsr                     ; (WIN_PUT)
        bcs rs
        lda #WIN_PUT
        jsr bnk_load
        bcs nr                  ; PUT perdu : la copie reste arrêtée
rs      lda bk_put
        sta put_on
nr      lda #$FF
        rts
go      jmp (bk_ent)
.)

; bnk_load : charge la banque A (bit de win_id) de CPA.BNK dans la
;   fenêtre. C=0 : chargée, win_id = A. C=1 : « CPA.BNK? » affiché ;
;   fenêtre intacte si CPA.BNK manque ou n'est pas de cette version, sinon
;   vide (win_id = 0). DMA et FCB de l'appelant gardés (BNK_FCB, BNK_BUF).
bnk_load
.(
        sta bk_id2
        lda dma
        sta bk_dma
        lda dma+1
        sta bk_dma+1
        ldx #35                 ; FCB : CPA.BNK, octets 12-35 à 0
cf      lda #0
        cpx #12
        bcs z
        lda bnk_name,x
z       sta BNK_FCB,x
        dex
        bpl cf
        lda #<BNK_FCB
        sta ZP_CFCB
        lda #>BNK_FCB
        sta ZP_CFCB+1
        jsr open_com
        bne op
        jmp bad
op      lda #<BNK_BUF
        sta dma
        lda #>BNK_BUF
        sta dma+1
        lda #0                  ; enregistrement 0 : signature
        jsr bk_read
        bne bad
        lda BNK_BUF
        cmp bnk_sig
        bne bad
        lda BNK_BUF+1
        cmp bnk_sig+1
        bne bad
        lda bk_id2              ; banque de bit b : enregistrements 5b-4...
        asl
        asl
        adc bk_id2              ; (C=0)
        sbc #4-1                ; (C=0 : -4)
        sta bk_rec
        lda #0                  ; la fenêtre change
        sta win_id
        lda #<WIN
        sta bk_dst
        lda #>WIN
        sta bk_dst+1
rec     lda bk_rec
        jsr bk_read
        bne bad
        lda bk_dst
        sta ZP_PTR2
        lda bk_dst+1
        sta ZP_PTR2+1
        sec                     ; octets à copier : 128, ou ce qui reste
        lda #<WIN_END           ; jusqu'à WIN_END
        sbc bk_dst
        tax
        lda #>WIN_END
        sbc bk_dst+1
        bne n128
        cpx #128
        bcc nx
n128    ldx #128
nx      stx bk_n
        ldy #0
cp      lda BNK_BUF,y
        sta (ZP_PTR2),y
        iny
        cpy bk_n
        bne cp
        cpy #128
        bne done                ; dernier morceau
        inc bk_rec
        tya                     ; adresse suivante : + 128
        clc
        adc bk_dst
        sta bk_dst
        bcc rec
        inc bk_dst+1
        bne rec                 ; (toujours)
bad     lda #<msg_bnk
        ldy #>msg_bnk
        jsr print_z
        sec
        bcs end
done    lda bk_id2
        sta win_id
        clc
end     php
        lda bk_dma
        sta dma
        lda bk_dma+1
        sta dma+1
        plp
        rts
; bk_read : enregistrement A de CPA.BNK dans BNK_BUF (lecture directe,
;   fonction 33) ; Z=1 si lu
bk_read
        sta BNK_FCB+33
        lda #0
        sta BNK_FCB+34
        sta BNK_FCB+35
        ldx #33
        lda #<BNK_FCB
        ldy #>BNK_FCB
        jsr bdos
        cmp #0
        rts
.)

bnk_name
        .byt 0
        .asc "CPA     BNK"
msg_bnk
        .asc "CPA.BNK?",13,10,0
