; dis.msg : messages of DIS.COM in English (the French ones are in
;   progs/msg/fr/dis.msg, same labels). Included by progs/dis.s.
m_use   .asc "DIS name [adr] [/E adr ...]",13,10
        .asc "machine code -> NAME.ASM, a source",13,10
        .asc "that ASM reassembles identically",13,10
        .asc "adr: load address, hex (0500)",13,10
        .asc "/E: more entry points",13,10
        .asc "default type .BIN",13,10,0
m_name  .asc "Invalid name",13,10,0
m_isasm .asc "Not a .ASM: DIS would write it",13,10,0
m_abs   .asc ": not found",13,10,0
m_empty .asc "Empty file",13,10,0
m_big   .asc "Goes past $FFFF",13,10,0
m_nosym .asc "No ATMOS.SYM: addresses in hex",13,10,0
m_mem   .asc "Not enough memory",13,10,0
m_rerr  .asc 13,10,"Read error",13,10,0
m_ro    .asc ": read-only file",13,10,0
m_dir   .asc "Directory full",13,10,0
m_full  .asc 13,10,"Disk full",13,10,0
m_done  .asc " written",13,10,0
