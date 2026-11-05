; =====================================================================
;  REMOTE.COM — console à distance : le Mac tape et lit à la place du
;  clavier et de l'écran (démon tools/remote.py, docs/console-distance.md)
;
;  REMOTE hote    compose (nom du fichier HOSTS, adresse IP ou nom DNS ;
;                 :port facultatif, 2324 par défaut) et active la console
;  REMOTE /N      active sans composer (liaison ouverte par TERM)
;  REMOTE OFF     coupe la console (et un rappel en cours), puis raccroche
;                 (+++, ATH0)
;  REMOTE         état
;
;  Le service tourne dans le BIOS, sous l'IRQ (src/serial.s) : REMOTE ne
;  fait que trouver et régler l'ACIA (acia_inc.s), composer, poser le
;  port et lever le drapeau par la fonction 117 du BDOS. La console
;  survit aux programmes et au démarrage à chaud ; un démarrage à froid
;  l'éteint. AUTO.BAT peut contenir « REMOTE hote ».
;  Après « REMOTE hote », le numéro composé est confié au pilote (op 4) :
;  si le démon se tait 10 s, le pilote raccroche et rappelle de lui-même,
;  toutes les 30 s jusqu'à ce qu'il réponde (pas après REMOTE /N).
; =====================================================================

#include "cpa.inc"

        *= $0500
start
.(
        lda #SE_STATE           ; pilote série présent ?
        sta ac_blk
        jsr ac_ser
        cmp #$FF
        bne s0
        lda #<m_nodrv
        ldy #>m_nodrv
        jmp puts
s0      ldx #0                  ; premier mot
        jsr skipsp
        lda TAIL+1,x
        bne s1
        jmp state               ; REMOTE seul : état
s1      cmp #"/"
        bne s2
        lda TAIL+2,x
        and #$DF
        cmp #"N"
        bne usage
        jsr port                ; /N : la liaison est déjà ouverte
        jsr ac_rcmd             ; ACIA réglée seulement s'il le faut
        cmp #$0B
        bne n1
        jsr ac_rctl
        cmp #$1E
        beq on
n1      jsr ac_setup
        jmp on
s2      ldy #0                  ; OFF ?
o1      lda TAIL+1,x
        and #$DF
        cmp w_off,y
        bne host2
        inx
        iny
        cpy #3
        bne o1
        lda TAIL+1,x
        jsr ac_end
        bne host2
        lda #SE_OFF             ; OFF : console coupée, puis raccroche
        jsr ser
        lda #<m_off
        ldy #>m_off
        jsr puts
        jsr ac_find
        jsr ac_hang
        rts
usage   lda #<m_use
        ldy #>m_use
        jmp puts
host2   ldx #0
host    jsr skipsp              ; X : début du nom
        stx hx
        lda #SE_OFF             ; la console rend l'ACIA pendant l'appel
        jsr ser
        jsr port
        jsr ac_setup
        ldx hx
        lda #<p2324
        ldy #>p2324
        jsr ac_dial
        bcs hr
        inc hn                  ; numéro à confier au pilote
        bne on
hr      rts
on      lda #SE_PORT            ; pose le port, active la console
        sta ac_blk
        lda ac_rdat+1
        sta ac_blk+1
        jsr ac_ser
        lda #SE_ON
        jsr ser
        lda hn
        beq o2
        jsr setnum
o2      lda #<m_on
        ldy #>m_on
        jmp puts
.)

; setnum : le numéro composé par ac_dial (« ATDT », signe de mode sauf
;   dans Oricutron, adresse:port, CR) confié au pilote (fonction 117,
;   op 4) ; trop long : « pas de rappel » affiché
setnum
.(
        ldx #0
a1      lda ac_satd,x           ; ATDT
        beq a2
        sta r_num,x
        inx
        bne a1
a2      ldy #0
        lda ac_wrk+AC_ADR
        cmp #"+"
        beq a3
        cmp #"="
        beq a3
        lda #"-"
        dey                     ; pas de signe à sauter
a3      iny
        sty hx
        ldy ac_rdat+1
        cpy #$1C                ; Oricutron : sans signe de mode
        beq a4
        sta r_num,x
        inx
a4      ldy hx
a5      lda ac_wrk+AC_ADR,y
        beq a6
        sta r_num,x
        inx
        iny
        bne a5
a6      lda #":"
        ldy #0
a7      sta r_num,x
        inx
        lda ac_wrk+AC_PRT,y
        iny
        cmp #0
        bne a7
        lda #13
        sta r_num,x
        lda #0
        sta r_num+1,x
        lda #<nblk
        ldy #>nblk
        ldx #F_SERIAL
        jsr BDOS
        cmp #$FF
        bne r
        lda #<m_norap
        ldy #>m_norap
        jmp puts
r       rts
.)

; state : « Console a distance : ... », puis le port
state
.(
        lda #<m_st
        ldy #>m_st
        jsr puts
        lda #SE_STATE
        jsr ser                 ; A = état, X = port
        stx hx
        lda ac_blk              ; (état rangé par ser)
        and #4
        beq a1
        lda #<m_lost
        ldy #>m_lost
        jmp a3
a1      lda ac_blk
        and #2
        beq a2
        lda #<m_act
        ldy #>m_act
        jmp a3
a2      lda #<m_cut
        ldy #>m_cut
a3      jsr puts
        lda #<m_port
        ldy #>m_port
        jsr puts
        lda hx
        beq p0
        cmp #$80
        bne p1
        lda #<m_ploci
        ldy #>m_ploci
        jmp puts
p1      lda #<m_poric
        ldy #>m_poric
        jmp puts
p0      lda #<m_pnone
        ldy #>m_pnone
        jmp puts
.)

; port : cherche l'ACIA et dit laquelle
port
.(
        jsr ac_find
        lda #<m_loci
        ldy #>m_loci
        bcc p
        lda #<m_oric
        ldy #>m_oric
p       jmp puts
.)

; ser : fonction 117, op A (p1 = 0) ; l'état rendu est rangé dans ac_blk
ser
        sta ac_blk
        lda #0
        sta ac_blk+1
        jsr ac_ser
        sta ac_blk
        rts

; skipsp : X sur le premier caractère non blanc de TAIL+1
skipsp
.(
l       lda TAIL+1,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)

; puts : affiche la chaîne A/Y terminée par « $ »
puts
        ldx #F_PRINT
        jmp BDOS

hx      .byt 0                  ; début de l'hôte ; port lu par l'état
hn      .byt 0                  ; 1 : numéro composé, à confier au pilote
nblk    .byt SE_NUM, <r_num, >r_num
w_off   .asc "OFF"
p2324   .asc "2324",0           ; port par défaut du démon

#include "acia.msg"
#include "acia_inc.s"
#include "remote.msg"

endp                            ; hors du fichier
ac_wrk  = endp                  ; 266 octets : HOSTS, réponses du modem
r_num   = endp+266              ; numéro confié au pilote (64 octets)
