; Banc d'essai de progs/fp_inc.s pour tools/test_fp.py (6502 simulé).
; Chaque entrée de la table appelle une routine sur des nombres rangés en
; mémoire : A en $0280, B en $0288, résultat en $0290.
; putc écrit en $0300 (index en $02FF) ; les erreurs mettent un code en
; $02FE (1 trop grand, 2 division par zéro, 3 calcul impossible) et sautent à $0203 (arrêt).
FP_ZP   = $90
NA      = $0280
NB      = $0288
NR      = $0290

        *= $1000
        jmp t_add               ; $1000
        jmp t_sub               ; $1003
        jmp t_mul               ; $1006
        jmp t_div               ; $1009
        jmp t_cmp               ; $100C
        jmp t_itof              ; $100F
        jmp t_toint             ; $1012
        jmp t_trunc             ; $1015
        jmp t_rnd               ; $1018
        jmp t_parse             ; $101B
        jmp t_print             ; $101E
        jmp t_sqrt              ; $1021
        jmp t_exp               ; $1024
        jmp t_ln                ; $1027
        jmp t_sin               ; $102A
        jmp t_cos               ; $102D
        jmp t_atn               ; $1030
        jmp t_sind              ; $1033
        jmp t_cosd              ; $1036
        jmp t_atnd              ; $1039

ldab    lda #<NA                ; ARG = A, FAC = B
        sta fpt
        lda #>NA
        sta fpt+1
        jsr fp_ldfac
        jsr fp_toarg
lda_b   lda #<NB
        sta fpt
        lda #>NB
        sta fpt+1
        jmp fp_ldfac
lda_a   lda #<NA
        sta fpt
        lda #>NA
        sta fpt+1
        jmp fp_ldfac
str     lda #<NR
        sta fpt
        lda #>NR
        sta fpt+1
        jmp fp_stfac

t_add   jsr ldab
        jsr fp_add
        jmp str
t_sub   jsr ldab
        jsr fp_sub
        jmp str
t_mul   jsr ldab
        jsr fp_mul
        jmp str
t_div   jsr ldab
        jsr fp_div
        jmp str
t_cmp   jsr ldab
        jsr fp_cmp
        sta NR
        rts
t_itof  lda $0298
        ldy $0299
        jsr fp_itof
        jmp str
t_toint jsr lda_a
        jsr fp_toint
        sta NR
        sty NR+1
        lda #0
        rol
        sta NR+2
        rts
t_trunc jsr lda_a
        jsr fp_trunc
        jmp str
t_rnd   jsr lda_a
        jsr fp_rnd
        jmp str
t_parse lda #$00
        sta fpt
        lda #$04
        sta fpt+1
        jsr fp_parse
        sty $0295
        jmp str
t_print jsr lda_a
        jmp fp_print

t_sqrt  jsr lda_a
        jsr fp_sqrt
        jmp str
t_exp   jsr lda_a
        jsr fp_exp
        jmp str
t_ln    jsr lda_a
        jsr fp_ln
        jmp str
t_sin   jsr lda_a
        jsr fp_sin
        jmp str
t_cos   jsr lda_a
        jsr fp_cos
        jmp str
t_atn   jsr lda_a
        jsr fp_atn
        jmp str
t_sind  jsr lda_a
        jsr fp_sind
        jmp str
t_cosd  jsr lda_a
        jsr fp_cosd
        jmp str
t_atnd  jsr lda_a
        jsr fp_atnd
        jmp str

putc    stx $02FD
        ldx $02FF
        sta $0300,x
        inc $02FF
        ldx $02FD
        rts
fp_err_big
        lda #1
        sta $02FE
        jmp $0203
fp_err_div
        lda #2
        sta $02FE
        jmp $0203
fp_err_dom
        lda #3
        sta $02FE
        jmp $0203

#include "../progs/fp_inc.s"
