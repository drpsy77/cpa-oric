;  =====================================================================
;  GRXASM.COM — traduit un fichier GRAPHER (.GRX) en assembleur
;
;  GRXASM NOM [/A|/C] [p1 ... p9]   (ou GRAPHER NOM /A ou /C, qui
;    passe la main ici)
;    NOM.GRX -> NOM.ASM, à assembler par ASM avec CPA.INC. Les routines
;    utiles de GRX.INC, HIRES.INC (ARR.INC, FIL.INC, SPR.INC, ANIM.INC
;    si besoin) y sont recopiées ; ces bibliothèques sont cherchées sur
;    le lecteur du .GRX, puis sur les lecteurs déjà lus (fonction 24) de
;    A: à D:. Même analyse que l'interpréteur (GRAPHER.COM) : les
;    routines communes sont dans grxc_inc.s. $1 à $9 sont remplacés
;    pendant la traduction ; /A est ignoré ; /C enchaîne « ASM NOM /E »
;    (CHAIN) : NOM.COM, et NOM.ASM effacé si l'assemblage réussit.
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
        sta cmode               ; /C (get_params) : 2
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
        lda #<h_code
        ldy #>h_code
        jsr os
        lda #0
        sta kn
        sta kn+1
        sta kanim
        sta karr
        sta kfil
        sta kspr
        sta csp
        sta kyx
        sta ktl                 ; noms des bibliothèques : aucun
        sta kbad
        sta kroot
        lda #1
        sta kcap
        lda #0
        ldx #51                 ; dimensions des tableaux : aucun ; aucun
kz      sta kd_i,x              ;   tableau fixe
        sta kf_ah,x
        sta kf_rt,x
        dex
        bpl kz
        lda #<PTOP              ; place des tableaux fixes : sous les
        sta kftop               ;   descripteurs, comme r_top
        lda #>PTOP
        sta kftop+1
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
        jsr kf_init             ; G_INIT, tables des lignes, adresses des
                                ;   tableaux fixes
        jsr kl_libs             ; routines utiles des bibliothèques
        jsr kf_none             ; sans tableau fixe : « G_INIT = g_init »
        jsr o_close
        jsr o_name              ; message : NOM.ASM ecrit
        lda #<m_done
        ldy #>m_done
        jsr puts
        jsr o_name
        jsr crlf
        lda cmode               ; /C : ASM NOM /E
        cmp #2
        beq to_asm
        jmp quit
.)

