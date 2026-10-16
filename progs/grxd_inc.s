;  GRXD_INC.S — GRAPHER et GRXASM : constantes et page zéro communes
;  (inclus par progs/grapher.s et progs/grxasm.s, jamais assemblé seul)

LMAX    = 126           ; longueur d'une ligne du fichier
CR      = 13
LF      = 10
NPAR    = 9
NCS     = 16            ; profondeur de la pile de contrôle
NVS     = 24            ; pile des valeurs de l'évaluateur
PTOP    = $9D60         ; le texte du fichier reste sous les descripteurs des
                        ;   tableaux (R_DESC, arr.inc), sous l'image HIRES

; types de la pile de contrôle
T_REP   = 1
T_FOR   = 2
T_WHILE = 3
T_CALL  = 4
T_IF    = 5             ; (traduction seulement)
T_SUB   = 6

; classes des commandes (pour sauter un bloc)
K_LOOP  = 1             ; REPEAT FOR WHILE
K_NEXT  = 2
K_IF    = 3
K_ELSE  = 4
K_ENDIF = 5
K_SUB   = 6
K_ENDS  = 7             ; ENDSUB

lp      = $10           ; pointeur de travail
lx      = $12           ; position dans lbuf
cur     = $13           ; ligne en cours (adresse dans le texte)
nxt     = $15           ; ligne suivante (une boucle la change)
sk      = $17           ; parcours du texte
gv      = $19           ; valeur de travail (2 octets)
gd      = $1B
tbl     = $1C           ; table des commandes (2 octets)
sav_sp  = $1E
pkey    = $1F           ; touche lue entre deux lignes (0 : aucune)
ev      = $20           ; valeur de l'expression (2 octets)
et      = $22           ; opérande de gauche (2 octets)
ex      = $24           ; position dans lbuf pendant une expression
edep    = $25           ; > 0 : les espaces sont permis
csp     = $26           ; pile de contrôle : nombre d'entrées
sdep    = $27           ; profondeur des blocs sautés
smask   = $28           ; classes qui terminent le saut
mt      = $29           ; multiplication / comparaison (2 octets)
mr      = $2B           ; reste (2 octets)
msg_s   = $2D           ; signes de la division (2 octets)
rnd     = $2F           ; générateur pseudo-aléatoire (2 octets)
vix     = $31           ; variable : première lettre (0-25)
vsp     = $32           ; pile des valeurs
pe      = $33           ; fin du texte chargé (2 octets)
; traduction (/A)
ostr    = $35           ; texte à écrire (2 octets)
kc      = $37           ; 1 : l'expression est la constante kv
kv      = $38           ; (2 octets)
oidx    = $3A           ; position dans obuf
kn      = $3B           ; blocs numérotés (2 octets)
kl      = $3D           ; bloc en cours (2 octets)
ksuf    = $3F           ; suffixe d'étiquette (T, E, X)
cmode   = $40           ; 1 : traduction en assembleur
oopen   = $41           ; 1 : NOM.ASM ouvert
klf     = $42           ; gauche d'une opération : constante ?
lv      = $43           ;   sa valeur (2 octets)
kop     = $45
ksym    = $46           ; destination (3 octets)
koff    = $49
kvar    = $4A
osx     = $4B
osy     = $4C
osv     = $4D
kin     = $4E
kst     = $4F
osa     = $50           ; instruction à écrire (2 octets)
kanim   = $52           ; 1 : ANIM traduit (NOM.ASM inclut ANIM.INC)
karr    = $55           ; 1 : tableaux ou chaînes (NOM.ASM inclut ARR.INC)
ihk     = $53           ; INKEY : code de la dernière touche lue
ihi     = $54           ;   et sa place dans la matrice (KB_HELD)
cnum    = $56           ; numéro de la commande trouvée par lookup
kfil    = $57           ; 1 : fichiers de données (NOM.ASM inclut FIL.INC)
kspr    = $58           ; 1 : sprites (NOM.ASM inclut SPR.INC)
vc      = $59           ; variable : second caractère (0 aucun, 1-26 lettre,
                        ;   27-36 chiffre)
vptr    = $5A           ; adresse de la variable (2 octets, interpréteur)
kvc     = $5C           ; second caractère de la variable kvar (traduction)
