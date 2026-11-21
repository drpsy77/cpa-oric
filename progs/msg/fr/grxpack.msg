; grxpack.msg : messages de GRXPACK.COM en français ; la traduction anglaise est
;   dans progs/msg/en/grxpack.msg, mêmes étiquettes. Inclus par progs/grxpack.s.
m_use   .asc "GRXPACK SOURCE DEST : ecrit DEST.GRX,",13,10
        .asc "le programme de SOURCE.GRX sans",13,10
        .asc "commentaires ni espaces inutiles.",13,10
        .asc "GRXPACK SOURCE /L n : la ligne de la",13,10
        .asc "source qui a donne la ligne n.",13,10,0
m_same  .asc "DEST doit etre un autre fichier",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_full  .asc "Disque plein : rien n'est ecrit",13,10,0
m_ro    .asc "Fichier protege : resultat dans",13,10
        .asc "DEST.$$$",13,10,0
m_long  .asc "Ligne trop longue : ",0
m_nol   .asc "Pas de ligne de ce numero",13,10,0
m_in    .asc "Lu    : ",0
m_out   .asc "Ecrit : ",0
m_lines .asc " lignes, ",0
m_bytes .asc " octets",13,10,0
m_l1    .asc "Ligne ",0
m_l2    .asc " : ligne ",0
m_l3    .asc " de la source",13,10,0
