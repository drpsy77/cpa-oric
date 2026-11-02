; =====================================================================
;  serial.s — pilote série résident et console à distance (option SERIE)
;
;  Port : l'ACIA 6551 du modem (LOCI $0380, Oricutron $031C), réglée par
;  le programme qui pose le port (REMOTE, acia_inc.s) : 9600 bauds 8N1,
;  DTR, sans interruption de l'ACIA. Accès par LDA / STA absolus
;  seulement (sr_rsta, sr_rdat, sr_wdat : octet bas posé par la fonction
;  117, op 1) : une écriture indexée lirait d'abord le registre visé.
;
;  Console à distance (docs/console-distance.md) : sous l'IRQ de 50 Hz,
;  le pilote lit ce qu'envoie le démon du Mac (tools/remote.py) et ne
;  répond qu'aux demandes. Mac -> Oric : $FE k (touche k rangée dans le
;  tampon du clavier, lue seulement s'il y a de la place), $FD "S"
;  (totaux), $FD "L" n (ligne n), $FD "B" (démarrage à chaud) ; tout
;  autre octet est ignoré (messages du modem). Oric -> Mac :
;      $FF type longueur données total
;  (total : somme sur 8 bits de type, longueur et données) ;
;  "S" : mode, colonne et ligne du curseur, curseur actif, puis les 28
;  totaux de Fletcher (s1, puis s2) des lignes de l'écran ; "L" : n, puis
;  les 40 octets de la ligne. La case du curseur est lue rétablie.
;
;  Variables : sr_port... (hw.inc, $FD13-$FD1F), effacées au démarrage à
;  froid seulement : le pilote survit au démarrage à chaud.
; =====================================================================

SER_FUNC = 117
; Plafonds par IRQ (sr_rxn, sr_rxw, sr_txn, sr_bdg), posés avec le port
; (table sr_par) : un vrai 6551 (Oricutron, carte série) n'a qu'un octet
; reçu et émet un octet par milliseconde ; le LOCI garde 32 octets reçus,
; tout de suite lisibles, et prend un octet émis dès que l'USB l'accepte.
;   sr_rxn : octets reçus au plus ; sr_rxw : attente de chacun après le
;   premier (pas de 25 µs environ) ; sr_txn : octets émis au plus ;
;   sr_bdg : attente de l'émetteur, comptée sur toute l'IRQ (pas de 30 µs)

; ---------------------------------------------------------------------
; sr_irq : appelé à 50 Hz par l'IRQ ; ne fait rien si la console est coupée
; ---------------------------------------------------------------------
sr_irq
.(
        lda sr_st
        and #2
        bne go
        rts
go      lda sr_rxn              ; réception : sr_rxn octets au plus
        sta sr_cnt
rx      lda sr_pfx              ; une touche n'est lue que si le tampon
        cmp #$FE                ; du clavier a de la place (sinon elle
        bne rx1                 ; attend dans le LOCI)
        ldx kb_head
        inx
        txa
        and #KB_MASK
        cmp kb_tail
        beq tx
rx1     ldx #1                  ; premier octet : sans attendre ; les
        lda sr_cnt              ; suivants : sr_rxw (un vrai 6551 n'en
        cmp sr_rxn              ; présente qu'un à la fois)
        beq rx2
        ldx sr_rxw
rx2     jsr sr_rsta
        and #$08
        bne rx3
        dex
        bne rx2
        beq tx
rx3     jsr sr_rdat
        jsr sr_rx
        dec sr_cnt
        bne rx
tx      lda sr_req              ; émission de la trame en cours
        beq r
        lda sr_txn
        sta sr_cnt
        lda sr_bdg
        sta sr_bud
t1      jsr sr_rsta
        and #$10
        bne t3
        dec sr_bud
        bne t1
        inc sr_wt               ; émetteur occupé : la suite à l'IRQ
        lda sr_wt               ; suivante ; 5 s sans rien : réponse
        cmp #250                ; abandonnée, liaison perdue (voyant r)
        bcc r
        lda #0
        sta sr_req
        lda #6
        sta sr_st
        jmp draw_flags
t3      jsr sr_next
        jsr sr_wdat
        lda #0
        sta sr_wt
        lda sr_req
        beq r
        dec sr_cnt
        bne t1
r       rts
.)

