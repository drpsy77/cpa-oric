; untap.msg : messages d'UNTAP.COM (français) ; la traduction anglaise est
; dans progs/msg/en/untap.msg, mêmes étiquettes. Inclus par progs/untap.s.
m_use   .asc "UNTAP nom [n|*] [/1] : blocs .TAP",13,10
        .asc "UNTAP JEU      liste les blocs",13,10
        .asc "UNTAP JEU 2    extrait le bloc 2",13,10
        .asc "UNTAP JEU *    extrait tous les blocs",13,10
        .asc "BASIC : NOM.BAS (texte, MKTAP)",13,10
        .asc "code : NOM.BIN ; /1 : BASIC Oric-1",13,10,0
m_name  .asc "Nom invalide",13,10,0
m_bnum  .asc "Numero de bloc : 1 a 255",13,10,0
m_abs   .asc " : absent",13,10,0
m_none  .asc "Aucun bloc (pas un .TAP ?)",13,10,0
m_nob   .asc "Bloc absent",13,10,0
m_blk   .asc "bloc ",0
m_inc   .asc " incomplet",13,10,0
m_bas   .asc "BAS ",0
m_bin   .asc "BIN ",0
m_run   .asc " /R",0
m_lig   .asc "ligne ",0
m_dif   .asc " : recodage different",13,10,0
m_ro    .asc " : fichier protege",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_full  .asc 13,10,"Disque plein",13,10,0
m_done  .asc " ecrit",13,10,0
