; =====================================================================
;  snd.s — son (BDOS fonction 116), circuit AY-3-8912
;
;  Appel : X = 116, A/Y = adresse d'un bloc [op, p1, p2, p3, p4, p5]
;     op 0  SILENCE                     coupe les trois voix
;     op 1  NOTE   voix, note, vol, dur  note 1-96 (37 = do central C4,
;                                       46 = la 440 Hz), 0 = silence
;     op 2  NOISE  voix, période, vol, dur   bruit (période 0-31)
;     op 3  ENV    forme, période lo, hi     enveloppe (vol 16 = enveloppe)
;     op 4  WAIT   voix                 attend la fin (255 : toutes)
;     op 5  STATUS                      -> A : bits des voix qui jouent
;     op 6  TONE   voix, pér. lo, hi, vol, dur  période brute (0-4095)
;  voix 0-2, vol 0-15 (16 : enveloppe), dur en 1/50 s (0 : sans fin).
;  Les durées sont décomptées par l'interruption à 50 Hz : la note joue
;  pendant que le programme continue (WAIT pour attendre).
;  Retour : A = 0, $FF si op ou paramètre incorrect.
; =====================================================================

SND_FUNC = 116
S_NOPS   = 7

snd_call
.(
        ldy #5
cp      lda (ZP_PTR),y
        sta s_p,y
        dey
        bpl cp
        lda s_p
        cmp #S_NOPS
        bcs err
        asl
        tax
        lda s_tab+1,x
        pha
        lda s_tab,x
        pha
        rts
err     lda #$FF
        rts
.)

s_tab   .word s_silence-1, s_note-1, s_noise-1, s_env-1, s_wait-1
        .word s_status-1, s_tone-1

; s_write : registre X <- A, à l'abri de l'interruption (le clavier
; utilise aussi l'AY)
s_write
        php
        sei
        jsr ay_write
        plp
        rts

s_silence
.(
        ldx #2
loop    lda #0
        sta s_dur,x
        txa
        pha
        clc
        adc #8                  ; volume de la voix
        tax
        lda #0
        jsr s_write
        pla
        tax
        dex
        bpl loop
        lda #$7F                ; mélangeur : tout coupé, port A en sortie
        sta s_mix
        ldx #7
        jsr s_write
        lda #0
        rts
.)

; s_chk : voix p1 correcte ? C=1 sinon
s_chk
        lda s_p+1
        cmp #3
        rts

s_note
.(
        jsr s_chk
        bcs bad
        lda s_p+2               ; note 0 : silence pendant dur
        beq rest
        cmp #97
        bcs bad
        sec
        sbc #1
        ldx #0                  ; octave = (note-1) / 12, demi-ton = reste
oct     cmp #12
        bcc semi
        sbc #12
        inx
        bne oct
semi    asl
        tay
        lda s_per,y             ; période dans s_lo / s_hi
        sta s_lo
        lda s_per+1,y
        sta s_hi
        txa                     ; période >> octave
        beq go
sh      lsr s_hi
        ror s_lo
        dex
        bne sh
go      lda s_p+3               ; volume
        sta s_vol
        lda s_p+4               ; durée
        sta s_d
        jmp s_play
rest    lda #0
        sta s_vol
        lda s_p+4
        sta s_d
        lda #0
        sta s_lo
        sta s_hi
        jmp s_play
bad     lda #$FF
        rts
.)

s_tone
.(
        jsr s_chk
        bcs bad
        lda s_p+2
        sta s_lo
        lda s_p+3
        and #$0F
        sta s_hi
        lda s_p+4
        sta s_vol
        lda s_p+5
        sta s_d
        jmp s_play
bad     lda #$FF
        rts
.)

; s_play : voix s_p+1, période s_lo/s_hi, volume s_vol, durée s_d
s_play
        lda s_p+1
        asl
        tax                     ; registres de période : 2 * voix
        lda s_lo
        jsr s_write
        inx
        lda s_hi
        jsr s_write
        ldx s_p+1               ; mélangeur : son oui, bruit non
        lda s_mix
        and s_off,x
        ora s_nbit,x
        sta s_mix
        ldx #7
        jsr s_write
; s_setvol : durée s_d et volume s_vol de la voix s_p+1
s_setvol
        ldx s_p+1
        lda s_d
        sta s_dur,x
        txa
        clc
        adc #8
        tax
        lda s_vol
        cmp #17
        bcc snd_v1
        lda #15
snd_v1  jsr s_write
        lda #0
        rts

s_noise
.(
        jsr s_chk
        bcs bad
        lda s_p+2
        and #31
        ldx #6
        jsr s_write
        ldx s_p+1               ; mélangeur : bruit oui, son non
        lda s_mix
        ora s_tbit,x
        and s_noff,x
        sta s_mix
        ldx #7
        jsr s_write
        lda s_p+3
        sta s_vol
        lda s_p+4
        sta s_d
        jmp s_setvol
bad     lda #$FF
        rts
.)

s_env
        lda s_p+2
        ldx #11
        jsr s_write
        lda s_p+3
        ldx #12
        jsr s_write
        lda s_p+1
        and #15
        ldx #13
        jsr s_write
        lda #0
        rts

s_wait
.(
        cli
loop    ldx s_p+1
        cpx #3
        bcc one
        lda s_dur               ; toutes les voix
        ora s_dur+1
        ora s_dur+2
        bne loop
        rts
one     lda s_dur,x
        bne loop
        rts
.)

s_status
.(
        lda #0
        ldx #2
loop    ldy s_dur,x
        beq nx
        ora s_bit,x
nx      dex
        bpl loop
        rts
.)

; snd_tick : appelé à 50 Hz par l'IRQ — fin des notes minutées
snd_tick
.(
        ldx #2
loop    lda s_dur,x
        beq nx
        dec s_dur,x
        bne nx
        txa                     ; durée écoulée : volume à 0
        pha
        clc
        adc #8
        tax
        lda #0
        jsr ay_write            ; (déjà sous interruption)
        pla
        tax
nx      dex
        bpl loop
        rts
.)

; périodes de l'octave 1 (do 32,7 Hz ... si), horloge de l'AY : 1 MHz
s_per   .word 1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073,1012
s_off   .byt $FE,$FD,$FB        ; masques : son de la voix
s_tbit  .byt $01,$02,$04
s_noff  .byt $F7,$EF,$DF        ; bruit de la voix
s_nbit  .byt $08,$10,$20
s_bit   .byt $01,$02,$04
