; grxasm.msg : messages de GRXASM.COM et commentaires du .ASM produit, en
;   français ; la traduction anglaise est dans progs/msg/en/grxasm.msg, mêmes
;   étiquettes. Inclus par progs/grxasm.s ; les lignes de code produites
;   restent dans grxasm.s (h_code, s_gcode).
h_head2 .asc ".ASM : traduit de ",0
h_head2b .asc ".GRX par GRXASM",13,10
        .asc "; ASM ",0
h_head3 .asc " donne le .COM (CPA.INC sur le meme",13,10
        .asc "; lecteur ; les routines utiles des",13,10
        .asc "; bibliotheques sont recopiees a la fin)",13,10,0
h_tail1 .asc "; boucles : compte, ou arrivee, pas et variable",13,10,0
s_ginit .asc "; tableaux fixes : reserves au lancement",13,10,0
m_done  .asc ".ASM ecrit : ASM ",0
m_nodim .asc "tableau non dimensionne",0
m_noinc .asc " absente (bibliotheque)",0
m_names .asc "Trop de noms (bibliotheques)",0
m_use   .asc "GRXASM NOM [/C] [p1..p9] : traduit",13,10
        .asc "NOM.GRX en NOM.ASM (pour ASM) ;",13,10
        .asc "/C : puis ASM, NOM.COM seul",13,10,"$"
