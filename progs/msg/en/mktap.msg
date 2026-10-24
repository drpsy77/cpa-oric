; mktap.msg : messages de MKTAP.COM en anglais (le français est dans
;   progs/msg/fr/mktap.msg, mêmes étiquettes). Inclus par progs/mktap.s.
m_use   .asc "MKTAP name file adr[,len] [/R] ...",13,10
        .asc "writes NAME.TAP for CLOAD (BASIC)",13,10
        .asc "adr, len: hex; /R: block is run",13,10
        .asc "MKTAP GAME GAME.COM 500 /R",13,10
        .asc "MKTAP G P.COM 9000 /R IMG.HIR A000",13,10,0
m_many  .asc "8 files at most",13,10,0
m_two   .asc "/R only once",13,10,0
m_name  .asc "Invalid name",13,10,0
m_adr   .asc "Invalid address",13,10,0
m_abs   .asc ": not found",13,10,0
m_rerr  .asc ": unreadable",13,10,0
m_void  .asc ": empty",13,10,0
m_short .asc ": shorter than len",13,10,0
m_range .asc ": outside 0500-BFFF",13,10,0
m_over  .asc ": overlaps ",0
m_ro    .asc ": file protected",13,10,0
m_dir   .asc "Directory full",13,10,0
m_full  .asc 13,10,"Disk full",13,10,0
m_done  .asc " written",13,10,0
m_bas   .asc " BASIC",0
m_run   .asc " /R",0
