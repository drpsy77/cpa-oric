; =====================================================================
;  ccp.s — interpréteur de commandes (Console Command Processor)
; =====================================================================

ccp
.(
#ifdef DISK
        jsr put_end             ; fin d'un PUT : fichier refermé
#endif
        lda cur_x               ; nouvelle ligne seulement si le curseur
        cmp #FIRST_COL          ; n'est pas déjà en début de ligne
        beq prompt
        jsr crlf
#ifdef DISK
prompt  lda cur_drv             ; lecteur courant
        clc
        adc #"A"
#else
prompt  lda #"A"
#endif
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
#ifdef DISK
        jsr scr_line            ; une ligne de script DO ?
        bcc scr
#endif

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
#ifdef DISK
        inx                     ; copie telle quelle (ECHO, GTEXT)
cpo     lda CMDBUF+2,x
        sta ORIGBUF,x
        dex
        bpl cpo
#endif
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
#ifdef DISK
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
#endif

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
#ifdef DISK
        jsr run_transient       ; ne revient que si NOM.COM est introuvable
#endif
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

#ifndef DISK
; parse_hex : lit jusqu'à 4 chiffres hexa à partir de ccp_pos
;   -> hex_val, C=1 si aucun chiffre trouvé. Met à jour ccp_pos.
parse_hex
.(
        lda #0
        sta hex_val
        sta hex_val+1
        sta hex_cnt
        ldx ccp_pos
        jsr skip_spaces
loop    lda CMDBUF+2,x
        sec
        sbc #"0"
        cmp #10
        bcc digit
        sbc #7                  ; 'A'-'0'-10 = 7 (C=1 ici)
        cmp #10
        bcc bad
        cmp #16
        bcs bad
digit   ldy #4
shl     asl hex_val
        rol hex_val+1
        dey
        bne shl
        ora hex_val
        sta hex_val
        inc hex_cnt
        inx
        bne loop
bad     stx ccp_pos
        lda hex_cnt
        cmp #1                  ; C=0 si au moins un chiffre
        bcc none
        clc
        rts
none    sec
        rts
.)
#endif

; ---------------------------------------------------------------------
; Table des commandes internes : nom, 0, adresse
; ---------------------------------------------------------------------
cmd_table
#ifndef DISK
        .asc "HEL"           ; version disque : HELP.COM
        .byt "P"|$80
        .word cmd_help
        .byt "?"|$80
        .word cmd_help
        .asc "ME"
        .byt "M"|$80
        .word cmd_mem
        .asc "DUM"           ; version disque : DEBUG.COM
        .byt "P"|$80
        .word cmd_dump
        .asc "POK"
        .byt "E"|$80
        .word cmd_poke
        .asc "G"
        .byt "O"|$80
        .word cmd_go
#endif
        .asc "VE"
        .byt "R"|$80
        .word cmd_ver
        .asc "CL"
        .byt "S"|$80
        .word cmd_cls
        .asc "DI"
        .byt "R"|$80
        .word cmd_dir
#ifdef DISK
        .asc "DIR"
        .byt "S"|$80
        .word cmd_dirs
#endif
#ifndef DISK
        .asc "A"
        .byt ":"|$80
        .word cmd_nop
#endif
        .asc "SPLI"
        .byt "T"|$80
        .word cmd_split
        .asc "TEX"
        .byt "T"|$80
        .word cmd_text
        .asc "GCL"
        .byt "S"|$80
        .word cmd_gcls
        .asc "PE"
        .byt "N"|$80
        .word cmd_pen
        .asc "PLO"
        .byt "T"|$80
        .word cmd_plot
        .asc "LIN"
        .byt "E"|$80
        .word cmd_line
        .asc "BO"
        .byt "X"|$80
        .word cmd_box
        .asc "FBO"
        .byt "X"|$80
        .word cmd_fbox
        .asc "CIRCL"
        .byt "E"|$80
        .word cmd_circle
        .asc "GTEX"
        .byt "T"|$80
        .word cmd_gtext
        .asc "ATT"
        .byt "R"|$80
        .word cmd_attr
        .asc "POIN"
        .byt "T"|$80
        .word cmd_point
        .asc "ECH"
        .byt "O"|$80
        .word cmd_echo
        .asc "PAUS"
        .byt "E"|$80
        .word cmd_pause
#ifdef DISK
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
#endif
        .byt 0

#ifndef DISK
cmd_nop
        rts
#endif

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

#ifndef DISK
cmd_help
        lda #<msg_help
        ldy #>msg_help
        jmp print_z
#endif

cmd_ver
        lda #<msg_banner
        ldy #>msg_banner
        jmp print_z

cmd_cls
        lda #$0C
        jmp conout

#ifndef DISK
cmd_mem
        lda #<msg_mem
        ldy #>msg_mem
        jmp print_z
#endif

#ifndef DISK
cmd_dir
        lda #<msg_nodisk
        ldy #>msg_nodisk
        jmp print_z
#endif

#ifndef DISK
; DUMP [adresse] : 8 lignes de 8 octets
cmd_dump
.(
        jsr parse_hex
        bcs cont
        lda hex_val
        sta dump_addr
        lda hex_val+1
        sta dump_addr+1
cont    lda #8
        sta ZP_T0
line    lda dump_addr+1
        ldy dump_addr
        jsr print_hex16
        lda dump_addr
        sta ZP_PTR
        lda dump_addr+1
        sta ZP_PTR+1
        ldy #0
hexl    lda #" "
        jsr conout
        lda (ZP_PTR),y
        jsr print_hex8
        iny
        cpy #8
        bne hexl
        lda #" "
        jsr conout
        ldy #0
ascl    lda (ZP_PTR),y
        cmp #$20
        bcc dot
        cmp #$7F
        bcc asc2
dot     lda #"."
asc2    jsr conout
        iny
        cpy #8
        bne ascl
        jsr crlf
        lda dump_addr
        clc
        adc #8
        sta dump_addr
        bcc nc
        inc dump_addr+1
nc      dec ZP_T0
        bne line
        rts
.)

; POKE adresse octet [octet…]
cmd_poke
.(
        jsr parse_hex
        bcs err
        lda hex_val
        sta ZP_PTR
        lda hex_val+1
        sta ZP_PTR+1
        ldy #0
        sty ZP_T0
loop    jsr parse_hex
        bcs end
        lda hex_val
        ldy ZP_T0
        sta (ZP_PTR),y
        inc ZP_T0
        bne loop
end     lda ZP_T0
        beq err
        rts
err     jmp syntax_err
.)

; GO adresse : appelle un programme ; RTS ramène au CCP
cmd_go
.(
        jsr parse_hex
        bcs err
        lda hex_val
        sta ccp_vec
        lda hex_val+1
        sta ccp_vec+1
        jsr call_cmd
        jmp wboot
err     jmp syntax_err
.)

#endif
syntax_err
        lda #<msg_syntax
        ldy #>msg_syntax
        jmp print_z

#ifndef DISK
msg_help
        .asc "HELP        this list",13,10
        .asc "VER         version",13,10
        .asc "CLS         clear screen",13,10
        .asc "MEM         memory map",13,10
#ifdef DISK
        .asc "DIR [afn]   list files",13,10
        .asc "TYPE file   show text file",13,10
        .asc "ERA afn     erase files",13,10
        .asc "REN new=old rename",13,10
        .asc "SAVE n file save n pages from 0500",13,10
        .asc "NAME [args] run NAME.COM",13,10
#else
        .asc "DIR         list files",13,10
#endif
        .asc "DUMP [adr]  show memory",13,10
        .asc "POKE adr bb bb...",13,10
        .asc "GO adr      run code (RTS = back)",13,10
        .asc "SPLIT/TEXT  image+text / text only",13,10
        .asc "GCLS        clear the image",13,10
        .asc "PEN m  PLOT x y  LINE x1 y1 x2 y2",13,10
        .asc "BOX/FBOX x1 y1 x2 y2  CIRCLE x y r",13,10
        .asc "GTEXT col y text  POINT x y",13,10
        .asc "ATTR col y1 y2 v  ECHO text  PAUSE",13,10
#ifdef DISK
        .asc "GSAVE/GLOAD file  save/load image",13,10
        .asc "PUT file cmd  output of cmd to file",13,10
        .asc "DO file [p1..p9]  run file.BAT",13,10
#endif
        .asc "Keys: CTRL-T caps (A/a), CTRL-P",13,10
        .asc "      printer (P), CTRL-X kill,",13,10
        .asc "      CTRL-C reboot, DEL erase,",13,10
        .asc "      <- -> edit, up/down history",13,10,0
msg_mem
        .asc "0000-00DF zero page (free)",13,10
        .asc "0200      WBOOT  0203 BDOS",13,10
        .asc "0400-04FF base page (DMA 0480)",13,10
        .asc "0500-B3FF TPA, 44800 bytes",13,10
        .asc "B400-BB7F charsets",13,10
        .asc "BB80-BFDF screen",13,10
        .asc "SPLIT: image A000-B3FF, TPA to 9FFF",13,10
#ifdef DISK
        .asc "C000-FFFF CP/A (overlay RAM)",13,10,0
#else
        .asc "C000-FFFF CP/A ROM",13,10,0
#endif
#endif
#ifndef DISK
msg_nodisk
        .asc "No disk in the ROM version.",13,10,0
#endif
msg_nosplit
        .asc "Not in SPLIT mode.",13,10,0
msg_syntax
        .asc "Syntax?",13,10,0
