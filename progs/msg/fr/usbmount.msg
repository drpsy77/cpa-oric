; usbmount.msg : messages de USBMOUNT.COM (français) ; la traduction anglaise
; est dans progs/msg/en/usbmount.msg, mêmes étiquettes. Inclus par
; progs/usbmount.s.
m_use   .asc "USBMOUNT [B: [nom|/E]] : disquette",13,10
        .asc "USBMOUNT nom.TAP [/B] : cassette",13,10
        .asc "/B : puis le BASIC",13,10,0
m_sysa  .asc "A: interdit (disquette systeme)",13,10,0
m_twice .asc "Deja montee en ",0
m_notdsk .asc "Pas une disquette",13,10,0
m_lfs   .asc "Pas d'image sur 0:",13,10,0
m_nottap .asc "Pas une cassette (.TAP)",13,10,0
m_drvq  .asc "Lecteur ? USBMOUNT B: nom.DSK",13,10,0
m_exp   .asc "Exporter d'abord : EXPORT ",0
m_nocfg .asc "Menu du LOCI illisible",13,10,0
