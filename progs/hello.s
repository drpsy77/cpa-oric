; HELLO.COM — premier programme transitoire CP/A
; Affiche un message puis la ligne de paramètres.
BDOS    = $0203
TAIL    = $0480

        *= $0500
        ldx #9                  ; affiche une chaîne terminée par '$'
        lda #<msg
        ldy #>msg
        jsr BDOS
        lda TAIL                ; longueur de la ligne de paramètres
        beq done
        ldx #9
        lda #<msg2
        ldy #>msg2
        jsr BDOS
        ldy #0
loop    lda TAIL+1,y
        beq crlf
        ldx #2                  ; affiche le caractère A
        jsr BDOS
        iny
        bne loop
crlf    ldx #9
        lda #<nl
        ldy #>nl
        jsr BDOS
done    rts                     ; retour au CCP

msg     .asc "Hello from a .COM file!",13,10,"$"
msg2    .asc "Arguments:$"
nl      .asc 13,10,"$"
