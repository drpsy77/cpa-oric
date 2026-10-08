; =====================================================================
;  ccp_disk.s — commandes disque du CCP et lancement des .COM
; =====================================================================

; ---------------------------------------------------------------------
; Analyse d'un nom de fichier
; ---------------------------------------------------------------------
; parse_fcb : lit un nom ([d:]nom[.ext], jokers * et ?) à partir de la
;   position X de la ligne et remplit le FCB pointé par ZP_CFCB.
;   pf_len = nombre d'octets du FCB à initialiser (36, ou 16 pour FCB2).
;   Retour : X après le nom.
parse_fcb
.(
        jsr skip_spaces
        ldy #0
        lda #0
        sta (ZP_CFCB),y
        lda CMDBUF+2,x
        beq nodrv
        lda CMDBUF+3,x
        cmp #":"
        bne nodrv
        lda CMDBUF+2,x
        sec
        sbc #"@"
        sta (ZP_CFCB),y
        inx
        inx
nodrv   ldy #1
        lda #9
        sta pf_end
        jsr field
        ldy #9
        lda #12
        sta pf_end
        lda CMDBUF+2,x
        cmp #"."
        bne noext
        inx
        jsr field
        jmp tail
noext   jsr pad_field
tail    ldy #12
        lda #0
z       sta (ZP_CFCB),y
        iny
        cpy pf_len
        bne z
        rts
.)

; field : recopie un champ (nom ou type) jusqu'à pf_end
field
.(
loop    cpy pf_end
        beq skip
        lda CMDBUF+2,x
        jsr is_delim
        beq pad_field
        cmp #"*"
        beq star
        sta (ZP_CFCB),y
        inx
        iny
        bne loop
star    lda #"?"
st      sta (ZP_CFCB),y
        iny
        cpy pf_end
        bne st
        inx
skip    lda CMDBUF+2,x          ; ignore les caractères en trop
        jsr is_delim
        beq done
        inx
        bne skip
done    rts
.)

pad_field
.(
        lda #" "
loop    cpy pf_end
        beq done
        sta (ZP_CFCB),y
        iny
        bne loop
done    rts
.)

; is_delim : Z=1 si A est un séparateur de nom (A préservé)
is_delim
        cmp #0
        beq isd
        cmp #" "
        beq isd
        cmp #"."
        beq isd
        cmp #"="
        beq isd
        cmp #","
        beq isd
        cmp #";"
isd     rts

; has_wild : C=1 si le nom contient un joker
has_wild
.(
        ldy #11
loop    lda (ZP_CFCB),y
        cmp #"?"
        beq yes
        dey
        bne loop
        clc
        rts
yes     sec
        rts
.)


; check_name : C=1 si le nom est vide ou contient un joker
check_name
        ldy #1
        lda (ZP_CFCB),y
        cmp #" "
        beq cn_bad
        jmp has_wild
cn_bad  sec
        rts

; is_empty : C=1 si aucun nom n'a été donné
is_empty
        ldy #1
        lda (ZP_CFCB),y
        cmp #" "
        beq ie_yes
        clc
        rts
ie_yes  sec
        rts

; def_pos : analyse le nom à la position ccp_pos dans le FCB par défaut
; def_chk : idem, puis check_name (C=1 si vide ou joker)
; pf_chk  : parse_fcb (FCB et position X déjà fixés), puis check_name
;   X = position après le nom (check_name ne touche pas X)
def_chk
        jsr def_pos
        jmp check_name
pf_chk
        jsr parse_fcb
        jmp check_name
def_pos
        jsr cf_def
        ldx ccp_pos
        jmp parse_fcb

cf_def
        lda #<DEF_FCB
        sta ZP_CFCB
        lda #>DEF_FCB
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        rts

dma_default
        lda #<DEF_DMA
        sta dma
        lda #>DEF_DMA
        sta dma+1
        rts

; bdos_def : appelle la fonction X du BDOS avec le FCB par défaut
bdos_def
        lda #<DEF_FCB
        ldy #>DEF_FCB
        jmp bdos

; ---------------------------------------------------------------------
; Nombres décimaux
; ---------------------------------------------------------------------
dec_lo  .byt <10000,<1000,<100,<10
dec_hi  .byt >10000,>1000,>100,>10

; print_dec : affiche A (bas) / Y (haut) en décimal
print_dec
.(
        sta dec_val
        sty dec_val+1
        lda #0
        sta dec_flag
        ldx #0
dig     ldy #0
sub     lda dec_val
        sec
        sbc dec_lo,x
        pha
        lda dec_val+1
        sbc dec_hi,x
        bcc dd
        sta dec_val+1
        pla
        sta dec_val
        iny
        bne sub
dd      pla
        tya
        bne show
        lda dec_flag
        beq nxt
        tya
show    ora #"0"
        jsr conout
        sta dec_flag
nxt     inx
        cpx #4
        bne dig
        lda dec_val
        ora #"0"
        jmp conout
.)

