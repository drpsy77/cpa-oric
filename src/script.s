; =====================================================================
;  script.s — DO fichier [p1 ... p9] : exécute les lignes de FICHIER.BAT
;
;  Chaque ligne est une commande, comme si on la tapait au prompt (elle
;  est affichée après « A> »). Les lignes vides et celles qui commencent
;  par « ; » sont ignorées. $1 à $9 sont remplacés par les paramètres
;  donnés à DO, $$ par $. Les programmes lancés par le script lisent le
;  clavier normalement. ESC au clavier entre deux lignes arrête le
;  script, de même qu'ESC pendant un PAUSE. Un DO dans un script passe
;  au nouveau script.
; =====================================================================

cmd_do
.(
        lda #<scr_fcb
        sta ZP_CFCB
        lda #>scr_fcb
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        lda #0
        sta scr_on
        ldx ccp_pos
        jsr parse_fcb
        stx ccp_cnt
        jsr check_name
        bcs syn
        lda scr_fcb+9           ; type BAT par défaut
        cmp #" "
        bne ext
        lda #"B"
        sta scr_fcb+9
        lda #"A"
        sta scr_fcb+10
        lda #"T"
        sta scr_fcb+11
ext     ldx #15
        lda #<scr_fcb
        ldy #>scr_fcb
        jsr bdos
        cmp #$FF
        bne found
        jmp no_file
found   ldx ccp_cnt             ; paramètres : la suite de la ligne
        jsr skip_spaces
        ldy #0
cp      lda ORIGBUF,x       ; paramètres tels que tapés
        sta scr_par,y
        beq done
        inx
        iny
        cpy #79
        bne cp
        lda #0
        sta scr_par,y
done    lda #128
        sta scr_idx
        lda #1
        sta scr_on
        rts
syn     jmp syntax_err
.)

; scr_getc : caractère suivant du script. C=1 en fin de fichier
scr_getc
.(
        ldx scr_idx
        bpl have
        lda #<scr_buf           ; enregistrement suivant
        sta dma
        lda #>scr_buf
        sta dma+1
        ldx #20
        lda #<scr_fcb
        ldy #>scr_fcb
        jsr bdos
        pha
        jsr dma_default
        pla
        cmp #0
        bne eof
        ldx #0
have    lda scr_buf,x
        inx
        stx scr_idx
        cmp #$1A
        beq eof
        clc
        rts
eof     lda #0
        sta scr_on
        sec
        rts
.)

; scr_line : ligne suivante du script dans CMDBUF (affichée).
; C=1 s'il n'y a pas (ou plus) de script : lire le clavier.
scr_line
.(
        lda scr_on
        bne go
no      sec
        rts
go      jsr const               ; ESC : arrêt du script
        beq next
        jsr conin_raw
        cmp #$1B
        bne next
        lda #0
        sta scr_on
        lda #<msg_scrstop
        ldy #>msg_scrstop
        jsr print_z
        sec
        rts
next    lda #0                  ; lit une ligne
        sta CMDBUF+1
rd      jsr scr_getc
        bcs eof
        cmp #$0D
        beq rd
        cmp #$0A
        beq eol
        cmp #9
        bne nt
        lda #" "
nt      cmp #"$"                ; $1-$9, $$
        bne store
        jsr scr_getc
        bcs eof
        cmp #"$"
        beq store
        sec
        sbc #"1"
        cmp #9
        bcs rd                  ; $ suivi d'autre chose : ignoré
        jsr put_param
        jmp rd
store   jsr add_char
        jmp rd
eof     lda CMDBUF+1            ; dernière ligne sans fin de ligne ?
        bne eol
        jmp no
eol     ldx CMDBUF+1            ; vide ou commentaire : suivante
        beq next
        lda CMDBUF+2
        cmp #";"
        beq next
        ldx #0                  ; affichage, comme si on l'avait tapée
show    cpx CMDBUF+1
        beq shown
        lda CMDBUF+2,x
        jsr conout
        inx
        bne show
shown   lda #0                  ; comme une ligne tapée : la pagination
        sta page_cnt            ; repart de zéro
        clc
        rts
.)

; add_char : ajoute A à la ligne (CMDMAX caractères au plus)
add_char
        ldx CMDBUF+1
        cpx #CMDMAX
        bcs ac_r
        sta CMDBUF+2,x
        inc CMDBUF+1
ac_r    rts

; put_param : recopie le paramètre numéro A (0 = $1) dans la ligne
put_param
.(
        sta ZP_T1
        ldy #0
word    jsr skip_sp             ; saute ZP_T1 mots
        lda ZP_T1
        beq copy
skipw   lda scr_par,y
        beq r
        cmp #" "
        beq endw
        iny
        bne skipw
endw    dec ZP_T1
        jmp word
copy    lda scr_par,y
        beq r
        cmp #" "
        beq r
        sty ZP_T0
        jsr add_char
        ldy ZP_T0
        iny
        bne copy
r       rts
skip_sp lda scr_par,y
        cmp #" "
        bne ss_r
        iny
        bne skip_sp
ss_r    rts
.)

msg_scrstop
        .asc "Script arrete.",13,10,0
