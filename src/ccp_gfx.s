; =====================================================================

;  ccp_gfx.s — primitives graphiques au prompt, ECHO et PAUSE
;
;  PEN m, PLOT x y, LINE x1 y1 x2 y2, BOX ..., FBOX ..., CIRCLE x y r,
;  GTEXT col y texte, ATTR col y1 y2 v, POINT x y : mêmes paramètres que
;  la fonction 115 du BDOS, en décimal (0 à 255). Il faut être en mode
;  SPLIT, et donner exactement le bon nombre de paramètres.
; =====================================================================

#ifndef DISK
ORIGBUF = CMDBUF+2       ; version ROM : pas de copie, texte en majuscules
#endif
G_PEN    = 1
G_PLOT   = 2
G_LINE   = 3
G_BOX    = 4
G_FBOX   = 5
G_CIRCLE = 6
G_TEXT   = 7
G_ATTR   = 8
G_POINT  = 9

cmd_pen    lda #G_PEN
           ldx #1
           bne gfx_cmd
cmd_plot   lda #G_PLOT
           ldx #2
           bne gfx_cmd
cmd_line   lda #G_LINE
           ldx #4
           bne gfx_cmd
cmd_box    lda #G_BOX
           ldx #4
           bne gfx_cmd
cmd_fbox   lda #G_FBOX
           ldx #4
           bne gfx_cmd
cmd_circle lda #G_CIRCLE
           ldx #3
           bne gfx_cmd
cmd_gtext  lda #G_TEXT
           ldx #2
           bne gfx_cmd
cmd_attr   lda #G_ATTR
           ldx #4
           bne gfx_cmd
cmd_point  lda #G_POINT
           ldx #2

gfx_cmd
.(
        sta cg_blk
        stx cg_n
        lda vmode               ; pas de bascule automatique
        bne split
        lda #<msg_nosplit
        ldy #>msg_nosplit
        jmp print_z
split   ldx ccp_pos
        lda #0
        sta cg_i
loop    lda cg_i
        cmp cg_n
        beq params
        jsr get_byte
        bcs syn
        ldy cg_i
        sta cg_blk+1,y
        inc cg_i
        jmp loop
params  jsr skip_spaces
        lda cg_blk
        cmp #G_TEXT             ; GTEXT : le reste de la ligne est le texte
        bne exact
        lda CMDBUF+2,x
        beq syn
        txa
        clc
        adc #<ORIGBUF
        sta cg_blk+3
        lda #>ORIGBUF
        adc #0
        sta cg_blk+4
        jmp call
exact   lda CMDBUF+2,x          ; rien de plus
        bne syn
call    ldx #GFX_FUNC
        lda #<cg_blk
        ldy #>cg_blk
        jsr bdos
        ldx cg_blk
        cpx #G_POINT            ; POINT : affiche 0 ou 1
        bne r
        ora #"0"
        jsr conout
        jmp crlf
r       rts
syn     jmp syntax_err
.)

; get_byte : nombre décimal 0-255 en CMDBUF+2+X -> A. C=1 si absent ou trop grand
get_byte
.(
        jsr skip_spaces
        lda #0
        sta dec_val
        sta hex_cnt
loop    lda CMDBUF+2,x
        sec
        sbc #"0"
        cmp #10
        bcs end
        sta ZP_T1
        lda dec_val             ; dec_val * 10 + chiffre, sans dépasser 255
        cmp #26
        bcs bad
        asl
        asl
        adc dec_val
        asl
        adc ZP_T1
        bcs bad
        sta dec_val
        inc hex_cnt
        inx
        bne loop
end     lda CMDBUF+2,x          ; le nombre doit finir par un espace
        beq ok
        cmp #" "
        bne bad
ok      lda hex_cnt
        beq bad
        lda dec_val
        clc
        rts
bad     sec
        rts
.)

; ECHO texte : affiche le texte (utile dans les scripts)
cmd_echo
.(
        ldx ccp_pos
        jsr skip_spaces
loop    lda ORIGBUF,x
        beq end
        jsr conout
        inx
        bne loop
end     jmp crlf
.)

; PAUSE [texte] : affiche le texte (ou un message), attend une touche.
; ESC arrête le script en cours.
cmd_pause
.(
        ldx ccp_pos
        jsr skip_spaces
        lda CMDBUF+2,x
        bne own
        lda #<msg_key
        ldy #>msg_key
        jsr print_z
        jmp wait
own     jsr cmd_echo
wait    jsr conin_raw
        cmp #$1B
        bne r
#ifdef DISK
        lda #0                  ; ESC : fin du script
        sta scr_on
#endif
r       rts
.)

msg_key .asc "Une touche pour continuer...",13,10,0
