; export.msg : messages de EXPORT.COM en anglais (le français est dans
;   progs/msg/fr/export.msg, mêmes étiquettes). Inclus par progs/export.s.
m_use   .asc "EXPORT file [name] : copies a file",13,10
        .asc "to the USB stick of the LOCI",13,10
        .asc "EXPORT *.LOG [folder] : several",13,10,0
m_sep   .asc " : ",0
m_done  .asc " file(s) exported",13,10,0
m_nf    .asc "File not found",13,10,0
m_dsk   .asc "Refused : disk image (.DSK)",13,10,0
m_full  .asc "USB stick full",13,10,0
m_ok    .asc " bytes copied",13,10,0
