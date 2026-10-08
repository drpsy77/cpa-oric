CP/A 0.9 - AIDE-MEMOIRE
-----------------------
afn           | nom, jokers * et ?
fic           | nom de fichier,
              |   lecteur facultatif
              |   (B:NOM.TXT)
adr bb        | hexa : 0500 A9
[...]         | facultatif

TOUCHES
-------
FUNCT         | menus deroulants
CTRL-T        | majuscules oui/non
              |   (voyant A ou a au
              |   bout de la barre)
<- ->         | deplace dans la ligne
              |   (on tape en
              |   insertion)
haut bas      | lignes deja tapees
              |   (historique)
ESC           | complete un nom de
              |   fichier (en debut
              |   de ligne : une
              |   commande) ; 2 fois
              |   : les noms
              |   possibles
DEL ^D        | efface a gauche /
              |   sous
^A ^E         | debut / fin de ligne
CTRL-X        | efface la ligne
CTRL-P        | imprimante oui/non
              |   (tout ce qui
              |   s'affiche ; voyant
              |   P ; aussi menu
              |   Systeme)
CTRL-C        | redemarrage a chaud
RESET         | retour au prompt

COMMANDES
---------
HELP [sujet]  | aide (HELP.COM)
VER           | version
CLS           | efface l'ecran
B:            | lecteur courant (A: a
              |   D:) ; aussi menu
              |   Systeme, Lecteur
              |   suivant ; un .COM
              |   absent est cherche
              |   sur A:
DIR [afn]     | liste des fichiers
DIRS [afn]    | idem, fichiers SYS
              |   compris
TYPE fic      | affiche un texte
ERA afn [/Q]  | efface, apres
              |   confirmation (/Q :
              |   sans question)
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
NOM [param]   | lance NOM.COM, sinon
              |   NOM.BAT

PROGRAMMES
----------
EDIT [fic]    | editeur de texte
HEX fic       | editeur hexadecimal
SET afn [opt] | attributs : RO RW SYS
              |   DIR (sans opt : les
              |   affiche)
LOGO [fic]    | Logo et sa tortue
              |   (charge fic.LOG)
ASM nom       | NOM.ASM -> NOM.COM et
              |   NOM.SYM
DEBUG nom [param]
              | debogueur
COPY src [dst]
              | copie, jokers admis :
              |   COPY *.COM B:, COPY
              |   *.TXT *.BAK, COPY
              |   B:*.LOG
FORMAT X: [/Q]
              | formate X: (A: : un
              |   seul lecteur) ; /Q
              |   : vide le
              |   repertoire
DISKCOPY s: d: [opt]
              | copie la disquette s:
              |   sur d: (A: A: : un
              |   seul lecteur) ; /T
              |   tout, /V relecture,
              |   /S systeme
              |   seulement (SYSGEN)
STAT [d:][afn]
              | taille : enreg.,
              |   blocs de 2 Ko,
              |   octets ; At : R
              |   protege, S systeme
              |   ; seul : place
              |   libre
XDO nom [param]
              | script appele par un
              |   script (lance par
              |   le CCP)
EXPORT fic [nom]
              | copie sur la cle USB
              |   du LOCI (HELP USB)
IMPORT nom [fic]
              | copie depuis la cle
              |   USB du LOCI
USBDIR [chemin]
              | fichiers de la cle
              |   USB du LOCI
MEM           | carte de la memoire
POKE adr bb.. | ecrit en memoire
              |   (code a lancer :
              |   0600 et +)
GO adr [param]
              | lance le code (RTS =
              |   retour)
GTEST         | demo graphique
HELLO [param] | exemple de .COM

USB : CLE DU LOCI
-----------------
EXPORT fic [nom]
              | fic -> cle (nom : par
              |   defaut fic,
              |   minuscules gardees)
IMPORT nom [fic]
              | cle -> fic (par
              |   defaut : nom coupe
              |   a 8.3 ; B: seul :
              |   sur B:)
/T            | (IMPORT) texte : LF
              |   seul -> CR LF
USBDIR [chemin]
              | liste (taille, <REP>
              |   : dossier)
