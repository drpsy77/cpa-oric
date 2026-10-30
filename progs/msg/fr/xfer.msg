; xfer.msg : messages de XFER.COM (français) ; la traduction anglaise est
; dans progs/msg/en/xfer.msg, mêmes étiquettes. Inclus par progs/xfer.s.
m_use   .asc "XFER R fic [nom] [/T] : recevoir",13,10
        .asc "XFER E fic [nom] [/T] : envoyer",13,10
        .asc " /T : texte (fins de ligne du Mac)",13,10
        .asc "Connexion d'abord par TERM, puis ^Q",13,10,"$"
m_wild  .asc "XFER : pas de jokers",13,10,"$"
m_nodsr .asc "Pas de modem (DSR)",13,10,"$"
m_nofil .asc "Fichier absent",13,10,"$"
m_dfull .asc 13,10,"Disque ou repertoire plein",13,10,"$"
m_ro    .asc "Fichier protege (R/O) : garde",13,10,"$"
m_renf  .asc "Erreur disque au renommage",13,10,"$"
m_rcv   .asc "Reception de $"
m_snd   .asc "Envoi de $"
m_sabs  .asc "Serveur : fichier absent",13,10,"$"
m_sref  .asc "Serveur : refus",13,10,"$"
m_norep .asc "Pas de reponse du serveur",13,10,"$"
m_blk   .asc 13,"Bloc $"
m_done  .asc " : termine",13,10,"$"
m_esc   .asc 13,10,"Annule (ESC)",13,10,"$"
m_can   .asc 13,10,"Annule par le serveur",13,10,"$"
m_fail  .asc 13,10,"Echec : trop d'erreurs",13,10,"$"
