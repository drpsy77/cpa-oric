; =====================================================================
;  fp_inc.s — nombres décimaux « à la Oric » (virgule flottante, 5 octets)
;
;  À inclure dans un programme (#include "fp_inc.s") après avoir défini :
;    FP_ZP        début de 48 octets libres en page zéro
;    putc         affiche le caractère A (A, X, Y conservés)
;    fp_err_big   appelé (JMP) si un résultat est trop grand
;    fp_err_div   appelé (JMP) pour une division par zéro
;
;  Format rangé (5 octets, comme le BASIC de l'Oric) : e, m0, m1, m2, m3.
;    e = 0 : zéro. Sinon la valeur est (-1)^s * 0.1mmm...(binaire) * 2^(e-128),
;    s = bit 7 de m0 ; à sa place, le premier bit de la mantisse vaut
;    toujours 1 (bit implicite). Mantisse de 32 bits : 9 chiffres environ,
;    de 1E-38 à 1E38 environ.
;  Calculs sur deux accumulateurs dépliés, FAC et ARG : exposant, mantisse
;  de 5 octets (4 + un octet de garde pour l'arrondi), signe (bit 7).
;
;  Routines (le résultat est dans FAC) :
;    fp_ldfac   FAC = nombre rangé en (fpt)      fp_stfac  (fpt) = FAC
;    fp_itof    FAC = entier signé A (bas) Y (haut)
;    fp_u32tof  FAC = entier sans signe de 32 bits ft..ft+3 (octet bas en ft)
;    fp_toint   A (bas) Y (haut) = FAC arrondi ; C=1 s'il ne tient pas
;    fp_add  fp_sub  fp_mul  fp_div      FAC = ARG op FAC
;    fp_cmp     A = $FF si ARG < FAC, 0 si égaux, 1 si ARG > FAC
;    fp_trunc   partie entière (vers zéro)   fp_rnd  arrondi au plus proche
;    fp_tofac / fp_toarg / fp_swap / fp_zero / fp_neg
;    fp_scale10 FAC = FAC * 10^A (A signé)
;    fp_parse   lit un nombre décimal en (fpt) ; Y = caractères lus
;    fp_print   affiche FAC (9 chiffres significatifs au plus)
; =====================================================================

fe      = FP_ZP         ; FAC : exposant
fm      = FP_ZP+1       ;   mantisse (5 octets, fm = poids fort)
fsg     = FP_ZP+6       ;   signe (bit 7)
ae      = FP_ZP+7       ; ARG : exposant
am      = FP_ZP+8       ;   mantisse (5 octets)
asg     = FP_ZP+13      ;   signe
ft      = FP_ZP+14      ; 8 octets de travail
fx      = FP_ZP+22      ; exposant sur 16 bits
fcnt    = FP_ZP+24
fdx     = FP_ZP+25      ; exposant décimal
fnd     = FP_ZP+26      ; nombre de chiffres
fpt     = FP_ZP+27      ; pointeur (2 octets)
fq      = FP_ZP+29      ; quotient (5 octets)
fr      = FP_ZP+34      ; reste (4 octets)
fdig    = FP_ZP+38      ; chiffres à afficher (9 octets)
fde     = FP_ZP+47      ; exposant décimal de l'affichage

; ---------------------------------------------------------------------
; Chargement, rangement, copies
; ---------------------------------------------------------------------
; fp_ldfac : FAC = nombre rangé en (fpt)
fp_ldfac
.(
        ldy #0
        lda (fpt),y
        sta fe
        beq z
        iny
        lda (fpt),y
        sta fsg
        ora #$80
        sta fm
        iny
        lda (fpt),y
        sta fm+1
        iny
        lda (fpt),y
        sta fm+2
        iny
        lda (fpt),y
        sta fm+3
        lda #0
        sta fm+4
        rts
z       jmp fp_zero
.)

; fp_stfac : (fpt) = FAC, arrondi par l'octet de garde
fp_stfac
.(
        lda fm+4                ; arrondi
        bpl rd
        ldx #3
inc1    inc fm,x
        bne rd
        dex
        bpl inc1
        lda #$80                ; la mantisse a débordé : 1.0
        sta fm
        inc fe
        bne rd
        jmp fp_err_big
rd      lda #0
        sta fm+4
        ldy #0
        lda fe
        sta (fpt),y
        beq z
        iny
        lda fm
        and #$7F
        sta fcnt
        lda fsg
        and #$80
        ora fcnt
        sta (fpt),y
        iny
        lda fm+1
        sta (fpt),y
        iny
        lda fm+2
        sta (fpt),y
        iny
        lda fm+3
        sta (fpt),y
        rts
z       ldy #4                  ; zéro : 5 octets nuls
        lda #0
zl      sta (fpt),y
        dey
        bpl zl
        rts
.)

; fp_zero : FAC = 0
fp_zero
.(
        lda #0
        ldx #6
l       sta fe,x
        dex
        bpl l
        rts
.)

; fp_toarg : ARG = FAC
fp_toarg
.(
        ldx #6
l       lda fe,x
        sta ae,x
        dex
        bpl l
        rts
.)

; fp_tofac : FAC = ARG
fp_tofac
.(
        ldx #6
l       lda ae,x
        sta fe,x
        dex
        bpl l
        rts
.)

; fp_swap : échange FAC et ARG
fp_swap
.(
        ldx #6
l       lda fe,x
        ldy ae,x
        sta ae,x
        tya
        sta fe,x
        dex
        bpl l
        rts
.)

fp_neg
        lda fsg
        eor #$80
        sta fsg
        rts

; fp_norm : normalise FAC (bit 7 de fm à 1) ; zéro si la mantisse est nulle
;   ou si l'exposant devient trop petit
fp_norm
.(
        ldx #5
byte    lda fm
        bne bits
        lda fe                  ; décale d'un octet
        sec
        sbc #8
        bcc z
        beq z
        sta fe
        lda fm+1
        sta fm
        lda fm+2
        sta fm+1
        lda fm+3
        sta fm+2
        lda fm+4
        sta fm+3
        lda #0
        sta fm+4
        dex
        bne byte
z       jmp fp_zero
bits    lda fm
        bmi done
        asl fm+4
        rol fm+3
        rol fm+2
        rol fm+1
        rol fm
        dec fe
        bne bits
        jmp fp_zero
done    rts
.)

; ---------------------------------------------------------------------
; Conversions avec les entiers
; ---------------------------------------------------------------------
; fp_itof : FAC = entier signé A (bas), Y (haut)
fp_itof
.(
        sty fsg
        cpy #$80
        bcc pos
        eor #$FF                ; valeur absolue
        clc
        adc #1
        tax
        tya
        eor #$FF
        adc #0
        tay
        txa
pos     sty fm
        sta fm+1
        lda #0
        sta fm+2
        sta fm+3
        sta fm+4
        lda #128+16
        sta fe
        jmp fp_norm
.)

; fp_u32tof : FAC = ft..ft+3 (sans signe, octet bas en ft)
fp_u32tof
        lda #0
        sta fsg
        sta fm+4
        lda ft+3
        sta fm
        lda ft+2
        sta fm+1
        lda ft+1
        sta fm+2
        lda ft
        sta fm+3
        lda #128+32
        sta fe
        jmp fp_norm

; fp_tou32 : mantisse de FAC = sa partie entière (FAC entier, 1 à 32 bits ;
;   résultat dans fm..fm+3, poids fort en fm)
fp_tou32
.(
        lda #128+32
        sec
        sbc fe
        tax
        beq r
s       lsr fm
        ror fm+1
        ror fm+2
        ror fm+3
        dex
        bne s
r       rts
.)

; fp_toint : A (bas), Y (haut) = FAC arrondi au plus proche ; C=1 s'il ne
;   tient pas sur 16 bits signés
fp_toint
.(
        jsr fp_rnd
        lda fe
        beq zero
        cmp #128+16
        bcs big
        jsr fp_tou32            ; valeur dans fm+2 (haut), fm+3 (bas)
        lda fsg
        bpl pos
        sec
        lda #0
        sbc fm+3
        tax
        lda #0
        sbc fm+2
        tay
        txa
        clc
        rts
pos     lda fm+3
        ldy fm+2
        clc
        rts
zero    tay
        clc
        rts
big     bne no                  ; -32768 tient encore
        lda fsg
        bpl no
        lda fm
        cmp #$80
        bne no
        lda fm+1
        ora fm+2
        ora fm+3
        bne no
        ldy #$80
        clc
        rts
no      sec
        rts
.)

; fp_trunc : FAC = partie entière de FAC (vers zéro)
fp_trunc
.(
        lda fe
        cmp #129
        bcs t1
        jmp fp_zero             ; |x| < 1
t1      cmp #128+40
        bcs r                   ; déjà entier
        sec
        sbc #128                ; n = nombre de bits entiers (1 à 39)
        pha
        lsr
        lsr
        lsr
        tay                     ; octet où passe la virgule
        pla
        and #7
        tax
        lda fp_mask,x
        and fm,y
        sta fm,y
        lda #0
c       iny
        cpy #5
        bcs r
        sta fm,y
        bcc c
r       rts
.)
fp_mask .byt $00,$80,$C0,$E0,$F0,$F8,$FC,$FE

; fp_rnd : FAC = FAC arrondi au plus proche entier (0,5 s'éloigne de zéro)
fp_rnd
        lda fe
        beq fr_r
        lda #128                ; ARG = 0,5 avec le signe de FAC
        sta ae
        lda #$80
        sta am
        lda #0
        sta am+1
        sta am+2
        sta am+3
        sta am+4
        lda fsg
        sta asg
        jsr fp_add
        jmp fp_trunc
fr_r    rts

; ---------------------------------------------------------------------
; Opérations : FAC = ARG op FAC
; ---------------------------------------------------------------------
fp_sub
        jsr fp_neg
fp_add
.(
        lda ae
        beq r                   ; ARG nul : FAC
        lda fe
        bne n1
        jmp fp_tofac            ; FAC nul : ARG
n1      cmp ae                  ; FAC doit avoir le plus grand exposant
        bcs n2
        jsr fp_swap
n2      lda fe
        sec
        sbc ae
        cmp #41
        bcs r                   ; ARG négligeable
        tax
sb      cpx #8                  ; aligne ARG : octets, puis bits
        bcc sbits
        lda am+3
        sta am+4
        lda am+2
        sta am+3
        lda am+1
        sta am+2
        lda am
        sta am+1
        lda #0
        sta am
        txa
        sec
        sbc #8
        tax
        jmp sb
sbits   dex
        bmi al
        lsr am
        ror am+1
        ror am+2
        ror am+3
        ror am+4
        jmp sbits
al      lda fsg
        eor asg
        bmi subm
        clc                     ; mêmes signes : addition
        ldx #4
la      lda fm,x
        adc am,x
        sta fm,x
        dex
        bpl la
        bcc r
        ror fm                  ; retenue : on décale
        ror fm+1
        ror fm+2
        ror fm+3
        ror fm+4
        inc fe
        bne r
        jmp fp_err_big
r       rts
subm    sec                     ; signes contraires : soustraction
        ldx #4
ls      lda fm,x
        sbc am,x
        sta fm,x
        dex
        bpl ls
        bcs nrm
        sec                     ; résultat négatif : on l'inverse
        ldx #4
lg      lda #0
        sbc fm,x
        sta fm,x
        dex
        bpl lg
        jsr fp_neg
nrm     jmp fp_norm
.)

; fp_expo : fx (16 bits signés) -> fe ; zéro si trop petit, erreur si trop
;   grand ; puis normalise
fp_expo
.(
        lda fx+1
        bmi z
        bne big
        lda fx
        beq z
        sta fe
        jmp fp_norm
z       jmp fp_zero
big     jmp fp_err_big
.)

fp_mul
.(
        lda fe
        beq r                   ; 0 * x
        lda ae
        bne go
        jmp fp_zero
go      lda fsg
        eor asg
        sta fsg
        clc                     ; exposant : fe + ae - 128
        lda fe
        adc ae
        sta fx
        lda #0
        adc #0
        sta fx+1
        sec
        lda fx
        sbc #128
        sta fx
        lda fx+1
        sbc #0
        sta fx+1
        ldx #3                  ; multiplicande en ft, produit fm:ft+4..7
c       lda fm,x
        sta ft,x
        lda #0
        sta fm,x
        sta ft+4,x
        dex
        bpl c
        ldy #32
loop    lsr am                  ; bit suivant du multiplicateur
        ror am+1
        ror am+2
        ror am+3
        bcc no
        clc
        ldx #3
la      lda fm,x
        adc ft,x
        sta fm,x
        dex
        bpl la
no      ror fm
        ror fm+1
        ror fm+2
        ror fm+3
        ror ft+4
        ror ft+5
        ror ft+6
        ror ft+7
        dey
        bne loop
        lda ft+4
        sta fm+4
        jmp fp_expo
r       rts
.)

fp_div
.(
        lda fe
        bne ok
        jmp fp_err_div
ok      lda ae
        bne go
        jmp fp_zero
go      lda fsg
        eor asg
        sta fsg
        sec                     ; exposant : ae - fe + 129
        lda ae
        sbc fe
        sta fx
        lda #0
        sbc #0
        sta fx+1
        clc
        lda fx
        adc #129
        sta fx
        lda fx+1
        adc #0
        sta fx+1
        lda #0                  ; reste : ft+5 (haut) et am..am+3
        sta ft+5
        ldx #4
qz      sta fq,x
        dex
        bpl qz
        ldy #40
loop    sec                     ; reste - diviseur
        lda am+3
        sbc fm+3
        sta fr+3
        lda am+2
        sbc fm+2
        sta fr+2
        lda am+1
        sbc fm+1
        sta fr+1
        lda am
        sbc fm
        sta fr
        lda ft+5
        sbc #0
        bcc no
        sta ft+5                ; ça passe : on garde la différence
        lda fr
        sta am
        lda fr+1
        sta am+1
        lda fr+2
        sta am+2
        lda fr+3
        sta am+3
no      rol fq+4                ; C = bit du quotient
        rol fq+3
        rol fq+2
        rol fq+1
        rol fq
        asl am+3
        rol am+2
        rol am+1
        rol am
        rol ft+5
        dey
        bne loop
        ldx #4
cq      lda fq,x
        sta fm,x
        dex
        bpl cq
        jmp fp_expo
.)

; fp_cmp : A = $FF si ARG < FAC, 0 si égaux, 1 si ARG > FAC
fp_cmp
.(
        lda ae                  ; signe de ARG (zéro : positif)
        beq a0
        lda asg
        and #$80
a0      sta fcnt
        lda fe
        beq f0
        lda fsg
        and #$80
f0      cmp fcnt
        beq same
        lda fcnt                ; signes différents
        bmi lt
gt      lda #1
        rts
lt      lda #$FF
        rts
same    lda ae                  ; mêmes signes : grandeurs
        cmp fe
        bne diff
        ldx #0
l       lda am,x
        cmp fm,x
        bne diff
        inx
        cpx #4
        bne l
        lda #0
        rts
diff    ror                     ; C=1 : |ARG| > |FAC|
        eor fcnt                ; négatifs : on inverse
        bmi gt
        bpl lt
.)

; ---------------------------------------------------------------------
; Puissances de 10
; ---------------------------------------------------------------------
; fp_ldpow : FAC = 10^X (X = 1 à 9, exact)
fp_ldpow
        txa
        asl
        asl
        sta fcnt
        txa
        clc
        adc fcnt                ; X * 5
        adc #<fp_p10m
        sta fpt
        lda #>fp_p10m
        adc #0
        sta fpt+1
        jmp fp_ldfac

; fp_scale10 : FAC = FAC * 10^A (A signé), par tranches de 10^9 au plus
fp_scale10
.(
        sta fdx
loop    lda fe
        beq r
        lda fdx
        beq r
        bmi neg
        cmp #10
        bcc k1
        lda #9
k1      pha                     ; k
        eor #$FF                ; fdx -= k
        sec
        adc fdx
        sta fdx
        jsr fp_toarg
        pla
        tax
        jsr fp_ldpow
        jsr fp_mul
        jmp loop
neg     eor #$FF
        clc
        adc #1                  ; -fdx
        cmp #10
        bcc k2
        lda #9
k2      pha                     ; k
        clc
        adc fdx
        sta fdx
        jsr fp_toarg
        pla
        tax
        jsr fp_ldpow
        jsr fp_div
        jmp loop
r       rts
.)

fp_p10  .byt $84,$20,$00,$00,$00        ; 10
        .byt $87,$48,$00,$00,$00        ; 100
        .byt $8A,$7A,$00,$00,$00        ; 1000
        .byt $8E,$1C,$40,$00,$00        ; 1E4
        .byt $91,$43,$50,$00,$00        ; 1E5
        .byt $94,$74,$24,$00,$00        ; 1E6
        .byt $98,$18,$96,$80,$00        ; 1E7
        .byt $9B,$3E,$BC,$20,$00        ; 1E8
        .byt $9E,$6E,$6B,$28,$00        ; 1E9
fp_p10m = fp_p10-5              ; 10^X est en fp_p10m + 5 * X

; ---------------------------------------------------------------------
; Lecture d'un nombre décimal : chiffres [. chiffres] [E [+-] chiffres]
; ---------------------------------------------------------------------
; fp_parse : texte en (fpt) -> FAC ; Y = nombre de caractères lus
;   (9 ou 10 chiffres gardés, tant qu'ils tiennent sur 32 bits ; le premier
;   chiffre abandonné arrondit, les suivants ne comptent que pour l'exposant)
fp_parse
.(
        lda #0
        ldx #3
z       sta ft,x
        dex
        bpl z
        sta fnd                 ; 1 : un chiffre a déjà été abandonné
        sta fdx                 ; exposant décimal
        sta fcnt                ; bit 7 : après la virgule
        tay
dig     lda (fpt),y
        cmp #"."
        bne nd
        bit fcnt
        bpl fpnt
        jmp end                 ; deuxième point : fin
fpnt    lda #$80
        sta fcnt
        iny
        bne dig
nd      sec
        sbc #"0"
        cmp #10
        bcs notd
        tax                     ; X = chiffre
        iny
        lda ft                  ; N = 0 et chiffre 0 : zéro de tête
        ora ft+1
        ora ft+2
        ora ft+3
        bne sig
        txa
        bne sig
        bit fcnt                ; après la virgule, il décale
        bpl dig
        dec fdx
        jmp dig
sig     lda ft+3                ; N < $19999999 : N * 10 + chiffre tient
        cmp #$19
        bcc keep
        bne drop
        lda ft+2
        cmp #$99
        bcc keep
        bne drop
        lda ft+1
        cmp #$99
        bcc keep
        bne drop
        lda ft
        cmp #$99
        bcc keep
drop    lda fnd                 ; chiffre de trop : le premier arrondit N
        bne d1
        inc fnd
        cpx #5
        bcc d1
        inc ft
        bne d1
        inc ft+1
        bne d1
        inc ft+2
        bne d1
        inc ft+3
d1      bit fcnt                ; avant la virgule, il multiplie par 10
        bmi dg2
        inc fdx
dg2     jmp dig
keep    bit fcnt
        bpl k1
        dec fdx
k1      jsr fp_n10              ; N = N * 10 + chiffre
        txa
        clc
        adc ft
        sta ft
        bcc dg2
        inc ft+1
        bne dg2
        inc ft+2
        bne dg2
        inc ft+3
        jmp dig
notd    lda (fpt),y             ; exposant ?
        cmp #"E"
        bne end
        sty fq                  ; position du E (on y revient sinon)
        iny
        lda #0
        sta fq+1                ; signe
        sta fq+2                ; valeur
        lda (fpt),y
        cmp #"+"
        beq sgn
        cmp #"-"
        bne ed
        dec fq+1
sgn     iny
ed      lda (fpt),y             ; au moins un chiffre
        sec
        sbc #"0"
        cmp #10
        bcc el
        ldy fq                  ; pas d'exposant : le E n'en fait pas partie
        jmp end
el      lda (fpt),y
        sec
        sbc #"0"
        cmp #10
        bcs edone
        sta fcnt
        lda fq+2                ; valeur * 10 + chiffre (bornée à 99)
        cmp #10
        bcs e2
        asl
        sta fq+3
        asl
        asl
        adc fq+3
        adc fcnt
        sta fq+2
e2      iny
        bne el
edone   lda fq+2
        bit fq+1
        bpl ep
        eor #$FF
        clc
        adc #1
ep      clc
        adc fdx                 ; fdx est petit : pas de débordement
        sta fdx
end     tya                     ; longueur lue
        pha
        jsr fp_u32tof
        lda fdx
        jsr fp_scale10
        pla
        tay
        rts
.)

; fp_n10 : ft..ft+3 = ft..ft+3 * 10 (X préservé)
fp_n10
.(
        asl ft                  ; * 2
        rol ft+1
        rol ft+2
        rol ft+3
        lda ft                  ; garde N * 2
        sta fr
        lda ft+1
        sta fr+1
        lda ft+2
        sta fr+2
        lda ft+3
        sta fr+3
        asl ft                  ; * 8
        rol ft+1
        rol ft+2
        rol ft+3
        asl ft
        rol ft+1
        rol ft+2
        rol ft+3
        clc                     ; * 8 + * 2
        lda ft
        adc fr
        sta ft
        lda ft+1
        adc fr+1
        sta ft+1
        lda ft+2
        adc fr+2
        sta ft+2
        lda ft+3
        adc fr+3
        sta ft+3
        rts
.)

; ---------------------------------------------------------------------
; Affichage : 9 chiffres significatifs, sans les zéros de fin ; notation
; ordinaire de 0.00001 à 999999999, sinon 1.5E12, 2E-7
; ---------------------------------------------------------------------
fp_print
.(
        lda fe
        bne nz
        lda #"0"
        jmp putc
nz      lda fsg
        bpl p
        lda #"-"
        jsr putc
        lda #0
        sta fsg
p       lda fe                  ; estimation : d = (e - 129) * 0,30
        sec
        sbc #129
        php
        bcs ep
        eor #$FF
        adc #1                  ; C=0 ici : valeur absolue
ep      jsr fp_m77              ; A = |e - 129| * 77 / 256
        plp
        bcs dpp
        eor #$FF                ; négatif : - (A + 1)
dpp     sta fde                 ; d = exposant décimal du premier chiffre
        lda #8                  ; ramène FAC vers 1E8..1E9
        sec
        sbc fde
        jsr fp_scale10
adj     jsr fp_toarg            ; FAC >= 1E9 : / 10
        ldx #9
        jsr fp_ldpow
        jsr fp_cmp
        bmi lo
        jsr fp_tofac
        jsr fp_toarg
        ldx #1
        jsr fp_ldpow
        jsr fp_div
        inc fde
        jmp adj
lo      jsr fp_tofac
lo2     jsr fp_toarg            ; FAC < 1E8 : * 10
        ldx #8
        jsr fp_ldpow
        jsr fp_cmp
        bpl ok
        jsr fp_tofac
        jsr fp_toarg
        ldx #1
        jsr fp_ldpow
        jsr fp_mul              ; (ARG est perdu : on repart de FAC)
        dec fde
        jmp lo2
ok      jsr fp_tofac
        jsr fp_rnd              ; entier de 9 chiffres
        jsr fp_tou32
        ldx #0                  ; chiffres, de 1E8 à 1
dg      lda #0
        sta fdig,x
sub     sec
        lda fm+3
        sbc fp_d0,x
        sta fr+3
        lda fm+2
        sbc fp_d1,x
        sta fr+2
        lda fm+1
        sbc fp_d2,x
        sta fr+1
        lda fm
        sbc fp_d3,x
        bcc nxt
        sta fm
        lda fr+1
        sta fm+1
        lda fr+2
        sta fm+2
        lda fr+3
        sta fm+3
        inc fdig,x
        bne sub
nxt     inx
        cpx #9
        bne dg
        lda fdig                ; l'arrondi a donné 1E9 : 1 et des zéros
        cmp #10
        bcc sg
        lda #1
        sta fdig
        inc fde
sg      ldx #9                  ; s = nombre de chiffres significatifs
s1      dex
        lda fdig,x
        beq s1
        inx
        stx fnd
        lda fde                 ; notation : 0 <= d <= 8 ordinaire,
        bmi small               ; -5 <= d < 0 : 0.000ddd, sinon E
        cmp #9
        bcs expn
        ldx #0                  ; ordinaire : chiffres, virgule après d+1
o1      jsr pdig
        cpx fde
        beq o2
        inx
        bne o1
o2      inx
        cpx fnd
        bcs r
        lda #"."
        jsr putc
o3      jsr pdig
        inx
        cpx fnd
        bcc o3
r       rts
small   cmp #$FB                ; d >= -5 ?
        bcc expn
        lda #"0"
        jsr putc
        lda #"."
        jsr putc
        ldx fde
z1      inx                     ; -d-1 zéros
        beq z2
        lda #"0"
        jsr putc
        jmp z1
z2      jsr pdig                ; X = 0
        inx
        cpx fnd
        bcc z2
        rts
expn    ldx #0                  ; d.ddddE[-]nn
        jsr pdig
        lda fnd
        cmp #2
        bcc e1
        lda #"."
        jsr putc
        inx
e0      jsr pdig
        inx
        cpx fnd
        bcc e0
e1      lda #"E"
        jsr putc
        lda fde
        bpl e3
        lda #"-"
        jsr putc
        lda fde
        eor #$FF
        clc
        adc #1
e3      ldx #"0"-1              ; dizaines
e4      inx
        sec
        sbc #10
        bcs e4
        adc #10+"0"
        pha
        txa
        cmp #"0"
        beq e5
        jsr putc
e5      pla
        jmp putc
pdig    lda fdig,x              ; affiche le chiffre X
        ora #"0"
        jmp putc
.)

; fp_m77 : A = A * 77 / 256 (partie entière) ; 77 = 64 + 8 + 4 + 1
fp_m77
.(
        sta fr                  ; fr : A décalé, fr+2 : somme (16 bits)
        sta fr+2
        lda #0
        sta fr+1
        sta fr+3
        ldx #2                  ; * 4
        jsr sh
        ldx #1                  ; * 8
        jsr sh
        ldx #3                  ; * 64
        jsr sh
        lda fr+3
        rts
sh      asl fr
        rol fr+1
        dex
        bne sh
        clc
        lda fr+2
        adc fr
        sta fr+2
        lda fr+3
        adc fr+1
        sta fr+3
        rts
.)

; puissances de 10 sur 32 bits (1E8 à 1), octet par octet
fp_d0   .byt $00,$80,$40,$A0,$10,$E8,$64,$0A,$01
fp_d1   .byt $E1,$96,$42,$86,$27,$03,$00,$00,$00
fp_d2   .byt $F5,$98,$0F,$01,$00,$00,$00,$00,$00
fp_d3   .byt $05,$00,$00,$00,$00,$00,$00,$00,$00
