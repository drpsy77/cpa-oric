; =====================================================================
;  boot.s — secteurs d'amorçage Microdisc de la disquette CP/A
;  (piste 0, face 0, secteurs 1 à 3 = secteurs logiques 0 à 2)
;
;  À la mise sous tension, l'EPROM du Microdisc lit la piste 0 en
;  croyant trouver une disquette Oric DOS : le secteur 2 contient un
;  faux enregistrement "BOOTUP.COM" décrit par le faux répertoire du
;  secteur 3. Elle charge ce secteur et exécute le code qui suit les
;  23 octets d'en-tête. Ce code se recopie en $9800, coupe ROM et
;  EPROM (RAM overlay visible), charge les 64 secteurs du système
;  (LSN 3 à 66) en $C000-$FFFF puis saute au vecteur RESET de CP/A.
;
;  Structure du faux système Oric DOS reprise de l'exemple
;  FloppyBuilder de l'OSDK.
; =====================================================================

FINAL       = $9800     ; adresse d'exécution du chargeur

FDC_CMD     = $0310
FDC_TRK     = $0311
FDC_SEC     = $0312
FDC_DATA    = $0313
MD_CTRL     = $0314
MD_DRQ      = $0318
MD_BASE     = $84       ; EPROM et ROM coupées, lecteur A, face 0

; variables en page zéro
ptr         = $02
sect        = $04
side        = $05
cyl         = $06
count       = $07

        *= 0

; ---------------------------------------------------------------------
; Secteur 1
; ---------------------------------------------------------------------
s1
        ; paramètres lus par l'EPROM (même disposition que Sedoric) :
        ; octet $12 = secteur du répertoire Oric DOS, $13 = sa piste
        .byt $01,$00,$00,$00,$00,$00,$00,$00
        .asc "        "
        .byt $00,$00,$03,$00,$00,$00,$01,$00
        .asc "CP/A boot disk",0
        .dsb 256-(*-s1),0

; ---------------------------------------------------------------------
; Secteur 2 : en-tête "BOOTUP.COM" puis code
; ---------------------------------------------------------------------
s2
        .byt $00,$00,$FF,$00,$D0,$9F,$D0,$9F,$02,$B9,$01,$00,$FF,$00,$00,$B9
        .byt $E4,$B9,$00,$00,$E6,$12,$00

        ; trouve notre propre adresse via la pile
        sei
        lda #$60                ; RTS
        sta $00
        jsr $0000
reloc_start
        tsx
        dex
        clc
        lda $0100,x
        adc #<(reloc_end-reloc_start+1)
        sta ptr
        lda $0101,x
        adc #>(reloc_end-reloc_start+1)
        sta ptr+1
        ldy #0
copy    lda (ptr),y
        sta FINAL,y
        iny
        cpy #(code_end-code_begin)
        bne copy
        jmp FINAL
reloc_end

        *= FINAL
code_begin
        lda #$00
        sta ptr
        lda #$C0
        sta ptr+1
        lda #4                  ; LSN 3 = piste 0, face 0, secteur 4
        sta sect
        lda #0
        sta side
        sta cyl
        lda #64                 ; 64 secteurs = 16 Ko
        sta count

loop    lda side
        asl
        asl
        asl
        asl
        ora #MD_BASE
        sta MD_CTRL
        lda cyl
        cmp FDC_TRK
        beq trk_ok
        sta FDC_DATA
        lda #$1F                ; SEEK avec vérification
        sta FDC_CMD
        jsr wait
trk_ok  lda sect
        sta FDC_SEC
        lda #$80                ; READ SECTOR
        sta FDC_CMD
        ldy #4
dly     dey
        bne dly
rd      lda MD_DRQ
        bmi rd
        lda FDC_DATA
        sta (ptr),y
        iny
        bne rd
        jsr wait
        and #$0E                ; non trouvé / CRC / perte de données
        bne loop                ; on recommence le secteur

        inc ptr+1
        inc sect
        lda sect
        cmp #18
        bne next
        lda #1
        sta sect
        lda side
        eor #1
        sta side
        bne next
        inc cyl
next    dec count
        bne loop
        jmp ($FFFC)             ; démarrage à froid de CP/A

wait    ldy #8
w1      dey
        bne w1
w2      lda FDC_CMD
        lsr
        bcs w2
        rts
code_end

        .dsb 256-((reloc_end-s2)+(code_end-code_begin)),0

; ---------------------------------------------------------------------
; Secteur 3 : faux répertoire Oric DOS (SYSTEM.DOS, BOOTUP.COM)
; ---------------------------------------------------------------------
s3
        .byt $00,$00,$02,$53,$59,$53,$54,$45,$4d,$44,$4f,$53,$01,$00,$02,$00
        .byt $02,$00,$00,$42,$4f,$4f,$54,$55,$50,$43,$4f,$4d,$00,$00,$00,$00
        .dsb 256-32,0
