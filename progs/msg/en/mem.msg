; mem.msg : messages de MEM.COM en anglais (le français est dans
;   progs/msg/fr/mem.msg, mêmes étiquettes). Inclus par progs/mem.s.
m_head  .asc "Memory map (",0
m_text  .asc "text mode)",13,10,0
m_split .asc "SPLIT mode)",13,10,0
m_low   .asc "0000-00DF free zero page",13,10
        .asc "00E0-00FF system zero page",13,10
        .asc "0100-01FF stack",13,10
        .asc "0200-02FF system (0203 = BDOS)",13,10
        .asc "0300-03FF input-output",13,10
        .asc "0400-04FF base page, DMA 0480",13,10,0
m_tpa   .asc "0500-",0
m_tpa2  .asc " TPA : ",0
m_tpa3  .asc " bytes",13,10,0
m_img   .asc "A000-B3FF picture (SPLIT)",13,10,0
m_resv  .asc "FF reserved (DEBUG)",13,10,0
gblk    .byt G_GETMODE
m_high  .asc "B400-BB7F character sets",13,10
        .asc "BB80-BFDF text screen",13,10
        .asc "C000-FFFF CP/A (overlay RAM)",13,10,0
