; mktap.msg : messages de MKTAP.COM (français) ; la traduction anglaise est
; dans progs/msg/en/mktap.msg, mêmes étiquettes. Inclus par progs/mktap.s.
m_use   .asc "MKTAP nom fic adr[,lg] [/R] ...",13,10
        .asc "ecrit NOM.TAP pour CLOAD (BASIC)",13,10
        .asc "adr, lg : hexa ; /R : bloc lance",13,10
        .asc "MKTAP JEU JEU.COM 500 /R",13,10
        .asc "MKTAP J P.COM 9000 /R IMG.HIR A000",13,10,0
m_many  .asc "8 fichiers au plus",13,10,0
m_two   .asc "/R une seule fois",13,10,0
m_name  .asc "Nom invalide",13,10,0
m_adr   .asc "Adresse invalide",13,10,0
m_abs   .asc " : absent",13,10,0
m_rerr  .asc " : illisible",13,10,0
m_void  .asc " : vide",13,10,0
m_short .asc " : plus court que lg",13,10,0
m_range .asc " : hors de 0500-BFFF",13,10,0
m_over  .asc " : chevauche ",0
m_ro    .asc " : fichier protege",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_full  .asc 13,10,"Disque plein",13,10,0
m_done  .asc " ecrit",13,10,0
m_bas   .asc " BASIC",0
m_run   .asc " /R",0
