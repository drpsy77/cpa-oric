; sys.msg : textes du système en anglais (le français est dans
;   src/msg/fr/sys.msg, mêmes étiquettes). Inclus par src/menu.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; un raccourci
; clavier est écrit au bout du libellé, aligné à droite.

mn_sys
#ifdef DISK
        .byt 6,11
#else
        .byt 5,11
#endif
        .asc "System",0
        .asc "Version",0
        .byt MA_TYPE
        .word ty_ver
        .asc "Help",0
        .byt MA_TYPE
        .word ty_help
        .asc "Memory",0
        .byt MA_TYPE
        .word ty_mem
        .asc "Printer  ^P",0
        .byt MA_CALL
        .word k_prt
#ifdef DISK
        .asc "Next drive",0
        .byt MA_CALL
        .word m_drive
#endif
        .asc "Reboot   ^C",0
        .byt MA_CALL
        .word m_reboot

#ifdef DISK
mn_fic  .byt 5,9
        .asc "Files",0
        .asc "Directory",0
        .byt MA_TYPE
        .word ty_dir
        .asc "Show...",0
        .byt MA_TYPE
        .word ty_type
        .asc "Copy...",0
        .byt MA_TYPE
        .word ty_copy
        .asc "Rename...",0
        .byt MA_TYPE
        .word ty_ren
        .asc "Erase...",0
        .byt MA_TYPE
        .word ty_era
#endif

mn_ecr  .byt 7,12
        .asc "Screen",0
        .asc "SPLIT mode",0
        .byt MA_TYPE
        .word ty_split
        .asc "Text mode",0
        .byt MA_TYPE
        .word ty_text
        .asc "Clear",0
        .byt MA_TYPE
        .word ty_cls
        .asc "Ink",0
        .byt MA_CALL
        .word m_ink
        .asc "Paper",0
        .byt MA_CALL
        .word m_paper
        .asc "Caps lock ^T",0
        .byt MA_CALL
        .word m_caps
        .asc "Paging",0
        .byt MA_CALL
        .word m_page

mn_clv  .byt 3,6
        .asc "Keyboard",0
        .asc "Fast",0
        .byt MA_CALL
        .word m_kfast
        .asc "Normal",0
        .byt MA_CALL
        .word m_knorm
        .asc "Slow",0
        .byt MA_CALL
        .word m_kslow

; console : pause en fin d'écran (bios.s, affiché en vidéo inverse), PAUSE
; (ccp_gfx.s), script arrêté par CTRL-C (script.s)
msg_more .asc " -- More (^C stop) -- ",0
msg_key  .asc "Press a key to go on...",13,10,0
#ifdef DISK
msg_scrstop .asc "Script stopped.",13,10,0
#endif
