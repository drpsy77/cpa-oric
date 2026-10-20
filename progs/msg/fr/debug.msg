; debug.msg : messages de DEBUG.COM (français) ; la traduction anglaise est
; dans progs/msg/en/debug.msg, mêmes étiquettes. Inclus par progs/debug.s.
; Les lettres des commandes (R L D M G T P B ? H Q) sont les mêmes dans les
; deux langues.
m_usage   .asc "Usage : DEBUG NOM [parametres]",13,10,0
m_banner  .asc "DEBUG CP/A 1.0 - H pour l'aide",13,10,0
m_noprog  .asc "Programme introuvable",13,10,0
m_big     .asc "Programme trop gros",13,10,0
m_nosym   .asc "Symboles ignores : pas de place",13,10,0
m_com     .asc ".COM ",0
m_nsym    .asc " symboles en ",0
m_end     .asc "Programme termine (G relance en 0500)",13,10,0
m_nmi     .asc "*RESET*",13,10,0
m_brk     .asc "BRK dans le programme",13,10,0
m_bp      .asc "Point d'arret ",0
m_badop   .asc "Opcode inconnu",13,10,0
m_brkop   .asc "BRK : utiliser G",13,10,0
m_free    .asc "Hors du programme : execution libre",13,10,0
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
m_what    .asc "? (H pour l'aide)",13,10,0
m_syntax  .asc "Syntaxe ?",13,10,0
m_nosymb  .asc "Symbole inconnu",13,10,0
m_bpfull  .asc "8 points d'arret au plus",13,10,0
m_nobp    .asc "Aucun point d'arret",13,10,0
m_eq      .asc " = ",0
m_help    .asc "R [reg=v]  registres (A X Y S PC,",13,10
          .asc "           indicateurs N V D I Z C)",13,10
          .asc "L [adr]    desassemble",13,10
          .asc "D [adr]    memoire",13,10
          .asc "M adr bb.. modifie la memoire",13,10
          .asc "G [adr]    execute",13,10
          .asc "T [n]      pas a pas",13,10
          .asc "P [n]      pas a pas, JSR d'un coup",13,10
          .asc "B [adr]    points d'arret, B- [adr]",13,10
          .asc "? expr     valeur (nom, $hex, #dec)",13,10
          .asc "Q          quitter",13,10
          .asc "RESET arrete le programme.",13,10
          .asc "Indic. : N negatif, V debordement,",13,10
          .asc "B BRK, D decimal, I IRQ masquees,",13,10
          .asc "Z zero, C retenue.",13,10,0
