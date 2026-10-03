; =====================================================================
;  bios.s — démarrage, interruptions, clavier, console
; =====================================================================

; ---------------------------------------------------------------------
; Démarrage à froid
; ---------------------------------------------------------------------
cold_boot
        sei
        cld
        ldx #$FF
        txs
        lda #$7F
        sta VIA_IER             ; toutes les interruptions VIA coupées
#ifdef DISK
        lda #MD_BASE            ; garde la RAM overlay visible, EPROM et IRQ disque coupées
        sta MD_CTRL
        lda #0                  ; variables système du BDOS (RAM overlay)
        tax
cb_sys  sta ALV,x
        inx
        bne cb_sys
#endif
        ; --- Efface page zéro, page 2 et page de base ---
        lda #0
        tax
cb_clr  sta $00,x
        sta $0200,x
        sta $0400,x
        inx
        bne cb_clr
        sta HIST                ; historique des lignes vide (A = 0)

        jsr ram_test            ; teste la TPA et la remplit de $00 (BRK)
        jsr video_vars_text
        jsr hw_init
        jsr font_init

        ; --- État initial ---
        lda #$FF
        sta kb_last
        lda #7
        sta cur_ink
        lda #1
        sta page_on
        sta g_pen               ; crayon : trace
        lda #25
        sta kb_delay
        lda #3
        sta kb_rate
        lda #1
        sta caps
        lda #20
        sta blink_cnt

        jsr draw_status
        jsr cls_body
        lda #<msg_banner
        ldy #>msg_banner
        jsr print_z
        jsr ram_report
        ; continue en démarrage à chaud

; ---------------------------------------------------------------------
; Démarrage à chaud : remet le matériel et le système en ordre, puis CCP
;   (vecteurs de la page 2, VIA, son coupé, police, barre de menus)
; ---------------------------------------------------------------------
wboot
        sei
        ldx #$FF
        txs
        cld
        jsr hw_init
        jsr font_init
        lda #0
        sta m_act
        sta top_cap             ; plus de débogueur résident
        lda #>TPA_END           ; haut de la TPA selon le mode
        ldx vmode
        beq wb_t
        lda #>IMG_BASE
wb_t    sta tpa_top+1
        lda #0
        sta tpa_top
        lda #1
        sta cur_en
        jsr draw_status
        lda VIA_T1CL            ; acquitte un éventuel T1 en attente
        lda #$C0
        sta VIA_IER             ; autorise l'interruption T1
        cli
        lda #<DEF_DMA
        sta dma
        lda #>DEF_DMA
        sta dma+1
#ifdef DISK
        jsr put_end             ; un PUT en cours est refermé
        jsr fs_reset
#endif
        jmp ccp

; Stubs recopiés en $0200
ram_vectors
        jmp wboot
        jmp bdos
        jmp irq_handler
        jmp nmi_handler

; ---------------------------------------------------------------------
; hw_init : VIA (timer 50 Hz arrêté côté IRQ), AY silencieux, vecteurs RAM
; ---------------------------------------------------------------------
hw_init
        lda #$7F
        sta VIA_IER
#ifdef DISK
        lda #MD_BASE
        sta MD_CTRL
#endif
        lda #$FF
        sta VIA_DDRA            ; port A en sortie (bus AY)
        lda #$F7
        sta VIA_DDRB            ; PB3 en entrée (clavier), le reste en sortie
        lda #$00
        sta VIA_ORB
        lda #PCR_IDLE
        sta VIA_PCR
        lda #$40
        sta VIA_ACR             ; T1 en mode continu, sans sortie PB7
        lda #<T1_PERIOD
        sta VIA_T1LL
        sta VIA_T1CL
        lda #>T1_PERIOD
        sta VIA_T1LH
        sta VIA_T1CH            ; démarre le timer
        ldx #13                 ; AY : tout silencieux, port A en sortie
hw_ay   lda #0
        cpx #7
        bne hw_ay1
        lda #$7F                ; mixer : sons coupés, port A en sortie
hw_ay1  jsr ay_write
        dex
        bpl hw_ay
        lda #$7F                ; son : mélangeur coupé, aucune note
        sta s_mix
        lda #0
        sta s_dur
        sta s_dur+1
        sta s_dur+2
        ldx #11                 ; vecteurs en RAM
