; copy.msg : messages de COPY.COM en anglais (le français est dans
;   progs/msg/fr/copy.msg, mêmes étiquettes). Inclus par progs/copy.s.
m_use   .asc "COPY src [dst] : copy (wildcards ok)",13,10
        .asc "COPY *.COM B:   COPY B:*.LOG",13,10
        .asc "COPY *.TXT *.BAK",13,10,0
m_none  .asc "No file",13,10,0
m_same  .asc " : same file",13,10,0
m_ro    .asc " : file protected",13,10,0
m_rerr  .asc " : unreadable",13,10,0
m_dir   .asc 13,10,"Directory full",13,10,0
m_full  .asc 13,10,"Disk full",13,10,0
m_done  .asc " file(s) copied",13,10,0
