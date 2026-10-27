; usbmount.msg : messages of USBMOUNT.COM in English (French in
; progs/msg/fr/usbmount.msg, same labels). Included by progs/usbmount.s.
m_use   .asc "USBMOUNT [B: [name|/E]] : disk",13,10
        .asc "USBMOUNT name.TAP [/B] : tape",13,10
        .asc "/B : then BASIC loads the tape",13,10,0
m_sysa  .asc "A: refused (system disk)",13,10,0
m_twice .asc "Already mounted in ",0
m_notdsk .asc "Not a disk image",13,10,0
m_nottap .asc "Not a tape (.TAP)",13,10,0
m_drvq  .asc "Drive ? USBMOUNT B: name.DSK",13,10,0
m_exp   .asc "Export it first : EXPORT ",0
m_nocfg .asc "LOCI menu unreadable",13,10,0
