; logotr.msg : messages de LOGOTR.COM en anglais (le français est dans
;   progs/msg/fr/logotr.msg, mêmes étiquettes). Inclus par progs/logotr.s.
D_LANG  = 1             ; sans option : traduit vers l'anglais (/EN)
m_use   .asc "LOGOTR NAME [DEST] [/EN|/FR] : turns",13,10
        .asc "NAME.LOG into English (/EN, the",13,10
        .asc "default) or French (/FR) ; no DEST :",13,10
        .asc "NAME replaced, NAME.BAK kept.",13,10
        .asc "Only the primitives are translated.",13,10,0
m_nf    .asc "File not found",13,10,0
m_big   .asc "File too big",13,10,0
m_dir   .asc "Directory full",13,10,0
m_full  .asc "Disk full : nothing changed",13,10,0
m_ro    .asc "File protected : translation in",13,10
        .asc "NAME.$$$",13,10,0
m_line  .asc "L ",0
m_sep   .asc " : ",0
m_crlf  .asc 13,10,0
m_wdata .asc "data list ? ",0
m_wname .asc "primitive name : ",0
m_ntr   .asc " words translated, ",0
m_nwarn .asc " warning(s)",13,10,0
m_done  .asc "Written : ",0
