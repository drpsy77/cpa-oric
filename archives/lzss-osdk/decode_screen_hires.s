; ============================================================================
; decode_screen_hires.s
;
; Decodeur LZSS "maison", relogeable, pour ecran HIRES Oric Atmos.
; Decompresse vers l'ecran HIRES fixe a $A000 (200 lignes x 40 octets
; = 8000 octets). Assembleur : xa (toolchain OSDK).
;
; ----------------------------------------------------------------------------
; FORMAT DU FLUX COMPRESSE
;
; Le flux est une suite de groupes de 8 "jetons". Chaque groupe est
; precede d'un octet de FLAGS (1 bit par jeton, bit 0 = 1er jeton du
; groupe, lu du bit 0 vers le bit 7) :
;
;   bit = 1  ->  jeton LITTERAL : 1 octet brut suit, recopie tel quel
;                dans l'ecran.
;
;   bit = 0  ->  jeton COPIE : 3 octets suivent :
;                  - distance_lo, distance_hi  (distance en arriere,
;                    16 bits little-endian ; 1 = l'octet ecrit juste
;                    avant dans l'ecran)
;                  - longueur (1 octet brut, valeur utile 4..255)
;                La copie se fait octet par octet (pas par bloc), ce
;                qui gere correctement les recouvrements (distance <
;                longueur), utile pour les aplats de couleur/pixels.
;
; Aucun marqueur de fin n'est necessaire : la taille de l'ecran est
; fixe (8000 octets), le decodeur s'arrete des que ce total est
; atteint (meme au milieu d'un groupe de flags).
;
; ----------------------------------------------------------------------------
; CONVENTION D'APPEL
;
; Point d'entree C (le compilateur OSDK appelle une fonction C nommee
; decode_screen_hires via le label _decode_screen_hires -- le simple
; prefixe '_' suffit, aucune declaration cote assembleur n'est necessaire) :
;
;   void decode_screen_hires(const unsigned char* src);
;
;   -> Le compilateur OSDK NE passe PAS les arguments dans A/X : il les
;      ecrit via ARGW_C/ARGW_D dans le buffer pointe par la variable
;      zero-page "sp" (voir MACROS.H), puis fait "ldy #<taille>" avant le
;      JSR (Y = nombre d'octets d'arguments, non utilise ici). Le pointeur
;      se recupere donc avec (sp),y : octet bas en y=0, octet haut en
;      y=1 -- exactement le pattern utilise par l'exemple officiel
;      OSDK sample/mixed/hello_world_mixed/print.s (_SimplePrint).
;
; Point d'entree pur assembleur (pas de passage par C) :
;
;   DecodeScreenHires
;
;   -> tmp0 doit deja contenir l'adresse de depart du flux compresse
;      avant le JSR.
;
; ----------------------------------------------------------------------------
; RELOGEABILITE
;
; Ce module n'ecrit ni ne lit aucune adresse absolue codee en dur sur
; lui-meme (pas de self-modifying code base sur son propre org) : tous
; les sauts internes utilisent des etiquettes. Il peut donc etre assemble
; a n'importe quelle adresse. Seule la destination de la decompression
; (l'ecran HIRES) est fixe a $A000, par definition du format ecran de
; l'Oric.
;
; Utilise tmp0/tmp1/tmp2, trois des variables de travail 16 bits ($50 et
; suivantes) declarees dans HEADER.S (OSDK\LIB). ATTENTION : selon la doc
; OSDK, ces variables sont de simples scratch, potentiellement ecrasees
; par tout appel de fonction (bibliotheque ou C) entre une ecriture et une
; lecture -- ce module n'appelle jamais rien pendant sa propre execution,
; donc aucun risque ici ; ne pas en supposer le contenu preserve avant/
; apres l'appel a decode_screen_hires depuis ton code C.
;
; ----------------------------------------------------------------------------
; INTEGRATION DANS UN PROJET OSDK
;
; OSDK compile chaque .c en .s, puis link65 concatene tous les .s du
; projet (ceux generes depuis le C et ceux ecrits a la main, dont celui-
; ci) en un seul linked.s, assemble en une seule passe par xa -- pas de
; veritable etape de link avec fichiers objets separes. Consequence :
; aucune directive .export/.import/.global n'est necessaire (HEADER.S
; lui-meme n'en utilise aucune pour declarer tmp0-tmp7).
;
; Comme tout le projet finit assemble comme un seul gros fichier, les
; labels internes de ce module (decode_loop, copy_token, etc.) sont
; places dans un bloc local .( ... .) pour eviter toute collision avec un
; label de meme nom ailleurs dans le projet. Seuls les deux points
; d'entree sont rendus visibles a l'exterieur du bloc, via le prefixe '+'
; (convention xa pour un label "global" au sein d'un bloc local).
; ============================================================================

.(

SCREEN_START    = $A000
SCREEN_SIZE     = 8000                          ; 200 lignes x 40 octets
SCREEN_END      = SCREEN_START + SCREEN_SIZE    ; $BF40

; ----------------------------------------------------------------------------
; Zone de travail (BSS, hors du flot d'execution)
; ----------------------------------------------------------------------------
        .bss

flagbyte    .dsb    1       ; octet de flags courant (8 bits utiles)
flagcount   .dsb    1       ; nombre de bits de flag restant a consommer
tmplen      .dsb    1       ; compteur de longueur pour un jeton COPIE

        .text

; ----------------------------------------------------------------------------
; +_decode_screen_hires : point d'entree C
;   L'argument (pointeur source) est lu depuis (sp),y -- voir la note sur
;   la convention d'appel OSDK plus haut dans ce fichier.
; ----------------------------------------------------------------------------
+_decode_screen_hires
        ldy     #0
        lda     (sp),y
        sta     tmp0
        iny
        lda     (sp),y
        sta     tmp0+1
        ; tombe directement dans DecodeScreenHires

; ----------------------------------------------------------------------------
; +DecodeScreenHires : point d'entree pur assembleur
;   tmp0 doit deja pointer sur le debut du flux compresse
; ----------------------------------------------------------------------------
+DecodeScreenHires
        lda     #<SCREEN_START
        sta     tmp1
        lda     #>SCREEN_START
        sta     tmp1+1

        lda     #0
        sta     flagcount               ; force le chargement d'un 1er octet de flags

; ----------------------------------------------------------------------------
; Boucle principale : un jeton par iteration
; ----------------------------------------------------------------------------
decode_loop
        lda     flagcount
        bne     have_flag

        ; recharge un octet de flags depuis le flux compresse
        ldy     #0
        lda     (tmp0),y
        sta     flagbyte
        inc     tmp0
        bne     reload_flag_no_carry
        inc     tmp0+1
reload_flag_no_carry
        lda     #8
        sta     flagcount

have_flag
        dec     flagcount
        lsr     flagbyte                ; bit sortant (carry) = jeton courant
        bcs     literal_token           ; carry=1 -> litteral, carry=0 -> copie

; ----------------------------------------------------------------------------
; Jeton COPIE : distance_lo, distance_hi, longueur (3 octets)
; ----------------------------------------------------------------------------
copy_token
        ldy     #0
        lda     (tmp0),y                ; distance_lo
        sta     tmp2
        iny
        lda     (tmp0),y                ; distance_hi
        sta     tmp2+1
        iny
        lda     (tmp0),y                ; longueur (4..255)
        sta     tmplen

        clc                             ; tmp0 += 3
        lda     tmp0
        adc     #3
        sta     tmp0
        bcc     copy_srcptr_no_carry
        inc     tmp0+1
copy_srcptr_no_carry

        ; tmp2 = tmp1 - distance  (adresse source de la copie dans l'ecran)
        sec
        lda     tmp1
        sbc     tmp2
        tax                             ; sauvegarde temporaire de l'octet bas
        lda     tmp1+1
        sbc     tmp2+1
        sta     tmp2+1
        stx     tmp2

copy_byte
        ldy     #0
        lda     (tmp2),y
        sta     (tmp1),y

        inc     tmp2
        bne     copy_srcaddr_no_carry
        inc     tmp2+1
copy_srcaddr_no_carry
        inc     tmp1
        bne     copy_dstaddr_no_carry
        inc     tmp1+1
copy_dstaddr_no_carry

        lda     tmp1+1                  ; ecran termine ?
        cmp     #>SCREEN_END
        bne     copy_continue
        lda     tmp1
        cmp     #<SCREEN_END
        beq     done

copy_continue
        dec     tmplen
        bne     copy_byte
        jmp     decode_loop

; ----------------------------------------------------------------------------
; Jeton LITTERAL : 1 octet brut
; ----------------------------------------------------------------------------
literal_token
        ldy     #0
        lda     (tmp0),y
        sta     (tmp1),y

        inc     tmp0
        bne     literal_srcaddr_no_carry
        inc     tmp0+1
literal_srcaddr_no_carry
        inc     tmp1
        bne     literal_dstaddr_no_carry
        inc     tmp1+1
literal_dstaddr_no_carry

        lda     tmp1+1                  ; ecran termine ?
        cmp     #>SCREEN_END
        bne     literal_continue
        lda     tmp1
        cmp     #<SCREEN_END
        beq     done

literal_continue
        jmp     decode_loop

done
        rts

.)
