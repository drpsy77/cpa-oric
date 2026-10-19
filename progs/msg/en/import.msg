; import.msg : messages de IMPORT.COM en anglais (le français est dans
;   progs/msg/fr/import.msg, mêmes étiquettes). Inclus par progs/import.s.
m_use   .asc "IMPORT name [file] [/T] : copies a",13,10
        .asc "file from the USB stick of the LOCI",13,10
        .asc "/T : text, lone LF -> CR LF,",13,10
        .asc "     TAB -> space",13,10,0
m_name  .asc "Bad CP/A name : IMPORT name file",13,10,0
m_dir   .asc "Directory full",13,10,0
m_ro    .asc "File protected (SET file RW)",13,10,0
m_full  .asc "Disk full",13,10,0
m_sep   .asc " : ",0
m_ok    .asc " bytes",13,10,0
