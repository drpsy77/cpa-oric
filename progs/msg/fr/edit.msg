; edit.msg : menus et messages d'EDIT.COM (français) ; la traduction anglaise
; est dans progs/msg/en/edit.msg, mêmes étiquettes. Inclus par progs/edit.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; it_quit et
; s_retour (« Retour » quand EDIT est lancé par LOGO) : 7 caractères copiés.
mn_fic  .byt 7,14
        .asc "Fichier",0
        .asc "Nouveau",0
        .byt MA_TYPE
        .word c_new
        .asc "Ouvrir...   ^O",0
        .byt MA_TYPE
        .word c_open
        .asc "Inserer...  ^I",0
        .byt MA_TYPE
        .word c_insert
        .asc "Enregistrer ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Enreg. sous...",0
        .byt MA_TYPE
        .word c_saveas
        .asc "Imprimer    ^P",0
        .byt MA_TYPE
        .word c_print
it_quit .asc "Quitter     ^Q",0
        .byt MA_TYPE
        .word c_quit

mn_edi  .byt 5,15
        .asc "Edition",0
        .asc "Marquer    ^Esp",0
        .byt MA_TYPE
        .word c_mark
        .asc "Copier       ^C",0
        .byt MA_TYPE
        .word c_copy
        .asc "Couper       ^X",0
        .byt MA_TYPE
        .word c_cut
        .asc "Coller       ^V",0
        .byt MA_TYPE
        .word c_paste
        .asc "Eff. paragr. ^K",0
        .byt MA_TYPE
        .word c_delp

mn_chr  .byt 4,14
        .asc "Chercher",0
        .asc "Chercher... ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Suivant     ^G",0
        .byt MA_TYPE
        .word c_next
        .asc "Remplacer.. ^H",0
        .byt MA_TYPE
        .word c_repl
        .asc "Trop long   ^L",0
        .byt MA_TYPE
        .word c_long

mn_opt  .byt 5,14
        .asc "Options",0
it_mots .asc ">Coupure mots",0
        .byt MA_TYPE
        .word c_wrap
it_car  .asc " Coupure 38car",0
        .byt MA_TYPE
        .word c_wcar
it_lig  .asc " Ligne      ^W",0
        .byt MA_TYPE
        .word c_wlig
        .asc " Ins/Rempl. ^E",0
        .byt MA_TYPE
        .word c_ins
        .asc " Statistiques",0
        .byt MA_TYPE
        .word c_stats

s_retour .asc "Retour "

m_noname  .asc "(sans nom)",0
m_ins     .asc "INS"
m_rfp     .asc "RFP"
m_full    .asc "Memoire pleine",0
m_mark    .asc "Marque posee",0
m_nomark  .asc "Pas de marque (Edition/Marquer)",0
m_empty   .asc "Bloc vide",0
m_big     .asc "Bloc trop grand (4 Ko max)",0
m_copied  .asc "Bloc copie",0
m_clipe   .asc "Presse-papiers vide",0
m_notf    .asc "Introuvable",0
m_wrapped .asc "Trouve en repartant du debut",0
m_nrep    .asc " remplacement(s)",0
m_car     .asc " car., ",0
m_mots    .asc " mots",0
m_wron    .asc "Coupure entre les mots",0
m_max     .asc ", max ",0
m_nolim   .asc "Pas de longueur maxi (EDIT.CFG)",0
m_nolong  .asc "Aucun paragraphe trop long",0
m_long    .asc "Paragraphe trop long : la suite",0
m_wroff   .asc "Coupure a 38 caracteres",0
m_wrlin   .asc "Ligne entiere (defilement)",0
m_newf    .asc "Nouveau fichier",0
m_toobig  .asc "Fichier tronque : trop gros",0
m_trunc   .asc "Texte tronque : Enreg. sous...",0
m_saved   .asc "Enregistre",0
m_ro      .asc "Fichier protege (R/O)",0
m_dirfull .asc "Repertoire plein",0
m_dfull   .asc "Disque plein : non enregistre",0
m_renf    .asc "Erreur disque : texte dans .$$$",0
m_badname .asc "Nom de fichier incorrect",0
q_lose    .asc "Abandonner les modifs (O/N) ?",0
q_quit    .asc "Texte modifie. Quitter (O/N) ?",0
q_open    .asc "Ouvrir : ",0
q_insert  .asc "Inserer : ",0
m_nofile  .asc "Fichier introuvable",0
m_pdone   .asc "Texte imprime",0
m_pstop   .asc "Impression interrompue",0
m_inserted .asc " car. inseres",0
q_saveas  .asc "Enregistrer sous : ",0
q_repl1   .asc "Remplacer ",0
q_repl2   .asc " (O/N) ?",0
q_find    .asc "Chercher : ",0
q_repl    .asc "Remplacer par : ",0
q_yn      .asc "Remplacer ? O/N/T(ous)/Esc",0
K_YES   = "O"           ; touche Oui
K_ALL   = "T"           ; touche Tous (remplacements)
