; asm.msg : messages d'ASM.COM en anglais (le français est dans
;   progs/msg/fr/asm.msg, mêmes étiquettes). Inclus par progs/asm.s.
; e_* : messages d'erreur, dans l'ordre de err_tab (asm.s).
e_syn     .asc "Syntax",0
e_undef   .asc "Unknown symbol",0
e_dup     .asc "Duplicate symbol",0
e_mode    .asc "Bad addressing mode",0
e_range   .asc "Value too large",0
e_branch  .asc "Branch too far",0
e_mnem    .asc "Unknown instruction",0
e_dir     .asc "Unknown directive",0
e_p1      .asc "Value not yet known",0
e_incnf   .asc "Include file not found",0
e_incnest .asc "Only one include level",0
e_block   .asc "Unmatched .( .) blocks",0
e_div     .asc "Division by zero",0
e_phase   .asc "Phase error",0
e_org     .asc "Address",0
e_fwd     .asc "Forward reference too complex",0
e_big     .asc "Code too big",0

m_usage   .asc "Usage : ASM NAME [/S] [/E]",13,10
          .asc " NAME.ASM -> NAME.COM ; /S : NAME.SYM",13,10
          .asc " /E : erases NAME.ASM if all is well",13,10,0
m_banner  .asc "ASM CP/A 1.0",13,10,0
m_nosrc   .asc "Source not found",13,10,0
m_pass    .asc "Pass ",0
m_big     .asc "Program too big for memory",13,10,0
m_errs    .asc " error(s): nothing written.",13,10,0
m_empty   .asc "No code produced.",13,10,0
m_com     .asc ".COM ",0
m_comma   .asc " : ",0
m_bytes   .asc " bytes",13,10,0
m_syms    .asc " symbols",0
m_symf    .asc " (.SYM)",0
m_dfull   .asc "Disk full",13,10,0
m_esc     .asc "Interrupted",13,10,0
m_colon   .asc " : ",0
m_symfull .asc "Symbol table full",13,10,0
