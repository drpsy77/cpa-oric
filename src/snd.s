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
;     op 7  SYNC   mode, relance     départ simultané des voix :
;                  mode 0 : préparation (NOTE, NOISE, TONE coupent la
;                  voix et retiennent son volume et sa durée ; ENV
;                  retient le départ de l'enveloppe) ; mode 1 : départ
;                  de toutes les voix préparées dans le même instant
;                  (interruptions masquées), enveloppe relancée si elle
;                  a été réglée pendant la préparation ou si relance = 1 ;
;                  mode 2 : abandon (les voix préparées restent muettes)
;     op 8  MIXER  voix, son, bruit  mélangeur : son et bruit de la voix
;                  (1 = oui, 0 = non), les deux à la fois possibles ;
;                  à donner après NOTE, NOISE ou TONE, qui le règlent
;  voix 0-2, vol 0-15 (16 : enveloppe), dur en 1/50 s (0 : sans fin).
;  Les durées sont décomptées par l'interruption à 50 Hz : la note joue
;  pendant que le programme continue (WAIT pour attendre).
;  Retour : A = 0, $FF si op ou paramètre incorrect.
; =====================================================================

SND_FUNC = 116
S_NOPS   = 9

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
        .word s_status-1, s_tone-1, s_sync-1, s_mixer-1

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
        lda #0                  ; fin d'une préparation
        sta s_hold
        ldx #2
dur     sta s_dur,x
        dex
        bpl dur
        ldx #10                 ; volumes des trois voix (A = 0)
vol     jsr s_write
        dex
        cpx #7
        bne vol
        lda #$7F                ; mélangeur : tout coupé, port A en sortie
        sta s_mix
        jmp s_wr0               ; (X = 7)
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
        lda #1                  ; mélangeur : son oui, bruit non
        sta s_p+2
        lsr
        sta s_p+3
        jsr mix_set
; s_setvol : durée s_d et volume s_vol de la voix s_p+1
s_setvol
        ldx s_p+1
        lda s_vol
        cmp #17
        bcc snd_v0
        lda #15
snd_v0  bit s_hold
        bpl snd_now
        sta s_pvol,x            ; préparation : retenue, voix coupée
        lda s_d
        sta s_pdur,x
        lda s_hold
        ora s_bit,x
        sta s_hold
        lda #0
        sta s_d
snd_now pha
        lda s_d
        sta s_dur,x
        txa
        ora #8
        tax
        pla
        jsr s_write
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
        lda s_p+3
        sta s_vol
        lda s_p+4
        sta s_d
        lda #0                  ; mélangeur : bruit oui, son non
        sta s_p+2
        lda #1
        sta s_p+3
        jsr mix_set
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
        sta s_penv
        bit s_hold              ; préparation : départ retenu
        bpl env_go
        lda #$40
        ora s_hold
        sta s_hold
        bne s_ok
env_go  ldx #13
s_wr0   jsr s_write
s_ok    lda #0
        rts

; s_sync : op 7 (voir l'en-tête)
s_sync
.(
        lda s_p+1
        beq prep
        cmp #2
        beq drop
        bcs s_bad
        php                     ; mode 1 : départ, interruptions masquées
        sei
        bit s_hold
        bvc voices
        lda s_penv
        ldx #13
        jsr ay_write
voices  ldy #2
loop    lda s_hold
        and s_bit,y
        beq nx
        lda s_pdur,y
        sta s_dur,y
        tya
        ora #8                  ; registre de volume de la voix
        tax
        lda s_pvol,y
        jsr ay_write
nx      dey
        bpl loop
        plp
drop    lda #0
        .byt $2C                ; (BIT abs : saute le LDA suivant)
prep    lda #$80
        sta s_hold
        bne s_ok                ; (A = $80)
        rts
.)
s_bad   lda #$FF
        rts

; s_mixer : op 8, voix p1, son p2, bruit p3 (0 = non, sinon oui)
s_mixer
        jsr s_chk
        bcs s_bad
; mix_set : mélangeur de la voix s_p+1 : son s_p+2, bruit s_p+3
mix_set
.(
        ldx s_p+1
        lda s_tbit,x            ; d'abord tout coupé pour la voix
        ora s_nbit,x
        ora s_mix
        ldy s_p+2
        beq t
        eor s_tbit,x            ; son oui (bit à 0)
t       ldy s_p+3
        beq n
        eor s_nbit,x            ; bruit oui
n       sta s_mix
        ldx #7
        bne s_wr0
.)

s_wait
.(
        cli
loop    jsr s_status
        ldx s_p+1
        cpx #3
        bcs all                 ; 255 : toutes les voix
        and s_bit,x
all     bne loop
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
s_tbit                          ; bit de son de la voix (et s_bit)
s_bit   .byt $01,$02,$04
s_nbit  .byt $08,$10,$20
