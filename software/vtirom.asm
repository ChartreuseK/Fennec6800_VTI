; Fennec 6800 VTI - Option ROM v0.1
; Provides a video terminal interface for the Fennec 6800 instead of 
; using a serial terminal hooked up to UART0 on the Fennec.
; Outputs over composite video or TTL video (mono but 15.7kHz)
;
; Input is provided via a parallel ASCII keyboard over a DIP14 socket
; or DA15 port, and processed through a 6820/6821/6520/6521 PIA
; 
; This ROM installs itself as the default console, while swapping
; the default AUX device to UART0 instead of UART1
;-----------------------------------------------------------------------
	CPU 6800
	
VTIBASE EQU $8000	; EXP6 left most jumper
; 9000 for EXP5, A000 for 4, B000 for 3, C000 for 2, D000 for 1

VIDRAM	EQU VTIBASE
ROMBASE EQU VTIBASE+$800	; Upper 2kB of EXP6
; 6845 VDP ports
CRTADDR	EQU VTIBASE+$7F8	; Lowest mirror
CRTDATA	EQU VTIBASE+$7F9
; 6820 PIA ports
PIABASE EQU VTIBASE+$FF8	; Lowest mirror
PIAORA	EQU PIABASE+0		; ORA/INA/DDRA
PIACRA	EQU PIABASE+1
PIAORB	EQU PIABASE+2		; ORB/INB/DDRB
PIACRB	EQU PIABASE+3

; Peripherals on mainboard 
UART1	EQU $EFF0
UART2	EQU $EFF2

; Zero page VTI addresses
VTIVAR	EQU $0040		; Base for our addresses
SAVEX	EQU VTIVAR+0	; w Place to save word
SCRADDR	EQU VTIVAR+2	; w Screen address pointer
SCRX	EQU VTIVAR+4	; b Cursor X pos
SCRY	EQU VTIVAR+5	; b Cursor Y pos

;-----------------------------------------------------------------------
; Controllable routines in ROM
;  - expect no reg preserved, result if any in A
CONTR	EQU $000C	; Start of controllable routines

CONIN	EQU CONTR	; 3 - JMP to GETC routine for console
CONOUT	EQU CONIN+3	; 3 - JMP TO PUTC routine for console
CONINNB	EQU CONOUT+3	; 3 - JMP to GETC (non-blocking) for console

AUXIN	EQU CONINNB+3	; 3 - JMP to GETC routine for aux 
AUXOUT	EQU AUXIN+3	; 3 - JMP TO PUTC routine for aux 
AUXINNB	EQU AUXOUT+3	; 3 - JMP to GETC (non-blocking) for aux

DEVIN	EQU AUXINNB+3	; 3 - JMP to device routine GETC
DEVOUT	EQU DEVIN+3	; 3 - JMP to device routine PUTC
DEVINNB	EQU DEVOUT+3	; 3 - JMP to device routine GETC (non-blocking)
			;  Device routines take device # in B
			;  0 = console, 1 = uart a, 2 = uart b, 
			;  3+ rom or user defined
CONTRE	EQU DEVINNB+3	; End of controllable routines
;-----------------------------------------------------------------------

	ORG ROMBASE
	DW $F10F	; Flo(o)f signature for a bootable ROM
	DB "VTIROM 0.1"	; 10 character name
	DB 0		; Null terminator
	; 3 bytes reserved for future use
	ORG ROMBASE+16	; Entry point at 16 bytes in
START
	JMP ENTER	; Jump over function table
FTABLE	; Table of functions with a static address for user programs
	JMP INITVDP	; Reset VDP
	JMP LOADVDP	; Load VDP registers with custom table
	JMP CLRSCR
	JMP SCROLL
	JMP HOME
	JMP GETC
	JMP GETCNB
	JMP PUTC
	
ENTER
	; We can assume a usable stack from the monitor
	JSR INITVDP		
	JSR CLRSCR
	JSR HOME
	JSR INSTALL
	RTS		; Return to monitor
	;---------------------------------------------------------------


; Copy VDP register table to VDP
INITVDP
	LDX #CRTTAB
LOADVDP			; (Call here to load with other X)
	CLRB
ILOOP	STAB CRTADDR	; B is current address
	LDAA 0,X	; Value from table
	STAA CRTDATA
	INX
	INCB
	CMPB #16	; 16 registers to fill
	BNE ILOOP
	RTS

; Install handlers into monitor
INSTALL
	LDX #GETC
	STX CONIN+1	; +1 to skip over JMP opcode
	LDX #PUTC
	STX CONOUT+1
	LDX #GETCNB
	STX CONINNB+1
	RTS

;-----------------------------------------------------------------------
; Get character from console
; TODO change to parallel keyboard
GETC    LDAB #$01	; Receive data full
.L      BITB UART1      
	BEQ .L
	LDAA UART1+1
	RTS
	
; Non-blocking GETC
GETCNB	LDAA #0		; 2 - Default return
	LDAB #$01	; 2 - 
	BITB UART1	; 4 -
	BEQ .E		; 4 -
	LDAA UART1+1	; 4 -
.E	TST A		; 2 - Set flags based on A
	RTS		; 5 -