; sr_rx : octet A reçu du Mac
sr_rx
.(
        ldx sr_pfx
        beq p0
        ldy #0
        sty sr_pfx
        cpx #$FE
        beq key
        cpx #$FD
        beq cmd
        pha                     ; "L" n ; n + $80 : les lignes n à 27
        and #$7F                ;   à la suite, une trame chacune
        cmp #28
        pla
        bcs r
        sta sr_n
        lda #"L"
req     sta sr_req              ; nouvelle demande (remplace la précédente)
        sty sr_i                ; (Y = 0)
        sty sr_wt
        lda #2                  ; liaison retrouvée
        sta sr_st
        jmp draw_flags
p0      cmp #$FD
        beq pfx
        cmp #$FE
        bne r
pfx     sta sr_pfx
r       rts
key     jmp kb_push             ; touche (place vérifiée par sr_irq)
cmd     cmp #"S"
        beq req
        cmp #"L"
        beq pfx
        cmp #"B"                ; démarrage à chaud
        bne r
        jmp wboot
.)

; sr_next : octet suivant de la trame -> A (sr_req = 0 après le dernier)
sr_next
.(
        ldx sr_i
        inc sr_i
        lda #$FF                ; début de trame (hors du total)
        dex
        bpl n1
        inx
        stx sr_sum
        rts
n1      lda sr_req
        dex
        bmi add                 ; type
        ldy #60                 ; longueur : S 60, L 41
        cmp #"S"
        beq n2
        ldy #41
n2      sty sr_len
        tya
        dex
        bmi add
        cpx sr_len              ; X = n° de l'octet de données
        beq sum
        cmp #60
        beq s
        dex                     ; trame L : n, puis les 40 octets
        bpl l1
        lda sr_n
        and #$7F
        tax
        jsr sr_line
        txa
        bpl add
l1      txa
        tay
        jsr sr_byte
        jmp add
sum     lda sr_req                ; fin de trame ; L n+$80 : ligne suivante
        cmp #"L"
        bne end
        lda sr_n
        bpl end
        cmp #$80+27
        bcs end
        inc sr_n
        lda #0
        sta sr_i
        beq sm
end     lda #0
        sta sr_req
sm      lda sr_sum
        rts
add     pha
        clc
        adc sr_sum
        sta sr_sum
        pla
        rts
s       dex                     ; trame S : mode, curseur, 28 totaux
        bpl s1
        ldy vmode               ; mode : 0 texte, 1 SPLIT, 2 HIRES plein ;
        bne m1                  ; bit 7 : écran texte au programme
        lda SCREEN+LAST_ROW*40+COLS-1
        cmp #ATTR_HIRES
        bne m1
        ldy #2
m1      lda scr_prog
        beq m2
        tya
        ora #$80
        tay
m2      tya
        jmp add
s1      cpx #3
        bcs tot
        cpx #2                  ; colonne, ligne ($0210, $0211), curseur
        bne s2                  ; actif ($0213)
        inx
s2      lda cur_x,x
        jmp add
tot     txa                     ; (C=1) ligne (X-3)/2 ; impair : s2
        sbc #3
        lsr
        bcs t2
        tax
        jsr sr_fl
        lda sr_s1
        bcc add                 ; (C=0)
t2      lda sr_s2
        bcs add
.)

; sr_fl : totaux de Fletcher de la ligne X -> sr_s1, sr_s2 (C=0)
sr_fl
.(
        jsr sr_line
        lda #0
        sta sr_s1
        sta sr_s2
        tay
l       jsr sr_byte
        clc
        adc sr_s1
        sta sr_s1
        clc
        adc sr_s2
        sta sr_s2
        iny
        cpy #40
        bne l
        clc
        rts
.)

; sr_line : la ligne X de l'écran sera lue par sr_byte
sr_line
        stx sr_l
        lda line_lo,x
        sta sr_lda+1
        lda line_hi,x
        sta sr_lda+2
        rts

