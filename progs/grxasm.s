;  =====================================================================
;  GRXASM.COM — traduit un fichier GRAPHER (.GRX) en assembleur
;
;  GRXASM NOM [p1 ... p9]       (ou GRAPHER NOM /A, qui passe la main ici)
;    NOM.GRX -> NOM.ASM, à assembler par ASM avec CPA.INC, GRX.INC,
;    HIRES.INC (ARR.INC, ANIM.INC si besoin). Même analyse que
;    l'interpréteur (GRAPHER.COM) : les routines communes sont dans
;    grxc_inc.s. $1 à $9 sont remplacés pendant la traduction ; /A
;    est ignoré.
;  =====================================================================

#include "cpa.inc"
#include "grxd_inc.s"

        *= $0500

        tsx
        stx sav_sp
        lda FCB1+1              ; sans nom : mode d'emploi
        cmp #" "
        bne named
        ldx #F_PRINT
        lda #<m_use
        ldy #>m_use
        jmp BDOS
named   ldx #NBUF               ; tampons à 0
        lda #0
z1      sta bufs-1,x
        dex
        bne z1
        ldx #KVU
z2      sta kvu-1,x             ; variables à deux caractères : aucune
        dex
        bne z2
        sta oopen
        sta csp
        jsr open_grx
        jsr load_text
        jsr get_params
        lda #<ptext
        sta cur
        lda #>ptext
        sta cur+1
        jmp compile

; =====================================================================
; Traduction en assembleur (GRXASM NOM -> NOM.ASM)
; =====================================================================
; Chaque ligne devient un commentaire puis son code ; le dessin appelle
; hires.inc, le reste la bibliothèque grx.inc. Une expression est
; compilée avec son état (kc = 1 : constante kv pas encore écrite ;
; kc = 0 : valeur dans g_ev à l'exécution) : les parties constantes
; sont calculées ici.

compile
.(
        jsr o_open
        lda #<h_head1           ; en-tête
        ldy #>h_head1
        jsr os
        jsr o_name
        lda #<h_head2
        ldy #>h_head2
        jsr os
        jsr o_name
        lda #<h_head2b
        ldy #>h_head2b
        jsr os
        jsr o_name
        lda #<h_head3
        ldy #>h_head3
        jsr os
        lda #0
        sta kn
        sta kn+1
        sta kanim
        sta karr
        sta kfil
        sta kspr
        sta csp
        ldx #51                 ; dimensions des tableaux : aucun
kz      sta kd_i,x
        dex
        bpl kz
kloop   jsr B_CONST             ; ESC : arrêt
        beq krd
        jsr B_CONIN
        cmp #27
        bne krd
        lda #<m_esc
        ldy #>m_esc
        jmp stop_msg
krd     ldy #0
        lda (cur),y
        beq kend
        jsr read_line
        ldx #0                  ; la ligne en commentaire
        jsr skipsp
        beq kx
        lda #";"
        jsr oc
        lda #" "
        jsr oc
        lda #<lbuf
        ldy #>lbuf
        jsr os
        jsr ocrlf
        jsr exec
kx      lda nxt
        sta cur
        lda nxt+1
        sta cur+1
        jmp kloop
kend    lda csp                 ; un bloc n'est pas fermé
        beq ok
        lda #0
        sta word
        lda #<m_open
        ldy #>m_open
        jmp error
ok      lda #<s_jend            ; fin, puis les boucles et les inclusions
        ldy #>s_jend
        jsr oi
        lda #<h_tail1
        ldy #>h_tail1
        jsr os
        lda #0
        sta kl
        sta kl+1
bl      lda kl                  ; B1 à Bn (boucles seulement)
        cmp knb
        bne bl1
        lda kl+1
        cmp knb+1
        beq bend
bl1     inc kl
        bne bl2
        inc kl+1
bl2     lda #0
        sta ksuf
        lda #"B"
        jsr o_lname
        lda #<s_bdata
        ldy #>s_bdata
        jsr os
        jmp bl
bend    jsr o_vars
        lda #<h_tail2           ; GRX.INC, ANIM.INC si besoin, HIRES.INC
        ldy #>h_tail2           ; (HIRES.INC reste à la fin : ses tables
        jsr os                  ;  suivent le programme)
        lda karr
        beq bnor
        lda #<h_tailR
        ldy #>h_tailR
        jsr os
bnor    lda kfil
        beq bnof
        lda #<h_tailF
        ldy #>h_tailF
        jsr os
bnof    lda kspr
        beq bnos
        lda #<h_tailS
        ldy #>h_tailS
        jsr os
bnos    lda kanim
        beq bnoa
        lda #<h_tailA
        ldy #>h_tailA
        jsr os
bnoa    lda #<h_tail3
        ldy #>h_tail3
        jsr os
        jsr o_close
        jsr o_name              ; message : NOM.ASM ecrit
        lda #<m_done
        ldy #>m_done
        jsr puts
        jsr o_name
        jsr crlf
        jmp quit
.)

; o_name : nom du fichier source (sans le type) sur la sortie, ou sur la
;   console après la fermeture du fichier
o_name
.(
        ldx #1
l       lda sfcb,x
        cmp #" "
        beq r
        stx lx
        ldy oopen
        beq con
        jsr oc
        jmp nx
con     jsr putc
nx      ldx lx
        inx
        cpx #9
        bne l
r       rts
.)

; ---------------------------------------------------------------------
; Fichier de sortie
; ---------------------------------------------------------------------
o_open
.(
        ldx #11                 ; NOM.ASM sur le lecteur de NOM.GRX
l       lda sfcb,x
        sta ofcb,x
        dex
        bpl l
        ldx #2
t       lda t_asm,x
        sta ofcb+9,x
        dex
        bpl t
        jsr o_fcb0
        ldx #F_DELETE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        jsr o_fcb0
        ldx #F_MAKE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_full
        ldy #>m_full
        jmp error
ok      lda #1
        sta oopen
        lda #0
        sta oidx
        rts
.)

o_fcb0
.(
        ldy #12
        lda #0
l       sta ofcb,y
        iny
        cpy #36
        bne l
        rts
.)

; oc : un caractère sur la sortie (X et Y gardés)
oc
.(
        stx osx
        sty osy
        ldy oidx
        sta obuf,y
        iny
        sty oidx
        cpy #128
        bne r
        jsr o_flush
r       ldx osx
        ldy osy
        rts
.)

o_flush
.(
        ldx #F_SETDMA
        lda #<obuf
        ldy #>obuf
        jsr BDOS
        ldx #F_WRITE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        pha
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
        pla
        bne full
        lda #0
        sta oidx
        rts
full    lda #<m_full
        ldy #>m_full
        jmp error
.)

o_close
.(
        lda oidx                ; dernier enregistrement complété par ^Z
        beq c
l       lda #$1A
        jsr oc
        lda oidx
        bne l
c       ldx #F_CLOSE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        lda #0
        sta oopen
        rts
.)

; o_drop : erreur pendant la traduction : le fichier est effacé
o_drop
.(
        lda oopen
        beq r
        lda #0
        sta oopen
        ldx #F_CLOSE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
        jsr o_fcb0
        ldx #F_DELETE
        lda #<ofcb
        ldy #>ofcb
        jsr BDOS
r       rts
.)

; ---------------------------------------------------------------------
; Écriture du texte assembleur
; ---------------------------------------------------------------------
; os : chaîne A/Y (0 à la fin) ; ocrlf : fin de ligne
os
.(
        sta ostr
        sty ostr+1
        ldy #0
l       lda (ostr),y
        beq r
        jsr oc
        iny
        bne l
r       rts
.)
ocrlf   lda #13
        jsr oc
        lda #10
        jmp oc

; oi : instruction A/Y (« jsr h_line »), en retrait, puis fin de ligne
oi      sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        jmp ocrlf
o_tab   lda #0                  ; Z ne vient plus de g_cmp/g_and/g_or
        sta kz
        lda #<s_tab
        ldy #>s_tab
        jmp os

; ohex : A en hexadécimal ($xx)
ohex
.(
        pha
        lda #"$"
        jsr oc
        pla
        pha
        lsr
        lsr
        lsr
        lsr
        jsr dig
        pla
        and #$0F
dig     cmp #10
        bcc d
        adc #6
d       adc #"0"
        jmp oc
.)

; oimm : « op #$xx » : A/Y = début (« lda # »), osv = valeur
oimm    sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        lda osv
        jsr ohex
        jmp ocrlf

