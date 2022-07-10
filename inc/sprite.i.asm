;------------------------------------------------------------------------------
; sprite.EnableSprites - Enable sprites
    macro sprite.EnableSprites
        nextreg $15, %00100011
    endm

;------------------------------------------------------------------------------
; sprite.DisableSprites - Disable sprites
    macro sprite.DisableSprites
        ReadNextReg %15
        and %11111110           ; Bit 0 off - disable sprites
        nextreg $15, a
    endm

;------------------------------------------------------------------------------
; sprite.ClearSprites - Clears all sprites
    macro sprite.ClearSprites
        ld b, 64
        ld a, 0
.resetSprite
        nextreg $34, a
        nextreg $35, 0
        nextreg $36, 0
        nextreg $37, 0
        nextreg $38, 0
        nextreg $39, 0
        inc a
        djnz    .resetSprite
        sprite.ClipWindow 0, 0, 319, 255
        sprite.SetTransparency 227
        sprite.LoadDefaultPalette 0
        sprite.LoadDefaultPalette 1
    endm

;------------------------------------------------------------------------------
; sprite.ClipWindow - Set sprite clip window
; Parameters:
;   left    - Left clip position
;   top     - Top clip position
;   width   - Width of the clip window
;   height  - Height of the clip window
    macro sprite.ClipWindow left, top, width, height
        nextreg $1c, %00000010          ; Reset sprite clip registers
        nextreg $19, left >> 1
        nextreg $19, (left + width) >> 1
        nextreg $19, top
        nextreg $19, top + height
    endm

;------------------------------------------------------------------------------
; sprite.SetTransparency
; Parameters
;   index   - Index of the transparency color
    macro sprite.SetTransparency index
        ld a, index
        nextreg $4b, a
    endm

;------------------------------------------------------------------------------
; sprite.Upload - Upload pattern data to the FPGA
; Parameters:
;   page - memory page containing the pattern data

    macro sprite.Upload page
        ld a, page
        call sprite._upload
    endm

;------------------------------------------------------------------------------
; sprite.Incbin - Map pattern data to memory page maped to $c000
;  
    macro sprite.Incbin page, filename
        mmu 6 7, page ; map page starting at 25 to slot 6 and 7
        org $c000   ; set org to address of slot 6
        incbin filename
    endm

;------------------------------------------------------------------------------
; sprite.LoadPalette - load an 8 bit palette from memory
; Parameters:
;   paletteNo   - palette number 0 or 1
;   paletteData - address of the start of the palette data
;   startIndex  - first palette index to start loading
;   count       - number of pallete entries to load
    macro sprite.LoadPalette paletteNo, paletteData, firstIndex, count
        ld a, paletteNo
        ld hl, paletteData
        ld bc, ((count & 0xff) << 8) | firstIndex
        call sprite._loadPalette8
    endm

;------------------------------------------------------------------------------
; sprite.LoadDefaultPalette - loads the sprite palette with default colours
; Parameters:
;   paletteNo   - palette number 0 or 1
    macro sprite.LoadDefaultPalette paletteNo
        ld a, paletteNo
        call sprite._loadDefaultPalette
    endm

;------------------------------------------------------------------------------
; sprite.SetActivePalette - sets the active palette
; Parameters:
;   paletteNo   - palette number 0 or 1
    macro sprite.SetActivePalette paletteNo
        ld a, paletteNo
        call sprite._setActivePalette
    endm

;------------------------------------------------------------------------------
; sprite.SetPaleteEntry - sets the color data for the specified color data
; Parameters:
;   paletteNo   - palette number 0 or 1
;   index       - palette index
;   colorData   - color data to set at the index
    macro sprite.SetPaleteEntry paletteNo, index, colorData
        ld a, paletteNo
        call sprite._selectRWPalette
        ld a, index
        nextreg $40, a
        ld a, colorData
        nextreg $41, a
    endm

;------------------------------------------------------------------------------
; sprite.Show - Show the specified sprite
; Parameters:
;   sprite  - Sprite to update
    macro sprite.Show sprite
        ld hl, sprite
        add hl, sprite.S_Sprite.vpat
        ld a, (hl)
        or %10000000
        ld (hl), a
    endm

