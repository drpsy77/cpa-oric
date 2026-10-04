; =====================================================================
;  ccp_disk.s — commandes disque du CCP et lancement des .COM
; =====================================================================

; ---------------------------------------------------------------------
; Analyse d'un nom de fichier
; ---------------------------------------------------------------------
; parse_fcb : lit un nom ([d:]nom[.ext], jokers * et ?) à partir de la
;   position X de la ligne et remplit le FCB pointé par ZP_CFCB.
;   pf_len = nombre d'octets du FCB à initialiser (36, ou 16 pour FCB2).
;   Retour : X après le nom.
parse_fcb
.(
        jsr skip_spaces
        ldy #0
        lda #0
        sta (ZP_CFCB),y
        lda CMDBUF+2,x
        beq nodrv
        lda CMDBUF+3,x
        cmp #":"
        bne nodrv
        lda CMDBUF+2,x
        sec
        sbc #"@"
        sta (ZP_CFCB),y
        inx
        inx
nodrv   ldy #1
        lda #9
        sta pf_end
        jsr field
        ldy #9
        lda #12
        sta pf_end
        lda CMDBUF+2,x
        cmp #"."
        bne noext
        inx
        jsr field
        jmp tail
noext   jsr pad_field
tail    ldy #12
        lda #0
z       sta (ZP_CFCB),y
        iny
        cpy pf_len
        bne z
        rts
.)

; field : recopie un champ (nom ou type) jusqu'à pf_end
field
.(
loop    cpy pf_end
        beq skip
        lda CMDBUF+2,x
        jsr is_delim
        beq pad_field
        cmp #"*"
        beq star
        sta (ZP_CFCB),y
        inx
        iny
        bne loop
star    lda #"?"
st      sta (ZP_CFCB),y
        iny
        cpy pf_end
        bne st
        inx
skip    lda CMDBUF+2,x          ; ignore les caractères en trop
        jsr is_delim
        beq done
        inx
        bne skip
done    rts
.)

pad_field
.(
        lda #" "
loop    cpy pf_end
        beq done
        sta (ZP_CFCB),y
        iny
        bne loop
done    rts
.)

; is_delim : Z=1 si A est un séparateur de nom (A préservé)
is_delim
        cmp #0
        beq isd
        cmp #" "
        beq isd
        cmp #"."
        beq isd
        cmp #"="
        beq isd
        cmp #","
        beq isd
        cmp #";"
isd     rts

; has_wild : C=1 si le nom contient un joker
has_wild
.(
        ldy #11
loop    lda (ZP_CFCB),y
        cmp #"?"
        beq yes
        dey
        bne loop
        clc
        rts
yes     sec
        rts
.)

; all_wild : C=1 si le nom est entièrement fait de jokers (*.*)
all_wild
.(
        ldy #11
loop    lda (ZP_CFCB),y
        cmp #"?"
        bne no
        dey
        bne loop
        sec
        rts
no      clc
        rts
.)

; check_name : C=1 si le nom est vide ou contient un joker
check_name
        ldy #1
        lda (ZP_CFCB),y
        cmp #" "
        beq cn_bad
        jmp has_wild
cn_bad  sec
        rts

; is_empty : C=1 si aucun nom n'a été donné
is_empty
        ldy #1
        lda (ZP_CFCB),y
        cmp #" "
        beq ie_yes
        clc
        rts
ie_yes  sec
        rts

cf_def
        lda #<DEF_FCB
        sta ZP_CFCB
        lda #>DEF_FCB
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        rts

dma_default
        lda #<DEF_DMA
        sta dma
        lda #>DEF_DMA
        sta dma+1
        rts

; bdos_def : appelle la fonction X du BDOS avec le FCB par défaut
bdos_def
        lda #<DEF_FCB
        ldy #>DEF_FCB
        jmp bdos

; ---------------------------------------------------------------------
; Nombres décimaux
; ---------------------------------------------------------------------
dec_lo  .byt <10000,<1000,<100,<10
dec_hi  .byt >10000,>1000,>100,>10

; print_dec : affiche A (bas) / Y (haut) en décimal
print_dec
.(
        sta dec_val
        sty dec_val+1
        lda #0
        sta dec_flag
        ldx #0
dig     ldy #0
sub     lda dec_val
        sec
        sbc dec_lo,x
        pha
        lda dec_val+1
        sbc dec_hi,x
        bcc dd
        sta dec_val+1
        pla
        sta dec_val
        iny
        bne sub
dd      pla
        tya
        bne show
        lda dec_flag
        beq nxt
        tya
show    ora #"0"
        jsr conout
        sta dec_flag
nxt     inx
        cpx #4
        bne dig
        lda dec_val
        ora #"0"
        jmp conout
.)

; parse_dec : nombre décimal (0-255) à la position X -> dec_val, C=1 si absent
parse_dec
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
        lda dec_val
        asl
        asl
        clc
        adc dec_val
        asl
        clc
        adc ZP_T1
        sta dec_val
        inc hex_cnt
        inx
        bne loop
end     lda hex_cnt
        cmp #1
        bcc none
        clc
        rts
none    sec
        rts
