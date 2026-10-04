; =====================================================================
;  CP/A — Control Program for Atmos
;  Mini système "à la CP/M" en ROM 16 Ko pour Oric Atmos
;  Assembleur : xa (OSDK)      Construire : ./build.sh
; =====================================================================
;
;  Carte mémoire
;  -------------
;  $0000-$00EF  page zéro libre pour les programmes
;  $00F0-$00FF  page zéro réservée au système
;  $0100-$01FF  pile
;  $0200-$020B  vecteurs en RAM (détournables) :
;                 $0200 JMP WBOOT   (équivalent de l'adresse 0 de CP/M)
;                 $0203 JMP BDOS    (équivalent de CALL 5)
;                 $0206 JMP IRQ
;                 $0209 JMP NMI
;  $0210-$02FF  variables système
;  $0300-$03FF  entrées/sorties (VIA 6522, contrôleur disque…)
;  $0400-$04FF  "page de base" : tampon de commande, FCB, DMA par défaut
;  $0500-$B3FF  TPA, zone des programmes utilisateur (44 800 octets)
;  $B400-$BB7F  jeux de caractères
;  $BB80-$BFDF  écran texte 40x28
;  $C000-$FFFF  cette ROM
;
;  Appel BDOS (depuis un programme) :
;      X = numéro de fonction (comme le registre C de CP/M)
;      A/Y = paramètre octet bas/haut (comme DE de CP/M)
;      JSR $0203   -> résultat dans A (et Y pour les valeurs 16 bits)
; =====================================================================

#include "hw.inc"

        *= $C000

; ---------------------------------------------------------------------
; Table de saut BIOS (adresses fixes, comme le BIOS de CP/M)
; ---------------------------------------------------------------------
bios_table
        jmp cold_boot           ; $C000 BOOT
        jmp wboot               ; $C003 WBOOT
        jmp const               ; $C006 CONST
        jmp conin_raw           ; $C009 CONIN
        jmp conout              ; $C00C CONOUT
        jmp bios_list           ; $C00F LIST
        jmp bios_list           ; $C012 PUNCH
        jmp bios_reader         ; $C015 READER
#ifdef DISK
        jmp disk_home           ; $C018 HOME
        jmp f_seldsk            ; $C01B SELDSK  (A = lecteur, seul 0)
        jmp bios_settrk         ; $C01E SETTRK  (sans effet : adressage par LSN)
        jmp bios_setsec         ; $C021 SETSEC  A/Y = n° de secteur logique
        jmp bios_dskbuf         ; $C024 SETDMA  A/Y = tampon de 256 octets
        jmp bios_read           ; $C027 READ    -> A=0 OK, 1 erreur
        jmp bios_write          ; $C02A WRITE
        jmp menu_install        ; $C02D MENUBAR A/Y = barre de menus
#else
        jmp bios_disk_stub      ; $C018 HOME
        jmp bios_disk_stub      ; $C01B SELDSK
        jmp bios_disk_stub      ; $C01E SETTRK
        jmp bios_disk_stub      ; $C021 SETSEC
        jmp bios_setdma         ; $C024 SETDMA
        jmp bios_disk_stub      ; $C027 READ
        jmp bios_disk_stub      ; $C02A WRITE
        jmp menu_install        ; $C02D MENUBAR A/Y = barre de menus
#endif

#include "bios.s"
#include "bdos.s"
#include "ccp.s"
#include "menu.s"
#include "gfx.s"
#include "ccp_gfx.s"
#include "snd.s"
#ifdef DISK
#include "disk.s"
#include "fs.s"
#include "ccp_disk.s"
#include "put.s"
#include "script.s"
#endif
#include "tables.s"
#include "font.s"

rom_end

; ---------------------------------------------------------------------
; Remplissage et vecteurs matériels du 6502
; ---------------------------------------------------------------------
        .dsb $FFFA-*,$FF
        .word V_NMI             ; NMI  (bouton RESET de l'Atmos)
        .word cold_boot         ; RESET (mise sous tension)
        .word V_IRQ             ; IRQ/BRK
