; =====================================================================
;  put.s — PUT fichier commande : copie la sortie console dans un fichier
;          (partie résidente : crochets vers la fenêtre, win.s)
;
;  Le code de PUT est dans la fenêtre $F7C0-$FCFF (win.s), chargé avec
;  le système, et rechargé de CPA.BNK (bank.s) si une autre banque a
;  pris sa place. Restent ici les tests faits sans entrer dans la
;  fenêtre : put_on (conout, put_end, put_nl), put_pend (entrée du BDOS)
;  et le contenu de la fenêtre (put_end, cmd_put). On n'entre dans la
;  fenêtre que si PUT y est et qu'une capture est en cours (put_on, posé
;  par la fenêtre elle-même), ou pour la commande PUT.
; =====================================================================

; put_end : termine la capture (prompt, démarrage à chaud) ; aussi après
;   un disque plein, qui a arrêté la copie (put_on à 0) mais laissé le
;   fichier ouvert et le message à afficher (put_lost)
put_end
        lda win_id              ; PUT absent (RESET pendant un prêt de la
        lsr                     ; fenêtre) : rien à refermer
        bcc pe_r
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

; PUT fichier commande : PUT rechargé de CPA.BNK s'il n'est pas dans la
;   fenêtre (refusé, avec le message du chargeur, si CPA.BNK manque)
cmd_put
        lda win_id
        lsr                     ; bit 0 : WIN_PUT
        bcs cp_ok
        lda #WIN_PUT
        jsr bnk_load
        bcs pe_r
cp_ok   jmp W_CMD
