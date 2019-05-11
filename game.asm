  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;;;;;;;;;;;;;;;

; DECLARE VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
falling .rs 1

goright .rs 1
goleft  .rs 1

rightupcounter .rs 1
rightdowncounter .rs 1

goingrightup .rs 1
goingrightdown .rs 1

leftupcounter .rs 1
leftdowncounter .rs 1

goingleftup .rs 1
goingleftdown .rs 1

rightswitched .rs 1
leftswitched .rs 1

  .bank 0
  .org $C000 

SwitchRightUpDownSub:
  LDA #$0
  STA goingrightup      ;make it go down
  LDA #$1
  STA goingrightdown
  STA rightswitched
  RTI

SwitchLeftUpDownSub:
  LDA #$0
  STA goingleftup       ;make it go down
  LDA #$1
  STA goingleftdown
  STA leftswitched
  RTI

AdvanceFrameFunc:
  LDX $0201
  CPX #$1
  INY

  BEQ MakeFrameZero
  BNE MakeFrameOne
  RTI

MakeFrameZero:
  STY $7FFF
  LDA $7FFF
  LSR A
  LSR A
  LSR A
  BCS MakeFrameOneFinal
MakeFrameZeroFinal:
  LDA #$0
  STA $0201
  RTI

MakeFrameOne:
  STY $7FFF
  LDA $7FFF
  LSR A
  LSR A
  LSR A
  BCS MakeFrameZeroFinal
MakeFrameOneFinal:
  LDA #$1
  STA $0201
  RTI

RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2
  LDA #$1
  STA falling
  LDA #$0


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
              

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010010   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ;latch buttons

;===============================================
;BUTTON READING STRUCTURE
;===============================================
; ReadButton:             start of function
;   LDA $4016             read controller value
;   AND #%00000001        read only bit 0
;   BEQ ReadButtonDone    if 0 then go to end
;                         if 1 then dont branch and move on
;
;   Do stuff 
;
; ReadButtonDone:         end of function


ReadA: 
  LDA $4016
  AND #%00000001
  BEQ ReadADone  

ContinueReadA:
  LDA #%01000000        ;flip sprite horizontally to the right
  STA $0202

  LDA #$1                 ;Set all variables to zero to have an ability to ascend
  STA goright
  STA goingrightup
  LDA #$0
  STA rightdowncounter
  STA rightupcounter
  STA goingrightdown
  STA goingrightdown
  STA rightswitched

  STA goleft
  STA leftupcounter
  STA leftdowncounter
  STA goingleftup
  STA goingleftdown
  STA leftswitched

  JMP JumpRight           ;jump to function

SwitchRightUpDown:          ;stop moving up and go down
  JSR SwitchRightUpDownSub

ReadADone:
  
JumpRight:
  LDA goright       ;dont go right constantly
  CMP #$1
  BEQ ContinueRight ;use trick to extend reach of code pointer
  JMP JumpRightEnd  ;leave cycle if variable not set

ContinueRight:
  LDA #$0
  STA falling

JumpUpRightLoop:          ;start a loop to move right and up diagonally
  LDA goingrightdown      ;see if the bird is supposed to move downwards
  CMP #$1
  BEQ JumpUpRightLoopEnd

  LDA #$1                 ;prevent it drom going down
  STA goingrightup
  LDA #$0
  STA goingrightdown

  INC rightupcounter      ;make a counter for the amount of frames the bird is going up
  LDA rightupcounter
  CMP #$05
  BEQ JumpUpRightLoopEnd

  LDA $0200     ;move sprite up
  CLC
  SBC #$02
  STA $0200

  LDA $0203     ;move sprite right
  CLC
  ADC #$02
  STA $0203
JumpUpRightLoopEnd:       ;verify that the cycle above is completed and that it can now go down
  LDA rightswitched
  CMP #$1
  BEQ JumpDownRightLoop
  LDA rightupcounter
  CMP #$05
  BEQ SwitchRightUpDown

JumpDownRightLoop:        ;go down
  LDA goingrightup          ;see if the bird is supposed to go down
  CMP #$1
  BEQ JumpDownEightLoopEnd

  LDA #$1                   ;prevent it from going up
  STA goingrightdown
  LDA #$0
  STA goingrightup

  INC rightdowncounter        ;make a counter to count how many frames the bird goes down
  LDA rightdowncounter
  CMP #$08
  BEQ JumpDownRightLoopEnd

  LDA $0200     ;move sprite down
  CLC
  ADC #$02
  STA $0200

  LDA $0203     ;move sprite right
  CLC
  ADC #$02
  STA $0203
