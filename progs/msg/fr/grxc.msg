; grxc.msg : messages communs à GRAPHER et GRXASM (progs/grxc_inc.s), en
;   français ; la traduction anglaise est dans progs/msg/en/grxc.msg, mêmes
;   étiquettes. Inclus par progs/grapher.s et progs/grxasm.s (une bibliothèque
;   ne contient pas de #include).
m_nogrx .asc "Fichier introuvable",13,10,"$"
m_unk   .asc "commande inconnue",0
m_param .asc "parametres ?",0
m_long  .asc "ligne de plus de 126 car.",0
m_full  .asc "disque plein",0
m_esc   .asc "Interrompu",0
m_big   .asc "Fichier trop gros",0
m_expr  .asc "expression ?",0
m_range .asc "valeur hors de 0-255",0
m_var   .asc "variable ? (A, AB ou A1)",0
m_div   .asc "division par zero",0
m_deep  .asc "trop de blocs imbriques",0
m_step  .asc "pas nul",0
m_nofor .asc "NEXT sans boucle",0
m_open  .asc "bloc non ferme",0
m_struct .asc "fin de bloc en trop",0
m_noret .asc "RETURN sans CALL",0
m_nosub .asc "SUB introuvable",0
m_strc  .asc "chaine dans un calcul",0
