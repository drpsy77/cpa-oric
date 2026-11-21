; grxpack.msg : messages de GRXPACK.COM en anglais (le français est dans
;   progs/msg/fr/grxpack.msg, mêmes étiquettes). Inclus par progs/grxpack.s.
m_use   .asc "GRXPACK SOURCE DEST : writes DEST.GRX,",13,10
        .asc "the program of SOURCE.GRX without",13,10
        .asc "comments or useless spaces.",13,10
        .asc "GRXPACK SOURCE /L n : the line of the",13,10
        .asc "source that gave line n.",13,10,0
m_same  .asc "DEST must be another file",13,10,0
m_nf    .asc "File not found",13,10,0
m_dir   .asc "Directory full",13,10,0
m_full  .asc "Disk full : nothing written",13,10,0
m_ro    .asc "Read-only file : result in",13,10
        .asc "DEST.$$$",13,10,0
m_long  .asc "Line too long : ",0
m_nol   .asc "No line with that number",13,10,0
m_in    .asc "Read  : ",0
m_out   .asc "Wrote : ",0
m_lines .asc " lines, ",0
m_bytes .asc " bytes",13,10,0
m_l1    .asc "Line ",0
m_l2    .asc " : line ",0
m_l3    .asc " of the source",13,10,0
