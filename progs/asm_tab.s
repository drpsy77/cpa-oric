; Généré par gen_asm_tab.py : mnémoniques et opcodes du 6502
; modes : IMP IMM ZP ZPX ZPY ABS ABX ABY IND INX INY REL ($FF = absent)
NMNEM = 56
mn_names
        .asc "ADCANDASLBCCBCSBEQBITBMI"
        .asc "BNEBPLBRKBVCBVSCLCCLDCLI"
        .asc "CLVCMPCPXCPYDECDEXDEYEOR"
        .asc "INCINXINYJMPJSRLDALDXLDY"
        .asc "LSRNOPORAPHAPHPPLAPLPROL"
        .asc "RORRTIRTSSBCSECSEDSEISTA"
        .asc "STXSTYTAXTAYTSXTXATXSTYA"
MN_JMP = 27
mn_first .byt 0,3,13,20,23,255,255,255,24,27,255,29,255,33,34,35,255,39,43,50,255,255,255,255,255,255
mn_ops
        .byt $FF,$69,$65,$75,$FF,$6D,$7D,$79,$FF,$61,$71,$FF   ; ADC
        .byt $FF,$29,$25,$35,$FF,$2D,$3D,$39,$FF,$21,$31,$FF   ; AND
        .byt $0A,$FF,$06,$16,$FF,$0E,$1E,$FF,$FF,$FF,$FF,$FF   ; ASL
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$90   ; BCC
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$B0   ; BCS
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F0   ; BEQ
        .byt $FF,$FF,$24,$FF,$FF,$2C,$FF,$FF,$FF,$FF,$FF,$FF   ; BIT
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$30   ; BMI
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$D0   ; BNE
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$10   ; BPL
        .byt $00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; BRK
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$50   ; BVC
        .byt $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$70   ; BVS
        .byt $18,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; CLC
        .byt $D8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; CLD
        .byt $58,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; CLI
        .byt $B8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; CLV
        .byt $FF,$C9,$C5,$D5,$FF,$CD,$DD,$D9,$FF,$C1,$D1,$FF   ; CMP
        .byt $FF,$E0,$E4,$FF,$FF,$EC,$FF,$FF,$FF,$FF,$FF,$FF   ; CPX
        .byt $FF,$C0,$C4,$FF,$FF,$CC,$FF,$FF,$FF,$FF,$FF,$FF   ; CPY
        .byt $FF,$FF,$C6,$D6,$FF,$CE,$DE,$FF,$FF,$FF,$FF,$FF   ; DEC
        .byt $CA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; DEX
        .byt $88,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; DEY
        .byt $FF,$49,$45,$55,$FF,$4D,$5D,$59,$FF,$41,$51,$FF   ; EOR
        .byt $FF,$FF,$E6,$F6,$FF,$EE,$FE,$FF,$FF,$FF,$FF,$FF   ; INC
        .byt $E8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; INX
        .byt $C8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; INY
        .byt $FF,$FF,$FF,$FF,$FF,$4C,$FF,$FF,$6C,$FF,$FF,$FF   ; JMP
        .byt $FF,$FF,$FF,$FF,$FF,$20,$FF,$FF,$FF,$FF,$FF,$FF   ; JSR
        .byt $FF,$A9,$A5,$B5,$FF,$AD,$BD,$B9,$FF,$A1,$B1,$FF   ; LDA
        .byt $FF,$A2,$A6,$FF,$B6,$AE,$FF,$BE,$FF,$FF,$FF,$FF   ; LDX
        .byt $FF,$A0,$A4,$B4,$FF,$AC,$BC,$FF,$FF,$FF,$FF,$FF   ; LDY
        .byt $4A,$FF,$46,$56,$FF,$4E,$5E,$FF,$FF,$FF,$FF,$FF   ; LSR
        .byt $EA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; NOP
        .byt $FF,$09,$05,$15,$FF,$0D,$1D,$19,$FF,$01,$11,$FF   ; ORA
        .byt $48,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; PHA
        .byt $08,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; PHP
        .byt $68,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; PLA
        .byt $28,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; PLP
        .byt $2A,$FF,$26,$36,$FF,$2E,$3E,$FF,$FF,$FF,$FF,$FF   ; ROL
        .byt $6A,$FF,$66,$76,$FF,$6E,$7E,$FF,$FF,$FF,$FF,$FF   ; ROR
        .byt $40,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; RTI
        .byt $60,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; RTS
        .byt $FF,$E9,$E5,$F5,$FF,$ED,$FD,$F9,$FF,$E1,$F1,$FF   ; SBC
        .byt $38,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; SEC
        .byt $F8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; SED
        .byt $78,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; SEI
        .byt $FF,$FF,$85,$95,$FF,$8D,$9D,$99,$FF,$81,$91,$FF   ; STA
        .byt $FF,$FF,$86,$FF,$96,$8E,$FF,$FF,$FF,$FF,$FF,$FF   ; STX
        .byt $FF,$FF,$84,$94,$FF,$8C,$FF,$FF,$FF,$FF,$FF,$FF   ; STY
        .byt $AA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TAX
        .byt $A8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TAY
        .byt $BA,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TSX
        .byt $8A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TXA
        .byt $9A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TXS
        .byt $98,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; TYA
