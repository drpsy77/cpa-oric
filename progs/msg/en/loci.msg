; loci.msg : messages de loci_inc.s (EXPORT, IMPORT, USBDIR) en anglais (le français est dans
;   progs/msg/fr/loci.msg, mêmes étiquettes). Inclus par progs/loci_inc.s.
m_noloci .asc "No LOCI : USB stick out of reach",13,10,0
m_uerr  .asc "USB error ",0
e_code  .byt 35,36,37,38,39,42,43,44,45,130,0
e_msg   .word m_e_nousb,m_e_nf,m_e_nf,m_e_name,m_e_deny,m_e_wp
        .word m_e_nousb,m_e_nousb,m_e_nousb,m_e_nf
m_e_nf  .asc " : not found",0
m_e_name .asc " : bad name",0
m_e_deny .asc " : refused (stick full ?)",0
m_e_wp  .asc " : stick protected",0
m_e_nousb .asc " : no readable USB stick",0