1:/DOCS/X.TXT | chemin sur la cle ;
              |   sans 1: : la
              |   premiere cle
0:X.TXT       | memoire interne du
              |   LOCI
^Z            | retires a l'EXPORT,
              |   ajoutes a l'IMPORT
X.DSK         | EXPORT refuse (image
              |   disque)

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
^L            | insere un fichier au
              |   curseur
^P            | imprime le texte (ESC
              |   arrete)
FUNCT         | menus Fichier (dont
              |   Inserer, Imprimer),
              |   Edition, Chercher,
              |   Options
Retour        | (lance par EDITE de
              |   LOGO) enregistre et
              |   revient

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
AV n  RE n    | avance / recule (n
              |   decimal admis)
DR n  GA n    | droite / gauche
              |   (degres, 0.5 admis)
LC  BC        | leve / baisse stylo
CT  MT        | cache / montre
VE  ORIGINE   | vide ecran / centre
POINT x y     | un point (coordonnees
              |   de la tortue, qui
              |   ne bouge pas)
TRAIT x y x y | un trait ; RECTANGLE,
              |   PAVE (plein) :
              |   coins opposes
CERCLE r      | autour de la tortue
              |   (r 0-127)
ETIQUETTE x   | ecrit x dans l'image
              |   a la tortue
FIXECOULEUR v | encre 0-7 ou papier
              |   16-23 de l'image
ALLUME? x y   | 1 si le point est
              |   allume
ECRANTEXTE    | tout en texte
ECRANMIXTE    | retour a l'image
REPETE n [..] | repete la liste
SI c [..] [..]
              | condition
POUR NOM :A ... FIN
              | definit une procedure
RENDS x       | la procedure rend x
EC x          | ecrit
SAUVE "N      | procedures -> N.LOG
CHARGE "N     | charge N.LOG
EDITE "N      | N.LOG dans EDIT, puis
              |   Retour
SAUVEIMAGE "N | dessin -> N.IMG
CHARGEIMAGE "N
              | charge N.IMG
3.14  2E-7    | decimaux (9 chiffres)
              |   ; 7 / 2 = 3.5
ENT x  ARRONDI x
              | partie entiere /
              |   entier proche
RACINE x      | racine carree
SIN COS ARCTAN
              | en degres (SIN 30 =
              |   0.5)
LN x  EXP x   | logarithme /
              |   exponentielle
ABS x         | valeur absolue
QUOTIENT a b  | division entiere ;
              |   RESTE a b : reste
"MOT  [A B]   | mot, liste (DONNE "L
              |   [A B])
PR SP x       | premier / sauf le
              |   premier
DER SD x      | dernier / sauf le
              |   dernier
ITEM n x      | n-ieme element
COMPTE x      | nombre d'elements
MOT a b       | colle deux mots
PH a b  LISTE a b
              | phrase / liste de
              |   deux
VIDE? MOT? LISTE?
              | 1 ou 0 ; aussi
              |   NOMBRE? MEMBRE? a b
EXEC [..]     | execute une liste
LISLISTE      | lit une ligne ->
              |   liste (LL)
LISMOT        | lit une ligne -> mot
LISCAR        | attend une touche ->
              |   caractere
ASCII x  CAR n
              | code d'un caractere /
              |   caractere
TOUCHE?       | 1 si une touche
              |   attend, 0 sinon
SON v n vol d | note n (37 = do, 0 =
              |   rien) sur la voix v
              |   (0-2), volume 0-15
              |   (16 = enveloppe),
              |   d/50 s (0 : sans
              |   fin)
SONF v p vol d
              | son de periode p
              |   (0-4095)
BRUITV v p vol d
              | bruit de periode p
              |   (0-31)
ENVELOPPE f p | forme 0-15, periode
              |   0-65535
MELANGE v s b | son et bruit de la
              |   voix (1 / 0)
ENSEMBLE [..] | les voix de la liste
              |   partent ensemble
ATTENDSSON v  | attend la fin (255 :
              |   toutes)
JOUE? v       | 1 si la voix joue
              |   encore
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
