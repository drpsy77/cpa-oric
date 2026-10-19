; export.msg : messages de EXPORT.COM (français) ; la traduction anglaise est
; dans progs/msg/en/export.msg, mêmes étiquettes. Inclus par progs/export.s.
m_use   .asc "EXPORT fic [nom] : copie un fichier",13,10
        .asc "sur la cle USB du LOCI",13,10
        .asc "EXPORT *.LOG [dossier] : plusieurs",13,10,0
m_sep   .asc " : ",0
m_done  .asc " fichier(s) exporte(s)",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_dsk   .asc "Refuse : image de disquette (.DSK)",13,10,0
m_full  .asc "Cle USB pleine",13,10,0
m_ok    .asc " octets copies",13,10,0
