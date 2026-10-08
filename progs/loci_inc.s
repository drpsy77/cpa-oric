; =====================================================================
;  loci_inc.s — accès aux fichiers de la clé USB du LOCI (bibliothèque
;  incluse à la fin de EXPORT, IMPORT et USBDIR ; jamais assemblée seule)
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
;  Tampons après la fin du programme : args, iobuf, dirent, numbuf, puis
;  lib_free, où le programme place les siens.
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
mia_chk
.(
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
        lda #0                  ; opération 0 : vide la pile d'échange
        sta MIA_OP
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

m_noloci .asc "LOCI absent : cle USB inaccessible",13,10,0
m_uerr  .asc "Erreur USB ",0
e_code  .byt 35,36,37,38,39,42,43,44,45,130,0
e_msg   .word m_e_nousb,m_e_nf,m_e_nf,m_e_name,m_e_deny,m_e_wp
        .word m_e_nousb,m_e_nousb,m_e_nousb,m_e_nf
m_e_nf  .asc " : introuvable",0
m_e_name .asc " : nom invalide",0
m_e_deny .asc " : refus (cle pleine ?)",0
m_e_wp  .asc " : cle protegee",0
m_e_nousb .asc " : pas de cle USB lisible",0

; tampons, après le programme (hors du fichier .COM)
lib_end
args    = lib_end
iobuf   = lib_end+128
dirent  = lib_end+256
numbuf  = lib_end+328
lib_free = lib_end+338  ; premier octet libre pour le programme
