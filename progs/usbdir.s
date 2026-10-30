; =====================================================================
;  USBDIR.COM — liste des fichiers de la clé USB du LOCI
;
;  USBDIR [chemin]
;    sans chemin : le répertoire courant de CP/A (docs/usb.md § 2.1) ;
;    JEUX un sous-répertoire, .. le parent, /JEUX depuis la racine du
;    support, 2:/JEUX sur la clé 2, 0: la mémoire interne du LOCI ;
;    *.DSK : les noms qui répondent au modèle (jokers * et ?)
;  USBDIR /S
;    les supports : 0: (mémoire interne) et les clés USB, avec leur
;    taille ; * : celui du répertoire courant
;  USBDIR /C [chemin]  (appelé par USBCD.BAT)
;    le répertoire devient le répertoire courant, écrit en retour ;
;    sans chemin : CMDER sur la clé, répertoires seuls (CHAIN)
;  Une ligne par fichier : nom (tel quel, minuscules comprises) et
;  taille en octets, <REP> pour un dossier ; à la fin, le chemin complet
;  listé et le nombre d'éléments. Les fichiers cachés ou système et ceux
;  dont le nom commence par un point (._X du Mac...) ne sont pas
;  montrés. ESC ou CTRL-C arrête la liste.
; =====================================================================

#include "cpa.inc"

fd      = $10
cnt     = $11           ; 2 octets : éléments montrés
len     = $13
wild    = $14           ; 1 : modèle à jokers
wpos    = $15           ;   son début dans apath

NAMEW   = 26            ; largeur de la colonne des noms

        *= $0500
start
.(
        jsr get_args
        ldx #0
        jsr skipsp
        stx len
        jsr mia_chk
        bcc lok
        rts
lok     jsr cw_get
        ldx len
        lda args,x
        cmp #"/"
        bne dir
        lda args+1,x
        and #$DF
        cmp #"C"
        beq opc
        cmp #"S"
        bne dir
        lda args+2,x
        beq sup
        cmp #" "
        bne dir
sup     jmp supports
opc     lda args+2,x            ; /C [chemin] : changer de répertoire
        beq cmder
        cmp #" "
        bne dir
        inx
        inx
        jsr skipsp
        lda args,x
        beq cmder
        jmp chdir
cmder   lda #<m_cmder           ; /C seul : CMDER, répertoires seuls
        ldy #>m_cmder
        ldx #F_CHAIN
        jmp BDOS
dir     jsr lpath_a
        bcc pok
        rts
pok     lda #0
        sta wild
        jsr lp_last
        bcc nw
        inc wild
        stx wpos
        jsr lp_cut
nw      lda #<apath
        ldy #>apath
        jsr usb_opendir
        php
        sta fd
        lda wild
        beq nwb
        jsr lp_back
nwb     plp
        bcc ook
        jmp usb_err
ook     lda #0
        sta cnt
        sta cnt+1

next    lda fd
        jsr usb_readdir
        bcc rok
        jsr usb_err
        jmp close
rok     lda dirent+2
        bne rk2
        jmp end                 ; nom vide : fin du répertoire
rk2     cmp #"."
        beq next
        lda dirent+66
        and #$06                ; caché ou système
        bne next
        lda wild
        beq show
        ldx wpos
        jsr wmatch
        bne next
show    ldy #0                  ; nom
pn      lda dirent+2,y
        beq pe
        jsr lputc
        iny
        cpy #64
        bne pn
pe      sty len
        cpy #NAMEW+1
        bcc pad
        jsr lcrlf               ; nom long : taille à la ligne
        lda #0
        sta len
pad     lda len                 ; colonne de la taille
        cmp #NAMEW
        bcs sz
        lda #" "
        jsr lputc
        inc len
        bne pad
sz      lda dirent+66
        and #$10
        beq file
        lda #<m_dir
        ldy #>m_dir
        jsr lputs
        jmp eol
file    ldx #3
cn      lda dirent+68,x
        sta num,x
        dex
        bpl cn
        lda #11
        jsr pnum
eol     jsr lcrlf
        inc cnt
        bne key
        inc cnt+1
key     jsr B_CONST             ; ESC ou CTRL-C : arrêt
        cmp #0
        bne kp
        jmp next
kp      jsr B_CONIN
        cmp #27
        beq end
        cmp #3
        beq end
        jmp next

end     lda #<apath             ; à la fin : chemin listé et nombre
        ldy #>apath
        jsr lputs
        lda #" "
        jsr lputc
        lda #":"
        jsr lputc
        ldx #0                  ; chemin long : le nombre à la ligne
pl      lda apath,x
        beq pls
        inx
        bne pl
pls     cpx #21
        bcc same
        jsr lcrlf
        jmp cnum
same    lda #" "
        jsr lputc
cnum    lda cnt
        sta num
        lda cnt+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        jsr pnum
        lda #<m_cnt
        ldy #>m_cnt
        jsr lputs
close   lda fd
        jmp usb_closedir
.)

; supports : USBDIR /S
; chdir : USBDIR /C chemin (X : début du chemin dans args). Le chemin
;   doit être un répertoire ; il devient le répertoire courant (fichier
;   0:CPA.CWD), qui est écrit en retour
chdir
.(
        jsr lpath_a
        bcc ok
        rts
ok      lda #<apath
        ldy #>apath
        jsr usb_opendir
        bcc od
        jmp usb_err
od      jsr usb_closedir
        lda #<apath
        ldy #>apath
        jsr cw_put
        bcc wok
        jmp usb_err             ; 0:CPA.CWD non écrit
wok     lda #<cwd
        ldy #>cwd
        jsr lputs
        jmp lcrlf
.)

m_cmder .asc "CMDER USB: /R",0

supports
.(
        jsr dv_open
        bcc lp
        jmp usb_err
lp      jsr dv_next
        bcs e
        lda #33
        jsr dv_fmt
        lda dv_n                ; * : support du répertoire courant
        ora #"0"
        cmp cwd
        bne pr
        lda cwd+1
        cmp #":"
        bne pr
        lda #" "
        sta dv_line+33
        lda #"*"
        sta dv_line+34
        lda #0
        sta dv_line+35
pr      lda #<dv_line
        ldy #>dv_line
        jsr lputs
        jsr lcrlf
        jmp lp
e       jmp dv_close
.)

#include "usbdir.msg"

#include "ljok_inc.s"
#include "lcwp_inc.s"
#include "loci.msg"         ; avant loci_inc.s, dont les tampons suivent la fin
#include "loci_inc.s"
