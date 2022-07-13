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
            db 0                ; animation frame index
            db 0                ; ticks since last animation update
            db 0                ; animation update counter
            db 0                ; rotation
            db flags            ; flags and rotation index
            db -1               ; Pattern to apply to the sprite
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
            add ix, de                          ; move to the next object
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
; gameobj.SetFlags - Set the flags for the game object (mirror/rotate)
; Parameters:
;   obj         - Game object to update
;   flags - Sprite flags (Rotate, MirrorX, MirrorY)
    macro gameobj.SetFlags obj, flags
        ld ix, obj
        ld a, flags
        call gameobj._setFlags
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
pattern     byte            ; Pattern to apply to sprite -1 for no change
    ends

noAnimation equ 0

;------------------------------------------------------------------------------
; gameobj._update - Update the game object
; Input:
;   IX  - Points to the game object to update
_update:
        push bc
        push de
        
        ld a, (ix+S_GameObj.state)
        bit stateAnimateBit, a
        call nz, _updateAnimation
 
        ld a, (ix+S_GameObj.state)
        bit stateUpdateBit, a
        call nz, _updateGameObj

        pop de
        pop bc
        ret

; IX - Points to the game object
_initGameObject:
        ret

; IX - Points to the game object
_updateAnimation:
        ; Load animation into DE
        ld e, (ix+S_GameObj.animation)
        ld d, (ix+S_GameObj.animation+1)
        
        ; check for null animation
        ld a, e
        or d
        jp z, .stopAnimation            ; Stop animation if there is no animation

        ; Point IY to the animation
        ld iyl, e
        ld iyh, d

        ; check if it is time for a new animation frame
        ld a, (ix+S_GameObj.tick)
        inc a                           
        or a                            
        jp z, .animate                          ; If tick was -1, we will force the animation update
        cp (iy+animation.S_Animation.frameDelay); Is it time for the next update?
        jp nz, .updateTicks                     ; If not, skip everything a update the tick

.animate
        set stateUpdateBit, (ix+S_GameObj.state); Set the update flag as we will be animating

        ld a, (ix+S_GameObj.state)

        bit stateRestartBit, a                  ; Should the animation be restarted
        jp nz, .restartAnimation                ;       If so, lets do that now

        bit stateRotateBit, a                   ; Should the animation be rotated
        jp nz, .rotate                          ;       If so, lets do the rotation

        bit stateAnimRevBit, a                  ; Test reverse bit
        ld a, (ix+S_GameObj.frame)              ; Load the current frame (no effect on the flags)
        jp nz, .animateBackward                 ; If reverse bit set, jump to .animateBackward
                                                ; else 
                                                ;  |
                                                ;  V
        ; Animate forwards
        inc a                                   ; Increment the frame index
        jp .checkAnimation

        ; Animate backwards
.animateBackward
        dec a                                   ; Decrement the frame index

.checkAnimation
        ld (ix+S_GameObj.frame), a              ; Store the new frame
        or a                                    ; If this is the first frame
        jp z, .endSequence                      ;       handle the end of the animation sequence
        cp (iy+animation.S_Animation.frameCount); If this is the last frame
        jp z, .endSequence                      ;       handle the end of the animation sequence
                                                ; else
        jp .postAnimation                       ;       run the post animation code
        
.endSequence
        ld a, (iy+animation.S_Animation.mode)
        
        cp animation.modeStop
        jp z, .stopAnimation

        ; Decide on the action when we reach the end on the animation sequence
        cp animation.modeRotateRight
        jp z, .setRotate
        
        cp animation.modeRotateLeft
        jp z, .setRotate
        
        cp animation.modeRestart
        jp z, .setRestart

        ; If none of the above, then it must be modeReverse
        ld a, (ix+S_GameObj.state)
        xor stateAnimRevSet                     ; Toggle the reverse direction flag
        ld (ix+S_GameObj.state), a
        
        jp .postAnimation

.setRotate
        set stateRotateBit, (ix+S_GameObj.state)
        jp .postAnimation