; sr_byte : octet Y de la ligne -> A, case du curseur rétablie (garde Y)
sr_byte
.(
        jsr sr_lda
        ldx cur_vis
        beq r
        cpy cur_x
        bne r
        ldx sr_l
        cpx cur_y
        bne r
        eor #$80
r       rts
.)
sr_lda  lda SCREEN,y
        rts

; registres de l'ACIA : LDA / STA absolus, octet bas posé par sr_call
sr_rsta lda $0381
        rts
sr_rdat lda $0380
        rts
sr_wdat sta $0380
        rts

; ---------------------------------------------------------------------
; Fonction 117 du BDOS : bloc [op, p1..p5]
;   0 état -> A : bit 0 port posé, bit 1 console active, bit 2 liaison
;     perdue ; X = octet bas du port (0 : aucun)
;   1 pose le port : p1 = octet bas ($80 LOCI, $1C Oricutron ; 0 : aucun,
;     console coupée)
;   2 console à distance active ($FF sans port) ; 3 coupée
; ---------------------------------------------------------------------
sr_call
.(
        ldy #0
        lda (ZP_PTR),y          ; op
        beq stat
        cmp #4
        bcs bad
        sei
        sty sr_pfx
        sty sr_req
        lsr                     ; 1 -> 0 ; 2 -> 1, C=0 ; 3 -> 1, C=1
        bne o23
        iny
        lda (ZP_PTR),y          ; p1
        ldx #3                  ; plafonds : 6551, ou LOCI ($80)
        cmp #$80
        bne pa
        ldx #7
pa      ldy #3
pl      lda sr_par,x
        sta sr_rxn,y
        dex
        dey
        bpl pl
        ldy #1
        lda (ZP_PTR),y
        sta sr_port
        sta sr_rdat+1
        sta sr_wdat+1
        tax
        inx
        stx sr_rsta+1
        tay
        bne ok
        beq st                  ; aucun port : console coupée
o23     bcs st                  ; 3 : coupée (Y = 0)
        lda sr_port
        beq bad
        ldy #2
st      sty sr_st
        jsr draw_flags
ok      cli
        lda #0
        rts
stat    ldx sr_port
        beq s0
        lda #1
s0      ora sr_st
        rts
bad     cli
        lda #$FF
        rts
.)

; ---------------------------------------------------------------------
; PUNCH ($C012, fonction 4 du BDOS) : envoie A au port ; attend
;   l'émetteur libre 5 s au plus (compteur 50 Hz : interruptions
;   permises). A = 0 et C=0 : parti ; A = $FF et C=1 : pas parti, ou
;   aucun port posé.
; ---------------------------------------------------------------------
bios_punch
.(
        ldx sr_port
        beq no
        tay
        lda ticks
        sta sr_t0
w       jsr sr_rsta
        and #$10
        bne ok
        lda ticks
        sec
        sbc sr_t0
        cmp #250
        bcc w
no      lda #$FF
        sec
        rts
ok      tya
        jsr sr_wdat
        lda #0
        clc
        rts
.)

; ---------------------------------------------------------------------
; READER ($C015, fonction 3 du BDOS) : attend un octet du port -> A ;
;   $1A (^Z) tout de suite si aucun port n'est posé ou si la console à
;   distance est active (le flux est à elle), et dès qu'une touche est
;   tapée sur l'Oric (elle reste dans le tampon).
; ---------------------------------------------------------------------
bios_reader
.(
        lda sr_port
        beq eof
        lda sr_st
        and #2
        bne eof
w       jsr const
        bne eof
        jsr sr_rsta
        and #$08
        beq w
        jmp sr_rdat
eof     lda #$1A
        rts
.)

; plafonds par IRQ : sr_rxn, sr_rxw, sr_txn, sr_bdg (6551, puis LOCI)
sr_par  .byt 4, 48, 24, 200
        .byt 16, 8, 64, 250

; voyant de la console à distance (draw_flags, colonne 36)
sr_flg  .asc " R r"