hw_vec  lda ram_vectors,x
        sta V_WBOOT,x
        dex
        bpl hw_vec
        rts

; font_init : recopie la police (96 caractères à partir du code 32)
font_init
.(
        lda #<font_data
        sta ZP_PTR
        lda #>font_data
        sta ZP_PTR+1
        lda #<(CHARSET+32*8)
        sta ZP_PTR2
        lda #>(CHARSET+32*8)
        sta ZP_PTR2+1
        ldx #3                  ; 3 pages = 768 octets
        ldy #0
loop    lda (ZP_PTR),y
        sta (ZP_PTR2),y
        iny
        bne loop
        inc ZP_PTR+1
        inc ZP_PTR2+1
        dex
        bne loop
        rts
.)

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

; ---------------------------------------------------------------------
; crash_screen : remet l'affichage en état après un plantage
;   (mode texte même depuis la haute résolution, police, écran effacé)
; ---------------------------------------------------------------------
crash_screen
.(
        lda #ATTR_TEXT50
        sta $BFDF               ; dernier octet lu par le circuit vidéo en HIRES
        sta SCREEN              ; (et annule la bascule du mode SPLIT)
        jsr video_vars_text
        jsr hw_init
        jsr font_init
        ldx #40                 ; ~40 ms : le circuit vidéo repasse en texte
w1      ldy #200
w2      dey
        bne w2
        dex
        bne w1
        lda #0
        sta m_act
        sta cur_vis
        lda kb_head             ; oublie les touches en attente
        sta kb_tail
        jsr draw_status
        jmp cls_body
.)

; ---------------------------------------------------------------------
; NMI : bouton RESET de l'Atmos -> adresse interrompue, démarrage à chaud
; ---------------------------------------------------------------------
nmi_handler
        sei
        tsx
        lda $0102,x             ; PC empilé par la NMI
        sta hex_val
        lda $0103,x
        sta hex_val+1
        ldx #$FF
        txs
        cld
        jsr crash_screen
        lda #<msg_reset
        ldy #>msg_reset
        jmp crash_msg

; ---------------------------------------------------------------------
; IRQ : timer 50 Hz -> clavier + clignotement du curseur
;       BRK -> adresse du BRK et démarrage à chaud
; ---------------------------------------------------------------------
irq_handler
        pha
        txa
        pha
        tya
        pha
        tsx
        lda $0104,x             ; P empilé par l'interruption
        and #$10
        bne irq_brk

        bit VIA_IFR
        bvc irq_end             ; pas le timer 1 : on ignore
        lda VIA_T1CL            ; acquitte T1

        inc ticks
        bne irq_t1
        inc ticks+1
irq_t1
        jsr kb_scan
        jsr snd_tick            ; fin des notes minutées

        dec blink_cnt
        bne irq_end
        lda #20
        sta blink_cnt
        lda cur_en
        beq irq_end
        jsr cur_toggle

irq_end
        pla
        tay
        pla
        tax
        pla
        rti

irq_brk                         ; X = pointeur de pile (A, X, Y empilés)
        lda $0105,x             ; adresse empilée = BRK + 2
        sec
        sbc #2
        sta hex_val
        lda $0106,x
        sbc #0
        sta hex_val+1
        ldx #$FF
        txs
        cld
        jsr crash_screen
        lda #<msg_brk
        ldy #>msg_brk
crash_msg
        jsr print_z
        lda hex_val+1
        ldy hex_val
        jsr print_hex16
        jsr crlf
        jmp wboot

; ---------------------------------------------------------------------
; ay_write : écrit A dans le registre X de l'AY-3-8912
; ---------------------------------------------------------------------
ay_write
        stx VIA_ORA_NH
        pha
        lda #PCR_LATCH
        sta VIA_PCR
        lda #PCR_IDLE
        sta VIA_PCR
        pla
        sta VIA_ORA_NH
        pha
        lda #PCR_WRITE
        sta VIA_PCR
        lda #PCR_IDLE
        sta VIA_PCR
        pla
        rts

; ---------------------------------------------------------------------
; Clavier
; ---------------------------------------------------------------------
; kb_col : place le masque de colonnes A dans le registre 14 de l'AY
;          (le registre 14 doit déjà être sélectionné)
kb_col
        sta VIA_ORA_NH
        lda #PCR_WRITE
        sta VIA_PCR
        lda #PCR_IDLE
        sta VIA_PCR
        rts

