; sys.msg : textes du système en français (barre de menus FUNCT du prompt,
;   messages de la console) ; la traduction anglaise est dans
;   src/msg/en/sys.msg, mêmes étiquettes. Inclus par src/menu.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; un raccourci
; clavier est écrit au bout du libellé, aligné à droite.
; Messages du CCP : en anglais court dans les deux langues (ccp.s...).

#ifdef DISK
mn_sys  .byt 6,15
#else
mn_sys  .byt 5,13
#endif
        .asc "Systeme",0
        .asc "Version",0
        .byt MA_TYPE
        .word ty_ver
        .asc "Aide",0
        .byt MA_TYPE
        .word ty_help
        .asc "Memoire",0
        .byt MA_TYPE
        .word ty_mem
#ifdef DISK
        .asc "Imprimante   ^P",0
#else
        .asc "Imprimante ^P",0
#endif
        .byt MA_CALL
        .word k_prt
#ifdef DISK
        .asc "Lecteur suivant",0
        .byt MA_CALL
        .word m_drive
        .asc "Redemarrer   ^C",0
#else
        .asc "Redemarrer ^C",0
#endif
        .byt MA_CALL
        .word m_reboot

#ifdef DISK
mn_fic  .byt 5,11
        .asc "Fichiers",0
        .asc "Catalogue",0
        .byt MA_TYPE
        .word ty_dir
        .asc "Afficher...",0
        .byt MA_TYPE
        .word ty_type
        .asc "Copier...",0
        .byt MA_TYPE
        .word ty_copy
        .asc "Renommer...",0
        .byt MA_TYPE
        .word ty_ren
        .asc "Effacer...",0
        .byt MA_TYPE
        .word ty_era
#endif

mn_ecr  .byt 7,13
        .asc "Ecran",0
        .asc "Mode SPLIT",0
        .byt MA_TYPE
        .word ty_split
        .asc "Mode texte",0
        .byt MA_TYPE
        .word ty_text
        .asc "Effacer",0
        .byt MA_TYPE
        .word ty_cls
        .asc "Encre",0
        .byt MA_CALL
        .word m_ink
        .asc "Papier",0
        .byt MA_CALL
        .word m_paper
        .asc "Majuscules ^T",0
        .byt MA_CALL
        .word m_caps
        .asc "Pagination",0
        .byt MA_CALL
        .word m_page

mn_clv  .byt 3,6
        .asc "Clavier",0
        .asc "Rapide",0
        .byt MA_CALL
        .word m_kfast
        .asc "Normal",0
        .byt MA_CALL
        .word m_knorm
        .asc "Lent",0
        .byt MA_CALL
        .word m_kslow

; console : pause en fin d'écran (bios.s, affiché en vidéo inverse), PAUSE
; (ccp_gfx.s), script arrêté par CTRL-C (script.s)
msg_more .asc " -- Suite (^C stop) -- ",0
msg_key  .asc "Une touche pour continuer...",13,10,0
#ifdef DISK
msg_scrstop .asc "Script arrete.",13,10,0
#endif
