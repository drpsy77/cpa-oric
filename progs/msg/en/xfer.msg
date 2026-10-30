; xfer.msg : messages de XFER.COM en anglais (le français est dans
;   progs/msg/fr/xfer.msg, mêmes étiquettes). Inclus par progs/xfer.s.
m_use   .asc "XFER R file [name] [/T] : receive",13,10
        .asc "XFER S file [name] [/T] : send",13,10
        .asc " /T : text (Mac line endings)",13,10
        .asc "Connect first with TERM, then ^Q",13,10,"$"
m_wild  .asc "XFER : no wildcards",13,10,"$"
m_nodsr .asc "No modem (DSR)",13,10,"$"
m_nofil .asc "No file",13,10,"$"
m_dfull .asc 13,10,"Disk or directory full",13,10,"$"
m_ro    .asc "File is read-only : kept",13,10,"$"
m_renf  .asc "Disk error while renaming",13,10,"$"
m_rcv   .asc "Receiving $"
m_snd   .asc "Sending $"
m_sabs  .asc "Server : no such file",13,10,"$"
m_sref  .asc "Server : refused",13,10,"$"
m_norep .asc "No answer from the server",13,10,"$"
m_blk   .asc 13,"Block $"
m_done  .asc " : done",13,10,"$"
m_esc   .asc 13,10,"Cancelled (ESC)",13,10,"$"
m_can   .asc 13,10,"Cancelled by the server",13,10,"$"
m_fail  .asc 13,10,"Failed : too many errors",13,10,"$"
