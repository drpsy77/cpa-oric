; =====================================================================
;  loci_inc.s — accès aux fichiers de la clé USB du LOCI (bibliothèque
;  incluse à la fin de EXPORT, IMPORT, USBDIR et CMDER ; jamais assemblée
;  seule)
;
;  Le LOCI dérive du Picocomputer 6502 : sa « MIA » expose à l'Oric
;  l'API du RIA en $03A0-$03BF (loci-rom/src/asminc/loci.inc, et
;  les sources C de loci-firmware, src/mia/api pour le détail des opérations) :
;    $03AC  pile d'échange de 512 octets : chaque écriture empile, chaque
;           lecture dépile (dans l'ordre croissant de la mémoire du LOCI)
;    $03AD  errno (code d'erreur de la dernière opération)
;    $03AF  numéro de l'opération : l'écrire la lance
;    $03B0  JSR : attend la fin (CLV / BVC * / LDA #A / LDX #X / RTS,
;           octets réécrits par le LOCI), rend le résultat dans A/X
;    $03B4  A (dernier paramètre) ; $03B6 X
;  Résultat négatif (X >= $80) : erreur, code dans $03AD. Une chaîne est
;  empilée à l'envers (dernier caractère d'abord), sans le 0 final.
;  Chemins : "1:/NOM" ou "/NOM" (sans lecteur : la première clé USB),
;  "0:NOM" la mémoire interne du LOCI.
;
;  Tampons après la fin du programme : args, iobuf, dirent, numbuf, cwd,
;  apath... (liste à la fin), puis lib_free, où le programme place les
;  siens.
;  Page zéro : $30-$3B.
; =====================================================================

MIA_XSTACK  = $03AC
MIA_ERRNO   = $03AD
MIA_OP      = $03AF
MIA_SPIN    = $03B0
MIA_A       = $03B4

OP_OPEN     = $14
OP_CLOSE    = $15
OP_READ     = $16       ; read_xstack
OP_WRITE    = $18       ; write_xstack
OP_OPENDIR  = $80
OP_CLOSEDIR = $81
OP_READDIR  = $82

O_RDONLY    = $01       ; drapeaux d'ouverture (ceux de cc65)
O_WRONLY    = $02
O_CREAT     = $10
O_TRUNC     = $20

lptr    = $30           ; 2 octets
lcnt    = $32
lwid    = $33
lt0     = $34
lt1     = $35
lt2     = $36
lsav    = $37
num     = $38           ; 4 octets : nombre affiché par pnum

; mia_chk : C=0 si le LOCI répond (pile d'échange vidée), sinon message
;   et C=1. On lit d'abord le code de $03B0 : sans LOCI, ces adresses
;   sont celles du VIA, et un JSR $03B0 planterait.
;   L'opération 0 (vider la pile d'échange) est lancée AVANT la lecture :
;   après le démarrage d'une disquette, le LOCI laisse en $03B3 le code
;   de démarrage (JMP ($FFFC), loci-firmware api_return_boot) et non
;   LDA # ; l'opération 0 y remet aussitôt CLV/BVC/LDA/LDX/RTS. Sans LOCI,
;   l'écriture tombe sur un registre du VIA (port A sans poignée de main),
;   sans effet : le son et le clavier réécrivent le port à chaque usage.
mia_chk
.(
        lda #0                  ; opération 0 : vide la pile d'échange
        sta MIA_OP
        lda $03B0
        cmp #$B8                ; CLV
        bne no
        lda $03B1
        cmp #$50                ; BVC
        bne no
        lda $03B3
        cmp #$A9                ; LDA #
        bne no
        lda $03B5
        cmp #$A2                ; LDX #
        bne no
        lda $03B7
        cmp #$60                ; RTS
        bne no
        clc
        rts
no      lda #<m_noloci
        ldy #>m_noloci
        jsr lputs
        sec
        rts
.)

; mia_call : lance l'opération A et attend ; A/X = résultat, C=1 si erreur
mia_call
        sta MIA_OP
        jsr MIA_SPIN
        cpx #$80
        rts

; push_str : empile la chaîne A/Y (terminée par 0) à l'envers ; garde X
push_str
.(
        sta lptr
        sty lptr+1
        ldy #0
pslen   lda (lptr),y
        beq e
        iny
        bne pslen
e       tya
        beq done
p       dey
        lda (lptr),y
        sta MIA_XSTACK
        tya
        bne p
done    rts
.)

; usb_open : ouvre le fichier A/Y, X = drapeaux -> A = descripteur, C=1 si erreur
usb_open
        jsr push_str
        stx MIA_A
        lda #OP_OPEN
        jmp mia_call

; usb_close : ferme le descripteur A
usb_close
        sta MIA_A
        lda #OP_CLOSE
        jmp mia_call

; usb_read : lit 128 octets au plus du descripteur A dans iobuf
;   -> A = octets lus (0 : fin du fichier), C=1 si erreur
usb_read
.(
        sta MIA_A
        lda #0                  ; compte (16 bits) : poids fort d'abord
        sta MIA_XSTACK
        lda #128
        sta MIA_XSTACK
        lda #OP_READ
        jsr mia_call
        bcs r
        sta lcnt
        ldy #0
l       cpy lcnt
        beq d
        lda MIA_XSTACK
        sta iobuf,y
        iny
        bne l
d       lda lcnt
        clc
r       rts
.)

; usb_write : écrit X octets de iobuf (1 à 128) sur le descripteur A
;   -> A = octets écrits, C=1 si erreur
usb_write
.(
        sta MIA_A
        txa
        tay
p       dey
        lda iobuf,y
        sta MIA_XSTACK
        tya
        bne p
        lda #OP_WRITE
        jmp mia_call
.)

; usb_opendir : ouvre le répertoire A/Y -> A = descripteur, C=1 si erreur
usb_opendir
        jsr push_str
        lda #OP_OPENDIR
        jmp mia_call

; usb_readdir : entrée suivante du répertoire A -> dirent (72 octets :
;   +0 descripteur, +2 nom (64, 0 à la fin ; vide après la dernière),
;   +66 attributs FAT ($10 répertoire, $02 caché, $04 système),
;   +68 taille sur 4 octets). C=1 si erreur.
usb_readdir
.(
        sta MIA_A
        lda #OP_READDIR
        jsr mia_call
        bcs r
        ldy #0
l       lda MIA_XSTACK
        sta dirent,y
        iny
        cpy #72
        bne l
        clc
r       rts
.)

usb_closedir
        sta MIA_A
        lda #OP_CLOSEDIR
        jmp mia_call

; usb_err : « Erreur USB nn : explication » d'après $03AD
usb_err
.(
        lda MIA_ERRNO
        sta lcnt
        lda #<m_uerr
        ldy #>m_uerr
        jsr lputs
        lda lcnt
        jsr pbyte
        ldx #0
f       lda e_code,x
        beq nl
        cmp lcnt
        beq hit
        inx
        bne f
hit     txa
        asl
        tax
        lda e_msg,x
        ldy e_msg+1,x
        jsr lputs
nl      jmp lcrlf
.)

; pbyte : affiche A en décimal
pbyte   sta num
        lda #0
        sta num+1
        sta num+2
        sta num+3
        ; (suite dans pnum, largeur 0)

; pnum : affiche num (4 octets, détruit) en décimal, cadré à droite sur
;   A colonnes (0 : sans espaces)
pnum
.(
        sta lwid
        ldx #0                  ; chiffre (0-9)
        ldy #0                  ; puissance de 10 (pas de 4)
dig     lda #"0"
        sta numbuf,x
sub     sec
        lda num
        sbc p10,y
        sta lt0
        lda num+1
        sbc p10+1,y
        sta lt1
        lda num+2
        sbc p10+2,y
        sta lt2
        lda num+3
        sbc p10+3,y
        bcc nxt
        sta num+3
        lda lt2
        sta num+2
        lda lt1
        sta num+1
        lda lt0
        sta num
        inc numbuf,x
        bne sub
nxt     iny
        iny
        iny
        iny
        inx
        cpx #10
        bne dig
        ldx #0                  ; premier chiffre utile (le dernier au moins)
z       lda numbuf,x
        cmp #"0"
        bne nz
        inx
        cpx #9
        bne z
nz      stx lt0
        lda #10
        sec
        sbc lt0
        sta lt1                 ; nombre de chiffres
pad     lda lt1
        cmp lwid
        bcs out
        lda #" "
        jsr lputc
        inc lt1
        bne pad
out     ldx lt0
o       lda numbuf,x
        jsr lputc
        inx
        cpx #10
        bne o
        rts
.)

p10     .byt $00,$CA,$9A,$3B, $00,$E1,$F5,$05, $80,$96,$98,$00
        .byt $40,$42,$0F,$00, $A0,$86,$01,$00, $10,$27,$00,$00
        .byt $E8,$03,$00,$00, $64,$00,$00,$00, $0A,$00,$00,$00
        .byt $01,$00,$00,$00

; lputc : affiche A (garde A, X, Y)
lputc
.(
        sta lsav
        pha
        txa
        pha
        tya
        pha
        lda lsav
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts
.)

lcrlf   lda #13
        jsr lputc
        lda #10
        jmp lputc

; lputs : affiche la chaîne A/Y terminée par 0
lputs
.(
        sta lptr
        sty lptr+1
        ldy #0
l       lda (lptr),y
        beq d
        jsr lputc
        iny
        bne l
d       rts
.)

; get_args : paramètres tels que tapés (casse d'origine) -> args, 0 à la
;   fin. La ligne d'origine (ORIG_LINE) finit par les paramètres, dont
;   TAIL donne la longueur ; à défaut, TAIL (en majuscules).
get_args
.(
        ldx #0
f       lda ORIG_LINE,x
        beq e
        inx
        bne f
e       txa
        sec
        sbc TAIL
        bcc up
        tax
        ldy #0
c       lda ORIG_LINE,x
        sta args,y
        beq d
        inx
        iny
        bne c
up      ldy #0
c2      lda TAIL+1,y
        sta args,y
        beq d
        iny
        cpy #127
        bne c2
        lda #0
        sta args,y
d       rts
.)

; skipsp / skipw : saute les espaces / le mot à partir de args,X
skipsp
.(
l       lda args,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)
skipw
.(
l       lda args,x
        beq r
        cmp #" "
        beq r
        inx
        bne l
r       rts
.)

; =====================================================================
;  Répertoire courant, chemins et supports (docs/usb.md § 2.1)
;
;  Le répertoire courant de CP/A est dans le fichier 0:CPA.CWD de la
;  mémoire interne du LOCI : le chemin (« 2:/JEUX/ORIC »), puis la
;  description du support (texte du LOCI après « 2: », « MSC 14.9 GB
;  SanDisk  Cruzer Blade    rev 1.00 »), une ligne chacun. cw_get le
;  lit dans cwd et cwdesc (sans fichier : la racine de la première clé),
;  et retrouve une clé changée de numéro d'après sa description.
;  lpath fait d'un nom tapé un chemin complet (apath), relatif au
;  répertoire lp_base (cwd par défaut).
;  Supports : la liste des appareils du LOCI (opendir d'un chemin vide)
;  donne « 0: Internal storage [15MB] », puis « n: MSC ... » pour un
;  stockage USB ; les autres appareils (clavier, Pico W) sont sautés.
; =====================================================================

; cw_get : répertoire courant dans cwd (et cwdesc) ; appeler après mia_chk
cw_get
.(
        lda #0
        sta cwd
        sta cwdesc
        lda #<cwd
        sta lp_base
        lda #>cwd
        sta lp_base+1
        lda #<cw_fn
        ldy #>cw_fn
        ldx #O_RDONLY
        jsr usb_open
        bcc yopn
        jmp ychk
yopn     sta cw_fd
        lda #0
        sta cw_ln
        sta cw_ix
yrd      lda cw_fd
        jsr usb_read
        bcs yeof
        cmp #0
        beq yeof
        ldy #0
ybl      lda iobuf,y
        cmp #13
        beq ynx
        cmp #10
        bne ych
        inc cw_ln
        lda #0
        sta cw_ix
        beq ynx
ych      ldx cw_ix
        cpx #127
        bcs ynx
        pha
        lda cw_ln
        beq yl0
        cmp #1
        bne yl2
        pla
        cpx #63
        bcs ynx
        sta cwdesc,x
        lda #0
        sta cwdesc+1,x
        inc cw_ix
        bne ynx
yl0      pla
        sta cwd,x
        lda #0
        sta cwd+1,x
        inc cw_ix
        bne ynx
yl2      pla
ynx      iny
        cpy lcnt
        bne ybl
        jmp yrd
yeof     lda cw_fd
        jsr usb_close
        lda cwd                 ; « n:/... » seulement
        sec
        sbc #"0"
        cmp #10
        bcs ybad
        lda cwd+1
        cmp #":"
        bne ybad
        lda cwd+2
        cmp #"/"
        beq ychk
ybad     lda #0
        sta cwd
ychk     lda cwd
        cmp #"0"
        bne ycks
        rts                     ; mémoire interne : toujours là
ycks     lda #$FF
        sta dv_first
        sta dv_found
        jsr dv_open
        bcs ydvd
ysc      jsr dv_next
        bcs ydce
        cmp #0
        beq ysc
        ldx dv_first
        bpl ynf
        sta dv_first
ynf      ldx cwd
        beq ysc
        jsr dv_same
        bne ysc
        lda dv_n
        sta dv_found
        ora #"0"
        cmp cwd
        bne ysc                  ; même clé, autre numéro : on cherche encore
ydce     jsr dv_close
ydvd     lda cwd
        beq ydflt
        lda dv_found
        bmi yabs
        ora #"0"
        cmp cwd
        beq yrt
        sta cwd                 ; clé renumérotée
        lda #<m_found
        ldy #>m_found
        jsr lputs
        lda cwd
        jsr lputc
        lda #":"
        jsr lputc
        jsr lcrlf
        jmp cw_write
yabs     lda #<m_absent          ; « Cle absente : SanDisk Cruzer »
        ldy #>m_absent
        jsr lputs
        lda #<cwdesc
        ldy #>cwdesc
        jsr dv_parse
        lda #<dv_name
        ldy #>dv_name
        jsr lputs
        jsr lcrlf
ydflt    lda #0
        sta cwdesc
        lda dv_first
        bmi ynone
        ora #"0"
        sta cwd
        lda #":"
        sta cwd+1
        lda #"/"
        sta cwd+2
        lda #0
        sta cwd+3
yrt      rts
ynone    lda #"/"                ; aucune clé : « / », le LOCI répondra
        sta cwd
        lda #0
        sta cwd+1
        rts
.)

; cw_put : le chemin A/Y (complet) devient le répertoire courant :
;   cwd, description du support, fichier 0:CPA.CWD (rien n'est écrit si
;   le répertoire ne change pas)
cw_put
.(
        sta lptr
        sty lptr+1
        ldy #0
ycq      lda (lptr),y
        cmp cwd,y
        bne ydif
        iny
        cmp #0
        bne ycq
        rts
ydif     ldy #0
ycp      lda (lptr),y
        sta cwd,y
        beq ycd
        iny
        cpy #127
        bne ycp
        lda #0
        sta cwd,y
ycd      lda #0
        sta cwdesc
        jsr dv_open
        bcs ywr
ysc      jsr dv_next
        bcs yscd
        ora #"0"
        cmp cwd
        bne ysc
        ldx #0
ydc      lda dirent+5,x
        sta cwdesc,x
        beq yscd
        inx
        cpx #63
        bne ydc
        lda #0
        sta cwdesc,x
yscd     jsr dv_close
ywr      ; (suite dans cw_write)
.)

; cw_write : écrit cwd et cwdesc dans 0:CPA.CWD
cw_write
.(
        lda #<cw_fn
        ldy #>cw_fn
        ldx #O_WRONLY+O_CREAT+O_TRUNC
        jsr usb_open
        bcs yrt
        sta cw_fd
        ldx #0
yc1      lda cwd,x
        beq ye1
        sta iobuf,x
        inx
        bpl yc1
ye1      txa
        beq ys2
        lda cw_fd
        jsr usb_write
ys2      lda #13
        sta iobuf
        lda #10
        sta iobuf+1
        ldx #2
        ldy #0
yc2      lda cwdesc,y
        beq ye2
        sta iobuf,x
        inx
        iny
        bne yc2
ye2      lda #13
        sta iobuf,x
        inx
        lda #10
        sta iobuf,x
        inx
        lda cw_fd
        jsr usb_write
        lda cw_fd
        jmp usb_close
yrt      rts
.)

; dv_open : liste des appareils du LOCI -> C=1 si refusée
dv_open
.(
        lda #<cw_nul            ; chemin vide
        ldy #>cw_nul
        jsr usb_opendir
        sta dv_fd
        rts
.)

; dv_next : support suivant -> A = dv_n = numéro (0 : mémoire interne),
;   texte du LOCI après « n: » dans dirent+5 ; C=1 à la fin
dv_next
.(
ylp      lda dv_fd
        jsr usb_readdir
        bcs yrt
        lda dirent+2
        beq yend
        sec
        sbc #"0"
        cmp #10
        bcs ylp
        sta dv_n
        lda dirent+3
        cmp #":"
        bne ylp
        lda dv_n
        beq yok                  ; « 0: Internal storage [15MB] »
        ldx #3                  ; « MSC » et un chiffre : stockage USB
yms      lda dirent+5,x
        cmp m_msc,x
        bne ylp
        dex
        bpl yms
        lda dirent+9
        sec
        sbc #"0"
        cmp #10
        bcs ylp
yok      lda dv_n
        clc
        rts
yend     sec
yrt      rts
.)

dv_close
        lda dv_fd
        jmp usb_closedir

; dv_same : Z=1 si le texte du support (dirent+5) est cwdesc
dv_same
.(
        ldx #0
ylp      lda dirent+5,x
        cmp cwdesc,x
        bne yrt
        cmp #0
        beq yrt
        inx
        cpx #60
        bne ylp
yrt      rts
.)

; dv_parse : du texte d'un support A/Y (« MSC 14.9 GB SanDisk  Cruzer
;   Blade    rev 1.00 ») -> dv_name (« SanDisk Cruzer Blade », espaces
;   réduits) et dv_size (« 14.9 Go »)
dv_parse
.(
        sta lptr
        sty lptr+1
        ldy #4                  ; après « MSC »
        ldx #0
ysz      lda (lptr),y            ; nombre
        beq ye
        cmp #" "
        beq ysu
        sta dv_size,x
        inx
        iny
        cpx #6
        bne ysz
ysu      sta dv_size,x           ; espace, puis l'unité (GB -> Go)
        inx
        iny
        lda (lptr),y
        beq ye
        sta dv_size,x
        inx
        lda #UNIT_B
        sta dv_size,x
        inx
        iny
        iny
ye       lda #0
        sta dv_size,x
        ldx #0                  ; fabricant et modèle, jusqu'à « rev »
ynm      lda (lptr),y
        beq yne
        cmp #" "
        bne ych
        iny
        lda (lptr),y
        cmp #" "
        beq ynm
        cmp #"r"
        bne ysp1
        iny
        lda (lptr),y
        dey
        cmp #"e"
        beq yne
ysp1     txa
        beq ynm
        lda #" "
        sta dv_name,x
        inx
        lda (lptr),y
ych      cpx #26
        bcs yne
        sta dv_name,x
        inx
        iny
        bne ynm
yne      lda #0
        sta dv_name,x
        rts
.)

; dv_fmt : ligne d'un support (dv_n, dirent) dans dv_line, sur A
;   colonnes (« 2: SanDisk Cruzer      14.9 Go ») : taille cadrée à
;   droite, nom coupé devant elle
dv_fmt
.(
        sta lt0
        lda dv_n
        ora #"0"
        sta dv_line
        lda #":"
        sta dv_line+1
        ldx #2
        lda #" "
yf       sta dv_line,x
        inx
        cpx lt0
        bne yf
        lda #0
        sta dv_line,x
        lda dv_n
        bne yusb
        ldx #0                  ; mémoire interne
yc1      lda m_int,x
        sta dv_name,x
        beq yc1e
        inx
        bne yc1
yc1e     ldx #0
yc2      lda m_intsz,x
        sta dv_size,x
        beq ynm
        inx
        bne yc2
yusb     lda #<dirent+5
        ldy #>dirent+5
        jsr dv_parse
ynm      ldy #0                  ; longueur de la taille
yl      lda dv_size,y
        beq yle0
        iny
        bne yl
yle0     sty lt2
        lda lt0                 ; nom : de la colonne 3 jusqu'à la taille
        clc
        sbc lt2
        sta lt1
        ldx #3
        ldy #0
yc3      lda dv_name,y
        beq ysz
        cpx lt1
        bcs ysz
        sta dv_line,x
        inx
        iny
        bne yc3
ysz      ldy lt2                 ; taille : à droite
yle      ldx lt0
yc4      dey
        bmi yrt
        dex
        lda dv_size,y
        sta dv_line,x
        jmp yc4
yrt      rts
.)

; lpath : chemin complet, dans apath, du nom A/Y (fini par 0 ou un
;   espace), relatif au répertoire lp_base (cwd) : « nom », « rep/nom »,
;   « /rep » (depuis la racine du support), « 2:/rep », « 0:nom » (sur
;   ce support), « .. » ; C=1 (message) si plus de 127 caractères
lpath
.(
        sta lp_in
        sty lp_in+1
        sta lptr
        sty lptr+1
        ldy #0
        lda (lptr),y
        sta lp_c0
        sec
        sbc #"0"
        cmp #10
        bcs ynsup
        iny
        lda (lptr),y
        cmp #":"
        bne ynsup0
        dey
        lda (lptr),y            ; « n: » : racine de ce support
        sta apath
        lda #":"
        sta apath+1
        lda #"/"
        sta apath+2
        ldx #3
        ldy #2
        bne ycomps
ynsup0   ldy #0
ynsup    lda lp_base             ; répertoire de base
        sta lptr
        lda lp_base+1
        sta lptr+1
        lda lp_c0
        ldx #0
        ldy #0
        cmp #"/"
        bne ylprl
yr1      lda (lptr),y            ; « /... » : racine du support de base
        beq ynob
        sta apath,x
        inx
        iny
        cmp #"/"
        bne yr1
        ldy #0
        beq ycomps
ylprl    lda (lptr),y
        beq yrle
        sta apath,x
        inx
        iny
        bne ylprl
yrle     ldy #0
        txa
        bne ycomps
ynob     ldx #0                  ; base sans « / » : « / »
        lda #"/"
        sta apath
        inx
ycomps   stx lt0                 ; longueur d'apath
        sty lt1                 ; position dans le nom
        lda lp_in
        sta lptr
        lda lp_in+1
        sta lptr+1
        ldx #0                  ; racine : jusqu'au premier « / » compris
yrt0     lda apath,x
        inx
        cmp #"/"
        bne yrt0
        stx lt2
ycl      ldy lt1
ysk      lda (lptr),y
        cmp #"/"
        bne yns
        iny
        bne ysk
yns      jsr lp_end
        beq ydone
        sty lt1
        cmp #"."
        bne yapp
        iny
        lda (lptr),y
        jsr lp_end
        beq ydot
        cmp #"."
        bne yapp0
        iny
        lda (lptr),y
        jsr lp_end
        bne yapp0
        sty lt1                 ; « .. » : un répertoire plus haut
        ldx lt0
yup      cpx lt2
        beq yupk
        dex
        lda apath,x
        cmp #"/"
        bne yup
        cpx lt2
        bcs yupk
        ldx lt2
yupk     stx lt0
        jmp ycl
ydot     sty lt1                 ; « . »
        jmp ycl
yapp0    ldy lt1
yapp     ldx lt0
        lda apath-1,x
        cmp #"/"
        beq ya1
        lda #"/"
        sta apath,x
        inx
ya1      lda (lptr),y
        jsr lp_end
        beq ya2
        cpx #127
        bcs ylong
        sta apath,x
        inx
        iny
        bne ya1
ya2      stx lt0
        sty lt1
        jmp ycl
ydone    ldx lt0
        lda #0
        sta apath,x
        clc
        rts
ylong    lda #<m_long
        ldy #>m_long
        jsr lputs
        sec
        rts
.)

; lpath_a : lpath du mot args,X
lpath_a
        txa
        clc
        adc #<args
        pha
        lda #>args
        adc #0
        tay
        pla
        jmp lpath

; lp_end : Z=1 si A finit un élément du chemin (0, espace, « / »)
lp_end
        cmp #0
        beq lpe
        cmp #" "
        beq lpe
        cmp #"/"
lpe     rts

; lp_last : X = début du dernier élément d'apath (après le dernier
;   « / ») ; C=1 s'il contient un joker (* ou ?)
lp_last
.(
        ldy #0
        ldx #0
ylp      lda apath,y
        beq ye
        iny
        cmp #"/"
        bne ylp
        tya
        tax
        bne ylp
ye       stx lt0
yw       lda apath,x
        beq yno
        inx
        cmp #"*"
        beq yy
        cmp #"?"
        bne yw
yy       sec
        ldx lt0
        rts
yno      clc
        ldx lt0
        rts
.)

; lupc : A en majuscule
lupc
        cmp #"a"
        bcc lu_r
        cmp #"z"+1
        bcs lu_r
        and #$DF
lu_r    rts

cw_fn   .asc "0:CPA.CWD"
cw_nul  .byt 0
m_msc   .asc "MSC "

; (messages : loci.msg, que le programme inclut juste avant ce fichier :
;  ASM ne permet qu'un niveau d'inclusion)

; tampons, après le programme (hors du fichier .COM)
lib_end
args    = lib_end
iobuf   = lib_end+128
dirent  = lib_end+256
numbuf  = lib_end+328
cwd     = lib_end+338   ; répertoire courant (128)
cwdesc  = lib_end+466   ;   description de son support (64)
apath   = lib_end+530   ; chemin complet fait par lpath (128)
dv_line = lib_end+658   ; ligne d'un support (40)
dv_name = lib_end+698   ;   fabricant et modèle (28)
dv_size = lib_end+726   ;   taille (10)
lp_nm   = lib_end+736   ; lp_find : nom trouvé (64)
lp_base = lib_end+800   ; (2) répertoire de base de lpath
lp_in   = lib_end+802   ; (2)
lp_c0   = lib_end+804
cw_fd   = lib_end+805
cw_ln   = lib_end+806
cw_ix   = lib_end+807
dv_first = lib_end+808
dv_found = lib_end+809
dv_n    = lib_end+810
dv_fd   = lib_end+811
lp_sv   = lib_end+812
lp_sx   = lib_end+813
lp_p    = lib_end+814
lp_fd   = lib_end+815
lp_n    = lib_end+816
wm_p0   = lib_end+817
wm_st   = lib_end+818
wm_mk   = lib_end+819
wm_c    = lib_end+820
lib_free = lib_end+821  ; premier octet libre pour le programme
