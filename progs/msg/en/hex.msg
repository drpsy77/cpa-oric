; hex.msg : menus et messages de HEX.COM en anglais (le français est dans
;   progs/msg/fr/hex.msg, mêmes étiquettes). Inclus par progs/hex.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; m_modes :
; trois mots de 4 caractères (mode de la ligne d'état).
mn_fic  .byt 3,14
        .asc "File",0
        .asc "Save        ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Reload      ^R",0
        .byt MA_TYPE
        .word c_reload
        .asc "Quit        ^Q",0
        .byt MA_TYPE
        .word c_quit

mn_all  .byt 5,13
        .asc "Go to",0
        .asc "Top      C-up",0
        .byt MA_TYPE
        .word c_top
        .asc "End    C-down",0
        .byt MA_TYPE
        .word c_bot
        .asc "Address... ^L",0
        .byt MA_TYPE
        .word c_goto
        .asc "Find...    ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Next       ^G",0
        .byt MA_TYPE
        .word c_next

mn_mod  .byt 1,13
        .asc "Mode",0
        .asc "Hex/ASCII TAB",0
        .byt MA_TYPE
        .word c_mode

m_usage   .asc "Usage : HEX file",13,10,"$"
m_nofile  .asc "File not found",13,10,"$"
m_empty   .asc "Empty file",13,10,"$"
m_nof2    .asc "File not found",0
m_trunc   .asc "Over 64 KB: start only",0
m_written .asc "Changes written",0
m_ro      .asc "Read only (file truncated)",0
m_saved   .asc "Saved",0
m_prot    .asc "File protected (R/O)",0
m_reload  .asc "File reloaded",0
m_dirfull .asc "Directory full",0
m_dfull   .asc "Disk full: not saved",0
m_badhex  .asc "Bad address",0
m_badpat  .asc "Bad pattern",0
m_notf    .asc "Not found",0
m_wrap    .asc "Found from the start",0
q_goto    .asc "Address (hex): ",0
q_find    .asc "Find (text or #hex): ",0
q_lose    .asc "Discard changes (Y/N) ?",0
q_quit    .asc "File changed. Quit (Y/N) ?",0
m_modes   .asc "HEX ASC R/O "
K_YES   = "Y"           ; touche Oui (Yes)