.setRestart
        set stateRestartBit, (ix+S_GameObj.state)
        jp .postAnimation

.rotate
        ld a, (iy+animation.S_Animation.mode)
        cp animation.modeRotateLeft
        jp z, .rotateLeft

.rotateRight
        ld a, (ix+S_GameObj.rotation)
        inc a
        jp .applyRotation

.rotateLeft
        ld a, (ix+S_GameObj.rotation)
        dec a

.applyRotation
        res stateRotateBit, (ix+S_GameObj.state); Clear the rotation flag
        and %00000011                           ; Clamp to 0..3
        ld (ix+S_GameObj.rotation), a           ; Update with the new rotation id
        ; fall through to .restartAnimation
        ;    |
        ;    |
        ;    V
.restartAnimation
        res stateRestartBit, (ix+S_GameObj.state); Clear the restart flag
        ld (ix+S_GameObj.frame), 0               ; Set the frame index to 0
        jp .postAnimation

.stopAnimation
        res stateAnimateBit, (ix+S_GameObj.state); Clear the animation flag to prevent further animation
        
.postAnimation    
        ; Update the pattern for the game object
        ld a, (iy+animation.S_Animation.firstPattern)
        add (ix+S_GameObj.frame)
        ld (ix+S_GameObj.pattern), a
        
        ; Check if a stopAfter frame limit was set
        ld a, (iy+animation.S_Animation.stopAfter)
        or a
        jp z, .resetTicks

        inc (ix+S_GameObj.animCtr)              ; Increment the counter
        cp (ix+S_GameObj.animCtr)               ; Have we reached the stop limit?
        jp nz, .resetTicks                      ;       If not, we continue
                                                ; else
        ld (ix+S_GameObj.animCtr), 0            ;       Reset the animation counter and
        res stateAnimateBit, (ix+S_GameObj.state);      stop the animation
.resetTicks
        xor a                                   ; Reset the ticks to 0
.updateTicks
        ld (ix+S_GameObj.tick), a
        ret

;------------------------------------------------------------------------------
; IX - Game Object
_updateGameObj:
        res stateUpdateBit, (ix+S_GameObj.state); Clear the update flag
        ld a, (ix+S_GameObj.state)

        ; Load sprite into IY
        ld e, (ix+S_GameObj.sprite)
        ld d, (ix+S_GameObj.sprite+1)
        ld iyl, e
        ld iyh, d

; Apply rotation
.updateRotation
        ld de, .rotationTbl                     ; Load rotation table
        ld a, (ix+S_GameObj.rotation)           ; get rotation index
        add de, a                               ; point to the rotation index
        ld a, (de)                              ; A - rotation/mirror flags
        ld b, a                                 ; Store flags in B

        ld a, (iy+sprite.S_Sprite.mrx8)         ; load current visuals
        and %11110001                           ; Mask mirror and rotate bits
        or b                                    ; mix in the rotation/mirror flags
        ld (iy+sprite.S_Sprite.mrx8), a         ; Apply flags

.updateSpritePattern
; Update sprite pattern
        ld a, (iy+sprite.S_Sprite.vpat)         ; Load current pattern        
        and %11000000                           ; Mask the sprite pattern
        or (ix+S_GameObj.pattern)               ; Set the pattern from B
        ld (iy+sprite.S_Sprite.vpat), a         ; Update the sprite
        ret
;                      ---          R        XY         XYR
.rotationTbl db %00000000, %00000010, %00001100, %00001110

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
        and flagMirrorXMsk & flagMirrorYMsk & flagRotateMsk
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

; Flag set masks
flagRotateSet  equ 1 << flagRotateBit
flagMirrorYSet equ 1 << flagMirrorYBit
flagMirrorXSet equ 1 << flagMirrorXBit

; Flag clear masks
flagRotateMsk  equ ~flagRotateSet
flagMirrorYMsk equ ~flagMirrorYSet
flagMirrorXMsk equ ~flagMirrorXSet

    endmodule