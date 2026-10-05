; ---------------------------------------------------------------------
;  hw.inc — matériel Oric Atmos et constantes système de CP/A
; ---------------------------------------------------------------------

; --- VIA 6522 ---
VIA_ORB     = $0300     ; port B : PB0-2 ligne clavier, PB3 détection touche
VIA_ORA     = $0301     ; port A (avec handshake)
VIA_DDRB    = $0302
VIA_DDRA    = $0303
VIA_T1CL    = $0304
VIA_T1CH    = $0305
VIA_T1LL    = $0306
VIA_T1LH    = $0307
VIA_ACR     = $030B
VIA_PCR     = $030C     ; CA2 -> BC1 de l'AY, CB2 -> BDIR de l'AY
VIA_IFR     = $030D
VIA_IER     = $030E
VIA_ORA_NH  = $030F     ; port A sans handshake (bus de données de l'AY)

PCR_IDLE    = $DD       ; AY inactif
PCR_LATCH   = $FF       ; AY : sélection de registre
PCR_WRITE   = $FD       ; AY : écriture de donnée

T1_PERIOD   = 19998     ; 20 ms à 1 MHz -> interruption à 50 Hz

; --- Écran ---
SCREEN      = $BB80
CHARSET     = $B400
COLS        = 40
ROWS        = 28
FIRST_COL   = 2         ; colonnes 0-1 réservées aux attributs
FIRST_ROW   = 1         ; ligne 0 = ligne d'état
LAST_ROW    = 27

ATTR_TEXT50 = $1A       ; attribut mode texte 50 Hz
ATTR_PAPER0 = $10       ; papier noir
ATTR_PAPER4 = $14       ; papier bleu
ATTR_INK7   = $07       ; encre blanche

; --- Page zéro système ($E0-$FF) ---
ZP_FCB      = $E0       ; FCB passé au BDOS
ZP_DIRP     = $E2       ; entrée de répertoire courante
ZP_DMAP     = $E4       ; adresse DMA (copie de travail)
ZP_DSK      = $E6       ; pointeur du pilote disque
ZP_CFCB     = $E8       ; FCB en cours d'analyse par le CCP
ZP_PTR      = $F0       ; pointeur général BDOS/CCP
ZP_PTR2     = $F2
ZP_SCR      = $F4       ; console
ZP_SCR2     = $F6
ZP_T0       = $F8
ZP_T1       = $F9
ZP_IRQ      = $FA       ; réservé à l'IRQ
ZP_IRQP     = $FC       ; pointeur pour le curseur (IRQ ou SEI)

; --- Mode vidéo ---
IMG_BASE    = $A000     ; image du mode SPLIT : 240 x 128 points
IMG_END     = $B400     ; (la ligne de points 128 tombe sur la police)
IMG_LINES   = 128
IMG_SWITCH  = IMG_BASE+127*40 ; 1re case de la ligne 127 : retour au texte
SPLIT_BAR   = 16        ; ligne de la barre de menus en mode SPLIT
ATTR_HIRES  = $1E       ; attribut haute résolution 50 Hz
ZP_BAR      = $FE       ; adresse de la ligne de la barre de menus

; --- Vecteurs RAM (page 2) ---
V_WBOOT     = $0200
V_BDOS      = $0203
V_IRQ       = $0206
V_NMI       = $0209
tpa_top     = $020C     ; 2 octets : premier octet après la TPA (public)

; --- Variables système (page 2) ---
cur_x       = $0210
cur_y       = $0211
cur_vis     = $0212     ; 1 = curseur actuellement inversé à l'écran
cur_en      = $0213     ; 1 = curseur activé
blink_cnt   = $0214
kb_head     = $0215
kb_tail     = $0216
kb_last     = $0217     ; dernière touche vue (index matrice) ou $FF
kb_rep      = $0218     ; compteur de répétition
kb_mods     = $0219     ; bit0 SHIFT, bit1 CTRL, bit2 FUNCT
caps        = $021A     ; 1 = verrouillage majuscules
ticks       = $021B     ; 2 octets, compteur 50 Hz
dma         = $021D     ; 2 octets, adresse DMA courante
dump_addr   = $021F     ; 2 octets, prochaine adresse pour DUMP
bdos_a      = $0221
bdos_y      = $0222
hex_val     = $0223     ; 2 octets
ccp_pos     = $0225
kb_row_n    = $0226
kb_newmods  = $0227
ccp_vec     = $0228     ; 2 octets
hex_cnt     = $022A
kb_buf      = $0230     ; 16 octets, tampon circulaire clavier
KB_MASK     = 15

ccp_tail    = $022B     ; position de la suite de la ligne après la commande
pf_end      = $022C     ; analyse de nom de fichier
pf_len      = $022D
ccp_cnt     = $022E
dec_val     = $0240     ; 2 octets
dec_flag    = $0242
con_last    = $0243     ; dernière ligne de la console (27, 26 en SPLIT)
chain_on    = $0244     ; 1 = CMDBUF contient une ligne laissée par CHAIN (47)

; --- Page de base ($0400) ---
CMDBUF      = $0400     ; [max][long][caractères…][0]
CMDMAX      = 78
DEF_FCB     = $045C
DEF_FCB2    = $046C
DEF_DMA     = $0480
TPA_START   = $0500
TPA_END     = $B400     ; premier octet après la TPA

#ifdef DISK
; --- Contrôleur Microdisc (WD1793) ---
FDC_CMD     = $0310     ; commande (écriture) / état (lecture)
FDC_TRK     = $0311
FDC_SEC     = $0312
FDC_DATA    = $0313
MD_CTRL     = $0314     ; écriture : contrôle ; lecture : bit 7 = /INTRQ
MD_DRQ      = $0318     ; lecture : bit 7 = /DRQ
MD_BASE     = $84       ; EPROM coupée, ROM coupée (RAM overlay), lecteur A, face 0

; --- Géométrie de la disquette CP/A ---
SPT         = 17        ; secteurs de 256 octets par piste
NSIDES      = 2
NCYL        = 42
NSECT       = 1428      ; SPT*NSIDES*NCYL
SYS_LSN     = 3         ; système : secteurs logiques 3..66 (16 Ko)
DIR_LSN     = 68        ; début de la zone de données (bloc 0 = répertoire)
BLK_SECT    = 8         ; bloc d'allocation = 2 Ko
NBLK        = 170       ; (NSECT-DIR_LSN)/BLK_SECT
DIR_ENT     = 128       ; blocs 0 et 1 : 128 entrées de 32 octets
ALV_LEN     = 22        ; (NBLK+7)/8

; --- RAM système dans la RAM overlay (au-dessus du code) ---
ALV         = $FD00     ; carte d'allocation
dsk_lsn     = $FD20     ; 2 octets
dsk_buf     = $FD22     ; 2 octets
dsk_cyl     = $FD24
dsk_side    = $FD25
dsk_sec     = $FD26
dsk_op      = $FD27
dsk_try     = $FD28
fs_lsn      = $FD2A     ; 2 octets
buf_lsn     = $FD2C     ; 2 octets
buf_ok      = $FD2E
dir_i       = $FD2F
fs_rec      = $FD30
fs_blk      = $FD31
fs_half     = $FD32
fs_t0       = $FD33
fs_t1       = $FD34
fs_found    = $FD35
m_anyex     = $FD36
srch_fcb    = $FD37     ; 2 octets
fs_idx      = $FD39
fs_err      = $FD3A
buf_dirty   = $FD3B
fs_ro       = $FD3C     ; un fichier protégé a été épargné
dir_all     = $FD3D     ; DIRS : montre aussi les fichiers SYS
fs_rex      = $FD3E     ; accès direct : extent et enregistrement visés
fs_rcr      = $FD3F
fs_szl      = $FD40     ; taille (fonction 35)
fs_szh      = $FD41
CCP_FCB     = $FD80     ; FCB privé du CCP (36 octets)
CCP_FCB2    = $FDB0     ; FCB de travail (REN)
SECBUF      = $FE00     ; tampon de secteur (256 octets)
#endif

; --- Menus et préférences (page 2) ---
m_lo        = $0250     ; 8 octets
m_hi        = $0258     ; 8 octets
m_x         = $0260     ; 8 octets
m_cnt       = $0268
m_cur       = $0269
m_k         = $026A
m_tmp       = $026B
m_act       = $026C
m_open      = $026D
m_item      = $026E
m_n         = $026F
m_w         = $0270
m_tot       = $0271
m_left      = $0272
m_end       = $0273
m_type      = $0274
m_arg       = $0275     ; 2 octets
m_savcur    = $0277
kb_delay    = $0278     ; délai avant répétition (1/50 s)
kb_rate     = $0279     ; période de répétition
cur_ink     = $027A
cur_paper   = $027B
ram_bad     = $027C     ; 2 octets : premier octet défectueux
ram_badf    = $027E
vmode       = $0280     ; 0 = texte, 1 = SPLIT
con_first   = $0281     ; première ligne de la console
bar_row     = $0282     ; ligne de la barre de menus
m_ti        = $0283
m_last      = $0284
; primitives graphiques
g_pen       = $0285
g_mask      = $0286
g_tmp       = $0287
g_p         = $0288     ; 6 octets : paramètres recopiés
g_px        = $028E     ; 2 octets
g_py        = $0290     ; 2 octets
g_x2        = $0292
g_y2        = $0293
g_dx        = $0294     ; 2 octets
g_dy        = $0296     ; 2 octets
g_err       = $0298     ; 2 octets
g_e2        = $029A     ; 2 octets
g_sx        = $029C
g_sy        = $029D
g_cx        = $029E
g_cy        = $029F
g_r         = $02A0
g_cnt       = $02A1
page_cnt    = $02A2     ; lignes défilées depuis la dernière touche
cg_blk      = $02B1     ; 6 octets : bloc des commandes graphiques
cg_n        = $02B7
cg_i        = $02B8
; son (BDOS 116)
s_p         = $02B9     ; 6 octets : paramètres recopiés
s_dur       = $02BF     ; 3 octets : durées restantes (1/50 s)
s_mix       = $02C2     ; copie du registre 7 (mélangeur)
s_lo        = $02C3
s_hi        = $02C4
s_vol       = $02C5
s_d         = $02C6
; édition de ligne (BDOS 10, src/rline.s)
rl_pos      = $02C7     ; position du curseur dans la ligne
rl_cnt      = $02C8     ; longueur de la ligne
rl_max      = $02C9     ; longueur maximale (79 au plus)
rl_sx       = $02CA     ; colonne et ligne d'écran du début de la ligne
rl_sy       = $02CB
rl_sc       = $02CC     ; valeur de scr_n quand rl_sy était juste
rl_old      = $02CD     ; longueur affichée
rl_hix      = $02CE     ; rang dans l'historique (0 = ligne en cours)
rl_t        = $02CF
scr_n       = $02D0     ; compteur de défilements (incrémenté par scroll)
cp_ws       = $02D1     ; complétion : début du mot
cp_n        = $02D2     ; nombre de noms trouvés
cp_cl       = $02D3     ; longueur du préfixe commun
cp_mode     = $02D4     ; bit 7 : afficher les noms au lieu de les comparer
cp_col      = $02D5     ; colonne de la liste
cp_pl       = $02D6     ; longueur du prompt recopié
cp_txt      = $02D7     ; 13 octets : nom de l'entrée en cours (« NOM.TYP »,0)
cp_com      = $02E4     ; 13 octets : préfixe commun
rl_pr       = $02F1     ; 15 octets : prompt recopié de l'écran
RLB         = $BA00     ; tampon d'édition (128 octets) } fin du jeu de caractères
HIST        = $BA80     ; historique (256 octets)      } alternatif, inutilisé
RLMAX       = 126     ; (<HIST + RLMAX + 1 < 256)
page_on     = $02A3     ; 1 = pause quand l'écran est plein (public)
img_fcb     = $02A4     ; 2 octets : FCB de GSAVE/GLOAD
img_dma     = $02A6     ; 2 octets : DMA de l'appelant
img_cnt     = $02A8
top_cap     = $02A9     ; page plafond de la TPA (0 = aucun), posé par DEBUG (public)
ZP_G        = ZP_M3     ; pointeur dans l'image

#ifdef DISK
; --- PUT : copie de la sortie console dans un fichier ---
put_on      = $02AA     ; 1 = capture en cours
put_pend    = $02AB     ; bit 7 : enregistrement(s) à écrire
put_lost    = $02AC     ; 1 = tampon débordé, 2 = disque plein
put_cnt     = $02AD     ; 2 octets : octets dans le tampon
put_fcb     = $FDD4     ; FCB du fichier (36 octets)
scr_on      = $02AF     ; 1 = script DO en cours
scr_idx     = $02B0     ; position dans l'enregistrement (128 : à lire)
ORIGBUF     = $F670     ; la ligne de commande avant passage en majuscules
scr_fcb     = $F6C0     ; FCB du script (36 octets)
scr_buf     = $F6E4     ; enregistrement courant (128 octets)
scr_par     = $F764     ; paramètres $1-$9 (80 octets)
PUT_SAVE    = $F7C0     ; sauvegarde de l'état pendant l'écriture (64 octets)
PUT_NZP     = 26        ; page zéro $E0-$F9
PUTBUF      = $F800     ; tampon (1280 octets, jusqu'à $FCFF)
PUTMAX      = 1280
SYS_END     = $F670     ; le code du système doit finir avant
#endif
