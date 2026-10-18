; =====================================================================
;  rl_keys.s — table des touches de l'édition de ligne (rline.s),
;  rangée dans la page $FF00 (données seulement)
; =====================================================================

;       RETURN <-  ->  haut bas DEL ^D  ^A  ^E  ^U  ^C  ^P  SHIFT<- SHIFT->
;       (disque : ESC TAB)
rl_keys .byt $0D,$08,$09,$0B,$0A,$7F,$04,$01,$05,$15,$03,$10,$F0,$F1
#ifdef DISK
        .byt $1B,$1D
#endif
RL_NKEYS = * - rl_keys
rl_vecs .word k_ret-1,k_left-1,k_right-1,k_up-1,k_down-1,k_del-1,k_fdel-1
        .word k_home-1,k_end-1,k_kill-1,k_brk-1,k_prt-1,k_home-1,k_end-1
#ifdef DISK
        .word k_cpl-1,k_cpl-1
#endif