; odec : kl en décimal (X gardé)
odec
.(
        txa
        pha
        lda kl
        sta gv
        lda kl+1
        sta gv+1
        lda #0
        sta gd
        ldx #0
dig     ldy #0
sub     sec
        lda gv
        sbc d_lo,x
        pha
        lda gv+1
        sbc d_hi,x
        bcc dn
        sta gv+1
        pla
        sta gv
        iny
        bne sub
dn      pla
        tya
        bne show
        lda gd
        beq nx
        tya
show    ora #"0"
        jsr oc
        sta gd
nx      inx
        cpx #4
        bne dig
        lda gv
        ora #"0"
        jsr oc
        pla
        tax
        rts
.)

; o_lab : étiquette A + numéro kl + suffixe ksuf (0 : aucun), en colonne 1
o_lab   jsr o_lname
        jmp ocrlf
o_lname jsr oc
        jsr odec
        lda ksuf
        beq ol_r
        jmp oc
ol_r    rts

; o_jmp : « jmp L<kl><suffixe A> »
o_jmp   sta ksuf
        jsr o_tab
        lda #<s_jmp
        ldy #>s_jmp
        jsr os
        lda #"L"
        jsr o_lname
        jmp ocrlf

; o_label : « L<kl><suffixe A> » en colonne 1
o_label sta ksuf
        lda #"L"
        jmp o_lab

; o_ab : « lda #<Bn » puis « ldy #>Bn »
o_ab    jsr o_tab
        lda #<s_ldalo
        ldy #>s_ldalo
        jsr os
        jsr o_bname
        jsr ocrlf
        jsr o_tab
        lda #<s_ldyhi
        ldy #>s_ldyhi
        jsr os
        jsr o_bname
        jmp ocrlf

; o_bname : « Bn », n = kb (numéro de la boucle)
o_bname lda kl
        pha
        lda kl+1
        pha
        lda kb
        sta kl
        lda kb+1
        sta kl+1
        lda #0
        sta ksuf
        lda #"B"
        jsr o_lname
        pla
        sta kl+1
        pla
        sta kl
        rts

; o_skipz : « lda g_ev / ora g_ev+1 / bne *+5 / jmp L<kl><A> » (si nul)
;   (« bne *+5 / jmp » seul quand kz : Z rendu par g_cmp, g_and, g_or)
o_skipz pha
        lda #<s_tst
        ldy #>s_tst
        ldx kz
        beq osz1
        lda #<s_bne5
        ldy #>s_bne5
osz1    jsr os
        pla
        jmp o_jmp

; ---------------------------------------------------------------------
; Destinations : ksym = « V_x », « Bn » ou un nom fixe ; koff = décalage
; ---------------------------------------------------------------------
; o_sym : nom de la destination, avec +koff
o_sym
.(
        lda ksym
        beq var
        cmp #1
        beq blk
        lda ksym+1              ; nom fixe : adresse en ksym+1/+2
        ldy ksym+2
        jsr os
        jmp off
var     lda #<s_v
        ldy #>s_v
        jsr os
        lda kvar
        clc
        adc #"A"
        jsr oc
        lda kvc                 ; second caractère
        beq off
        cmp #27
        bcs dg
        adc #"A"-1              ; (C=0) lettre
        jsr oc
        jmp off
dg      adc #"0"-28             ; (C=1) chiffre
        jsr oc
        jmp off
blk     jsr o_bname
off     lda koff
        beq r
        lda #"+"
        jsr oc
        lda koff
        ora #"0"
        jmp oc
r       rts
.)

