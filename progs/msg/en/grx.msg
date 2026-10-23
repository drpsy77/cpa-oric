; grx.msg : messages de la bibliothèque d'exécution des programmes traduits
;   (progs/grx.inc), en anglais (le français est dans progs/msg/fr/grx.msg,
;   mêmes étiquettes). Recopié dans GRX.INC à la place de « ;#msg grx.msg »
;   par tools/strip_inc.py ; g_m_el : longueur du préfixe
;   (FIL.INC affiche le message sans lui).
g_m_el    = 7                 ; longueur de « Error: »
g_m_err   .asc "Error: ",0
g_m_nolo  .asc "Error: LORES first",0
g_m_noimg .asc "Error: picture not found",0
g_m_full  .asc "Error: disk full",0
g_m_ro    .asc "Error: read-only file",0
g_m_dir   .asc "Error: directory full",0
