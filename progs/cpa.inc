; ---------------------------------------------------------------------
;  cpa.inc — interface publique de CP/A pour les programmes .COM
; ---------------------------------------------------------------------
BDOS        = $0203     ; X = fonction, A/Y = paramètre
WBOOT       = $0200     ; retour au système

; Table BIOS
B_CONST     = $C006     ; A=$FF si une touche attend
B_CONIN     = $C009     ; attend une touche (menus FUNCT gérés)
B_CONOUT    = $C00C     ; affiche A
B_HOME      = $C018     ; tête du lecteur des accès directs en piste 0
B_SELDSK    = $C01B     ; A = lecteur (0-3) -> A = 0, $FF si absent/illisible
B_SETSEC    = $C021     ; A/Y = secteur logique (LSN, 0-1427)
B_SETDMA    = $C024     ; A/Y = tampon de 256 octets
B_READ      = $C027     ; lit le secteur -> A = 0, 1 si erreur
B_WRITE     = $C02A     ; écrit le secteur -> A = 0, 1 si erreur
B_MENUBAR   = $C02D     ; installe la barre de menus A/Y

; Page de base
FCB1        = $045C
FCB2        = $046C
TAIL        = $0480     ; longueur + paramètres
DEF_DMA     = $0480

; Variables publiques de la console
CON_CURX    = $0210     ; colonne du curseur (2..39)
CON_CURY    = $0211     ; ligne du curseur (1..27)
CON_CURVIS  = $0212     ; 1 = curseur inversé à l'écran en ce moment
CON_CUREN   = $0213     ; 1 = curseur clignotant actif
CON_BLINK   = $0214     ; compteur de clignotement

SCREEN      = $BB80

; Fonctions du BDOS
F_CONOUT    = 2
F_LIST      = 5         ; A = caractère à imprimer (Centronics)
F_PRINT     = 9
F_RESET     = 13        ; tampon écrit, lecteurs à relire (démarrage à chaud)
F_OPEN      = 15
F_CLOSE     = 16
F_SFIRST    = 17
F_SNEXT     = 18
F_DELETE    = 19
F_READ      = 20
F_WRITE     = 21
F_MAKE      = 22
F_RENAME    = 23
F_SELDSK    = 14        ; A = lecteur (0 = A:) devient le lecteur courant
F_LOGIN     = 24        ; -> A : lecteurs lus (bit 0 = A:)
F_CURDSK    = 25        ; -> A : lecteur courant (0 = A:)
F_SETDMA    = 26
F_ATTRIB    = 30        ; bit 7 de t1 = R/O, de t2 = SYS
F_RREAD     = 33        ; lecture directe (enregistrement R0-R1 du FCB)
F_RWRITE    = 34        ; écriture directe
F_FSIZE     = 35        ; taille en enregistrements -> R0-R1
F_SETRND    = 36        ; R0-R1 <- position séquentielle
F_CHAIN     = 47        ; A/Y = ligne de commande (0 à la fin) : le CCP
                        ;   l'exécute après la fin du programme
FCB_R0      = 33        ; octets 33-35 du FCB : R0, R1, R2

; Actions des menus
MA_TYPE     = 1
MA_CALL     = 2

; Haut de la TPA (public) : $B400 en mode texte, $A000 en mode SPLIT
TPA_TOP     = $020C

; Graphisme (mode SPLIT) : X = F_GFX, A/Y = bloc [op, p1, p2, p3, p4, p5]
F_GFX       = 115
G_CLS       = 0
G_PEN       = 1         ; p1 : 0 efface, 1 trace, 2 inverse
G_PLOT      = 2         ; x, y
G_LINE      = 3         ; x1, y1, x2, y2
G_BOX       = 4
G_FBOX      = 5
G_CIRCLE    = 6         ; x, y, r
G_TEXT      = 7         ; col, y, adr
G_ATTR      = 8         ; col, y1, y2, valeur
G_POINT     = 9         ; x, y -> A
G_MODE      = 10        ; 0 texte, 1 SPLIT, 2 SPLIT sans effacer l'image
G_GETMODE   = 11        ; -> A
G_GSAVE     = 12        ; fcb_lo, fcb_hi : enregistre l'image (.IMG)
G_GLOAD     = 13        ; fcb_lo, fcb_hi : charge une image, passe en SPLIT

; Compteur 50 Hz (2 octets, incrémenté par l interruption)
SYS_TICKS   = $021B

; Variables publiques du système
PAGE_ON     = $02A3     ; 1 = pause quand la console est pleine
TOP_CAP     = $02A9     ; page plafond de la TPA posée par DEBUG (0 = aucune)

; Son (fonction 116 du BDOS) : X = F_SND, A/Y = bloc [op, p1..p5]
F_SND       = 116
S_SILENCE   = 0         ; coupe tout
S_NOTE      = 1         ; voix, note (1-96, 37 = do central), vol (0-15), durée
S_NOISE     = 2         ; voix, période (0-31), vol, durée
S_ENV       = 3         ; forme, période lo, période hi
S_WAIT      = 4         ; voix (255 : toutes)
S_STATUS    = 5         ; -> A : bits des voix qui jouent
S_TONE      = 6         ; voix, période lo, hi, vol, durée
S_SYNC      = 7         ; mode : 0 préparation, 1 départ simultané, 2 abandon
S_MIXER     = 8         ; voix, son (0/1), bruit (0/1)

; Script DO en cours (version disquette, pour XDO.COM) : ces zones du
; système gardent l'état du script entre deux lignes
SCR_ON      = $02AF     ; 1 = script en cours
SCR_IDX     = $02B0     ; position dans SCR_BUF (128 : enregistrement à lire)
SCR_FCB     = $F6C0     ; FCB du script, ouvert (36 octets)
SCR_BUF     = $F6E4     ; enregistrement en cours (128 octets)
SCR_PAR     = $F764     ; paramètres $1-$9, séparés par des espaces (80 octets)
ORIG_LINE   = $F670     ; ligne de commande en cours, casse d'origine, 0 à la fin
