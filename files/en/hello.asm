; HELLO.COM - first CP/A transient program
; Shows a message, then the parameter line.
BDOS    = $0203
TAIL    = $0480

        *= $0500
        ldx #9                  ; prints a string ended by '$'
        lda #<msg
        ldy #>msg
        jsr BDOS
        lda TAIL                ; length of the parameter line
        beq done
        ldx #9
        lda #<msg2
        ldy #>msg2
        jsr BDOS
        ldy #0
loop    lda TAIL+1,y
        beq crlf
        ldx #2                  ; prints character A
        jsr BDOS
        iny
        bne loop
crlf    ldx #9
        lda #<nl
        ldy #>nl
        jsr BDOS
done    rts                     ; back to the CCP

msg     .asc "Hello from a .COM file!",13,10,"$"
msg2    .asc "Arguments:$"
nl      .asc 13,10,"$"
