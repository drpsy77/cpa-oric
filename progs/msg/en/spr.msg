; spr.msg : messages de la bibliothèque des sprites et des tuiles
;   (progs/spr.inc), en anglais (le français est dans progs/msg/fr/spr.msg,
;   mêmes étiquettes). Inclus par progs/grapher.s ; recopié dans SPR.INC à la
;   place de « ;#msg spr.msg » par tools/strip_inc.py.
sz_m_res  .asc "SPRITES first",0
sz_m_pool .asc "SPOOL first",0
sz_m_spr  .asc ".SPR file?",0
sz_m_full .asc "no more characters for sprites",0
tz_m_set .asc "TILESET first",0
