; vsync.msg : messages de VSYNC.COM en anglais (le français est dans
;   progs/msg/fr/vsync.msg, mêmes étiquettes). Inclus par progs/vsync.s.
texts   .byt 2,2
        .asc "VSYNC : screen timing",0
        .byt 4,2
        .asc "The middle text is only visible at",0
        .byt 5,2
        .asc "one precise moment of the scan.",0
        .byt 7,2
        .asc "Left/right arrows : 1 line",0
        .byt 8,2
        .asc "Up/down arrows    : 8 lines",0
        .byt 10,2
        .asc "Middle text whole and still :",0
        .byt 11,2
        .asc "RETURN keeps it (ESC cancels).",0
        .byt ROW,8
        .asc "**** SCREEN SET ****",0
        .byt 17,2
        .asc "Setting kept until the next",0
        .byt 18,2
        .asc "boot (animations without tearing).",0
        .byt 0

m_ok    .asc "Screen set.",13,10,"$"
m_esc   .asc "Setting cancelled.",13,10,"$"
