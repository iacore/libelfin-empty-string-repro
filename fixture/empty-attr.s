# fixture/empty-attr.s — the smallest input that makes libelfin call
# value::as_string on a zero-length DWARF string.
#
# One compilation unit with a single DIE (DW_TAG_compile_unit) carrying
# DW_AT_name as a DW_FORM_string of length 0.
#
# Assemble:  cc -c empty-attr.s -o empty-attr.o
#            (as empty-attr.s -o empty-attr.o also works)

        .section .debug_abbrev,"",@progbits
        .uleb128 1                      # abbreviation code 1
        .uleb128 0x11                   # DW_TAG_compile_unit
        .byte    0                      # DW_CHILDREN_no
        .uleb128 0x03                   # DW_AT_name
        .uleb128 0x08                   # DW_FORM_string
        .uleb128 0                      # end of attribute list
        .uleb128 0
        .byte    0                      # end of abbreviation list

        .section .debug_info,"",@progbits
        .long    .Lcu_end - .Lcu_start  # unit_length
.Lcu_start:
        .short   4                      # DWARF version
        .long    0                      # offset into .debug_abbrev
        .byte    8                      # address size
        .uleb128 1                      # abbreviation code 1
        .byte    0                      # DW_AT_name: the empty string
.Lcu_end: