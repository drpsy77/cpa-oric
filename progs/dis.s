; =====================================================================
;  DIS.COM — désassembleur : un fichier de code machine devient un
;  source qu'ASM réassemble en un fichier identique
;
;  DIS NOM [adr] [/E adr ...]
;    NOM     type .BIN par défaut, lecteur facultatif ; NOM.ASM est
;            écrit sur le même lecteur (remplacé s'il existe)
;    adr     adresse de chargement, en hexadécimal ($0500 par défaut)
;    /E      points d'entrée en plus (8 au plus ; hors du fichier :
;            ignorés)
;
;  1. Suivi : en partant des points d'entrée (le début du fichier, ceux
;     de /E, les vecteurs $FFFA-$FFFF si le fichier les contient), DIS
;     suit les instructions, les sauts, les appels et les deux suites
;     de chaque branchement ; un saut indirect, RTS, RTI, BRK, un code
;     non documenté ou la fin du fichier arrêtent la suite. Ce qui est
;     atteint est du code, le reste des données.
;  2. Une instruction dans laquelle commence une autre (code qui se
;     chevauche, « BIT » qui saute un octet) est écrite en .byt.
;  3. Étiquettes Lxxxx : cibles des sauts, des branchements et des
;     adresses absolues qui tombent dans le fichier, points d'entrée de
;     /E ; une adresse dans une instruction s'écrit Lxxxx+1 ou +2 (code
;     modifié par lui-même).
;  4. Les adresses connues prennent le nom donné par ATMOS.SYM (ROM
;     1.1, VIA ; cherché sur le lecteur du fichier, puis en A:) : comme
;     étiquette dans le fichier, déclaré en tête du source ailleurs ;
;     pas pour un .COM de CP/A (la ROM y est cachée).
;  5. Écriture : les données en .byt, en .asc (au moins 4 caractères
;     imprimables), en .dsb (au moins 8 octets égaux). Une instruction
;     absolue dont l'adresse tient sur un octet (ASM choisirait la page
;     zéro) est écrite en .byt, l'instruction en commentaire.
;
;  Mémoire : 3 bits par octet du fichier (début d'instruction, intérieur
;  d'une instruction, étiquette ; le deuxième sert aussi de liste « à
;  suivre » pendant le suivi), puis un cache d'enregistrements de 128
;  octets (lus par la fonction 33, lecture directe), en puissance de 2.
;  Le fichier n'a pas à tenir en mémoire. Format : docs/oric-basic.md
;  § 5.2. Tables d'instructions : asm_tab.s et dis_inc.s (celles de
;  DEBUG).
; =====================================================================

#include "cpa.inc"

NENT    = 8             ; points d'entrée de /E
NBYT    = 6             ; octets par ligne .byt
NASC    = 20            ; caractères par ligne .asc
SYMMAX  = 64            ; enregistrements d'ATMOS.SYM lus au plus (8 Ko)

