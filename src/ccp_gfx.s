; =====================================================================

;  ccp_gfx.s — primitives graphiques au prompt (version ROM), ECHO, PAUSE
;
;  PEN m, PLOT x y, LINE x1 y1 x2 y2, BOX ..., FBOX ..., CIRCLE x y r,
;  GTEXT col y texte, ATTR col y1 y2 v, POINT x y : mêmes paramètres que
;  la fonction 115 du BDOS, en décimal (0 à 255). Il faut être en mode
;  SPLIT, et donner exactement le bon nombre de paramètres.
;  Version disque : ces commandes sont dans GRAPHER.COM (fichiers .GRX),
;  qui dessine aussi en HIRES plein écran ; get_byte reste (SAVE).
; =====================================================================

G_PEN    = 1
G_PLOT   = 2
G_LINE   = 3
G_BOX    = 4
G_FBOX   = 5
G_CIRCLE = 6
G_TEXT   = 7
G_ATTR   = 8
G_POINT  = 9


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
        lda #0                  ; ESC : fin du script
        sta scr_on
r       rts
.)

