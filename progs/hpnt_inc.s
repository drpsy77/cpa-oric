; =====================================================================
;  hpnt_inc.s — h_paint : le remplissage (pnt_inc.s) pour hires.inc.
;  Recopié avec pnt_inc.s dans HIRES.INC par tools/strip_inc.py
;  (marques ;#inc) ; inclus par les programmes qui dessinent avec
;  hires.inc et remplissent (GRAPHER), avant pnt_inc.s ; pas par LOGO,
;  qui a son propre appel. Jamais assemblé seul.
;    h_paint   remplit depuis (h_x1, h_y1) avec le crayon h_pm (0 gomme,
;              1 ou 2 trace), dans l'image de h_lines lignes
; =====================================================================
P_ZP    = $C2           ; page zéro de pnt_inc.s : hq de hires.inc
h_paint lda h_x1
        sta p_x
        lda h_y1
        sta p_y
        lda h_lines
        sta p_ny
        lda h_pm
        sta p_pen
        jmp paint
