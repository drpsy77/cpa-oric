; edsprite.msg : menus et messages d'EDSPRITE.COM en anglais (le français est
;   dans progs/msg/fr/edsprite.msg, mêmes étiquettes). Inclus par
;   progs/edsprite.s.
mn_fic  .byt 5,15
        .asc "File",0
        .asc "New          ^N",0
        .byt MA_TYPE
        .word c_81
        .asc "Open...      ^O",0
        .byt MA_TYPE
        .word c_82
        .asc "Save         ^S",0
        .byt MA_TYPE
        .word c_83
        .asc "Save as...",0
        .byt MA_TYPE
        .word c_84
        .asc "Quit         ^Q",0
        .byt MA_TYPE
        .word c_85

mn_edi  .byt 5,11
        .asc "Edit",0
        .asc "Undo     ^Z",0
        .byt MA_TYPE
        .word c_86
        .asc "Cut      ^X",0
        .byt MA_TYPE
        .word c_87
        .asc "Copy     ^C",0
        .byt MA_TYPE
        .word c_88
        .asc "Paste    ^V",0
        .byt MA_TYPE
        .word c_89
        .asc "Clear",0
        .byt MA_TYPE
        .word c_8a

mn_spr  .byt 9,12
        .asc "Sprite",0
        .asc "New...",0
        .byt MA_TYPE
        .word c_8b
        .asc "Duplicate",0
        .byt MA_TYPE
        .word c_8c
        .asc "Delete",0
        .byt MA_TYPE
        .word c_8d
        .asc "Rename...",0
        .byt MA_TYPE
        .word c_8e
        .asc "Size...",0
        .byt MA_TYPE
        .word c_8f
        .asc "Move down",0
        .byt MA_TYPE
        .word c_90
        .asc "Move up",0
        .byt MA_TYPE
        .word c_91
        .asc "Select   ^I",0
        .byt MA_TYPE
        .word c_92
        .asc "Draw     ^I",0
        .byt MA_TYPE
        .word c_93

mn_des  .byt 11,17
        .asc "Draw",0
        .asc "Invert",0
        .byt MA_TYPE
        .word c_94
        .asc "Flip horizontal",0
        .byt MA_TYPE
        .word c_95
        .asc "Flip vertical",0
        .byt MA_TYPE
        .word c_96
        .asc "Quarter turn",0
        .byt MA_TYPE
        .word c_97
        .asc "Shift left",0
        .byt MA_TYPE
        .word c_98
        .asc "Shift right",0
        .byt MA_TYPE
        .word c_99
        .asc "Shift up",0
        .byt MA_TYPE
        .word c_9a
        .asc "Shift down",0
        .byt MA_TYPE
        .word c_9b
        .asc "Mask = drawing",0
        .byt MA_TYPE
        .word c_9c
        .asc "Outline",0
        .byt MA_TYPE
        .word c_a1
        .asc "From the font...",0
        .byt MA_TYPE
        .word c_9d

mn_vue  .byt 3,12
        .asc "View",0
        .asc "Hex codes  ^H",0
        .byt MA_TYPE
        .word c_9e
        .asc "Backdrop",0
        .byt MA_TYPE
        .word c_9f
        .asc "Animate",0
        .byt MA_TYPE
        .word c_a0

K_YES   = "Y"           ; Yes key
K_SPR   = "S"           ; new file: sprites
K_TIL   = "T"           ;   or tiles

m_bad     .asc "Not a .SPR file",13,10,"$"
m_bad2    .asc "Not a .SPR file: new one",0
m_new     .asc "New file",0
m_noname  .asc "(no name)",0
m_real    .asc "Real",0
m_codes   .asc "Codes",0
m_zsel    .asc "List: arrows, ^I or RETURN",0
m_car     .asc "char ",0
m_pen     .asc "pen",0
m_nomask  .asc "No mask (tiles)",0
m_noundo  .asc "Nothing to undo",0
m_mem     .asc "Memory full",0
m_full    .asc "255 sprites at most",0
m_copied  .asc "Copied",0
m_noclip  .asc "Clipboard empty",0
m_last    .asc "Last sprite: kept",0
m_rot     .asc "Quarter turn: 4x3 sprite only",0
m_badnum  .asc "Code from 32 to 127",0
m_badsize .asc "Size: 1 to 4 x 1 to 4 (2X2)",0
m_badname .asc "Name: 1 to 4 letters or digits",0
m_badfn   .asc "Bad file name",0
m_dirfull .asc "Directory full: not saved",0
m_dfull   .asc "Disk full: not saved",0
m_ro      .asc "File read-only (R/O)",0
m_renf    .asc "Error: file left in NAME.$$$",0
m_saved   .asc "Saved",0
q_del     .asc "Delete this sprite (Y/N)?",0
q_code    .asc "First code (32-127): ",0
q_size    .asc "Size (e.g. 2X2): ",0
q_name    .asc "Name (4 chars): ",0
q_genre   .asc "Sprites or Tiles (S/T)?",0
q_lose    .asc "Discard the changes (Y/N)?",0
q_open    .asc "Open: ",0
q_saveas  .asc "Save as: ",0
q_repl    .asc "Replace this file (Y/N)?",0
q_quit    .asc "File changed. Quit (Y/N)?",0
s_plein   .asc "solid",0
s_masque  .asc "mask",0
s_transp  .asc "clear",0
s_vide    .asc "empty",0
d_vide    .asc "Backdrop: none",0
d_damier  .asc "Backdrop: checks",0
d_brique  .asc "Backdrop: bricks",0
d_herbe   .asc "Backdrop: grass",0
g_spr     .asc "sprites",0
g_til     .asc "tiles",0
h_sel     .asc "S:sprite  M:mask  RETURN:draw",0
h_ed      .asc "SPC:solid  M:mask  P:pen  ^I:list",0
h_ed1     .asc "SPC:solid/empty  P:pen  ^I:list",0
hints     .word h_sel, h_ed, h_ed1
snames    .word s_plein, s_masque, s_transp
snames1   .word s_plein, s_vide, s_vide
dnames    .word d_vide, d_damier, d_brique, d_herbe
gnames    .word g_spr, g_til
