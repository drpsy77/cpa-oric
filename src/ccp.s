; =====================================================================
;  ccp.s — interpréteur de commandes (Console Command Processor)
; =====================================================================

ccp
.(
        jsr put_end             ; fin d'un PUT : fichier refermé
        lda cur_x               ; nouvelle ligne seulement si le curseur
        cmp #FIRST_COL          ; n'est pas déjà en début de ligne
        beq prompt
        jsr crlf
prompt  lda cur_drv             ; lecteur courant
        clc
        adc #"A"
        jsr conout
        lda #">"
        jsr conout
        lda chain_on            ; ligne laissée par CHAIN (BDOS 47) ?
        beq nochain
        lda #0
        sta chain_on
        tax
chs     cpx CMDBUF+1            ; affichée, comme une ligne de script
        beq scr
        lda CMDBUF+2,x
        jsr conout
        inx
        bne chs
nochain
        jsr scr_line            ; une ligne de script DO ?
        bcc scr

        lda #CMDMAX
        sta CMDBUF
        lda #<CMDBUF
        sta ZP_PTR
        lda #>CMDBUF
        sta ZP_PTR+1
        jsr read_line
scr     jsr crlf

        ; termine la ligne par 0 et la passe en majuscules
        ldx CMDBUF+1
        lda #0
        sta CMDBUF+2,x
        inx                     ; copie telle quelle (ECHO, GTEXT)
cpo     lda CMDBUF+2,x
        sta ORIGBUF,x
        dex
        bpl cpo
        ldx #0
up      lda CMDBUF+2,x
        beq parsed
        cmp #"a"
        bcc upn
        cmp #"z"+1
        bcs upn
        and #$DF
        sta CMDBUF+2,x
upn     inx
        bne up

parsed  ldx #0
        jmp ccp_run
.)

