; =====================================================================
;  put.s — PUT fichier commande : copie la sortie console dans un fichier
;
;  Les caractères affichés par conout sont aussi rangés dans un tampon
;  (PUTBUF, 1280 octets, dans la RAM overlay). Écrire sur le disque
;  depuis conout serait dangereux (conout est appelé au milieu d'une
;  fonction du BDOS, ou entre deux appels liés comme « chercher premier /
;  suivant ») : les enregistrements pleins sont écrits à l'entrée du
;  BDOS suivant, en sauvant puis en rendant l'état du système de
;  fichiers (page zéro, variables, DMA). Le fichier est refermé, complété
;  par des ^Z, au retour au prompt ou au démarrage à chaud.
;  Si le programme affiche sans jamais appeler le BDOS, le tampon peut
;  déborder : la fin de la sortie est alors perdue (message à la fin).
; =====================================================================

; put_char : range A dans le tampon (appelé par conout). Préserve A, X, Y
put_char
.(
        pha
        lda put_cnt+1           ; tampon plein ?
        cmp #>PUTMAX
        bcc ok
        lda #1
        sta put_lost
        pla
        rts
ok      clc                     ; adresse = PUTBUF + put_cnt
        adc #>PUTBUF
        sta pc_st+2
        lda put_cnt
        sta pc_st+1
        pla
        pha
pc_st   sta PUTBUF
        inc put_cnt
        bne c1
        inc put_cnt+1
c1      lda put_cnt+1           ; un enregistrement complet : à écrire
        bne pend
        lda put_cnt
        bpl done
pend    lda #$80
        sta put_pend
done    pla
        rts
.)

; put_nl : CR LF dans le fichier seulement (ligne remplie à l'écran par
; le retour automatique, comme celles de DIR)
put_nl
        lda put_on
        beq pn_r
        lda #13
        jsr put_char
        lda #10
        jmp put_char
pn_r    rts

; put_flush : écrit les enregistrements complets. Appelé à l'entrée du
; BDOS (aucune fonction en cours) ou par put_end. Préserve A, X, Y et
; l'état du système de fichiers.
put_flush
.(
        pha
        txa
        pha
        tya
        pha
        lda #0
        sta put_pend
        ldx #PUT_NZP-1          ; sauve la page zéro système
sz      lda $E0,x
        sta PUT_SAVE,x
        dex
        bpl sz
        ldx #11                 ; variables du disque et du FS (sans le cache)
sv1     lda dsk_lsn,x
        sta PUT_SAVE+PUT_NZP,x
        dex
        bpl sv1
        ldx #11
sv2     lda dir_i,x
        sta PUT_SAVE+PUT_NZP+12,x
        dex
        bpl sv2
        lda dma
        sta PUT_SAVE+PUT_NZP+24
        lda dma+1
        sta PUT_SAVE+PUT_NZP+25
        lda bdos_a
        sta PUT_SAVE+PUT_NZP+26
        lda bdos_y
        sta PUT_SAVE+PUT_NZP+27
        lda #<PUTBUF            ; enregistrements complets
        sta dma
        lda #>PUTBUF
        sta dma+1
wl      lda put_cnt+1
        bne one
        lda put_cnt
        bpl rest
one     ldx #21
        lda #<put_fcb
        ldy #>put_fcb
        jsr bdos
        cmp #0
        beq wok
        lda #2                  ; disque plein : on arrête la capture
        sta put_lost
        lda #0
        sta put_on
        sta put_cnt
        sta put_cnt+1
        beq rs
wok     clc
        lda dma
        adc #128
        sta dma
        bcc w1
        inc dma+1
w1      sec
        lda put_cnt
        sbc #128
        sta put_cnt
        bcs wl
        dec put_cnt+1
        jmp wl
rest    ldy #0                  ; le reste (< 128) revient au début
        ldx put_cnt
        beq rs
        lda dma
        sta pr_ld+1
        lda dma+1
        sta pr_ld+2
mv      cpy put_cnt
        beq rs
pr_ld   lda PUTBUF,y
        sta PUTBUF,y
        iny
        bne mv
rs      ldx #PUT_NZP-1          ; rend l'état
rz      lda PUT_SAVE,x
        sta $E0,x
        dex
        bpl rz
        ldx #11
rv1     lda PUT_SAVE+PUT_NZP,x
        sta dsk_lsn,x
        dex
        bpl rv1
        ldx #11
rv2     lda PUT_SAVE+PUT_NZP+12,x
        sta dir_i,x
        dex
        bpl rv2
        lda PUT_SAVE+PUT_NZP+24
        sta dma
        lda PUT_SAVE+PUT_NZP+25
        sta dma+1
        lda PUT_SAVE+PUT_NZP+26
        sta bdos_a
        lda PUT_SAVE+PUT_NZP+27
        sta bdos_y
        pla
        tay
        pla
        tax
        pla
        rts
.)

; put_end : termine la capture (prompt, démarrage à chaud)
put_end
.(
        lda put_on
        bne go
        rts
go      jsr put_flush
        lda put_on              ; arrêtée par une erreur ?
        beq close
        ldx put_cnt             ; dernier enregistrement complété par ^Z
        beq close
        lda #$1A
pad     sta PUTBUF,x
        inx
        bpl pad
        stx put_cnt
        jsr put_flush
close   lda #0
        sta put_on
        sta put_pend
        ldx #16
        lda #<put_fcb
        ldy #>put_fcb
        jsr bdos
        lda put_lost
        beq r
        cmp #2
        beq full
        lda #<msg_putlost
        ldy #>msg_putlost
        jmp print_z
full    lda #<msg_dfull
        ldy #>msg_dfull
        jmp print_z
r       rts
.)

; PUT fichier commande [paramètres]
cmd_put
.(
        lda put_on              ; pas de PUT dans un PUT
        bne bad
        lda #<put_fcb
        sta ZP_CFCB
        lda #>put_fcb
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        ldx ccp_pos
        jsr pf_chk
        bcs bad
        jsr skip_spaces         ; une commande doit suivre
        lda CMDBUF+2,x
        beq bad
        stx ccp_cnt
        ldx #19                 ; remplace un fichier existant
        lda #<put_fcb
        ldy #>put_fcb
        jsr bdos
        ldx #12
        lda #0
z       sta put_fcb,x
        inx
        cpx #36
        bne z
        ldx #22
        lda #<put_fcb
        ldy #>put_fcb
        jsr bdos
        cmp #$FF
        beq full
        lda #0
        sta put_cnt
        sta put_cnt+1
        sta put_pend
        sta put_lost
        lda #1
        sta put_on
        pla                     ; on ne revient pas à call_cmd
        pla
        ldx ccp_cnt
        jmp ccp_run             ; exécute la commande
full    lda #<msg_dirfull
        ldy #>msg_dirfull
        jmp print_z
bad     jmp syntax_err
.)

msg_putlost
        .asc "PUT: end lost (too long)",13,10,0
