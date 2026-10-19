; diskcopy.msg : messages de DISKCOPY.COM en anglais (le français est dans
;   progs/msg/fr/diskcopy.msg, mêmes étiquettes). Inclus par progs/diskcopy.s.
m_use   .asc "DISKCOPY src: dst: [/T] [/V] [/S]",13,10
        .asc "copies a disk (dst formatted)",13,10
        .asc "/T all  /V verify",13,10
        .asc "/S system only (SYSGEN)",13,10,0
m_srcbad .asc "Source unreadable",13,10,0
m_dstbad .asc "Destination unreadable : FORMAT ?",13,10,0
m_cs    .asc "System (boot) copied to ",0
m_cs2   .asc 13,10,"(files kept).",0
m_ca    .asc "All of ",0
m_ca2   .asc " will be replaced by ",0
m_ca3   .asc ".",0
m_yn    .asc 13,10,"Go on (Y/N) ? ",0
m_c1    .asc "The DESTINATION will be replaced.",0
m_abort .asc "Cancelled",13,10,0
m_ok    .asc 13,10,"Copy done",13,10,0
m_inc   .asc 13,10,"Copy interrupted : destination",13,10
        .asc "incomplete",13,10,0
m_sys   .asc "Put the system disk back in A:,",13,10
        .asc "then a key",13,10,0
m_isrc  .asc 13,10,"SOURCE in ",0
m_idst  .asc 13,10,"DESTINATION in ",0
m_key   .asc ", a key",0
m_rerr  .asc 13,10,"Read error, sector ",0
m_werr  .asc 13,10,"Write error, sector ",0
m_verr  .asc 13,10,"Verify mismatch, sector ",0
m_tr    .asc "Slice ",0
m_rd    .asc " : reading    ",0
m_wr    .asc " : writing    ",0
m_vf    .asc " : verifying  ",0
K_YES   = "Y"           ; touche Oui (Yes)