; ---------------------------------------------------------------------
; DIR [afn]
; ---------------------------------------------------------------------
; DIRS [afn] : comme DIR, fichiers système (SYS) compris
cmd_dirs
        lda #1
        bne dir_go
cmd_dir
        lda #0
dir_go
        sta dir_all
.(
        jsr def_pos
        jsr is_empty
        bcc named
        ldy #1                  ; pas de nom : *.*
        lda #"?"
fill    sta (ZP_CFCB),y
        iny
        cpy #12
        bne fill
named   lda #0
        sta ccp_cnt
        sta dec_flag            ; colonne
        jsr dma_default
        ldx #17
        jsr bdos_def
loop    cmp #$FF
        beq end
        lda dir_all             ; DIR cache les fichiers SYS
        bne show
        lda DEF_DMA+10
        bmi next
show    ldy #1
nm      lda DEF_DMA,y
        and #$7F
        jsr conout
        iny
        cpy #9
        bne nm
        lda #"."
        jsr conout
ext     lda DEF_DMA,y
        and #$7F
        jsr conout
        iny
        cpy #12
        bne ext
        inc ccp_cnt
        ldx dec_flag
        cpx #2
        beq wrap                ; 3e colonne : retour à la ligne automatique
        lda #" "
        jsr conout
        inx
        stx dec_flag
        jmp next
wrap    lda #0
        sta dec_flag
        jsr put_nl              ; PUT : fin de ligne dans le fichier
next    ldx #18
        jsr bdos
        jmp loop
end     lda dec_flag
        beq nocr
        jsr crlf
nocr    lda ccp_cnt
        bne free
        jsr no_file
        ldx act_drv             ; lecteur illisible : pas de place libre
        lda bitmask,x
        and log_vec
        bne free
        rts
free    jsr count_free          ; espace libre en Ko = blocs * 2
        asl
        tax
        lda #0
        rol
        tay
        txa
        jsr print_dec
        lda #<msg_free
        ldy #>msg_free
        jmp print_z
.)

; TYPE, ERA et REN sont des programmes (progs/type.s, era.s, ren.s) :
; place libérée dans le système (piste J de la revue de place).

; ---------------------------------------------------------------------
; SAVE n fichier : enregistre n pages de 256 octets à partir de $0500
; ---------------------------------------------------------------------
cmd_save
.(
        ldx ccp_pos
        jsr get_byte            ; A = dec_val
        bcs syn
        beq syn
        lda tpa_top+1           ; au plus jusqu'au haut de la TPA
        sec
        sbc #>TPA_START-1
        sta pf_end
        lda dec_val
        cmp pf_end
        bcs syn
        sta ccp_cnt
        jsr cf_def
        jsr pf_chk
        bcs syn
        ldx #19                 ; remplace un fichier existant
        jsr bdos_def
        ldx #22
        jsr bdos_def
        cmp #$FF
        beq dirfull
        lda #<TPA_START
        sta dma
        lda #>TPA_START
        sta dma+1
page    lda #2
        sta dec_flag
half    ldx #21
        jsr bdos_def
        cmp #0
        bne dskfull
        lda dma
        eor #$80
        sta dma
        bne nxt
        inc dma+1
nxt     dec dec_flag
        bne half
        dec ccp_cnt
        bne page
        ldx #16
        jsr bdos_def
        jmp dma_default
dskfull ldx #16
        jsr bdos_def
        jsr dma_default
        lda #<msg_dfull
        ldy #>msg_dfull
        jmp print_z
dirfull lda #<msg_dirfull
        ldy #>msg_dirfull
        jmp print_z
syn     jmp syntax_err
.)

; GSAVE fichier / GLOAD fichier : image du mode SPLIT (type .IMG)
cmd_gsave
        jsr img_name
        bcs gs_syn
        jsr img_save
        jmp img_msg
cmd_gload
        jsr img_name
        bcs gs_syn
        jsr img_load
img_msg cmp #0
        beq gs_r
        cmp #1
        bne im2
        lda #<msg_nofile
        ldy #>msg_nofile
        jmp print_z
im2     cmp #2
        bne im3
        lda #<msg_dfull
        ldy #>msg_dfull
        jmp print_z
im3     lda #<msg_nosplit
        ldy #>msg_nosplit
        jmp print_z
gs_syn  jmp syntax_err
gs_r    rts

; img_name : nom de fichier -> DEF_FCB, A/Y = DEF_FCB, C=1 si incorrect
img_name
        jsr def_chk
        lda #<DEF_FCB
        ldy #>DEF_FCB
        rts