.)

; ---------------------------------------------------------------------
; DIR [afn]
; ---------------------------------------------------------------------
; DIRS [afn] : comme DIR, fichiers système (SYS) compris
cmd_dirs
        lda #1
        bne dir_go
cmd_dir
        lda #0
dir_go
        sta dir_all
.(
        jsr cf_def
        ldx ccp_pos
        jsr parse_fcb
        jsr is_empty
        bcc named
        ldy #1                  ; pas de nom : *.*
        lda #"?"
fill    sta (ZP_CFCB),y
        iny
        cpy #12
        bne fill
named   lda #0
        sta ccp_cnt
        sta dec_flag            ; colonne
        jsr dma_default
        ldx #17
        jsr bdos_def
loop    cmp #$FF
        beq end
        lda dir_all             ; DIR cache les fichiers SYS
        bne show
        lda DEF_DMA+10
        bmi next
show    ldy #1
nm      lda DEF_DMA,y
        and #$7F
        jsr conout
        iny
        cpy #9
        bne nm
        lda #"."
        jsr conout
ext     lda DEF_DMA,y
        and #$7F
        jsr conout
        iny
        cpy #12
        bne ext
        inc ccp_cnt
        ldx dec_flag
        cpx #2
        beq wrap                ; 3e colonne : retour à la ligne automatique
        lda #" "
        jsr conout
        inx
        stx dec_flag
        jmp next
wrap    lda #0
        sta dec_flag
        jsr put_nl              ; PUT : fin de ligne dans le fichier
next    ldx #18
        jsr bdos
        jmp loop
end     lda dec_flag
        beq nocr
        jsr crlf
nocr    lda ccp_cnt
        bne free
        jsr no_file
free    jsr count_free          ; espace libre en Ko = blocs * 2
        asl
        tax
        lda #0
        rol
        tay
        txa
        jsr print_dec
        lda #<msg_free
        ldy #>msg_free
        jmp print_z
.)

; ---------------------------------------------------------------------
; TYPE fichier
; ---------------------------------------------------------------------
cmd_type
.(
        jsr cf_def
        ldx ccp_pos
        jsr parse_fcb
        jsr check_name
        bcs syn
        jsr dma_default
        ldx #15
        jsr bdos_def
        cmp #$FF
        beq nofile
rec     ldx #20
        jsr bdos_def
        cmp #0
        bne end
        ldy #0
ch      lda DEF_DMA,y
        cmp #$1A                ; ^Z : fin de texte
        beq end
        jsr conout
        iny
        bpl ch
        jsr const               ; une touche interrompt l'affichage
        beq rec
        jsr conin_raw
end     lda cur_x               ; retour à la ligne seulement si nécessaire
        cmp #FIRST_COL
        beq endok
        jmp crlf
endok   rts
nofile  jmp no_file
syn     jmp syntax_err
.)

; ---------------------------------------------------------------------
; ERA afn
; ---------------------------------------------------------------------
cmd_era
.(
        jsr cf_def
        ldx ccp_pos
        jsr parse_fcb
        jsr is_empty
        bcs syn
        jsr all_wild
        bcc go
        lda #<msg_all
        ldy #>msg_all
        jsr print_z
        jsr conin_raw
        jsr conout
        pha
        jsr crlf
        pla
        and #$DF
        cmp #"Y"
        bne quit
go      ldx #19
        jsr bdos_def
        cmp #$FE
        beq ro
        cmp #$FF
        bne quit
        jmp no_file
ro      jmp file_ro
quit    rts
syn     jmp syntax_err
.)

; ---------------------------------------------------------------------
; REN nouveau=ancien
; ---------------------------------------------------------------------
cmd_ren
.(
        lda #<CCP_FCB2
        sta ZP_CFCB
        lda #>CCP_FCB2
        sta ZP_CFCB+1
        lda #16
        sta pf_len
        ldx ccp_pos
        jsr parse_fcb
        jsr check_name
        bcs syn
        jsr skip_spaces
        lda CMDBUF+2,x
        cmp #"="
        bne syn
        inx
        jsr cf_def
        jsr parse_fcb
        jsr check_name
        bcs syn
        ; le nouveau nom ne doit pas exister
        jsr dma_default
        ldx #17
        lda #<CCP_FCB2
        ldy #>CCP_FCB2
        jsr bdos
        cmp #$FF
        bne exists
        ldx #15
cp      lda CCP_FCB2,x
        sta DEF_FCB+16,x
        dex
        bpl cp
        ldx #23
        jsr bdos_def
        cmp #$FE
        beq ro
        cmp #$FF
        bne done
        jmp no_file
ro      jmp file_ro
done    rts
exists  lda #<msg_exists
        ldy #>msg_exists
        jmp print_z
syn     jmp syntax_err
.)

