; edsprite.msg : menus et messages d'EDSPRITE.COM (français) ; la traduction
; anglaise est dans progs/msg/en/edsprite.msg, mêmes étiquettes. Inclus par
; progs/edsprite.s. Menus : .byt nombre d'articles, largeur (plus long
; libellé). Messages de la ligne d'état : 37 caractères au plus.
mn_fic  .byt 5,15
        .asc "Fichier",0
        .asc "Nouveau      ^N",0
        .byt MA_TYPE
        .word c_81
        .asc "Ouvrir...    ^O",0
        .byt MA_TYPE
        .word c_82
        .asc "Enregistrer  ^S",0
        .byt MA_TYPE
        .word c_83
        .asc "Enreg. sous...",0
        .byt MA_TYPE
        .word c_84
        .asc "Quitter      ^Q",0
        .byt MA_TYPE
        .word c_85

mn_edi  .byt 5,11
        .asc "Edit",0
        .asc "Annuler  ^Z",0
        .byt MA_TYPE
        .word c_86
        .asc "Couper   ^X",0
        .byt MA_TYPE
        .word c_87
        .asc "Copier   ^C",0
        .byt MA_TYPE
        .word c_88
        .asc "Coller   ^V",0
        .byt MA_TYPE
        .word c_89
        .asc "Effacer",0
        .byt MA_TYPE
        .word c_8a

mn_spr  .byt 9,12
        .asc "Sprite",0
        .asc "Nouveau...",0
        .byt MA_TYPE
        .word c_8b
        .asc "Dupliquer",0
        .byt MA_TYPE
        .word c_8c
        .asc "Supprimer",0
        .byt MA_TYPE
        .word c_8d
        .asc "Renommer...",0
        .byt MA_TYPE
        .word c_8e
        .asc "Taille...",0
        .byt MA_TYPE
        .word c_8f
        .asc "Avancer",0
        .byt MA_TYPE
        .word c_90
        .asc "Reculer",0
        .byt MA_TYPE
        .word c_91
        .asc "Select   ^I",0
        .byt MA_TYPE
        .word c_92
        .asc "Saisie   ^I",0
        .byt MA_TYPE
        .word c_93

mn_des  .byt 10,17
        .asc "Dessin",0
        .asc "Inverser",0
        .byt MA_TYPE
        .word c_94
        .asc "Miroir horizont.",0
        .byt MA_TYPE
        .word c_95
        .asc "Miroir vertical",0
        .byt MA_TYPE
        .word c_96
        .asc "Quart de tour",0
        .byt MA_TYPE
        .word c_97
        .asc "Decaler a gauche",0
        .byt MA_TYPE
        .word c_98
        .asc "Decaler a droite",0
        .byt MA_TYPE
        .word c_99
        .asc "Decaler en haut",0
        .byt MA_TYPE
        .word c_9a
        .asc "Decaler en bas",0
        .byt MA_TYPE
        .word c_9b
        .asc "Silhouette=dessin",0
        .byt MA_TYPE
        .word c_9c
        .asc "Prendre police..",0
        .byt MA_TYPE
        .word c_9d

mn_vue  .byt 3,12
        .asc "Vue",0
        .asc "Codes hexa ^H",0
        .byt MA_TYPE
        .word c_9e
        .asc "Decor",0
        .byt MA_TYPE
        .word c_9f
        .asc "Animer",0
        .byt MA_TYPE
        .word c_a0

K_YES   = "O"           ; touche Oui
K_SPR   = "S"           ; nouveau fichier : sprites
K_TIL   = "T"           ;   ou tuiles

m_bad     .asc "Pas un fichier .SPR",13,10,"$"
m_bad2    .asc "Pas un fichier .SPR : nouveau",0
m_new     .asc "Nouveau fichier",0
m_noname  .asc "(sans nom)",0
m_real    .asc "Reel",0
m_codes   .asc "Codes",0
m_zsel    .asc "Select : RETURN saisie, S/M",0
m_car     .asc "car ",0
m_pen     .asc "crayon",0
m_nomask  .asc "Pas de masque (tuiles)",0
m_noundo  .asc "Rien a annuler",0
m_mem     .asc "Memoire pleine",0
m_full    .asc "255 sprites au plus",0
m_copied  .asc "Copie",0
m_noclip  .asc "Presse-papiers vide",0
m_last    .asc "Dernier sprite : garde",0
m_rot     .asc "Quart de tour : sprite 4x3",0
m_badnum  .asc "Code de 32 a 127",0
m_badsize .asc "Taille : 1 a 4 x 1 a 4 (2X2)",0
m_badname .asc "Nom : 1 a 4 lettres ou chiffres",0
m_badfn   .asc "Nom de fichier incorrect",0
m_dirfull .asc "Repertoire plein : non enregistre",0
m_dfull   .asc "Disque plein : non enregistre",0
m_ro      .asc "Fichier protege (R/O)",0
m_renf    .asc "Erreur : fichier dans NOM.$$$",0
m_saved   .asc "Enregistre",0
q_del     .asc "Supprimer ce sprite (O/N) ?",0
q_code    .asc "Premier code (32-127) : ",0
q_size    .asc "Taille (ex. 2X2) : ",0
q_name    .asc "Nom (4 car.) : ",0
q_genre   .asc "Sprites ou Tuiles (S/T) ?",0
q_lose    .asc "Abandonner les modifs (O/N) ?",0
q_open    .asc "Ouvrir : ",0
q_saveas  .asc "Enregistrer sous : ",0
q_repl    .asc "Remplacer ce fichier (O/N) ?",0
q_quit    .asc "Fichier modifie. Quitter (O/N) ?",0
s_plein   .asc "plein",0
s_masque  .asc "masque",0
s_transp  .asc "transparent",0
s_vide    .asc "vide",0
d_vide    .asc "Decor : vide",0
d_damier  .asc "Decor : damier",0
d_brique  .asc "Decor : briques",0
d_herbe   .asc "Decor : herbe",0
g_spr     .asc "sprites",0
g_til     .asc "tuiles",0
snames    .word s_plein, s_masque, s_transp
snames1   .word s_plein, s_vide, s_vide
dnames    .word d_vide, d_damier, d_brique, d_herbe
gnames    .word g_spr, g_til
