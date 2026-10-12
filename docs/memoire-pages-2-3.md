# CP/A — pages 2 et 3 de la mémoire (`$0200-$03FF`)

Référence : `src/hw.inc` (système), `progs/cpa.inc` (interface publique des programmes).
Document à tenir à jour avec eux (octobre 2026).

**Public** : fait partie du contrat d'interface (`docs/architecture.md`), donc stable et commun
aux versions disquette et ROM ; un programme peut s'en servir. **Interne** : variable du
système, qui peut changer ou bouger d'une version à l'autre ; un programme n'y touche pas (sauf
mention). **Disque** : version disquette seulement (l'adresse reste réservée dans la ROM).

CP/A remplace la ROM BASIC : rien de ce que le BASIC de l'Oric range en page 2 n'a cours ici.

## Page 2 (`$0200-$02FF`) : vecteurs et variables du système

Toute la page 2 est remise à 0 au démarrage à froid (`cold_boot`), puis initialisée.

### Vecteurs (`$0200-$020F`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$0200` | `V_WBOOT` / `WBOOT` | 3 | `JMP` démarrage à chaud (retour au système) | public |
| `$0203` | `V_BDOS` / `BDOS` | 3 | `JMP` BDOS : X = fonction, A/Y = paramètre | public |
| `$0206` | `V_IRQ` | 3 | `JMP` IRQ, détournable (DEBUG) | public |
| `$0209` | `V_NMI` | 3 | `JMP` NMI (bouton RESET), détournable (DEBUG) | public |
| `$020C` | `tpa_top` / `TPA_TOP` | 2 | premier octet après la TPA : `$B400` en texte, `$A000` en SPLIT, moins si un plafond est posé (`$02A9`) | public |
| `$020E` | `scr_prog` / `SCR_PROG` | 1 | 1 = un programme a l'écran texte entier (LORES, `h_lores`) : console muette (ni menus, ni voyants ; FUNCT et CTRL-T arrivent au programme comme des touches) ; remis à 0 par `h_text` et le démarrage à chaud | public |
| `$020F` | — | 1 | **libre** | |

### Console et clavier (`$0210-$023F`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$0210` | `cur_x` / `CON_CURX` | 1 | colonne du curseur (2-39) | public |
| `$0211` | `cur_y` / `CON_CURY` | 1 | ligne du curseur (1-27) | public |
| `$0212` | `cur_vis` / `CON_CURVIS` | 1 | 1 = la case du curseur est inversée en ce moment | public |
| `$0213` | `cur_en` / `CON_CUREN` | 1 | 1 = curseur clignotant actif | public |
| `$0214` | `blink_cnt` / `CON_BLINK` | 1 | compteur du clignotement | public |
| `$0215` | `kb_head` | 1 | tampon clavier : position d'écriture (IRQ) | interne |
| `$0216` | `kb_tail` | 1 | tampon clavier : position de lecture | interne |
| `$0217` | `kb_last` | 1 | touche enfoncée en ce moment (index dans la matrice, ligne × 8 + colonne) ou `$FF` ; une seule touche vue à la fois | interne (candidat au public pour les jeux) |
| `$0218` | `kb_rep` | 1 | compte à rebours de la répétition | interne |
| `$0219` | `kb_mods` | 1 | modificateurs : bit 0 SHIFT, bit 1 CTRL, bit 2 FUNCT | interne |
| `$021A` | `caps` | 1 | 1 = majuscules verrouillées (CTRL-T, voyant `A`/`a`) | interne |
| `$021B` | `ticks` / `SYS_TICKS` | 2 | compteur 50 Hz (incrémenté par l'IRQ du timer 1) | public |
| `$021D` | `dma` | 2 | adresse DMA courante du BDOS (fonction 26) | interne |
| `$021F` | `dump_addr` | 2 | prochaine adresse de DUMP (ROM) | interne |
| `$0221` | `bdos_a` | 1 | paramètre A reçu par le BDOS | interne |
| `$0222` | `bdos_y` | 1 | paramètre Y reçu par le BDOS | interne |
| `$0223` | `hex_val` | 2 | nombre hexadécimal lu par le CCP | interne |
| `$0225` | `ccp_pos` | 1 | position d'analyse dans la ligne de commande | interne |
| `$0226` | `kb_row_n` | 1 | ligne de la matrice en cours d'examen (IRQ) | interne |
| `$0227` | `kb_newmods` | 1 | modificateurs lus pendant le balayage (IRQ) | interne |
| `$0228` | `ccp_vec` | 2 | adresse de la commande interne à lancer | interne |
| `$022A` | `hex_cnt` | 1 | nombre de chiffres lus | interne |
| `$022B` | `ccp_tail` | 1 | début de la suite de la ligne après la commande | interne |
| `$022C` | `pf_end` | 1 | analyse d'un nom de fichier | interne |
| `$022D` | `pf_len` | 1 | idem | interne |
| `$022E` | `ccp_cnt` | 1 | compteur de travail du CCP (SAVE, PAPER/INK) | interne |
| `$022F` | — | 1 | **libre** | |
| `$0230-$023F` | `kb_buf` | 16 | tampon circulaire du clavier (rempli par l'IRQ) | interne |

### Divers, son, menus, préférences (`$0240-$027F`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$0240` | `dec_val` | 2 | nombre décimal lu par le CCP | interne |
| `$0242` | `dec_flag` | 1 | idem | interne |
| `$0243` | `con_last` | 1 | dernière ligne de la console (27 ; 26 en SPLIT) | interne |
| `$0244` | `chain_on` | 1 | 1 = une ligne laissée par CHAIN (BDOS 47) attend en `$0400` | interne |
| `$0245` | `lst_echo` | 1 | imprimante : bit 0 = CTRL-P actif, bit 7 = suspendu pendant l'édition d'une ligne | interne |
| `$0246` | `s_hold` | 1 | son, op 7 (SYNC) : bit 7 préparation, bit 6 enveloppe à relancer, bits 0-2 voix préparées | interne |
| `$0247` | `s_pvol` | 3 | volumes des voix préparées | interne |
| `$024A` | `s_pdur` | 3 | durées des voix préparées | interne |
| `$024D` | `s_penv` | 1 | dernière forme d'enveloppe (registre 13 de l'AY) | interne |
| `$024E-$024F` | — | 2 | **libres** | |
| `$0250` | `m_lo` | 8 | menus : adresses des menus de la barre (octet bas) | interne |
| `$0258` | `m_hi` | 8 | idem (octet haut) | interne |
| `$0260` | `m_x` | 8 | colonne de chaque titre dans la barre | interne |
| `$0268` | `m_cnt` | 1 | nombre de menus de la barre | interne |
| `$0269` | `m_cur` | 1 | menu ouvert | interne |
| `$026A` | `m_k` | 1 | touche lue dans un menu | interne |
| `$026B` | `m_tmp` | 1 | travail | interne |
| `$026C` | `m_act` | 1 | 1 = un menu est en cours | interne |
| `$026D` | `m_open` | 1 | menu déroulé | interne |
| `$026E` | `m_item` | 1 | article choisi | interne |
| `$026F` | `m_n` | 1 | nombre d'articles | interne |
| `$0270` | `m_w` | 1 | largeur du menu | interne |
| `$0271` | `m_tot` | 1 | travail (dessin) | interne |
| `$0272` | `m_left` | 1 | colonne gauche du menu | interne |
| `$0273` | `m_end` | 1 | travail (dessin) | interne |
| `$0274` | `m_type` | 1 | action de l'article (`MA_TYPE`, `MA_CALL`) | interne |
| `$0275` | `m_arg` | 2 | adresse liée à l'action | interne |
| `$0277` | `m_savcur` | 1 | état du curseur avant le menu | interne |
| `$0278` | `kb_delay` | 1 | délai avant répétition, en 1/50 s (menu Clavier) | interne |
| `$0279` | `kb_rate` | 1 | période de répétition (menu Clavier) | interne |
| `$027A` | `cur_ink` | 1 | encre de la console, 0-7 (INK, menu Ecran) | interne (lu par VSYNC.COM) |
| `$027B` | `cur_paper` | 1 | papier de la console, 0-7 (PAPER, menu Ecran) | interne (lu par VSYNC.COM) |
| `$027C` | `ram_bad` | 2 | test de la RAM : premier octet défectueux | interne |
| `$027E` | `ram_badf` | 1 | test de la RAM : défaut trouvé | interne |
| `$027F` | — | 1 | **libre** | |

### Vidéo et graphisme (`$0280-$02A1`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$0280` | `vmode` | 1 | 0 = texte, 1 = SPLIT | interne (lire : BDOS 115, op 11) |
| `$0281` | `con_first` | 1 | première ligne de la console (1 ; 17 en SPLIT) | interne |
| `$0282` | `bar_row` | 1 | ligne de la barre de menus (0 ; 16 en SPLIT) | interne |
| `$0283` | `m_ti` | 1 | menus : travail | interne |
| `$0284` | `m_last` | 1 | menus : travail | interne |
| `$0285` | `g_pen` | 1 | crayon du BDOS 115 : 0 efface, 1 trace, 2 inverse | interne |
| `$0286` | `g_mask` | 1 | masque du point | interne |
| `$0287` | `g_tmp` | 1 | travail | interne |
| `$0288` | `g_p` | 6 | paramètres de la fonction 115, recopiés | interne |
| `$028E` | `g_px` | 2 | tracé : x courant | interne |
| `$0290` | `g_py` | 2 | tracé : y courant | interne |
| `$0292` | `g_x2` | 1 | tracé : x d'arrivée | interne |
| `$0293` | `g_y2` | 1 | tracé : y d'arrivée | interne |
| `$0294` | `g_dx` | 2 | Bresenham : écart en x | interne |
| `$0296` | `g_dy` | 2 | Bresenham : écart en y | interne |
| `$0298` | `g_err` | 2 | Bresenham : erreur | interne |
| `$029A` | `g_e2` | 2 | Bresenham : erreur × 2 | interne |
| `$029C` | `g_sx` | 1 | sens en x | interne |
| `$029D` | `g_sy` | 1 | sens en y | interne |
| `$029E` | `g_cx` | 1 | cercle : centre x | interne |
| `$029F` | `g_cy` | 1 | cercle : centre y | interne |
| `$02A0` | `g_r` | 1 | cercle : rayon | interne |
| `$02A1` | `g_cnt` | 1 | travail | interne |

### Console, images, PUT, scripts (`$02A2-$02B8`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$02A2` | `page_cnt` | 1 | lignes défilées depuis la dernière touche (pause en fin d'écran) | interne |
| `$02A3` | `page_on` / `PAGE_ON` | 1 | 1 = pause quand la console est pleine (PAGE ON/OFF, menu Ecran, Pagination ; 1 au démarrage à froid) | public |
| `$02A4` | `img_fcb` | 2 | GSAVE/GLOAD : adresse du FCB | interne, disque |
| `$02A6` | `img_dma` | 2 | GSAVE/GLOAD : DMA de l'appelant | interne, disque |
| `$02A8` | `img_cnt` | 1 | GSAVE/GLOAD : compteur | interne, disque |
| `$02A9` | `top_cap` / `TOP_CAP` | 1 | page plafond de la TPA (0 = aucun), posée par DEBUG ; remise à 0 au démarrage à chaud | public |
| `$02AA` | `put_on` | 1 | 1 = PUT en cours (copie de la console dans un fichier) | interne, disque |
| `$02AB` | `put_pend` | 1 | bit 7 : enregistrements à écrire | interne, disque |
| `$02AC` | `put_lost` | 1 | 1 = tampon débordé, 2 = disque plein | interne, disque |
| `$02AD` | `put_cnt` | 2 | octets dans le tampon de PUT | interne, disque |
| `$02AF` | `scr_on` / `SCR_ON` | 1 | 1 = script DO en cours | public (pour XDO.COM), disque |
| `$02B0` | `scr_idx` / `SCR_IDX` | 1 | position dans l'enregistrement du script (128 : à lire) | public (pour XDO.COM), disque |
| `$02B1` | `cg_blk` | 6 | bloc des commandes graphiques du CCP (version ROM) | interne |
| `$02B7` | `cg_n` | 1 | idem | interne |
| `$02B8` | `cg_i` | 1 | idem | interne |

### Son (`$02B9-$02C6`) et édition de ligne (`$02C7-$02FF`)

| Adresse | Nom | Taille | Contenu | Statut |
|---|---|---|---|---|
| `$02B9` | `s_p` | 6 | paramètres de la fonction 116, recopiés | interne |
| `$02BF` | `s_dur` | 3 | durées restantes des trois voix, en 1/50 s (IRQ) | interne |
| `$02C2` | `s_mix` | 1 | copie du registre 7 de l'AY (mélangeur) | interne |
| `$02C3` | `s_lo` | 1 | travail | interne |
| `$02C4` | `s_hi` | 1 | travail | interne |
| `$02C5` | `s_vol` | 1 | travail | interne |
| `$02C6` | `s_d` | 1 | travail | interne |
| `$02C7` | `rl_pos` | 1 | BDOS 10 : position du curseur dans la ligne | interne |
| `$02C8` | `rl_cnt` | 1 | longueur de la ligne | interne |
| `$02C9` | `rl_max` | 1 | longueur maximale | interne |
| `$02CA` | `rl_sx` | 1 | colonne d'écran du début de la ligne | interne |
| `$02CB` | `rl_sy` | 1 | ligne d'écran du début de la ligne | interne |
| `$02CC` | `rl_sc` | 1 | valeur de `scr_n` quand `rl_sy` était juste | interne |
| `$02CD` | `rl_old` | 1 | longueur affichée | interne |
| `$02CE` | `rl_hix` | 1 | rang dans l'historique (0 = ligne en cours) | interne |
| `$02CF` | `rl_t` | 1 | travail | interne |
| `$02D0` | `scr_n` | 1 | compteur de défilements de la console | interne |
| `$02D1` | `cp_ws` | 1 | complétion (ESC) : début du mot | interne |
| `$02D2` | `cp_n` | 1 | nombre de noms trouvés | interne |
| `$02D3` | `cp_cl` | 1 | longueur du préfixe commun | interne |
| `$02D4` | `cp_mode` | 1 | bit 7 : afficher les noms au lieu de les compter | interne |
| `$02D5` | `cp_col` | 1 | colonne de la liste | interne |
| `$02D6` | `cp_pl` | 1 | longueur du prompt recopié | interne |
| `$02D7` | `cp_txt` | 13 | nom de l'entrée en cours (« NOM.TYP », 0) | interne |
| `$02E4` | `cp_com` | 13 | préfixe commun | interne |
| `$02F1-$02FF` | `rl_pr` | 15 | prompt recopié de l'écran | interne |

**Octets libres de la page 2** : `$020F`, `$022F`, `$024E-$024F`, `$027F` (5 octets).

## Page 3 (`$0300-$03FF`) : entrées et sorties

Sur l'Oric, le VIA 6522 ne décode que les 4 bits bas de l'adresse : il répond dans toute la
page 3, sauf aux adresses qu'une extension prend pour elle (le Microdisc, le LOCI). Une
écriture à une adresse non prise tombe donc sur un registre du VIA (`$03A8` = registre 8 sans
LOCI) : un programme ne touche aux registres d'une extension qu'après l'avoir reconnue.

### VIA 6522 (`$0300-$030F`, et ses reflets)

| Adresse | Registre | Usage dans CP/A |
|---|---|---|
| `$0300` | ORB (port B) | PB0-2 : ligne du clavier ; PB3 (entrée) : une touche est enfoncée ; PB4 : strobe de l'imprimante (repos à 1) ; autres bits en sortie |
| `$0301` | ORA (port A, avec poignée de main) | bus de données de l'AY-3-8912 et de l'imprimante |
| `$0302` | DDRB | `$F7` : PB3 en entrée, le reste en sortie |
| `$0303` | DDRA | `$FF` : port A en sortie |
| `$0304-$0305` | T1 compteur | timer 1 : top 50 Hz de l'IRQ ; lancé au démarrage à froid seulement (la phase, calée par VSYNC, tient jusqu'à l'arrêt) |
| `$0306-$0307` | T1 latch | période 19 966 (19 968 cycles = une trame vidéo de 312 lignes × 64) |
| `$0308-$0309` | T2 | inutilisé |
| `$030A` | SR | inutilisé |
| `$030B` | ACR | `$40` : T1 en mode continu, sans sortie PB7 |
| `$030C` | PCR | CA2 → BC1 et CB2 → BDIR de l'AY (sélection et écriture des registres du son et du clavier) |
| `$030D` | IFR | indicateurs : T1 (IRQ), CA1 (accusé de réception de l'imprimante) |
| `$030E` | IER | seule l'interruption de T1 est autorisée |
| `$030F` | ORA sans poignée de main | bus de l'AY (registre 14 de l'AY = colonnes du clavier) |

### Contrôleur de disquettes Microdisc (`$0310-$031B`, version disquette)

Même interface sur le Microdisc d'origine, le Cumulus, le LOCI et Oricutron.

| Adresse | Registre | Usage |
|---|---|---|
| `$0310` | WD1793 : commande (écriture) / état (lecture) | état : bit 0 occupé, bits 2-6 erreurs (`$5C` : protégé, non trouvé, CRC, perte de données), bit 7 « pas prêt » (toujours 0 : READY est câblé actif sur le Microdisc et le LOCI) |
| `$0311` | WD1793 : piste | un seul registre pour les quatre lecteurs : le pilote garde la piste de chacun (`dsk_trk`, `$FDA4`) |
| `$0312` | WD1793 : secteur | |
| `$0313` | WD1793 : données | |
| `$0314` | contrôle (écriture) / IRQ (lecture) | écriture : bit 7 EPROM du Microdisc coupée (1), bits 5-6 lecteur, bit 4 face, bit 3 densité, bit 2 horloge, bit 1 ROM BASIC (0 = coupée : RAM overlay `$C000-$FFFF`), bit 0 IRQ du contrôleur ; CP/A écrit `$84` (`MD_BASE` : EPROM coupée, horloge, ROM coupée, IRQ coupée) plus le lecteur et la face. Lecture : bit 7 = /INTRQ (0 = commande finie) |
| `$0318` | DRQ (lecture) | bit 7 = /DRQ (0 = un octet de données à lire ou à écrire) |
| `$0319` | LOCI (lecture) | `"L"` ($4C) si un LOCI est là (marque d'identité de la MIA) ; sert à reconnaître le LOCI sans écrire (`loci_abs`, `src/disk.s`) |

### LOCI (version disquette)

| Adresse | Usage |
|---|---|
| `$0380-$0383` | ACIA 6551 émulée (port série ; modem WiFi, voir `docs/loci-modem-wifi.md` ; le firmware répond aussi en `$0340`) ; pas encore utilisée par CP/A (entrées PUNCH et READER du BIOS réservées) |
| `$03A0-$03BF` | MIA : interface du Picocomputer 6502 (registres de `loci-rom/src/include/loci.h`) |

Registres de la MIA utilisés par CP/A :

| Adresse | Usage |
|---|---|
| `$03A8` | XRAM, fenêtre 1 : lire rend l'octet à l'adresse `$03AA-$03AB`, puis l'adresse avance du pas |
| `$03A9` | pas de la fenêtre 1 (CP/A met 1) |
| `$03AA-$03AB` | adresse de la fenêtre 1 dans la XRAM du LOCI ; l'écrire recharge `$03A8`. CP/A y lit la configuration du menu du LOCI : `"LOCI"` en `$8000`, octet `mounts` en `$800B` (bit n = lecteur n monté) |
| `$03AC` | pile d'échange de 512 octets : chaque écriture empile, chaque lecture dépile |
| `$03AD-$03AE` | errno de la dernière opération |
| `$03AF` | numéro d'opération : l'écrire lance l'opération (0 : vider la pile d'échange) |
| `$03B0-$03B7` | routine à appeler par `JSR $03B0` : `CLV` / `BVC *` (attente de la fin) / `LDA #A` / `LDX #X` / `RTS` ; le LOCI en réécrit les octets, A en `$03B4`, X en `$03B6`. Après le démarrage d'une disquette, `$03B3` contient un `JMP ($FFFC)` jusqu'à la première opération : d'où l'opération 0 de `mia_chk` (`progs/loci_inc.s`) |

Oricutron place son ACIA simulée en `$031C-$031F`. Le reste de la page 3 (`$0320-$033F`,
`$0344-$037F`, `$0384-$039F`, `$03C0-$03FF`) n'est utilisé par aucune extension connue de
CP/A : ce sont des reflets du VIA.
