; =====================================================================
;  img.s — banque IMG de la fenêtre : images du mode SPLIT sur disque
;          (BDOS 115 op 12 GSAVE et 13 GLOAD) et commandes SAVE, GSAVE,
;          GLOAD du CCP
;
;  Assemblée avec le système (cpa.s, après les vecteurs, *= WIN), mais
;  pas chargée avec lui : build.sh la découpe et la range dans CPA.BNK
;  (tools/mkbnk.py). Le code résident n'y entre que par win_call
;  (bank.s), qui la charge dans la fenêtre si elle n'y est pas.
;  Elle s'arrête avant $FA00 (tampon de PUT, jamais touché par un prêt).
; =====================================================================

g_gsave
        lda g_p+1
        ldy g_p+2
        jmp img_save
g_gload
        lda g_p+1
        ldy g_p+2
        jmp img_load

; ---------------------------------------------------------------------
; Images du mode SPLIT sur disque : 40 enregistrements, $A000-$B3FF
; ---------------------------------------------------------------------
; img_prep : FCB A/Y, type IMG par défaut, octets 12-35 à zéro, DMA sauvé
img_prep
.(
        sta img_fcb
        sty img_fcb+1
        sta ZP_PTR2
        sty ZP_PTR2+1
        ldy #9
        lda (ZP_PTR2),y
        cmp #" "
        bne ext
        lda #"I"
        sta (ZP_PTR2),y
        iny
        lda #"M"
        sta (ZP_PTR2),y
        iny
        lda #"G"
        sta (ZP_PTR2),y
ext     ldy #12
        lda #0
z       sta (ZP_PTR2),y
        iny
        cpy #36
        bne z
        lda dma
        sta img_dma
        lda dma+1
        sta img_dma+1
        lda #<IMG_BASE
        sta dma
        lda #>IMG_BASE
        sta dma+1
        lda #40
        sta img_cnt
        rts
.)

img_bdos                        ; fonction X sur le FCB de l'image
        lda img_fcb
        ldy img_fcb+1
        jmp bdos

img_next                        ; enregistrement suivant ; Z=1 si fini
        clc
        lda dma
        adc #128
        sta dma
        bcc in1
        inc dma+1
in1     dec img_cnt
        rts

img_end                         ; rend le DMA de l'appelant, A = code
        pha
        lda img_dma
        sta dma
        lda img_dma+1
        sta dma+1
        pla
        rts

; img_save : A/Y = FCB. A = 0 OK, 2 disque ou répertoire plein, 3 fichier
;   protégé (R/O), $FF pas en mode SPLIT. Écriture sûre, comme EDIT : l'image
;   va dans NOM.$$$ (FCB BNK_FCB), puis NOM.IMG est effacé et NOM.$$$ renommé.
;   Disque plein : NOM.$$$ effacé, NOM.IMG intact.
img_save
.(
        ldx vmode
        bne ok
        lda #$FF
        rts
ok      sta img_f               ; FCB du fichier : img_f (et img_fcb,
        sty img_f+1             ; ZP_PTR2 jusqu'au premier appel du BDOS)
        jsr img_prep
        ldx #15                 ; protégé ? (bit 7 de S1 après ouverture)
        jsr img_bdos
        cmp #$FF
        beq new
        jsr img_pf
        ldy #13
        lda (ZP_PTR2),y
        bpl new
        lda #3
        jmp img_end
new     jsr img_pf              ; NOM.$$$ : nom recopié, type $$$
        ldy #35
ct      lda #0
        cpy #12
        bcs ct1
        lda (ZP_PTR2),y
        cpy #9
        bcc ct1
        lda #"$"
ct1     sta BNK_FCB,y
        dey
        bpl ct
        lda #<BNK_FCB           ; la suite écrit NOM.$$$
        sta img_fcb
        lda #>BNK_FCB
        sta img_fcb+1
        ldx #19                 ; un ancien NOM.$$$ est effacé
        jsr img_bdos
        ldx #22
        jsr img_bdos
        cmp #$FF
        beq full
loop    ldx #21
        jsr img_bdos
        cmp #0
        bne wfail
        jsr img_next
        bne loop
        ldx #16
        jsr img_bdos
        cmp #$FF
        beq wf2
        jsr img_pf              ; nouveau nom (FCB+16) : NOM.IMG
        ldy #11
cn      lda (ZP_PTR2),y
        sta BNK_FCB+16,y
        dey
        bpl cn
        ldx #19                 ; ancien NOM.IMG effacé
        lda img_f
        ldy img_f+1
        jsr bdos
        ldx #23                 ; NOM.$$$ -> NOM.IMG
        jsr img_bdos
        lda #0
        jmp img_end
wfail   ldx #16                 ; fermé (ses blocs entrent au répertoire),
        jsr img_bdos            ; puis effacé (ils sont rendus)
wf2     ldx #19
        jsr img_bdos
full    lda #2
        jmp img_end
.)

; img_pf : ZP_PTR2 = FCB du fichier (img_f)
img_pf
        lda img_f
        sta ZP_PTR2
        lda img_f+1
        sta ZP_PTR2+1
        rts

; img_load : A/Y = FCB. A = 0 OK (mode SPLIT), 1 fichier absent
img_load
.(
        jsr img_prep
        ldx #15
        jsr img_bdos
        cmp #$FF
        bne loop
        lda #1
        jmp img_end
loop    ldx #20
        jsr img_bdos
        cmp #0
        bne done
        jsr img_next
        bne loop
done    lda vmode               ; déjà en SPLIT : on garde la console
        beq sw
        lda #ATTR_TEXT50
        sta IMG_SWITCH
        bne fin
sw      jsr video_split
fin     lda #0
        jmp img_end
.)

; ---------------------------------------------------------------------
; SAVE n fichier : enregistre n pages de 256 octets à partir de $0500
; ---------------------------------------------------------------------
i_save
.(
        ldx ccp_pos
        jsr get_byte            ; A = dec_val
        bcs syn
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
        jsr pf_chk
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
i_gsave
        jsr img_name
        bcs gs_syn
        jsr img_save
        jmp img_msg
i_gload
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
im3     cmp #3
        bne im4
        lda #<msg_iro
        ldy #>msg_iro
        jmp print_z
im4     lda #<msg_nosplit
        ldy #>msg_nosplit
        jmp print_z
gs_syn  jmp syntax_err
gs_r    rts

; img_name : nom de fichier -> DEF_FCB, A/Y = DEF_FCB, C=1 si incorrect
img_name
        jsr def_chk
        lda #<DEF_FCB
        ldy #>DEF_FCB
        rts


msg_iro
        .asc "File R/O",13,10,0