; page zéro
sp      = $10           ; 2 octets : chaîne (puts, wstr)
val     = $12           ; 2 octets : adresse cherchée (inf, symf)
ptr     = $14           ; 2 octets (dis_init, zinit, symboles)
tmpb    = $16           ; (dis_init, decode)
pb      = $17           ; (phex)
org     = $18           ; 2 octets : adresse de chargement
last    = $1A           ; 2 octets : dernière adresse du fichier
flen    = $1C           ; 2 octets : longueur du fichier
nb      = $1E           ; 2 octets : taille d'une carte de bits
maps    = $20           ; 6 octets : cartes S, I, L
mapS    = maps          ;   débuts d'instruction
mapI    = maps+2        ;   intérieurs (pendant le suivi : à suivre)
mapL    = maps+4        ;   étiquettes
bo      = $26           ; 2 octets : position dans le fichier
bq      = $28           ; 2 octets : bo / 8
bm      = $2A           ; masque du bit de bo
bp      = $2B           ; 2 octets : octet de la carte
pc      = $2D           ; 2 octets : instruction décodée (decode)
op      = $2F           ; son code
kind    = $30           ; son mode ($FF : inconnu, ou ne tient pas)
ilen    = $31           ; sa longueur
opv     = $32           ; 2 octets : opérande (cible d'un branchement)
asbyt   = $34           ; $80 : instruction écrite en .byt
ra      = $35           ; 2 octets : adresse lue (rdb)
t0      = $37           ; 2 octets (rdb)
rlo     = $39           ; enregistrement (rdb)
rhi     = $3A
cache   = $3B           ; 2 octets : cache des enregistrements
cmask   = $3D           ; nombre d'emplacements - 1
rp      = $3E           ; 2 octets : emplacement (rdb)
gx      = $40           ; X et Y gardés (rdb)
gy      = $41
symlo   = $42           ; 2 octets : table des noms
symp    = $44           ; 2 octets : nom trouvé (symf)
opos    = $46           ; position dans obuf
ox      = $47           ; X gardé (putb)
fp      = $48           ; 2 octets : FCB (pname, pfull)
sp0     = $4A           ; pile au départ
nent    = $4B           ; points d'entrée de /E
found   = $4C           ; $80 : le balayage a suivi quelque chose
cnt     = $4D
dg      = $4E           ; (ndec, gethex)
nrec    = $4F           ; 2 octets : enregistrements du fichier
si      = $51           ; 2 octets : balayage de la liste à suivre
bsav    = $53           ; 2 octets : bo gardé
symmin  = $55           ; 2 octets : plus petite valeur de la table
noat    = $57           ; $80 : pas d'ATMOS.SYM (.COM)
plain   = $58           ; $80 : opérande en hexa (commentaire d'un .byt)
nlin    = $59           ; octets sur la ligne .byt
raw     = $5A           ; 2 octets : octets de l'opérande, tels quels
rc      = $5C           ; longueur d'une suite (same, prt)
ch      = $5D           ; (putc)
cont    = $5E           ; $80 : la ligne .asc précédente était pleine
emode   = $5F           ; entries : 0 à suivre, $80 étiquettes

        *= $0500
start
.(
        tsx
        stx sp0
        lda #0
        sta nent
        sta noat
        lda #<$0500
        sta org
        lda #>$0500
        sta org+1
        ldx #1
        jsr skipsp
        lda TAIL,x
        bne s1
usage   lda #<m_use
        ldy #>m_use
        jmp fail
s1      lda #<ifcb
        sta fp
        lda #>ifcb
        sta fp+1
        jsr pname
        bcc s2
        lda #<m_name
        ldy #>m_name
        jmp fail
s2      lda ifcb+9              ; type .BIN par défaut
        cmp #" "
        bne s3
        ldy #2
t1      lda t_bin,y
        sta ifcb+9,y
        dey
        bpl t1
s3      ldy #2                  ; .COM : pas de noms de la ROM
c1      lda ifcb+9,y
        cmp t_com,y
        bne c2
        dey
        bpl c1
        lda #$80
        sta noat
c2      ldy #2                  ; .ASM : refusé (ce serait la sortie)
a1      lda ifcb+9,y
        cmp t_asm,y
        bne opt
        dey
        bpl a1
        lda #<m_isasm
        ldy #>m_isasm
        jmp fail
opt     jsr skipsp              ; adresse, /E adr ...
        lda TAIL,x
        beq go
        cmp #"/"
        beq o1
        jsr gethex
        bcs usage
        lda val
        sta org
        lda val+1
        sta org+1
        jmp opt
o1      lda TAIL+1,x
        and #$DF
        cmp #"E"
        bne usage
        inx
        inx
o2      jsr skipsp
        lda TAIL,x
        beq go
        cmp #"/"
        beq opt
        jsr gethex
        bcs us2
        ldy nent
        cpy #NENT
        bcs us2
        lda val
        sta entl,y
        lda val+1
        sta enth,y
        inc nent
        jmp o2
go      jmp main
us2     jmp usage
.)

fail    jsr puts
quit    ldx sp0
        txs
        rts

t_bin   .asc "BIN"
t_com   .asc "COM"
t_asm   .asc "ASM"
t_sym   .asc "ATMOS   SYM"

; ---------------------------------------------------------------------
main
.(
        ldy #8                  ; NOM.ASM : même lecteur, même nom
n1      lda ifcb,y
        sta ofcb,y
        dey
        bpl n1
        lda #<ifcb
        ldy #>ifcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne o3
        lda #<ifcb
        ldy #>ifcb
        jsr pfull
        lda #<m_abs
        ldy #>m_abs
        jmp fail
o3      lda #<ifcb              ; taille : 1 à 511 enregistrements
        ldy #>ifcb
        ldx #F_FSIZE
        jsr BDOS
        lda ifcb+FCB_R0+2
        bne big
        lda ifcb+FCB_R0+1
        cmp #2
        bcs big
        sta nrec+1
        lda ifcb+FCB_R0
        sta nrec
        ora nrec+1
        bne o4
        lda #<m_empty
        ldy #>m_empty
        jmp fail
big     lda #<m_big
        ldy #>m_big
        jmp fail
o4      lda nrec+1              ; flen = nrec x 128
        lsr
        lda nrec
        ror
        sta flen+1
        lda #0
        ror
        sta flen
        clc                     ; last = org + flen - 1, sans dépasser $FFFF
        lda org
        adc flen
        sta last
        lda org+1
        adc flen+1
        sta last+1
        bcc l1
        ora last
        bne big
l1      lda last
        bne l2
        dec last+1
l2      dec last
        lda nrec                ; nb = nrec x 16
        sta nb
        lda nrec+1
        sta nb+1
        ldy #4
n2      asl nb
        rol nb+1
        dey
        bne n2
        lda #<ifcb              ; « B:JEU.BIN 9800-9FFF »
        ldy #>ifcb
        jsr pfull
        lda #" "
        jsr putc
        lda org+1
        jsr phex
        lda org
        jsr phex
        lda #"-"
        jsr putc
        lda last+1
        jsr phex
        lda last
        jsr phex
        jsr crlf
        jsr dis_init
        jsr zinit
        jsr loadsym
        jsr setmem
        lda #0
        sta emode
        jsr entries
        jsr sweep
        jsr cover
        jsr labels
        jsr emit
        lda #<ofcb
        ldy #>ofcb
        jsr pfull
        lda #<m_done
        ldy #>m_done
        jmp puts
.)

; ---------------------------------------------------------------------
; zinit : zpalt[code] = 1 pour une instruction absolue (ABS, ABX, ABY)
;   qui a une forme page zéro (ZP, ZPX, ZPY) : ASM choisirait celle-ci
;   pour une adresse sur un octet
zinit
.(
        ldx #0
        txa
c       sta zpalt,x
        inx
        bne c
        lda #<mn_ops
        sta ptr
        lda #>mn_ops
        sta ptr+1
        lda #NMNEM
        sta cnt
r       ldy #M_ZP
m       lda (ptr),y
        cmp #$FF
        beq n
        sty tmpb
        tya
        clc
        adc #M_ABS-M_ZP
        tay
        lda (ptr),y
        ldy tmpb
        cmp #$FF
        beq n
        tax
        lda #1
        sta zpalt,x
n       iny
        cpy #M_ZPY+1
        bne m
        clc
        lda ptr
        adc #12
        sta ptr
        bcc d
        inc ptr+1
d       dec cnt
        bne r
        rts
.)

; ---------------------------------------------------------------------
; loadsym : ATMOS.SYM en dyn (lecteur du fichier, puis A:) ; table vide
;   pour un .COM ou si elle est absente. symmin : plus petite valeur.
loadsym
.(
        lda #<dyn
        sta symlo
        sta ptr
        lda #>dyn
        sta symlo+1
        sta ptr+1
        lda #0
        tay
        sta (ptr),y
        bit noat
        bmi scan
        lda ifcb
        jsr trysym
        bcc scan
        lda #1
        jsr trysym
        bcc scan
        lda #<m_nosym
        ldy #>m_nosym
        jsr puts
scan    lda #$FF
        sta symmin
        sta symmin+1
        lda symlo
        sta ptr
        lda symlo+1
        sta ptr+1
l       ldy #0
        lda (ptr),y
        beq e
        ldy #1                  ; valeur < symmin ?
        lda (ptr),y
        cmp symmin
        iny
        lda (ptr),y
        sbc symmin+1
        bcs nx
        lda (ptr),y
        sta symmin+1
        dey
        lda (ptr),y
        sta symmin
nx      ldy #0
        lda (ptr),y
        clc
        adc #4
        adc ptr
        sta ptr
        bcc l
        inc ptr+1
        bne l
e       lda #0                  ; terminateur (lu, ou posé par trysym)
        sta (ptr),y
        rts
.)

; trysym : A = lecteur ; ATMOS.SYM lu en symlo (SYMMAX enregistrements au
;   plus, un 0 après) -> C=0 ; C=1 : absent
trysym
.(
        sta sfcb
        ldy #10
n       lda t_sym,y
        sta sfcb+1,y
        dey
        bpl n
        lda #0
        ldy #12
z       sta sfcb,y
        iny
        cpy #36
        bne z
        lda #<sfcb
        ldy #>sfcb
        ldx #F_OPEN
        jsr BDOS
        cmp #$FF
        bne o
        sec
        rts
o       lda #SYMMAX
        sta cnt
r       lda ptr
        ldy ptr+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<sfcb
        ldy #>sfcb
        ldx #F_READ
        jsr BDOS
        cmp #0
        bne e
        clc
        lda ptr
        adc #128
        sta ptr
        bcc d
        inc ptr+1
d       dec cnt
        bne r
e       lda #0
        tay
        sta (ptr),y
        clc
        rts
.)

; ---------------------------------------------------------------------
; setmem : cartes après la table (3 x nb octets, à zéro), puis le cache
;   jusqu'au haut de la TPA : 2^k emplacements de 128 octets (256 au plus)
setmem
.(
        sec                     ; ptr : terminateur de la table -> +1
        lda ptr
        adc #0
        sta mapS
        lda ptr+1
        adc #0
        sta mapS+1
        ldx #0
m       clc
        lda maps,x
        adc nb
        sta maps+2,x
        lda maps+1,x
        adc nb+1
        sta maps+3,x
        bcs nm1
        inx
        inx
        cpx #4
        bne m
        clc
        lda mapL                ; cache = mapL + nb
        adc nb
        sta cache
        lda mapL+1
        adc nb+1
        sta cache+1
nm1     bcs nomem
        sec                     ; place : TPA_TOP - cache
        lda TPA_TOP
        sbc cache
        sta t0
        lda TPA_TOP+1
        sbc cache+1
        sta t0+1
        bcc nomem
        lda t0                  ; emplacements : place / 128
        asl
        lda t0+1
        rol
        bcs all
        cmp #0
        beq nomem
        ldx #0                  ; plus grande puissance de 2
p1      lsr
        beq p2
        inx
        bne p1
p2      lda #0
p3      dex
        bmi p4
        sec
        rol
        bne p3
all     lda #$FF
p4      sta cmask
        lda mapS                ; cartes à zéro
        sta ptr
        lda mapS+1
        sta ptr+1
        lda nb                  ; t0 = 3 x nb
        asl
        sta t0
        lda nb+1
        rol
        sta t0+1
        clc
        lda t0
        adc nb
        sta t0
        lda t0+1
        adc nb+1
        sta t0+1
        ldy #0
z       lda t0
        ora t0+1
        beq tg
        tya
        sta (ptr),y
        inc ptr
        bne z1
        inc ptr+1
z1      lda t0
        bne z2
        dec t0+1
z2      dec t0
        jmp z
tg      ldx #0                  ; emplacements vides
t       lda #$FF
        sta tagh,x
        inx
        bne t
        rts
nomem   lda #<m_mem
        ldy #>m_mem
        jmp fail
.)

; ---------------------------------------------------------------------
; entries : début du fichier, /E, vecteurs $FFFA-$FFFF -> à suivre ;
;   avec emode = $80 : étiquettes sur /E et les vecteurs
entries
.(
        bit emode
        bmi e0
        lda org
        sta opv
        lda org+1
        sta opv+1
        jsr todo
e0      lda #0
        sta cnt
e       ldx cnt
        cpx nent
        beq v
        lda entl,x
        sta opv
        lda enth,x
        sta opv+1
        jsr eact
        inc cnt
        bne e
v       lda last                ; fichier jusqu'à $FFFF, depuis $FFFA au moins
        and last+1
        cmp #$FF
        bne r
        lda org+1
        cmp #$FF
        bne w
        lda org
        cmp #$FB
        bcs r
w       lda #$FA
        sta ra
        lda #$FF
        sta ra+1
v1      jsr rdb
        sta opv
        inc ra
        jsr rdb
        sta opv+1
        inc ra
        jsr eact
        lda ra
        bne v1
r       rts
.)

; eact : point d'entrée opv -> à suivre (emode = 0) ; étiquette ($80)
eact
.(
        bit emode
        bmi l
        jmp todo
l       lda opv
        sta val
        lda opv+1
        sta val+1
        jsr inf
        bcs r
        jmp ref
r       rts
.)

; todo : opv dans le fichier, pas encore suivi -> à suivre (carte I)
todo
.(
        lda opv
        sta val
        lda opv+1
        sta val+1
        jsr inf
        bcs r
        ldx #0
        jsr btst
        bne r
        ldx #2
        jmp bset
r       rts
.)

; sweep : suit tout ce qui est « à suivre », jusqu'à ce qu'un balayage
;   complet n'en trouve plus
sweep
.(
s0      lda #0
        sta found
        sta si
        sta si+1
s1      clc
        lda mapI
        adc si
        sta ptr
        lda mapI+1
        adc si+1
        sta ptr+1
        ldy #0
        lda (ptr),y
        beq s3
        ldx #0                  ; bit le plus bas
s2      lsr
        bcs s4
        inx
        bne s2
s4      stx tmpb
        lda si+1                ; bo = si x 8 + bit
        sta bo+1
        lda si
        asl
        rol bo+1
        asl
        rol bo+1
        asl
        rol bo+1
        ora tmpb
        sta bo
        ldx #2
        jsr bclr
        lda #$80
        sta found
        jsr trace
        jmp s1                  ; même octet : d'autres bits ?
s3      inc si
        bne s5
        inc si+1
s5      lda si
        cmp nb
        lda si+1
        sbc nb+1
        bcc s1
        bit found
        bmi s0
        rts
.)

; trace : suit les instructions depuis bo
trace
.(
        clc
        lda bo
        adc org
        sta pc
        lda bo+1
        adc org+1
        sta pc+1
l       lda pc
        sta val
        lda pc+1
        sta val+1
        jsr inf
        bcs r
        ldx #0
        jsr btst
        bne r                   ; déjà suivi
        jsr decode
        bit kind
        bmi r                   ; inconnu, ou ne tient pas
        ldx #0
        jsr bset
        lda op
        cmp #$4C                ; JMP adr
        bne t1
        jmp todo
t1      cmp #$6C                ; JMP (adr), RTS, RTI, BRK : fin
        beq r
        cmp #$60
        beq r
        cmp #$40
        beq r
        cmp #$00
        beq r
        cmp #$20                ; JSR
        beq call
        lda kind
        cmp #M_REL
        bne nx
        bit asbyt
        bmi nx
call    jsr todo
nx      clc
        lda pc
        adc ilen
        sta pc
        bcc l
        inc pc+1
        bne l
r       rts
.)

; ---------------------------------------------------------------------
; cover : une instruction dans laquelle commence une autre n'est plus un
;   début (écrite en .byt) ; sinon ses octets 2 et 3 sont « intérieurs »
cover
.(
        lda #0
        sta bo
        sta bo+1
l       jsr nexts
        bcs r
        jsr decbo
        lda bo
        sta bsav
        lda bo+1
        sta bsav+1
        ldx ilen
        dex
        beq nx
        stx cnt
c1      jsr incbo
        ldx #0
        jsr btst
        bne cut
        dec cnt
        bne c1
        jsr rstbo
        ldx ilen
        dex
        stx cnt
c2      jsr incbo
        ldx #2
        jsr bset
        dec cnt
        bne c2
        beq nx
cut     jsr rstbo
        ldx #0
        jsr bclr
nx      jsr rstbo
        jsr incbo
        jmp l
r       rts
.)

; labels : étiquettes (carte L) et noms utilisés (bit 7 du genre)
labels
.(
        lda #$80                ; points d'entrée de /E, vecteurs
        sta emode
        jsr entries
        lda #0
        sta bo
        sta bo+1
        sta plain
l       jsr nexts
        bcs r
        jsr decbo
        lda bo
        sta bsav
        lda bo+1
        sta bsav+1
        bit asbyt
        bmi nx
        lda opv
        sta val
        lda opv+1
        sta val+1
        lda kind
        cmp #M_REL
        beq far
        cmp #M_ABS
        bcc zp
        cmp #M_INX
        bcs zp                  ; INX, INY : page zéro
far     jsr inf
        bcs zp
        jsr ref
        jmp nx
zp      lda kind
        cmp #M_ZP
        bcc nx                  ; IMP, IMM
        jsr inf                 ; dans le fichier : pas de nom
        bcc nx
        jsr symf
        bcs nx
        ldy #3
        lda (symp),y
        ora #$80
        sta (symp),y
nx      jsr rstbo
        jsr incbo
        jmp l
r       rts
.)

; ref : étiquette pour la position bo ; dans une instruction : sur son
;   début
ref
.(
        ldx #2
        jsr btst
        beq lab
        jsr instart
lab     ldx #4
        jmp bset
.)

; instart : bo intérieur -> bo = début de l'instruction, A = écart (1, 2)
instart
.(
        jsr dec1
        ldx #0
        jsr btst
        bne one
        jsr dec1
        lda #2
        rts
one     lda #1
        rts
dec1    lda bo
        bne d
        dec bo+1
d       dec bo
        rts
.)

; ---------------------------------------------------------------------
; emit : écrit NOM.ASM
emit
.(
        jsr create
        lda #<s_hdr             ; « ; DIS B:JEU.BIN »
        ldy #>s_hdr
        jsr wstr
        lda #<ifcb
        ldy #>ifcb
        jsr wfull
        jsr wcrlf
        lda symlo               ; noms utilisés : NOM = $hhhh
        sta ptr
        lda symlo+1
        sta ptr+1
h1      ldy #0
        lda (ptr),y
        beq h3
        ldy #3
        lda (ptr),y
        bpl h2
        lda ptr
        sta symp
        lda ptr+1
        sta symp+1
        jsr wname
        lda #<s_eq
        ldy #>s_eq
        jsr wstr
        ldy #2
        lda (ptr),y
        beq h4
        jsr whex
h4      ldy #1
        lda (ptr),y
        jsr whex
        jsr wcrlf
h2      ldy #0
        lda (ptr),y
        clc
        adc #4
        adc ptr
        sta ptr
        bcc h1
        inc ptr+1
        bne h1
h3      lda #<s_org             ; « *= $hhhh »
        ldy #>s_org
        jsr wstr
        lda org+1
        jsr whex
        lda org
        jsr whex
        jsr wcrlf
        lda #0
        sta bo
        sta bo+1
        sta cont
loop    lda bo
        cmp flen
        lda bo+1
        sbc flen+1
        bcs done
        ldx #4                  ; étiquette en colonne 1
        jsr btst
        beq nl
        clc
        lda bo
        adc org
        sta val
        lda bo+1
        adc org+1
        sta val+1
        jsr wlab                ; colonne 9, ou une espace après un nom long
        cmp #8
        bcs one
        sta tmpb
        lda #8
        sec
        sbc tmpb
        tax
        bne ind
one     ldx #1
        bne ind
nl      ldx #8
ind     lda #" "
        jsr putb
        dex
        bne ind
        ldx #0
        jsr btst
        beq dat
        lda #0
        sta cont
        jsr winst
        jmp eol
dat     jsr wdata
eol     jsr wcrlf
        jmp loop
done    jmp wclose
.)

; winst : l'instruction en bo, bo avance
winst
.(
        jsr decbo
        bit asbyt
        bpl ins
        lda #<s_byt             ; .byt $op,$lo,$hi ; instruction
        ldy #>s_byt
        jsr wstr
        ldy #0
        lda op
b       jsr wdol
        iny
        cpy ilen
        beq c
        lda #","
        jsr putb
        lda raw-1,y
        jmp b
c       lda #<s_com
        ldy #>s_com
        jsr wstr
        lda #$80
        sta plain
        jsr wins
        lda #0
        sta plain
        jmp adv
ins     jsr wins
adv     clc
        lda bo
        adc ilen
        sta bo
        bcc r
        inc bo+1
r       rts
.)

; wins : mnémonique (en minuscules) et opérande
wins
.(
        ldx op
        lda dis_mn,x
        sta tmpb
        asl
        adc tmpb
        tax
        ldy #3
m       lda mn_names,x
        ora #$20
        jsr putb
        inx
        dey
        bne m
        lda kind
        bne o
        rts
o       lda #" "
        jsr putb
        lda kind
        asl
        tax
        lda optab+1,x
        pha
        lda optab,x
        pha
        rts
.)

optab   .word o_imm-1, o_imm-1, o_zp-1, o_zpx-1, o_zpy-1, o_abs-1, o_abx-1
        .word o_aby-1, o_ind-1, o_inx-1, o_iny-1, o_abs-1

o_imm   lda #"#"
        jsr putb
        lda opv
        jmp wdol
o_zp    jmp wzp
o_zpx   jsr wzp
cx      lda #","
        jsr putb
        lda #"x"
        jmp putb
o_zpy   jsr wzp
cy      lda #","
        jsr putb
        lda #"y"
        jmp putb
o_abs   jmp wabs
o_abx   jsr wabs
        jmp cx
o_aby   jsr wabs
        jmp cy
o_ind   lda #"("
        jsr putb
        jsr wabs
cp      lda #")"
        jmp putb
o_inx   lda #"("
        jsr putb
        jsr wzp
        jsr cx
        jmp cp
o_iny   lda #"("
        jsr putb
        jsr wzp
        jsr cp
        jmp cy

; wzp : opérande sur un octet : nom, sinon $hh
wzp
.(
        bit plain
        bmi h
        lda opv
        sta val
        lda #0
        sta val+1
        lda bo                  ; bo de l'instruction écrite : gardé
        pha
        lda bo+1
        pha
        jsr inf                 ; dans le fichier (chargé en page zéro) :
        pla                     ;   pas de nom
        sta bo+1
        pla
        sta bo
        bcc h
        jsr symf
        bcs h
        jmp wname
h       lda opv
        jmp wdol
.)

; wabs : adresse : étiquette (dans le fichier), nom, sinon $hhhh
wabs
.(
        bit plain
        bmi h
        lda bo                  ; bo de l'instruction écrite : gardé
        pha
        lda bo+1
        pha
        lda opv
        sta val
        lda opv+1
        sta val+1
        jsr inf
        bcs n0
        ldx #2
        jsr btst
        beq l0
        jsr instart
        pha
        jsr bo2val
        jsr wlab
        lda #"+"
        jsr putb
        pla
        ora #"0"
        jsr putb
        jmp l1
l0      jsr wlab
l1      pla
        sta bo+1
        pla
        sta bo
        rts
n0      pla
        sta bo+1
        pla
        sta bo
        jsr symf
        bcs h
        jmp wname
h       lda #"$"
        jsr putb
        lda opv+1
        jsr whex
        lda opv
        jmp whex
.)

bo2val  clc
        lda bo
        adc org
        sta val
        lda bo+1
        adc org+1
        sta val+1
        rts

; wlab : étiquette de l'adresse val (dans le fichier) : son nom dans
;   ATMOS.SYM, sinon « Lhhhh » ; A = longueur
wlab
.(
        jsr symf
        bcs l
        jsr wname
        ldy #0
        lda (symp),y
        rts
l       lda #"L"
        jsr putb
        lda val+1
        jsr whex
        lda val
        jsr whex
        lda #5
        rts
.)

; ---------------------------------------------------------------------
; wdata : données depuis bo (pas un début d'instruction), jusqu'à une
;   limite (début, étiquette, fin), bo avance
wdata
.(
        jsr same
        cmp #8
        bcc ac
        sta cnt                 ; .dsb n,$hh
        lda #0
        sta cont
        lda #<s_dsb
        ldy #>s_dsb
        jsr wstr
        lda cnt
        sta val
        lda #0
        sta val+1
        jsr wdec
        lda #","
        jsr putb
        jsr byte
        jsr wdol
        ldx cnt
d1      jsr incbo
        dex
        bne d1
        rts
ac      jsr prt
        cmp #4
        bcs a0
        bit cont                ; suite d'une chaîne coupée : .asc aussi
        bpl b
        cmp #0
        beq b
a0      sta cnt                 ; .asc "..."
        ldx #0                  ; pleine : la suivante continue la chaîne
        cmp #NASC
        bne a2
        ldx #$80
a2      stx cont
        lda #<s_asc
        ldy #>s_asc
        jsr wstr
a1      jsr byte
        jsr putb
        jsr incbo
        dec cnt
        bne a1
        lda #$22
        jmp putb
b       lda #<s_byt             ; .byt $hh,...
        ldy #>s_byt
        jsr wstr
        lda #0
        sta nlin
        sta cont
b1      jsr byte
        jsr wdol
        jsr incbo
        inc nlin
        lda nlin
        cmp #NBYT
        beq r
        jsr limit
        bcs r
        jsr same
        cmp #8
        bcs r
        jsr prt
        cmp #4
        bcs r
        lda #","
        jsr putb
        jmp b1
r       rts
.)

; same : A = octets égaux à celui de bo (255 au plus, jusqu'à une limite)
same
.(
        jsr savbo
        jsr byte
        sta tmpb
        lda #1
        sta rc
l       lda rc
        cmp #255
        beq e
        jsr incbo
        jsr limit
        bcs e
        jsr byte
        cmp tmpb
        bne e
        inc rc
        bne l
e       jsr rstbo
        lda rc
        rts
.)

; prt : A = caractères imprimables depuis bo (NASC au plus), sans « " »
prt
.(
        jsr savbo
        lda #0
        sta rc
l       jsr byte
        cmp #$22
        beq e
        cmp #" "
        bcc e
        cmp #$7F
        bcs e
        inc rc
        lda rc
        cmp #NASC
        beq e
        jsr incbo
        jsr limit
        bcc l
e       jsr rstbo
        lda rc
        rts
.)

; limit : C=1 si bo est une limite (fin du fichier, début, étiquette)
limit
.(
        lda bo
        cmp flen
        lda bo+1
        sbc flen+1
        bcs r
        ldx #0
        jsr btst
        bne yes
        ldx #4
        jsr btst
        bne yes
        clc
        rts
yes     sec
r       rts
.)

; byte : octet du fichier en bo -> A (X, Y gardés)
byte    clc
        lda bo
        adc org
        sta ra
        lda bo+1
        adc org+1
        sta ra+1
        jmp rdb

savbo   lda bo
        sta bsav
        lda bo+1
        sta bsav+1
        rts
rstbo   lda bsav
        sta bo
        lda bsav+1
        sta bo+1
        rts
incbo   inc bo
        bne ib
        inc bo+1
ib      rts

; decbo : décode l'instruction en bo (pc = org + bo)
decbo   clc
        lda bo
        adc org
        sta pc
        lda bo+1
        adc org+1
        sta pc+1
        ; (suite : decode)

; ---------------------------------------------------------------------
; decode : instruction en pc -> op, kind ($FF : inconnue ou ne tient pas
;   dans le fichier), ilen, opv (opérande ; branchement : la cible),
;   asbyt ($80 : à écrire en .byt : branchement hors de $0000-$FFFF,
;   adresse absolue sur un octet quand la page zéro existe)
decode
.(
        lda pc
        sta ra
        lda pc+1
        sta ra+1
        jsr rdb
        sta op
        tax
        lda #0
        sta asbyt
        sta opv+1
        lda #1
        sta ilen
        lda dis_md,x
        sta kind
        bmi r
        tax
        lda md_len,x
        sta ilen
        tax                     ; dernier octet : pc + ilen - 1 <= last
        dex
        txa
        clc
        adc pc
        tay
        lda pc+1
        adc #0
        bcs no
        cmp last+1
        bcc fit
        bne no
        cpy last
        bcc fit
        beq fit
no      lda #$FF
        sta kind
        lda #1
        sta ilen
r       rts
fit     lda ilen
        cmp #1
        beq r
        jsr nxt
        sta opv
        lda ilen
        cmp #3
        bne o2
        jsr nxt
        sta opv+1
o2      lda opv
        sta raw
        lda opv+1
        sta raw+1
        lda kind
        cmp #M_REL
        bne ab
        lda opv                 ; cible = pc + 2 + déplacement
        tay
        ldx #0
        cmp #$80
        bcc p
        dex
p       clc
        lda pc
        adc #2
        sta opv
        lda pc+1
        adc #0
        sta opv+1
        lda #0
        adc #0
        sta tmpb
        clc
        tya
        adc opv
        sta opv
        txa
        adc opv+1
        sta opv+1
        txa
        adc tmpb
        beq r
        lda #$80
        sta asbyt
        rts
ab      cmp #M_ABS
        bcc r
        cmp #M_IND
        bcs r
        lda opv+1
        bne r
        ldx op
        lda zpalt,x
        beq r
        lda #$80
        sta asbyt
        rts
nxt     inc ra
        bne n1
        inc ra+1
n1      jmp rdb
.)

; ---------------------------------------------------------------------
; inf : val dans le fichier -> C=0, bo = val - org ; sinon C=1
inf
.(
        sec
        lda val
        sbc org
        sta bo
        lda val+1
        sbc org+1
        sta bo+1
        bcc o
        lda bo
        cmp flen
        lda bo+1
        sbc flen+1
        bcs o
        clc
        rts
o       sec
        rts
.)

; nexts : premier début d'instruction à partir de bo -> C=0 ; C=1 : aucun
nexts
.(
l       lda bo
        cmp flen
        lda bo+1
        sbc flen+1
        bcs r
        ldx #0
        jsr bptr
        lda (bp),y
        bne b
        lda bo                  ; octet de la carte nul : 8 positions
        ora #7
        sta bo
        bne i
b       and bm
        bne yes
i       jsr incbo
        jmp l
yes     clc
r       rts
.)

; Cartes de bits : X = 0 (S), 2 (I), 4 (L), position bo
; btst : Z=1 si le bit est nul ; bset, bclr
btst    jsr bptr
        lda (bp),y
        and bm
        rts
bset    jsr bptr
        lda (bp),y
        ora bm
        sta (bp),y
        rts
bclr    jsr bptr
        lda bm
        eor #$FF
        and (bp),y
        sta (bp),y
        rts
bptr    lda bo+1
        sta bq+1
        lda bo
        lsr bq+1
        ror
        lsr bq+1
        ror
        lsr bq+1
        ror
        clc
        adc maps,x
        sta bp
        lda bq+1
        adc maps+1,x
        sta bp+1
        lda bo
        and #7
        tay
        lda bits,y
        sta bm
        ldy #0
        rts
bits    .byt 1,2,4,8,16,32,64,128

; ---------------------------------------------------------------------
; rdb : octet du fichier à l'adresse ra -> A (X et Y gardés). Cache à
;   correspondance directe : enregistrement n dans l'emplacement
;   n & cmask ; un emplacement absent est lu (fonction 33).
rdb
.(
        stx gx
        sty gy
        sec
        lda ra
        sbc org
        sta t0
        lda ra+1
        sbc org+1
        sta t0+1
        lda t0                  ; enregistrement = position / 128
        asl
        lda t0+1
        rol
        sta rlo
        lda #0
        rol
        sta rhi
        lda rlo
        and cmask
        tax
        lda tagl,x
        cmp rlo
        bne miss
        lda tagh,x
        cmp rhi
        beq hit
miss    lda rlo
        sta tagl,x
        sta ifcb+FCB_R0
        lda rhi
        sta tagh,x
        sta ifcb+FCB_R0+1
        lda #0
        sta ifcb+FCB_R0+2
        jsr slot
        lda rp
        ldy rp+1
        ldx #F_SETDMA
        jsr BDOS
        lda #<ifcb
        ldy #>ifcb
        ldx #F_RREAD
        jsr BDOS
        cmp #0
        beq get
        lda #<m_rerr
        ldy #>m_rerr
        jmp fail
hit     jsr slot
get     lda t0
        and #127
        tay
        lda (rp),y
        ldx gx
        ldy gy
        rts
slot    txa                     ; rp = cache + X x 128
        lsr
        sta rp+1
        lda #0
        ror
        clc
        adc cache
        sta rp
        lda rp+1
        adc cache+1
        sta rp+1
        rts
.)

; ---------------------------------------------------------------------
; symf : nom valant val -> C=0, symp ; C=1 : aucun
symf
.(
        lda val
        cmp symmin
        lda val+1
        sbc symmin+1
        bcc no
        lda symlo
        sta symp
        lda symlo+1
        sta symp+1
l       ldy #0
        lda (symp),y
        beq no
        iny
        lda (symp),y
        cmp val
        bne nx
        iny
        lda (symp),y
        cmp val+1
        beq yes
nx      ldy #0
        lda (symp),y
        clc
        adc #4
        adc symp
        sta symp
        bcc l
        inc symp+1
        bne l
no      sec
        rts
yes     clc
        rts
.)

; wname : le nom en symp dans le fichier
wname
.(
        ldy #0
        lda (symp),y
        tax
        ldy #4
l       lda (symp),y
        jsr putb
        iny
        dex
        bne l
        rts
.)

; ---------------------------------------------------------------------
; Écriture de NOM.ASM
; create : ofcb (lecteur et nom déjà posés) + type ASM, remplacé s'il
;   existe, ouvert
create
.(
        ldy #2
t       lda t_asm,y
        sta ofcb+9,y
        dey
        bpl t
        lda #0
        ldy #12
z       sta ofcb,y
        iny
        cpy #36
        bne z
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        cmp #$FE
        bne m
        lda #<ofcb
        ldy #>ofcb
        jsr pfull
        lda #<m_ro
        ldy #>m_ro
        jmp fail
m       lda #<ofcb
        ldy #>ofcb
        ldx #F_MAKE
        jsr BDOS
        cmp #$FF
        bne ok
        lda #<m_dir
        ldy #>m_dir
        jmp fail
ok      lda #0
        sta opos
        rts
.)

; wclose : dernier enregistrement complété par des ^Z, fichier fermé
wclose
.(
l       lda opos
        beq c
        lda #$1A
        jsr putb
        jmp l
c       lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jmp BDOS
.)

; putb : A dans le fichier écrit (X et Y gardés) ; disque plein :
;   fichier effacé, fin
putb
.(
        stx ox
        ldx opos
        sta obuf,x
        inx
        stx opos
        ldx ox
        bit opos                ; 128 : enregistrement plein
        bmi fl
        rts
fl      pha
        tya
        pha
        lda #<obuf
        ldy #>obuf
        ldx #F_SETDMA
        jsr BDOS
        lda #<ofcb
        ldy #>ofcb
        ldx #F_WRITE
        jsr BDOS
        cmp #0
        beq ok
        lda #<ofcb
        ldy #>ofcb
        ldx #F_CLOSE
        jsr BDOS
        lda #<ofcb
        ldy #>ofcb
        ldx #F_DELETE
        jsr BDOS
        lda #<m_full
        ldy #>m_full
        jmp fail
ok      lda #0
        sta opos
        pla
        tay
        ldx ox
        pla
        rts
.)

; wstr : chaîne A/Y dans le fichier
wstr
.(
        sta sp
        sty sp+1
        ldy #0
l       lda (sp),y
        beq r
        jsr putb
        iny
        bne l
r       rts
.)

wcrlf   lda #13
        jsr putb
        lda #10
        jmp putb

; wdol : « $hh » (X et Y gardés) ; whex : « hh »
wdol    pha
        lda #"$"
        jsr putb
        pla
whex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr d
        pla
        and #$0F
d       stx pb
        tax
        lda hexd,x
        ldx pb
        jmp putb
.)

; wdec : val en décimal dans le fichier
wdec
.(
        jsr ndec
        ldx #0
l       lda dbuf,x
        jsr putb
        inx
        cpx dg
        bne l
        rts
.)

; wfull : nom du FCB A/Y dans le fichier (B:NOM.EXT)
wfull   ldx #<putb
        stx pv+1
        ldx #>putb
        stx pv+2
        jsr pfull0
        ldx #<putc
        stx pv+1
        ldx #>putc
        stx pv+2
        rts

; ---------------------------------------------------------------------
; pname : nom en TAIL,X -> FCB fp (lecteur, nom, type ; 12-35 à zéro)
;   C=1 : nom vide ou invalide (jokers)
pname
.(
        ldy #0
        lda #0
        sta (fp),y
        iny
        lda #" "
b       sta (fp),y
        iny
        cpy #12
        bne b
        lda #0
z       sta (fp),y
        iny
        cpy #36
        bne z
        lda TAIL+1,x            ; lecteur
        cmp #":"
        bne nm
        lda TAIL,x
        and #$DF
        sec
        sbc #"A"-1
        beq bad
        cmp #5
        bcs bad
        ldy #0
        sta (fp),y
        inx
        inx
nm      ldy #1
n1      jsr nchr
        bcs n2
        cmp #"."
        beq ty
        cpy #9
        bcs n3
        sta (fp),y
        iny
n3      inx
        bne n1
ty      inx
        ldy #9
t1      jsr nchr
        bcs n2
        cmp #"."
        beq bad
        cpy #12
        bcs t2
        sta (fp),y
        iny
t2      inx
        bne t1
n2      ldy #1                  ; nom vide : refusé
        lda (fp),y
        cmp #" "
        beq bad
        clc
        rts
bad     sec
        rts
.)

; nchr : caractère TAIL,X du nom en majuscule -> C=1 en fin de nom
;   (espace, fin, /) ; jokers et « : » : erreur (pile rendue)
nchr
.(
        lda TAIL,x
        beq e
        cmp #" "
        beq e
        cmp #"/"
        beq e
        cmp #"*"
        beq bad
        cmp #"?"
        beq bad
        cmp #":"
        beq bad
        cmp #"a"
        bcc r
        cmp #"z"+1
        bcs r
        and #$DF
r       clc
        rts
e       sec
        rts
bad     lda #<m_name
        ldy #>m_name
        jmp fail
.)

skipsp
.(
l       lda TAIL,x
        cmp #" "
        bne r
        inx
        bne l
r       rts
.)

; gethex : nombre hexadécimal en TAIL,X (« $ » facultatif, 4 chiffres au
;   plus, jusqu'à l'espace, « / » ou la fin) -> val, C=0 ; C=1 : invalide
gethex
.(
        lda #0
        sta val
        sta val+1
        sta dg
        lda TAIL,x
        cmp #"$"
        bne l
        inx
l       lda TAIL,x
        beq e
        cmp #" "
        beq e
        cmp #"/"
        beq e
        and #$DF                ; minuscules (les chiffres gardent leur bit 5 :
        cmp #"A"                ;   « 0 » & $DF = $10)
        bcc dig
        cmp #"F"+1
        bcs no
        sbc #"A"-11             ; C=0 : A -> 10
        jmp put
dig     lda TAIL,x
        sec
        sbc #"0"
        cmp #10
        bcs no
put     ldy dg
        cpy #4
        bcs no
        ldy #4
s       asl val
        rol val+1
        dey
        bne s
        ora val
        sta val
        inc dg
        inx
        bne l
no      sec
        rts
e       lda dg
        beq no
        clc
        rts
.)

; ---------------------------------------------------------------------
; pfull : nom du FCB A/Y à l'écran (B:NOM.EXT si le lecteur est donné) ;
;   pfull0 : vers la routine pv (putc ou putb)
pfull   ldx #<putc
        stx pv+1
        ldx #>putc
        stx pv+2
pfull0
.(
        sta fp
        sty fp+1
        ldy #0
        lda (fp),y
        beq nm
        clc
        adc #"A"-1
        jsr pv
        lda #":"
        jsr pv
nm      ldy #1
l1      lda (fp),y
        cmp #" "
        beq ex
        jsr pv
        iny
        cpy #9
        bne l1
ex      ldy #9
        lda (fp),y
        cmp #" "
        beq r
        lda #"."
        jsr pv
l2      lda (fp),y
        cmp #" "
        beq r
        jsr pv
        iny
        cpy #12
        bne l2
r       rts
.)
pv      jmp putc

; ndec : val -> dbuf (chiffres décimaux sans zéros de tête), dg = nombre
ndec
.(
        lda #0
        sta dg
        ldy #4
d       ldx #0
s       lda val
        sec
        sbc dl,y
        pha
        lda val+1
        sbc dh,y
        bcc n
        sta val+1
        pla
        sta val
        inx
        bne s
n       pla
        txa
        bne put
        lda dg
        bne put0
        cpy #0
        bne nx
put0    txa
put     ora #"0"
        ldx dg
        sta dbuf,x
        inc dg
nx      dey
        bpl d
        rts
.)
dl      .byt <1,<10,<100,<1000,<10000
dh      .byt >1,>10,>100,>1000,>10000

; phex : A en deux chiffres hexadécimaux à l'écran (X et Y gardés)
phex
.(
        pha
        lsr
        lsr
        lsr
        lsr
        jsr d
        pla
        and #$0F
d       stx pb
        tax
        lda hexd,x
        ldx pb
        jmp putc
.)
hexd    .asc "0123456789ABCDEF"

putc
.(
        sta ch
        pha
        txa
        pha
        tya
        pha
        lda ch
        ldx #F_CONOUT
        jsr BDOS
        pla
        tay
        pla
        tax
        pla
        rts
.)
crlf    lda #13
        jsr putc
        lda #10
        jmp putc
puts
.(
        sta sp
        sty sp+1
        ldy #0
l       lda (sp),y
        beq r
        jsr putc
        iny
        bne l
r       rts
.)

s_hdr   .asc "; DIS ",0
s_eq    .asc " = $",0
s_org   .asc "        *= $",0
s_byt   .asc ".byt ",0
s_asc   .asc ".asc ",$22,0
s_dsb   .asc ".dsb ",0
s_com   .asc " ; ",0

#include "dis_inc.s"
#include "asm_tab.s"
#include "dis.msg"

endc
ifcb    = endc          ; le fichier lu (36 octets)
ofcb    = ifcb+36       ; NOM.ASM
sfcb    = ofcb+36       ; ATMOS.SYM
entl    = sfcb+36       ; points d'entrée de /E
enth    = entl+NENT
dbuf    = enth+NENT     ; chiffres décimaux (5)
obuf    = dbuf+5        ; enregistrement à écrire
dis_mn  = obuf+128      ; code -> mnémonique (dis_inc.s)
dis_md  = dis_mn+256    ; code -> mode
zpalt   = dis_md+256    ; code -> 1 : absolu qui a une forme page zéro
tagl    = zpalt+256     ; emplacements du cache : enregistrement lu
tagh    = tagl+256
dyn     = tagh+256      ; ATMOS.SYM, cartes, cache
