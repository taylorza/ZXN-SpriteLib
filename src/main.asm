        SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
        DEVICE ZXSPECTRUMNEXT
        CSPECTMAP "spritelib.map"

        org     $8000
        
        include <util.i.asm>
        include <sprite.i.asm>
        include <animation.i.asm>
        include <gameobj.i.asm>

main:
        di
        nextreg $7, 0
        
        sprite.EnableSprites
        sprite.ClearSprites
        sprite.Upload 25

        gameobj.Show player
        gameobj.Show car
        gameobj.Show spaceship
        
        gameobj.SetPos player, 64, 64
        gameobj.SetPos car, 32, 32
        gameobj.SetPos spaceship, 128, 128
        
gameLoop:
        WaitForScanline 128
        ld a, 1
        out ($fe), a

        ld a, (y)
        ld hl, dy
        add a, (hl)
        ld (y), a
        cp a, 0
        jr z, .reverse
        cp a, 191
        jr z, .reverse
        jr .update
.reverse        
        ld a, (dy)
        neg
        ld (dy), a
.update
        gameobj.SetPos spaceship, 128, (y)
        gameobj.UpdateAll

        ld a, 6
        out ($fe), a
        jp gameLoop

y       db 0
dy      db 1

;------------------------------------------------------------------------------
; Sprites
        sprite.StartDefinition
playerSprite    sprite.Define 0
carSprite       sprite.Define 21
spaceshipSprite sprite.DefineUnifiedAuto 27, 2, 4, 0    ; Auto create sprite for the ship body which is 2x4
                sprite.DefineRelative 35, 0, 16, 0      ; Define the four relative sprites that form the ship weapon
                sprite.DefineRelative 36, 16, 16, 0     ; these are still relative to the anchor defined by
                sprite.DefineRelative 37, 0, 32, 0      ; sprite.DefineUnifiedAuto. Each of these could be labeled 
                sprite.DefineRelative 38, 16, 32, 0     ; seperately to apply separate animations etc.

        sprite.EndDefinition

;------------------------------------------------------------------------------
; Animations
; firstPattern, frameCount, frameDelay, mode, stopAfter
playerIdleDown  animation.Define 0, 3, 15, animation.modeRestart, 0
playerIdleSide  animation.Define 3, 3, 15, animation.modeRestart, 0
carRotate       animation.Define 21, 3, 5, animation.modeRotateRight, 0

;------------------------------------------------------------------------------
; Game objects
; sprite, animation
        gameobj.StartDefinition
player          gameobj.Define playerSprite, playerIdleDown, 0
car             gameobj.Define carSprite, carRotate, 0
spaceship       gameobj.Define spaceshipSprite, gameobj.noAnimation, 0

        gameobj.EndDefinition


;------------------------------------------------------------------------------
; Stack reservation
STACK_SIZE      equ     100

stack_bottom:
        defs    STACK_SIZE * 2
stack_top:
        defw    0

; Load sprite pattern data into page 25
patternData sprite.Incbin 25, "assets/spaceshooter.spr"

;------------------------------------------------------------------------------
; Output configuration
        SAVENEX OPEN "spritelib.nex", main, stack_top 
        SAVENEX CORE 2,0,0
        SAVENEX CFG 7,0,0,0
        SAVENEX AUTO 
        SAVENEX CLOSE