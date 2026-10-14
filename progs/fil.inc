; =====================================================================
;  fil.inc — fichiers de données de GRAPHER : SAVE et LOAD (tableau en
;  texte), BSAVE et BLOAD (tableau en binaire), BSAVE SCREEN et BLOAD
;  SCREEN (écran texte du LORES), FOUND. Commune à l'interpréteur
;  (GRAPHER.COM) et aux programmes traduits par GRXASM (qui ne
;  l'incluent que s'ils s'en servent). Incluse après arr.inc, dont elle
;  se sert (descripteurs, rz_count, rz_fillb, r_fail), et avant
;  hires.inc (h_lo).
;
;  À définir par le programme qui l'inclut :
;    f_fcb      FCB de 36 octets : lecteur et nom (8 + 3) déjà en place ;
;               le type manquant devient TXT, DAT ou SCR
;    f_fmt      r_j (signé) -> f_nbuf en décimal, 0 à la fin
;    f_mlo, f_mful  messages « LORES d'abord », « disque plein »
;    (et ce que demande arr.inc)
;
;    f_go       X = opération : 0 SAVE, 1 LOAD (texte), 2 BSAVE, 3 BLOAD
;               (A/Y = descripteur du tableau), 4 BSAVE SCREEN, 5 BLOAD
;               SCREEN (LORES seulement)
;    f_fnd      FOUND -> r_j : 1 si le dernier LOAD ou BLOAD a trouvé son
;               fichier, 0 sinon (le tableau ou l'écran n'a pas changé)
;
;  Texte (format de CP/M, comme EDIT) : une ligne du fichier par ligne
;  du tableau, CR LF à la fin de chaque ligne, ^Z pour compléter le
;  dernier enregistrement ; LOAD accepte CR LF, LF ou CR et s'arrête au
;  premier ^Z. Tableau $ : la ligne telle quelle jusqu'au premier 0
;  (codes 1-31 refusés par SAVE). Tableau d'entiers : nombres séparés
;  par des espaces (ou des tabulations). Une dimension : une seule
;  ligne. LOAD met d'abord le tableau à 0.
;  Binaire : octets tels quels (entiers : octet bas, octet haut), dernier
;  enregistrement complété par des 0 ; BLOAD lit la taille du tableau.
;  Enregistrements dans le tampon par défaut (DEF_DMA, $0480).
;  Page zéro : $D0-$DF.
; =====================================================================

f_p     = $D0           ; adresse dans le tableau (2 octets)
f_r     = $D2           ; lignes restantes (2 octets)
f_c     = $D4           ; éléments restants dans la ligne (2 octets)
f_es    = $D6           ; octets par élément (1 ou 2)
                        ;   (f_p à f_es : comme dans le descripteur)
f_n     = $D7           ; octets du tableau (2 octets)
f_ln    = $D9           ; ligne du fichier (2 octets)
f_i     = $DD           ; position dans l'enregistrement (128 : à lire)
f_ug    = $DE           ; caractère remis (0 : aucun ; ^Z : fin)
f_op    = $DF           ; opération (0-5)

f_go
.(
        stx f_op
        cpx #4
        bcc qar
        lda h_lo                ; écran texte : LORES seulement
        bne qsc
        lda #<f_mlo
        ldy #>f_mlo
        jmp r_fail
qsc      lda #<$BB80
        sta f_p
        lda #>$BB80
        sta f_p+1
        lda #<1120
        sta f_n
        lda #>1120
        sta f_n+1
        bne qgo
qar      jsr rz_desc
        jsr f_dims
qgo      lda f_op
        asl
        tax
        lda f_tab+1,x
        pha
        lda f_tab,x
        pha
        rts
.)
f_tab   .word f_tsave-1,f_tload-1,f_wblk-1,f_rblk-1,f_wblk-1,f_rblk-1

; f_fnd : FOUND -> r_j
f_fnd   lda f_found
        sta r_j
        lda #0
        sta r_j+1
        rts

; f_dims : descripteur r_dp -> f_p, f_es, f_n (octets), f_r (lignes),
;   rz_b (éléments par ligne)
f_dims
.(
        ldy #6                  ; adresse, taille 1, taille 2, octets
ql      lda (r_dp),y
        sta f_p,y
        dey
        bpl ql
        lda f_c                 ; une dimension : une ligne de taille 1
        ora f_c+1
        bne q2
        lda f_r
        sta f_c
        lda f_r+1
        sta f_c+1
        sty f_r+1               ; (Y = $FF)
        inc f_r+1
        lda #1
        sta f_r
q2      ldx #3                  ; éléments = lignes * éléments par ligne
q3      lda f_r,x
        sta rz_a,x
        dex
        bpl q3
        jsr rz_mul
        lda rz_p
        sta f_n
        lda rz_p+1
        sta f_n+1
        lda f_es
        lsr
        bcs q4
        asl f_n                 ; entiers : deux octets
        rol f_n+1
q4      lda f_c
        sta rz_b
        lda f_c+1
        sta rz_b+1
        rts
.)

; ---------------------------------------------------------------------
; Fichier : ouverture, enregistrements, caractères
; ---------------------------------------------------------------------
; f_fcbset : type par défaut, FCB à 0 après le nom, DMA -> A/Y = f_fcb
f_fcbset
.(
        lda f_op                ; 0-1 TXT, 2-3 DAT, 4-5 SCR
        and #6
        sta f_i
        lsr
        adc f_i                 ; (op / 2) * 3
        tax
        lda f_fcb+9
        cmp #" "
        bne qz
        ldy #0
qt       lda f_typ,x
        sta f_fcb+9,y
        inx
        iny
        cpy #3
        bne qt
qz       lda #0
        sta f_ug
        ldx #12
qzl      sta f_fcb,x
        inx
        cpx #36
        bne qzl
        ldx #F_SETDMA
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jsr BDOS
.)
f_ay    lda #<f_fcb
        ldy #>f_fcb
        rts

; f_ropen : ouverture en lecture -> C=1 et f_found = 1 si le fichier
;   existe ; C=0 et f_found = 0 sinon
f_ropen
.(
        jsr f_fcbset
        ldx #F_OPEN
        jsr BDOS
        ldx #0
        cmp #$FF
        beq qnf
        inx
qnf      stx f_found
        lda #128
        sta f_i
        cpx #1
        rts
.)

; f_wopen : fichier remplacé par un fichier vide (disque plein : erreur)
f_wopen
        jsr f_fcbset
        ldx #F_DELETE
        jsr BDOS
        jsr f_ay
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        beq f_full
        lda #0
        sta f_i
        rts
f_full  lda #<f_mful
        ldy #>f_mful
        jmp r_fail

; f_putc : A dans l'enregistrement, écrit quand il est plein (Y gardé)
f_putc
.(
        ldx f_i
        sta DEF_DMA,x
        inx
        stx f_i
        bpl qr
        tya
        pha
        jsr f_ay
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        bne f_full
        sta f_i
        pla
        tay
qr       rts
.)

; f_wclose : dernier enregistrement complété par A, puis fermeture
f_wclose
.(
        ldx f_i
        beq qc
        pha
        jsr f_putc
        pla
        jmp f_wclose
qc       jsr f_ay
        ldx #F_CLOSE
        jmp BDOS
.)

; f_getb : octet suivant -> A, C=0 ; C=1 à la fin du fichier
f_getb
.(
        ldx f_i
        bpl qget
        jsr f_ay
        ldx #F_READ
        jsr BDOS
        cmp #0
        sec
        bne qr
        tax
qget     lda DEF_DMA,x
        inx
        stx f_i
        clc
qr       rts
.)

; f_getc : caractère suivant (texte) ; ^Z à la fin, ensuite toujours
f_getc
.(
        lda f_ug
        beq qrd
        cmp #$1A
        beq qr
        ldx #0                  ; caractère remis
        stx f_ug
qr       rts
qrd      jsr f_getb
        bcs qeof
        cmp #$1A
        bne qr
qeof     lda #$1A
        sta f_ug
        rts
.)

; f_iseol : C=1 si A finit la ligne (CR, LF, ^Z) ; A gardé
f_iseol
.(
        cmp #13
        beq qy
        cmp #10
        beq qy
        cmp #$1A
        beq qy
        clc
        rts
qy       sec
        rts
.)

; ---------------------------------------------------------------------
; Binaire (tableau ou écran) : f_n octets à partir de f_p
; ---------------------------------------------------------------------
f_wblk
.(
        jsr f_wopen
ql       jsr f_left
        beq qe
        ldy #0
        lda (f_p),y
        jsr f_putc
        jsr f_next
        jmp ql
qe       lda #0
        jmp f_wclose
.)

f_rblk
.(
        jsr f_ropen
        bcc qr                   ; absent : rien ne change
        lda f_op
        cmp #5
        beq ql                   ; l'écran n'est pas effacé
        jsr f_zero
ql       jsr f_left
        beq qr
        jsr f_getb
        bcs qr                   ; fichier plus court : le reste à 0
        ldy #0
        sta (f_p),y
        jsr f_next
        jmp ql
qr       rts
.)

; f_left : Z=1 s'il ne reste rien (f_n = 0)
f_left  lda f_n
        ora f_n+1
        rts

; f_next : octet suivant (f_p + 1, f_n - 1)
f_next
.(
        inc f_p
        bne qn1
        inc f_p+1
qn1      lda f_n
        bne qn2
        dec f_n+1
qn2      dec f_n
        rts
.)

; f_zero : tout le tableau à 0
f_zero  lda f_p
        sta r_sa
        lda f_p+1
        sta r_sa+1
        lda f_n
        sta rz_p
        lda f_n+1
        sta rz_p+1
        lda #0
        sta rz_v
        sta rz_v+1
        jmp rz_fillb

; ---------------------------------------------------------------------
; Texte
; ---------------------------------------------------------------------
; f_row : Z=1 s'il ne reste plus de ligne ; sinon f_c = éléments d'une
;   ligne, rz_flt = 0
f_row
.(
        lda f_r
        ora f_r+1
        beq qr
        lda rz_b
        sta f_c
        lda rz_b+1
        sta f_c+1
        lda #0
        sta rz_flt
        lda #1                  ; Z=0
qr       rts
.)

; f_lend : ligne suivante du tableau (f_r - 1)
f_lend
.(
        lda f_r
        bne qn
        dec f_r+1
qn       dec f_r
        rts
.)

; f_elt : élément suivant de la ligne (f_p + f_es, f_c - 1) ; Z=1 si la
;   ligne est finie
f_elt
.(
        ldx f_es
ql       inc f_p
        bne qn1
        inc f_p+1
qn1      dex
        bne ql
        lda f_c
        bne qn2
        dec f_c+1
qn2      dec f_c
        lda f_c
        ora f_c+1
        rts
.)

f_tsave
.(
        jsr f_wopen
qrow     jsr f_row
        beq qdone
        ldx f_es
        dex
        bne qints
qstr     ldy #0                  ; tableau $ : jusqu'au premier 0
        lda (f_p),y
        ldx rz_flt
        bne qsk
        cmp #0
        beq qz0
        cmp #32
        bcc qcode
        jsr f_putc
        jmp qsk
qz0      inc rz_flt
qsk      jsr f_elt
        bne qstr
        beq qeol
qints    lda rz_flt              ; entiers séparés par un espace
        beq qfirst
        lda #" "
        jsr f_putc
qfirst   inc rz_flt
        ldy #0
        lda (f_p),y
        sta r_j
        iny
        lda (f_p),y
        sta r_j+1
        jsr f_putn
        jsr f_elt
        bne qints
qeol     lda #13
        jsr f_putc
        lda #10
        jsr f_putc
        jsr f_lend
        jmp qrow
qdone    lda #$1A
        jmp f_wclose
qcode    lda #<f_m_code
        ldy #>f_m_code
        jmp r_fail
.)

f_tload
.(
        jsr f_ropen
        bcs qok
        rts                     ; absent : rien ne change
qok      jsr f_zero
        lda #0
        sta f_ln
        sta f_ln+1
qrow     jsr f_row
        beq qmore
        lda f_ug                ; fin du fichier : le reste à 0
        cmp #$1A
        beq qr0
        inc f_ln
        bne ql1
        inc f_ln+1
ql1      ldx f_es
        dex
        bne qints
qstr     jsr f_getc              ; tableau $ : la ligne telle quelle
        jsr f_iseol
        bcs qeol
        ldx f_c
        bne qs1
        ldx f_c+1
        beq qlong
qs1      ldy #0
        sta (f_p),y
        jsr f_elt
        jmp qstr
qints    jsr f_getc              ; entiers
qil      cmp #" "
        beq qints
        cmp #9
        beq qints
        jsr f_iseol
        bcs qeol
        ldx f_c
        bne qi1
        ldx f_c+1
        beq qlong
qi1      jsr f_num
        pha
        ldy #0
        lda r_j
        sta (f_p),y
        iny
        lda r_j+1
        sta (f_p),y
        jsr f_elt
        pla
        jmp qil
qeol     cmp #13                 ; CR LF : le LF aussi
        bne qe1
        jsr f_getc
        cmp #10
        beq qe1
        sta f_ug
qe1      jsr f_left2             ; le reste de la ligne : déjà à 0
        jsr f_lend
        jmp qrow
qr0      rts
qmore    jsr f_getc              ; plus rien que des blancs ?
        cmp #$1A
        beq qr
        cmp #33
        bcc qmore
        inc f_ln
        lda #<f_m_lines
        ldy #>f_m_lines
        jmp f_lerr
qlong    lda #<f_m_long
        ldy #>f_m_long
        jmp f_lerr
qr       rts
.)

; f_left2 : saute les éléments qui restent dans la ligne
f_left2
.(
ql       lda f_c
        ora f_c+1
        beq qr
        jsr f_elt
        jmp ql
qr       rts
.)

; f_num : nombre (A = premier caractère) -> r_j ; A = caractère qui le
;   suit (espace, tabulation ou fin de ligne) ; erreur sinon
f_num
.(
        ldx #0
ql      cpx #6                  ; 6 caractères au plus (-32768)
        bcs qbad
        sta rz_nbuf,x
        inx
        stx rz_nd
        jsr f_getc
        ldx rz_nd
        cmp #" "
        beq qe
        cmp #9
        beq qe
        jsr f_iseol
        bcc ql
qe      pha
        jsr rz_atoi             ; (arr.inc)
        pla
        bcs qbad
        rts
qbad    lda #<f_m_num
        ldy #>f_m_num
        jmp f_lerr
.)

; f_putn : r_j (signé) en décimal dans le fichier (f_fmt du programme)
f_putn
.(
        jsr f_fmt
        ldy #0
ql      lda f_nbuf,y
        beq qr
        jsr f_putc
        iny
        bne ql
qr      rts
.)

; f_lerr : erreur A/Y suivie de « : L n » (n = f_ln), écrite dans DEF_DMA
f_lerr
.(
        sta f_p
        sty f_p+1
        lda #0
        sta f_i
        tay
ql       lda (f_p),y
        beq qn
        jsr f_putc
        iny
        bne ql
qn       ldy #0
ql2      lda f_tl,y
        jsr f_putc
        iny
        cpy #5
        bne ql2
        lda f_ln
        sta r_j
        lda f_ln+1
        sta r_j+1
        jsr f_putn
        lda #0
        jsr f_putc
        lda #<DEF_DMA
        ldy #>DEF_DMA
        jmp r_fail
.)

f_found .byt 0
f_typ   .asc "TXTDATSCR"
f_tl    .asc " : L "
f_m_code  .asc "code 0-31 : BSAVE",0
f_m_long  .asc "ligne trop longue",0
f_m_lines .asc "trop de lignes",0
f_m_num   .asc "nombre ?",0