;------------------------------------------------------------------------------
; sprite.Hide - Hide the specified sprite
; Parameters:
;   sprite  - Sprite to update
    macro sprite.Hide sprite
        ld hl, sprite
        add hl, sprite.S_Sprite.vpat
        ld a, (hl)
        and %01111111
        ld (hl), a
    endm

;------------------------------------------------------------------------------
; sprite.SetPos - Set the screen position of the specified sprite
; Parameters:
;   sprite  - Sprite to update
;   xpos    - Sprite X
;   ypos    - Sprite Y
    macro sprite.SetPos sprite, xpos, ypos
        ld hl, sprite
        ld de, xpos
        ld a, ypos
        call sprite._setPos
    endm

;------------------------------------------------------------------------------
;sprite.SetPattern - Change the pattern for the specified sprite
; Parameters:
;       sprite - Sprite to update
;       pattern - Pattern to select for the sprite
    macro sprite.SetPattern sprite, pattern
        ld hl, sprite
        ld a, pattern ; load into A so we can handle address references
        call sprite._setPattern
    endm

;------------------------------------------------------------------------------
; sprite.UpdateAll - Update all sprites
    macro sprite.UpdateAll
        call sprite._updateAll
    endm
    
;------------------------------------------------------------------------------
; sprite.StartDefinition - Start the definition of sprites        
        macro sprite.StartDefinition
sprite.definedAt    equ $
        endm

;------------------------------------------------------------------------------
; sprite.EndDefinition - End the definition of the sprites
        macro sprite.EndDefinition
sprite.spriteCount  equ ($-sprite.definedAt) / sprite.S_Sprite
        endm
;------------------------------------------------------------------------------
; sprite.Define - Define a individual sprite
; Parameters:
;   pattern - Default sprite pattern
    macro sprite.Define pattern
        db 0, 0, 0, %01000000 | pattern, 0
    endm

;------------------------------------------------------------------------------
; sprite.DefineUnified - Define a unified sprite
; Parameters:
;   pattern - Default sprite pattern
    macro sprite.DefineUnified pattern
        db 0, 0, 0, %01000000 | pattern, %00100000
    endm

;------------------------------------------------------------------------------
; sprite.DefineRelative - Define a relative sprite
; Parameters:
;   pattern - Default sprite pattern
;   xoffs   - X offset from anchor
;   yoffs   - Y offset from anchor
;   isRelPattern - 1 if pattern number is relative to anchor
    macro sprite.DefineRelative pattern, xoffs, yoffs, isRelPattern
        db xoffs, yoffs, 0, %11000000 | pattern, %01000000 | (isRelPattern & %00000001)
    endm

;------------------------------------------------------------------------------
; sprite.DefineUnifiedAuto - Auto defines a unified sprite with flexible layout
; Parameters:
;   pattern - Anchor pattern
;   w       - Cells in the X direction
;   h       - Cells in the Y direction
;   anchor  - Anchor cell
    macro sprite.DefineUnifiedAuto pattern, w, h, anchor
.offsX = (anchor%w)*16
.offsY = (anchor/w)*16
        db 0, 0, 0, %01000000 | (pattern + anchor), %00100000   ; Anchor sprite
.i = 0
        while .i < w*h; 64
            if .i != anchor
                db (.i%w)*16 - .offsX
                db (.i/w)*16 - .offsY
                db 0
                db %11000000 | .i
                db %01000001 ; Unified, pattern relative to anchor
            endif
.i = .i + 1
        endw
    endm

    module sprite
;--------------------------------------------------------------------
; S_Sprite - struct representing a sprite
; See: https://www.specnext.com/sprites/
    struct S_Sprite
x       byte 0  ; ATTR-0 : x-low byte
y       byte 0  ; ATTR-1 : y-low byte
mrx8    byte 0  ; ATTR-2 : PPPP XM YM R X/PR   
vpat    byte 0  ; ATTR-3 : V E NNNNNN
attr4   byte 0  ; ATTR-4    - H     - 1=4 bit sprite (Only anchor sprites)
                ;             N6    - Bit 6 of pattern
                ;             T     - 0=Composite, 1=Unified
                ;             XX/YY - 00=1x, 01=2x, 10=4x, 11=8x
                ;             NR    - 1=Pattern relative to anchor
                ;             Y8    - 9th bit of Y coordinate
                ; Anchor    - H N6 T XX YY Y8
                ; Composite - 0 1 N6 XX YY NR
                ; Unified   - 0 1 N6 00 00 NR
    ends

