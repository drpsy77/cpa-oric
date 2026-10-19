; mem.msg : messages de MEM.COM (français) ; la traduction anglaise est
; dans progs/msg/en/mem.msg, mêmes étiquettes. Inclus par progs/mem.s.
m_head  .asc "Carte memoire (mode ",0
m_text  .asc "texte)",13,10,0
m_split .asc "SPLIT)",13,10,0
m_low   .asc "0000-00DF page zero libre",13,10
        .asc "00E0-00FF page zero du systeme",13,10
        .asc "0100-01FF pile",13,10
        .asc "0200-02FF systeme (0203 = BDOS)",13,10
        .asc "0300-03FF entrees-sorties",13,10
        .asc "0400-04FF page de base, DMA 0480",13,10,0
m_tpa   .asc "0500-",0
m_tpa2  .asc " TPA : ",0
m_tpa3  .asc " octets",13,10,0
m_img   .asc "A000-B3FF image (SPLIT)",13,10,0
m_resv  .asc "FF reservee (DEBUG)",13,10,0
gblk    .byt G_GETMODE
m_high  .asc "B400-BB7F jeux de caracteres",13,10
        .asc "BB80-BFDF ecran texte",13,10
        .asc "C000-FFFF CP/A (RAM overlay)",13,10,0
