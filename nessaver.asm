; PPU IO ports
PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
OAMADDR = $2003
OAMDATA = $2004
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007
OAMDMA = $4014
; APU IO ports
APUFLAGS = $4015
SQ1_ENV = $4000
SQ1_SWEEP = $4001
SQ1_LO = $4002
SQ1_HI = $4003
SQ2_ENV = $4004
SQ2_SWEEP = $4005
SQ2_LO = $4006
SQ2_HI = $4007
TRI_ENV = $4008
TRI_LO = $400A
TRI_HI = $400B

NO_DVDPALETTES = 9

    .segment "ZEROPAGE"

dvdpalindex:
    .byte $00

dvdinfo: ; bit 0 - up/down, bit 1 - left/right
    .byte %00000000

wait:
    .byte $00, $00, $00

aura:
    .byte $00

    .segment "HEADER"

    .byte "NES", $1A ; iNES Header
    .byte 2 ; PRG data size (16kb)
    .byte 1 ; CHR data size (8kb)
    .byte $01, $00 ; Mapper

    .segment "STARTUP"

    .segment "CODE"

vblankwait:
    bit PPUSTATUS
    bpl vblankwait
    rts

nextpal:
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$12
    sta PPUADDR
    lda PPUDATA
    sta aura

    inc dvdpalindex
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$10
    sta PPUADDR
    lda dvdpalindex
    cmp #NO_DVDPALETTES
    bne @a
    lda #$00
    sta dvdpalindex
@a:
    asl
    asl
    tax
@loop:
    lda dvdpalettes, x
    sta PPUDATA
    inx
    txa
    and #%00000011
    bne @loop
    rts

reset:
    sei 
    cld 
    ldx #$40
    stx $4017
    ldx #$FF
    txs 
    inx 
    stx PPUCTRL
    stx PPUMASK
    stx $4010

    jsr vblankwait

@clrmem:
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    lda #$FE
    sta $0200, x
    inx 
    bne @clrmem

    jsr vblankwait

    lda #%00000011
    sta dvdinfo

ldpal:
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
@loop:
    lda palettes, x
    sta PPUDATA
    inx 
    cpx #$20
    bne @loop

    ; enable rendering
    lda #%10010000
    sta PPUCTRL

    lda #%00011110
    sta PPUMASK

ldspr:
    ldx #$00
@loop:
    ; y-offset (x / 32) 
    txa
    and #%11100000
    lsr
    lsr
    adc #$80
    sta $0200, x
    inx
    ; sprite index (x / 4)
    txa
    lsr
    lsr
    sta $0200, x
    inx
    ; attributes
    lda #%00000000
    sta $0200, x
    inx
    ; x-offset ((x % 32) / 4)
    txa
    and #%00011111
    asl
    adc #$10
    sta $0200, x
    inx
    ; loop logic etc etc etc lololol
    cpx #$A0
    bne @loop

main:
    inc wait
    lda wait
    bne main

    inc wait+1
    lda wait+1
    cmp #8
    bne main
    lda #$00
    sta wait+1

    jsr vblankwait

    lda dvdinfo
    and #%00000001
    bne @right
    lda $0203
    cmp #$06
    bne @xpass
    lda dvdinfo
    ora #%00000001
    sta dvdinfo
    jsr nextpal
    jmp @xpass
@right:
    lda $0203
    cmp #$BB
    bne @xpass
    lda dvdinfo
    and #%11111110
    sta dvdinfo
    jsr nextpal
@xpass:

    lda dvdinfo
    and #%00000010
    bne @down
    lda $0200
    cmp #$0C
    bne @ypass
    lda dvdinfo
    ora #%00000010
    sta dvdinfo
    jsr nextpal
    jmp @ypass
@down:
    lda $0200
    cmp #$B7
    bne @ypass
    lda dvdinfo
    and #%11111101
    sta dvdinfo
    jsr nextpal
@ypass:

    ldx #$00
@xloop:
    lda dvdinfo
    and #%00000001
    bne @xlright
    dec $0203, x
    jmp @xlpass
@xlright:
    inc $0203, x
@xlpass:
    inx
    inx
    inx
    inx
    cpx #$A0
    bne @xloop

    ldx #$00
@yloop:
    lda dvdinfo
    and #%00000010
    bne @yldown
    dec $0200, x
    jmp @ylpass
@yldown:
    inc $0200, x
@ylpass:
    inx
    inx
    inx
    inx
    cpx #$A0
    bne @yloop

    jmp main

nmi:
    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMDMA

    inc wait+2
    lda wait+2
    cmp #8
    bcc @skipaurachk
    lda #$00
    sta wait+2

    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda aura
    ldx #$00
@auraloop:
    sta PPUDATA
    inx
    cpx #$04
    bne @auraloop
    sbc #$10
    cmp #$40
    bcc @auranoreset
    lda #$0F
@auranoreset:
    sta aura
@skipaurachk:

    lda #%10010000
    sta PPUCTRL

    lda #%00011110
    sta PPUMASK

    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    rti

palettes:
    ; Background palettes
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F

    ; Sprite palettes
    .byte $0F, $20, $30, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F

dvdpalettes:
    .byte $0F, $20, $30, $0F ; white (default)
    .byte $0F, $2C, $1C, $0F ; neon blue
    .byte $0F, $3B, $2A, $0F ; green
    .byte $0F, $28, $18, $0F ; gold
    .byte $0F, $22, $11, $0F ; light blue
    .byte $0F, $26, $16, $0F ; red
    .byte $0F, $23, $24, $0F ; purple
    .byte $0F, $06, $17, $0F ; fire
    .byte $0F, $19, $09, $0F ; dark green

    .segment "VECTORS"

    .word nmi
    .word reset
    .word 0

    .segment "CHARS"

    .incbin "graphics.chr"