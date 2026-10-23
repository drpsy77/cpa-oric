; logovoc.msg : vocabulaire de LOGO.COM en anglais (en français : progs/msg/fr/logovoc.msg).
; Généré par tools/gen_logo_voc.py — ne pas éditer à la main.
; Tables rangées par première lettre (ix_build) : nom, 0, adresse de la routine.
prims
        .asc "BYE",0
        .word p_quitte
        .asc "BACK",0
        .word p_re
        .asc "BK",0
        .word p_re
        .asc "CIRCLE",0
        .word p_cercle
        .asc "CLEAN",0
        .word p_net
        .asc "CLEARSCREEN",0
        .word p_ve
        .asc "CS",0
        .word p_ve
        .asc "CLEARTEXT",0
        .word p_vt
        .asc "CT",0
        .word p_vt
        .asc "DOT",0
        .word p_point
        .asc "EDIT",0
        .word p_edite
        .asc "ED",0
        .word p_edite
        .asc "ENVELOPE",0
        .word p_env
        .asc "ERASE",0
        .word p_oublie
        .asc "ER",0
        .word p_oublie
        .asc "ERALL",0
        .word p_oubtout
        .asc "FORWARD",0
        .word p_av
        .asc "FD",0
        .word p_av
        .asc "FILLRECT",0
        .word p_pave
        .asc "HELP",0
        .word p_aide
        .asc "HIDETURTLE",0
        .word p_ct
        .asc "HT",0
        .word p_ct
        .asc "HOME",0
        .word p_orig
        .asc "IF",0
        .word p_si
        .asc "LOAD",0
        .word p_charge
        .asc "LOADPIC",0
        .word p_cimage
        .asc "LABEL",0
        .word p_etiq
        .asc "LEFT",0
        .word p_ga
        .asc "LT",0
        .word p_ga
        .asc "LINE",0
        .word p_trait
        .asc "MAKE",0
        .word p_donne
        .asc "MIX",0
        .word p_melange
        .asc "NOISE",0
        .word p_bruitv
        .asc "NOTE",0
        .word p_son
        .asc "OUTPUT",0
        .word p_rends
        .asc "OP",0
        .word p_rends
        .asc "PENDOWN",0
        .word p_bc
        .asc "PD",0
        .word p_bc
        .asc "PRINT",0
        .word p_ecris
        .asc "PR",0
        .word p_ecris
        .asc "PENERASE",0
        .word p_gomme
        .asc "PE",0
        .word p_gomme
        .asc "PENREVERSE",0
        .word p_inv
        .asc "PX",0
        .word p_inv
        .asc "PENUP",0
        .word p_lc
        .asc "PU",0
        .word p_lc
        .asc "PRINTOUT",0
        .word p_liste
        .asc "PO",0
        .word p_liste
        .asc "POTS",0
        .word p_titres
        .asc "QUIT",0
        .word p_quitte
        .asc "RIGHT",0
        .word p_dr
        .asc "RT",0
        .word p_dr
        .asc "RUN",0
        .word p_exec
        .asc "RECTANGLE",0
        .word p_rect
        .asc "REPEAT",0
        .word p_repete
        .asc "SPLITSCREEN",0
        .word p_emixte
        .asc "SS",0
        .word p_emixte
        .asc "SETHEADING",0
        .word p_fcap
        .asc "SETH",0
        .word p_fcap
        .asc "SETXY",0
        .word p_fxy
        .asc "SETCOLOR",0
        .word p_fcoul
        .asc "SETCURSOR",0
        .word p_fixecur
        .asc "SETCELL",0
        .word p_fixecar
        .asc "SHOWTURTLE",0
        .word p_mt
        .asc "ST",0
        .word p_mt
        .asc "STOP",0
        .word p_stop
        .asc "SILENCE",0
        .word p_silence
        .asc "SAVE",0
        .word p_sauve
        .asc "SAVEPIC",0
        .word p_simage
        .asc "TEXTSCREEN",0
        .word p_etexte
        .asc "TS",0
        .word p_etexte
        .asc "TOGETHER",0
        .word p_ensemble
        .asc "TO",0
        .word p_pour
        .asc "TONE",0
        .word p_sonf
        .asc "TYPE",0
        .word p_tape
        .asc "WAIT",0
        .word p_attends
        .asc "WAITSOUND",0
        .word p_attson
        .byt 0
