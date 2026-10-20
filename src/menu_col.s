; =====================================================================
;  menu_col.s — encres des menus déroulants selon le papier, rangées
;  dans la page $FF00 (données seulement ; lues par draw_item, menu.s)
;
;  Un menu déroulant est en vidéo inverse : son fond est la couleur
;  complémentaire du papier (7 - papier) et son texte la complémentaire de
;  l'encre de l'attribut. Pour afficher l'encre e, l'attribut vaut donc
;  $80 + 7 - e. Un octet par papier (0 noir ... 7 blanc) : bits 0-2 =
;  7 - encre d'un article, bits 4-6 = 7 - encre de l'article sélectionné.
;
;  papier   menu     article  sélection
;  noir     blanc    magenta  bleu
;  rouge    cyan     magenta  bleu
;  vert     magenta  jaune    cyan
;  jaune    bleu     jaune    cyan
;  bleu     jaune    bleu     rouge
;  magenta  vert     bleu     rouge
;  cyan     rouge    jaune    cyan
;  blanc    noir     jaune    cyan
; =====================================================================
m_colors .byt $32,$32,$14,$14,$63,$63,$14,$14
