; cmder.msg : barre de menus, messages et en-têtes de CMDER.COM (français) ;
; la traduction anglaise est dans progs/msg/en/cmder.msg, mêmes étiquettes.
; Inclus par progs/cmder.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; it_sys,
; s_hide, s_show : 11 caractères copiés. m_t2, m_t2u : 18 caractères (en-tête
; d'une colonne en mode deux colonnes). gname : 7 caractères par genre.
; spos, spos2 : colonne du signe + ou - du tri dans les en-têtes (clés 1-4 :
; ordre du disque, nom, type, taille ; puis la même chose pour la clé USB).

bar     .byt 4
        .word mn_f, mn_m, mn_t, mn_v

mn_f    .byt 14,16
        .asc "Fichier",0
        .asc "Voir         RET",0
        .byt MA_TYPE
        .word c81
        .asc "Copier...     ^C",0
        .byt MA_TYPE
        .word c82
        .asc "Copier texte...",0
        .byt MA_TYPE
        .word c9e
        .asc "Deplacer...   ^X",0
        .byt MA_TYPE
        .word c83
        .asc "Renommer...   ^N",0
        .byt MA_TYPE
        .word c84
        .asc "Effacer      DEL",0
        .byt MA_TYPE
        .word c85
        .asc "Dupliquer...  ^U",0
        .byt MA_TYPE
        .word ca0
        .asc "Monter...     ^O",0
        .byt MA_TYPE
        .word ca1
        .asc "Attributs...  ^A",0
        .byt MA_TYPE
        .word c86
        .asc "Infos          ?",0
        .byt MA_TYPE
        .word c87
        .asc "Imprimer liste",0
        .byt MA_TYPE
        .word c99
        .asc "Lecteur...    ^L",0
        .byt MA_TYPE
        .word c88
        .asc "Relire        ^R",0
        .byt MA_TYPE
        .word c89
        .asc "Quitter       ^Q",0
        .byt MA_TYPE
        .word c8a

mn_m    .byt 6,14
        .asc "Marque",0
        .asc "Marquer    ESP",0
        .byt MA_TYPE
        .word c8b
        .asc "Marquer...   +",0
        .byt MA_TYPE
        .word c8c
        .asc "Oter...      -",0
        .byt MA_TYPE
        .word c8d
        .asc "Inverser     *",0
        .byt MA_TYPE
        .word c8e
        .asc "Tout",0
        .byt MA_TYPE
        .word c8f
        .asc "Rien",0
        .byt MA_TYPE
        .word c90

mn_t    .byt 4,14
        .asc "Trier",0
        .asc "Ordre disque 1",0
        .byt MA_TYPE
        .word c91
        .asc "Nom          2",0
        .byt MA_TYPE
        .word c92
        .asc "Type         3",0
        .byt MA_TYPE
        .word c93
        .asc "Taille       4",0
        .byt MA_TYPE
        .word c94

mn_v    .byt 9,17
        .asc "Vue",0
        .asc "Filtrer...     /",0
        .byt MA_TYPE
        .word c95
        .asc "Sans filtre",0
        .byt MA_TYPE
        .word c96
        .asc "Repertoires seuls",0
        .byt MA_TYPE
        .word c9f
it_sys  .asc "Cacher SYS ",0
        .byt MA_TYPE
        .word c97
        .asc "Taille exacte ^E",0
        .byt MA_TYPE
        .word c98
        .asc "Absents autre",0
        .byt MA_TYPE
        .word c9a
        .asc "Zoom          ^Z",0
        .byt MA_TYPE
        .word c9b
        .asc "Echanger      ^W",0
        .byt MA_TYPE
        .word c9c
        .asc "Autre col.    ^I",0
        .byt MA_TYPE
        .word c9d

s_hide  .asc "Cacher SYS "
s_show  .asc "Montrer SYS"

m_cols  .asc "  NOM      TYP  TAILLE RS   N GENRE",0
m_help  .asc "FUNCT menus  ESP marque  ESC fin",0
m_nodrv .asc "lecteur absent ou illisible",0
m_fic   .asc " fic",0
m_lib   .asc "K libre",0
m_marks .asc " marque(s) : ",0
m_oct   .asc " o",0
m_sep   .asc " : ",0
m_enr   .asc " enr., ",0
m_blk   .asc " bloc(s)",0
m_none  .asc "Aucun fichier",0
m_vmore .asc "-- ESP : suite, ESC : retour --",0
m_vend  .asc "-- Fin du fichier : une touche --",0
m_rerr  .asc "Fichier illisible",0
m_era   .asc "Effacer ",0
m_cop   .asc "Copier ",0
m_mov   .asc "Deplacer ",0
m_nfic  .asc " fichiers",0
m_yn    .asc " (O/N) ?",0
m_ynt   .asc " (O/N/T) ?",0
m_to    .asc " vers : ",0
m_erased .asc " efface(s)",0
m_copied .asc " copie(s)",0
m_moved .asc " deplace(s)",0
m_prot  .asc " protege(s)",0
m_illis .asc " illisible(s)",0
m_bad   .asc "Nom incorrect",0
m_one   .asc "Un nom : un seul fichier",0
m_one1  .asc "Un seul fichier a la fois",0
m_nodst .asc "Destination illisible",0
m_dirf  .asc "Repertoire plein",0
m_full  .asc "Disque plein : copie effacee",0
m_repl  .asc "Remplacer ",0
m_isrc  .asc "SOURCE en ",0
m_idst  .asc "DESTINATION en ",0
m_key   .asc ", une touche",0
m_keyst .asc " (ESC : rester)",0
m_err   .asc "Erreur, ",0
m_same  .asc "Comme la source : continuer (O/N) ?",0
m_ioerr .asc "Erreur disque : verifiez la disquette",0
m_t2    .asc " NOM      TYP   Ko"
m_twod  .asc "Deux lecteurs differents",0
m_twou  .asc "Une seule colonne USB",0
m_usbonly .asc "Cle USB seulement",0
m_nosup .asc "Choisir d'abord un support",0
m_sups  .asc "supports",0
m_fonly .asc "Fichiers seulement",0
m_imgm  .asc "Image montee en ",0
m_ofkey .asc " de la cle",0
m_dupq  .asc "Dupliquer en : ",0
m_dupok .asc "Duplique",0
m_tmpn  .asc "~CPADUP.TMP",0
m_ko    .asc " Ko",0
m_mntq  .asc "Monter en : ",0
m_notimg .asc "Pas une image (.DSK ou .TAP)",0
m_sysa  .asc "A: interdit (disquette systeme)",0
m_usb   .asc "USB:",0
m_usbro .asc "Cle USB : pas d'attributs",0
m_usberr .asc "Erreur USB (cle absente ou pleine ?)",0
m_noloci2 .asc "LOCI absent : cle USB inaccessible",0
m_refus .asc " refuse(s)",0
m_colsu .asc "  NOM                         TAILLE",0
m_t2u   .asc " NOM            Ko"
m_rep   .asc "<REP>",0
m_ucut  .asc " +",0
m_one2  .asc "Une seule colonne",0
m_prt   .asc "Impression... (ESC arrete)",0
m_prtok .asc "Liste imprimee",0
m_libre .asc "Libre ",0
m_req   .asc "K, requis ",0
m_ynk   .asc "K : O/N ?",0
m_non   .asc "Non ! ",0
m_rdir  .asc "Lecture du repertoire...",0
m_cpy   .asc "Copie : ",0
m_incpl .asc " incomplet",0
m_esc   .asc "Interrompu",0
m_newn  .asc "Nouveau nom : ",0
m_taken .asc "Nom deja pris",0
m_ro    .asc "Fichier protege (R/O)",0
m_roorig .asc "Original protege (R/O)",0
m_renok .asc "Renomme",0
m_samedrv .asc "Meme lecteur seulement",0
m_attq  .asc "Attributs (R S) : ",0
m_attbad .asc "R et S seulement",0
m_attok .asc "Attributs changes",0
m_markq .asc "Marquer : ",0
m_unmq  .asc "Oter : ",0
m_filtq .asc "Filtre : ",0
m_drvq  .asc "Lecteur (A-D) : ",0
m_drvbad .asc "Lecteur A a D",0
m_wait  .asc "Tailles exactes... (ESC arrete)",0
m_exok  .asc "Tailles exactes",0

gname   .asc "       Prog   Script Grapher"
        .asc "Logo   Source Texte  Config "
        .asc "Image  Anim   Symb.  Tempo  Disque "

spos    .byt 29,5,14,22
        .byt 0,5,5,29           ; (clé USB)
spos2   .byt 0,4,13,15
        .byt 0,4,4,15           ; (clé USB)

K_YES   = "O"           ; touche Oui
K_ALL   = "T"           ; touche Tous
