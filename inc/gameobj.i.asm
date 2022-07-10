;------------------------------------------------------------------------------
; gameobj.StartDefinition - Start the definition of the game objects
        macro gameobj.StartDefinition
gameobj.definedAt    equ $
        endm

;------------------------------------------------------------------------------
; gameobj.EndDefinition - End the definition of the game objects
        macro gameobj.EndDefinition
gameobj.count  equ ($-gameobj.definedAt) / gameobj.S_GameObj
        endm

;------------------------------------------------------------------------------
; gameobj.Define - Define a game object
; Parameters:
;   sprite      - Sprite used to render the game object
;   animation   - Animation to apply to the game object. 
;                 gameobj.noAnimation for game objects with no animations
        macro gameobj.Define sprite, animation, flags
            db gameobj.stateActiveSet | gameobj.stateAnimateSet
            dw sprite           ; sprite used to render the game object
            dw animation        ; animator
            db 0                ; animation frame
            db 0                ; ticks since last animation update
            db 0                ; animation update counter
            db 0                ; rotation to apply
            db 0                ; flags
        endm

;------------------------------------------------------------------------------
; gameobj.UpdateAll - Update all the active game objects
        macro gameobj.UpdateAll
            ld b, gameobj.count
            ld ix, gameobj.definedAt
            ld de, gameobj.S_GameObj
.update
            ld a, (ix+gameobj.S_GameObj.state)  ; load state flags
            bit gameobj.stateActiveBit, a
            call nz, gameobj._update            ; only update active objects
            add ix, de
            djnz .update
            sprite.UpdateAll
        endm

;------------------------------------------------------------------------------
; gameobj.Sprite - Load sprite pointer into DE
; Parameters:
;   obj         - Game object to show
        macro gameobj.Sprite obj
            ld hl, obj
            add hl, gameobj.S_GameObj.sprite
            ld e, (hl)
            inc hl
            ld d, (hl)
        endm

;------------------------------------------------------------------------------
; gameobj.Show - Show the specified game object
; Parameters:
;   obj         - Game object to show
        macro gameobj.Show obj
            gameobj.Sprite obj
            sprite.Show de 
        endm

;------------------------------------------------------------------------------
; gameobj.Hide - Hide the specified game object
; Parameters:
;   obj         - Game object to hide
        macro gameobj.Hide obj
            gameobj.Sprite obj
            sprite.Hide de
        endm

;------------------------------------------------------------------------------
; gameobj.SetPos - Set the screen position of the specified game object
; Parameters:
;   obj     - Game object to update
;   xpos    - Game object X
;   ypos    - Game object Y
        macro gameobj.SetPos obj, xpos, ypos
            gameobj.Sprite obj
            sprite.SetPos de, xpos, ypos
        endm

;------------------------------------------------------------------------------
; gameobj.SetAnimation - Change the animation
; Parameters:
;   obj         - Game object to update
;   animimation - New animation
;   flags - Sprite flags (Rotate, MirrorX, MirrorY)
    macro gameobj.SetAnimation obj, animation, flags
        ld ix, obj
        ld hl, animation
        ld a, flags
        call gameobj._setAnimation
    endm        

    module gameobj

    struct S_GameObj
state       byte            ; Game object state flags
sprite      word 0          ; Sprite

animation   word 0          ; Animation (0-For no animation)
frame       byte 0          ; Current animation frame
tick        byte 0          ; Ticks since last animation update
animCtr     byte 0          ; Animation update counter
rotation    byte 0          ; 0-North, 1-East, 2-South, 3-West
flags       byte 0          ; Game object flags (Mirror, Rotate)
    ends

noAnimation equ 0

;------------------------------------------------------------------------------
; gameobj._update - Update the game object
; Input:
;   IX  - Points to the game object to update
_update:
        ld a, (ix+S_GameObj.state)
        bit stateAnimateBit, a      
        ret z             

        push bc
        push de

        ; Load animation into IY
        ld e, (ix+S_GameObj.animation)
        ld d, (ix+S_GameObj.animation+1)
        
        ; check for null animation
        ld a, e
        or d
        jp z, .stopAnimation    ; Stop animation if there is no animation

        ld iyl, e               ; Else load animation to IY
        ld iyh, d

        ; Check if we should update the animation
        ld a, (ix+S_GameObj.tick)
        inc a
        or a
        jp z, .animate          ; If tick was -1 then we will force an animation update
        cp (iy+animation.S_Animation.frameDelay) ; otherwise we check if ticks == frameDelay
        jp nz, .doneAnimation   ; If not, we exit early

