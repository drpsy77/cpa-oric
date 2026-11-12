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
;  (totaux), $FD "L" n (ligne n), $FD "C" n (totaux des lignes n à n+7),
;  $FD "B" (démarrage à chaud) ; tout autre octet est ignoré (messages
;  du modem). Lignes 0-27 : l'écran ($BB80) ; 28-75 : la police du mode
;  texte, 40 octets chacune à partir de $B400 (caractères redéfinis).
;  Oric -> Mac :
;      $FF type longueur données total
;  (total : somme sur 8 bits de type, longueur et données) ;
;  "S" : mode, colonne et ligne du curseur, curseur actif, puis les 28
;  totaux de Fletcher (s1, puis s2) des lignes de l'écran ; "L" : n, puis
;  les 40 octets de la ligne ; "C" : les totaux des 8 lignes demandées.
;  La case du curseur est lue rétablie.
;
;  Variables : sr_port... (hw.inc, $FD13-$FD1F), effacées au démarrage à
;  froid seulement : le pilote survit au démarrage à chaud.
; =====================================================================

SER_FUNC = 117
SR_FLMAX = 6            ; totaux de lignes par IRQ au plus (~1 100 cycles
                        ; chacun) : l'IRQ reste loin d'une trame (VSYNC,
                        ; animations décodées juste après le top)
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
go      lda sr_rp               ; rappel en cours : lui seul
        beq si
        jmp sr_rap
si      lda sr_num              ; silence : plus rien reçu depuis 512 IRQ
        beq go2                 ; (10 s ; le démon demande l'état deux
        inc sr_si               ; fois par seconde) : la ligne est morte,
        bne go2                 ; rappel (seulement si REMOTE a composé)
        inc sr_sh
        lda sr_sh
        cmp #2
        bcc go2
        lda #0
        sta sr_req
        sta sr_rp               ; étape 1
        lda #6                  ; voyant r
        sta sr_st
        jsr draw_flags
        jmp sr_nxt
go2     lda sr_rxn              ; réception : sr_rxn octets au plus
        sta sr_cnt
rx      lda sr_pfx              ; une touche n'est lue que si le tampon
        cmp #$FE                ; du clavier a de la place (sinon elle
        bne rx1                 ; attend dans le LOCI)
        ldx kb_head
        inx
        txa
        and #KB_MASK
        cmp kb_tail
        beq kf
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
        ldy #0                  ; un octet reçu : la ligne vit
        sty sr_si
        sty sr_sh
        jsr sr_rx
        dec sr_cnt
        bne rx
        beq tx
kf      ldy #0                  ; une touche attend (tampon du clavier
        sty sr_si               ; plein) : la ligne vit aussi
        sty sr_sh
tx      lda sr_req              ; émission de la trame en cours
        beq r
        lda sr_txn
        sta sr_cnt
        lda sr_bdg
        sta sr_bud
        lda #SR_FLMAX           ; totaux de lignes permis dans l'IRQ
        sta sr_flc
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
        lda sr_flc              ; plafond des totaux atteint : la suite
        beq r                   ; à l'IRQ suivante
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
        pha                     ; "L" n, "C" n ; L n + $80 : les lignes
        and #$7F                ;   n à 27 (n à 75 dans la police) à la
        cmp #76                 ;   suite, une trame chacune
        pla
        bcs r
        sta sr_n
        txa                     ; "L" ou "C"
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
        cmp #"C"
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
        ldy #60                 ; longueur : S 60, C 16, L 41
        cmp #"S"
        beq n2
        ldy #16
        cmp #"C"
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
        cmp #16
        beq c
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
        beq end
        cmp #$80+75
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
m2      tya                     ; bit 6 : touche tapée sur l'Oric depuis
        ora sr_kb               ; la trame S précédente
        ldy #0
        sty sr_kb
        jmp add
s1      cpx #3
        bcs tot
        cpx #2                  ; colonne, ligne ($0210, $0211), curseur
        bne s2                  ; actif ($0213)
        inx
s2      lda cur_x,x
        jmp add
c       txa                     ; trame C : ligne n + X/2 ; impair : s2
        clc
        adc sr_n
        adc sr_n
        bcc t0                  ; (toujours)
tot     txa                     ; (C=1) ligne (X-3)/2 ; impair : s2
        sbc #3
t0      lsr
        bcs t2
        tax
        jsr sr_fl
        lda sr_s1
        bcc add                 ; (C=0)
t2      lda sr_s2
        bcs add
.)

; sr_fl : totaux de Fletcher de la ligne X -> sr_s1, sr_s2 (C=0) ; un de
;   moins permis dans l'IRQ (sr_flc). La ligne est lue directement (~27
;   cycles par octet, 1 100 par ligne), puis la case du curseur, lue
;   inversée, est rétablie dans les totaux : s1 + $80, et s2 + $80 si elle
;   y compte un nombre impair de fois (40 - x : x impair).
sr_fl
.(
        dec sr_flc
        jsr sr_line
        lda sr_lda+1
        sta ld+1
        lda sr_lda+2
        sta ld+2
        lda #0
        sta sr_s2
        tay                     ; A = s1
l       clc
ld      adc SCREEN,y
        tax
        clc
        adc sr_s2
        sta sr_s2
        txa
        iny
        cpy #40
        bne l
        ldx cur_vis
        beq e
        ldx sr_l
        cpx cur_y
        bne e
        eor #$80
        tax
        lda cur_x
        lsr
        bcc e1
        lda sr_s2
        eor #$80
        sta sr_s2
e1      txa
e       sta sr_s1
        clc
        rts
.)

