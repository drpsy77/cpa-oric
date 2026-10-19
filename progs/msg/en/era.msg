; era.msg : messages de ERA.COM en anglais (le français est dans
;   progs/msg/fr/era.msg, mêmes étiquettes). Inclus par progs/era.s.
m_use   .asc "ERA afn [/Q] : erases (wildcards ok)",13,10
        .asc "after confirmation ; /Q : no question",13,10,0
m_nf    .asc "File not found",13,10,0
m_ro    .asc " protected, kept",13,10,0
m_none  .asc "Nothing to erase",13,10,0
m_ask1  .asc "Erase ",0
m_ask2  .asc " file(s) (Y/N) ? ",0
m_abort .asc "Cancelled",13,10,0
m_done  .asc " file(s) erased",13,10,0
K_YES   = "Y"           ; touche Oui (Yes)
