; import.msg : messages de IMPORT.COM (français) ; la traduction anglaise est
; dans progs/msg/en/import.msg, mêmes étiquettes. Inclus par progs/import.s.
m_use   .asc "IMPORT nom [fic] [/T] : copie un",13,10
        .asc "fichier de la cle USB du LOCI",13,10
        .asc "/T : texte, LF seul -> CR LF,",13,10
        .asc "     TAB -> espace",13,10,0
m_name  .asc "Nom CP/A invalide : IMPORT nom fic",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_ro    .asc "Fichier protege (SET fic RW)",13,10,0
m_full  .asc "Disque plein",13,10,0
m_sep   .asc " : ",0
m_ok    .asc " octets",13,10,0