;------------------------------------------------------------------------------
; sprite._upload - Upload sprite data to FPGA
; Input:
;       A - Page containing sprites 
_upload:
        nextreg $56, a          ; Bank first 8K to $C000..$DFFF
        inc a           
        nextreg $57, a          ; Bank second 8K to $E000..$FFFF           

        xor a
        ld bc, $303b
        out (c),a               ; Select pattern slot 0
        ld hl, $c000            ; Start at addres $C000     
        ld bc, $005b            ; Sprite pattern-upload I/O port, B=0 inner loop 256 bytes
        ld a, 64                ; 64 patterns to upload
.uploadPatterns:
        otir                    ; B=0 ahead, so otir will repeat 256x ("dec b" wraps 0 to 255)
        dec a   
        jr nz, .uploadPatterns

        ret

;------------------------------------------------------------------------------
; sprite._selectRWPalette - Select the sprite read/write palette
; Input:
;   A   - Palette number
_selectRWPalette:
        or a
        jr nz, .palette2
        ld d, %0'010'0000   ; Auto increment palette index, sprite palette 1
        jr .selectPalette
.palette2        
        ld d, %0'110'0000   ; Auto increment palette index, sprite palette 2
.selectPalette
        ReadNextReg $43
        and %0'000'1111     ; Mask bits to be altered
        or d                ; Set the selected palette
        nextreg $43, a      ; Update the register
        ret

;------------------------------------------------------------------------------
; sprite._loadPalette8 - Load 8 bit sprite palette
; Input:
;       A   - Palette number (0, 1)
;       HL  - Palette color data
;       C   - Starting palette index to update
;       B   - Palette entries to update
_loadPalette8:
        call _selectRWPalette
        call util._write8bitPalette
        ret        

;------------------------------------------------------------------------------
; sprite._loadDefaultPalette - Load sprite default palette
; Input:
;       A   - Palette number (0, 1)
_loadDefaultPalette:
        call _selectRWPalette

        nextreg $40, 0      ; Set the start index
    
        ld b, 0             ; Update all 256 entries
        xor a               ; start with color 0
.loadColorEntry
        nextreg $41, a      ; set color data
        inc a               ; next color value
        djnz .loadColorEntry

        ret 

;------------------------------------------------------------------------------
; sprite._setActivePalette - Set the active palette for sprites
; Input:
;       A   - Palette number (0, 1)
_setActivePalette:
        or a
        jr nz, .palette2
        ld d, %0000'0'000   ; sprite palette 1
        jr .selectPalette
.palette2        
        ld d, %0000'1'000   ; sprite palette 2
.selectPalette
        ReadNextReg $43
        and %1111'0'111     ; Mask bits to be altered
        or d                ; Set the selected palette
        
        nextreg $43, a      ; Update the register
        ret

;------------------------------------------------------------------------------
; sprite._setPattern - Change the pattern applied to the sprite
; Input:
;   HL  - Sprite to update
;   A   - New pattern to apply to the sprite
_setPattern:
        and %00111111                   ; limit pattern 0-63
        ld c, a                         ; put pattern in C
        ld de, sprite.S_Sprite.vpat
        add hl, de                      ; move to the vpat attribute
        ld a, (hl)                      ; load the current vpat value
        and a, %11000000                ; mask off the pattern
        or a, c                         ; combine new pattern
        ld (hl), a                      ; store the updated vpat
        ret

;------------------------------------------------------------------------------
; sprite._updateAll - Update the sprite hardware with the in memory structures
_updateAll:
        xor a
        ld bc, $303b
        out (c), a          ; Select sprite slot 0

        ld hl, definedAt
        ld d, spriteCount        
        ld c, $57 
.updateSprite:
        ld b, S_Sprite
        otir 
        dec d
        jr nz, .updateSprite
        ret

;------------------------------------------------------------------------------
; sprite._setPos - Update the sprite position
; Input:
;   HL - Sprite to update
;   DE - X pos
;   A  - Y pos
_setPos:
        ld (hl), e      ; X - LSB
        inc hl          ; Move to Y
        ld (hl), a      ; Y - LSB
        inc hl          
        ld a, d     
        and %00000001   ; Mask the MSbit 
        or (hl)         ; apply it to the X
        ret 

    endmodule
