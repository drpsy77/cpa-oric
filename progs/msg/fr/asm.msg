; asm.msg : messages d'ASM.COM (français) ; la traduction anglaise est dans
; progs/msg/en/asm.msg, mêmes étiquettes. Inclus par progs/asm.s.
; e_* : messages d'erreur, dans l'ordre de err_tab (asm.s).
e_syn     .asc "Syntaxe",0
e_undef   .asc "Symbole inconnu",0
e_dup     .asc "Symbole deja defini",0
e_mode    .asc "Mode d'adressage impossible",0
e_range   .asc "Valeur trop grande",0
e_branch  .asc "Branchement trop loin",0
e_mnem    .asc "Instruction inconnue",0
e_dir     .asc "Directive inconnue",0
e_p1      .asc "Valeur inconnue a ce stade",0
e_incnf   .asc "Fichier inclus introuvable",0
e_incnest .asc "Un seul niveau d'inclusion",0
e_block   .asc "Blocs .( .) mal appaires",0
e_div     .asc "Division par zero",0
e_phase   .asc "Erreur de phase",0
e_org     .asc "Adresse",0
e_fwd     .asc "Reference en avant trop complexe",0
e_big     .asc "Code trop gros",0

m_usage   .asc "Usage : ASM NOM [/S] [/E]",13,10
          .asc " NOM.ASM -> NOM.COM ; /S : NOM.SYM",13,10
          .asc " /E : efface NOM.ASM si tout va bien",13,10,0
m_banner  .asc "ASM CP/A 1.0",13,10,0
m_nosrc   .asc "Source introuvable",13,10,0
m_pass    .asc "Passe ",0
m_big     .asc "Programme trop gros pour la memoire",13,10,0
m_errs    .asc " erreur(s) : rien n'est ecrit.",13,10,0
m_empty   .asc "Aucun code produit.",13,10,0
m_com     .asc ".COM ",0
m_comma   .asc " : ",0
m_bytes   .asc " octets",13,10,0
m_syms    .asc " symboles",0
m_symf    .asc " (.SYM)",0
m_dfull   .asc "Disque plein",13,10,0
m_esc     .asc "Interrompu",13,10,0
m_colon   .asc " : ",0
m_symfull .asc "Table des symboles pleine",13,10,0
