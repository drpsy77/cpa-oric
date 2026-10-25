; grxasm.msg : messages de GRXASM.COM et commentaires du .ASM produit, en
;   anglais (le français est dans progs/msg/fr/grxasm.msg, mêmes étiquettes).
;   Inclus par progs/grxasm.s ; les lignes de code produites restent dans
;   grxasm.s (h_code, s_gcode).
h_head2 .asc ".ASM: translated from ",0
h_head2b .asc ".GRX by GRXASM",13,10
        .asc "; ASM ",0
h_head3 .asc " gives the .COM (CPA.INC on the same",13,10
        .asc "; drive; the useful routines of the",13,10
        .asc "; libraries are copied at the end)",13,10,0
h_tail1 .asc "; loops: count, or end, step and variable",13,10,0
s_ginit .asc "; fixed arrays: reserved at start",13,10,0
m_done  .asc ".ASM written: ASM ",0
m_nodim .asc "array not dimensioned",0
m_noinc .asc " missing (library)",0
m_names .asc "Too many names (libraries)",0
m_use   .asc "GRXASM NAME [/C|/O] [p1..p9]: turns",13,10
        .asc "NAME.GRX into NAME.ASM (for ASM);",13,10
        .asc "/C: then ASM, NAME.COM only",13,10
        .asc "/O: NAME.TAP for a bare Oric",13,10,"$"
; /O (bare Oric)
h_head3o .asc " /T gives the .TAP for a bare",13,10
        .asc "; Oric (CLOAD",34,34,"; the useful routines",13,10
        .asc "; of the libraries, ORIC.INC included,",13,10
        .asc "; are copied at the end; O_PLACE over",13,10
        .asc "; 255: too big for the Oric",13,10,0
m_lim   .asc "value out of range",0
m_mem   .asc "memory full",0
m_noo   .asc "not with /O",0
m_nfil  .asc "too many files (/O)",0
m_nofil .asc " missing: not included",0
