; dis.msg : messages de DIS.COM (français) ; la traduction anglaise est
; dans progs/msg/en/dis.msg, mêmes étiquettes. Inclus par progs/dis.s.
m_use   .asc "DIS nom [adr] [/E adr ...]",13,10
        .asc "code machine -> NOM.ASM, un source",13,10
        .asc "qu'ASM reassemble a l'identique",13,10
        .asc "adr : chargement en hexa (0500)",13,10
        .asc "/E : points d'entree en plus",13,10
        .asc "type .BIN par defaut",13,10,0
m_name  .asc "Nom invalide",13,10,0
m_isasm .asc "Pas un .ASM : DIS l'ecrirait",13,10,0
m_abs   .asc " : absent",13,10,0
m_empty .asc "Fichier vide",13,10,0
m_big   .asc "Depasse $FFFF",13,10,0
m_nosym .asc "ATMOS.SYM absent : adresses en hexa",13,10,0
m_mem   .asc "Memoire insuffisante",13,10,0
m_rerr  .asc 13,10,"Erreur de lecture",13,10,0
m_ro    .asc " : fichier protege",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_full  .asc 13,10,"Disque plein",13,10,0
m_done  .asc " ecrit",13,10,0
