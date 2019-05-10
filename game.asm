  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;;;;;;;;;;;;;;;

; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
falling .rs 1
goright .rs 1
goleft  .rs 1

rightupcounter .rs 1
rightdowncounter .rs 1

goingrightup .rs 1
goingrightdown .rs 1

switched .rs 1

  .bank 0
  .org $C000 

SwitchRightLeftSub:
  LDA #$0
  STA goingrightup
  LDA #$1
  STA goingrightdown
  STA switched
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

  LDA #%00010000   ; enable sprites
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

  LDA #$1                 ;disable left jump
  STA goright
  STA goingrightup
  LDA #$0
  STA goleft
  STA rightdowncounter
  STA rightupcounter
  STA goingrightdown
  STA goingrightdown
  STA switched
  JMP JumpRight

SwitchRightLeft:
  JSR SwitchRightLeftSub

ReadADone:
  

JumpRight:
  LDA goright       ;dont go right constantly
  CMP #$1
  BEQ Continue
  JMP JumpRightEnd

Continue:
  LDA #$0
  STA falling

JumpUpRightLoop:
  LDA goingrightdown
  CMP #$1
  BEQ JumpUpRightLoopEnd

  LDA #$1
  STA goingrightup
  LDA #$0
  STA goingrightdown

  INC rightupcounter
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
JumpUpRightLoopEnd:
  LDA switched
  CMP #$1
  BEQ JumpDownRightLoop
  LDA rightupcounter
  CMP #$05
  BEQ SwitchRightLeft

JumpDownRightLoop:

  LDA goingrightup
  CMP #$1
  BEQ JumpDownRightLoopEnd

  LDA #$1
  STA goingrightdown
  LDA #$0
  STA goingrightup

  INC rightdowncounter
  LDA rightdowncounter
  CMP #$05
  BEQ JumpDownRightLoopEnd

  LDA $0200     ;move sprite down
  SEC
  ADC #$02
  STA $0200

  LDA $0203     ;move sprite right
  CLC
  ADC #$02
  STA $0203
JumpDownRightLoopEnd:

CheckBothVars:
  LDA rightdowncounter
  CMP #$05
  BNE CheckBothVarsEnd
  LDA rightupcounter
  CMP #$05
  BNE CheckBothVarsEnd

  LDA #$0
  STA goright

  LDA #$1
  STA falling

CheckBothVarsEnd:

JumpRightEnd:

ReadB: 
  LDA $4016
  AND #%00000001
  BEQ ReadBDone
ReadBDone:

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

  ; LDA $0200
  ; SEC
  ; SBC #$02
  ; STA $0200
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

  LDA #%00000000        ;flip sprite horizontally to the left
  STA $0202

  ; LDA $0203
  ; SEC
  ; SBC #$02
  ; STA $0203
ReadLeftDone:

ReadRight:
  LDA $4016
  AND #%00000001
  BEQ ReadRightDone

  LDA #%01000000        ;flip sprite horizontally to the right
  STA $0202
ReadRightDone:

Fall:
  LDA falling
  CMP #$0
  BEQ DontFall

  LDA $0200
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
  .db $0F,$30,$07,$27

sprites:
     ;vert tile attr horiz
  .db $80, $01, $00, $80   ;sprite 0

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