; kb_row : sélectionne la ligne X, renvoie Z=0 si une touche est enfoncée
;          dans les colonnes actives. Préserve X et Y.
kb_row
        lda VIA_ORB
        and #$F8
        sta ZP_IRQ
        txa
        ora ZP_IRQ
        sta VIA_ORB
        nop
        nop
        nop
        nop
        lda VIA_ORB
        and #$08
        rts

kb_colmask
        .byt $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F

; kb_scan : appelé à 50 Hz depuis l'IRQ
kb_scan
.(
        ; sélection du registre 14 (port A de l'AY)
        lda #14
        sta VIA_ORA_NH
        lda #PCR_LATCH
        sta VIA_PCR
        lda #PCR_IDLE
        sta VIA_PCR

        ; --- modificateurs : colonne 4 ---
        lda #0
        sta kb_newmods
        lda #$EF
        jsr kb_col
        ldx #4                  ; SHIFT gauche
        jsr kb_row
        beq m1
        lda #1
        sta kb_newmods
m1      ldx #7                  ; SHIFT droit
        jsr kb_row
        beq m2
        lda #1
        ora kb_newmods
        sta kb_newmods
m2      ldx #2                  ; CTRL
        jsr kb_row
        beq m3
        lda #2
        ora kb_newmods
        sta kb_newmods
m3      ldx #5                  ; FUNCT
        jsr kb_row
        beq m4
        lda #4
        ora kb_newmods
        sta kb_newmods
m4      lda kb_newmods      ; FUNCT vient d'être enfoncée -> code MENU_KEY
        and #4
        beq nofn
        lda kb_mods
        and #4
        bne nofn
        lda kb_newmods
        sta kb_mods
        lda #MENU_KEY
        sta ZP_IRQ
        jmp push
nofn    lda kb_newmods
        sta kb_mods

        ; --- touches ordinaires : toutes les colonnes sauf la 4 ---
        lda #$10
        jsr kb_col
        ldx #7
rows    jsr kb_row
        bne got_row
        dex
        bpl rows
nokey   lda #$FF
        sta kb_last
        rts

got_row stx kb_row_n
        ldy #7
cols    cpy #4
        beq nextc
        lda kb_colmask,y
        jsr kb_col
        ldx kb_row_n
        jsr kb_row
        bne got_col
nextc   dey
        bpl cols
        bmi nokey               ; rebond : rien de stable

got_col tya
        sta ZP_IRQ
        lda kb_row_n
        asl
        asl
        asl
        ora ZP_IRQ              ; index = ligne*8 + colonne
        cmp kb_last
        beq held
        sta kb_last
        lda kb_delay            ; délai avant répétition (0,5 s par défaut)
        sta kb_rep
        jmp emit
held    dec kb_rep
        bne done
        lda kb_rate             ; puis ~16 caractères/s par défaut
        sta kb_rep

emit    ldx kb_last
        lda kb_mods
        and #1
        beq unsh
        lda keymap_shift,x
        jmp gotc
unsh    lda keymap_norm,x
gotc    beq done
        sta ZP_IRQ

        ; verrouillage majuscules : inverse la casse des lettres
        lda caps
        beq nocaps
        lda ZP_IRQ
        and #$DF
        cmp #"A"
        bcc nocaps
        cmp #"Z"+1
        bcs nocaps
        lda ZP_IRQ
        eor #$20
        sta ZP_IRQ
nocaps
        ; CTRL : code de contrôle
        lda kb_mods
        and #2
        beq push
        lda ZP_IRQ
        and #$1F
        sta ZP_IRQ
        cmp #$14                ; CTRL-T : bascule majuscules (comme l'Atmos)
        bne push
        lda caps
        eor #1
        sta caps
        jmp draw_caps

push    ldx kb_head
        lda ZP_IRQ
        sta kb_buf,x
        inx
        txa
        and #KB_MASK
        cmp kb_tail
        beq done                ; tampon plein : on perd la touche
        sta kb_head
done    rts
.)

; ---------------------------------------------------------------------
; const : A=$FF si un caractère attend, sinon A=0 (flags positionnés)
; ---------------------------------------------------------------------
const
        lda kb_tail
        cmp kb_head
        beq const0
        lda #$FF
        rts
const0  lda #0
        rts

; conin_raw : attend un caractère et le renvoie dans A (sans écho)
conin_raw
        jsr conin_key
        cmp #MENU_KEY
        bne cr_r
        jsr menu_run
        jmp conin_raw
cr_r    rts

; conin_key : touche brute, sans gestion des menus
conin_key
        lda kb_tail
        cmp kb_head
        beq conin_key
        stx ZP_T1
        ldx kb_tail
        lda kb_buf,x
        pha
        lda #0                  ; une touche lue : la pagination repart
        sta page_cnt
        inx
        txa
        and #KB_MASK
        sta kb_tail
        ldx ZP_T1
        pla
        rts

bios_list
        rts                     ; pas d'imprimante pour l'instant
bios_reader
        lda #$1A                ; ^Z = fin de fichier
        rts
bios_setdma
        sta dma
        sty dma+1
        rts
bios_disk_stub
        lda #1                  ; erreur : pas encore de pilote disque
        rts

; ---------------------------------------------------------------------
; Console
; ---------------------------------------------------------------------
; conout : affiche le caractère A. Préserve A, X, Y.
;   $0D retour chariot, $0A saut de ligne, $08 recul, $09 tabulation,
;   $0C efface l'écran, $20-$7E caractères imprimables.
conout
        php
        sei
        pha
        txa
        pha
        tya
        pha
        lda cur_vis
        beq co_hidden
        jsr cur_toggle
co_hidden
        tsx
        lda $0103,x
#ifdef DISK
        ldy put_on              ; PUT : copie dans le tampon
        beq co_np
        jsr put_char
co_np
#endif
        jsr con_char
        jsr show_cursor
        pla
        tay
        pla
        tax
        pla
        plp
        rts

; show_cursor : (avec interruptions masquées) affiche le curseur s'il est actif
show_cursor
        lda cur_en
        beq sc_no
        lda cur_vis
        bne sc_no
        jsr cur_toggle
        lda #20
        sta blink_cnt
sc_no   rts

; cur_toggle : inverse la cellule sous le curseur
cur_toggle
        ldx cur_y
        lda line_lo,x
        sta ZP_IRQP
        lda line_hi,x
        sta ZP_IRQP+1
        ldy cur_x
        lda (ZP_IRQP),y
        eor #$80
        sta (ZP_IRQP),y
        lda cur_vis
        eor #1
        sta cur_vis
        rts

con_char
.(
        cmp #$0D
        bne n1
        lda #FIRST_COL
        sta cur_x
        rts
n1      cmp #$0A
        bne n2
        jmp line_down
n2      cmp #$08
        bne n3
        lda cur_x
        cmp #FIRST_COL+1
        bcc r
        dec cur_x
r       rts
n3      cmp #$0C
        bne n4
        jmp cls_body
n4      cmp #$09
        bne n5
tab     lda #" "
        jsr put_printable
        lda cur_x
        sec
        sbc #FIRST_COL
        and #7
        bne tab
        rts
n5      cmp #$20
        bcc r
        cmp #$7F
        bcs r
        ; continue sur put_printable
.)

put_printable
        pha
        ldx cur_y
        lda line_lo,x
        sta ZP_SCR
        lda line_hi,x
        sta ZP_SCR+1
        pla
        ldy cur_x
        sta (ZP_SCR),y
        inc cur_x
        lda cur_x
        cmp #COLS
        bcc pp_ok
        lda #FIRST_COL
        sta cur_x
        jmp line_down
pp_ok   rts

line_down
        inc cur_y
        lda cur_y
        cmp #LAST_ROW+1
        bcc ld_pg
        lda #LAST_ROW
        sta cur_y
        jsr scroll
ld_pg   lda page_on             ; écran plein depuis la dernière touche ?
        beq ld_ok
#ifdef DISK
        lda put_on              ; pas de pause pendant un PUT
        bne ld_ok
#endif
        inc page_cnt
        lda #LAST_ROW
        sec
        sbc con_first
        cmp page_cnt
        bne ld_ok
        jmp page_pause
ld_ok   rts

; page_pause : « -- Suite --» en bas de l'écran, attend une touche
;   (appelée depuis conout : interruptions masquées, curseur caché)
page_pause
.(
        ldx #LAST_ROW
        lda line_lo,x
        sta ZP_SCR
        lda line_hi,x
        sta ZP_SCR+1
        ldx #0
        ldy #FIRST_COL
pmsg    lda msg_more,x
        beq pwait
        ora #$80
        sta (ZP_SCR),y
        inx
        iny
        bne pmsg
pwait   cli                     ; le clavier fonctionne par interruption
        jsr conin_key
        sei
        pha
        ldx #LAST_ROW
        jsr clear_row
        pla
        cmp #3                  ; CTRL-C : abandon, retour au système
        bne pgo
        jmp V_WBOOT
pgo
        lda #0
        sta page_cnt
        rts
.)

; scroll : remonte les lignes 2..27 d'un cran, efface la ligne 27
scroll
.(
        inc scr_n               ; pour l'édition de ligne (rline.s)
        ldx con_first
loop    lda line_lo,x
        sta ZP_SCR
        lda line_hi,x
        sta ZP_SCR+1
        lda line_lo+1,x
        sta ZP_SCR2
        lda line_hi+1,x
        sta ZP_SCR2+1
        ldy #COLS-1
cp      lda (ZP_SCR2),y
        sta (ZP_SCR),y
        dey
        cpy #FIRST_COL
        bcs cp
        inx
        cpx #LAST_ROW
        bne loop
        ldx #LAST_ROW
        jmp clear_row
.)

; clear_row : efface la ligne X (attributs + espaces)
clear_row
.(
        lda line_lo,x
        sta ZP_SCR
        lda line_hi,x
        sta ZP_SCR+1
        ldy #0
        lda cur_paper
        ora #$10
        sta (ZP_SCR),y
        iny
        lda cur_ink
        sta (ZP_SCR),y
        lda #" "
        ldy #COLS-1
loop    sta (ZP_SCR),y
        dey
        cpy #FIRST_COL
        bcs loop
        rts
.)

; cls_body : efface la zone console et place le curseur en haut
cls_body
.(
        ldx con_first
loop    jsr clear_row
        inx
        cpx #LAST_ROW+1
        bne loop
        lda #FIRST_COL
        sta cur_x
        lda con_first
        sta cur_y
        lda #0
        sta cur_vis
        sta page_cnt
        rts
.)

; draw_status : ligne d'état (ligne 0) = barre de menus du système
draw_status
        lda #<sys_bar
        ldy #>sys_bar
        jmp menu_install

draw_caps                       ; (appelée aussi depuis l'IRQ : CTRL-T)
.(
        ldy #38
        ldx #3
        lda caps
        beq off
on      lda caps_text,x
        sta (ZP_BAR),y
        dey
        dex
        bpl on
        rts
off     lda #" "
o1      sta (ZP_BAR),y
        dey
        dex
        bpl o1
        rts
.)

caps_text
        .asc "CAPS"

; ---------------------------------------------------------------------
; Utilitaires d'affichage (A/Y = adresse d'une chaîne terminée par 0)
; ---------------------------------------------------------------------
print_z
.(
        sta ZP_PTR2
        sty ZP_PTR2+1
        ldy #0
loop    lda (ZP_PTR2),y
        beq end
        jsr conout
        iny
        bne loop
        inc ZP_PTR2+1
        bne loop
end     rts
.)

crlf
        lda #$0D
        jsr conout
        lda #$0A
        jmp conout

print_hex16                     ; A = octet haut, Y = octet bas
        jsr print_hex8
        tya
print_hex8
        pha
        lsr
        lsr
        lsr
        lsr
        jsr print_nib
        pla
        pha
        and #$0F
        jsr print_nib
        pla
        rts
print_nib
        cmp #10
        bcc pn_dig
        adc #6
pn_dig  adc #"0"
        jmp conout

msg_banner
        .asc "CP/A 0.9 - Control Program for Atmos",13,10
        .asc "TPA $0500-$B3FF, BDOS: JSR $0203",13,10
        .asc "Type HELP for commands.",13,10,0
msg_more
        .asc " -- Suite : une touche (^C stop) -- ",0
msg_reset
        .asc "*RESET* at ",0
msg_brk
        .asc "*BRK* at ",0
msg_ramok
        .asc "RAM test OK.",13,10,0
msg_rambad
        .asc "RAM error at ",0
