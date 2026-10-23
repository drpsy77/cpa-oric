; logovoc.msg : vocabulaire de LOGO.COM en français (en anglais : progs/msg/en/logovoc.msg).
; Généré par tools/gen_logo_voc.py — ne pas éditer à la main.
; Tables rangées par première lettre (ix_build) : nom, 0, adresse de la routine.
prims
        .asc "AVANCE",0
        .word p_av
        .asc "AV",0
        .word p_av
        .asc "ATTENDS",0
        .word p_attends
        .asc "ATTENDSSON",0
        .word p_attson
        .asc "AIDE",0
        .word p_aide
        .asc "AUREVOIR",0
        .word p_quitte
        .asc "BAISSECRAYON",0
        .word p_bc
        .asc "BC",0
        .word p_bc
        .asc "BRUITV",0
        .word p_bruitv
        .asc "CACHETORTUE",0
        .word p_ct
        .asc "CT",0
        .word p_ct
        .asc "CERCLE",0
        .word p_cercle
        .asc "CHARGE",0
        .word p_charge
        .asc "CHARGEIMAGE",0
        .word p_cimage
        .asc "DROITE",0
        .word p_dr
        .asc "DR",0
        .word p_dr
        .asc "DONNE",0
        .word p_donne
        .asc "EXECUTE",0
        .word p_exec
        .asc "EXEC",0
        .word p_exec
        .asc "ECRANTEXTE",0
        .word p_etexte
        .asc "EDITE",0
        .word p_edite
        .asc "ECRANMIXTE",0
        .word p_emixte
        .asc "ETIQUETTE",0
        .word p_etiq
        .asc "ECRIS",0
        .word p_ecris
        .asc "EC",0
        .word p_ecris
        .asc "ENVELOPPE",0
        .word p_env
        .asc "ENSEMBLE",0
        .word p_ensemble
        .asc "FIXECAP",0
        .word p_fcap
        .asc "FIXEXY",0
        .word p_fxy
        .asc "FIXECOULEUR",0
        .word p_fcoul
        .asc "FIXECURSEUR",0
        .word p_fixecur
        .asc "FIXECARECRAN",0
        .word p_fixecar
        .asc "GAUCHE",0
        .word p_ga
        .asc "GA",0
        .word p_ga
        .asc "GOMME",0
        .word p_gomme
        .asc "INVERSE",0
        .word p_inv
        .asc "LEVECRAYON",0
        .word p_lc
        .asc "LC",0
        .word p_lc
        .asc "LISTE",0
        .word p_liste
        .asc "MONTRETORTUE",0
        .word p_mt
        .asc "MT",0
        .word p_mt
        .asc "MELANGE",0
        .word p_melange
        .asc "NETTOIE",0
        .word p_net
        .asc "ORIGINE",0
        .word p_orig
        .asc "OUBLIE",0
        .word p_oublie
        .asc "OUBLIETOUT",0
        .word p_oubtout
        .asc "POINT",0
        .word p_point
        .asc "PAVE",0
        .word p_pave
        .asc "POUR",0
        .word p_pour
        .asc "QUITTE",0
        .word p_quitte
        .asc "RENDS",0
        .word p_rends
        .asc "RECULE",0
        .word p_re
        .asc "RE",0
        .word p_re
        .asc "RECTANGLE",0
        .word p_rect
        .asc "REPETE",0
        .word p_repete
        .asc "SI",0
        .word p_si
        .asc "STOP",0
        .word p_stop
        .asc "SONF",0
        .word p_sonf
        .asc "SON",0
        .word p_son
        .asc "SILENCE",0
        .word p_silence
        .asc "SAUVE",0
        .word p_sauve
        .asc "SAUVEIMAGE",0
        .word p_simage
        .asc "TRAIT",0
        .word p_trait
        .asc "TAPE",0
        .word p_tape
        .asc "TITRES",0
        .word p_titres
        .asc "VIDEECRAN",0
        .word p_ve
        .asc "VE",0
        .word p_ve
        .asc "VIDETEXTE",0
        .word p_vt
        .asc "VT",0
        .word p_vt
        .byt 0