.animate
        set stateUpdateBit, (ix+S_GameObj.state) ; Set the update flag
        
        ld a, (ix+S_GameObj.state)
        bit stateRestartBit, a      ; Check if animation should restart
        jp nz, .restartAnimation    

        bit stateAnimRevBit, a      ; Check if animation should be reversed
        jp z, .animateForward       ;  1 - Reverse
        jp .animateBackward    

.animateForward
        ld a, (ix+S_GameObj.frame)
        inc a
        cp (iy+animation.S_Animation.frameCount)
        jp z, .changeDirection
        ld (ix+S_GameObj.frame), a
        jp .resetTicks

.animateBackward
        ld a, (ix+S_GameObj.frame)
        or a
        jp z, .changeDirection
        dec a
        ld (ix+S_GameObj.frame), a
        jp .resetTicks

.changeDirection
        ld a, (iy+animation.S_Animation.mode)
        
        cp animation.modeRotateRight
        jp z, .rotateRight

        cp animation.modeRotateLeft
        jp z, .rotateLeft

        cp animation.modeStop
        jp z, .stopAnimation
        
        cp animation.modeRestart
        jp z, .restartAnimation

        ; Check if there are 2 or more frames to animate otherwise stop the animation
        ld a, (iy+animation.S_Animation.frameCount)
        sub 2
        jp m, .stopAnimation ; stop if there are fewer than 2 frames

        ld a, (ix+S_GameObj.state)
        xor stateAnimRevSet         ; flip direction flag
        ld (ix+S_GameObj.state), a


        bit stateAnimRevBit, a      ; Check if animation should be reversed
        jp nz, .changeDirectionBackward

        inc (ix+S_GameObj.frame)
        jp .resetTicks

.changeDirectionBackward
        dec (ix+S_GameObj.frame)        
        jp .resetTicks
        
.rotateRight
        ld a, (ix+S_GameObj.rotation)
        inc a
        jp .rotateAnimation
.rotateLeft
        ld a, (ix+S_GameObj.rotation)
        dec a
.rotateAnimation
        and %00000011   ; clamp to 0-3
        ld (ix+S_GameObj.rotation), a
        set stateRotateBit, (ix+S_GameObj.state)    ; Set the rotation flag
        ; fall through to .restartAnimation
        ;   |
        ;   |
        ;   v
.restartAnimation:
        res stateRestartBit, (ix+S_GameObj.state) ; Clear the restart flag
        xor a                                     ; Reset to frame 0
        ld (ix+S_GameObj.frame), a   
        jp .resetTicks

.stopAnimation:
        res stateAnimateBit, (ix+S_GameObj.state)

.resetTicks
        ld a, (iy+animation.S_Animation.stopAfter) ; load A with stopAfter
        or a
        jp z, .resetTicksContinue    ; if stopAfter = 0 we animate perpetualy

        inc (ix+S_GameObj.animCtr)   ; increment the animation counter 
        ld b, (ix+S_GameObj.animCtr) ; load B with animation counter
        cp b
        jp nz, .resetTicksContinue   ; Continue if less than stopAfter
        ld (ix+S_GameObj.animCtr), 0 ; reset the counter
        res stateAnimateBit, (ix+S_GameObj.state) ; stop the animation
.resetTicksContinue
        xor a
.doneAnimation   
        ld (ix+S_GameObj.tick), a

; Check if an update is required
.updateGameObj
        ld a, (ix+S_GameObj.state)
        bit stateUpdateBit, a                   ; State in A
        jp z, .doneUpdate
        
        res stateUpdateBit, (ix+S_GameObj.state) ; Reset the update flag

        ; calculate new pattern number IY contains the animation
        ld a, (iy+animation.S_Animation.firstPattern)
        ld b, (ix+S_GameObj.frame)
        add a, b
        and %00111111                           ; Mask pattern bits
        ld b, a                                 ; New pattern number in B

        ; Switch IY to point to the sprite
        ld e, (ix+S_GameObj.sprite)
        ld d, (ix+S_GameObj.sprite+1)
        ld iyl, e
        ld iyh, d

        ; set the sprite pattern
        ld a, (iy+sprite.S_Sprite.vpat)         ; Load current pattern        
        and %11000000                           ; Mask the sprite pattern
        or b                                    ; Set the new pattern from B
        ld (iy+sprite.S_Sprite.vpat), a         ; Update the sprite
        
        ld a, (ix+S_GameObj.state)
        bit stateRotateBit, a                   ; Check if rotation is required
        jp nz, .updateRotation                  ; if so, rotate
                                                ;   else apply visual flags
