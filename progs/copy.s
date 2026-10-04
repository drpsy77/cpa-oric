; COPY.COM — copie un fichier : COPY SOURCE DEST
; Exemple d'utilisation des fonctions fichiers du BDOS.
BDOS    = $0203
FCB1    = $045C                 ; source, préparée par le CCP
FCB2    = $046C                 ; nom de la destination (16 octets)
BUF     = $0800                 ; tampon de copie, après le programme
BUFEND  = $B400                 ; fin de la TPA
ptr     = $10                   ; page zéro libre pour les programmes

        *= $0500
        jmp start

usage   lda #<msg_use
        ldy #>msg_use
        ldx #9
        jmp BDOS
nosrc   lda #<msg_nosrc
        ldy #>msg_nosrc
        ldx #9
        jmp BDOS
err     lda #<msg_err
        ldy #>msg_err
        ldx #9
        jmp BDOS

start
        ; recopie le nom de destination dans notre propre FCB
        ldx #15
c1      lda FCB2,x
        sta dst,x
        dex
        bpl c1
        lda dst+1
        cmp #" "
        beq usage
        lda FCB1+1
        cmp #" "
        beq usage

        ldx #15                 ; ouvre la source
        lda #<FCB1
        ldy #>FCB1
        jsr BDOS
        cmp #$FF
        beq nosrc
        lda #0
        sta FCB1+32

        ldx #19                 ; supprime puis crée la destination
        lda #<dst
        ldy #>dst
        jsr BDOS
        ldx #22
        lda #<dst
        ldy #>dst
        jsr BDOS
        cmp #$FF
        beq err

pass    lda #<BUF               ; lit autant d'enregistrements que possible
        sta ptr
        lda #>BUF
        sta ptr+1
        lda #0
        sta nrec
        sta nrec+1
        sta eof
rd      lda ptr+1
        cmp #>BUFEND
        bcs wr
        ldx #26
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #20
        lda #<FCB1
        ldy #>FCB1
        jsr BDOS
        cmp #0
        bne at_eof
        jsr next_ptr
        inc nrec
        bne rd
        inc nrec+1
        bne rd
at_eof  lda #1
        sta eof
wr      lda #<BUF               ; puis les écrit
        sta ptr
        lda #>BUF
        sta ptr+1
wloop   lda nrec
        ora nrec+1
        beq written
        ldx #26
        lda ptr
        ldy ptr+1
        jsr BDOS
        ldx #21
        lda #<dst
        ldy #>dst
        jsr BDOS
        cmp #0
        beq wok
        jmp err
wok     jsr next_ptr
        lda nrec
        bne dec1
        dec nrec+1
dec1    dec nrec
        jmp wloop
written lda eof
        beq pass
        ldx #16
        lda #<dst
        ldy #>dst
        jsr BDOS
        lda #<msg_ok
        ldy #>msg_ok
        ldx #9
        jmp BDOS                ; le RTS de la fonction 9 revient au CCP

next_ptr
        lda ptr
        eor #$80
        sta ptr
        bne np
        inc ptr+1
np      rts

msg_ok    .asc "Copied.",13,10,"$"
msg_use   .asc "Usage: COPY SOURCE DEST",13,10,"$"
msg_nosrc .asc "Source not found",13,10,"$"
msg_err   .asc "Write error",13,10,"$"
nrec      .word 0
eof       .byt 0
dst       .dsb 36,0
