CP/A 0.9 - AIDE-MEMOIRE
-----------------------
afn           | nom, jokers * et ?
fic           | nom de fichier
adr bb        | hexa : 0500 A9
[...]         | facultatif

TOUCHES
-------
FUNCT         | menus deroulants
CTRL-T        | majuscules oui/non
<- ->         | deplace dans la ligne
              |   (on tape en
              |   insertion)
haut bas      | lignes deja tapees
              |   (historique)
ESC           | complete un nom de
              |   fichier ; 2 fois :
              |   les noms possibles
DEL ^D        | efface a gauche /
              |   sous
^A ^E         | debut / fin de ligne
CTRL-X        | efface la ligne
CTRL-C        | redemarrage a chaud
RESET         | retour au prompt

COMMANDES
---------
HELP [sujet]  | aide (HELP.COM)
VER           | version
CLS           | efface l'ecran
DIR [afn]     | liste des fichiers
DIRS [afn]    | idem, fichiers SYS
              |   compris
TYPE fic      | affiche un texte
ERA afn       | efface des fichiers
REN nouv=anc  | renomme
SAVE n fic    | sauve n pages de 0500
PUT fic cmd [param]
              | lance cmd, copie sa
              |   sortie dans fic
DO fic [p1..p9]
              | lance FIC.BAT ($1..$9
              |   = parametres, ESC
              |   arrete)
ECHO texte    | affiche le texte
PAUSE [texte] | attend une touche
SPLIT         | image + 10 lignes
TEXT          | texte seul
GCLS          | efface l'image
PEN m         | 0 efface 1 trace 2
              |   inv.
PLOT x y      | point (x 0-239, y
              |   0-127)
LINE x1 y1 x2 y2
              | ligne
BOX x1 y1 x2 y2
              | rectangle
FBOX x1 y1 x2 y2
              | rectangle plein
CIRCLE x y r  | cercle
GTEXT col y texte
              | texte dans l'image
              |   (col 0-39)
ATTR col y1 y2 v
              | attribut : encre 0-7,
              |   papier 16-23
POINT x y     | affiche 1 si allume
GSAVE fic     | sauve l'image (.IMG)
GLOAD fic     | charge l'image
NOM [param]   | lance NOM.COM

PROGRAMMES
----------
EDIT [fic]    | editeur de texte
HEX fic       | editeur hexadecimal
SET afn [opt] | attributs : RO RW SYS
              |   DIR (sans opt : les
              |   affiche)
LOGO          | Logo et sa tortue
ASM nom       | NOM.ASM -> NOM.COM et
              |   NOM.SYM
DEBUG nom [param]
              | debogueur
COPY src dst  | copie un fichier
STAT [afn]    | taille : enreg.,
              |   blocs de 2 Ko,
              |   octets ; seul :
              |   place libre
MEM           | carte de la memoire
POKE adr bb.. | ecrit en memoire
              |   (code a lancer :
              |   0600 et +)
GO adr [param]
              | lance le code (RTS =
              |   retour)
GTEST         | demo graphique
HELLO [param] | exemple de .COM

EDIT
----
fleches       | deplacement
^A ^E         | debut / fin de ligne
^R ^C         | page prec. / suiv.
^Q ^Z         | debut / fin du texte
DEL ^D        | efface avant / sous
^Y            | efface le paragraphe
^O            | insere / remplace
^F ^G         | cherche / suivant
^S            | enregistre
FUNCT         | menus Fichier (dont
              |   Inserer), Edition,
              |   Chercher, Options

HEX
---
fleches RET   | deplacement
^R ^C         | page prec. / suiv.
^Q ^Z         | debut / fin
^A            | aller a l'adresse
^F ^G         | cherche texte ou
              |   #hexa / suivant
^O            | mode HEX / ASCII
^S            | enregistre
ESC           | quitte

LOGO
----
AV n  RE n    | avance / recule
DR n  GA n    | droite / gauche
LC  BC        | leve / baisse stylo
CT  MT        | cache / montre
VE  ORIGINE   | vide ecran / centre
REPETE n [..] | repete la liste
SI c [..] [..]
              | condition
POUR NOM :A ... FIN
              | definit une procedure
EC x          | ecrit
SAUVE "N      | procedures -> N.LOG
CHARGE "N     | charge N.LOG
SAUVEIMAGE "N | dessin -> N.IMG
CHARGEIMAGE "N
              | charge N.IMG
LISCAR        | attend une touche,
              |   rend son code
TOUCHE?       | 1 si une touche
              |   attend, 0 sinon
NOTE n d      | joue la note n (37 =
              |   do) pendant d/50 s
BRUIT d       | bruit pendant d/50 s
SILENCE       | coupe le son
AIDE          | liste complete
QUITTE        | retour a CP/A

ASM : SYNTAXE
-------------
etiq          | en colonne 1
NOM = expr    | constante
*= adr        | adresse (0500)
.byt .asc     | octets, "chaines"
.word         | mots 16 bits
.dsb n[,v]    | n octets
.(  .)        | bloc, etiquettes
              |   locales
#include "f"  | inclusion
$ % "c" *     | hexa, binaire, car.,
              |   ici
< >           | octet bas / haut

MEMOIRE
-------
0000-00DF     | page zero libre
0200 / 0203   | WBOOT / BDOS
020C          | haut de la TPA (mot)
0400-04FF     | page de base, DMA
              |   0480
0500-B3FF     | programmes (TPA)
A000-B3FF     | image en mode SPLIT
              |   (TPA jusqu'a 9FFF)
B400-BB7F     | jeux de caracteres
BB80-BFDF     | ecran texte
C000-FFFF     | CP/A (RAM overlay)
DEBUG         | se place en 8400-9FFF
MEM           | cette carte, selon le
              |   mode

DEBUG
-----
R [reg=v]     | registres (A X Y S PC
              |   P, N V D I Z C)
L [adr]       | desassemble
D [adr]       | memoire
M adr bb..    | modifie la memoire
G [adr]       | execute
T [n]         | pas a pas
P [n]         | pas a pas, JSR d'un
              |   coup
B [adr]       | pose / liste les
              |   points d'arret
B- [adr]      | enleve (tous)
? expr        | valeur et symbole
H  Q          | aide / quitte
adr           | hexa, #decimal, nom+n
