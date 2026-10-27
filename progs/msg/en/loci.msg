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
m_long  .asc "Path too long",13,10,0
m_found .asc "Stick found in ",0
m_absent .asc "Stick missing : ",0
m_nfw   .asc "Not found : ",0
m_many  .asc "Several files : be more precise",13,10,0
m_dots  .asc "...",13,10,0
m_int   .asc "LOCI memory",0
m_intsz .asc "15 MB",0
UNIT_B  = "B"
