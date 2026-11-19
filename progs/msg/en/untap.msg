; untap.msg : messages d'UNTAP.COM en anglais (le français est dans
;   progs/msg/fr/untap.msg, mêmes étiquettes). Inclus par progs/untap.s.
m_use   .asc "UNTAP name [n|*] [/1]: .TAP blocks",13,10
        .asc "UNTAP GAME     lists the blocks",13,10
        .asc "UNTAP GAME 2   extracts block 2",13,10
        .asc "UNTAP GAME *   extracts all blocks",13,10
        .asc "BASIC: NAME.BAS (text, MKTAP)",13,10
        .asc "code: NAME.BIN; /1: Oric-1 BASIC",13,10,0
m_name  .asc "Invalid name",13,10,0
m_bnum  .asc "Block number: 1 to 255",13,10,0
m_abs   .asc ": not found",13,10,0
m_none  .asc "No block (not a .TAP?)",13,10,0
m_nob   .asc "No such block",13,10,0
m_blk   .asc "block ",0
m_inc   .asc " incomplete",13,10,0
m_bas   .asc "BAS ",0
m_bin   .asc "BIN ",0
m_run   .asc " /R",0
m_lig   .asc "line ",0
m_dif   .asc ": re-encodes differently",13,10,0
m_ro    .asc ": file protected",13,10,0
m_dir   .asc "Directory full",13,10,0
m_full  .asc 13,10,"Disk full",13,10,0
m_done  .asc " written",13,10,0
