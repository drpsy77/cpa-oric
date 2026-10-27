; loci.msg : messages de loci_inc.s (français) ; la traduction anglaise est
; dans progs/msg/en/loci.msg, mêmes étiquettes. Inclus par progs/loci_inc.s.
m_noloci .asc "LOCI absent : cle USB inaccessible",13,10,0
m_uerr  .asc "Erreur USB ",0
e_code  .byt 35,36,37,38,39,42,43,44,45,130,0
e_msg   .word m_e_nousb,m_e_nf,m_e_nf,m_e_name,m_e_deny,m_e_wp
        .word m_e_nousb,m_e_nousb,m_e_nousb,m_e_nf
m_e_nf  .asc " : introuvable",0
m_e_name .asc " : nom invalide",0
m_e_deny .asc " : refus (cle pleine ?)",0
m_e_wp  .asc " : cle protegee",0
m_e_nousb .asc " : pas de cle USB lisible",0
m_long  .asc "Chemin trop long",13,10,0
m_found .asc "Cle trouvee en ",0
m_absent .asc "Cle absente : ",0
m_nfw   .asc "Introuvable : ",0
m_many  .asc "Plusieurs fichiers : preciser",13,10,0
m_dots  .asc "...",13,10,0
m_int   .asc "memoire du LOCI",0
m_intsz .asc "15 Mo",0
UNIT_B  = "o"           ; GB -> Go, MB -> Mo