w_pour   .asc "TO",0
w_fin    .asc "END",0
funcs
        .asc "ARCTAN",0
        .word f_atn
        .asc "ASCII",0
        .word f_ascii
        .asc "ABS",0
        .word f_abs
        .asc "BUTFIRST",0
        .word f_sp
        .asc "BF",0
        .word f_sp
        .asc "BUTLAST",0
        .word f_sd
        .asc "BL",0
        .word f_sd
        .asc "COS",0
        .word f_cos
        .asc "CHAR",0
        .word f_car
        .asc "COUNT",0
        .word f_compte
        .asc "CURSOR",0
        .word f_curseur
        .asc "CELL",0
        .word f_carecr
        .asc "DOT?",0
        .word f_allume
        .asc "EXP",0
        .word f_exp
        .asc "EMPTY?",0
        .word f_videp
        .asc "FIRST",0
        .word f_premier
        .asc "HEADING",0
        .word f_cap
        .asc "INT",0
        .word f_ent
        .asc "ITEM",0
        .word f_item
        .asc "KEY?",0
        .word f_touche
        .asc "KEY",0
        .word f_tkey
        .asc "LAST",0
        .word f_dernier
        .asc "LN",0
        .word f_ln
        .asc "LIST",0
        .word f_liste
        .asc "LIST?",0
        .word f_listep
        .asc "MEMBER?",0
        .word f_membrep
        .asc "NUMBER?",0
        .word f_nombrep
        .asc "PLAYING?",0
        .word f_joue
        .asc "QUOTIENT",0
        .word f_quotient
        .asc "ROUND",0
        .word f_arrondi
        .asc "RANDOM",0
        .word f_hasard
        .asc "READLIST",0
        .word f_lisliste
        .asc "RL",0
        .word f_lisliste
        .asc "READWORD",0
        .word f_lismot
        .asc "RW",0
        .word f_lismot
        .asc "READCHAR",0
        .word f_liscar
        .asc "RC",0
        .word f_liscar
        .asc "REMAINDER",0
        .word f_reste
        .asc "SENTENCE",0
        .word f_phrase
        .asc "SE",0
        .word f_phrase
        .asc "SQRT",0
        .word f_racine
        .asc "SIN",0
        .word f_sin
        .asc "WORD",0
        .word f_mot
        .asc "WORD?",0
        .word f_motp
        .asc "XCOR",0
        .word f_xcor
        .asc "YCOR",0
        .word f_ycor
        .byt 0
; commandes tapées par les menus ($18 : efface d'abord la ligne)
ty_charge .byt $18
          .asc "LOAD ",$22,0
ty_sauve  .byt $18
          .asc "SAVE ",$22,0
ty_edite  .byt $18
          .asc "EDIT ",$22,0
ty_cimg   .byt $18
          .asc "LOADPIC ",$22,0
ty_simg   .byt $18
          .asc "SAVEPIC ",$22,0
ty_titres .byt $18
          .asc "POTS",13,0
ty_oubtout .byt $18
          .asc "ERALL",13,0
ty_quitte .byt $18
          .asc "QUIT",13,0
ty_ve     .byt $18
          .asc "CS",13,0
ty_orig   .byt $18
          .asc "HOME",13,0
ty_ct     .byt $18
          .asc "HT",13,0
ty_mt     .byt $18
          .asc "ST",13,0
ty_etxt   .byt $18
          .asc "TEXTSCREEN",13,0
ty_emix   .byt $18
          .asc "SPLITSCREEN",13,0
ty_lc     .byt $18
          .asc "PU",13,0
ty_aide   .byt $18
          .asc "HELP",13,0
s_charge .asc "LOAD ",$22,0
