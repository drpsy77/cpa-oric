; debug.msg : messages de DEBUG.COM en anglais (le français est dans
;   progs/msg/fr/debug.msg, mêmes étiquettes). Inclus par progs/debug.s.
; Les lettres des commandes (R L D M G T P B ? H Q) sont les mêmes dans les
; deux langues.
m_usage   .asc "Usage : DEBUG NAME [parameters]",13,10,0
m_banner  .asc "DEBUG CP/A 1.0 - H for help",13,10,0
m_noprog  .asc "Program not found",13,10,0
m_big     .asc "Program too big",13,10,0
m_nosym   .asc "Symbols skipped: no room",13,10,0
m_com     .asc ".COM ",0
m_nsym    .asc " symbols at ",0
m_end     .asc "Program ended (G restarts at 0500).",13,10,0
m_nmi     .asc "*RESET*",13,10,0
m_brk     .asc "BRK in the program",13,10,0
m_bp      .asc "Breakpoint ",0
m_badop   .asc "Unknown opcode",13,10,0
m_brkop   .asc "BRK : use G",13,10,0
m_free    .asc "Outside the program: free run",13,10,0
m_pc      .asc "PC=",0
m_a       .asc " A=",0
m_x       .asc " X=",0
m_y       .asc " Y=",0
m_s       .asc " S=",0
m_p       .asc "P=",0
m_flags   .asc "  N V - B D I Z C",13,10,0
m_pad     .asc "      ",0
m_3sp     .asc "   ",0
m_byt     .asc ".BYT ",0
m_cx      .asc ",X",0
m_cy      .asc ",Y",0
m_what    .asc "? (H for help)",13,10,0
m_syntax  .asc "Syntax ?",13,10,0
m_nosymb  .asc "Unknown symbol",13,10,0
m_bpfull  .asc "8 breakpoints at most",13,10,0
m_nobp    .asc "No breakpoint",13,10,0
m_eq      .asc " = ",0
m_help    .asc "R [reg=v]  registers (A X Y S PC,",13,10
          .asc "           flags N V D I Z C)",13,10
          .asc "L [adr]    disassemble",13,10
          .asc "D [adr]    memory",13,10
          .asc "M adr bb.. change memory",13,10
          .asc "G [adr]    run",13,10
          .asc "T [n]      single step",13,10
          .asc "P [n]      single step, JSR at once",13,10
          .asc "B [adr]    breakpoints, B- [adr]",13,10
          .asc "? expr     value (name, $hex, #dec)",13,10
          .asc "Q          quit",13,10
          .asc "RESET stops the program.",13,10
          .asc "Flags : N negative, V overflow,",13,10
          .asc "B BRK, D decimal, I IRQ masked,",13,10
          .asc "Z zero, C carry.",13,10,0
