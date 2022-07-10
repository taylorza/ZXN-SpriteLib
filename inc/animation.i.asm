;------------------------------------------------------------------------------
; animation.Define - Define an animation
; Parameters:
;   firstPattern    - first pattern of the animation sequence
;   frameCount      - frames in animation
;   frameDelay      - ticks between frame transitions
;   mode            - animation mode : modeStop, modeRestart, modeReverse 
;   stopAfter       - animated frames to compled before stopping the animation, 0-infinite
                    
    macro animation.Define firstPattern, frameCount, frameDelay, mode, stopAfter
        db firstPattern, frameCount, frameDelay, mode, stopAfter
    endm

    module animation
    
    struct S_Animation
firstPattern    byte 0
frameCount      byte 0
frameDelay      byte 0
mode            byte 0  ; 0-stop, 1-restart, 2-reverse
stopAfter       byte 0  ; 0-infinite, n-animation frames to complete
    ends

modeStop        equ 0
modeRestart     equ 1
modeReverse     equ 2
modeRotateRight equ 3
modeRotateLeft  equ 4
    endmodule

    