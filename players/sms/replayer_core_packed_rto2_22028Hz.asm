;----------------------------------------------------------------------------
; Copyright (C) 2006 Arturo Ragozini and Daniel Vik
;
; This software is provided 'as-is', without any express or implied
; warranty. In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
; claim that you wrote the original software. If you use this software
; in a product, an acknowledgment in the product documentation would be
; appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
; misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;----------------------------------------------------------------------------

; Modified in 2016 by Maxim for operation on Sega 8-bit consoles (and similar 
; hardware with IO-mapped SN76489 variants)

;
; Replayer core to play packed-volume 44kHz samples generated by pcmenc
;
; pcmenc should use the following command line arguments:
;
; pcmenc -rto 2 -p 4 -dt1 157 -dt2 11 -dt3 157 file.wav
;
; and optionally -r to split sample into blocks for rom replayer
;

; There are three channel updates per two underlying samples.
; One channel update is for the odd samples, the other two are
; for the even ones. We try to make these second two as close together 
; as possible, and equalise the spacing to the first. 
; The total loop length is 325 cycles, to match an underlying sample 
; at 22050Hz (3579545 / 325 * 2 = 22028).

;-------------------------------------
; Plays one sample
; HL - pointes to triplet count followed by data
;-------------------------------------
PLAY_SAMPLE:
  ld e, (hl)
  inc hl
  ld d, (hl)
  inc hl
  ld bc, $007f ; for out (c),r
  
.macro GetHi
  ld a,(hl)       ; 7
  .repeat 4
  rra             ; 16
  .endr
  and $0f         ; 7
.endm             ; Total 30

.macro GetLo
  ld a,(hl)       ; 7
  inc hl          ; 6
  and $0f         ; 7
.endm             ; Total 14

PsgLoop:
  ; Get high nibble and play channel 0
  rld             ; 18 Get high nibble at hl into low nibble of a, will trash RAM data. Faster then getting it and shifting 4 times
  and $f          ;  7
  or (0<<5) | $90 ;  7
  out (c), a      ; 12 <-- 0 (157 cycles)
  
  call Delay82    ; 82
  
  ; Get low nibble, increment and store in b
  ld a,(hl)       ;  7
  inc hl          ;  6
  and $f          ;  7
  or (1<<5) | $90 ;  7
  ld b,a          ;  4
  
  ; Get high nibble and set for channel 2
  rld             ; 18
  and $f          ;  7
  or (2<<5) | $90 ;  7
    
  ; Emit
  out (c),b       ; 12 <-- 1 (157 cycles)
  out ($7f),a     ; 11 <-- 2 (11 cycles)
  
  ; Check counter
  ; Decrement length and return if zero
  dec de          ;  6
  ld a,d          ;  4
  or e            ;  4
  ret z           ;  5

  ; =======================================
  
  call Delay99    ; 99
  
  ; Get low nibble, increment and play channel 0
  ld a,(hl)       ;  7
  inc hl          ;  6
  and $f          ;  7
  or (0<<5) | $90 ;  7
  out (c), a      ; 12 <-- 0 (157 cycles)

  call Delay82    ; 82
  
  ; Get high nibble and store in b
  rld             ; 18
  and $f          ;  7
  or (1<<5) | $90 ;  7
  ld b,a          ;  4
  
  ; Get low nibble, increment and set for channel 2
  ld a,(hl)       ;  7
  inc hl          ;  6
  and $f          ;  7
  or (2<<5) | $90 ;  7
  
  ; Emit
  out (c),b       ; 12 <-- 1 (157 cycles)
  out ($7f),a     ; 11 <-- 2 (11 cycles)
  
  call Delay87
  
  ; Check counter
  ; Decrement length and return if zero
  dec de          ;  6
  ld a,d          ;  4
  or e            ;  4
  jr nz, PsgLoop  ; 12
  
  
  ; =====================================
  ret

  ; This is a big ugly...
Delay105:
  push bc         ; 11
    ld b,0        ;  7
    jp Delay77    ; 10

Delay99:
  push bc         ; 11
    ld b,0        ;  7
    jr Delay69    ; 12

Delay87:
  push bc         ; 11
    ld b,0        ;  7
    jr Delay57    ; 12

Delay82:
  push bc         ; 11
    jp Delay61    ; 10

Delay77:  nop     ;  4
Delay73:  nop     ;  4
Delay69:  nop     ;  4
Delay65:  nop     ;  4
Delay61:  nop     ;  4
Delay57:  nop     ;  4
Delay53:  nop     ;  4
Delay49:  nop     ;  4
Delay45:  nop     ;  4
Delay41:  nop     ;  4
Delay37: pop bc   ; 10
Delay27: ret      ; 10
  ; (calls to get here cost 17)