; Apply visual flags
        ld a, (ix+S_GameObj.flags)
        and flagMirrorXSet | flagMirrorYSet | flagRotateSet
        ld b, a                                 ; Visual flags in B
        ld a, (iy+sprite.S_Sprite.mrx8)
        and flagMirrorXMsk & flagMirrorYMsk & flagRotateMsk
        or b
        ld (iy+sprite.S_Sprite.mrx8), a
        jp .doneUpdate

; Apply rotation
.updateRotation
        ld de, .rotationFlags                   ; Load rotation flags
        ld a, (ix+S_GameObj.rotation)           ; get rotation index
        add de, a                               ; point to the rotation index
        ld a, (de)                              ; A - rotation/mirror flags
        ld b, a                                 ; Store flags in B

        ld a, (iy+sprite.S_Sprite.mrx8)         ; load current visuals
        and %11110001                           ; Mask mirror and rotate bits
        or b                                    ; mix in the rotation/mirror flags
        ld (iy+sprite.S_Sprite.mrx8), a         ; Apply flags

.doneUpdate
        pop de
        pop bc
        ret
;                      ---          R        XY         XYR
.rotationFlags db %00000000, %00000010, %00001100, %00001110


;------------------------------------------------------------------------------
; gameobj._setAnimation - Sets the current animation for the game object
; Input:
;   IX  - game object to update
;   HL  - new animation
;   A   - flags
_setAnimation:
        and flagMirrorXSet | flagMirrorYSet | flagRotateSet
        ld b, a                                     ; Store the sprite flags in B
        ; Check if rotation or mirroring has changed
        ld a, (ix+S_GameObj.flags)   
        and flagMirrorXSet | flagMirrorYSet | flagRotateSet
        cp b
        jp nz, .changeAnimation          

        ; Check if animation has changed
        ld a, (ix+S_GameObj.animation)
        cp l
        jp nz, .changeAnimation
        ld a, (ix+S_GameObj.animation+1)
        cp h
        ret z                                       ; No changes so return
.changeAnimation 
        ld (ix+S_GameObj.tick), -1                  ; Reset the ticks, force update       
        ld (ix+S_GameObj.animation), l              ; update the animation pointer
        ld (ix+S_GameObj.animation+1), h
        ld a, (ix+S_GameObj.state)
        set stateRestartBit, a                      ; force an animation restart
        and stateAnimRevMsk & stateRotateMsk        ; force forward animation and disable rotation
        ld (ix+S_GameObj.state), a                  ; apply changes

        ld a, (ix+S_GameObj.flags)   
        and flagMirrorXMsk | flagMirrorYMsk | flagRotateMsk
        or b                                        ; apply the rotation flags
        ld (ix+S_GameObj.flags), a
        ret

; State bit assignments
stateActiveBit  equ 0
stateAnimateBit equ 1
stateRestartBit equ 2
stateAnimRevBit equ 3
stateUpdateBit  equ 4
stateRotateBit  equ 5


; State masks
stateActiveSet  equ 1 << stateActiveBit
stateAnimateSet equ 1 << stateAnimateBit
stateRestartSet equ 1 << stateRestartBit
stateAnimRevSet equ 1 << stateAnimRevBit
stateUpdateSet  equ 1 << stateUpdateBit
stateRotateSet  equ 1 << stateRotateBit

; State flag clear masks
stateActiveMsk  equ ~stateActiveSet
stateAnimateMsk equ ~stateAnimateSet
stateRestartMsk equ ~stateRestartSet
stateAnimRevMsk equ ~stateAnimRevSet
stateUpdateMsk  equ ~stateUpdateSet
stateRotateMsk  equ ~stateRotateSet


; Flag bit assignments
flagRotateBit   equ 1
flagMirrorYBit  equ 2
flagMirrorXBit  equ 3

; Flag masks
; State flag set masks
flagRotateSet  equ 1 << flagRotateBit
flagMirrorYSet equ 1 << flagMirrorYBit
flagMirrorXSet equ 1 << flagMirrorXBit

; State flag clear masks
flagRotateMsk  equ ~flagRotateSet
flagMirrorYMsk equ ~flagMirrorYSet
flagMirrorXMsk equ ~flagMirrorXSet

    endmodule