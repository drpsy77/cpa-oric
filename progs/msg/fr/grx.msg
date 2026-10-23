; grx.msg : messages de la bibliothèque d'exécution des programmes traduits
;   (progs/grx.inc), en français ; la traduction anglaise est dans
;   progs/msg/en/grx.msg, mêmes étiquettes. Recopié dans GRX.INC à la place de
;   « ;#msg grx.msg » par tools/strip_inc.py ; g_m_el : longueur du préfixe «
;   Erreur : » (FIL.INC affiche le message sans lui).
g_m_el    = 9                 ; longueur de « Erreur : »
g_m_err   .asc "Erreur : ",0
g_m_nolo  .asc "Erreur : LORES d'abord",0
g_m_noimg .asc "Erreur : image introuvable",0
g_m_full  .asc "Erreur : disque plein",0
g_m_ro    .asc "Erreur : fichier protege",0
g_m_dir   .asc "Erreur : repertoire plein",0