JumpDownRightLoopEnd:

CheckBothVarsRight:
  LDA rightdowncounter          ;see if both cycles have completed
  CMP #$08
  BNE CheckBothVarsRightEnd
  LDA rightupcounter
  CMP #$05
  BNE CheckBothVarsRightEnd

  LDA #$0
  STA goright

  LDA #$1                       ;make bird fall again
  STA falling

CheckBothVarsRightEnd:

JumpRightEnd:

;==========================================
;THIS SECTION WORKS PRETTY MUCH THE SAME AS
;           THE PREVIOUS ONE
;==========================================

ReadB: 
  LDA $4016
  AND #%00000001
  BEQ ReadBDone

ContinueReadB:
  LDA #%00000000        ;flip sprite horizontally to the left
  STA $0202

  LDA #$1                 ;disable right jump
  STA goleft
  STA goingleftup
  LDA #$0
  STA goright
  STA rightdowncounter
  STA rightupcounter
  STA goingrightdown
  STA goingrightdown
  STA rightswitched

  STA leftupcounter
  STA leftdowncounter
  STA goingleftup
  STA goingleftdown
  STA leftswitched

  JMP JumpLeft

SwitchLeftUpDown:
  JSR SwitchLeftUpDownSub

ReadBDone:

JumpLeft:
  LDA goleft       ;dont go left constantly
  CMP #$1
  BEQ ContinueLeft
  JMP JumpLeftEnd

ContinueLeft:
  LDA #$0
  STA falling

JumpUpLeftLoop:
  LDA goingleftdown
  CMP #$1
  BEQ JumpUpLeftLoopEnd

  LDA #$1
  STA goingleftup
  LDA #$0
  STA goingleftdown

  INC leftupcounter
  LDA leftupcounter
  CMP #$05
  BEQ JumpUpLeftLoopEnd

  LDA $0200     ;move sprite up
  CLC
  SBC #$02
  STA $0200

  LDA $0203     ;move sprite right
  SEC
  SBC #$02
  STA $0203
JumpUpLeftLoopEnd:
  LDA leftswitched
  CMP #$1
  BEQ JumpDownLeftLoop
  LDA leftupcounter
  CMP #$05
  BEQ SwitchLeftUpDown

JumpDownLeftLoop:

  LDA goingleftup
  CMP #$1
  BEQ JumpDownLeftLoopEnd

  LDA #$1
  STA goingleftdown
  LDA #$0
  STA goingleftup

  INC leftdowncounter
  LDA leftdowncounter
  CMP #$08
  BEQ JumpDownLeftLoopEnd

  LDA $0200     ;move sprite down
  CLC
  ADC #$02
  STA $0200

  LDA $0203     ;move sprite left
  SEC
  SBC #$02
  STA $0203
JumpDownLeftLoopEnd:

CheckBothVarsLeft:
  LDA leftdowncounter
  CMP #$08
  BNE CheckBothVarsLeftEnd
  LDA leftupcounter
  CMP #$05
  BNE CheckBothVarsLeftEnd

  LDA #$0
  STA goleft

  LDA #$1
  STA falling

CheckBothVarsLeftEnd:

JumpLeftEnd:

ReadSelect:
  LDA $4016
  AND #%00000001
  BEQ ReadSelectDone
ReadSelectDone:

ReadStart:
  LDA $4016
  AND #%00000001
  BEQ ReadStartDone
ReadStartDone:
  
ReadUp:
  LDA $4016
  AND #%0000001
  BEQ ReadUpDone
ReadUpDone:

ReadDown:
  LDA $4016
  AND #%00000001
  BEQ ReadDownDone
ReadDownDone:

ReadLeft:
  LDA $4016
  AND #%00000001
  BEQ ReadLeftDone
ReadLeftDone:

ReadRight:
  LDA $4016
  AND #%00000001
  BEQ ReadRightDone
ReadRightDone:

Fall:               ;fall
  LDA falling       ;see if supposed to fall
  CMP #$0
  BEQ DontFall

  LDA $0200         ;move down
  CLC
  ADC #$02
  STA $0200
DontFall:

AdvanceFrame:
  JMP AdvanceFrameFunc

  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$30,$06,$27,$06,$30,$16

sprites:
     ;vert tile attr horiz
  .db $80, $01, $00, $80   ;sprite 0
  .db $50, $11, $00, $60

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "game.chr"   ;includes 8KB graphics file from SMB1