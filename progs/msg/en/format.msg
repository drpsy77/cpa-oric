; format.msg : messages de FORMAT.COM en anglais (le français est dans
;   progs/msg/fr/format.msg, mêmes étiquettes). Inclus par progs/format.s.
m_use   .asc "FORMAT X: [/Q] : formats X: (A to D)",13,10
        .asc "/Q : only empties the directory",13,10,0
m_ins   .asc "Insert in A: the disk to format",13,10,0
m_all   .asc "All of ",0
m_all2  .asc " will be erased. Go on (Y/N) ? ",0
m_abort .asc "Cancelled",13,10,0
m_sys   .asc "Put the system disk back in A:,",13,10
        .asc "then a key",13,10,0
m_unr   .asc "Unreadable disk : FORMAT without /Q",13,10,0
m_werr  .asc "Write error",13,10,0
m_qok   .asc "Directory empty",13,10,0
m_ok    .asc 13,10,"Format done",13,10,0
m_int   .asc 13,10,"Interrupted : format the disk again",13,10,0
m_abs   .asc 13,10,"Drive ",0
m_abs2  .asc " missing or empty",13,10,0
m_wp    .asc 13,10,"Disk write-protected",13,10,0
m_inc   .asc 13,10,"Track only partly written",13,10,0
m_verr  .asc 13,10,"Verify : error on sector ",0
m_42    .asc "42-track image? 80 tracks needed",13,10,0
m_trk   .asc "Track ",0
m_face  .asc " side ",0
K_YES   = "Y"           ; touche Oui (Yes)
