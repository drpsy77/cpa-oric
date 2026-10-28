; cmder.msg : barre de menus, messages et en-têtes de CMDER.COM en anglais
;   (le français est dans progs/msg/fr/cmder.msg, mêmes étiquettes).
;   Inclus par progs/cmder.s.
; Menus : .byt nombre d'articles, largeur (plus long libellé) ; it_sys,
; s_hide, s_show : 11 caractères copiés. m_t2, m_t2u : 18 caractères (en-tête
; d'une colonne en mode deux colonnes). gname : 7 caractères par genre.
; spos, spos2 : colonne du signe + ou - du tri dans les en-têtes (clés 1-4 :
; ordre du disque, nom, type, taille ; puis la même chose pour la clé USB).

bar     .byt 4
        .word mn_f, mn_m, mn_t, mn_v

mn_f    .byt 14,16
        .asc "File",0
        .asc "View         RET",0
        .byt MA_TYPE
        .word c81
        .asc "Copy...       ^C",0
        .byt MA_TYPE
        .word c82
        .asc "Copy as text...",0
        .byt MA_TYPE
        .word c9e
        .asc "Move...       ^X",0
        .byt MA_TYPE
        .word c83
        .asc "Rename...     ^N",0
        .byt MA_TYPE
        .word c84
        .asc "Erase        DEL",0
        .byt MA_TYPE
        .word c85
        .asc "Duplicate...  ^U",0
        .byt MA_TYPE
        .word ca0
        .asc "Mount...      ^O",0
        .byt MA_TYPE
        .word ca1
        .asc "Attributes... ^A",0
        .byt MA_TYPE
        .word c86
        .asc "Info           ?",0
        .byt MA_TYPE
        .word c87
        .asc "Print list",0
        .byt MA_TYPE
        .word c99
        .asc "Drive...      ^L",0
        .byt MA_TYPE
        .word c88
        .asc "Reread        ^R",0
        .byt MA_TYPE
        .word c89
        .asc "Quit          ^Q",0
        .byt MA_TYPE
        .word c8a

mn_m    .byt 6,14
        .asc "Mark",0
        .asc "Mark       SPC",0
        .byt MA_TYPE
        .word c8b
        .asc "Mark...      +",0
        .byt MA_TYPE
        .word c8c
        .asc "Unmark...    -",0
        .byt MA_TYPE
        .word c8d
        .asc "Invert       *",0
        .byt MA_TYPE
        .word c8e
        .asc "All",0
        .byt MA_TYPE
        .word c8f
        .asc "None",0
        .byt MA_TYPE
        .word c90

mn_t    .byt 4,14
        .asc "Sort",0
        .asc "Disk order   1",0
        .byt MA_TYPE
        .word c91
        .asc "Name         2",0
        .byt MA_TYPE
        .word c92
        .asc "Type         3",0
        .byt MA_TYPE
        .word c93
        .asc "Size         4",0
        .byt MA_TYPE
        .word c94

mn_v    .byt 9,16
        .asc "View",0
        .asc "Filter...      /",0
        .byt MA_TYPE
        .word c95
        .asc "No filter",0
        .byt MA_TYPE
        .word c96
        .asc "Directories only",0
        .byt MA_TYPE
        .word c9f
it_sys  .asc "Hide SYS   ",0
        .byt MA_TYPE
        .word c97
        .asc "Exact size    ^E",0
        .byt MA_TYPE
        .word c98
        .asc "Not on other",0
        .byt MA_TYPE
        .word c9a
        .asc "Zoom          ^Z",0
        .byt MA_TYPE
        .word c9b
        .asc "Swap          ^W",0
        .byt MA_TYPE
        .word c9c
        .asc "Other col.    ^I",0
        .byt MA_TYPE
        .word c9d

s_hide  .asc "Hide SYS   "
s_show  .asc "Show SYS   "

m_cols  .asc "  NAME     TYP    SIZE RS   N KIND",0
m_help  .asc "FUNCT menus  SPC mark  ESC quit",0
m_nodrv .asc "drive missing or unreadable",0
m_fic   .asc " fls",0
m_lib   .asc "K free",0
m_marks .asc " marked : ",0
m_oct   .asc " bytes",0
m_sep   .asc " : ",0
m_enr   .asc " rec, ",0
m_blk   .asc " block(s)",0
m_none  .asc "No file",0
m_vmore .asc "-- SPC : more, ESC : back --",0
m_vend  .asc "-- End of file : press a key --",0
m_rerr  .asc "File unreadable",0
m_era   .asc "Erase ",0
m_cop   .asc "Copy ",0
m_mov   .asc "Move ",0
m_nfic  .asc " files",0
m_yn    .asc " (Y/N) ?",0
m_ynt   .asc " (Y/N/A) ?",0
m_to    .asc " to : ",0
m_erased .asc " erased",0
m_copied .asc " copied",0
m_moved .asc " moved",0
m_prot  .asc " protected",0
m_illis .asc " unreadable",0
m_bad   .asc "Bad name",0
m_one   .asc "A name : one file only",0
m_one1  .asc "One file at a time",0
m_nodst .asc "Destination unreadable",0
m_dirf  .asc "Directory full",0
m_full  .asc "Disk full : copy erased",0
m_repl  .asc "Replace ",0
m_isrc  .asc "SOURCE in ",0
m_idst  .asc "DESTINATION in ",0
m_key   .asc ", press a key",0
m_keyst .asc " (ESC : stay)",0
m_err   .asc "Error, ",0
m_same  .asc "Same as the source : go on (Y/N) ?",0
m_ioerr .asc "Disk error : check the disk",0
m_t2    .asc " NAME     TYP   KB"
m_twod  .asc "Two different drives",0
m_twou  .asc "Only one USB column",0
m_usbonly .asc "USB stick only",0
m_nosup .asc "Choose a device first",0
m_sups  .asc "devices",0
m_fonly .asc "Files only",0
m_imgm  .asc "Image mounted in ",0
m_ofkey .asc " from the stick",0
m_dupq  .asc "Duplicate as : ",0
m_dupok .asc "Duplicated",0
m_tmpn  .asc "~CPADUP.TMP",0
m_ko    .asc " KB",0
m_mntq  .asc "Mount in : ",0
m_notimg .asc "Not an image (.DSK or .TAP)",0
m_sysa  .asc "A: refused (system disk)",0
m_usb   .asc "USB:",0
m_usbro .asc "USB stick : no attributes",0
m_usberr .asc "USB error (key missing or full ?)",0
m_noloci2 .asc "No LOCI : USB key unreachable",0
m_refus .asc " refused",0
m_colsu .asc "  NAME                          SIZE",0
m_t2u   .asc " NAME           KB"
m_rep   .asc "<DIR>",0
m_ucut  .asc " +",0
m_one2  .asc "One column only",0
m_prt   .asc "Printing... (ESC stops)",0
m_prtok .asc "List printed",0
m_libre .asc "Free ",0
m_req   .asc "K, needed ",0
m_ynk   .asc "K : Y/N ?",0
m_non   .asc "No ! ",0
m_rdir  .asc "Reading the directory...",0
m_cpy   .asc "Copy : ",0
m_incpl .asc " incomplete",0
m_esc   .asc "Interrupted",0
m_newn  .asc "New name : ",0
m_taken .asc "Name already used",0
m_ro    .asc "File protected (R/O)",0
m_roorig .asc "Original protected (R/O)",0
m_renok .asc "Renamed",0
m_samedrv .asc "Same drive only",0
m_attq  .asc "Attributes (R S) : ",0
m_attbad .asc "R and S only",0
m_attok .asc "Attributes changed",0
m_markq .asc "Mark : ",0
m_unmq  .asc "Unmark : ",0
m_filtq .asc "Filter : ",0
m_drvq  .asc "Drive (A-D) : ",0
m_drvbad .asc "Drive A to D",0
m_wait  .asc "Exact sizes... (ESC stops)",0
m_exok  .asc "Exact sizes",0

gname   .asc "       Prog   Script Grapher"
        .asc "Logo   Source Text   Config "
        .asc "Image  Anim   Symb.  Temp   Disk   "

spos    .byt 29,6,14,22
        .byt 0,6,6,31           ; (clé USB)
spos2   .byt 0,5,13,15
        .byt 0,5,5,15           ; (clé USB)

K_YES   = "Y"           ; touche Oui (Yes)
K_ALL   = "A"           ; touche Tous (All)
