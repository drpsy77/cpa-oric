; copy.msg : messages de COPY.COM (français) ; la traduction anglaise est
; dans progs/msg/en/copy.msg, mêmes étiquettes. Inclus par progs/copy.s.
m_use   .asc "COPY src [dst] : copie (jokers admis)",13,10
        .asc "COPY *.COM B:   COPY B:*.LOG",13,10
        .asc "COPY *.TXT *.BAK",13,10,0
m_none  .asc "Aucun fichier",13,10,0
m_same  .asc " : meme fichier",13,10,0
m_ro    .asc " : fichier protege",13,10,0
m_rerr  .asc " : illisible",13,10,0
m_dir   .asc 13,10,"Repertoire plein",13,10,0
m_full  .asc 13,10,"Disque plein",13,10,0
m_done  .asc " fichier(s) copie(s)",13,10,0
