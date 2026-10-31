; format.msg : messages de FORMAT.COM (français) ; la traduction anglaise est
; dans progs/msg/en/format.msg, mêmes étiquettes. Inclus par progs/format.s.
m_use   .asc "FORMAT X: [/Q] : formate X: (A a D)",13,10
        .asc "/Q : vide seulement le repertoire",13,10,0
m_ins   .asc "Inserez en A: la disquette a formater",13,10,0
m_all   .asc "Tout ",0
m_all2  .asc " sera efface. Suite (O/N) ? ",0
m_abort .asc "Abandon",13,10,0
m_sys   .asc "Remettez la disquette systeme en A:,",13,10
        .asc "puis une touche",13,10,0
m_unr   .asc "Disquette illisible : FORMAT sans /Q",13,10,0
m_werr  .asc "Erreur d'ecriture",13,10,0
m_qok   .asc "Repertoire vide",13,10,0
m_ok    .asc 13,10,"Formatage termine",13,10,0
m_int   .asc 13,10,"Interrompu : disquette a reformater",13,10,0
m_abs   .asc 13,10,"Lecteur ",0
m_abs2  .asc " absent ou vide",13,10,0
m_wp    .asc 13,10,"Disquette protegee en ecriture",13,10,0
m_inc   .asc 13,10,"Piste ecrite en partie seulement",13,10,0
m_verr  .asc 13,10,"Relecture : erreur secteur ",0
m_42    .asc "Image de 42 pistes ? Il en faut 80",13,10,0
m_trk   .asc "Piste ",0
m_face  .asc " face ",0
K_YES   = "O"           ; touche Oui
