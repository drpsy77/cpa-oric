; vsync.msg : messages de VSYNC.COM (français) ; la traduction anglaise est
; dans progs/msg/en/vsync.msg, mêmes étiquettes. Inclus par progs/vsync.s.
texts   .byt 2,2
        .asc "VSYNC : calage de l'ecran",0
        .byt 4,2
        .asc "Le texte du milieu n'est visible qu'a",0
        .byt 5,2
        .asc "un instant precis du balayage.",0
        .byt 7,2
        .asc "Fleches gauche/droite : 1 ligne",0
        .byt 8,2
        .asc "Fleches haut/bas      : 8 lignes",0
        .byt 10,2
        .asc "Texte du milieu entier et immobile :",0
        .byt 11,2
        .asc "RETURN garde le reglage (ESC annule).",0
        .byt ROW,8
        .asc "**** ECRAN CALE ****",0
        .byt 17,2
        .asc "Reglage garde jusqu'au prochain",0
        .byt 18,2
        .asc "demarrage (animations sans dechirure).",0
        .byt 0

m_ok    .asc "Ecran cale.",13,10,"$"
m_esc   .asc "Reglage annule.",13,10,"$"
