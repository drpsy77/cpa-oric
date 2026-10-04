; =====================================================================
;  fs.s — système de fichiers « à la CP/M 2.2 » (fonctions BDOS 13-25)
;
;  Disquette : 2 faces x 42 pistes x 17 secteurs de 256 octets
;  Blocs de 2 Ko (8 secteurs), 170 blocs, numéros sur 8 bits.
;  Répertoire : blocs 0-1 = 128 entrées de 32 octets, format CP/M :
;     0 utilisateur ($E5 = libre), 1-8 nom, 9-11 type, 12 EX, 13 S1,
;     14 S2, 15 RC, 16-31 numéros de blocs
;  Une entrée couvre 16 blocs = 32 Ko = 2 extents logiques de 16 Ko
;  (EXM=1 comme CP/M) ; EX = dernier extent logique, RC = nombre
;  d'enregistrements de 128 octets dans ce dernier extent.
;
;  FCB (36 octets) : 0 lecteur, 1-11 nom, 12 EX, 13 S1, 14 S2, 15 RC,
;     16-31 blocs, 32 CR (enregistrement courant), 33-35 R0-R2
; =====================================================================

FCB_EX  = 12
FCB_RC  = 15
FCB_AL  = 16
FCB_CR  = 32
FCB_S1  = 13

; ---------------------------------------------------------------------
; Accès secteur avec cache d'un secteur (écriture différée)
; ---------------------------------------------------------------------
; read_lsn : charge le secteur fs_lsn dans SECBUF. C=1 si erreur.
;   Le tampon est en écriture différée : un secteur modifié (buf_dirty)
;   est réécrit avant d'en charger un autre, et à la fermeture.
read_lsn
.(
        lda buf_ok
        beq load
        lda buf_lsn
        cmp fs_lsn
        bne load
        lda buf_lsn+1
        cmp fs_lsn+1
        bne load
        clc
        rts
load    jsr flush
        bcs err
        lda #0
        sta buf_ok
        lda fs_lsn
        sta dsk_lsn
        sta buf_lsn
        lda fs_lsn+1
        sta dsk_lsn+1
        sta buf_lsn+1
        jsr set_secbuf
        jsr disk_read
        bne io_err
        lda #1
        sta buf_ok
        clc
err     rts
.)

; claim_lsn : prend le secteur fs_lsn sans le lire (il sera entièrement
;   réécrit). C=1 si erreur.
claim_lsn
        jsr flush
        bcs cl_r
        lda fs_lsn
        sta buf_lsn
        lda fs_lsn+1
        sta buf_lsn+1
        lda #1
        sta buf_ok
        clc
cl_r    rts

; flush : réécrit le tampon s'il a été modifié. C=1 si erreur.
flush
        lda buf_dirty
        beq fl_ok
        lda buf_ok
        beq fl_ok
        jmp write_buf
fl_ok   clc
        rts

; write_buf : écrit SECBUF sur le disque (secteur buf_lsn). C=1 si erreur.
write_buf
        lda #0
        sta buf_dirty
        lda buf_lsn
        sta dsk_lsn
        lda buf_lsn+1
        sta dsk_lsn+1
        jsr set_secbuf
        jsr disk_write
        bne io_err
        clc
        rts

io_err
        lda #0
        sta buf_ok
        sta buf_dirty
        lda #1
        sta fs_err
        lda #<msg_ioerr
        ldy #>msg_ioerr
        jsr print_z
        sec
        rts

set_secbuf
        lda #<SECBUF
        sta dsk_buf
        lda #>SECBUF
        sta dsk_buf+1
        rts

; ---------------------------------------------------------------------
; Répertoire
; ---------------------------------------------------------------------
; dir_get : lit l'entrée dir_i, ZP_DIRP pointe dessus. C=1 si erreur.
dir_get
        lda dir_i
        lsr
        lsr
        lsr
        clc
        adc #<DIR_LSN
        sta fs_lsn
        lda #>DIR_LSN
        adc #0
        sta fs_lsn+1
        jsr read_lsn
        bcs dg_r
        lda dir_i
        and #7
        asl
        asl
        asl
        asl
        asl
        sta ZP_DIRP
        lda #>SECBUF
        sta ZP_DIRP+1
        clc
