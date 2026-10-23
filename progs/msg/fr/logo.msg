; logo.msg : menus, aide (AIDE) et messages de LOGO.COM en français ; la
;   traduction anglaise est dans progs/msg/en/logo.msg, mêmes étiquettes. Inclus
;   par progs/logo.s. Les noms des primitives et les commandes tapées par les
;   menus sont dans logovoc.msg (tools/gen_logo_voc.py).
; barre de menus : les articles tapent des commandes
lg_bar  .byt 3
        .word mn_fic, mn_tor, mn_aid
mn_fic  .byt 8,12
        .asc "Fichier",0
        .asc "Charger...",0
        .byt MA_TYPE
        .word ty_charge
        .asc "Sauver...",0
        .byt MA_TYPE
        .word ty_sauve
        .asc "Editer...",0
        .byt MA_TYPE
        .word ty_edite
        .asc "Charger img.",0
        .byt MA_TYPE
        .word ty_cimg
        .asc "Sauver img.",0
        .byt MA_TYPE
        .word ty_simg
        .asc "Titres",0
        .byt MA_TYPE
        .word ty_titres
        .asc "Tout oubli",0
        .byt MA_TYPE
        .word ty_oubtout
        .asc "Quitter",0
        .byt MA_TYPE
        .word ty_quitte
mn_tor  .byt 7,12
        .asc "Tortue",0
        .asc "Efface ecran",0
        .byt MA_TYPE
        .word ty_ve
        .asc "Origine",0
        .byt MA_TYPE
        .word ty_orig
        .asc "Cache",0
        .byt MA_TYPE
        .word ty_ct
        .asc "Montre",0
        .byt MA_TYPE
        .word ty_mt
        .asc "Leve crayon",0
        .byt MA_TYPE
        .word ty_lc
        .asc "Ecran texte",0
        .byt MA_TYPE
        .word ty_etxt
        .asc "Ecran mixte",0
        .byt MA_TYPE
        .word ty_emix
mn_aid  .byt 1,10
        .asc "Aide",0
        .asc "Primitives",0
        .byt MA_TYPE
        .word ty_aide


m_banner  .asc "LOGO CP/A - tapez AIDE",13,10,0
m_prompt  .asc "? ",0
m_prompt2 .asc "> ",0
m_defined .asc " defini.",13,10,0
m_saved   .asc "Sauve.",13,10,0
m_loaded  .asc "Charge.",13,10,0
m_aide    .asc "AV RE DR GA n  LC BC GOMME INVERSE",13,10
          .asc "CT MT VE NETTOIE ORIGINE",13,10
          .asc "ECRANTEXTE ECRANMIXTE  VT  TAPE x",13,10
          .asc "FIXECURSEUR c l CURSEUR CARECRAN c l",13,10
          .asc "FIXECAP n  FIXEXY x y  ATTENDS n",13,10
          .asc "POINT x y  TRAIT RECTANGLE PAVE x y x y",13,10
          .asc "CERCLE r  ETIQUETTE x  FIXECOULEUR v",13,10
          .asc "SON v n vol d (37 = do)  SILENCE",13,10
          .asc "SONF v p vol d  BRUITV v p vol d",13,10
          .asc "ENVELOPPE f p  MELANGE v son bruit",13,10
          .asc "ENSEMBLE [..]  ATTENDSSON v  JOUE? v",13,10
          .asc "REPETE n [..]  SI c [..] [..]  STOP",13,10
          .asc "POUR NOM :A ... FIN  DONNE ",$22,"X n",13,10
          .asc "ECRIS n/",$22,"mot/[..]  HASARD CAP",13,10
          .asc "XCOR YCOR  + - * / ( ) = < >",13,10
          .asc "LISLISTE LISMOT LISCAR TOUCHE? TOUCHE",13,10
          .asc "ASCII x  CAR n  FIXECARECRAN c l n",13,10
          .asc "ENT ARRONDI ABS  QUOTIENT RESTE",13,10
          .asc "Decimaux : 3.14  1.5E-7  7 / 2",13,10
          .asc "RACINE SIN COS ARCTAN LN EXP",13,10
          .asc "MOT PHRASE LISTE PREMIER DERNIER",13,10
          .asc "SAUFPREMIER SAUFDERNIER ITEM",13,10
          .asc "COMPTE VIDE? MOT? NOMBRE? LISTE?",13,10
          .asc "MEMBRE?  EXECUTE [..]  RENDS x",13,10
          .asc "SAUVE/CHARGE/EDITE ",$22,"NOM  TITRES",13,10
          .asc "SAUVEIMAGE/CHARGEIMAGE ",$22,"NOM",13,10
          .asc "LISTE/OUBLIE ",$22,"NOM  OUBLIETOUT",13,10
          .asc "ESC interrompt  QUITTE",13,10,0
e_what    .asc "Que faire de cela ?",0
e_unknown .asc "Je ne connais pas",0
e_value   .asc "Il manque une valeur",0
e_novar   .asc "Pas de valeur pour",0
e_div     .asc "Division par zero",0
e_notnum  .asc "Il faut un nombre",0
e_big     .asc "Nombre trop grand",0
e_dom     .asc "Calcul impossible",0
e_empty   .asc "Mot ou liste vide",0
e_word    .asc "Il faut un mot",0
e_list    .asc "Il faut une liste [ ] apres",0
e_bracket .asc "Il manque un ] apres",0
e_deep    .asc "Trop de niveaux",0
e_mem     .asc "Memoire pleine",0
e_esc     .asc "Interrompu",0
e_quote   .asc "Il faut un nom avec ",$22," apres",0
e_inload  .asc "Interdit pendant CHARGE :",0
e_pour    .asc "POUR seulement au debut d'une ligne",0
e_name    .asc "Il faut un nom apres POUR",0
e_disk    .asc "Erreur disque",0
e_nofile  .asc "Fichier introuvable",0
e_long    .asc "Ligne de plus de 126 car. : L ",0
e_noret   .asc "Rien n'a ete rendu par",0
e_unused  .asc "Que faire de ce que rend",0
e_rtop    .asc "RENDS seulement dans une procedure",0
e_text    .asc "Impossible en ecran texte :",0
e_range   .asc "Valeur hors limites :",0
m_lost    .asc "Etat de LOGO.$$$ perdu",13,10,0
