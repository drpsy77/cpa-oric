; =====================================================================
;  cold.s — ce que seul le démarrage à froid fait : test de la RAM, et
;  (version disquette) lancement de A:AUTO.BAT.
;  Version disquette : dans la fenêtre (win.s), appelé par cold_boot si
;  win_id a le bit WIN_COLD, effacé ensuite par le tampon de PUT.
;  Version ROM : résident.
; =====================================================================

#ifdef DISK
; cold_win : test de la RAM et son compte rendu, puis AUTO.BAT ; la
;   fenêtre ne garde ensuite que PUT (un BOOT plus tard ne revient pas ici)
cold_win
.(
        jsr ram_test
        jsr ram_report
        lda #WIN_PUT
        sta win_id
        jsr fs_reset            ; A: (cur_drv = 0), DMA en $0480
        ldx #11                 ; FCB : A:AUTO.BAT
cf      lda auto_fcb,x
        sta CCP_FCB,x
        dex
        bpl cf
        lda #0
        sta CCP_FCB+12          ; extent 0
        inc io_quiet            ; pas de message si A: ne répond pas
        ldx #17                 ; cherche le premier
        lda #<CCP_FCB
        ldy #>CCP_FCB
        jsr bdos
        dec io_quiet
        cmp #$FF
        beq r
        ldx #3                  ; trouvé : ligne « AUTO » laissée au CCP,
cl      lda auto_fcb+1,x        ; comme par CHAIN (affichée, puis exécutée
        sta CMDBUF+2,x          ; comme un script : ESC l'arrête entre
        dex                     ; deux lignes)
        bpl cl
        lda #4
        sta CMDBUF+1
        lda #1
        sta chain_on
r       rts
auto_fcb
        .byt 1
        .asc "AUTO    BAT"
.)
#endif

; ---------------------------------------------------------------------
; ram_test : comme la ROM de l'Atmos, écrit $AA puis $55 dans chaque
;   octet de la TPA et vérifie la relecture ; laisse ensuite $00 (BRK),
;   pour qu'un saut perdu dans la TPA soit intercepté.
;   ram_badf <> 0 si un octet est défectueux (premier en ram_bad).
; ---------------------------------------------------------------------
ram_test
.(
        lda #<TPA_START
        sta ZP_PTR
        lda #>TPA_START
        sta ZP_PTR+1
        ldy #0
loop    lda #$AA
        sta (ZP_PTR),y
        cmp (ZP_PTR),y
        bne bad
        lsr                     ; $55
        sta (ZP_PTR),y
        cmp (ZP_PTR),y
        bne bad
next    lda #0
        sta (ZP_PTR),y
        iny
        bne loop
        inc ZP_PTR+1
        lda ZP_PTR+1
        cmp #>TPA_END
        bne loop
        rts
bad     lda ram_badf
        bne next
        inc ram_badf
        sty ram_bad
        lda ZP_PTR+1
        sta ram_bad+1
        jmp next
.)

ram_report
        lda ram_badf
        bne rr_bad
        lda #<msg_ramok
        ldy #>msg_ramok
        jmp print_z
rr_bad  lda #<msg_rambad
        ldy #>msg_rambad
        jsr print_z
        lda ram_bad+1
        ldy ram_bad
        jsr print_hex16
        jmp crlf

msg_ramok
        .asc "RAM test OK.",13,10,0
msg_rambad
        .asc "RAM error at ",0
