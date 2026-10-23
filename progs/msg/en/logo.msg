; logo.msg : menus, aide (HELP) et messages de LOGO.COM en anglais (le
;   français est dans progs/msg/fr/logo.msg, mêmes étiquettes). Inclus
;   par progs/logo.s. Les noms des primitives et les commandes tapées par les
;   menus sont dans logovoc.msg (tools/gen_logo_voc.py).
; barre de menus : les articles tapent des commandes
lg_bar  .byt 3
        .word mn_fic, mn_tor, mn_aid
mn_fic  .byt 8,11
        .asc "File",0
        .asc "Load...",0
        .byt MA_TYPE
        .word ty_charge
        .asc "Save...",0
        .byt MA_TYPE
        .word ty_sauve
        .asc "Edit...",0
        .byt MA_TYPE
        .word ty_edite
        .asc "Load pic...",0
        .byt MA_TYPE
        .word ty_cimg
        .asc "Save pic...",0
        .byt MA_TYPE
        .word ty_simg
        .asc "Procedures",0
        .byt MA_TYPE
        .word ty_titres
        .asc "Erase all",0
        .byt MA_TYPE
        .word ty_oubtout
        .asc "Quit",0
        .byt MA_TYPE
        .word ty_quitte
mn_tor  .byt 7,12
        .asc "Turtle",0
        .asc "Clear screen",0
        .byt MA_TYPE
        .word ty_ve
        .asc "Home",0
        .byt MA_TYPE
        .word ty_orig
        .asc "Hide",0
        .byt MA_TYPE
        .word ty_ct
        .asc "Show",0
        .byt MA_TYPE
        .word ty_mt
        .asc "Pen up",0
        .byt MA_TYPE
        .word ty_lc
        .asc "Text screen",0
        .byt MA_TYPE
        .word ty_etxt
        .asc "Split screen",0
        .byt MA_TYPE
        .word ty_emix
mn_aid  .byt 1,10
        .asc "Help",0
        .asc "Primitives",0
        .byt MA_TYPE
        .word ty_aide


m_banner  .asc "LOGO CP/A - type HELP",13,10,0
m_prompt  .asc "? ",0
m_prompt2 .asc "> ",0
m_defined .asc " defined.",13,10,0
m_saved   .asc "Saved.",13,10,0
m_loaded  .asc "Loaded.",13,10,0
m_aide    .asc "FD BK RT LT n  PU PD PE PX",13,10
          .asc "HT ST CS CLEAN HOME",13,10
          .asc "TS SS  CT  TYPE x",13,10
          .asc "SETCURSOR c l CURSOR CELL c l",13,10
          .asc "SETH n  SETXY x y  WAIT n",13,10
          .asc "DOT x y  LINE RECTANGLE FILLRECT",13,10
          .asc "  x y x y  CIRCLE r  LABEL x",13,10
          .asc "SETCOLOR v  NOTE v n vol d (37 = C)",13,10
          .asc "SILENCE  TONE v p vol d",13,10
          .asc "NOISE v p vol d  ENVELOPE f p",13,10
          .asc "MIX v sound noise  TOGETHER [..]",13,10
          .asc "WAITSOUND v  PLAYING? v",13,10
          .asc "REPEAT n [..]  IF c [..] [..]  STOP",13,10
          .asc "TO NAME :A ... END  MAKE ",$22,"X n",13,10
          .asc "PRINT n/",$22,"word/[..]  RANDOM HEADING",13,10
          .asc "XCOR YCOR  + - * / ( ) = < >",13,10
          .asc "READLIST READWORD READCHAR KEY? KEY",13,10
          .asc "ASCII x  CHAR n  SETCELL c l n",13,10
          .asc "INT ROUND ABS  QUOTIENT REMAINDER",13,10
          .asc "Decimals: 3.14  1.5E-7  7 / 2",13,10
          .asc "SQRT SIN COS ARCTAN LN EXP",13,10
          .asc "WORD SENTENCE LIST FIRST LAST",13,10
          .asc "BUTFIRST BUTLAST ITEM",13,10
          .asc "COUNT EMPTY? WORD? NUMBER? LIST?",13,10
          .asc "MEMBER?  RUN [..]  OUTPUT x",13,10
          .asc "SAVE/LOAD/EDIT ",$22,"NAME  POTS",13,10
          .asc "SAVEPIC/LOADPIC ",$22,"NAME",13,10
          .asc "PO/ERASE ",$22,"NAME  ERALL",13,10
          .asc "ESC interrupts  BYE",13,10,0
e_what    .asc "What to do with this ?",0
e_unknown .asc "I don't know how to",0
e_value   .asc "Not enough inputs to",0
e_novar   .asc "No value for",0
e_div     .asc "Division by zero",0
e_notnum  .asc "A number is needed",0
e_big     .asc "Number too big",0
e_dom     .asc "Impossible calculation",0
e_empty   .asc "Empty word or list",0
e_word    .asc "A word is needed",0
e_list    .asc "A list [ ] is needed after",0
e_bracket .asc "Missing ] after",0
e_deep    .asc "Too many levels",0
e_mem     .asc "Memory full",0
e_esc     .asc "Interrupted",0
e_quote   .asc "A name with ",$22," is needed after",0
e_inload  .asc "Not allowed during LOAD :",0
e_pour    .asc "TO only at the start of a line",0
e_name    .asc "A name is needed after TO",0
e_disk    .asc "Disk error",0
e_nofile  .asc "File not found",0
e_long    .asc "Line over 126 chars : L ",0
e_noret   .asc "No output from",0
e_unused  .asc "What to do with the output of",0
e_rtop    .asc "OUTPUT only in a procedure",0
e_text    .asc "Not on the text screen :",0
e_range   .asc "Value out of range :",0
m_lost    .asc "State in LOGO.$$$ lost",13,10,0
