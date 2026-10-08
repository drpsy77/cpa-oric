; =====================================================================
;  USBDIR.COM — liste des fichiers de la clé USB du LOCI
;
;  USBDIR [chemin]
;    sans chemin : la racine de la clé ; 1:/DOCS un dossier ; 0: la
;    mémoire interne du LOCI
;  Une ligne par fichier : nom (tel quel, minuscules comprises) et
;  taille en octets, <REP> pour un dossier. Les fichiers cachés ou
;  système et ceux dont le nom commence par un point (._X du Mac...)
;  ne sont pas montrés. ESC ou CTRL-C arrête la liste.
; =====================================================================

#include "cpa.inc"

fd      = $10
cnt     = $11           ; 2 octets : éléments montrés
len     = $13

NAMEW   = 26            ; largeur de la colonne des noms

        *= $0500
start
.(
        jsr get_args
        ldx #0
        jsr skipsp
        ldy #0
cl      lda args,x
        beq ce
        cmp #" "
        beq ce
        sta path,y
        inx
        iny
        cpy #100
        bne cl
ce      lda #0
        sta path,y
        cpy #0
        bne hasp
        lda #"/"                ; sans chemin : la racine
        sta path
        lda #0
        sta path+1
hasp    jsr mia_chk
        bcc open
        rts
open    lda #<path
        ldy #>path
        jsr usb_opendir
        bcc ook
        jmp usb_err
ook     sta fd
        lda #0
        sta cnt
        sta cnt+1

next    lda fd
        jsr usb_readdir
        bcc rok
        jsr usb_err
        jmp close
rok     lda dirent+2
        beq end                 ; nom vide : fin du répertoire
        cmp #"."
        beq next
        lda dirent+66
        and #$06                ; caché ou système
        bne next
        ldy #0                  ; nom
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

m_dir   .asc "      <REP>",0
m_cnt   .asc " element(s)",13,10,0

#include "loci_inc.s"

path    = lib_free      ; chemin (101)
