; PAPER.BAT c : papier (0 noir ... 7 blanc) : colonne 0 de chaque ligne = $10 + couleur
; aucun controle : la couleur est collee au chiffre ($1 = 4 -> 14)
; pas de boucle dans un script : une ligne par ligne d'ecran ($BB80 + n x $28)
POKE 027B 0$1
POKE BBA8 1$1
POKE BBD0 1$1
POKE BBF8 1$1
POKE BC20 1$1
POKE BC48 1$1
POKE BC70 1$1
POKE BC98 1$1
POKE BCC0 1$1
POKE BCE8 1$1
POKE BD10 1$1
POKE BD38 1$1
POKE BD60 1$1
POKE BD88 1$1
POKE BDB0 1$1
POKE BDD8 1$1
POKE BE00 1$1
POKE BE28 1$1
POKE BE50 1$1
POKE BE78 1$1
POKE BEA0 1$1
POKE BEC8 1$1
POKE BEF0 1$1
POKE BF18 1$1
POKE BF40 1$1
POKE BF68 1$1
POKE BF90 1$1
POKE BFB8 1$1