; ---------------------------------------------------------------------
; SAVE n fichier : enregistre n pages de 256 octets à partir de $0500
; ---------------------------------------------------------------------
cmd_save
.(
        ldx ccp_pos
        jsr parse_dec
        bcs syn
        lda dec_val
        beq syn
        lda tpa_top+1           ; au plus jusqu'au haut de la TPA
        sec
        sbc #>TPA_START-1
        sta pf_end
        lda dec_val
        cmp pf_end
        bcs syn
        sta ccp_cnt
        jsr cf_def
        jsr parse_fcb
        jsr check_name
        bcs syn
        ldx #19                 ; remplace un fichier existant
        jsr bdos_def
        ldx #22
        jsr bdos_def
        cmp #$FF
        beq dirfull
        lda #<TPA_START
        sta dma
        lda #>TPA_START
        sta dma+1
page    lda #2
        sta dec_flag
half    ldx #21
        jsr bdos_def
        cmp #0
        bne dskfull
        lda dma
        eor #$80
        sta dma
        bne nxt
        inc dma+1
nxt     dec dec_flag
        bne half
        dec ccp_cnt
        bne page
        ldx #16
        jsr bdos_def
        jmp dma_default
dskfull ldx #16
        jsr bdos_def
        jsr dma_default
        lda #<msg_dfull
        ldy #>msg_dfull
        jmp print_z
dirfull lda #<msg_dirfull
        ldy #>msg_dirfull
        jmp print_z
syn     jmp syntax_err
.)

; GSAVE fichier / GLOAD fichier : image du mode SPLIT (type .IMG)
cmd_gsave
        jsr img_name
        bcs gs_syn
        jsr img_save
        jmp img_msg
cmd_gload
        jsr img_name
        bcs gs_syn
        jsr img_load
img_msg cmp #0
        beq gs_r
        cmp #1
        bne im2
        lda #<msg_nofile
        ldy #>msg_nofile
        jmp print_z
im2     cmp #2
        bne im3
        lda #<msg_dfull
        ldy #>msg_dfull
        jmp print_z
im3     lda #<msg_nosplit
        ldy #>msg_nosplit
        jmp print_z
gs_syn  jmp syntax_err
gs_r    rts

; img_name : nom de fichier -> DEF_FCB, A/Y = DEF_FCB, C=1 si incorrect
img_name
        jsr cf_def
        ldx ccp_pos
        jsr parse_fcb
        jsr check_name
        lda #<DEF_FCB
        ldy #>DEF_FCB
        rts

; ---------------------------------------------------------------------
; run_transient : charge NOM.COM en $0500 et l'exécute.
;   Ne revient (RTS) que si le fichier est introuvable.
;   Avant le lancement : FCB1 en $045C, FCB2 en $046C, ligne de
;   paramètres en $0480 (longueur puis caractères), DMA = $0480.
;   Le programme revient au système par RTS ou JMP $0200.
; ---------------------------------------------------------------------
run_transient
.(
        lda #<CCP_FCB
        sta ZP_CFCB
        lda #>CCP_FCB
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        ldx ccp_pos
        jsr parse_fcb
        stx ccp_tail
        jsr has_wild
        bcc nowild
        rts
nowild  ldy #9
        lda (ZP_CFCB),y
        cmp #" "
        bne hasext
        lda #"C"
        sta (ZP_CFCB),y
        iny
        lda #"O"
        sta (ZP_CFCB),y
        iny
        lda #"M"
        sta (ZP_CFCB),y
hasext  ldx #15
        lda #<CCP_FCB
        ldy #>CCP_FCB
        jsr bdos
        cmp #$FF
        bne found
        rts
found   lda #<TPA_START
        sta dma
        lda #>TPA_START
        sta dma+1
load    ldx #20
        lda #<CCP_FCB
        ldy #>CCP_FCB
        jsr bdos
        cmp #0
        bne loaded
        lda dma
        eor #$80
        sta dma
        bne load
        inc dma+1
        lda dma+1
        cmp tpa_top+1
        bcc load
        lda #<msg_big
        ldy #>msg_big
        jsr print_z
        jmp wboot
loaded  cmp #1
        bne fail

        ; FCB1, FCB2 et ligne de paramètres
        jsr cf_def
        ldx ccp_tail
        jsr parse_fcb
        lda #<DEF_FCB2
        sta ZP_CFCB
        lda #>DEF_FCB2
        sta ZP_CFCB+1
        lda #16
        sta pf_len
        jsr parse_fcb
        ldx ccp_tail
        ldy #0
tl      lda CMDBUF+2,x
        beq tend
        sta DEF_DMA+1,y
        inx
        iny
        cpy #126
        bne tl
tend    lda #0
        sta DEF_DMA+1,y
        sty DEF_DMA
        jsr dma_default
        jsr TPA_START
        jmp wboot
fail    jmp wboot
.)

no_file
        lda #<msg_nofile
        ldy #>msg_nofile
        jmp print_z

msg_free
        .asc "K free",13,10,0
msg_nofile
        .asc "No file",13,10,0
msg_all
        .asc "ALL (Y/N)? ",0
msg_exists
        .asc "File exists",13,10,0
file_ro lda #<msg_ro
        ldy #>msg_ro
        jmp print_z
msg_ro
        .asc "File R/O",13,10,0
msg_dfull
        .asc "Disk full",13,10,0
msg_dirfull
        .asc "Directory full",13,10,0
msg_big
        .asc "Program too big",13,10,0
