;--------------------------------------------------------------------------
; ReadNextReg - Read a Next Register
; Parameters:
;   reg     - Next register to read
; Output:
;   A       - Value read from the register
        macro ReadNextReg reg
                ld a, reg
                call util._readNextReg
        endm

        module util
;------------------------------------------------------------------------------
; WaitForScanline - Wait for a specific scanline
; Paremeters:
;       line - Scanline to wait for
        macro WaitForScanline line
                ld de, line
                call util._waitForScanline
        endm

;------------------------------------------------------------------------------
; _readNextReg - Read a Next Register
; Input:
;   A       - Next register to read
; Output:
;   A       - Value read from the register
_readNextReg:
        push bc
        ld bc, $243b
        out (c), a
        inc b
        in a, (c)
        pop bc
        ret

;------------------------------------------------------------------------------
; _write8bitPalette - Write 8 bit color data to the palette
; Input:
;   HL      - Color data
;   B       - Entries to write
;   C       - Starting entry
;   A       - Palette to write to
;             0 - ULA - 1
;             4 - ULA - 2
;             1 - Layer 2  - 1
;             5 - Layer 2  - 2
;             2 - Sprite - 1
;             6 - Sprite - 2
;             3 - Tilemap - 1
;             7 - Tilemap - 2
_write8bitPalette:
        ld a, c
        nextreg $40, a  ; set start index
.write8bitEntry    
        ld a, (hl)
        nextreg $41, a
        inc hl
        djnz .write8bitEntry
        ret

;------------------------------------------------------------------------------
; _waitForScanline - Wait for a specific scanline
; Input:
;       E - Scanline to wait for
_waitForScanline:
.tooSoon
        ld bc, $243b
        ld a, $1f       ; 1F - Scanline LSB
        out (c), a      ; Select the register
        
        inc b           ; Move to the data port
        in a, (c)       ; Read the current scanline
        cp e            ; Compare it to the target scanline
        jr z, .tooSoon  ; Delay 1 frame for fast game loops

.wait   
        in a, (c)       ; Read the current scanline
        cp e            ; Compare it to the target scanline
        jr nz, .wait    ; If not there yet, try again
        ret

;------------------------------------------------------------------------------
; _waitForScanline - Wait for a specific scanline
; Input:
;       DE - Scanline to wait for
_waitForScanlineFull:
        push af
        push de
        push hl

.tooSoon
        call .loadScanline
        or a
        sbc hl, de
        jp z, .tooSoon

.wait   
        call .loadScanline
        or a
        sbc hl, de
        jp nz, .wait
        pop af
        pop de
        pop hl
        ret

.loadScanline           ; Read current scanline into HL
        ld bc, $243b
        ld a, $1e        ; 1E - Scanline MSB
        out (c), a
        inc b
        in a, (c)
        ld h, a

        dec b
        ld a, $1f       ; 1F - Scanline LSB
        out (c), a
        inc b
        in a, (c)
        ld l, a
        ret
    endmodule