; ccp_run : exécute la commande qui commence en CMDBUF+2+X
ccp_run
.(
        jsr skip_spaces
        lda CMDBUF+2,x
        bne some
        jmp ccp                 ; ligne vide
some    stx ccp_pos
        lda CMDBUF+3,x          ; « X: » seul : changement de lecteur
        cmp #":"
        bne tbl
        lda CMDBUF+4,x
        beq drv
        cmp #" "
        bne tbl
drv     lda CMDBUF+2,x
        sec
        sbc #"A"
        ldx #14
        jsr bdos
        cmp #0
        beq dok
        jmp uk0                 ; « X:? »
dok     jmp ccp
tbl

        ; recherche dans la table des commandes internes
        lda #<cmd_table
        sta ZP_PTR2
        lda #>cmd_table
        sta ZP_PTR2+1
        ; une entrée : le nom, dernier caractère avec le bit 7, puis l'adresse
entry   ldy #0
        lda (ZP_PTR2),y
        beq unknown             ; fin de table
        ldx ccp_pos
cmpc    lda (ZP_PTR2),y
        and #$7F
        cmp CMDBUF+2,x
        bne skipl
        inx
        lda (ZP_PTR2),y
        iny
        asl                     ; C = bit 7 : fin du nom
        bcc cmpc
        lda CMDBUF+2,x          ; le mot tapé doit s'arrêter ici
        beq match
        cmp #" "
        beq match
        bne skipped             ; (Y est déjà sur l'adresse)
skipl   lda (ZP_PTR2),y         ; avance jusqu'au dernier caractère du nom
        iny
        asl
        bcc skipl
skipped tya
        clc
        adc #2                  ; adresse
        adc ZP_PTR2
        sta ZP_PTR2
        bcc entry
        inc ZP_PTR2+1
        bne entry

match   stx ccp_pos             ; position des arguments
        lda (ZP_PTR2),y
        sta ccp_vec
        iny
        lda (ZP_PTR2),y
        sta ccp_vec+1
        jsr call_cmd
        jmp ccp

unknown
        jsr run_transient       ; ne revient que si NOM.COM est introuvable
uk0     ldx ccp_pos             ; affiche le mot suivi de '?', comme CP/M
uk      lda CMDBUF+2,x
        beq ukq
        cmp #" "
        beq ukq
        jsr conout
        inx
        bne uk
ukq     lda #"?"
        jsr conout
        jmp ccp
.)

call_cmd
        jmp (ccp_vec)

; skip_spaces : avance X sur le premier caractère non espace
skip_spaces
.(
loop    lda CMDBUF+2,x
        cmp #" "
        bne end
        inx
        bne loop
end     rts
.)


; ---------------------------------------------------------------------
; Table des commandes internes : nom, 0, adresse
; ---------------------------------------------------------------------
cmd_table
        .asc "VE"
        .byt "R"|$80
        .word cmd_ver
        .asc "CL"
        .byt "S"|$80
        .word cmd_cls
        .asc "DI"
        .byt "R"|$80
        .word cmd_dir
        .asc "DIR"
        .byt "S"|$80
        .word cmd_dirs
        .asc "SPLI"
        .byt "T"|$80
        .word cmd_split
        .asc "TEX"
        .byt "T"|$80
        .word cmd_text
        .asc "GCL"
        .byt "S"|$80
        .word cmd_gcls
        .asc "PAPE"
        .byt "R"|$80
        .word cmd_paper
        .asc "IN"
        .byt "K"|$80
        .word cmd_ink
        .asc "PAG"
        .byt "E"|$80
        .word cmd_page
        .asc "ECH"
        .byt "O"|$80
        .word cmd_echo
        .asc "PAUS"
        .byt "E"|$80
        .word cmd_pause
        .asc "SAV"
        .byt "E"|$80
        .word cmd_save
        .asc "GSAV"
        .byt "E"|$80
        .word cmd_gsave
        .asc "GLOA"
        .byt "D"|$80
        .word cmd_gload
        .asc "PU"
        .byt "T"|$80
        .word cmd_put
        .asc "D"
        .byt "O"|$80
        .word cmd_do
        .byt 0


; SPLIT : image 240 x 128 en haut, texte en dessous
cmd_split
        jsr gcls
        jmp video_split

cmd_text
        jmp video_text

cmd_gcls
        lda vmode
        bne cg_ok
        lda #<msg_nosplit
        ldy #>msg_nosplit
        jmp print_z
cg_ok   jmp gcls


cmd_ver
        lda #<msg_banner
        ldy #>msg_banner
        jmp print_z

cmd_cls
        lda #$0C
        jmp conout

; PAPER n / INK n : couleur du fond / de l'encre (0-7) de toutes les lignes
;   de la console, comme les articles Papier et Encre du menu Ecran (la
;   même couleur pour les deux est permise ici)
cmd_paper
        ldy #cur_paper-cur_ink
        .byt $2C                ; BIT abs : saute l'instruction suivante
cmd_ink
        ldy #0
        sty ccp_cnt
        ldx ccp_pos
        jsr get_byte
        bcs cpi_syn
        cmp #8
        bcs cpi_syn
        ldy ccp_cnt
        sta cur_ink,y
        jmp apply_colors

; PAGE ON / PAGE OFF : pause quand l'écran est plein, ou non (comme
;   l'article Pagination du menu Ecran)
cmd_page
        ldx ccp_pos
        jsr skip_spaces
        lda CMDBUF+2,x
        cmp #"O"
        bne cpi_syn
        lda CMDBUF+3,x
        ldy #1
        cmp #"N"
        beq cpg_set
        dey
        cmp #"F"
        bne cpi_syn
cpg_set sty page_on
        rts
cpi_syn jmp syntax_err



syntax_err
        lda #<msg_syntax
        ldy #>msg_syntax
        jmp print_z

msg_nosplit
        .asc "Not in SPLIT mode.",13,10,0
msg_syntax
        .asc "Syntax?",13,10,0
