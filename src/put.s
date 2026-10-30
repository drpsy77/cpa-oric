; =====================================================================
;  put.s — PUT fichier commande : copie la sortie console dans un fichier
;          (partie résidente : crochets vers la fenêtre, win.s)
;
;  Le code de PUT est dans la fenêtre $F7C0-$FCFF (win.s), chargé avec
;  le système. Restent ici les tests faits sans entrer dans la fenêtre :
;  put_on (conout, put_end, put_nl), put_pend (entrée du BDOS) et le
;  contenu de la fenêtre (cmd_put). On n'entre dans la fenêtre que si
;  une capture est en cours (put_on, posé par la fenêtre elle-même), ou
;  pour la commande PUT si la fenêtre contient PUT.
; =====================================================================

; put_end : termine la capture (prompt, démarrage à chaud) ; aussi après
;   un disque plein, qui a arrêté la copie (put_on à 0) mais laissé le
;   fichier ouvert et le message à afficher (put_lost)
put_end
        lda put_on
        ora put_lost
        beq pe_r
        jmp W_END
pe_r    rts

; put_nl : CR LF dans le fichier seulement (ligne remplie à l'écran par
; le retour automatique, comme celles de DIR)
put_nl
        lda put_on
        beq pe_r
        lda #13
        jsr W_CHAR
        lda #10
        jmp W_CHAR

; PUT fichier commande : refusé si la fenêtre ne contient pas PUT
cmd_put
        lda win_id
        lsr                     ; bit 0 : WIN_PUT
        bcc cp_no
        jmp W_CMD
cp_no   lda #<msg_putno
        ldy #>msg_putno
        jmp print_z

msg_putno
        .asc "PUT: not loaded",13,10,0