;-----------------------------------------------------------------------
; Print character in A to the screen (preserve X)
PUTC
	PSHA
	PSHB
	STX SAVEX	; Preserve X register
	LDX SCRADDR	; Get screen pointer (assume up to date)
	CMPA #'\r'	; Carriage return
	BEQ .CR
	CMPA #'\n'	; Newline
	BEQ .NL
	CMPA #'\b'	; Backspace
	BEQ .BS
	CMPA #'\t'	; (Horizontal) Tab
	BEQ .TAB
	; Otherwise assume printable character
	STAA 0,X	; Store to the screen
	INC SCRX	; Move to next character in line
	LDAA SCRX	; Check current X pos
	CMPA #64	; If past screen width?
	BNE .END	
	LDAA #0		; Hit width of screen, go to next line
	STAA SCRX	; Return to 0 	JMP S0OUT
	BRA .NL		; Insert newline
.TAB	LDAA SCRX	; 
	ADDA #8		; Add 8 to force going to next tabstop
	ANDA #$F8	; Round down to the next multiple of 8
	STAA SCRX	
	CMPA #64	; IfJSR GETDISP past screen width?
	BNE .END
	LDAA #0		; Hit width of screen? go to next line
	STAA SCRX	; Return to 0
	BRA .NL		; Newline
.CR	LDAA #0		; Simply return to start of line
	STAA SCRX	; Set X pos to 0
	BRA .END
.NL	INC SCRY	; Try and go to the next line
	LDAA SCRY	
	CMPA #24	; If past screen height?
	BNE .END	
	DEC SCRY	; Return back to last line of screen
	JSR SCROLL	; Scroll the screen up one line
	BRA .END
.BS	LDAA SCRX	; Are we at the start of a line?
	BEQ .END	; If so nothing to backspace
	DEC SCRX	; Otherwise move back one pos
	BRA .END
.END	JSR GETDISP	; Recalculate DISP pointer
	LDX SAVEX	; Restore X
	PULB
	PULA
	RTS

;-----------------------------------------------------------------------
; Scroll screen one line
SCROLL
	LDX #VIDRAM
.LOOP	LDAA 64,X	; Read from next line
	STAA 0,X	; to current line
	INX		; Go from top to bottom till we hit the end
	CPX #VIDRAM+(64*23)	; Start of last line of screen
	BNE .LOOP
	; Now clear last line
	BRA CLREND
;-----------------------------------------------------------------------
; Clear screen (fill with spaces)
CLRSCR
	JSR HOME	; Home cursor
	LDX #VIDRAM
CLREND	; Clear to end of screen starting at X
	LDAA #' '	; Space to clear with
.LOOP	STAA 0,X
	INX
	CPX #VIDRAM+(64*24)
	BNE .LOOP
	RTS
	
;-----------------------------------------------------------------------
; Home cursor (0,0)
HOME
	LDAA #0
	STAA SCRX
	STAA SCRY
	JMP GETDISP

;-----------------------------------------------------------------------
; Convert SCRX, SCRY to screen memory address in SCRADDR
GETDISP
	LDAA SCRY
	RORA		; Low 2 bits to upper 2 bits of addr 
	RORA		; 3x because ROR goes through carry
	RORA
	ANDA #$C0	; Low 2 bits of addr in upper 2
	ORAA SCRX	; Or in x position (6-bits = 64)
	STAA SCRADDR+1	; Low byte of screen address
	LDAB #15	; Cursor position register (low byte) in VDP
	STAB CRTADDR	
	STAA CRTDATA	; Set VDP cursor
	LDAA SCRY	; Now get remaining 3 bits of Y addr
	LSRA		
	LSRA		
	DECB		; high byte cursor position register
	STAB CRTADDR
	STAA CRTDATA	; Set VDP cursor (high)
	ORAA #(VIDRAM>>8)	; VIDRAM base addr
	STAA SCRADDR	; Upper byte of pointer to screen complete
	RTS


;-----------------------------------------------------------------------
; 12MHz dot clock
; "NTSC" (B&W) single field progressive "mode"
; 15,720Hz horizontal (approx)
; 60Hz vertical refresh
; 8x8 font
; 64x24
; 
; H-total 95 chars (15,789Hz horizontal)
; H-displayed 64 chars = 42.6us                              51.2 ideal
; H-sync pos = 64chars + 8 +  1.5us =~ 82 chars 1.33us front  1.5 ideal
; H-sync width = 4.7us =~ 7 chars = 4.666us sync              4.7 ideal
; Back porch of 95 chars - 89 chars = 6 chars + 8 = 4us       6.2 ideal
;-----------------------------------------------------------------------
; 1 character (8 pixels) = 666ns
;-----------------------------------------------------------------------
; V-total lines 262 (262.5 but sssh) 
; Characters are 8 lines high
; VTotal = 32.75 -> 31 (subtract one and lose fraction)
; VAdjust = 0.75 * 8 = 6 scanlines
; VDisplayed = 24 (visible rows)  (Up to 28/29 works)
; VSyncPos = 30
; Non interlaced
; 8 scalines per char (-1 = 7)
; Cursor start at 0, blink at 1/32 field rate (5&6 set)
CRTTAB
	DB	95, 64		; R0/R1 H-Total and H-displayed
	DB	76, 7		; R2/R3 HSync Pos and HSync Width
	DB	31, 6		; R4/R5 VTotal and VTotal Adjust
	DB	24, 27		; R6/R7 VDisplayed and VSync Pos
	DB	$00, 7		; R8/R9 Interlace and Max Scan Line
	DB	$66, 7		; R10/R11 Cursor start & end
	DW	$0000		; R12/13 Start address
	DW	$0000		; R14/15 Cursor address
	
	ORG ROMBASE+$7FF
	DB	$FF

	END
