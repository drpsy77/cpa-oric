; =====================================================================
;  bdos.s — appels système (numérotation de CP/M 2.2)
;  Entrée : X = fonction, A/Y = paramètre (bas/haut). Sortie : A (et Y)
; =====================================================================

BDOS_NFUNC = 37

bdos
        cld
#ifdef DISK
        bit put_pend            ; sortie de PUT à écrire (entre deux appels)
        bpl bd_np
        jsr put_flush
bd_np
#endif
        sta bdos_a
        sty bdos_y
        sta ZP_PTR
        sty ZP_PTR+1
        cpx #GFX_FUNC
        bne bd_snd
        jmp gfx_call
bd_snd  cpx #SND_FUNC
        bne bd_ch
        jmp snd_call
bd_ch   cpx #CHAIN_FUNC
        beq f_chain
bd_std  cpx #BDOS_NFUNC
        bcs bdos_bad
        txa
        asl
        tax
        lda bdos_tab+1,x
        pha
        lda bdos_tab,x
        pha
        lda bdos_a
        rts                     ; saute à la fonction, qui revient à l'appelant

bdos_bad
        lda #$FF
        rts

; ---------------------------------------------------------------------
; 47 CHAIN : termine le programme et fait exécuter une ligne de commande
;   par le CCP, comme si on l'avait tapée (la fonction 47 de CP/M 3 ; ici
;   la ligne est donnée par A/Y, terminée par 0, 78 caractères au plus).
;   Ne revient pas : démarrage à chaud, puis le CCP affiche et exécute
;   la ligne avant tout script DO en cours.
; ---------------------------------------------------------------------
CHAIN_FUNC = 47
f_chain
.(
        ldy #0                  ; copie dans CMDBUF (une ligne en $0480
cp      lda (ZP_PTR),y          ; peut s'y recopier : la destination est
        beq end                 ; plus bas)
        sta CMDBUF+2,y
        iny
        cpy #CMDMAX
        bne cp
end     sty CMDBUF+1
        lda #1
        sta chain_on
        jmp wboot
.)

bdos_tab
        .word f_wboot-1         ; 0  réinitialisation système
        .word f_conin-1         ; 1  lecture console avec écho
        .word f_conout-1        ; 2  écriture console
        .word f_reader-1        ; 3  lecteur auxiliaire
        .word f_none-1          ; 4  perforateur auxiliaire
        .word bios_list-1       ; 5  imprimante (A = caractère)
        .word f_dirio-1         ; 6  E/S console directe
        .word f_none-1          ; 7  (octet IOBYTE)
        .word f_none-1          ; 8
        .word f_print-1         ; 9  affiche une chaîne terminée par '$'
        .word f_readbuf-1       ; 10 lecture d'une ligne éditable
        .word f_const-1         ; 11 état console
        .word f_version-1       ; 12 version
#ifdef DISK
        .word fs_reset-1        ; 13 réinitialisation disques
        .word f_seldsk-1        ; 14 sélection disque
        .word f_open-1          ; 15 ouverture fichier
        .word f_close-1         ; 16 fermeture fichier
        .word f_sfirst-1        ; 17 recherche premier
        .word f_snext-1         ; 18 recherche suivant
        .word f_delete-1        ; 19 suppression
        .word f_read-1          ; 20 lecture séquentielle
        .word f_write-1         ; 21 écriture séquentielle
        .word f_make-1          ; 22 création
        .word f_rename-1        ; 23 renommage
        .word f_login-1         ; 24 lecteurs lus (bit 0 = A:)
        .word f_curdsk-1        ; 25 lecteur courant
#else
        .word f_disk-1          ; 13 réinitialisation disques
        .word f_disk-1          ; 14 sélection disque
        .word f_disk-1          ; 15 ouverture fichier
        .word f_disk-1          ; 16 fermeture fichier
        .word f_disk-1          ; 17 recherche premier
        .word f_disk-1          ; 18 recherche suivant
        .word f_disk-1          ; 19 suppression
        .word f_disk-1          ; 20 lecture séquentielle
        .word f_disk-1          ; 21 écriture séquentielle
        .word f_disk-1          ; 22 création
        .word f_disk-1          ; 23 renommage
        .word f_none-1          ; 24 disques connectés
        .word f_none-1          ; 25 disque courant
#endif
        .word f_setdma-1        ; 26 adresse DMA
        .word f_none-1          ; 27 (vecteur d'allocation)
        .word f_none-1          ; 28 (protection du disque)
        .word f_none-1          ; 29 (vecteur R/O)
#ifdef DISK
        .word f_attrib-1        ; 30 attributs de fichier
        .word f_none-1          ; 31 (paramètres du disque)
        .word f_none-1          ; 32 (numéro d'utilisateur)
        .word f_rread-1         ; 33 lecture directe
        .word f_rwrite-1        ; 34 écriture directe
        .word f_fsize-1         ; 35 taille du fichier
        .word f_setrnd-1        ; 36 position directe <- séquentielle
#else
        .word f_none-1          ; 30
        .word f_none-1          ; 31
        .word f_none-1          ; 32
        .word f_none-1          ; 33
        .word f_none-1          ; 34
        .word f_none-1          ; 35
        .word f_none-1          ; 36
#endif

f_wboot
        jmp wboot

f_conin
        jsr conin_raw
        jmp conout              ; écho ; conout préserve A

f_conout
        jmp conout

f_reader
        jmp bios_reader

f_none
        lda #0
        rts

f_disk
        lda #$FF                ; pas encore de disque : erreur
        rts

f_dirio
        cmp #$FF
        bne dio_1
        jsr const
        beq dio_r
        jmp conin_raw
dio_1   cmp #$FE
        bne dio_2
        jmp const
dio_2   jmp conout
dio_r   rts

f_print
.(
        ldy #0
loop    lda (ZP_PTR),y
        cmp #"$"
        beq end
        jsr conout
        iny
        bne loop
        inc ZP_PTR+1
        bne loop
end     rts
.)

f_const
        jmp const

f_version
        lda #$22                ; niveau de compatibilité CP/M 2.2
        ldy #$00
        rts

f_setdma
        lda bdos_a
        sta dma
        lda bdos_y
        sta dma+1
        rts

; f_readbuf / read_line (fonction 10) : voir rline.s
