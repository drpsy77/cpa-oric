; hex.msg : menus et messages de HEX.COM (français) ; la traduction anglaise
; est dans progs/msg/en/hex.msg, mêmes étiquettes. Inclus par progs/hex.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; m_modes :
; trois mots de 4 caractères (mode de la ligne d'état).
mn_fic  .byt 3,14
        .asc "Fichier",0
        .asc "Enregistrer ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Recharger   ^R",0
        .byt MA_TYPE
        .word c_reload
        .asc "Quitter     ^Q",0
        .byt MA_TYPE
        .word c_quit

mn_all  .byt 5,13
        .asc "Aller",0
        .asc "Debut  C-haut",0
        .byt MA_TYPE
        .word c_top
        .asc "Fin     C-bas",0
        .byt MA_TYPE
        .word c_bot
        .asc "Adresse... ^L",0
        .byt MA_TYPE
        .word c_goto
        .asc "Chercher.. ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Suivant    ^G",0
        .byt MA_TYPE
        .word c_next

mn_mod  .byt 1,13
        .asc "Mode",0
        .asc "Hex/ASCII  ^I",0
        .byt MA_TYPE
        .word c_mode

m_usage   .asc "Usage : HEX fichier",13,10,"$"
m_nofile  .asc "Fichier introuvable",13,10,"$"
m_empty   .asc "Fichier vide",13,10,"$"
m_nof2    .asc "Fichier introuvable",0
m_trunc   .asc "Plus de 64 Ko : debut seulement",0
m_written .asc "Modifications ecrites",0
m_ro      .asc "Lecture seule (fichier tronque)",0
m_saved   .asc "Enregistre",0
m_prot    .asc "Fichier protege (R/O)",0
m_reload  .asc "Fichier relu",0
m_dirfull .asc "Repertoire plein",0
m_dfull   .asc "Disque plein : non enregistre",0
m_badhex  .asc "Adresse incorrecte",0
m_badpat  .asc "Motif incorrect",0
m_notf    .asc "Introuvable",0
m_wrap    .asc "Trouve en repartant du debut",0
q_goto    .asc "Adresse (hexa) : ",0
q_find    .asc "Chercher (texte ou #hexa) : ",0
q_lose    .asc "Abandonner les modifs (O/N) ?",0
q_quit    .asc "Fichier modifie. Quitter (O/N) ?",0
m_modes   .asc "HEX ASC LECT"
K_YES   = "O"           ; touche Oui
