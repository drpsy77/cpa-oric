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
prompt  lda #"A"
        jsr conout
        lda #">"
        jsr conout
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

        ; recherche dans la table des commandes internes
        lda #<cmd_table
        sta ZP_PTR2
        lda #>cmd_table
        sta ZP_PTR2+1
entry   ldy #0
        lda (ZP_PTR2),y
        beq unknown             ; fin de table
        ldx ccp_pos
cmpc    lda (ZP_PTR2),y
        beq endname
        cmp CMDBUF+2,x
        bne nomatch
        inx
        iny
        bne cmpc
endname lda CMDBUF+2,x          ; le mot tapé doit s'arrêter ici
        beq match
        cmp #" "
        beq match
nomatch ldy #0                  ; avance jusqu'à l'entrée suivante
skipl   lda (ZP_PTR2),y
        beq skipped
        iny
        bne skipl
skipped tya
        clc
        adc #3                  ; 0 de fin + adresse
        adc ZP_PTR2
        sta ZP_PTR2
        bcc entry
        inc ZP_PTR2+1
        bne entry

match   stx ccp_pos             ; position des arguments
        iny
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
        ldx ccp_pos             ; affiche le mot suivi de '?', comme CP/M
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
        .asc "HELP",0           ; version disque : HELP.COM
        .word cmd_help
        .asc "?",0
        .word cmd_help
        .asc "MEM",0
        .word cmd_mem
        .asc "DUMP",0           ; version disque : DEBUG.COM
        .word cmd_dump
        .asc "POKE",0
        .word cmd_poke
        .asc "GO",0
        .word cmd_go
#endif
        .asc "VER",0
        .word cmd_ver
        .asc "CLS",0
        .word cmd_cls
        .asc "DIR",0
        .word cmd_dir
#ifdef DISK
        .asc "DIRS",0
        .word cmd_dirs
#endif
        .asc "A:",0
        .word cmd_nop
        .asc "SPLIT",0
        .word cmd_split
        .asc "TEXT",0
        .word cmd_text
        .asc "GCLS",0
        .word cmd_gcls
        .asc "PEN",0
        .word cmd_pen
        .asc "PLOT",0
        .word cmd_plot
        .asc "LINE",0
        .word cmd_line
        .asc "BOX",0
        .word cmd_box
        .asc "FBOX",0
        .word cmd_fbox
        .asc "CIRCLE",0
        .word cmd_circle
        .asc "GTEXT",0
        .word cmd_gtext
        .asc "ATTR",0
        .word cmd_attr
        .asc "POINT",0
        .word cmd_point
        .asc "ECHO",0
        .word cmd_echo
        .asc "PAUSE",0
        .word cmd_pause
#ifdef DISK
        .asc "TYPE",0
        .word cmd_type
        .asc "ERA",0
        .word cmd_era
        .asc "REN",0
        .word cmd_ren
        .asc "SAVE",0
        .word cmd_save
        .asc "GSAVE",0
        .word cmd_gsave
        .asc "GLOAD",0
        .word cmd_gload
        .asc "PUT",0
        .word cmd_put
        .asc "DO",0
        .word cmd_do
#endif
        .byt 0

cmd_nop
        rts

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
        .asc "Keys: CTRL-T caps, CTRL-X kill,",13,10
        .asc "      CTRL-C reboot, DEL erase",13,10,0
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