; sr_line : la ligne X sera lue par sr_byte (garde X) : 0-27 l'écran,
;   28-75 la police ($B400 + 40 * (X - 28))
sr_line
.(
        stx sr_l
        cpx #28
        bcs p
        lda line_lo,x
        sta sr_lda+1
        lda line_hi,x
        sta sr_lda+2
        rts
p       lda #<$B400
        sta sr_lda+1
        lda #>$B400
        sta sr_lda+2
        txa
        sbc #28                 ; (C=1)
        tay
        beq r
l       clc
        lda sr_lda+1
        adc #40
        sta sr_lda+1
        bcc n
        inc sr_lda+2
n       dey
        bne l
r       rts
.)

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

; ---------------------------------------------------------------------
; Rappel automatique : la console est active, REMOTE a composé (sr_num),
;   et le démon ne demande plus rien depuis 10 s (relancé, liaison
;   tombée, WiFi perdu) : sous l'IRQ, une étape à la fois (sr_rp, voyant
;   r), sans jamais bloquer l'Oric :
;     1 une seconde de silence      5 une seconde (réponses jetées)
;     2 +++                         6 le numéro (« ATDT-hôte:port », CR)
;     3 une seconde de silence      7 CONNECT attendu 20 s
;     4 CR, ATH0, CR (raccroche)    8 30 s, puis l'étape 1
;   CONNECT : la console reprend (voyant R), le démon redemande l'écran.
;   REMOTE OFF (fonction 117, op 3) arrête tout.
; ---------------------------------------------------------------------
sr_rap
.(
        ldx #8                  ; reçu : jeté, sauf le CONNECT attendu
rx      jsr sr_rsta             ; (étape 7)
        and #$08
        beq tx
        jsr sr_rdat
        ldy sr_rp
        cpy #7
        bne rx1
        and #$7F
        ldy sr_mi
        cmp sr_conn,y
        beq m1
        ldy #0
        cmp #"C"
        bne m0
m1      iny
m0      sty sr_mi
        cpy #4
        beq ok
rx1     dex
        bne rx
tx      ldx sr_rp               ; étape d'envoi : un octet par IRQ
        lda sr_shi-1,x
        beq wt
        sta sr_s+2
        lda sr_slo-1,x
        sta sr_s+1
        jsr sr_rsta
        and #$10
        beq r
        ldy sr_mi
        jsr sr_s
        beq nx
        jsr sr_wdat
        inc sr_mi
        ldy sr_mi               ; dernier octet parti : étape suivante
        jsr sr_s                ; tout de suite (sinon la réception de
        beq nx                  ; l'IRQ suivante jetterait le CONNECT)
r       rts
wt      lda sr_tml              ; attente : délai (mot) décompté
        bne d
        lda sr_tmh
        beq nx
        dec sr_tmh
d       dec sr_tml
        rts
nx      jmp sr_nxt
ok      lda #0                  ; CONNECT : la console reprend
        sta sr_rp
        sta sr_si
        sta sr_sh
        sta sr_pfx
        sta sr_req
        lda #2
        sta sr_st
        jmp draw_flags
.)
sr_s    lda $FFFF,y             ; octet Y de la chaîne de l'étape
        rts

; sr_nxt : étape suivante du rappel (après la 8 : la 1), délai et
;   position remis
sr_nxt
.(
        ldx sr_rp
        cpx #8
        bne n
        ldx #0
n       inx
        stx sr_rp
        lda sr_dlo-1,x
        sta sr_tml
        lda sr_dhi-1,x
        sta sr_tmh
        lda #0
        sta sr_mi
        rts
.)

; étapes 1 à 8 : délai en IRQ (attentes), chaîne envoyée (envois)
sr_dlo  .byt 50, 0, 50, 0, 50, 0, <1000, <1500
sr_dhi  .byt 0, 0, 0, 0, 0, 0, >1000, >1500
sr_slo  .byt 0, <sr_cpl, 0, <sr_cath, 0, <sr_num, 0, 0
sr_shi  .byt 0, >sr_cpl, 0, >sr_cath, 0, >sr_num, 0, 0
sr_cpl  .asc "+++", 0
sr_cath .byt 13
        .asc "ATH0"
        .byt 13, 0
sr_conn .asc "CONN"

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
;   4 numéro à rappeler (p1, p2 : adresse d'une chaîne terminée par 0,
;     40 caractères au plus : « ATDT-hôte:port », CR) : $FF s'il est trop
;     long (pas de rappel) ; les op 1 à 3 l'effacent et arrêtent un rappel
; ---------------------------------------------------------------------
sr_call
.(
        ldy #0
        lda (ZP_PTR),y          ; op
        beq stat
        cmp #4
        beq num
        bcs bad
        sei
        sty sr_pfx
        sty sr_req
        sty sr_rp
        sty sr_num
        sty sr_si
        sty sr_sh
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
num     iny                     ; op 4 : chaîne p1/p2 copiée dans sr_num
        lda (ZP_PTR),y
        sta nl+1
        iny
        lda (ZP_PTR),y
        sta nl+2
        ldy #0
        sei
nl      lda $FFFF,y
        sta sr_num,y
        beq ok
        iny
        cpy #SR_NUML
        bne nl
        lda #0                  ; trop long : pas de rappel
        sta sr_num
        beq bad
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
