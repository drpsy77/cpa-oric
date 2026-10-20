; edit.msg : menus et messages d'EDIT.COM en anglais (le français est dans
;   progs/msg/fr/edit.msg, mêmes étiquettes). Inclus par progs/edit.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; it_quit et
; s_retour (« Back » quand EDIT est lancé par LOGO) : 7 caractères copiés.
mn_fic  .byt 7,14
        .asc "File",0
        .asc "New",0
        .byt MA_TYPE
        .word c_new
        .asc "Open...     ^O",0
        .byt MA_TYPE
        .word c_open
        .asc "Insert...   ^I",0
        .byt MA_TYPE
        .word c_insert
        .asc "Save        ^S",0
        .byt MA_TYPE
        .word c_save
        .asc "Save as...",0
        .byt MA_TYPE
        .word c_saveas
        .asc "Print       ^P",0
        .byt MA_TYPE
        .word c_print
it_quit .asc "Quit        ^Q",0
        .byt MA_TYPE
        .word c_quit

mn_edi  .byt 5,15
        .asc "Edit",0
        .asc "Mark       ^Spc",0
        .byt MA_TYPE
        .word c_mark
        .asc "Copy         ^C",0
        .byt MA_TYPE
        .word c_copy
        .asc "Cut          ^X",0
        .byt MA_TYPE
        .word c_cut
        .asc "Paste        ^V",0
        .byt MA_TYPE
        .word c_paste
        .asc "Del. para.   ^K",0
        .byt MA_TYPE
        .word c_delp

mn_chr  .byt 4,14
        .asc "Search",0
        .asc "Find...     ^F",0
        .byt MA_TYPE
        .word c_find
        .asc "Next        ^G",0
        .byt MA_TYPE
        .word c_next
        .asc "Replace...  ^H",0
        .byt MA_TYPE
        .word c_repl
        .asc "Too long    ^L",0
        .byt MA_TYPE
        .word c_long

mn_opt  .byt 5,14
        .asc "Options",0
it_mots .asc ">Word wrap",0
        .byt MA_TYPE
        .word c_wrap
it_car  .asc " Wrap at 38",0
        .byt MA_TYPE
        .word c_wcar
it_lig  .asc " Line       ^W",0
        .byt MA_TYPE
        .word c_wlig
        .asc " Ins/Ovr    ^E",0
        .byt MA_TYPE
        .word c_ins
        .asc " Statistics",0
        .byt MA_TYPE
        .word c_stats

s_retour .asc "Back   "

m_noname  .asc "(no name)",0
m_ins     .asc "INS"
m_rfp     .asc "OVR"
m_full    .asc "Memory full",0
m_mark    .asc "Mark set",0
m_nomark  .asc "No mark (Edit/Mark)",0
m_empty   .asc "Empty block",0
m_big     .asc "Block too big (4 KB max)",0
m_copied  .asc "Block copied",0
m_clipe   .asc "Clipboard empty",0
m_notf    .asc "Not found",0
m_wrapped .asc "Found from the start",0
m_nrep    .asc " replacement(s)",0
m_car     .asc " chars, ",0
m_mots    .asc " words",0
m_wron    .asc "Wrap between words",0
m_max     .asc ", max ",0
m_nolim   .asc "No length limit (EDIT.CFG)",0
m_nolong  .asc "No paragraph too long",0
m_long    .asc "Paragraph too long: next one",0
m_wroff   .asc "Wrap at 38 characters",0
m_wrlin   .asc "Whole line (scrolling)",0
m_newf    .asc "New file",0
m_toobig  .asc "File truncated: too big",0
m_trunc   .asc "Text truncated: Save as...",0
m_saved   .asc "Saved",0
m_ro      .asc "File protected (R/O)",0
m_dirfull .asc "Directory full",0
m_dfull   .asc "Disk full: not saved",0
m_renf    .asc "Disk error: text in .$$$",0
m_badname .asc "Bad file name",0
q_lose    .asc "Discard changes (Y/N) ?",0
q_quit    .asc "Text changed. Quit (Y/N) ?",0
q_open    .asc "Open: ",0
q_insert  .asc "Insert: ",0
m_nofile  .asc "File not found",0
m_pdone   .asc "Text printed",0
m_pstop   .asc "Printing interrupted",0
m_inserted .asc " chars inserted",0
q_saveas  .asc "Save as: ",0
q_repl1   .asc "Replace ",0
q_repl2   .asc " (Y/N) ?",0
q_find    .asc "Find: ",0
q_repl    .asc "Replace with: ",0
q_yn      .asc "Replace? Y/N/A(ll)/Esc",0
K_YES   = "Y"           ; touche Oui (Yes)
K_ALL   = "A"           ; touche Tous (All) : remplacements
