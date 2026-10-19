; diskcopy.msg : messages de DISKCOPY.COM (français) ; la traduction anglaise est
; dans progs/msg/en/diskcopy.msg, mêmes étiquettes. Inclus par progs/diskcopy.s.
m_use   .asc "DISKCOPY src: dst: [/T] [/V] [/S]",13,10
        .asc "copie une disquette (dst formatee)",13,10
        .asc "/T tout  /V relecture",13,10
        .asc "/S systeme seulement (SYSGEN)",13,10,0
m_srcbad .asc "Source illisible",13,10,0
m_dstbad .asc "Destination illisible : FORMAT ?",13,10,0
m_cs    .asc "Systeme (amorcage) copie sur ",0
m_cs2   .asc 13,10,"(fichiers gardes).",0
m_ca    .asc "Tout ",0
m_ca2   .asc " sera remplace par ",0
m_ca3   .asc ".",0
m_yn    .asc 13,10,"Suite (O/N) ? ",0
m_c1    .asc "La DESTINATION sera remplacee.",0
m_abort .asc "Abandon",13,10,0
m_ok    .asc 13,10,"Copie terminee",13,10,0
m_inc   .asc 13,10,"Copie interrompue : destination",13,10
        .asc "incomplete",13,10,0
m_sys   .asc "Remettez la disquette systeme en A:,",13,10
        .asc "puis une touche",13,10,0
m_isrc  .asc 13,10,"SOURCE en ",0
m_idst  .asc 13,10,"DESTINATION en ",0
m_key   .asc ", une touche",0
m_rerr  .asc 13,10,"Erreur de lecture, secteur ",0
m_werr  .asc 13,10,"Erreur d'ecriture, secteur ",0
m_verr  .asc 13,10,"Relecture differente, secteur ",0
m_tr    .asc "Tranche ",0
m_rd    .asc " : lecture    ",0
m_wr    .asc " : ecriture   ",0
m_vf    .asc " : relecture  ",0
K_YES   = "O"           ; touche Oui