; ---------------------------------------------------------------------
; run_transient : charge NOM.COM en $0500 et l'exécute ; à défaut,
;   lance le script NOM.BAT par DO (retour direct au prompt).
;   Ne revient (RTS) que si rien n'est trouvé, ou si le type n'est
;   ni COM ni BAT.
;   Avant le lancement : FCB1 en $045C, FCB2 en $046C, ligne de
;   paramètres en $0480 (longueur puis caractères), DMA = $0480.
;   Le programme revient au système par RTS ou JMP $0200.
; ---------------------------------------------------------------------
run_transient
.(
        lda #<CCP_FCB
        sta ZP_CFCB
        lda #>CCP_FCB
        sta ZP_CFCB+1
        lda #36
        sta pf_len
        ldx ccp_pos
        jsr parse_fcb
        stx ccp_tail
        jsr has_wild
        bcc nowild
notcom  rts                     ; joker, ou type ni COM ni BAT : NOM.EXT?
nowild  ldy #9                  ; type vide : COM, puis BAT si absent ;
        lda (ZP_CFCB),y         ; autre type que COM ou BAT : refusé (un
        cmp #" "                ; texte serait exécuté comme du code)
        bne hasext
        ldx #0
        jsr set_type            ; NOM.COM
        jsr open_com
        bne found
        ldx #3                  ; NOM.COM absent : NOM.BAT
        jsr set_type
        jmp try_bat
hasext  ldx #0
        jsr cmp_type
        beq opencom
        ldx #3
        jsr cmp_type
        bne notcom
try_bat jsr open_ccp            ; script : comme DO NOM [p1..p9]
        beq notcom
        jsr cmd_do              ; reprend le nom à ccp_pos (type BAT)
        pla                     ; retour direct au prompt
        pla
        jmp ccp
opencom jsr open_com
        bne found
        rts
found   lda #<TPA_START
        sta dma
        lda #>TPA_START
        sta dma+1
load    ldx #20
        lda #<CCP_FCB
        ldy #>CCP_FCB
        jsr bdos
        cmp #0
        bne loaded
        lda dma
        eor #$80
        sta dma
        bne load
        inc dma+1
        lda dma+1
        cmp tpa_top+1
        bcc load
        lda #<msg_big
        ldy #>msg_big
        jsr print_z
        jmp wboot
loaded  cmp #1
        bne fail

        ; FCB1, FCB2 et ligne de paramètres
        jsr cf_def
        ldx ccp_tail
        jsr parse_fcb
        lda #<DEF_FCB2
        sta ZP_CFCB
        lda #>DEF_FCB2
        sta ZP_CFCB+1
        lda #16
        sta pf_len
        jsr parse_fcb
        ldx ccp_tail
        ldy #0
tl      lda CMDBUF+2,x
        beq tend
        sta DEF_DMA+1,y
        inx
        iny
        cpy #126
        bne tl
tend    lda #0
        sta DEF_DMA+1,y
        sty DEF_DMA
        jsr dma_default
        jsr TPA_START
        jmp wboot
fail    jmp wboot
.)

; set_type / cmp_type : type du FCB (ZP_CFCB) <- / comparé à COM (X=0)
;   ou BAT (X=3). cmp_type : Z=1 si égal.
set_type
.(
        ldy #9
loop    lda type_tab,x
        sta (ZP_CFCB),y
        inx
        iny
        cpy #12
        bne loop
        rts
.)
cmp_type
.(
        ldy #9
loop    lda type_tab,x
        cmp (ZP_CFCB),y
        bne r
        inx
        iny
        cpy #12
        bne loop
r       rts
.)
type_tab .asc "COMBAT"

; open_com : comme open_ccp ; un programme sans lecteur donné qui n'est
;   pas sur le lecteur courant est cherché sur A: (disquette système)
open_com
.(
        jsr open_ccp
        bne r
        lda cur_drv
        beq r                   ; (Z=1 : introuvable)
        lda CCP_FCB
        bne nf
        inc CCP_FCB             ; A:
        jsr open_ccp
        bne r
        dec CCP_FCB             ; (Z=1)
r       rts
nf      lda #0
        rts
.)

; open_ccp : ouvre CCP_FCB, Z=1 si introuvable
open_ccp
        ldx #15
        lda #<CCP_FCB
        ldy #>CCP_FCB
        jsr bdos
        cmp #$FF
        rts

no_file
        lda #<msg_nofile
        ldy #>msg_nofile
        jmp print_z

msg_free
        .asc "K free",13,10,0
msg_nofile
        .asc "No file",13,10,0
msg_dfull
        .asc "Disk full",13,10,0
msg_dirfull
        .asc "Directory full",13,10,0
msg_big
        .asc "Program too big",13,10,0