; o_store : « sta dest » (A/Y = début de l'instruction : « sta »)
o_ins_sym
        sta osa
        sty osa+1
        jsr o_tab
        lda osa
        ldy osa+1
        jsr os
        jsr o_sym
        jmp ocrlf

; o_st16 : résultat de l'expression (kc/kv ou g_ev) -> destination
;   (16 bits, koff puis koff+1)
o_st16
.(
        lda kc
        beq dyn
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jsr oimm
        jsr sta1
        lda kv+1                ; même octet : A le contient déjà
        cmp kv
        beq sta2
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv+1
        sta osv
        pla
        jsr oimm
        jmp sta2
dyn     lda #<s_ldaev
        ldy #>s_ldaev
        jsr oi
        jsr sta1
        lda #<s_ldaev1
        ldy #>s_ldaev1
        jsr oi
sta2    inc koff
        jsr sta1
        dec koff
        rts
sta1    lda #<s_sta
        ldy #>s_sta
        jmp o_ins_sym
.)

; dest_var / dest_blk / dest_fix : choix de la destination
dest_var                        ; A = lettre (0-25), X = second caractère
        sta kvar
        stx kvc
        lda #0
        sta ksym
        sta koff
        txa
        beq dv_r
        dex                     ; deux caractères : marquée dans kvu
        txa                     ;   (5 octets par lettre)
        and #7
        tay
        txa
        lsr
        lsr
        lsr
        sta kvt
        lda kvar
        asl
        asl
        adc kvar                ; (C=0) lettre * 5
        adc kvt
        tax
        lda #1
dv_b    dey
        bmi dv_s
        asl
        bne dv_b
dv_s    ora kvu,x
        sta kvu,x
dv_r    rts

; o_vars : « V_xy .word 0 » pour chaque variable à deux caractères
;   rencontrée (les autres sont dans GRX.INC)
o_vars
.(
        lda #0
        sta kvar
ov1     lda #1
        sta kvc
ov2     lda kvar                ; marquée ?
        asl
        asl
        adc kvar
        sta kvt
        ldx kvc
        dex
        txa
        and #7
        tay
        txa
        lsr
        lsr
        lsr
        clc
        adc kvt
        tax
        lda kvu,x
b       dey
        bmi t
        lsr
        bpl b                   ; (lsr met N à 0)
t       lsr
        bcc nx
        lda #0
        sta ksym
        sta koff
        jsr o_sym
        lda #<s_vdata
        ldy #>s_vdata
        jsr os
nx      inc kvc
        lda kvc
        cmp #37
        bcc ov2
        inc kvar
        lda kvar
        cmp #26
        bcs ov3
        jmp ov1
ov3     rts
.)
dest_blk
        lda #1
        sta ksym
        lda #0
        sta koff
        rts
dest_fix                        ; A/Y = nom
        sta ksym+1
        sty ksym+2
        lda #2
        sta ksym
        lda #0
        sta koff
        rts

; k_mat : constante en attente -> g_ev (à l'exécution)
k_mat
.(
        lda kc
        beq r
        lda #<s_gev
        ldy #>s_gev
        jsr dest_fix
        jsr o_st16
        lda #0
        sta kc
r       rts
.)

; ---------------------------------------------------------------------
; Expressions
; ---------------------------------------------------------------------
k_pexpr lda #0
        beq kpx
k_lexpr lda #1
kpx     sta edep
        jsr skipsp
        beq k_epar
        cmp #";"
        beq k_epar
        stx ex
        lda #0
        sta vsp
        jsr k_or
        ldx ex
        lda lbuf,x
        beq kpok
        cmp #" "
        beq kpok
        cmp #";"
        bne k_eexp
kpok    lda edep
        beq kpr
        jsr endline
kpr     rts
k_epar  jmp e_param
k_eexp  jmp e_expr

k_or
.(
        jsr k_cmp
loop    jsr ws
        jsr gch
        cmp #"&"
        beq op
        cmp #"|"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_cmp
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_cmp
.(
        jsr is_str              ; deux chaînes comparées ?
        bcc str
        jsr k_sum
        jsr relop
        bcs r
        pha
        jsr k_left
        jsr ws
        jsr k_sum
        pla
        jmp k_apply
r       rts
str     jsr k_str
        lda #<s_rsave
        ldy #>s_rsave
        jsr oi
        jsr ws
        jsr relop
        bcs bad
        and #$7F
        pha
        jsr ws
        jsr k_str
        pla
        sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        lda #<s_rcmp
        ldy #>s_rcmp
        jsr oi
        lda #0
        sta kc
        rts
bad     jmp e_strc
.)

k_sum
.(
        jsr k_term
loop    jsr ws
        jsr gch
        cmp #"+"
        beq op
        cmp #"-"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_term
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_term
.(
        jsr k_un
loop    jsr ws
        jsr gch
        cmp #"*"
        beq op
        cmp #"/"
        beq op
        cmp #"%"
        bne r
op      pha
        inc ex
        jsr k_left
        jsr ws
        jsr k_un
        pla
        jsr k_apply
        jmp loop
r       rts
.)

k_un
.(
        jsr ws
        jsr gch
        cmp #"-"
        bne k_prim
        inc ex
        jsr k_un
        lda kc
        beq dyn
        lda kv                  ; constante : opposée ici
        sta ev
        lda kv+1
        sta ev+1
        jsr neg_ev
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        rts
dyn     lda #<s_neg
        ldy #>s_neg
        jmp oi
.)

k_prim
.(
        jsr ws
        jsr gch
        cmp #"("
        bne nopar
        inc ex
        inc edep
        jsr k_or
        jmp x_close
nopar   cmp #34                 ; une chaîne dans un calcul
        beq kstrc
        cmp #"0"
        bcc id
        cmp #"9"+1
        bcs id
        jsr parse_num           ; nombre : constante
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        lda #1
        sta kc
        rts
id      jsr parse_id
        cpx #3
        bcs func
        cpx #1
        bne v2
        jsr gch                 ; A( ou A$( : un élément de tableau
        cmp #"("
        beq kael
        cmp #"$"
        beq kbel
v2      jsr kw_var              ; variable -> g_ev
        lda vix
        ldx vc
        jsr dest_var
        lda #0
        sta kc
        lda #<s_ldai            ; (o_st16 à l'envers : var -> g_ev)
        jsr ld_var
        rts
kael    lda kw
        ldx #0
        jmp k_aget
kbel    inc ex
        jsr gch
        cmp #"("
        bne kstrc               ; A$ : une chaîne
        lda kw
        ldx #1
        jmp k_aget
kstrc   jmp e_strc
func    jsr find_fn
        cmp #0
        beq f_rnd
        cmp #1
        beq f_abs
        cmp #2
        beq f_point
        cmp #4
        bne kfs1
        jmp f_scrn
kfs1
        cmp #5
        bne fink
        jsr x_open              ; LEN(chaîne)
        jsr k_str
        jsr x_close
        lda #<s_rlen
        ldy #>s_rlen
        jmp dyn
fink    cmp #6
        bne fink2
        jsr k_fil
        lda #<s_ffnd            ; FOUND
        ldy #>s_ffnd
        jmp dyn
fink2   lda #<s_inkey
        ldy #>s_inkey
        jmp dyn
f_rnd   jsr x_open
        jsr k_or
        jsr x_close
        jsr k_mat
        lda #<s_rnd
        ldy #>s_rnd
        jmp dyn
f_abs   jsr x_open
        jsr k_or
        jsr x_close
        lda kc
        beq ab
        lda kv+1                ; constante : ici
        bpl r
        lda kv
        sta ev
        lda kv+1
        sta ev+1
        jsr neg_ev
        lda ev
        sta kv
        lda ev+1
        sta kv+1
r       rts
ab      lda #<s_abs
        ldy #>s_abs
        jmp oi
f_point jsr x_open
        jsr k_or
        jsr k_mat
        lda #<s_push
        ldy #>s_push
        jsr oi
        jsr x_comma
        jsr k_or
        jsr x_close
        jsr k_mat
        lda #<s_pop
        ldy #>s_pop
        jsr oi
        lda #<s_point
        ldy #>s_point
        jmp dyn
f_scrn  jsr x_open              ; comme POINT : g_et = col, g_ev = lig
        jsr k_or
        jsr k_mat
        lda #<s_push
        ldy #>s_push
        jsr oi
        jsr x_comma
        jsr k_or
        jsr x_close
        jsr k_mat
        lda #<s_pop
        ldy #>s_pop
        jsr oi
        lda #<s_scrn
        ldy #>s_scrn
dyn     jsr oi
        lda #0
        sta kc
        rts
.)

; ld_var : g_ev <- variable kvar (« lda V_x / sta g_ev » ...)
ld_var
.(
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        lda #<s_stev
        ldy #>s_stev
        ldx kdst                ; opérande droit simple : vers g_et
        beq lda1
        lda #<s_stet
        ldy #>s_stet
lda1    jsr oi
        inc koff
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        lda #<s_stev1
        ldy #>s_stev1
        ldx kdst
        beq lda2
        lda #<s_stet1
        ldy #>s_stet1
lda2    jmp oi
.)

; k_left : opérande de gauche gardé (constante ici, valeur sur la pile
;   des valeurs à l'exécution)
;   A = opérateur. Gauche calculée et droite simple (un nombre ou une
;   variable, rien de plus fort après) : ni g_push ni g_pop, la gauche reste
;   dans g_ev, la droite ira dans g_et (vs_f = 2, kdst)
k_left
.(
        sta kop
        ldy vsp
        cpy #NVS
        bcs deep
        lda kc
        sta vs_f,y
        lda kv
        sta vs_lo,y
        lda kv+1
        sta vs_hi,y
        inc vsp
        lda kc
        bne r
        jsr k_simple
        bcs push
        ldy vsp
        lda #2
        sta vs_f-1,y
        sta kdst                ; (non nul)
        rts
push    lda #<s_push
        ldy #>s_push
        jmp oi
r       rts
deep    jmp e_expr
.)

; k_simple : C=0 si l'opérande droit de kop (en ex) est simple : un nombre
;   ou une variable, suivi de rien qui lie plus fort que kop. / et % : non
;   (pas d'opération inversée)
k_simple
.(
        lda kop
        cmp #"/"
        beq ks_n0
        cmp #"%"
        bne ks_go
ks_n0   sec
        rts
ks_go   ldx #0                  ; niveau : 0 * ; 1 + - ; 2 comparaison ; 3 & |
        cmp #"*"
        beq ks_lv
        inx
        cmp #"+"
        beq ks_lv
        cmp #"-"
        beq ks_lv
        inx
        cmp #$80
        bcs ks_lv
        inx
ks_lv   stx kvt
        ldy ex
        jsr ks_sp
        lda lbuf,y
        jsr isdig
        bcc ks_num
        jsr isalpha
        bcs ks_no
        iny                     ; variable : une lettre, puis lettre ou chiffre
        lda lbuf,y
        jsr isalpha
        bcc ks_2
        jsr isdig
        bcs ks_nm
ks_2    iny
ks_nm   lda lbuf,y              ; ni ( ni $, ni lettre ou chiffre collés
        cmp #"("
        beq ks_no
        cmp #"$"
        beq ks_no
ks_end  jsr isalpha
        bcc ks_no
        jsr isdig
        bcc ks_no
        jsr ks_sp
        lda lbuf,y
        ldx kvt
        beq ks_yes              ; * : l'opérande est complet
        jsr ks_in
        .asc "*/%",0
        bcc ks_no
        dex
        beq ks_yes
        jsr ks_in
        .asc "+-",0
        bcc ks_no
        dex
        beq ks_yes
        jsr ks_in
        .asc "=<>",0
        bcc ks_no
ks_yes  clc
        rts
ks_num  iny
        lda lbuf,y
        jsr isdig
        bcc ks_num
        bcs ks_end
ks_no   sec
        rts
ks_sp   lda edep                ; espaces sautés si edep > 0
        beq ks_spr
ks_spl  lda lbuf,y
        cmp #" "
        bne ks_spr
        iny
        bne ks_spl
ks_spr  rts
.)

; ks_in : C=0 si A est dans la liste qui suit l'appel (terminée par 0) ;
;   on revient après la liste. A, X, Y gardés
ks_in
.(
        sta gd
        sty kvt+1
        pla
        sta gv
        pla
        sta gv+1
        lda #1                  ; kvt : 1 pas trouvé, 0 trouvé
        sta kvt
        ldy #0
l       iny
        lda (gv),y
        beq e
        cmp gd
        bne l
        lda #0
        sta kvt
f       iny                     ; jusqu'au 0
        lda (gv),y
        bne f
e       tya                     ; retour : gv + Y (le 0, dernier octet)
        clc
        adc gv
        sta gv
        bcc n
        inc gv+1
n       lda gv+1
        pha
        lda gv
        pha
        lda kvt                 ; C = pas trouvé
        lsr
        lda gd
        ldy kvt+1
        rts
.)

; k_apply : gauche (k_left) op A droite (kc/kv)
k_apply
.(
        sta kop
        dec vsp
        ldy vsp
        lda vs_f,y
        sta klf
        lda vs_lo,y
        sta lv
        lda vs_hi,y
        sta lv+1
        lda klf
        beq lstk
        cmp #2
        bne kcst
        jmp lreg
kcst    lda kc
        beq lcst
        lda lv                  ; deux constantes : calcul ici
        sta et
        lda lv+1
        sta et+1
        lda kv
        sta ev
        lda kv+1
        sta ev+1
        lda kop
        jsr binop
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        rts
lcst    lda #<s_ldai            ; gauche constante -> g_et
        ldy #>s_ldai
        pha
        lda lv
        sta osv
        pla
        jsr oimm
        lda #<s_stet
        ldy #>s_stet
        jsr oi
        lda lv+1                ; même octet : A le contient déjà
        cmp lv
        beq lc1
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda lv+1
        sta osv
        pla
        jsr oimm
lc1     lda #<s_stet1
        ldy #>s_stet1
        jsr oi
        jmp eop
lstk    jsr k_mat               ; gauche sur la pile des valeurs
        lda #<s_pop
        ldy #>s_pop
        jsr oi
eop     lda #0
        sta kc
        lda kop
        bpl ar
        and #$7F                ; comparaison : ldx #n / jsr g_cmp
        sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        lda #<s_cmp
        ldy #>s_cmp
        jsr oi
zset    lda #1                  ; Z rendu (IF, WHILE : sans lda/ora)
        sta kz
        rts
; gauche dans g_ev, droite simple : dans g_et (variable, déjà écrite), ou
;   constante écrite ici ; opération inversée
lreg    lda #0
        sta kdst
        lda kc
        beq swp
        lda kop                 ; X - k : X + (-k)
        cmp #"-"
        bne lr1
        lda kv
        sta ev
        lda kv+1
        sta ev+1
        jsr neg_ev
        lda ev
        sta kv
        lda ev+1
        sta kv+1
        lda #"+"
        sta kop
lr1     lda #<s_etn
        ldy #>s_etn
        jsr dest_fix
        jsr o_st16
swp     lda kop
        bpl sa
        and #$7F                ; < et >, <= et >= échangés
        tax
        lda cswp,x
        ora #$80
        sta kop
        jmp eop
sa      cmp #"-"
        bne eopj
        lda #"r"                ; X - Y : g_rsub
        sta kop
eopj    jmp eop
cswp    .byt 0,1,2,5,6,3,4
ar      ldx #0                  ; opération -> sa routine
f       lda ops,x
        beq r
        cmp kop
        beq found
        inx
        inx
        inx
        bne f
found   lda ops+1,x
        ldy ops+2,x
        jsr oi
        lda kop
        cmp #"&"
        beq zset
        cmp #"|"
        beq zset
r       rts
ops     .byt "+"
        .word s_add
        .byt "-"
        .word s_sub
        .byt "*"
        .word s_mul
        .byt "/"
        .word s_div
        .byt "%"
        .word s_mod
        .byt "&"
        .word s_and
        .byt "|"
        .word s_or
        .byt "r"
        .word s_rsub
        .byt 0
.)

; k_byte : paramètre de 0 à 255 -> A (à l'exécution)
k_byte
.(
        jsr k_pexpr
        lda kc
        beq dyn
        lda kv+1                ; constante : vérifiée ici
        bne bad
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jmp oimm
bad     lda #<m_range
        ldy #>m_range
        jmp error
dyn     lda #<s_byte
        ldy #>s_byte
        jmp oi
.)

; k_p : paramètre de 0 à 255 -> destination fixe A/Y (« h_x1 »)
k_p     pha
        tya
        pha
        jsr k_byte
        pla
        tay
        pla
        jsr dest_fix
        lda #<s_sta
        ldy #>s_sta
        jmp o_ins_sym
k_p2    lda #<s_hx1
        ldy #>s_hx1
        jsr k_p
        lda #<s_hy1
        ldy #>s_hy1
        jmp k_p
k_p4    jsr k_p2
        lda #<s_hx2
        ldy #>s_hx2
        jsr k_p
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jmp endline

; o_text : texte de lbuf (X) jusqu'à la fin, en .byt (guillemets à part)
o_lit   lda #34                 ; texte jusqu'au guillemet final
        bne ot0
o_text  lda #0                  ; texte jusqu'à la fin de la ligne
ot0     sta kterm
.(
        stx lx
        lda #<s_byt
        ldy #>s_byt
        jsr os
        lda #0
        sta kin                 ; dans une chaîne
        sta kst                 ; quelque chose écrit
l       ldx lx
        lda lbuf,x
        beq end
        inc lx
        cmp kterm
        beq end
        cmp #34
        beq num
        cmp #" "
        bcc num
        pha
        lda kin
        bne in
        jsr comma
        lda #34
        jsr oc
        lda #1
        sta kin
in      pla
        jsr oc
        jmp l
num     pha
        jsr close
        jsr comma
        pla
        jsr ohex
        jmp l
end     jsr close
        jsr comma
        lda #"0"
        jsr oc
        jmp ocrlf
close   lda kin
        beq cr
        lda #34
        jsr oc
        lda #0
        sta kin
cr      rts
comma   lda kst
        beq kc1
        lda #","
        jmp oc
kc1     lda #1
        sta kst
        rts
.)

; ---------------------------------------------------------------------
; Commandes traduites
; ---------------------------------------------------------------------
k_call0 jsr endline             ; A/Y : instruction seule (« jsr h_full »)
        pla
        tay
        pla
        jmp oi
k_hires lda #<s_hires
        pha
        lda #>s_hires
        pha
        jmp k_call0
k_split lda #<s_split
        pha
        lda #>s_split
        pha
        jmp k_call0
k_text  lda #<s_text
        pha
        lda #>s_text
        pha
        jmp k_call0
k_gcls  lda #<s_gcls
        pha
        lda #>s_gcls
        pha
        jmp k_call0
k_wait  lda #<s_wait
        pha
        lda #>s_wait
        pha
        jmp k_call0
k_end   lda #<s_jend
        pha
        lda #>s_jend
        pha
        jmp k_call0
k_lores lda #<s_lores
        pha
        lda #>s_lores
        pha
        jmp k_call0
k_cls   lda #<s_lcls
        pha
        lda #>s_lcls
        pha
        jmp k_call0
k_locate
        jsr k_p2
        jsr endline
        lda #<s_loc
        ldy #>s_loc
        jmp oi
k_char  jsr k_p2
        jsr k_byte
        jsr endline
        lda #<s_chr
        ldy #>s_chr
        jmp oi
k_spc
.(
        lda #<s_hx1             ; nombre -> h_x1, octet -> h_y1
        ldy #>s_hx1
        jsr k_p
        jsr skipsp
        beq dflt
        cmp #";"
        beq dflt
        lda #<s_hy1
        ldy #>s_hy1
        jsr k_p
        jmp e
dflt    stx lx
        lda #<s_ldai            ; espace par défaut
        ldy #>s_ldai
        pha
        lda #32
        sta osv
        pla
        jsr oimm
        lda #<s_hy1
        ldy #>s_hy1
        jsr dest_fix
        lda #<s_sta
        ldy #>s_sta
        jsr o_ins_sym
        ldx lx
e       jsr endline
        lda #<s_spc
        ldy #>s_spc
        jmp oi
.)
k_tab   jsr k_byte
        jsr endline
        lda #<s_ltab
        ldy #>s_ltab
        jmp oi
k_get   jsr getvar              ; GET V : g_get -> g_ev -> V
        jsr endline
        lda #<s_get
        ldy #>s_get
        jsr oi
        lda #0
        sta kc
        lda vix
        ldx vc
        jsr dest_var
        jmp o_st16
k_pen   jsr k_pexpr
        lda kc                  ; constante : 0 à 2
        beq kpen1
        lda kv+1
        bne kpen0
        lda kv
        cmp #3
        bcc kpen1
kpen0   jmp e_param
kpen1   ldx #0
        jsr k_rebyte
        lda #<s_pen
        ldy #>s_pen
        jmp oi
k_plot  jsr k_p2
        jsr endline
        lda #<s_plot
        ldy #>s_plot
        jmp oi
k_line  jsr k_p4
        lda #<s_line
        ldy #>s_line
        jmp oi
k_box   jsr k_p4
        lda #<s_box
        ldy #>s_box
        jmp oi
k_fbox  jsr k_p4
        lda #<s_fbox
        ldy #>s_fbox
        jmp oi
k_circle
        jsr k_p2
        lda #<s_hr
        ldy #>s_hr
        jsr k_p
        jsr endline
        lda #<s_circle
        ldy #>s_circle
        jmp oi
k_attr  jsr k_p2
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jsr k_byte
        jsr endline
        lda #<s_attr
        ldy #>s_attr
        jmp oi
k_gtext jsr k_p2                ; le texte suit l'appel
        lda lbuf,x
        beq kgt
        inx
kgt     stx lx
        lda #<s_gtext
        ldy #>s_gtext
        jsr oi
        ldx lx
        jmp o_text
k_echo  jsr skipsp
        stx lx
        lda #<s_echo
        ldy #>s_echo
        jsr oi
        ldx lx
        jmp o_text
k_gnum  jsr k_p2
        jsr k_pexpr
        jsr endline
        jsr k_mat
        lda #<s_gnum
        ldy #>s_gnum
        jmp oi
k_delay jsr k_pexpr
        jsr endline
        jsr k_mat
        lda #<s_delay
        ldy #>s_delay
        jmp oi
k_print stx ex                  ; une chaîne ?
        lda #1
        sta edep
        lda #0
        sta vsp
        jsr is_str
        bcs kpn
        jsr str_only
        bcs kpn
        jsr k_str
        ldx ex
        jsr endline
        lda #<s_rprint
        ldy #>s_rprint
        jmp oi
kpn     ldx ex
        jsr k_lexpr
        jsr k_mat
        lda #<s_print
        ldy #>s_print
        jmp oi
k_gload lda #<s_gload
        ldy #>s_gload
        jmp k_img
k_anim  jsr animarg             ; passages dans A, puis l'appel et le nom
        lda #1
        sta kanim
        lda #<s_anim
        ldy #>s_anim
        jsr oi
        jmp k_fnm
k_gsave lda #<s_gsave
        ldy #>s_gsave
k_img
.(
        pha
        tya
        pha
        jsr getname             ; le nom (lecteur, 8 + 3) suit l'appel
        pla
        tay
        pla
        jmp oi_fnm
.)
oi_fnm  jsr oi
; k_fnm : lecteur et nom de ifcb, écrits après l'appel (.byt, .asc)
k_fnm
.(
        lda #<s_byt
        ldy #>s_byt
        jsr os
        lda ifcb
        jsr ohex
        jsr ocrlf
        lda #<s_asc
        ldy #>s_asc
        jsr os
        ldx #1
l       lda ifcb,x
        jsr oc
        inx
        cpx #12
        bne l
        lda #34
        jsr oc
        jmp ocrlf
.)

; k_rebyte : (après k_pexpr) A <- valeur à l'exécution
k_rebyte
        lda kc
        beq krb1
        lda #<s_ldai
        ldy #>s_ldai
        pha
        lda kv
        sta osv
        pla
        jmp oimm
krb1    lda #<s_byte
        ldy #>s_byte
        jmp oi

; ---------------------------------------------------------------------
; Tableaux et chaînes traduits (appels à ARR.INC)
; ---------------------------------------------------------------------
; kd_get : A = lettre, X = sorte -> A = dimensions notées par DIM (Y changé)
kd_get
.(
        sec
        sbc #"A"
        tay
        cpx #0
        beq i
        lda kd_s,y
        rts
i       lda kd_i,y
        rts
.)
; k_need : A = lettre, X = sorte : tableau déclaré par un DIM plus haut,
;   sinon erreur ; kdn = ses dimensions ; A et X gardés
k_need
.(
        pha
        jsr kd_get
        sta kdn
        pla
        ldy kdn
        beq bad
        rts
bad     lda #<m_nodim
        ldy #>m_nodim
        jmp error
.)
; k_desc : A = lettre, X = sorte : « lda #lo / ldy #hi » du descripteur
k_desc  jsr desc_of
        sty kdh
        sta osv
        lda #<s_ldai
        ldy #>s_ldai
        jsr oimm
        lda kdh
        sta osv
        lda #<s_ldyi
        ldy #>s_ldyi
        jmp oimm
; k_oi : instruction A/Y, puis valeur à l'exécution (kc = 0)
k_oi    jsr oi
        lda #0
        sta kc
        rts
k_push  lda #<s_push
        ldy #>s_push
        jmp oi
k_pop   lda #<s_pop
        ldy #>s_pop
        jmp oi

; k_aget : élément du tableau (lettre A, X = sorte), indices en ex -> g_ev
k_aget
.(
        jsr k_need
        pha
        txa
        pha
        jsr x_open
        jsr k_or
        jsr k_mat
        jsr ws
        jsr gch
        cmp #","
        beq two
        jsr x_close
        pla
        tax
        pla
        cpx #0
        beq one
        pha                     ; M$(i) d'un tableau à deux dimensions :
        jsr kd_get              ;   une ligne, donc une chaîne
        cmp #2
        bne o1
        jmp e_strc
o1      pla
        ldx #1
one     jsr k_desc
        lda #<s_get1
        ldy #>s_get1
        jmp k_oi
two     inc ex
        jsr k_push
        jsr k_or
        jsr k_mat
        jsr x_close
        jsr k_pop
        pla
        tax
        pla
        jsr k_desc
        lda #<s_get2
        ldy #>s_get2
        jmp k_oi
.)

; k_str : chaîne en ex -> code qui en fait la chaîne courante
k_str
.(
        jsr is_str
        bcs bad
        lda #1
        sta karr
        jsr gch
        cmp #34
        bne var
        inc ex                  ; texte : « jsr r_lit », puis .byt
        ldy ex
l       lda lbuf,y              ; un guillemet final ?
        beq bad
        iny
        cmp #34
        bne l
        lda #<s_rlit
        ldy #>s_rlit
        jsr oi
        ldx ex
        jsr o_lit
        lda lx
        sta ex
        rts
var     jsr isalpha
        pha
        inc ex
        inc ex
        jsr gch
        cmp #"("
        beq row
        pla                     ; A$ : un tableau à une dimension
        ldx #1
        jsr k_need
        ldy kdn
        cpy #1
        bne bad
        jsr k_desc
        lda #<s_whole
        ldy #>s_whole
        jmp oi
row     jsr x_open
        jsr k_or
        jsr k_mat
        jsr x_close
        pla
        ldx #1
        jsr k_desc
        lda #<s_row
        ldy #>s_row
        jmp oi
bad     jmp e_strc
.)

; k_aassign : affectation d'un élément ou d'une chaîne (voir arr_assign)
k_aassign
.(
        stx ex
        lda #0
        sta vsp
        sta edep
        sta aak
        lda word
        sta aal
        jsr gch
        cmp #"$"
        bne t1
        inc ex
        inc aak
t1      lda aal
        ldx aak
        jsr k_need
        jsr gch
        cmp #"("
        beq idx
        ldy kdn                 ; A$ = chaîne
        cpy #1
        beq ksb1
        jmp bad
ksb1
        lda aal
        ldx #1
        jsr k_desc
        lda #<s_whole
        ldy #>s_whole
        jsr oi
        jmp sas
idx     jsr x_open
        jsr k_or
        jsr k_mat
        jsr ws
        jsr gch
        cmp #","
        beq two
        jsr x_close
        lda aak
        beq one
        lda aal
        ldx #1
        jsr kd_get
        cmp #2
        bne one
        lda aal                 ; M$(l) = chaîne
        ldx #1
        jsr k_desc
        lda #<s_row
        ldy #>s_row
        jsr oi
        jmp sas
one     lda aal
        ldx aak
        jsr k_desc
        lda #<s_ea1
        ldy #>s_ea1
        jsr oi
        jmp elt
two     inc ex
        jsr k_push
        jsr k_or
        jsr k_mat
        jsr x_close
        jsr k_pop
        lda aal
        ldx aak
        jsr k_desc
        lda #<s_ea2
        ldy #>s_ea2
        jsr oi
elt     lda #<s_atoj            ; adresse de l'élément gardée
        ldy #>s_atoj
        jsr oi
        jsr k_push
        jsr aeq
        jsr k_lexpr             ; valeur -> g_ev
        jsr k_mat
        jsr k_pop               ; g_et = adresse
        lda aak
        bne b
        lda #<s_stw
        ldy #>s_stw
        jmp oi
b       lda #<s_stb
        ldy #>s_stb
        jmp oi
sas     lda #<s_rsave           ; destination gardée
        ldy #>s_rsave
        jsr oi
        jsr aeq
        jsr k_str               ; source
        ldx ex
        jsr endline
        lda #<s_rswap
        ldy #>s_rswap
        jsr oi
        lda #<s_rcopy
        ldy #>s_rcopy
        jmp oi
bad     jmp e_strc
.)

; DIM traduit
k_dim
.(
        jsr skipsp
        bne kfb1
        jmp bad
kfb1
item    jsr isalpha
        bcc kfb2
        jmp bad
kfb2
        sta aal
        inx
        lda #0
        sta aak
        lda lbuf,x
        cmp #"$"
        bne i1
        inx
        inc aak
i1      stx ex
        lda #0
        sta vsp
        sta edep
        lda #1
        sta karr
        jsr x_open
        jsr k_or
        jsr k_mat
        jsr ws
        jsr gch
        ldy #1
        cmp #","
        bne one
        inc ex
        jsr k_push
        jsr k_or
        jsr k_mat
        jsr k_pop
        ldy #2
one     sty kdn
        jsr x_close
        lda aal                 ; dimensions notées pour la suite
        sec
        sbc #"A"
        tay
        lda kdn
        ldx aak
        bne s1
        sta kd_i,y
        beq s2
        bne s2
s1      sta kd_s,y
s2      lda aak                 ; « ldx #octets », descripteur, r_dim
        eor #1
        clc
        adc #1
        sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        lda aal
        ldx aak
        jsr k_desc
        lda kdn
        cmp #2
        beq d2
        lda #<s_dim1
        ldy #>s_dim1
        jsr oi
        jmp nx
d2      lda #<s_dim2
        ldy #>s_dim2
        jsr oi
nx      ldx ex
        lda lbuf,x
        beq r
        cmp #" "
        bne bad
        jsr skipsp
        beq r
        cmp #";"
        beq kdn1
        jmp item
kdn1
r       rts
bad     jmp e_param
.)

; FILL traduit
k_fill
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda #0
        sta aak
        lda lbuf,x
        cmp #"$"
        bne f1
        inx
        inc aak
f1      lda lbuf,x
        cmp #" "
        bne bad
        jsr k_pexpr
        jsr endline
        jsr k_mat
        lda aal
        ldx aak
        jsr k_need
        jsr k_desc
        lda #<s_rfill
        ldy #>s_rfill
        jmp oi
bad     jmp e_param
.)

; INPUT traduit
k_input
.(
        jsr skipsp
        jsr isalpha
        bcs bad
        lda lbuf+1,x
        cmp #"$"
        beq str
        jsr getvar
        jsr endline
        lda #1
        sta karr
        lda #<s_rninp
        ldy #>s_rninp
        jsr oi
        lda #0
        sta kc
        lda vix
        ldx vc
        jsr dest_var
        jmp o_st16
str     stx ex
        lda #1
        sta edep
        lda #0
        sta vsp
        jsr k_str
        ldx ex
        jsr endline
        lda #<s_rinput
        ldy #>s_rinput
        jmp oi
bad     jmp e_param
.)

; affectation : variable vix, vc ; X sur le « = »
k_let   jsr getvar
        jsr skipsp
        cmp #"="
        beq k_assign
        jmp e_param
k_assign
        jsr k_incdec            ; V = V + 1, V = V - 1 : inc, dec
        bcc kas_r
        lda vix                 ; (l'expression change vix et vc)
        pha
        lda vc
        pha
        inx
        jsr k_lexpr
        pla
        tax
        pla
        jsr dest_var
        jmp o_st16
kas_r   rts

; k_incdec : X sur le « = » de V = ... ; si c'est V = V + 1 ou V = V - 1
;   (rien d'autre sur la ligne), écrit inc ou dec, C=0 ; sinon C=1, X gardé
k_incdec
.(
        txa
        tay
        iny
        jsr sp
        lda lbuf,y
        jsr isalpha
        bcs no
        sec
        sbc #"A"
        cmp vix
        bne no
        iny
        lda lbuf,y              ; second caractère, comme getvar
        jsr isalpha
        bcs dg
        sbc #"A"-2              ; (C=0) lettre : 1-26
        jmp c2
dg      jsr isdig
        bcs n1
        sbc #"0"-28             ; (C=0) chiffre : 27-36
c2      iny
        cmp vc
        bne no
        beq op
n1      lda vc
        bne no
op      jsr sp
        lda lbuf,y
        cmp #"+"
        beq ok
        cmp #"-"
        bne no
ok      sta kop
        iny
        jsr sp
        lda lbuf,y
        cmp #"1"
        bne no
        iny
        jsr sp
        lda lbuf,y
        beq yes
        cmp #";"
        beq yes
no      sec
        rts
sp      lda lbuf,y
        cmp #" "
        bne spr
        iny
        bne sp
spr     rts
yes     lda vix
        ldx vc
        jsr dest_var
        lda kop
        cmp #"-"
        beq kdec
        lda #<s_inc             ; inc V / bne *+5 / inc V+1
        ldy #>s_inc
        jsr o_ins_sym
        jsr bne5
        inc koff
        lda #<s_inc
        ldy #>s_inc
        jsr o_ins_sym
        clc
        rts
kdec    lda #<s_lda             ; lda V / bne *+5 / dec V+1 / dec V
        ldy #>s_lda
        jsr o_ins_sym
        jsr bne5
        inc koff
        lda #<s_dec
        ldy #>s_dec
        jsr o_ins_sym
        dec koff
        lda #<s_dec
        ldy #>s_dec
        jsr o_ins_sym
        clc
        rts
bne5    lda #<s_bne5
        ldy #>s_bne5
        jmp os
.)

; k_newblk : nouveau bloc kl = ++kn, empilé avec le type A
k_newblk
.(
        inc kn
        bne n
        inc kn+1
n       ldy kn
        sty kl
        ldy kn+1
        sty kl+1
        jsr cs_push
        lda kl
        sta cs_al,y
        lda kl+1
        sta cs_ah,y
        lda #0
        sta cs_v,y
        rts
.)

; k_top : sommet de la pile de contrôle -> Y, kl ; type dans A (0 : vide)
k_top
.(
        ldy csp
        beq none
        dey
        lda cs_al,y
        sta kl
        lda cs_ah,y
        sta kl+1
        lda cs_bl,y             ; boucle : son numéro
        sta kb
        lda cs_bh,y
        sta kb+1
        lda cs_t,y
        rts
none    lda #0
        rts
.)

; k_newloop : la boucle du sommet (Y) reçoit le numéro kb = ++knb (Bn)
k_newloop
.(
        inc knb
        bne n
        inc knb+1
n       lda knb
        sta kb
        sta cs_bl,y
        lda knb+1
        sta kb+1
        sta cs_bh,y
        rts
.)

k_repeat
        lda #T_REP
        jsr k_newblk
        jsr k_newloop
        jsr k_pexpr
        jsr endline
        jsr dest_blk
        jsr o_st16
        lda #"T"
        jsr o_label
        jsr o_ab
        lda #<s_rept
        ldy #>s_rept
        jsr oi
        lda #<s_bcc
        ldy #>s_bcc
        jsr oi
        lda #"E"
        jmp o_jmp

k_for
.(
        jsr getvar
        lda vix
        sta fvar
        lda vc
        sta fvar+1
        lda #T_FOR
        jsr k_newblk
        jsr k_newloop
        jsr k_pexpr             ; départ -> variable
        txa                     ; (position dans la ligne)
        pha
        jsr fv_dest
        jsr o_st16
        jsr fv_dest             ; adresse de la variable -> Bn+4
        lda #<s_ldalo
        ldy #>s_ldalo
        jsr o_ins_sym
        lda #4
        jsr fv_sta
        jsr fv_dest
        lda #<s_ldahi
        ldy #>s_ldahi
        jsr o_ins_sym
        lda #5
        jsr fv_sta
        pla
        tax
        jsr k_pexpr             ; arrivée -> Bn
        jsr dest_blk
        jsr o_st16
        lda #1                  ; pas : 1 par défaut
        sta kc
        sta kv
        lda #0
        sta kv+1
        jsr skipsp
        beq step
        cmp #";"
        beq step
        jsr k_pexpr
        lda kc
        beq step
        lda kv
        ora kv+1
        bne step
        lda #<m_step
        ldy #>m_step
        jmp error
step    jsr endline
        jsr dest_blk            ; pas -> Bn+2
        lda #2
        sta koff
        jsr o_st16
        lda #"T"
        jsr o_label
        jsr o_ab
        lda #<s_forok
        ldy #>s_forok
        jsr oi
        lda #<s_bcc
        ldy #>s_bcc
        jsr oi
        lda #"E"
        jmp o_jmp
.)

; fv_dest : destination = variable du FOR (fvar)
fv_dest lda fvar
        ldx fvar+1
        jmp dest_var

; fv_sta : « sta Bn+A » (bloc en cours)
fv_sta  pha
        jsr dest_blk
        pla
        sta koff
        lda #<s_sta
        ldy #>s_sta
        jmp o_ins_sym

k_while
.(
        lda #T_WHILE
        jsr k_newblk
        lda #"T"
        jsr o_label
        jsr k_lexpr
        lda kc
        beq dyn
        lda kv
        ora kv+1
        bne r                   ; WHILE vrai : rien à tester
        lda #"E"
        jmp o_jmp
dyn     lda #"E"
        jmp o_skipz
r       rts
.)

k_next
.(
        jsr k_top
        cmp #T_REP
        beq ok
        cmp #T_FOR
        beq ok
        cmp #T_WHILE
        beq ok
        lda #<m_nofor
        ldy #>m_nofor
        jmp error
ok      pha
        lda #<s_brk
        ldy #>s_brk
        jsr oi
        pla
        cmp #T_FOR
        bne back
        jsr o_ab
        lda #<s_fstep
        ldy #>s_fstep
        jsr oi
        lda #<s_bcs
        ldy #>s_bcs
        jsr oi
back    lda #"T"
        jsr o_jmp
        lda #"E"
        jsr o_label
        dec csp
        rts
.)

k_if
.(
        lda #T_IF
        jsr k_newblk
        jsr k_lexpr
        lda kc
        beq dyn
        lda kv
        ora kv+1
        bne r
        lda #"X"
        jmp o_jmp
dyn     lda #"X"
        jmp o_skipz
r       rts
.)

k_else
.(
        jsr k_top
        cmp #T_IF
        bne bad
        lda cs_v,y
        bne bad
        lda #1
        sta cs_v,y
        lda #"E"
        jsr o_jmp
        lda #"X"
        jmp o_label
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_endif
.(
        jsr k_top
        cmp #T_IF
        bne bad
        lda cs_v,y
        bne e
        lda #"X"
        jsr o_label
e       lda #"E"
        jsr o_label
        dec csp
        rts
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_sub
.(
        jsr getsub              ; nom -> cname
        jsr endline
        lda #T_SUB
        jsr k_newblk
        lda #"E"                ; rencontré en chemin : sauté
        jsr o_jmp
        jsr o_pname
        jmp ocrlf
.)

k_endsub
.(
        jsr k_top
        cmp #T_SUB
        bne bad
        lda #<s_rts
        ldy #>s_rts
        jsr oi
        lda #"E"
        jsr o_label
        dec csp
        rts
bad     lda #<m_struct
        ldy #>m_struct
        jmp error
.)

k_return
.(
        jsr endline
        ldy csp                 ; dans un SUB ?
l       dey
        bmi bad
        lda cs_t,y
        cmp #T_SUB
        bne l
        lda #<s_rts
        ldy #>s_rts
        jmp oi
bad     lda #<m_noret
        ldy #>m_noret
        jmp error
.)

k_call
        jsr sub_find            ; vérifie que SUB NOM existe
        jsr o_tab
        lda #<s_jsr
        ldy #>s_jsr
        jsr os
        jsr o_pname
        jmp ocrlf

; o_pname : « P_NOM »
o_pname lda #<s_p
        ldy #>s_p
        jsr os
        lda #<cname
        ldy #>cname
        jmp os

; textes de l'assembleur produit
s_tab   .asc " ",0        ; retrait des instructions (directives et
                                ;   étiquettes en colonne 1)
s_jmp   .asc "jmp ",0
s_jsr   .asc "jsr ",0
s_jend  .asc "jmp g_end",0
s_ldalo .asc "lda #<",0
s_ldyhi .asc "ldy #>",0
s_ldai  .asc "lda #",0
s_ldahi .asc "lda #>",0
s_ldxi  .asc "ldx #",0
s_ldyi  .asc "ldy #",0
s_get1  .asc "jsr r_get1",0
s_get2  .asc "jsr r_get2",0
s_ea1   .asc "jsr r_ea1",0
s_ea2   .asc "jsr r_ea2",0
s_atoj  .asc "jsr r_atoj",0
s_stw   .asc "jsr r_stw",0
s_stb   .asc "jsr r_stb",0
s_whole .asc "jsr r_whole",0
s_row   .asc "jsr r_row",0
s_rlit  .asc "jsr r_lit",0
s_rsave .asc "jsr r_save",0
s_rswap .asc "jsr r_swap",0
s_rcopy .asc "jsr r_copy",0
s_rcmp  .asc "jsr r_cmp",0
s_rlen  .asc "jsr r_len",0
s_rprint .asc "jsr r_print",0
s_rinput .asc "jsr r_input",0
s_rninp .asc "jsr r_ninput",0
s_rfill .asc "jsr r_fill",0
s_dim1  .asc "jsr r_dim1",0
s_dim2  .asc "jsr r_dim2",0
s_lda   .asc "lda ",0
s_inc   .asc "inc ",0
s_dec   .asc "dec ",0
s_etn   .asc "g_et",0
s_rsub  .asc "jsr g_rsub",0
s_sta   .asc "sta ",0
s_ldaev .asc "lda g_ev",0
s_ldaev1 .asc "lda g_ev+1",0
s_stev  .asc "sta g_ev",0
s_stev1 .asc "sta g_ev+1",0
s_stet  .asc "sta g_et",0
s_stet1 .asc "sta g_et+1",0
s_gev   .asc "g_ev",0
s_v     .asc "V_",0
s_p     .asc "P_",0
s_tst   .asc " lda g_ev",13,10," ora g_ev+1",13,10
s_bne5  .asc " bne *+5",13,10,0
s_bcc   .asc "bcc *+5",0
s_bcs   .asc "bcs *+5",0
s_rts   .asc "rts",0
s_byt   .asc ".byt ",0
s_asc   .asc ".asc ",34,0
s_bdata .asc " .word 0,0,0",13,10,0
s_vdata .asc " .word 0",13,10,0
s_hx1   .asc "h_x1",0
s_hy1   .asc "h_y1",0
s_hx2   .asc "h_x2",0
s_hy2   .asc "h_y2",0
s_hr    .asc "h_r",0
s_hires .asc "jsr h_full",0
s_split .asc "jsr h_split",0
s_text  .asc "jsr h_text",0
s_gcls  .asc "jsr g_cls",0
s_wait  .asc "jsr g_wait",0
s_pen   .asc "jsr h_pen",0
s_plot  .asc "jsr h_plot",0
s_line  .asc "jsr h_line",0
s_box   .asc "jsr h_box",0
s_fbox  .asc "jsr h_fbox",0
s_circle .asc "jsr h_circle",0
s_attr  .asc "jsr h_attr",0
s_gtext .asc "jsr g_gtext",0
s_echo  .asc "jsr g_echo",0
s_gnum  .asc "jsr g_gnum",0
s_delay .asc "jsr g_delay",0
s_print .asc "jsr g_print",0
s_gload .asc "jsr g_gload",0
s_gsave .asc "jsr g_gsave",0
s_anim  .asc "jsr a_grx",0
s_lda0  .asc "lda #0",0
s_byte  .asc "jsr g_byte",0
s_push  .asc "jsr g_push",0
s_pop   .asc "jsr g_pop",0
s_neg   .asc "jsr g_neg",0
s_rnd   .asc "jsr g_rnd",0
s_abs   .asc "jsr g_abs",0
s_point .asc "jsr g_point",0
s_inkey .asc "jsr g_inkey",0
s_ffnd  .asc "jsr f_fnd",0
s_ffnm  .asc "jsr g_fnm",0
s_fgo   .asc "jsr f_go",0
s_scrn  .asc "jsr g_scrn",0
s_lores .asc "jsr h_lores",0
s_lcls  .asc "jsr g_lcls",0
s_loc   .asc "jsr g_loc",0
s_chr   .asc "jsr g_chr",0
s_spc   .asc "jsr g_spc",0
s_ltab  .asc "jsr g_tab",0
s_get   .asc "jsr g_get",0
s_cmp   .asc "jsr g_cmp",0
s_add   .asc "jsr g_add",0
s_sub   .asc "jsr g_sub",0
s_mul   .asc "jsr g_mul",0
s_div   .asc "jsr g_div",0
s_mod   .asc "jsr g_mod",0
s_and   .asc "jsr g_and",0
s_or    .asc "jsr g_or",0
s_rept  .asc "jsr g_rept",0
s_forok .asc "jsr g_forok",0
s_fstep .asc "jsr g_forstep",0
s_brk   .asc "jsr g_brk",0
h_head1 .asc "; ",0
h_head2 .asc ".ASM : traduit de ",0
h_head2b .asc ".GRX par GRXASM",13,10
        .asc "; ASM ",0
h_head3 .asc " donne le .COM (CPA.INC, GRX.INC et",13,10
        .asc "; HIRES.INC sur le meme lecteur)",13,10
        .asc "#include ",34,"CPA.INC",34,13,10
        .asc "*= $0500",13,10
        .asc " jsr g_init",13,10,0
h_tail1 .asc "; boucles : compte, ou arrivee, pas et variable",13,10,0
h_tail2 .asc "#include ",34,"GRX.INC",34,13,10,0
h_tailA .asc "#include ",34,"ANIM.INC",34,13,10,0
h_tailR .asc "#include ",34,"ARR.INC",34,13,10,0
h_tailF .asc "#include ",34,"FIL.INC",34,13,10,0
h_tailS .asc "#include ",34,"SPR.INC",34,13,10,0
s_sres  .asc "jsr s_res",0
s_spool .asc "jsr s_pool",0
s_sshow .asc "jsr s_show",0
s_shide .asc "jsr s_hide",0
s_sk    .asc "s_k",0
s_sn    .asc "s_n",0
s_scol  .asc "s_col",0
s_slig  .asc "s_lig",0
h_tail3 .asc "#include ",34,"HIRES.INC",34,13,10,0
t_asm   .asc "ASM"
m_done  .asc ".ASM ecrit : ASM ",0
m_nodim .asc "tableau non dimensionne",0


; ndim_s : A = lettre -> A = dimensions de son tableau $ (0 : pas
;   réservé) : d'après la table kd_s
ndim_s
.(
        sec
        sbc #"A"
        tax
        lda kd_s,x
        rts
.)

; SAVE, LOAD, BSAVE, BLOAD traduits : « jsr g_fnm » et le nom, puis
;   le descripteur en A/Y, « ldx #opération », « jsr f_go » (FIL.INC)
k_save  lda #0
        beq k_file
k_load  lda #1
        bne k_file
k_bsave lda #2
        bne k_file
k_bload lda #3
k_file
.(
        pha
        jsr f_arg
        jsr getname
        jsr k_fil
        lda #<s_ffnm
        ldy #>s_ffnm
        jsr oi_fnm
        pla
        tax
        lda aak
        cmp #2
        bne ar
        cpx #2                  ; SCREEN : BSAVE et BLOAD seulement
        bcc bad
        inx
        inx
        bne op
ar      txa
        pha
        lda aal
        ldx aak
        jsr k_need
        jsr k_desc
        pla
        tax
op      stx osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        lda #<s_fgo
        ldy #>s_fgo
        jmp oi
bad     jmp e_param
.)
; ---------------------------------------------------------------------
; Sprites traduits (appels à SPR.INC)
; ---------------------------------------------------------------------
k_sprites
        jsr k_pexpr
        jsr endline
        jsr k_mat
        jsr k_spr
        lda #<s_sres
        ldy #>s_sres
        jmp oi
k_spool jsr intarg
        jsr altopt
        jsr k_ldxa
        lda aal
        ldx #0
        jsr k_need
        jsr k_desc
        lda #<s_spool
        ldy #>s_spool
        jmp oi
k_sshow lda #<s_sk
        ldy #>s_sk
        jsr k_p
        jsr sprarg
        txa
        pha
        lda aal
        ldx #1
        jsr k_need
        pla
        tax
        lda #<s_sn
        ldy #>s_sn
        jsr k_p
        lda #<s_scol
        ldy #>s_scol
        jsr k_p
        lda #<s_slig
        ldy #>s_slig
        jsr k_p
        jsr altopt
        jsr k_ldxa
        lda aal
        ldx #1
        jsr k_desc
        lda #<s_sshow
        ldy #>s_sshow
        jmp oi
k_shide jsr k_byte
        jsr endline
        jsr k_spr
        lda #<s_shide
        ldy #>s_shide
        jmp oi
; k_ldxa : « ldx #A » (tas) ; NOM.ASM inclura SPR.INC
k_ldxa  sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
k_spr   lda #1
        sta kspr
        sta karr
        rts

; k_fil : NOM.ASM inclura ARR.INC et FIL.INC
k_fil   lda #1
        sta kfil
        sta karr
        rts

; affectations ; ANIM ; console
x_asg   = k_assign
x_aasg  = k_aassign
an_val  jsr k_byte              ; ANIM nom n : constante ou calcul
        jmp endline
an_none lda #<s_lda0            ; ANIM nom : 0 (jusqu'à une touche)
        ldy #>s_lda0
        jmp oi
to_text rts                     ; (la console reste en mode texte)

m_use   .asc "GRXASM NOM [p1..p9] : traduit",13,10
        .asc "NOM.GRX en NOM.ASM (pour ASM).",13,10,"$"
a_sig   .asc "ANI"
R_DESC  = PTOP          ; descripteurs des tableaux (= R_DESC de arr.inc)

#include "grxc_inc.s"

; adresses des commandes, dans l'ordre de la table cmds (grxc_inc.s) : traduction
cadr
        .word k_next     ; NEXT
        .word k_if       ; IF
        .word k_endif    ; ENDIF
        .word k_else     ; ELSE
        .word k_locate   ; LOCATE
        .word k_char     ; CHAR
        .word k_sshow    ; SSHOW
        .word k_shide    ; SHIDE
        .word k_plot     ; PLOT
        .word k_line     ; LINE
        .word k_let      ; LET
        .word k_for      ; FOR
        .word k_repeat   ; REPEAT
        .word k_while    ; WHILE
        .word k_call     ; CALL
        .word k_endsub   ; ENDSUB
        .word k_return   ; RETURN
        .word k_sub      ; SUB
        .word k_box      ; BOX
        .word k_fbox     ; FBOX
        .word k_circle   ; CIRCLE
        .word k_pen      ; PEN
        .word k_gtext    ; GTEXT
        .word k_gnum     ; GNUM
        .word k_attr     ; ATTR
        .word k_gcls     ; GCLS
        .word k_print    ; PRINT
        .word k_delay    ; DELAY
        .word k_wait     ; WAIT
        .word k_echo     ; ECHO
        .word k_hires    ; HIRES
        .word k_split    ; SPLIT
        .word k_text     ; TEXT
        .word k_gload    ; GLOAD
        .word k_anim     ; ANIM
        .word k_gsave    ; GSAVE
        .word k_end      ; END
        .word k_spc      ; SPC
        .word k_tab      ; TAB
        .word k_get      ; GET
        .word k_cls      ; CLS
        .word k_lores    ; LORES
        .word k_dim      ; DIM
        .word k_fill     ; FILL
        .word k_input    ; INPUT
        .word k_save     ; SAVE
        .word k_load     ; LOAD
        .word k_bsave    ; BSAVE
        .word k_bload    ; BLOAD
        .word k_sprites  ; SPRITES
        .word k_spool    ; SPOOL

; tampons après le programme, mis à 0 au lancement
bufs    = *
sfcb    = bufs          ; .GRX
ifcb    = sfcb+36       ; image, animation (nom vérifié)
par_lo  = ifcb+36       ; paramètres $1-$9 : adresse et longueur
par_hi  = par_lo+NPAR
par_len = par_hi+NPAR
word    = par_len+NPAR  ; commande en cours
kw      = word+9        ; mot cherché dans la table
cname   = kw+9          ; nom de sous-programme
numbuf  = cname+9       ; nombre écrit
fvar    = numbuf+8  ; FOR : variable (lettre, second caractère)
aal     = fvar+2        ; tableau en cours : lettre
aak     = aal+1         ;   et sorte (0 entiers, 1 $)
kdn     = aak+1         ; dimensions du tableau
kdh     = kdn+1
kterm   = kdh+1         ; o_text : 0, ou le guillemet final
kd_i    = kterm+1       ; dimensions des tableaux d'entiers
kd_s    = kd_i+26       ;   et des tableaux $ (à la suite)
knb     = kd_s+26       ; boucles numérotées (Bn, 2 octets)
kb      = knb+2         ;   boucle en cours (2 octets)
kz      = kb+2          ; 1 : Z vient de la dernière instruction (g_cmp...)
kdst    = kz+1          ; 1 : l'opérande droit simple va dans g_et
ofcb    = kdst+1        ; NOM.ASM
NBUF    = ofcb+36-bufs
cs_t    = ofcb+36       ; pile de contrôle : type
cs_v    = cs_t+NCS      ;   IF : 1 après ELSE
cs_pl   = cs_v+NCS      ;   ligne de reprise
cs_ph   = cs_pl+NCS
cs_al   = cs_ph+NCS     ;   compte (REPEAT) ou arrivée (FOR)
cs_ah   = cs_al+NCS
cs_bl   = cs_ah+NCS     ;   pas (FOR)
cs_bh   = cs_bl+NCS
vs_lo   = cs_bh+NCS     ; pile des valeurs
vs_hi   = vs_lo+NVS
vs_f    = vs_hi+NVS     ; gauche constante ?
kvt     = vs_f+NVS      ; dest_var, o_vars, k_simple : travail (2 octets)
kvu     = kvt+2         ; variables à deux caractères rencontrées : 5 octets
KVU     = 130           ;   par lettre, bit (second caractère - 1)
obuf    = kvu+KVU       ; NOM.ASM : enregistrement en cours
rawbuf  = obuf+128      ; ligne lue
lbuf    = rawbuf+LMAX+1 ;   puis $1-$9 remplacés
ptext   = lbuf+LMAX+1   ; texte du fichier, jusqu'à PTOP
