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
;  Le chemin complet est écrit d'abord, puis une ligne par fichier :
;  nom (tel quel, minuscules comprises) et taille en octets, <REP> pour
;  un dossier. Les fichiers cachés ou système et ceux dont le nom
;  commence par un point (._X du Mac...) ne sont pas montrés. ESC ou
;  CTRL-C arrête la liste.
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
        cmp #"S"
        bne dir
        lda args+2,x
        beq sup
        cmp #" "
        bne dir
sup     jmp supports
dir     jsr lpath_a
        bcc pok
        rts
pok     lda #<apath             ; le chemin d'abord
        ldy #>apath
        jsr lputs
        jsr lcrlf
        lda #0
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

end     lda cnt
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
#include "loci.msg"         ; avant loci_inc.s, dont les tampons suivent la fin
#include "loci_inc.s"
