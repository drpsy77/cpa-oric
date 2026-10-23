; logotr.msg : messages de LOGOTR.COM en français ; la traduction anglaise est
;   dans progs/msg/en/logotr.msg, mêmes étiquettes. Inclus par progs/logotr.s.
D_LANG  = 0             ; sans option : traduit vers le français (/FR)
m_use   .asc "LOGOTR NOM [DEST] [/EN|/FR] : traduit",13,10
        .asc "NOM.LOG vers l'anglais (/EN) ou le",13,10
        .asc "francais (/FR, par defaut) ; sans",13,10
        .asc "DEST : NOM remplace, NOM.BAK garde.",13,10
        .asc "Seules les primitives sont traduites.",13,10,0
m_nf    .asc "Fichier introuvable",13,10,0
m_big   .asc "Fichier trop gros",13,10,0
m_dir   .asc "Repertoire plein",13,10,0
m_full  .asc "Disque plein : rien n'est change",13,10,0
m_ro    .asc "Fichier protege : traduction dans",13,10
        .asc "NOM.$$$",13,10,0
m_line  .asc "L ",0
m_sep   .asc " : ",0
m_crlf  .asc 13,10,0
m_wdata .asc "liste de donnees ? ",0
m_wname .asc "nom de primitive : ",0
m_ntr   .asc " mots traduits, ",0
m_nwarn .asc " avertissement(s)",13,10,0
m_done  .asc "Ecrit : ",0
