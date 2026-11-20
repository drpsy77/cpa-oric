; =====================================================================
;  dis_inc.s — modes d'adressage et tables du désassembleur, partagés
;  par DEBUG.COM et DIS.COM (tables d'instructions : asm_tab.s)
;  L'appelant fournit : ptr (2 octets) et tmpb en page zéro, dis_mn et
;  dis_md (256 octets chacun).
; =====================================================================
M_IMP   = 0
M_IMM   = 1
M_ZP    = 2
M_ZPX   = 3
M_ZPY   = 4
M_ABS   = 5
M_ABX   = 6
M_ABY   = 7
M_IND   = 8
M_INX   = 9
M_INY   = 10
M_REL   = 11

md_len  .byt 1,2,2,2,2,3,3,3,3,2,2,2

; dis_init : tables opcode -> mnémonique et mode, à partir de mn_ops
dis_init
.(
        ldx #0
        lda #$FF
cl      sta dis_mn,x
        sta dis_md,x
        inx
        bne cl
        lda #<mn_ops
        sta ptr
        lda #>mn_ops
        sta ptr+1
        lda #0
        sta tmpb                ; numéro du mnémonique
mn      ldy #0
md      lda (ptr),y
        cmp #$FF
        beq nx
        tax
        lda tmpb
        sta dis_mn,x
        tya
        sta dis_md,x
nx      iny
        cpy #12
        bne md
        clc
        lda ptr
        adc #12
        sta ptr
        bcc m1
        inc ptr+1
m1      inc tmpb
        lda tmpb
        cmp #NMNEM
        bne mn
        rts
.)