dg_r    rts

; match : compare le FCB et l'entrée courante. Z=1 si elles correspondent.
;   '?' dans le FCB = joker. m_anyex<>0 : tous les extents.
match
.(
        ldy #0
        lda (ZP_DIRP),y
        bne no                  ; libre ($E5) ou autre utilisateur
        ldy #11
loop    lda (ZP_FCB),y
        cmp #"?"
        beq next
        eor (ZP_DIRP),y
        and #$7F
        bne no
next    dey
        bne loop
        lda m_anyex
        bne yes
        ldy #FCB_EX
        lda (ZP_FCB),y
        cmp #"?"
        beq yes
        lsr
        sta fs_t1
        lda (ZP_DIRP),y
        lsr
        cmp fs_t1
        bne no
yes     lda #0
        rts
no      lda #1
        rts
.)

; dir_search : cherche à partir de dir_i. C=0 trouvé, C=1 sinon.
dir_search
.(
loop    lda dir_i
        cmp #DIR_ENT
        bcs nf
        jsr dir_get
        bcs nf
        jsr match
        beq found
        inc dir_i
        jmp loop
found   clc
        rts
nf      sec
        rts
.)

; dir_free : cherche une entrée libre depuis 0. C=0 trouvé.
dir_free
.(
        lda #0
        sta dir_i
loop    jsr dir_get
        bcs nf
        ldy #0
        lda (ZP_DIRP),y
        cmp #$E5
        beq found
        inc dir_i
        lda dir_i
        cmp #DIR_ENT
        bne loop
nf      sec
        rts
found   clc
        rts
.)

; ---------------------------------------------------------------------
; Carte d'allocation
; ---------------------------------------------------------------------
bitmask .byt 1,2,4,8,16,32,64,128

; alv_index : A = bloc -> Y = octet, X = bit
alv_index
        pha
        and #7
        tax
        pla
        lsr
        lsr
        lsr
        tay
        rts

alv_set
        jsr alv_index
        lda ALV,y
        ora bitmask,x
        sta ALV,y
        rts

alv_clr
        jsr alv_index
        lda bitmask,x
        eor #$FF
        and ALV,y
        sta ALV,y
        rts

; alloc_block : A = bloc libre (marqué occupé), C=1 si disque plein
alloc_block
.(
        lda #2
        sta fs_t0
loop    lda fs_t0
        cmp #NBLK
        bcs full
        jsr alv_index
        lda ALV,y
        and bitmask,x
        beq got
        inc fs_t0
        bne loop
full    sec
        rts
got     lda fs_t0
        jsr alv_set
        lda fs_t0
        clc
        rts
.)

; count_free : A = nombre de blocs libres
count_free
.(
        lda #0
        sta fs_t1
        lda #2
        sta fs_t0
loop    lda fs_t0
        jsr alv_index
        lda ALV,y
        and bitmask,x
        bne used
        inc fs_t1
used    inc fs_t0
        lda fs_t0
        cmp #NBLK
        bne loop
        lda fs_t1
        rts
.)