; to_asm : CHAIN « ASM [d:]NOM /E »
to_asm
.(
        ldy #0
        ldx #0
c1      lda t_casm,x            ; « ASM »
        sta rawbuf,y
        iny
        inx
        cpx #4
        bne c1
        lda sfcb                ; lecteur du .GRX
        beq nm
        clc
        adc #"A"-1
        sta rawbuf,y
        iny
        lda #":"
        sta rawbuf,y
        iny
nm      ldx #1
c2      lda sfcb,x
        cmp #" "
        beq e
        sta rawbuf,y
        iny
        inx
        cpx #9
        bne c2
e       ldx #0
c3      lda t_ce,x              ; « /E », 0
        sta rawbuf,y
        iny
        inx
        cpx #4
        bne c3
        lda #<rawbuf
        ldy #>rawbuf
        ldx #F_CHAIN
        jmp BDOS
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
        ldy kcap
        beq nc
        jsr kcapt               ; noms des bibliothèques relevés
nc      ldy oidx
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

; ohex : A en hexadécimal ($xx) ; ohexd : sans « $ »
ohex    pha
        lda #"$"
        jsr oc
        pla
ohexd
.(
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
; Destinations : ksym = « V_x », « Bn », un nom fixe, ou (3) un élément
;   de tableau fixe (« T_S+kfo », suivi de « ,y » si kyx) ; koff = décalage
; ---------------------------------------------------------------------
; o_sym : nom de la destination, avec +koff
o_sym
.(
        lda ksym
        beq var
        cmp #1
        beq blk
        cmp #3
        bne fix
        jmp o_asym
fix     lda ksym+1              ; nom fixe : adresse en ksym+1/+2
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
        bne fink1
        jsr k_fil
        lda #<s_ffnd            ; FOUND
        ldy #>s_ffnd
        jmp dyn
fink1   cmp #7
        bne fink2
        jmp k_ftile
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
        sty ksn
        iny                     ; variable : une lettre, puis lettre ou chiffre
        lda lbuf,y
        jsr isalpha
        bcc ks_2
        jsr isdig
        bcs ks_nm
ks_2    iny
ks_nm   lda lbuf,y              ; ni ( ni $, ni lettre ou chiffre collés
        cmp #"("
        bne ks_n1
        jsr ks_arr              ; sauf un élément d'indices constants d'un
        bcs ks_no               ;   tableau d'entiers fixe
        lda lbuf,y
        jmp ks_end
ks_n1   cmp #"$"
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
; ks_arr : Y sur « ( » après un nom (en ksn) ; C=0 si c'est un élément
;   d'un tableau d'entiers fixe dont les indices sont des nombres (adresse
;   connue : « S(3) ») ou, pour un petit tableau, des variables simples
;   (« X(I) », « G(I,J) ») : lu sans toucher g_ev ; Y après « ) »
ks_arr  tya
        sec
        sbc ksn
        cmp #1                  ; nom d'une lettre
        bne ks_an
        sty ksy
        ldx ksn
        lda lbuf,x
        jsr isalpha
        ldx #0
        jsr kf_isf
        bcs ks_an
        lda kf_sm,y
        sta kvt+1               ; (kvt+1 : variables permises)
        ldy ksy
        jsr ks_tk
        bcs ks_an
        cmp #","
        bne ks_a1
        jsr ks_tk
        bcs ks_an
ks_a1   cmp #")"
        bne ks_an
        iny
        clc
        rts
ks_an   sec
        rts
ks_tk   iny                     ; nombre, ou variable ; A = ce qui suit
        lda lbuf,y
        jsr isdig
        bcc ks_dl
        ldx kvt+1
        beq ks_dn
        jsr isalpha
        bcs ks_dr
        iny
        lda lbuf,y
        jsr isalpha
        bcc ks_v2
        jsr isdig
        bcs ks_v1
ks_v2   iny
ks_v1   lda lbuf,y
        clc
        rts
ks_dl   iny
        lda lbuf,y
        jsr isdig
        bcc ks_dl
        clc
ks_dr   rts
ks_dn   sec
        rts
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
        cmp #"/"                ; division par une constante nulle : à la
        beq kz0                 ;   traduction (l'exécution ne vérifie
        cmp #"%"                ;   rien)
        bne kz1
kz0     lda kc
        beq kz1
        lda kv
        ora kv+1
        bne kz1
        lda #<m_div
        ldy #>m_div
        jmp error
kz1     dec vsp
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

; k_byte : paramètre de 0 à 255 -> A (à l'exécution) ; une variable
;   seule : « lda V_x » (son octet bas) ; rien n'est vérifié à l'exécution
k_byte
.(
        jsr skipsp
        jsr kv_one
        bcc kb_v
        jmp kb_ex
kb_v    jsr getvar
        txa
        pha
        lda vix
        ldx vc
        jsr dest_var
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        pla
        tax
        lda #0
        sta kc
        rts
kb_ex   jsr k_pexpr
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
dyn     lda #<s_ldaev
        ldy #>s_ldaev
        jmp oi
.)

; kv_one : en lbuf (X), une variable simple seule (A, AB, A1, puis fin,
;   espace ou « ; ») ? -> C=0 ; X ne change pas
kv_one
.(
        lda lbuf,x
        jsr isalpha
        bcs no
        lda lbuf+1,x
        jsr isalpha
        bcc two
        lda lbuf+1,x
        jsr isdig
        bcs one
two     lda lbuf+2,x
        jmp chk
one     lda lbuf+1,x
chk     beq yes
        cmp #" "
        beq yes
        cmp #";"
        beq yes
no      sec
        rts
yes     clc
        rts
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

; PRINTV, ECHOV, SPCV : la même chose entre h_lvon et h_lvoff
k_printv
        jsr k_vlon
        jsr k_print
        jmp k_vloff
k_echov jsr k_vlon
        jsr k_echo
        jmp k_vloff
k_spcv  jsr k_vlon
        jsr k_spc
k_vloff lda #<s_vloff
        ldy #>s_vloff
        jmp oi
k_vlon  lda #<s_vlon
        ldy #>s_vlon
        jmp oi

; SCROLH n, SCROLV n [c1 l1 c2 l2 [x]], ROTH n, ROTV n [c1 l1 c2 l2] :
;   r_sdef, r_sn, rectangle et octet facultatifs, puis « lda #op » et
;   r_scrl
k_scrolh
        lda #0
        .byt $2C                ; (BIT abs : saute l'instruction suivante)
k_scrolv
        lda #1
        .byt $2C
k_roth  lda #2
        .byt $2C
k_rotv  lda #3
.(
        pha
        lda #1                  ; NOM.ASM inclura ARR.INC (r_scrl)
        sta karr
        lda #<s_sdef
        ldy #>s_sdef
        jsr oi
        jsr k_pexpr
        lda #<s_hsn
        ldy #>s_hsn
        jsr dest_fix
        jsr o_st16
        lda #0
        sta kc
        jsr skipsp
        beq e
        cmp #";"
        beq e
        jsr k_p2
        lda #<s_hx2
        ldy #>s_hx2
        jsr k_p
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        pla
        pha
        and #2
        bne e                   ; rotation : pas d'octet de remplissage
        jsr skipsp
        beq e
        cmp #";"
        beq e
        lda #<s_hsf
        ldy #>s_hsf
        jsr k_p
e       jsr endline
        pla
        sta osv
        lda #<s_ldai
        ldy #>s_ldai
        jsr oimm
        lda #<s_scrl
        ldy #>s_scrl
        jmp oi
.)

; PASTE T$(c,l) col lig larg haut, GRAB : indices sur la pile des
;   valeurs, coin et taille dans h_x1 h_y1 h_x2 h_y2, descripteur dans
;   A/Y, puis g_paste ou g_grab
k_paste lda #0
        .byt $2C
k_grab  lda #1
.(
        pha
        jsr skipsp
        jsr isalpha
        bcs bad
        sta aal
        inx
        lda lbuf,x
        cmp #"$"
        bne bad
        inx
        stx ex
        lda aal
        ldx #1
        jsr k_need
        lda #1
        sta karr
        lda #0
        sta vsp
        sta edep
        jsr x_open
        jsr k_or
        jsr k_mat
        jsr k_push
        jsr x_comma
        jsr k_or
        jsr k_mat
        jsr k_push
        jsr x_close
        ldx ex
        lda lbuf,x
        cmp #" "
        bne bad
        jsr k_p2
        lda #<s_hx2
        ldy #>s_hx2
        jsr k_p
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jsr endline
        lda aal
        ldx #1
        jsr k_desc
        pla
        bne g
        lda #<s_paste
        ldy #>s_paste
        jmp oi
g       lda #<s_grab
        ldy #>s_grab
        jmp oi
bad     jmp e_param
.)
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
; PRINT e1 e2 ... [;] : chaque élément calcule sa valeur (g_ev) ou sa
;   chaîne, puis l'appel qui l'affiche (g_pnum, r_pstr) ; celui du dernier
;   est gardé (kpp) : un élément seul sans « ; » donne l'appel qui passe
;   aussi à la ligne (g_print, r_print), sinon g_pend à la fin
k_print
.(
        stx ex
        lda #0
        sta kpp+1
        sta kpi
kpit    ldx ex
        jsr skipsp
        beq kpnl
        cmp #";"
        beq kpsm
        stx ex
        jsr kp_fl
        inc kpi
        lda #1                  ; espaces permis dans un calcul (A - B)
        sta edep
        lda #0
        sta vsp
        jsr is_str              ; une chaîne seule (pas une comparaison) ?
        bcs kpnum
        jsr str_only
        bcs kpnum
        jsr k_str
        lda #<s_rpstr
        ldy #>s_rpstr
        bne kpend
kpnum   jsr k_or
        jsr k_mat
        lda #<s_pnum
        ldy #>s_pnum
kpend   sta kpp
        sty kpp+1
        jmp kpit
kpsm    inx                     ; « ; » seul en fin de ligne : on reste
        jsr skipsp
        beq kp_fl
        cmp #";"
        beq kp_fl
kpnl    lda kpi                 ; un seul élément : l'appel avec passage
        cmp #1                  ;   à la ligne
        bne kpn2
        lda kpp
        ldy #<s_print
        ldx #>s_print
        cmp #<s_pnum
        beq kpn1
        ldy #<s_rprint
        ldx #>s_rprint
kpn1    tya
        pha
        txa
        tay
        pla
        jmp oi
kpn2    jsr kp_fl
        lda #<s_pend
        ldy #>s_pend
        jmp oi
.)
; kp_fl : écrit l'appel en attente du PRINT (kpp), s'il y en a un
kp_fl   lda kpp+1
        beq kpf_r
        ldy kpp+1
        lda kpp
        ldx #0
        stx kpp+1
        jmp oi
kpf_r   rts
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
krb1    lda #<s_ldaev
        ldy #>s_ldaev
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
        jsr kf_isf              ; tableau fixe : accès direct
        bcs old
        jmp kf_get
old     pha
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
idx     lda aal                 ; élément d'un tableau fixe : accès direct
        ldx aak
        jsr kf_isf
        bcs idx0
        cpx #0
        beq kfp
        jsr kd_get              ; M$(l) = chaîne : une ligne
        cmp #2
        bne kfp
        jsr kf_hcom
        bcs idx0
kfp     jmp kf_put
idx0    jsr x_open
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

; DIM traduit. Un tableau de tailles constantes, hors de tout bloc et
;   déclaré pour la première fois, est fixe (kf_new) : réservé au lancement
;   par G_INIT, à une adresse connue ici ; rien n'est écrit à la ligne du DIM
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
        sta kf_s2
        sta kf_s2+1
        lda #1
        sta karr
        jsr x_open
        jsr k_or                ; taille 1 : constante gardée (kfc)
        lda kc
        sta kfc
        lda kv
        sta kf_s1
        lda kv+1
        sta kf_s1+1
        jsr ws
        jsr gch
        cmp #","
        bne one
        inc ex
        lda kfc
        bne t1
        jsr k_push              ; taille 1 calculée : sur la pile
t1      jsr k_or                ; taille 2
        jsr x_close
        lda #2
        sta kdn
        lda kc
        beq t2d
        lda kv
        sta kf_s2
        lda kv+1
        sta kf_s2+1
        lda kfc
        beq t2c
        jsr kf_new              ; deux constantes : fixe ?
        bcc fix
        jsr k_mat               ; non : taille 2 -> g_ev,
        jsr kd_et               ;   taille 1 -> g_et
        jmp emit
t2c     jsr k_mat               ; taille 1 calculée, 2 constante
t2p     jsr k_pop
        jmp emit
t2d     lda kfc                 ; taille 2 calculée
        beq t2p
        jsr kd_et
        jmp emit
one     jsr x_close
        lda #1
        sta kdn
        lda kfc
        beq emit
        jsr kf_new              ; constante : fixe ?
        bcc fix
        jsr k_mat
emit    jsr kd_note
        lda aak                 ; « ldx #octets », descripteur, r_dim
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
        jmp nx
fix     jsr kd_note
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

; kd_note : dimensions (kdn) du tableau aal, aak notées pour la suite
kd_note lda aal
        sec
        sbc #"A"
        tay
        lda kdn
        ldx aak
        bne kdn_s
        sta kd_i,y
        rts
kdn_s   sta kd_s,y
        rts

; kd_et : taille 1 constante (kf_s1) -> g_et
kd_et   lda kf_s1
        sta kv
        lda kf_s1+1
        sta kv+1
; k_etc : constante kv -> g_et
k_etc   lda #1
        sta kc
        lda #<s_etn
        ldy #>s_etn
        jsr dest_fix
        jsr o_st16
        lda #0
        sta kc
        rts

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
ok      cmp #T_FOR                  ; (pas de test d'ESC dans les boucles)
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
s_rpstr .asc "jsr r_pstr",0
s_pnum  .asc "jsr g_pnum",0
s_pend  .asc "jsr g_pend",0
s_rinput .asc "jsr r_input",0
s_rninp .asc "jsr r_ninput",0
s_rfill .asc "jsr r_fill",0
s_dim1  .asc "jsr r_dim1",0
s_dim2  .asc "jsr r_dim2",0
s_lda   .asc "lda ",0
s_ldx   .asc "ldx ",0
s_ldy   .asc "ldy ",0
s_adc   .asc "adc ",0
s_adci  .asc "adc #",0
s_asl   .asc "asl",0
s_clc   .asc "clc",0
s_tay   .asc "tay",0
s_pha   .asc "pha",0
s_pla   .asc "pla",0
s_cx    .asc ",x",0
s_equ   .asc " = ",0
s_gcode .asc "G_INIT jsr g_init",13,10    ; après le commentaire s_ginit
        .asc " inc g_sp",13,10
        .asc " inc g_sp",13,10,0
s_ginone .asc "G_INIT = g_init",13,10,0
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
s_loc   .asc "jsr h_loc",0
s_chr   .asc "jsr h_chr",0
s_spc   .asc "jsr g_spc",0
s_ltab  .asc "jsr h_ltab",0
s_vlon  .asc "jsr h_lvon",0
s_vloff .asc "jsr h_lvoff",0
s_sdef  .asc "jsr r_sdef",0
s_hsn   .asc "r_sn",0
s_hsf   .asc "r_sf",0
s_scrl  .asc "jsr r_scrl",0
s_paste .asc "jsr g_paste",0
s_grab  .asc "jsr g_grab",0
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
h_head1 .asc "; ",0
h_code  .asc "#include ",34,"CPA.INC",34,13,10   ; après le commentaire h_head3
        .asc "*= $0500",13,10
        .asc " jsr G_INIT",13,10,0
s_sres  .asc "jsr s_res",0
s_spool .asc "jsr s_pool",0
s_sshow .asc "jsr s_show",0
s_tset  .asc "jsr t_set",0
s_tmap  .asc "jsr g_tmap",0
s_tfont .asc "jsr t_font",0
s_tget  .asc "jsr t_get",0
s_tw    .asc "t_w",0
s_th    .asc "t_h",0
s_tc    .asc "t_c",0
s_shide .asc "jsr s_hide",0
s_sk    .asc "s_k",0
s_sn    .asc "s_n",0
s_scol  .asc "s_col",0
s_slig  .asc "s_lig",0
t_asm   .asc "ASM"


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
; ---------------------------------------------------------------------
; Tuiles traduites (appels à SPR.INC)
; ---------------------------------------------------------------------
; TILE(x,y) : comme SCRN (g_et = x, g_ev = y), puis t_get
k_ftile jsr k_spr
        jsr x_open
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
        lda #<s_tget
        ldy #>s_tget
        jmp k_oi
; TILESET D$ larg haut [K$] : t_w, t_h, chaîne courante, X = 1 si K$
k_tileset
.(
        jsr sprarg
        jsr k_need1
        lda #<s_tw
        ldy #>s_tw
        jsr k_p
        lda #<s_th
        ldy #>s_th
        jsr k_p
        jsr skipsp
        beq no
        cmp #";"
        beq no
        stx ex
        lda #0
        sta edep
        jsr k_str               ; K$ : chaîne courante
        ldx ex
        jsr endline
        lda #1
        .byt $2C                ; (BIT abs : saute lda #0)
no      lda #0
        jsr k_ldxa
        lda aal
        ldx #1
        jsr k_desc
        lda #<s_tset
        ldy #>s_tset
        jmp oi
.)
; TMAP T$ X Y col lig larg haut : X, Y sur la pile des valeurs, fenêtre
;   dans h_x1 h_y1 h_x2 h_y2, descripteur dans A/Y, puis g_tmap
k_tmap
.(
        jsr sprarg
        jsr k_need1
        jsr k_pexpr
        jsr k_mat
        jsr k_push
        jsr k_pexpr
        jsr k_mat
        jsr k_push
        jsr k_p2
        lda #<s_hx2
        ldy #>s_hx2
        jsr k_p
        lda #<s_hy2
        ldy #>s_hy2
        jsr k_p
        jsr endline
        jsr k_spr
        lda aal
        ldx #1
        jsr k_desc
        lda #<s_tmap
        ldy #>s_tmap
        jmp oi
.)
; TFONT S$ code [ALT]
k_tfont jsr sprarg
        jsr k_need1
        lda #<s_tc
        ldy #>s_tc
        jsr k_p
        jsr altopt
        jsr k_ldxa
        lda aal
        ldx #1
        jsr k_desc
        lda #<s_tfont
        ldy #>s_tfont
        jmp oi

; k_need1 : le tableau $ aal doit être déclaré (X gardé)
k_need1 txa
        pha
        lda aal
        ldx #1
        jsr k_need
        pla
        tax
        rts

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

; ---------------------------------------------------------------------
; Tableaux à adresse fixe
; ---------------------------------------------------------------------
; Un tableau fixe (k_dim, kf_new) est réservé au lancement par G_INIT
;   (r_dim1, r_dim2 dans l'ordre des DIM, avant tout autre), sous R_DESC :
;   son adresse est donc connue ici (kftop suit r_top) et NOM.ASM la nomme
;   T_S (entiers) ou C_S (tableau $). Un élément d'indices constants est
;   une adresse fixe (« lda T_S+6 ») ; dans un petit tableau (256 octets au
;   plus), un indice calculé donne le décalage dans Y (« lda T_S,y ») ;
;   pour deux indices, une table des lignes (TR_S : décalage du début de
;   chaque ligne) évite la multiplication. Un grand tableau passe par son
;   descripteur, comme un tableau ordinaire. Cases 0-25 : entiers, 26-51 :
;   tableaux $.

; kf_isf : A = lettre, X = sorte : C=0 si le tableau est fixe (Y = case) ;
;   A et X gardés
kf_isf
.(
        pha
        sec
        sbc #"A"
        cpx #0
        beq i1
        adc #25                 ; (C=1) + 26
i1      tay
        lda kf_ah,y
        beq no
        pla
        clc
        rts
no      pla
        sec
        rts
.)

; kf_set : comme kf_isf, et si fixe : kfy, kfe (octets par élément), kfsm
kf_set
.(
        jsr kf_isf
        bcs r
        sty kfy
        pha
        lda kf_sm,y
        sta kfsm
        lda #2
        cpx #0
        beq e
        lda #1
e       sta kfe
        pla
        clc
r       rts
.)

; kf_new : le tableau aal, aak du DIM (tailles kf_s1, kf_s2, kdn
;   dimensions) peut-il être fixe ? C=0 : oui, il est réservé ici
kf_new
.(
        lda csp                 ; hors de tout bloc
        beq k0
nt      sec
        rts
k0      lda aal                 ; premier DIM de ce tableau
        ldx aak
        jsr kd_get
        bne nt
        lda kf_s1+1             ; taille 1 : 1 à 32767
        bmi nt
        ora kf_s1
        beq nt
        lda kf_s1
        sta km_a
        lda kf_s1+1
        sta km_a+1
        lda #1
        sta km_b
        lda #0
        sta km_b+1
        lda kdn
        cmp #2
        bne n1
        lda kf_s2+1             ; taille 2 : 1 à 32767
        bmi nt
        ora kf_s2
        beq nt
        lda kf_s2
        sta km_b
        lda kf_s2+1
        sta km_b+1
n1      jsr kmul                ; éléments, puis octets (comme r_dim)
        bcs no
        lda aak
        bne n2
        asl km_p
        rol km_p+1
        bmi no
n2      sec                     ; adresse = haut - octets
        lda kftop
        sbc km_p
        sta kt
        lda kftop+1
        sbc km_p+1
        bcc no
        cmp #>$0500             ; trop bas : DIM ordinaire (« memoire
        bcc no                  ;   pleine » au lancement)
        sta kt+1
        lda aal
        ldx aak
        jsr kf_isf              ; Y = case
        lda kt
        sta kf_al,y
        sta kftop
        lda kt+1
        sta kf_ah,y
        sta kftop+1
        lda kf_s1
        sta kf_1l,y
        lda kf_s1+1
        sta kf_1h,y
        lda kf_s2
        sta kf_2l,y
        lda kf_s2+1
        sta kf_2h,y
        ldx #0                  ; petit : 256 octets au plus
        lda km_p+1
        beq sm
        cmp #1
        bne sm0
        lda km_p
        bne sm0
sm      inx
sm0     txa
        sta kf_sm,y
        clc
        rts
no      sec
        rts
.)

; kmul : km_p <- km_a * km_b (positifs) ; C=1 au-delà de 32767
kmul
.(
        lda #0
        sta km_p
        sta km_p+1
l       lda km_b
        ora km_b+1
        beq d
        lsr km_b+1
        ror km_b
        bcc n
        clc
        lda km_p
        adc km_a
        sta km_p
        lda km_p+1
        adc km_a+1
        sta km_p+1
        bcs o
        bmi o
n       lda km_b
        ora km_b+1
        beq d
        asl km_a
        rol km_a+1
        bcs o
        bpl l
o       sec
        rts
d       clc
        rts
.)

; kf_init : fin de NOM.ASM, s'il y a des tableaux fixes : G_INIT (les DIM
;   fixes, du plus haut au plus bas), les tables des lignes utilisées, les
;   adresses (« T_S = $9D56 »)
kf_init
.(
        lda kftop
        cmp #<PTOP
        bne go
        lda kftop+1
        cmp #>PTOP
        bne go
        rts
go      lda #<s_ginit
        ldy #>s_ginit
        jsr os
        lda #<s_gcode
        ldy #>s_gcode
        jsr os
        lda #<PTOP
        sta kt
        lda #>PTOP
        sta kt+1
loop    lda #$FF                ; le plus haut sous kt
        sta kfy
        lda #0
        sta km_a
        sta km_a+1
        ldy #51
f       lda kf_ah,y
        beq fn
        lda kf_al,y
        cmp kt
        lda kf_ah,y
        sbc kt+1
        bcs fn
        lda km_a
        cmp kf_al,y
        lda km_a+1
        sbc kf_ah,y
        bcs fn
        lda kf_al,y
        sta km_a
        lda kf_ah,y
        sta km_a+1
        sty kfy
fn      dey
        bpl f
        ldy kfy
        bmi done
        lda km_a
        sta kt
        lda km_a+1
        sta kt+1
        jsr kf_dimo
        jmp loop
done    lda #<s_rts
        ldy #>s_rts
        jsr oi
        ldy #0                  ; tables des lignes
t       lda kf_rt,y
        beq tn
        sty kfy
        jsr kf_rows
        ldy kfy
tn      iny
        cpy #52
        bne t
        ldy #0                  ; adresses
e       lda kf_ah,y
        beq en
        sty kfy
        clc
        jsr o_aname
        lda #<s_equ
        ldy #>s_equ
        jsr os
        ldy kfy
        lda kf_ah,y
        jsr ohex
        ldy kfy
        lda kf_al,y
        jsr ohexd
        jsr ocrlf
        ldy kfy
en      iny
        cpy #52
        bne e
        rts
.)

; kf_none : sans tableau fixe, G_INIT est g_init
kf_none
.(
        lda kftop
        cmp #<PTOP
        bne r
        lda kftop+1
        cmp #>PTOP
        bne r
        lda #<s_ginone
        ldy #>s_ginone
        jmp os
r       rts
.)

; kf_dimo : le DIM du tableau fixe kfy, dans G_INIT
kf_dimo
.(
        ldy kfy
        lda kf_1l,y
        sta kv
        lda kf_1h,y
        sta kv+1
        lda kf_2l,y
        ora kf_2h,y
        beq d1
        jsr k_etc               ; taille 1 -> g_et
        ldy kfy
        lda kf_2l,y
        sta kv
        lda kf_2h,y
        sta kv+1
        lda #2
        bne d2
d1      lda #1
d2      sta kdn
        lda #1                  ; taille (2) -> g_ev
        sta kc
        jsr k_mat
        lda #2                  ; « ldx #octets »
        ldy kfy
        cpy #26
        bcc d3
        lda #1
d3      sta osv
        lda #<s_ldxi
        ldy #>s_ldxi
        jsr oimm
        jsr kf_desc
        lda #<s_dim1
        ldy #>s_dim1
        ldx kdn
        cpx #2
        bne d4
        lda #<s_dim2
        ldy #>s_dim2
d4      jmp oi
.)

; kf_rows : table des lignes du tableau kfy (« TR_S .byt $00,$10,... »)
kf_rows
.(
        sec
        jsr o_aname
        lda #" "
        jsr oc
        ldy kfy
        lda kf_1l,y             ; octets par ligne (taille 1 : colonnes)
        cpy #26
        bcs r1
        asl
r1      sta kfrs
        lda kf_2l,y             ; nombre de lignes (taille 2)
        sta kt
        lda kf_2h,y
        sta kt+1
        lda #0
        sta kfv0
ln      lda #<s_byt
        ldy #>s_byt
        jsr os
        ldx #16
nx      lda kfv0
        jsr ohex
        clc
        lda kfv0
        adc kfrs
        sta kfv0
        lda kt
        bne d
        dec kt+1
d       dec kt
        lda kt
        ora kt+1
        beq end
        dex
        beq eol
        lda #","
        jsr oc
        jmp nx
eol     jsr ocrlf
        jmp ln
end     jmp ocrlf
.)

; o_aname : nom du tableau fixe kfy (« T_S », « C_S ») ; C=1 : sa table
;   des lignes (« TR_S », « CR_S »)
o_aname
.(
        php
        lda #"T"
        ldx kfy
        cpx #26
        bcc a1
        lda #"C"
a1      jsr oc
        plp
        bcc a2
        lda #"R"
        jsr oc
a2      lda #"_"
        jsr oc
        txa
        cmp #26
        bcc a3
        sbc #26
a3      clc
        adc #"A"
        jmp oc
.)

; o_asym : (o_sym, ksym = 3) « T_S », +kfo+koff, « ,y » si kyx
o_asym
.(
        clc
        jsr o_aname
        clc
        lda kfo
        adc koff
        sta kt
        lda kfo+1
        adc #0
        sta kt+1
        ora kt
        beq y
        lda #"+"
        jsr oc
        lda kl                  ; décimal (odec écrit kl)
        pha
        lda kl+1
        pha
        lda kt
        sta kl
        lda kt+1
        sta kl+1
        jsr odec
        pla
        sta kl+1
        pla
        sta kl
y       lda kyx
        beq r
        lda #","
        jsr oc
        lda #"y"
        jmp oc
r       rts
.)

; kf_desc : « lda #lo / ldy #hi » du descripteur du tableau kfy
kf_desc
.(
        lda kfy
        ldx #0
        cmp #26
        bcc d
        sbc #26
        inx
d       clc
        adc #"A"
        jmp k_desc
.)

; kf_dst : destination = élément du tableau kfy (kfo, kyx)
kf_dst  lda #3
        sta ksym
        lda #0
        sta koff
        rts

; kf_look : nature de ce qui commence en ex : 1 une variable simple, 2 un
;   nombre (« -3 » compris), 0 autre chose ; suivi (espaces permis) de ) ou ,
;   (kfvm = 0, un indice) ou de la fin de la ligne (kfvm = 1, une valeur)
kf_look
.(
        ldy ex
        jsr sp
        lda lbuf,y
        cmp #"-"
        bne v0
        iny
        lda lbuf,y
        jsr isdig
        bcs no
v0      jsr isdig
        bcc num
        jsr isalpha
        bcs no
        iny
        lda lbuf,y
        jsr isalpha
        bcc v2
        jsr isdig
        bcs v1
v2      iny
v1      lda #1
        bne e
num     iny
        lda lbuf,y
        jsr isdig
        bcc num
        lda #2
e       sta kq2
        jsr sp
        lda lbuf,y
        ldx kfvm
        bne val
        cmp #")"
        beq yes
        cmp #","
        beq yes
no      lda #0
        rts
val     cmp #0
        beq yes
        cmp #";"
        bne no
yes     lda kq2
        rts
sp      lda lbuf,y
        cmp #" "
        bne r
        iny
        bne sp
r       rts
.)

; kf_one : indice X (0 ou 1) en ex -> kcl,x = 0 calculé (g_ev), 1 variable
;   (kix,x, kic,x : petit tableau seulement), 2 constante (kil,x, kih,x)
kf_one
.(
        stx kw1
        lda kfsm
        beq e
        lda #0
        sta kfvm
        jsr kf_look
        cmp #1
        bne e
        ldx ex
        jsr getvar
        stx ex
        ldx kw1
        lda vix
        sta kix,x
        lda vc
        sta kic,x
        lda #1
        bne r
e       jsr k_or
        ldx kw1
        lda kc
        beq r
        lda kv
        sta kil,x
        lda kv+1
        sta kih,x
        lda #2
r       sta kcl,x
        rts
.)

; kq_fr : l'opérande de kf_op est l'indice X (variable, sinon g_ev)
kq_fr   lda kcl,x
        and #1
        sta kq
        lda kix,x
        sta kqx
        lda kic,x
        sta kqc
        rts

; kf_mat : indice constant X -> g_ev (kcl,x = 0)
kf_mat  lda kil,x
        sta kv
        lda kih,x
        sta kv+1
        lda #0
        sta kcl,x
        lda #1
        sta kc
        jmp k_mat

; kf_op : instruction A/Y (« lda ») sur l'opérande kq : variable kqx, kqc,
;   sinon g_ev
kf_op
.(
        pha
        tya
        pha
        lda kq
        beq vg
        lda kqx
        ldx kqc
        jsr dest_var
        jmp go
vg      lda #<s_gev
        ldy #>s_gev
        jsr dest_fix
go      pla
        tay
        pla
        jmp o_ins_sym
.)
kf_lda  lda #<s_lda
        ldy #>s_lda
        jmp kf_op
kf_adc  lda #<s_adc
        ldy #>s_adc
        jmp kf_op
o_asl   lda #<s_asl
        ldy #>s_asl
        jmp oi
o_clc   lda #<s_clc
        ldy #>s_clc
        jmp oi

; kf_row : « ldx op / lda TR_S,x » : début de la ligne de l'indice kq
kf_row
.(
        lda #<s_ldx
        ldy #>s_ldx
        jsr kf_op
        jsr o_tab
        lda #<s_lda
        ldy #>s_lda
        jsr os
        sec
        jsr o_aname
        lda #<s_cx
        ldy #>s_cx
        jsr os
        jsr ocrlf
        ldy kfy
        lda #1
        sta kf_rt,y
        rts
.)

; kf_r1 : kfr1 <- début constant de la ligne kil+1 (second indice ; octet
;   bas)
kf_r1
.(
        ldy kfy
        lda kf_1l,y             ; colonnes
        ldx kfe
        cpx #2
        bne r0
        asl
r0      sta kt
        lda #0
        ldx kil+1
        beq r2
r1      clc
        adc kt
        dex
        bne r1
r2      sta kfr1
        rts
.)

; kf_st1 : indice constant kil -> kfo = décalage ; C=1 s'il ne convient pas
kf_st1
.(
        lda kih
        bmi no
        sta kfo+1
        lda kil
        sta kfo
        lda kfe
        cmp #2
        bne ok
        asl kfo
        rol kfo+1
        bmi no
ok      clc
        rts
no      sec
        rts
.)

; kf_st2 : indices constants kil (colonne), kil+1 (ligne) -> kfo ; C=1
;   s'il ne convient pas
kf_st2
.(
        lda kih
        ora kih+1
        bmi no
        lda kil+1               ; ligne * colonnes + colonne
        sta km_a
        lda kih+1
        sta km_a+1
        ldy kfy
        lda kf_1l,y
        sta km_b
        lda kf_1h,y
        sta km_b+1
        jsr kmul
        bcs no
        clc
        lda km_p
        adc kil
        sta kfo
        lda km_p+1
        adc kih
        sta kfo+1
        bmi no
        lda kfe
        cmp #2
        bne ok
        asl kfo
        rol kfo+1
        bmi no
ok      clc
        rts
no      sec
        rts
.)

; kf_ix : indices de l'élément du tableau fixe kfy (ex sur « ( ») ->
;   kfm = 0 : adresse fixe (kfo) ; 1 : décalage dans A (code écrit) ;
;   3 : décalage = octet bas de l'opérande kq (pas encore lu) ;
;   2 : par le descripteur : g_ev (kfn = 1), ou g_et et g_ev (kfn = 2)
kf_ix
.(
        lda #0
        sta kyx
        sta kfr
        jsr x_open
        ldx #0
        jsr kf_one
        jsr ws
        jsr gch
        cmp #","
        bne one
        jmp two
one     jsr x_close             ; ---- un indice (tableau mis à plat)
        lda kfe                 ; M$(i) : une chaîne
        cmp #2
        beq o0
        ldy kfy
        lda kf_2l,y
        ora kf_2h,y
        beq o0
        jmp e_strc
o0      lda kcl
        cmp #2
        bne o1
        jsr kf_st1              ; constant : adresse fixe
        bcc stat
        ldx #0
        jsr kf_mat
o1      lda kfsm
        bne o2
        lda #1                  ; grand tableau : par le descripteur
        jmp desc
o2      ldx #0
        jsr kq_fr
        lda kfe
        cmp #2
        beq o3
        lda #3                  ; octets : le décalage est l'indice
        sta kfm
        rts
o3      jsr kf_lda
        jsr o_asl
        jmp m1
stat    lda #0
        sta kfm
        rts
two     inc ex                  ; ---- deux indices
        lda kfsm
        bne s0
        lda kcl                 ; grand tableau
        bne b1
        jsr k_push              ; premier calculé : sur la pile
b1      jsr k_or
        jsr x_close
        lda kcl
        bne b2
        jsr k_mat
        jsr k_pop
        jmp desc2
b2      lda kc                  ; premier constant
        beq b3
        lda kv
        sta kil+1
        lda kv+1
        sta kih+1
        jsr kf_st2
        bcc stat
b3      jsr k_mat               ; second -> g_ev, premier -> g_et
        lda kil
        sta kv
        lda kih
        sta kv+1
        jsr k_etc
desc2   lda #2
desc    sta kfn
        lda #2
        sta kfm
        rts
s0      lda #0                  ; petit tableau : début de la ligne (second
        sta kfr                 ;   indice, table TR_S) + colonne (premier)
        lda kcl                 ; colonne calculée (dans g_ev) et ligne
        bne s1                  ;   calculée aussi : la colonne (* 2) va
        sta kfvm                ;   sur la pile (kfr = 2)
        jsr kf_look
        bne s1
        ldx #0
        jsr kq_fr
        jsr kf_lda
        lda kfe
        cmp #2
        bne s0p
        jsr o_asl
s0p     lda #<s_pha
        ldy #>s_pha
        jsr oi
        lda #2
        sta kfr
s1      ldx #1                  ; la ligne
        jsr kf_one
        jsr x_close
        lda kcl+1
        cmp #2
        bne rv
        lda kcl                 ; ---- ligne constante
        cmp #2
        bne rc
        jsr kf_st2              ; colonne constante aussi : adresse fixe
        bcs rc0
        jmp stat
rc0     ldx #0                  ; ne convient pas : la colonne dans g_ev
        jsr kf_mat
rc      jsr kf_r1               ; colonne (* 2) + début constant de la ligne
        ldx #0
        jsr kq_fr
        lda kfe
        cmp #2
        beq rc2
        lda kfr1
        bne rc3
        lda #3                  ; décalage = la colonne
        sta kfm
        rts
rc3     jsr kf_lda
        jmp rc4
rc2     jsr kf_lda
        jsr o_asl
        lda kfr1
        bne rc4
        jmp m1
rc4     jsr o_clc
        lda kfr1
        sta osv
        lda #<s_adci
        ldy #>s_adci
        jsr oimm
        jmp m1
rv      lda kfr                 ; ---- ligne variable ou calculée
        cmp #2
        bne rv1
        lda #<s_pla             ; colonne gardée -> g_et
        ldy #>s_pla
        jsr oi
        lda #<s_stet
        ldy #>s_stet
        jsr oi
rv1     ldx #1
        jsr kq_fr
        jsr kf_row              ; A = début de la ligne
        lda kfr
        cmp #2
        bne rv2
        jsr o_clc               ; + colonne gardée
        lda #<s_etn
        ldy #>s_etn
        jsr dest_fix
        lda #<s_adc
        ldy #>s_adc
        jsr o_ins_sym
        jmp m1
rv2     lda kcl                 ; colonne constante
        cmp #2
        bne rv3
        lda kil
        ldx kfe
        cpx #2
        bne rv4
        asl
rv4     cmp #0
        beq m1
        sta osv
        jsr o_clc
        lda #<s_adci
        ldy #>s_adci
        jsr oimm
        jmp m1
rv3     ldx #0                  ; colonne variable, ou dans g_ev
        jsr kq_fr
        jsr o_clc
        jsr kf_adc
        lda kfe
        cmp #2
        bne m1
        jsr kf_adc
m1      lda #1
        sta kfm
        rts
.)

; kf_toy : décalage -> Y (« tay », ou « ldy op »)
kf_toy
.(
        lda kfm
        cmp #3
        beq t3
        lda #<s_tay
        ldy #>s_tay
        jmp oi
t3      lda #<s_ldy
        ldy #>s_ldy
        jmp kf_op
.)
; kf_pha : décalage -> pile du 6502
kf_pha
.(
        lda kfm
        cmp #3
        bne p
        jsr kf_lda
p       lda #<s_pha
        ldy #>s_pha
        jmp oi
.)

; kf_get : (k_aget) élément du tableau fixe A, X -> g_ev ; l'état des
;   tableaux fixes est gardé sur la pile (un indice peut lire un autre
;   tableau : « X(P(I)) »)
kf_get
.(
        sta kfa
        stx kfk
        ldx #KFN-1
s       lda kfst,x
        pha
        dex
        bpl s
        lda kfa
        ldx kfk
        jsr kf_set
        jsr kf_ix
        lda kfm
        cmp #2
        bne g1
        jsr kf_desc             ; par le descripteur
        lda #<s_get1
        ldy #>s_get1
        ldx kfn
        cpx #2
        bne g0
        lda #<s_get2
        ldy #>s_get2
g0      jsr oi
        jmp z
g1      cmp #0
        beq g3
        jsr kf_toy              ; décalage dans Y
        lda #0
        sta kfo
        sta kfo+1
        lda #1
        sta kyx
g3      jsr kf_dst
        lda kfe
        cmp #2
        bne g4
        jsr ld_var              ; « lda T_S+n / sta g_ev ... »
        jmp z
g4      jsr kf_ldb
z       ldx #0
r       pla
        sta kfst,x
        inx
        cpx #KFN
        bne r
        lda #0
        sta kc
        rts
.)

; kf_ldb : octet de la destination -> g_ev
kf_ldb  lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        lda #<s_stev
        ldy #>s_stev
        jsr oi
        lda #<s_lda0
        ldy #>s_lda0
        jsr oi
        lda #<s_stev1
        ldy #>s_stev1
        jmp oi

; kf_stb : valeur (kc/kv ou g_ev) -> A, de 0 à 255 (sinon erreur, à
;   l'exécution comme r_stb)
kf_stb
.(
        lda kc
        beq dyn
        lda kv+1
        bne big
        lda kv
        sta osv
        lda #<s_ldai
        ldy #>s_ldai
        jmp oimm
big     lda #<m_range           ; constante hors de 0-255 : à la traduction
        ldy #>m_range
        jmp error
dyn     lda #<s_ldaev
        ldy #>s_ldaev
        jmp oi
.)

; kf_put : (k_aassign, ex sur « ( ») affectation d'un élément du tableau
;   fixe aal, aak
kf_put
.(
        lda aal
        ldx aak
        jsr kf_set
        jsr kf_ix
        lda kfm
        cmp #2
        bne p1
        jsr kf_desc             ; par le descripteur : comme un tableau
        lda #<s_ea1             ;   ordinaire
        ldy #>s_ea1
        ldx kfn
        cpx #2
        bne p0
        lda #<s_ea2
        ldy #>s_ea2
p0      jsr oi
        lda #<s_atoj
        ldy #>s_atoj
        jsr oi
        jsr k_push
        jsr aeq
        jsr k_lexpr
        jsr k_mat
        jsr k_pop
        lda #<s_stw
        ldy #>s_stw
        ldx kfe
        cpx #2
        beq pw
        lda #<s_stb
        ldy #>s_stb
pw      jmp oi
p1      cmp #0
        bne p2
        jsr aeq                 ; adresse fixe
        jsr k_lexpr
        jmp st
p2      jsr aeq                 ; décalage dans Y
        lda #1
        sta kfvm
        jsr kf_look
        sta kq2
        bne p3
        jsr kf_pha              ; valeur calculée : décalage gardé
        ldx ex
        jsr k_lexpr
        lda #<s_pla
        ldy #>s_pla
        jsr oi
        lda #<s_tay
        ldy #>s_tay
        jsr oi
        jmp sy
p3      jsr kf_toy              ; nombre ou variable : Y n'est pas touché
        lda kq2
        cmp #1
        bne p4
        lda kfe
        cmp #2
        bne p4
        ldx ex                  ; entier <- variable : copie directe
        jsr getvar
        jsr endline
        jmp kf_cpv
p4      ldx ex
        jsr k_lexpr
sy      lda #0
        sta kfo
        sta kfo+1
        lda #1
        sta kyx
st      lda kfe
        cmp #2
        bne sb
        jsr kf_dst
        jsr o_st16
        jmp z
sb      jsr kf_stb
        jsr kf_dst
        lda #<s_sta
        ldy #>s_sta
        jsr o_ins_sym
z       lda #0
        sta kyx
        sta kc
        rts
.)

; kf_cpv : variable vix, vc -> élément (Y)
kf_cpv
.(
        lda #0
        sta kfo
        sta kfo+1
        sta kt
l       lda vix
        ldx vc
        jsr dest_var
        lda kt
        sta koff
        lda #<s_lda
        ldy #>s_lda
        jsr o_ins_sym
        jsr kf_dst
        lda kt
        sta koff
        lda #1
        sta kyx
        lda #<s_sta
        ldy #>s_sta
        jsr o_ins_sym
        lda #0
        sta kyx
        inc kt
        lda kt
        cmp #2
        bne l
        lda #0
        sta kc
        rts
.)

; kf_hcom : C=0 si l'élément en ex (« ( ») a deux indices
kf_hcom
.(
        ldy ex
        ldx #0
l       lda lbuf,y
        beq no
        cmp #"("
        bne c1
        inx
        bne nx
c1      cmp #")"
        bne c2
        dex
        beq no
        bne nx
c2      cmp #","
        bne nx
        cpx #1
        beq yes
nx      iny
        bne l
no      sec
        rts
yes     clc
        rts
.)

; ---------------------------------------------------------------------
; Bibliothèques : seules les routines utiles sont recopiées dans NOM.ASM
; ---------------------------------------------------------------------
; Les copies de la disquette (GRX.INC... HIRES.INC) sont marquées par
;   tools/mark_inc.py : « ;@#NNN » (numéro de la routine qui précède la
;   première du fichier), « ;@DDDEEE » (une routine commence, son étiquette
;   suit ; elle a besoin des routines DDD, EEE ; « ;@* » : toujours gardée),
;   « ;@+DDD » (suite), « ;@=NNN » (lignes de la routine NNN ; 000 :
;   toujours). Pendant la traduction, oc relève les noms écrits (kcapt) ;
;   à la fin, kl_libs lit les marques (routines appelées par leur nom ou
;   par une constante qui le vaut), complète par les besoins (kl_clos),
;   puis recopie les lignes des routines gardées.
kp      = $5E           ; pointeurs de travail (2 octets chacun)
kp2     = $60

; kcapt : (oc) A = caractère écrit ; garde les noms qui commencent par une
;   minuscule et contiennent « _ » (ktok -> liste kroot). A gardé
kcapt
.(
        sta kca
        cmp #"_"
        beq id
        cmp #"0"
        bcc fin
        cmp #"9"+1
        bcc id
        cmp #"A"
        bcc fin
        cmp #"Z"+1
        bcs lo
        inc kbad                ; majuscule : pas un nom de bibliothèque
        bne id
lo      cmp #"a"
        bcc fin
        cmp #"z"+1
        bcs fin
id      ldx ktl
        cpx #15
        bcc id1
        inc kbad                ; trop long
        bne r
id1     sta ktok,x
        inc ktl
        bne r
fin     lda ktl
        beq r
        tax
        lda #0
        sta ktok,x
        lda kbad
        bne z
        lda ktok
        cmp #"a"
        bcc z
z0      lda ktok,x              ; un « _ » ?
        cmp #"_"
        beq ok
        dex
        bpl z0
        bmi z
ok      jsr kr_find
        bcc z
        jsr kr_add
z       lda #0
        sta ktl
        sta kbad
r       lda kca
        rts
.)

; kr_find : ktok dans la liste kroot ? C=0 : oui ; sinon C=1, kp sur la fin
kr_find
.(
        lda #<kroot
        sta kp
        lda #>kroot
        sta kp+1
l       ldy #0
        lda (kp),y
        beq no
c       lda (kp),y
        cmp ktok,y
        bne d
        cmp #0
        beq yes
        iny
        bne c
d       lda (kp),y              ; nom suivant
        beq n
        iny
        bne d
n       iny
        tya
        clc
        adc kp
        sta kp
        bcc l
        inc kp+1
        bcs l
yes     clc
        rts
no      sec
        rts
.)

; kr_add : ajoute ktok (kp : fin de la liste)
kr_add
.(
        lda kp                  ; place : 18 octets au moins
        cmp #<(kroot+KROOT-18)
        lda kp+1
        sbc #>(kroot+KROOT-18)
        bcs full
        ldy #$FF
l       iny
        lda ktok,y
        sta (kp),y
        bne l
        iny
        sta (kp),y              ; nouvelle fin
        rts
full    lda #<m_names
        ldy #>m_names
        jmp stop_msg
.)

; kl_libs : bibliothèques de NOM.ASM, routines utiles seulement
kl_libs
.(
        lda #0
        sta kcap
        lda #<KMK               ; aucune routine gardée, sauf 000
        sta kp
        lda #>KMK
        sta kp+1
        ldx #>KMAXR
        ldy #0
        tya
z       sta (kp),y
        iny
        bne z
        inc kp+1
        dex
        bne z
        lda #1
        sta KMK
        lda #<KEDG
        sta kep
        lda #>KEDG
        sta kep+1
        lda #0                  ; lecture des marques
        jsr kl_run
        jsr kl_clos
        lda #1                  ; recopie
.)
; kl_run : A = 0 : lit les marques ; 1 : recopie ; chaque bibliothèque utile
kl_run
.(
        sta kpass
        lda #0
        sta kli
l       ldy kli
        ldx klfl,y              ; drapeau (0 : toujours)
        beq go
        lda 0,x
        beq nx
go      jsr kl_file
nx      inc kli
        lda kli
        cmp #6
        bne l
        rts
.)

; kl_find : ouvre la bibliothèque ifcb sur le lecteur du .GRX, sinon sur
;   un lecteur déjà lu (fonction 24) de A: à D: (la disquette système).
;   C=0 : ouverte
kl_find
.(
        lda sfcb
        sta ifcb
        jsr kl_open
        bne y
        ldx #F_LOGIN
        jsr BDOS
        sta kdv
        lda #1
        sta ifcb
l       lsr kdv
        bcc n
        jsr kl_open
        bne y
n       inc ifcb
        lda ifcb
        cmp #5
        bcc l
        rts                     ; (C=1)
y       clc
        rts
.)
; kl_open : ouvre ifcb (octets 12-35 à 0) ; Z=1 si absent
kl_open
.(
        lda #0
        ldy #12
c       sta ifcb,y
        iny
        cpy #36
        bne c
        ldx #F_OPEN
        lda #<ifcb
        ldy #>ifcb
        jsr BDOS
        cmp #$FF
        rts
.)
kdv     .byt 0                  ; lecteurs lus (fonction 24), décalés

; kl_file : la bibliothèque kli
kl_file
.(
        ldx #0                  ; FCB : lecteur du .GRX, nom de la table
        ldy kli
        beq n0
n9      txa
        clc
        adc #11
        tax
        dey
        bne n9
n0
        ldy #0
n       lda klnm,x
        sta ifcb+1,y
        inx
        iny
        cpy #11
        bne n
        jsr kl_find
        bcc ok
        jsr to_text             ; absente : « GRX.INC absente »
        ldx #1
p       lda ifcb,x
        cmp #" "
        beq p1
        stx kli
        jsr putc
        ldx kli
p1      inx
        cpx #9
        bne p2
        lda #"."
        stx kli
        jsr putc
        ldx kli
p2      cpx #12
        bne p
        lda #<m_noinc
        ldy #>m_noinc
        jmp stop_msg
ok      lda #128
        sta ipos
        lda #0
        sta ieof
        sta cnt
        sta cnt+1
        sta cur
        sta cur+1
        sta kname
line    jsr kl_getl
        bcc ln
        rts
ln      lda lbuf
        cmp #";"
        bne norm
        lda lbuf+1
        cmp #"@"
        bne norm
        ldx #3
        lda lbuf+2
        cmp #"#"
        bne m1
        jsr khex3               ; ;@#NNN
        lda gv
        sta cnt
        lda gv+1
        sta cnt+1
        jmp line
m1      cmp #"="
        bne m2
        jsr khex3               ; ;@=NNN
        lda gv
        sta cur
        lda gv+1
        sta cur+1
        jmp line
m2      cmp #"+"
        beq dep
        inc cnt                 ; ;@DDD... : une routine commence
        bne m3
        inc cnt+1
m3      lda cnt
        sta cur
        lda cnt+1
        sta cur+1
        lda #1
        sta kname
        dex
        lda lbuf+2
        cmp #"*"
        bne dep
        jsr kmark               ; toujours gardée
        ldx #3
dep     lda kpass
        bne dl
dl0     lda lbuf,x              ; besoins : une arête cur -> DDD chacun
        beq dl
        jsr khex3
        jsr kedge
        jmp dl0
dl      jmp line
norm    lda kpass
        beq names
        jsr kmk_cur             ; recopie si la routine est gardée
        beq nl
        lda #<lbuf
        ldy #>lbuf
        jsr os
        jsr ocrlf
nl      jmp line
names   lda kname               ; l'étiquette de la routine, ou une
        bne nm                  ;   constante qui la vaut
        lda cur
        ora cur+1
        beq nl
nm      ldx #0                  ; nom en colonne 0 -> ktok
nm1     lda lbuf,x
        jsr kl_idc
        bcs nm2
        sta ktok,x
        inx
        cpx #15
        bne nm1
nm2     lda #0
        sta ktok,x
        lda kname
        bne nm4
nm3     lda lbuf,x              ; constante : « nom = »
        inx
        cmp #" "
        beq nm3
        cmp #"="
        bne nm5
nm4     jsr kr_find
        bcs nm5
        jsr kmark
nm5     lda #0
        sta kname
        jmp line
.)

; kl_idc : C=0 si A peut faire partie d'un nom
kl_idc
.(
        cmp #"_"
        beq y
        cmp #"0"
        bcc n
        cmp #"9"+1
        bcc y
        jsr isalpha
        bcs n
        lda lbuf,x              ; (isalpha met en majuscule)
y       clc
        rts
n       sec
        rts
.)

; khex3 : 3 chiffres hexadécimaux en lbuf,x -> gv ; X après eux
khex3
.(
        lda #0
        sta gv
        sta gv+1
        ldy #3
l       lda lbuf,x
        inx
        sec
        sbc #"0"
        cmp #10
        bcc d
        sbc #7
d       pha
        asl gv
        rol gv+1
        asl gv
        rol gv+1
        asl gv
        rol gv+1
        asl gv
        rol gv+1
        pla
        ora gv
        sta gv
        dey
        bne l
        rts
.)

; kedge : arête cur -> gv (4 octets en kep)
kedge
.(
        lda kep
        sta kp
        lda kep+1
        sta kp+1
        cmp #>(PTOP-4)
        bcs full
        ldy #0
        lda cur
        sta (kp),y
        iny
        lda cur+1
        sta (kp),y
        iny
        lda gv
        sta (kp),y
        iny
        lda gv+1
        sta (kp),y
        clc
        lda kep
        adc #4
        sta kep
        bcc r
        inc kep+1
r       rts
full    lda #<m_names
        ldy #>m_names
        jmp stop_msg
.)

; kmk_cur : A = marque de la routine cur (Z=1 : pas gardée) ; kmark : la
;   marque
kmk_cur jsr kmk_p
        lda (kp2),y
        rts
kmark   jsr kmk_p
        lda #1
        sta (kp2),y
        rts
kmk_p   clc                     ; kp2 = KMK + cur, Y = 0
        lda cur
        adc #<KMK
        sta kp2
        lda cur+1
        adc #>KMK
        sta kp2+1
        ldy #0
        rts

; kl_clos : une routine gardée garde celles dont elle a besoin (arêtes
;   parcourues jusqu'à ce que rien ne change)
kl_clos
.(
again   lda #0
        sta kch
        lda #<KEDG
        sta kp
        lda #>KEDG
        sta kp+1
l       lda kp
        cmp kep
        lda kp+1
        sbc kep+1
        bcs end
        ldy #0
        lda (kp),y
        sta cur
        iny
        lda (kp),y
        sta cur+1
        jsr kmk_cur
        beq nx
        ldy #2
        lda (kp),y
        sta cur
        iny
        lda (kp),y
        sta cur+1
        jsr kmk_cur
        bne nx
        jsr kmark
        sta kch
nx      clc
        lda kp
        adc #4
        sta kp
        bcc l
        inc kp+1
        bcs l
end     lda kch
        bne again
        rts
.)

; kl_getl : ligne suivante de la bibliothèque -> lbuf ; C=1 à la fin
kl_getl
.(
        ldx #0
l       jsr kl_getc
        bcs eof
        cmp #10
        beq end
        cmp #13
        beq l
        cpx #LMAX
        bcs l
        sta lbuf,x
        inx
        bne l
eof     cpx #0
        bne end
        sec
        rts
end     lda #0
        sta lbuf,x
        clc
        rts
.)
kl_getc
.(
        lda ieof
        bne e
        ldy ipos
        cpy #128
        bne g
        stx kcx                 ; enregistrement suivant
        ldx #F_SETDMA
        lda #<ibuf
        ldy #>ibuf
        jsr BDOS
        ldx #F_READ
        lda #<ifcb
        ldy #>ifcb
        jsr BDOS
        ldx kcx
        cmp #0
        bne e1
        ldy #0
g       lda ibuf,y
        iny
        sty ipos
        cmp #$1A
        beq e1
        clc
        rts
e1      lda #1
        sta ieof
e       sec
        rts
.)

; bibliothèques, dans l'ordre de NOM.ASM (HIRES.INC à la fin : ses
;   tables suivent h_end) ; drapeau en page zéro (0 : toujours)
klnm    .asc "GRX     INC"
        .asc "ARR     INC"
        .asc "FIL     INC"
        .asc "SPR     INC"
        .asc "ANIM    INC"
        .asc "HIRES   INC"
klfl    .byt 0,karr,kfil,kspr,kanim,0
#include "grxasm.msg"          ; messages, en-tête du .ASM (progs/msg/fr, en)
#include "grxc.msg"            ; messages de grxc_inc.s

; affectations ; ANIM ; console
x_asg   = k_assign
x_aasg  = k_aassign
an_val  jsr k_byte              ; ANIM nom n : constante ou calcul
        jmp endline
an_none lda #<s_lda0            ; ANIM nom : 0 (jusqu'à une touche)
        ldy #>s_lda0
        jmp oi
to_text rts                     ; (la console reste en mode texte)

t_casm  .asc "ASM "
t_ce    .asc " /E",0
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
        .word k_paste    ; PASTE
        .word k_grab     ; GRAB
        .word k_scrolh   ; SCROLH
        .word k_scrolv   ; SCROLV
        .word k_roth     ; ROTH
        .word k_rotv     ; ROTV
        .word k_printv   ; PRINTV
        .word k_echov    ; ECHOV
        .word k_spcv     ; SPCV
        .word k_tileset  ; TILESET
        .word k_tmap     ; TMAP
        .word k_tfont    ; TFONT

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
kf_al   = kvu+KVU       ; tableaux fixes (52 cases : entiers, puis $) :
kf_ah   = kf_al+52      ;   adresse (octet haut 0 : pas fixe)
kf_1l   = kf_ah+52      ;   taille 1
kf_1h   = kf_1l+52
kf_2l   = kf_1h+52      ;   taille 2 (0 : une dimension)
kf_2h   = kf_2l+52
kf_sm   = kf_2h+52      ;   1 : petit (256 octets au plus)
kf_rt   = kf_sm+52      ;   1 : table des lignes utilisée
kftop   = kf_rt+52      ; haut de leur place, comme r_top (2 octets)
kt      = kftop+2       ; travail (2 octets)
km_a    = kt+2          ; kmul (2 octets chacun)
km_b    = km_a+2
km_p    = km_b+2
kf_s1   = km_p+2        ; DIM : tailles (2 octets chacune)
kf_s2   = kf_s1+2
kfc     = kf_s2+2       ;   1 : taille 1 constante
kfrs    = kfc+1         ; kf_rows : octets par ligne
kfv0    = kfrs+1        ;   valeur
ksn     = kfv0+1        ; k_simple : début du nom
ksy     = ksn+1
kfa     = ksy+1         ; kf_get : lettre, sorte
kfk     = kfa+1
kfvm    = kfk+1         ; kf_look : 0 indice, 1 valeur
kfst    = kfvm+1        ; état d'un accès, gardé par kf_get :
kfy     = kfst          ;   case du tableau
kfe     = kfy+1         ;   octets par élément
kfsm    = kfe+1         ;   petit tableau ?
kfm     = kfsm+1        ;   kf_ix : mode
kfn     = kfm+1         ;   dimensions (descripteur)
kfr     = kfn+1         ;   ligne : 1 dans A, 2 sur la pile
kfo     = kfr+1         ;   décalage constant (2 octets)
kyx     = kfo+2         ;   1 : « ,y » après le nom
kq      = kyx+1         ;   opérande de kf_op : 0 g_ev, 1 variable
kqx     = kq+1          ;     (vix, vc)
kqc     = kqx+1
kw1     = kqc+1         ;   kf_one : indice 0 ou 1
kcl     = kw1+1         ;   indices : nature (2 octets)
kix     = kcl+2         ;     variable (2 + 2 octets)
kic     = kix+2
kil     = kic+2         ;     constante (2 + 2 octets)
kih     = kil+2
kfr1    = kih+2         ;   début constant de la ligne
kq2     = kfr1+1        ;   kf_look
KFN     = kq2+1-kfst
kcap    = kq2+1         ; 1 : oc relève les noms (kcapt)
kca     = kcap+1
kcx     = kca+1
ktl     = kcx+1         ; nom en cours : longueur
kbad    = ktl+1         ;   <> 0 : pas un nom de bibliothèque
ktok    = kbad+1        ;   16 octets
kpass   = ktok+16       ; kl_run : 0 marques, 1 recopie
kli     = kpass+1       ; bibliothèque en cours
kname   = kli+1         ; 1 : la ligne porte l'étiquette d'une routine
kch     = kname+1       ; kl_clos : une marque ajoutée
ipos    = kch+1         ; lecture d'une bibliothèque : position dans ibuf
ieof    = ipos+1
cnt     = ieof+1        ; numéro de la dernière routine lue (2 octets)
kep     = cnt+2         ; fin des arêtes (2 octets)
kpp     = kep+2         ; PRINT : appel en attente (2 octets ; octet haut 0 :
kpi     = kpp+2         ;   aucun), nombre d'éléments
ibuf    = kpi+1         ; 128 octets
kroot   = ibuf+128      ; noms relevés (terminés par 0 ; 0 à la fin)
KROOT   = 768
obuf    = kroot+KROOT   ; NOM.ASM : enregistrement en cours
rawbuf  = obuf+128      ; ligne lue
lbuf    = rawbuf+LMAX+1 ;   puis $1-$9 remplacés
ptext   = lbuf+LMAX+1   ; texte du fichier, jusqu'à PTOP
KMK     = ptext         ; fin de la traduction : marques des routines
KMAXR   = 1024          ;   (une par numéro)
KEDG    = KMK+KMAXR     ;   puis les arêtes (4 octets : de, vers)
