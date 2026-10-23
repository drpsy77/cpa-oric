; grxc.msg : messages communs à GRAPHER et GRXASM (progs/grxc_inc.s), en
;   anglais (le français est dans progs/msg/fr/grxc.msg, mêmes étiquettes).
;   Inclus par progs/grapher.s et progs/grxasm.s (une bibliothèque ne contient
;   pas de #include).
m_nogrx .asc "File not found",13,10,"$"
m_unk   .asc "unknown command",0
m_param .asc "parameters?",0
m_long  .asc "line over 126 chars",0
m_full  .asc "disk full",0
m_esc   .asc "Interrupted",0
m_big   .asc "File too big",0
m_expr  .asc "expression?",0
m_range .asc "value not in 0-255",0
m_var   .asc "variable? (A, AB or A1)",0
m_div   .asc "division by zero",0
m_deep  .asc "too many nested blocks",0
m_step  .asc "zero step",0
m_nofor .asc "NEXT without loop",0
m_open  .asc "block not closed",0
m_struct .asc "extra end of block",0
m_noret .asc "RETURN without CALL",0
m_nosub .asc "SUB not found",0
m_strc  .asc "string in a calculation",0