; ---------------------------------------------------------------------
; Fonction 13 : réinitialisation du système disque
;   Recalibre, reconstruit la carte d'allocation, DMA = $0480.
; ---------------------------------------------------------------------
fs_reset
.(
        jsr flush
        lda #0
        sta buf_ok
        sta buf_dirty
        sta fs_err
        jsr disk_home
        lda #<DEF_DMA
        sta dma
        lda #>DEF_DMA
        sta dma+1
        ldx #ALV_LEN-1
        lda #0
clr     sta ALV,x
        dex
        bpl clr
        lda #0
        jsr alv_set
        lda #1
        jsr alv_set
        lda #0
        sta dir_i
entry   jsr dir_get
        bcs err
        ldy #0
        lda (ZP_DIRP),y
        cmp #$E5
        beq next
        ldy #FCB_AL
blk     sty fs_idx
        lda (ZP_DIRP),y
        beq nb
        cmp #NBLK
        bcs nb
        jsr alv_set
nb      ldy fs_idx
        iny
        cpy #32
        bne blk
next    inc dir_i
        lda dir_i
        cmp #DIR_ENT
        bne entry
        lda #0
        rts
err     lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 15 : ouverture (A=0 si trouvé, $FF sinon)
; ---------------------------------------------------------------------
f_open
        jsr set_fcb
open_ext
.(
        lda #0
        sta dir_i
        sta m_anyex
        jsr dir_search
        bcs nf
        ; copie des numéros de blocs
        ldy #FCB_AL
cp      lda (ZP_DIRP),y
        sta (ZP_FCB),y
        iny
        cpy #32
        bne cp
        ldy #9                  ; R/O (bit 7 de t1) -> bit 7 de S1 du FCB
        lda (ZP_DIRP),y
        and #$80
        ldy #FCB_S1
        sta (ZP_FCB),y
        ; RC de l'extent demandé
        ldy #FCB_EX
        lda (ZP_DIRP),y
        sta fs_t0               ; EX de l'entrée
        lda (ZP_FCB),y
        cmp fs_t0
        beq same
        bcs after
        lda #128                ; extent plein, avant le dernier
        bne setrc
after   lda #0
        beq setrc
same    ldy #FCB_RC
        lda (ZP_DIRP),y
setrc   ldy #FCB_RC
        sta (ZP_FCB),y
        lda #0
        rts
nf      lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 16 : fermeture — met à jour l'entrée du répertoire
; ---------------------------------------------------------------------
f_close
        jsr set_fcb
close_int
.(
        jsr flush
        bcs nf
        lda #0
        sta dir_i
        sta m_anyex
        jsr dir_search
        bcs nf
        ldy #FCB_AL
cp      lda (ZP_FCB),y
        beq skip
        sta (ZP_DIRP),y
skip    iny
        cpy #32
        bne cp
        ldy #FCB_EX
        lda (ZP_DIRP),y
        sta fs_t0
        lda (ZP_FCB),y
        cmp fs_t0
        bcc done                ; extent antérieur : rien à changer
        bne newer
        ldy #FCB_RC             ; même extent : garde le plus grand RC
        lda (ZP_FCB),y
        cmp (ZP_DIRP),y
        bcc done
        sta (ZP_DIRP),y
        jmp done
newer   sta (ZP_DIRP),y         ; EX
        ldy #FCB_RC
        lda (ZP_FCB),y
        sta (ZP_DIRP),y
done    jsr write_buf
        bcs nf
        lda #0
        rts
nf      lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonctions 17/18 : recherche premier / suivant
;   Copie l'entrée trouvée (32 octets) au début du DMA, A=0 ; $FF sinon.
; ---------------------------------------------------------------------
f_sfirst
        jsr set_fcb
        lda ZP_FCB
        sta srch_fcb
        lda ZP_FCB+1
        sta srch_fcb+1
        lda #0
        sta dir_i
        beq snext_int
f_snext
        lda srch_fcb
        sta ZP_FCB
        lda srch_fcb+1
        sta ZP_FCB+1
snext_int
.(
        lda #0
        sta m_anyex
        jsr dir_search
        bcs nf
        jsr set_dmap
        ldy #31
cp      lda (ZP_DIRP),y
        sta (ZP_DMAP),y
        dey
        bpl cp
        inc dir_i
        lda #0
        rts
nf      lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 19 : suppression (jokers admis, tous les extents)
; ---------------------------------------------------------------------
f_delete
        jsr set_fcb
.(
        lda #0
        sta dir_i
        sta fs_found
        sta fs_ro
        lda #1
        sta m_anyex
loop    jsr dir_search
        bcs end
        jsr is_ro               ; protégé : on n'y touche pas
        bcc del
        inc dir_i
        jmp loop
del     ldy #0
        lda #$E5
        sta (ZP_DIRP),y
        ldy #FCB_AL
fr      sty fs_idx
        lda (ZP_DIRP),y
        beq nb
        cmp #NBLK
        bcs nb
        jsr alv_clr
nb      ldy fs_idx
        iny
        cpy #32
        bne fr
        jsr write_buf
        bcs err
        inc fs_found
        inc dir_i
        jmp loop
end     jmp ro_end
err     jmp ro_err
.)

; ro_end : fin de ERA / REN. A = 0, $FE si un fichier protégé a été
; épargné, $FF si rien n'a été trouvé
ro_end
        lda #0
        sta m_anyex
        lda fs_ro
        bne ro_fe
        lda fs_found
        beq ro_err
        lda #0
        rts
ro_fe   lda #$FE
        rts
ro_err  lda #0
        sta m_anyex
        lda #$FF
        rts

; is_ro : C=1 si l'entrée courante est en lecture seule (fs_ro = 1)
is_ro
        ldy #9
        lda (ZP_DIRP),y
        asl
        bcc ir_r
        lda #1
        sta fs_ro
ir_r    rts

; ro_named : C=1 si un fichier protégé porte le nom du FCB (ZP_FCB)
ro_named
.(
        lda #0
        sta dir_i
        lda #1
        sta m_anyex
loop    jsr dir_search
        bcs no
        jsr is_ro
        bcs yes
        inc dir_i
        jmp loop
no      clc
yes     lda #0
        sta m_anyex
        rts
.)

; ---------------------------------------------------------------------
; Fonction 30 : attributs — le bit 7 des octets 1-11 du FCB est recopié
;   dans toutes les entrées correspondantes (t1 = R/O, t2 = SYS)
; ---------------------------------------------------------------------
f_attrib
        jsr set_fcb
.(
        lda #0
        sta dir_i
        sta fs_found
        lda #1
        sta m_anyex
loop    jsr dir_search
        bcs end
        ldy #11
bits    lda (ZP_FCB),y
        and #$80
        sta fs_t0
        lda (ZP_DIRP),y
        and #$7F
        ora fs_t0
        sta (ZP_DIRP),y
        dey
        bne bits
        jsr write_buf
        bcs err
        inc fs_found
        inc dir_i
        jmp loop
end     lda #0
        sta m_anyex
        sta fs_ro
        lda fs_found
        beq err
        lda #0
        rts
err     lda #0
        sta m_anyex
        lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 22 : création (A=0, ou $FF si répertoire plein)
; ---------------------------------------------------------------------
f_make
        jsr set_fcb
        jsr ro_named
        bcc make_int
        lda #$FF
        rts
make_int
.(
        jsr dir_free
        bcs full
        ldy #0
        lda #0
        sta (ZP_DIRP),y
        iny
nm      lda (ZP_FCB),y
        and #$7F
        sta (ZP_DIRP),y
        iny
        cpy #12
        bne nm
        lda (ZP_FCB),y          ; EX
        sta (ZP_DIRP),y
        iny
        lda #0
z1      sta (ZP_DIRP),y         ; S1, S2, RC, blocs
        iny
        cpy #32
        bne z1
        ldy #FCB_S1
        sta (ZP_FCB),y
        ldy #FCB_RC
z2      sta (ZP_FCB),y          ; RC et blocs du FCB à 0
        iny
        cpy #32
        bne z2
        jsr write_buf
        bcs full
        lda #0
        rts
full    lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 23 : renommage — ancien nom en FCB+0, nouveau en FCB+16
; ---------------------------------------------------------------------
f_rename
        jsr set_fcb
.(
        lda #0
        sta fs_ro
        clc                     ; le nouveau nom est-il protégé ?
        lda ZP_FCB
        adc #16
        sta ZP_FCB
        bcc n1
        inc ZP_FCB+1
n1      jsr ro_named
        php
        sec
        lda ZP_FCB
        sbc #16
        sta ZP_FCB
        bcs n2
        dec ZP_FCB+1
n2      plp
        bcc go
        lda #$FE
        rts
go      lda #0
        sta dir_i
        sta fs_found
        sta fs_ro
        lda #1
        sta m_anyex
loop    jsr dir_search
        bcs end
        jsr is_ro               ; protégé : pas renommé
        bcc ren
        inc dir_i
        jmp loop
ren     ldy #1
cp      tya
        clc
        adc #16
        tay
        lda (ZP_FCB),y
        and #$7F
        pha
        tya
        sec
        sbc #16
        tay
        lda (ZP_DIRP),y         ; garde les attributs
        and #$80
        sta fs_t0
        pla
        ora fs_t0
        sta (ZP_DIRP),y
        iny
        cpy #12
        bne cp
        jsr write_buf
        bcs err
        inc fs_found
        inc dir_i
        jmp loop
end     jmp ro_end
err     jmp ro_err
.)

; ---------------------------------------------------------------------
; rec_lsn : enregistrement courant du FCB -> fs_lsn, fs_half
;   C=1 si le bloc n'est pas alloué.
; ---------------------------------------------------------------------
rec_index
        ldy #FCB_EX             ; fs_rec = (EX and 1)*128 + CR
        lda (ZP_FCB),y
        lsr
        ldy #FCB_CR
        lda (ZP_FCB),y
        and #$7F
        bcc ri1
        ora #$80
ri1     sta fs_rec
        lsr                     ; Y = FCB_AL + fs_rec/16
        lsr
        lsr
        lsr
        clc
        adc #FCB_AL
        tay
        rts

rec_lsn
.(
        jsr rec_index
        lda (ZP_FCB),y
        beq hole
        sta fs_blk
        lda #0
        sta fs_lsn+1
        lda fs_blk
        asl                     ; bloc * 8
        rol fs_lsn+1
        asl
        rol fs_lsn+1
        asl
        rol fs_lsn+1
        sta fs_lsn
        lda fs_rec              ; + secteur dans le bloc
        lsr
        and #7
        ora fs_lsn
        clc
        adc #<DIR_LSN
        sta fs_lsn
        lda fs_lsn+1
        adc #>DIR_LSN
        sta fs_lsn+1
        lda fs_rec
        and #1
        sta fs_half
        clc
        rts
hole    sec
        rts
.)

; ---------------------------------------------------------------------
; Fonction 20 : lecture séquentielle (A=0 OK, 1 fin de fichier, $FF erreur)
; ---------------------------------------------------------------------
f_read
        jsr set_fcb
.(
        ldy #FCB_CR
        lda (ZP_FCB),y
        ldy #FCB_RC
        cmp (ZP_FCB),y
        bcc have
        lda (ZP_FCB),y
        cmp #128
        bcc eof                 ; extent incomplet : fin
        ; extent suivant
        ldy #FCB_EX
        lda (ZP_FCB),y
        clc
        adc #1
        sta (ZP_FCB),y
        ldy #FCB_CR
        lda #0
        sta (ZP_FCB),y
        jsr open_ext
        bne eof
        ldy #FCB_RC
        lda (ZP_FCB),y
        beq eof
have    jsr rec_lsn
        bcs eof
        jsr read_lsn
        bcs err
        jsr copy_out
        ldy #FCB_CR
        lda (ZP_FCB),y
        clc
        adc #1
        sta (ZP_FCB),y
        lda #0
        rts
eof     lda #1
        rts
err     lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; Fonction 21 : écriture séquentielle (A=0 OK, 1 répertoire plein,
;               2 disque plein, $FF erreur)
; ---------------------------------------------------------------------
f_write
        jsr set_fcb
        ldy #FCB_S1             ; ouvert en lecture seule ?
        lda (ZP_FCB),y
        bpl fw_ok
        lda #$FF
        rts
fw_ok
.(
        ldy #FCB_CR
        lda (ZP_FCB),y
        cmp #128
        bcc room
        ; extent logique plein : passe au suivant
        ldy #FCB_EX
        lda (ZP_FCB),y
        and #1
        beq same_entry
        jsr close_int           ; l'entrée (32 Ko) est pleine : on la ferme
        beq cl_ok
        jmp err
cl_ok
        ldy #FCB_EX
        lda (ZP_FCB),y
        clc
        adc #1
        sta (ZP_FCB),y
        jsr make_int            ; et on en crée une nouvelle
        beq reset_cr
        jmp dfull
same_entry
        lda (ZP_FCB),y
        clc
        adc #1
        sta (ZP_FCB),y
        ldy #FCB_RC
        lda #0
        sta (ZP_FCB),y
reset_cr
        ldy #FCB_CR
        lda #0
        sta (ZP_FCB),y
room
&fw_room                        ; (écriture directe : enregistrement CR)
        jsr rec_index
        lda (ZP_FCB),y
        bne have
        sty fs_idx
        jsr alloc_block
        bcs full
        ldy fs_idx
        sta (ZP_FCB),y
have    jsr rec_lsn
        ; ajout en fin de fichier sur un secteur neuf : inutile de le lire
        lda fs_half
        bne rd
        ldy #FCB_CR
        lda (ZP_FCB),y
        ldy #FCB_RC
        cmp (ZP_FCB),y
        bcc rd
        jsr claim_lsn
        bcs err
        ldy #0
        lda #$1A
fill    sta SECBUF+128,y
        iny
        bpl fill
        bmi docp
rd      jsr read_lsn
        bcs err
docp    jsr set_dmap
        ldy #0
        lda fs_half
        bne hi
lo      lda (ZP_DMAP),y
        sta SECBUF,y
        iny
        bpl lo
        bmi wrt
hi      lda (ZP_DMAP),y
        sta SECBUF+128,y
        iny
        bpl hi
wrt     lda #1
        sta buf_dirty
        ldy #FCB_CR
        lda (ZP_FCB),y
        clc
        adc #1
        sta (ZP_FCB),y
        ldy #FCB_RC
        cmp (ZP_FCB),y
        bcc ok
        sta (ZP_FCB),y
ok      lda #0
        rts
dfull   lda #1
        rts
full    lda #2
        rts
err     lda #$FF
        rts
.)

; copy_out : demi-secteur courant (fs_half) -> DMA
copy_out
.(
        jsr set_dmap
        ldy #0
        lda fs_half
        bne hi
lo      lda SECBUF,y
        sta (ZP_DMAP),y
        iny
        bpl lo
        rts
hi      lda SECBUF+128,y
        sta (ZP_DMAP),y
        iny
        bpl hi
        rts
.)

; ---------------------------------------------------------------------
; Accès direct (fonctions 33 à 36). Numéro d'enregistrement : R0-R2 du
; FCB (octets 33-35), 0 à 4095 (un fichier fait au plus 2720 enreg.).
; L'enregistrement courant n'avance pas : une lecture séquentielle
; reprend au même endroit.
; ---------------------------------------------------------------------
FCB_R0  = 33

; rnd_rec : R0-R2 -> fs_rex (extent), fs_rcr (enregistrement). C=1 et
; A=6 si hors limites
rnd_rec
.(
        ldy #FCB_R0+2
        lda (ZP_FCB),y
        bne bad
        dey
        lda (ZP_FCB),y
        cmp #$10
        bcs bad
        sta fs_t1
        dey
        lda (ZP_FCB),y
        and #$7F
        sta fs_rcr
        lda (ZP_FCB),y
        asl                     ; bit 7 de R0 -> C
        lda fs_t1
        rol                     ; extent = R / 128
        sta fs_rex
        clc
        rts
bad     lda #6
        sec
        rts
.)

; Fonction 33 : lecture directe (0 OK, 1 enregistrement jamais écrit,
;               4 extent inexistant, 6 hors limites, $FF erreur)
f_rread
        jsr set_fcb
.(
        jsr rnd_rec
        bcs r
        ldy #FCB_EX
        lda fs_rex
        cmp (ZP_FCB),y
        beq same
        sta (ZP_FCB),y
        jsr open_ext
        beq same
        lda #4
        rts
same    ldy #FCB_CR
        lda fs_rcr
        sta (ZP_FCB),y
        jsr rec_lsn
        bcs hole
        jsr read_lsn
        bcs err
        jsr copy_out
        lda #0
r       rts
hole    lda #1
        rts
err     lda #$FF
        rts
.)

; Fonction 34 : écriture directe (0 OK, 2 disque plein, 5 répertoire
;               plein, 6 hors limites, $FF erreur ou fichier R/O)
f_rwrite
        jsr set_fcb
.(
        ldy #FCB_S1
        lda (ZP_FCB),y
        bpl ok
        lda #$FF
        rts
ok      jsr rnd_rec
        bcs r
        ldy #FCB_EX
        lda fs_rex
        cmp (ZP_FCB),y
        beq same
        jsr close_int           ; on change d'extent : l'actuel est rangé
        ldy #FCB_EX
        lda fs_rex
        sta (ZP_FCB),y
        jsr open_ext
        beq same
        jsr make_int            ; extent nouveau (fichier à trous)
        beq same
        lda #5
        rts
same    ldy #FCB_CR
        lda fs_rcr
        sta (ZP_FCB),y
        jsr fw_room
        pha
        ldy #FCB_CR             ; la position ne bouge pas
        lda fs_rcr
        sta (ZP_FCB),y
        pla
r       rts
.)

; Fonction 35 : taille du fichier en enregistrements -> R0-R2
f_fsize
        jsr set_fcb
.(
        lda #0
        sta fs_szl
        sta fs_szh
        sta dir_i
        lda #1
        sta m_anyex
loop    jsr dir_search
        bcs end
        ldy #FCB_EX             ; EX * 128 + RC
        lda (ZP_DIRP),y
        lsr
        sta fs_t1
        lda #0
        ror
        ldy #FCB_RC
        clc
        adc (ZP_DIRP),y
        sta fs_t0
        bcc n1
        inc fs_t1
n1      lda fs_t0               ; plus grand que le maximum ?
        cmp fs_szl
        lda fs_t1
        sbc fs_szh
        bcc nx
        lda fs_t0
        sta fs_szl
        lda fs_t1
        sta fs_szh
nx      inc dir_i
        jmp loop
end     lda #0
        sta m_anyex
        ldy #FCB_R0
        lda fs_szl
        sta (ZP_FCB),y
        iny
        lda fs_szh
        sta (ZP_FCB),y
        iny
        lda #0
        sta (ZP_FCB),y
        rts
.)

; Fonction 36 : R0-R2 = position séquentielle courante (EX * 128 + CR)
f_setrnd
        jsr set_fcb
        ldy #FCB_EX
        lda (ZP_FCB),y
        lsr
        sta fs_t1
        lda #0
        ror
        ldy #FCB_CR
        ora (ZP_FCB),y
        ldy #FCB_R0
        sta (ZP_FCB),y
        iny
        lda fs_t1
        sta (ZP_FCB),y
        iny
        lda #0
        sta (ZP_FCB),y
        rts

; ---------------------------------------------------------------------
set_fcb
        lda ZP_PTR
        sta ZP_FCB
        lda ZP_PTR+1
        sta ZP_FCB+1
        rts

set_dmap
        lda dma
        sta ZP_DMAP
        lda dma+1
        sta ZP_DMAP+1
        rts

; Fonction 14 : sélection du lecteur (seul A: existe)
f_seldsk
        cmp #0
        bne fsd_bad
        lda #0
        rts
fsd_bad lda #$FF
        rts

msg_ioerr
        .asc 13,10,"BDOS: disk I/O error",13,10,0