w_pour   .asc "POUR",0
w_fin    .asc "FIN",0
funcs
        .asc "ALLUME?",0
        .word f_allume
        .asc "ARCTAN",0
        .word f_atn
        .asc "ASCII",0
        .word f_ascii
        .asc "ARRONDI",0
        .word f_arrondi
        .asc "ABS",0
        .word f_abs
        .asc "CAP",0
        .word f_cap
        .asc "COS",0
        .word f_cos
        .asc "CAR",0
        .word f_car
        .asc "COMPTE",0
        .word f_compte
        .asc "CURSEUR",0
        .word f_curseur
        .asc "CARECRAN",0
        .word f_carecr
        .asc "DERNIER",0
        .word f_dernier
        .asc "DER",0
        .word f_dernier
        .asc "EXP",0
        .word f_exp
        .asc "ENT",0
        .word f_ent
        .asc "HASARD",0
        .word f_hasard
        .asc "ITEM",0
        .word f_item
        .asc "JOUE?",0
        .word f_joue
        .asc "LN",0
        .word f_ln
        .asc "LISLISTE",0
        .word f_lisliste
        .asc "LL",0
        .word f_lisliste
        .asc "LISMOT",0
        .word f_lismot
        .asc "LISCAR",0
        .word f_liscar
        .asc "LISTE",0
        .word f_liste
        .asc "LISTE?",0
        .word f_listep
        .asc "MOT",0
        .word f_mot
        .asc "MOT?",0
        .word f_motp
        .asc "MEMBRE?",0
        .word f_membrep
        .asc "NOMBRE?",0
        .word f_nombrep
        .asc "PHRASE",0
        .word f_phrase
        .asc "PH",0
        .word f_phrase
        .asc "PREMIER",0
        .word f_premier
        .asc "PR",0
        .word f_premier
        .asc "QUOTIENT",0
        .word f_quotient
        .asc "RACINE",0
        .word f_racine
        .asc "RESTE",0
        .word f_reste
        .asc "SIN",0
        .word f_sin
        .asc "SAUFPREMIER",0
        .word f_sp
        .asc "SP",0
        .word f_sp
        .asc "SAUFDERNIER",0
        .word f_sd
        .asc "SD",0
        .word f_sd
        .asc "TOUCHE?",0
        .word f_touche
        .asc "TOUCHE",0
        .word f_tkey
        .asc "VIDE?",0
        .word f_videp
        .asc "XCOR",0
        .word f_xcor
        .asc "YCOR",0
        .word f_ycor
        .byt 0
; commandes tapées par les menus ($18 : efface d'abord la ligne)
ty_charge .byt $18
          .asc "CHARGE ",$22,0
ty_sauve  .byt $18
          .asc "SAUVE ",$22,0
ty_edite  .byt $18
          .asc "EDITE ",$22,0
ty_cimg   .byt $18
          .asc "CHARGEIMAGE ",$22,0
ty_simg   .byt $18
          .asc "SAUVEIMAGE ",$22,0
ty_titres .byt $18
          .asc "TITRES",13,0
ty_oubtout .byt $18
          .asc "OUBLIETOUT",13,0
ty_quitte .byt $18
          .asc "QUITTE",13,0
ty_ve     .byt $18
          .asc "VE",13,0
ty_orig   .byt $18
          .asc "ORIGINE",13,0
ty_ct     .byt $18
          .asc "CT",13,0
ty_mt     .byt $18
          .asc "MT",13,0
ty_etxt   .byt $18
          .asc "ECRANTEXTE",13,0
ty_emix   .byt $18
          .asc "ECRANMIXTE",13,0
ty_lc     .byt $18
          .asc "LC",13,0
ty_aide   .byt $18
          .asc "AIDE",13,0
s_charge .asc "CHARGE ",$22,0
