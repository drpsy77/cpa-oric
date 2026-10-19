; =====================================================================
;  MEM.COM — carte de la mémoire
;
;  Affiche les zones de la mémoire ; la TPA (fin et taille) est lue
;  dans le haut de la TPA ($020C), qui dépend du mode texte ou SPLIT.
; =====================================================================

#include "cpa.inc"

num     = $10           ; nombre à afficher en décimal (3 octets)
t0      = $13
t1      = $14
dg      = $15
nz      = $16
sptr    = $17           ; 2 octets
split   = $19           ; 1 = mode SPLIT
lim     = $1A           ; page de fin normale de la TPA ($B4 ou $A0)

        *= $0500
start
.(
        lda #<gblk              ; mode demandé au BDOS (115, GETMODE)
        ldy #>gblk
        ldx #F_GFX
        jsr BDOS
        sta split
        lda #<m_head
        ldy #>m_head
        jsr puts
        lda split
        bne spl
        lda #$B4                ; fin normale de la TPA
        sta lim
        lda #<m_text
        ldy #>m_text
        bne mode
spl     lda #$A0
        sta lim
        lda #<m_split
        ldy #>m_split
mode    jsr puts
        lda #<m_low
        ldy #>m_low
        jsr puts
        ; TPA : 0500-(haut-1), taille = haut - $0500
        lda #<m_tpa
        ldy #>m_tpa
        jsr puts
        lda TPA_TOP
        sec
        sbc #1
        tax
        lda TPA_TOP+1
        sbc #0
        jsr phex8
        txa
        jsr phex8
        lda #<m_tpa2
        ldy #>m_tpa2
        jsr puts
        lda TPA_TOP
        sta num
        lda TPA_TOP+1
        sec
        sbc #$05
        sta num+1
        lda #0
        sta num+2
        jsr pdec
        lda #<m_tpa3
        ldy #>m_tpa3
        jsr puts
        lda TPA_TOP+1           ; plafond posé sous la fin normale :
        cmp lim                 ; zone réservée (DEBUG)
        bcs img
        jsr phex8
        lda #"0"
        jsr putc
        jsr putc
        lda #"-"
        jsr putc
        ldx lim
        dex
        txa
        jsr phex8
        lda #<m_resv
        ldy #>m_resv
        jsr puts
img     lda split
        beq high
        lda #<m_img
        ldy #>m_img
        jsr puts
high    lda #<m_high
        ldy #>m_high
        jmp puts
.)

; pdec : affiche num (24 bits) en décimal, sans zéros de tête
pdec
.(
        ldx #0
        stx nz
pw      lda #0
        sta dg
sub     lda num
        sec
        sbc p0,x
        sta t0
        lda num+1
        sbc p1,x
        sta t1
        lda num+2
        sbc p2,x
        bcc out
        sta num+2
        lda t1
        sta num+1
        lda t0
        sta num
        inc dg
        bne sub
out     lda dg
        ora nz
        bne show
        cpx #5                  ; le dernier chiffre est toujours affiché
        bne skip
show    lda dg
        ora #"0"
        jsr putc
        sta nz
skip    inx
        cpx #6
        bne pw
        rts
.)
p0      .byt $A0,$10,$E8,$64,$0A,$01
p1      .byt $86,$27,$03,$00,$00,$00
p2      .byt $01,$00,$00,$00,$00,$00

; phex8 : affiche A en hexadécimal (X et Y conservés)
phex8
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nib
        pla
        and #$0F
nib     ora #"0"
        cmp #"9"+1
        bcc putc
        adc #6                  ; C=1 : + 7
; putc : affiche A (A, X et Y conservés)
putc    pha
        txa
        pha
        tya
        pha
        tsx
        lda $0103,x
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts

; puts : affiche la chaîne A/Y terminée par 0
puts
.(
        sta sptr
        sty sptr+1
        ldy #0
loop    lda (sptr),y
        beq done
        jsr putc
        iny
        bne loop
done    rts
.)

#include "mem.msg"
