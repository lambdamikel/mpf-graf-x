; LCD 3D Frame Demonstation Program
; ---------------------------------
; By B. Chiha May-2023

; This program is based off an article published in The Amstrad User Issue 69, 
; October 1990.  The program was written in BASIC, I've converted it to Z80

; There are two parts to this program.  Drawing a 3D point in 2D space and rotating
; the 3D points around on of three axis, X, Y and Z
;
; To draw a 3D point on a 2D cartesian plane.  The X and Y component are just plotted as 
; they are, The Z component is used to give depth to the X,Y point.  A positive Z value
; will make the X,Y point closer to the edges of the screen to give it the impression
; it is closer to the eye.  And a negative value will make the point closer to the center
; of the screen.  This gives the impression that it is far away.
;
; The formular to calculate depth is logarithmic and is 2^Z.  This is then multipled 
; to the X and Y values.  Once done a size facter is used to convert the point to LCD 
; coordinates.
;
; To rotate the 3D points, A Rotational Matrix is used.  These use a combination of 
; SINE and COSINE values to two of the points.  To make things easier, each
; rotation is done at 10 degrees.  But a SIN/COS function can be used if needed.
;
; As the math involved in rotating and displaying points is complex, number with 
; floating points are needed.  Any point or data that requires a decimal place uses
; Fixed Point numbering.  I have used Fixed Point 8.8, where a value in a sixteen bit
; Regisiter like HL, has the Interger part in H and the fraction part in L. or H.L
; Lets say HL is 1234, where H=0x12 and L=0x34.  To convert this number to decimal
; 0x12 is now 18 and 0x34 is 52/256 = 0.203125 which becomes 18.203125.  This is 
; sufficient precision for what is needed.
;
; Lastly, as the depth factor is 2^Z, it is recommened to have all points for the 3D
; shapes between -1 and 1 or 0xFF00 and 0x0100 (Fixed Point 8.8 notation).  Otherwise
; values greater than 1 become too skewed.

        ORG 1800H
	; ORG 7000H

VDP      	equ 	$00f0

;------------------------------------------------------------------------
;  Constants
;------------------------------------------------------------------------

PLUS            EQU     0x10            ;+ key           Guess higher
MINUS           EQU     0x11            ;- key           Guess lower
GO              EQU     0x12            ;GO key          Accept input
DATA            EQU     0x14            ;DATA key        Give up, MPF next
DEL             EQU     0x17            ;DEL key         Clear input
PC              EQU     0x18            ;PC key          Cheat
REG             EQU     0x1B            ;REG key         Restart program

SA              EQU     00001000B       ;Segment A
SB              EQU     00010000B       ;Segment B
SC              EQU     00100000B       ;Segment C
SD              EQU     10000000B       ;Segment D
SE              EQU     00000001B       ;Segment E
SF              EQU     00000100B       ;Segment F
SG              EQU     00000010B       ;Segment G
DP              EQU     01000000B       ;Decimal point

;------------------------------------------------------------------------
;  Monitor routines
;------------------------------------------------------------------------

SCAN            EQU     0x05FE          ;Scan display until a key pressed
SCAN1           EQU     0x0624          ;Scan display once
HEX7            EQU     0x0689          ;Convert digit to 7-segement
HEX7SG          EQU     0x0678          ;Convert 2 hex digits to 7-segment
TONE            EQU     0x05E4          ;Generate tone (C=freq, HL=cycles)
TONE1K          EQU     0x05DE          ;Sound a 1kHz tone during (HL)
TONE2K          EQU     0x05E2          ;Sound a 2kHz tone during (HL)


; Varibles	
V_MID_X:	EQU 80			;Center X of LCD
V_MID_Y:	EQU 64			;Center Y of LCD
V_SHAPE_TOTAL:	EQU 1		;Total Shapes

; Constants for SIN and COS at 10˚.  	
C_SIN10:	EQU 2CH 		;SIN(10) = 0.173648 or 44/256.  44 = 0x2C
C_COS10:	EQU 0FCH 		;COS(10) = 0.984808 or 252/256.  252 = 0xFC
        
START:

	LD HL, COL
	LD (HL), 1

	LD HL, BCOL
	LD (HL), 0

	LD HL, PLAYBACK
	LD (HL), 0

	LD HL, DBUFFER
	LD (HL), 1

	LD HL, SHOWINFO
	LD (HL), 1

	LD A, 0
	LD (INDEX), A

	LD A, 0
	LD (LENGTH), A

        CALL G_INIT_GRAFX
        LD A, 0		; Shape 0 = Cube; more shapes can be added as memory permits
	
;Get Shape Data. 
        ADD A, A
        LD H, 00H
        LD L, A
        LD DE, SHAPES
        ADD HL, DE
        LD A, (HL)
        INC HL
        LD H, (HL)
        LD L, A
;Copy Shape to working area
        LD DE, POINTS
        LD A, (HL)
        LD B, A
        ADD A, A 		;Point Total x 2
        ADD A, B 		;Point Total + 1
        ADD A, A        ;Point Total x 2
        LD C, A
        LD A, 00H
        LD B, 00H
        ADC A, B		;Update B with Carry if needed
        LD B, A
        INC BC			;Include Points total
        INC BC			;Include Size
        LDIR
	
        
;Draw Shape to LCD
;-----------------
DRAW_SHAPE:

        CALL G_START_CUBE_DRAW_TO_BUFFER    	;Clear display

        LD HL, POINTS 	;Iterate through points
        LD A, (HL) 		;Number of points
        LD (POINT_COUNT), A ;Store Current points left
        INC HL			;Move to size
        INC HL 			;Move to first real point
POINTS_LOOP:	
;Get X,Y,Z from the POINTS Data and place on stack.
        LD C, (HL) 		;P(X) Value
        INC HL
        LD B, (HL)
        INC HL
        PUSH BC 		;Store P(X) on Stack
        LD C, (HL) 		;P(Y) Value
        INC HL
        LD B, (HL)
        INC HL
        PUSH BC 		;Store P(Y) on Stack
        LD C, (HL) 		;P(Z) Value
        INC HL
        LD B, (HL)
        INC HL
        PUSH BC 		;Store P(Z) on Stack
;Save Points Address
        PUSH HL
        POP IY 			;Save HL in IY for later
        
;Mag = 2^P(Z) or e^(Z * ln(2))
        POP HL 			;P(Z)
        CALL POWER_2_X 	;Calculate 2^P(Z)
;P(Y) * Mag
        POP DE 			;P(Y)
        PUSH HL 		;Save Mag
        LD B, H
        LD C, L 		;Move HL -> BC
        CALL MULT_DExBC ;Calculate P(Y) x Mag
;new Y = SIZE * (P(Y) * M)
        LD D, H
        LD E, L 		;Move HL -> DE
        LD A, (POINTS+1)
        LD B, A 		;Set BC to Size Factor
        LD C, 00H
        CALL MULT_DExBC ;Calculate new Y
;Store new Y on Stack (Pop Mag and P(X) first)
        POP BC 			;Get Mag
        POP DE 			;Get P(X)
        PUSH HL 		;Store new Y
;P(X) * Mag
        CALL MULT_DExBC ;Calculate P(X) x Mag
;new X = SIZE * (P(X) * Mag)
        LD D, H
        LD E, L 		;Move HL -> DE
        LD A, (POINTS+1)
        LD B, A 		;Set BC to Size Factor
        LD C, 00H
        CALL MULT_DExBC ;Calculate new X
;Store new X on Stack
        PUSH HL 		;Store new X
;Check if all points are done, or second point is to loaded
        LD HL, POINT_COUNT
        DEC (HL) 		;Next Point
        BIT 0, (HL) 	;If its an odd number?
        PUSH IY
        POP HL 			;Restore HL for next point if needed
        JR NZ, POINTS_LOOP ;Get the second point
        
;Both Points X,Y are saved on the stack.  Draw them to the LCD Buffer
;Note: Points are in 8.8, LCD only takes integers, so ROUND to the nearest
;      integer. Stack has X1,Y1,X0,Y0 if you pop in this order
        
        POP HL 			;Ger first Point X1
        CALL ROUND_HL 	;Round it
        ADD A, V_MID_X 	;Center it
        LD D, A 		;X1
        POP HL 			;Ger first Point Y1
        CALL ROUND_HL 	;Round it
        ADD A, V_MID_Y 	;Center it
        LD E, A 		;Y1
        POP HL 			;Ger second Point X0
        CALL ROUND_HL 	;Round it
        ADD A, V_MID_X 	;Center it
        LD B, A 		;X1
        POP HL 			;Ger second Point Y0
        CALL ROUND_HL 	;Round it
        ADD A, V_MID_Y 	;Center it
        LD C, A 		;Y1
        
        CALL G_DRAW_LINE ;DRAW a line from BC to DE to Graph Buffer
        
        LD A, (POINT_COUNT) ;Check for any more points left?
        OR A
        JR Z, DISPLAY_IMAGE ;No points left, so Display to LCD
        PUSH IY
        POP HL 			;Restore Current Points pointer
        JR POINTS_LOOP 	;Get the next two points
        
;All points are plotted to GBUF, now Display the LCD and wait for KEY Press
DISPLAY_IMAGE:	
        CALL G_CUBE_FINISHED_DRAW
	
GET_KEY:

	LD	A,(PLAYBACK)
	OR	A
	JR 	Z, ENTER_KEY

PLAYBACK_LOOP:

	LD HL,	LENGTH	; end of buffer?
	LD A, (HL)
	LD B, A

	LD HL, INDEX 	; get key from RECORD buffer 
	LD A, (HL)	; get index 

	CP B
	JR NZ, GET_NEXT_ENTRY

	; reached end of buffer, wrap around 

	LD HL, INDEX
	LD A, 0
	LD (INDEX), A

GET_NEXT_ENTRY:

	INC (HL)	; get next entry from buffer; prepare index point for next round 
	LD B, 0
	LD C, A
	LD HL, RECORD
	ADD HL, BC

	LD A, (HL)
	JP DISPATCH_KEY	

ENTER_KEY:

	LD      IX,MENUTEXT
	ld 	hl,DSPBFFR
	ld	b, 6

	call scan

	CP      DATA              ; Was it the DATA key?
	JR	NZ, CONTINUE_SCANNING

	;; VDP playback - set start index to 0

	call G_REPLAY
	
	JP GET_KEY

CONTINUE_SCANNING: 

        CP      GO              ; Was it the GO key?
	JR	NZ, CONTINUE_SCANNING1 

;;	GO key = Enter PLAYBACK MODE 

	LD HL, PLAYBACK
	LD (HL), 1

	LD A, (INDEX)
	LD (LENGTH), A

	LD A, 0
	LD (INDEX), A

	JP GET_KEY

CONTINUE_SCANNING1: 

        CP      PC              ; Was it the PC key?
	JR	NZ, CONTINUE_SCANNING2

	LD HL, DBUFFER
	LD A, (HL)
	LD B, A
	LD A, 1
	SUB B

	LD (DBUFFER), A

	LD A, (DBUFFER) 
	OR A
	JR Z, CONTA
	LD HL, 100
	CALL TONE1K
	CALL G_DBUFFERING_ON 
	JP GET_KEY
CONTA:
	LD HL, 100
	CALL TONE2K
	CALL G_DBUFFERING_OFF 
	JP GET_KEY


CONTINUE_SCANNING2: 

        CP      REG              ; Was it the REG key?
	JR	NZ, CONTINUE_SCANNING3 

	LD HL, SHOWINFO 
	LD A, (HL)
	LD B, A
	LD A, 1
	SUB B

	LD (SHOWINFO), A

	LD A, (SHOWINFO) 
	OR A
	JR Z, CONTB
	LD HL, 100
	CALL TONE1K
	CALL G_INFO_ON
	JP GET_KEY
CONTB:
	LD HL, 100
	CALL TONE2K
	CALL G_INFO_OFF
	JP GET_KEY

CONTINUE_SCANNING3: 

        CP      1
	JR	NZ, CONTINUE_SCANNING4

	LD A, (COL)
	INC A
	LD (COL), A
	
	CALL G_SET_COL 
	JP GET_KEY
	
CONTINUE_SCANNING4: 

        CP      2
	JR	NZ, RECORD_AND_DISPATCH_KEY 

	LD A, (BCOL)
	INC A
	LD (BCOL), A
	
	CALL G_SET_BCOL 
	JP GET_KEY	

RECORD_AND_DISPATCH_KEY:

	PUSH AF		; push key into RECORD buffer
	LD HL, INDEX
	LD A, (HL)
	INC (HL)	; point to next entry
	LD B, 0
	LD C, A
	LD HL, RECORD
	ADD HL, BC
	POP AF 
	LD (HL), A	

DISPATCH_KEY:

        CP PLUS 	;Plus Key
        JR Z, ADJUST_SIZE
        CP MINUS 	;Minus Key
        JR Z, ADJUST_SIZE

        RRCA 			;Check for keys 0,4,8,C by shifting
        RRCA 			;twice to the right..Clever!
        CP 04H 			;Compare with 4 to see if valid key
        JP NC, GET_KEY 	;All other keys have higher bits set
        
;Select Rotation based on key 1,2,3 (or '4', '8', 'C' on Keypad)
;If 0 is pressed, jump to Start Menu
        ADD A, A 		;Double A
        LD H, 00H
        LD L, A
        LD DE, ROT_LUT 	;Point DE to Rotate Look up table
        ADD HL, DE 		;Index it
        LD A, (HL)
        INC HL
        LD H, (HL)
        LD L, A
        JP (HL) 		;Jump to Rotation Routine (or Start)
        
;Size of Object Adjustment.
;Input A, 10=increase, 11=decrease
ADJUST_SIZE:	
        LD B, A
        LD A, 01H 		;Default to plus
        RRC B 			;Check to see if its a negative
        JR NC, $ + 4
        NEG
        LD B, A
        LD A, (POINTS+1)
        ADD A, B 		;Modify size factor
        LD (POINTS+1), A 	;Save it back
        JP DRAW_SHAPE 	;Redraw shape
        
;Rotate Points around the X Axis
;P'(Y) = COS(𝛉) * P(Y) + SIN(𝛉) * P(Z)
;P'(Z) = COS(𝛉) * P(Z) - SIN(𝛉) * P(Y)
ROTATE_X:	
        LD HL, POINTS 	;Iterate through points
        LD A, (HL) 		;Number of points
        LD (POINT_COUNT), A ;Store Current points left
        INC HL          ;Skip Size
        INC HL 			;Move to first real point
ROTX_LOOP:	
        CALL SAVE_POINTS ;Store P(X),P(Y) and P(Z) in RAM for easy access
;Save Points Address
        PUSH HL
        POP IY 			;Save HL in IY for later
;P'(Y) = COS(𝛉) * P(Y) + SIN(𝛉) * P(Z)
        LD DE, (OP2)
        LD (OP4), DE 	;Save for P'(Z) calculation
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(Y)
        PUSH HL 		;Store value on stack
        LD DE, (OP3)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(Z)
        POP DE 			;Retrived first operand
        ADD HL, DE 		;Add to get new point
        LD (OP2), HL 	;Save new P(Y)
;P'(Z) = COS(𝛉) * P(Z) - SIN(𝛉) * P(Y)
        LD DE, (OP3)
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(Z)
        PUSH HL 		;Store value on stack
        LD DE, (OP4)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(Y)
        POP DE 			;Retrived first operand
        EX DE, HL
        OR A 			;Clear Carry
        SBC HL, DE 		;Subtract to get new point
        LD (OP3), HL 	;Save new P(Z)
;Update Original Points with new ones
        PUSH IY
        POP HL 			;Get Original HL
        CALL OP_TO_POINTS ;Move Operands back to Points and Return
        LD A, (POINT_COUNT) ;Check for any more points left?
        DEC A 			;One Vector down
        LD (POINT_COUNT), A ;Save new points left
        JP Z, DRAW_SHAPE ;No, Exit and Draw new shape
        JR ROTX_LOOP 	;Yes, Do next three points
        
;Rotate Points around the Y Axis
;P'(X) = COS(𝛉) * P(X) - SIN(𝛉) * P(Z)
;P'(Z) = SIN(𝛉) * P(X) + COS(𝛉) * P(Z)
ROTATE_Y:	
        LD HL, POINTS 	;Iterate through points
        LD A, (HL) 		;Number of points
        LD (POINT_COUNT), A ;Store Current points left
        INC HL          ;Skip Size
        INC HL 			;Move to first real point
ROTY_LOOP:	
        CALL SAVE_POINTS ;Store P(X),P(Y) and P(Z) in RAM for easy access
;Save Points Address
        PUSH HL
        POP IY 			;Save HL in IY for later
;P'(X) = COS(𝛉) * P(X) - SIN(𝛉) * P(Z)
        LD DE, (OP1)
        LD (OP4), DE 	;Save for P'(X) calculation
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(X)
        PUSH HL 		;Store value on stack
        LD DE, (OP3)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(Z)
        POP DE 			;Retrived first operand
        EX DE, HL
        OR A 			;Clear Carry
        SBC HL, DE 		;Subtract to get new point
        LD (OP1), HL 	;Save new P(X)
;P'(Z) = SIN(𝛉) * P(X) + COS(𝛉) * P(Z)
        LD DE, (OP4)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(X)
        PUSH HL 		;Store value on stack
        LD DE, (OP3)
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(Z)
        POP DE 			;Retrived first operand
        ADD HL, DE 		;Add to get new point
        LD (OP3), HL 	;Save new P(Z)
;Update Original Points with new ones
        PUSH IY
        POP HL 			;Get Original HL
        CALL OP_TO_POINTS ;Move Operands back to Points and Return
        LD A, (POINT_COUNT) ;Check for any more points left?
        DEC A 			;One Vector down
        LD (POINT_COUNT), A ;Save new points left
        JP Z, DRAW_SHAPE ;No, Exit and Draw new shape
        JR ROTY_LOOP 	;Yes, Do next three points
        
;Rotate Points around the Z Axis
;P'(X) = COS(𝛉) * P(X) + SIN(𝛉) * P(Y)
;P'(Y) = COS(𝛉) * P(Y) - SIN(𝛉) * P(X)
ROTATE_Z:	
        LD HL, POINTS 	;Iterate through points
        LD A, (HL) 		;Number of points
        LD (POINT_COUNT), A ;Store Current points left
        INC HL          ;Skip Size
        INC HL 			;Move to first real point
ROTZ_LOOP:	
        CALL SAVE_POINTS ;Store P(X),P(Y) and P(Z) in RAM for easy access
;Save Points Address
        PUSH HL
        POP IY 			;Save HL in IY for later
;P'(X) = COS(𝛉) * P(X) + SIN(𝛉) * P(Y)
        LD DE, (OP1)
        LD (OP4), DE 	;Save for P'(X) calculation
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(X)
        PUSH HL 		;Store value on stack
        LD DE, (OP2)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(Y)
        POP DE 			;Retrived first operand
        ADD HL, DE 		;Add to get new point
        LD (OP1), HL 	;Save new P(X)
;P'(Y) = COS(𝛉) * P(Y) - SIN(𝛉) * P(X)
        LD DE, (OP2)
        LD BC, C_COS10 	;COS(10)
        CALL MULT_DExBC ;Calculate COS(𝛉) * P(Y)
        PUSH HL 		;Store value on stack
        LD DE, (OP4)
        LD BC, C_SIN10 	;SIN(10)
        CALL MULT_DExBC ;Calculate SIN(𝛉) * P(X)
        POP DE 			;Retrived first operand
        EX DE, HL
        OR A 			;Clear Carry
        SBC HL, DE 		;Subtract to get new point
        LD (OP2), HL 	;Save new P(Y)
;Update Original Points with new ones
        PUSH IY
        POP HL 			;Get Original HL
        CALL OP_TO_POINTS ;Move Operands back to Points and Return
        LD A, (POINT_COUNT) ;Check for any more points left?
        DEC A 			;One Vector down
        LD (POINT_COUNT), A ;Save new points left
        JP Z, DRAW_SHAPE ;No, Exit and Draw new shape
        JR ROTZ_LOOP 	;Yes, Do next three points
        
;Rotation Look up table and menu.  For buttons 0,4,8 and C
ROT_LUT:	
        DW START, ROTATE_X, ROTATE_Y, ROTATE_Z
        
;SAVE Points X,Y,Z pointed by HL into Temporaly Operators
;Input: HL pointing to 16 bit Point data X,Y,Z
;Output: HL remains unchanged from Input
SAVE_POINTS:	
;Get X,Y,Z from the POINTS Data and place on stack.
        PUSH HL 		;Save HL
        LD BC, 0006H 	;Six Bytes
        LD DE, OP1 		;First Temperaly Operand
        LDIR 			;Copy
        POP HL 			;Restore HL
        RET
        
;Store Temporarly Operands back to Points, Move HL to start of next point
OP_TO_POINTS:	
        EX DE, HL 		;Save HL
        LD BC, 0006H 	;Six Bytes
        LD HL, OP1 		;First Temperaly Operand
        LDIR 			;Copy
        EX DE, HL 		;Restore HL
        RET
        
;------------------
;Menu Display
;------------------
; Here is a little example of how to use most of the Graphic Functions in the
; lcd_128x65_glib.z80 file.
DISPLAY_MENU:	
	ret      


MENUTEXT:       DB     SA+SF+SE+SD	      ;C
	        DB     SA+SB+SC+SD+SE+SF+SG   ;8 
	        DB     SF+SG+SB+SC            ;4
	        DB     SF+SG+SE+SD            ;t
	        DB     SG+SE+SD+SC            ;o
	        DB     SE+SG                  ;r


;------------------
;Maths Routines
;------------------
; Treat these routines as Black Boxes.  Not much documentation here.  Assume all
; registers get corrupted except for IN/OUT Registers.  For more information see:
; https://learn.cemetech.net/index.php?title=Z80:Advanced_Math
        
;Multiply D.E by B.C and cater for negative D.E
;Input: D.E x B.C
;Return: H.L
MULT_DExBC:	
        LD IX, 0000H
        ADD IX, BC 		;Set up for Negative DE
        BIT 7, D 		;Check for negative
        JP Z, BC_Times_DE ;Just Multipy and exit
        CALL BC_Times_DE
        PUSH IX
        POP DE
        LD B, E
        LD C, 00H
        OR A
        SBC HL, BC 		;Subtract DE * 256 from HL
        RET
        
;Two to the Power of H.L and cater for negative H.L
;Input: H.L
;Return: H.L
POWER_2_X:	
        BIT 7, H 		;Check for negative
        JP Z, POW2_X 	;Positive, just calculate H.L
        CALL NEG_HL 	;Negate H.L
        CALL POW2_X 	;Calculate 2^H.L
        EX DE, HL
        CALL DE_INV 	;Calculate 1/D.E
        EX DE, HL
        RET
        
;Round H.L to the nearest Integer.  0-7F down, 80-FF up
;Input: H.L
;Output: A (Rounded H)
ROUND_HL:	
        LD A, L
        RLCA
        LD A, 00H
        ADC A, H
        RET
        
;B.C times D.E.  Use H.L for 8.8 values
;Return: BH.LA
BC_TIMES_DE:	
;  BC*DE->BHLA
        LD A, B
        LD HL, 0
        LD B, H
        ADD A, A
        JR NC, $ + 5
        LD H, D
        LD L, E
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, B
        PUSH HL
        LD H, B
        LD L, B
        LD B, A
        LD A, C
        LD C, H
        ADD A, A
        JR NC, $ + 5
        LD H, D
        LD L, E
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        ADD HL, HL
        RLA
        JR NC, $ + 4
        ADD HL, DE
        ADC A, C
        POP DE
        LD C, A
        LD A, L
        LD L, H
        LD H, C
        ADD HL, DE
        RET NC
        INC B
        RET
        
;1/D.E or Inverse of D.E
;Input/Output: D.E
DE_INV:	
        LD HL, 256
        LD B, 8
INVLOOP:	
        ADD HL, HL
        SBC HL, DE
        JR NC, $ + 3
        ADD HL, DE
        RLA
        DJNZ INVLOOP
        CPL
        LD E, A
        LD D, B
        RET
        
;Negate HL
;Input: HL
;Output: HL
NEG_HL:	
        XOR A
        SUB L
        LD L, A
        SBC A, A
        SUB H
        LD H, A
        RET
        
;Two to the Power of H.L
;Inputs: HL is the 8.8 fixed point number 'x' for 2^x
;Outputs: DEHL is the 24.8 fixed point result. Use H.L for 8.8
POW2_X:	
        LD A, L
        OR A
        PUSH HL 		;SAVE H FOR LATER, H IS THE INTEGER PART OF THE POWER
        LD H, 1
        JR Z, INTEGERPOW
        SCF
        RRA
        JR NC, $ - 1
        LD HL, 2 * 256
POWLOOP:	
        PUSH AF
        CALL SQRTHL_PREC12 ;SQRT(H.L). RETURNS IN HL
        POP AF
        SRL A
        JR Z, INTEGERPOW
        JR NC, POWLOOP
        ADD HL, HL
        JP POWLOOP
INTEGERPOW:	
        POP BC
        LD DE, 0
        LD A, B
        OR A
        RET Z
        
        ADD HL, HL
        RL E
        RL D
        JR C, WAYOVERFLOW
        DJNZ $ - 7
        RET
WAYOVERFLOW:	
        LD HL, - 1
        LD D, H
        LD E, L
        RET
        
;Square Root of H.L
;Inputs: H.L
;Output: H.L
SQRTHL_PREC12:	
        XOR A
        LD B, A
        
        LD E, L
        LD L, H
        LD H, A
        
        ADD HL, HL
        ADD HL, HL
        CP H
        JR NC, $ + 5
        DEC H
        LD A, 4
        
        ADD HL, HL
        ADD HL, HL
        LD C, A
        SUB H
        JR NC, $ + 6
        CPL
        LD H, A
        INC C
        INC C
        
        LD A, C
        ADD HL, HL
        ADD HL, HL
        ADD A, A
        LD C, A
        SUB H
        JR NC, $ + 6
        CPL
        LD H, A
        INC C
        INC C
        
        LD A, C
        ADD HL, HL
        ADD HL, HL
        ADD A, A
        LD C, A
        SUB H
        JR NC, $ + 6
        CPL
        LD H, A
        INC C
        INC C
        
        LD A, C
        LD L, E
        
        ADD HL, HL
        ADD HL, HL
        ADD A, A
        LD C, A
        SUB H
        JR NC, $ + 6
        CPL
        LD H, A
        INC C
        INC C
        
        LD A, C
        ADD HL, HL
        ADD HL, HL
        ADD A, A
        LD C, A
        SUB H
        JR NC, $ + 6
        CPL
        LD H, A
        INC C
        INC C
        
        LD A, C
        ADD A, A
        LD C, A
        ADD HL, HL
        ADD HL, HL
        JR NC, $ + 6
        SUB H
        JP $ + 6
        SUB H
        JR NC, $ + 6
        INC C
        INC C
        CPL
        LD H, A
        
        LD A, L
        LD L, H
        ADD A, A
        LD H, A
        ADC HL, HL
        ADC HL, HL
        SLA C
        INC C
        RL B
        SBC HL, BC
        JR NC, $ + 3
        ADD HL, BC
        SBC A, A
        ADD A, A
        INC A
        ADD A, C
        LD C, A
        
        ADD HL, HL
        ADD HL, HL
        SLA C
        INC C
        RL B
        SBC HL, BC
        JR NC, $ + 3
        ADD HL, BC
        SBC A, A
        ADD A, A
        INC A
        ADD A, C
        LD C, A
        
        ADD HL, HL
        ADD HL, HL
        SLA C
        INC C
        RL B
        SBC HL, BC
        JR NC, $ + 3
        ADD HL, BC
        SBC A, A
        ADD A, A
        INC A
        ADD A, C
        LD C, A
        
        ADD HL, HL
        ADD HL, HL
        SLA C
        INC C
        RL B
        SBC HL, BC
        JR NC, $ + 3
        ADD HL, BC
        SBC A, A
        ADD A, A
        INC A
        ADD A, C
        LD C, A
        
        ADD HL, HL
        ADD HL, HL
        SLA C
        INC C
        RL B
        SBC HL, BC
        JR NC, $ + 3
        ADD HL, BC
        SBC A, A
        ADD A, A
        INC A
        ADD A, C
        LD C, A
        
        SRL B
        RR C
        LD H, B
        LD L, C
        RET

;------------------------------------

delay: 
;       push de 
;       ld de, $00ff
;       ld b,e          ; Number of loops is in DE
;       dec de          ; Calculate DB value (destroys B, D and E)
;       inc d
;delay1:
    ; ... do something here
	    
;    djnz delay1
;    dec d
;    jp nz,delay1
	    
;    pop de 
	    
ret 


G_INIT_GRAFX:	 

	;;
	;; Init 
	;; 

	ld a, $fe 
	ld bc, VDP
	out (c), a
	call delay

	ret 

G_SET_COL:

	ld a, $f2	; SET PALETTE COLOR -> sync
	ld bc, VDP
	out (c), a
	call delay

	ld a, (COL) 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR	

	ret
	
G_SET_BCOL:

	ld a, $f3	; SET PALETTE COLOR -> sync
	ld bc, VDP
	out (c), a
	call delay

	ld a, (BCOL) 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR	

	ret

G_DBUFFERING_ON: 

	ld a, $fc 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR	
	call G_REPLAY

	ret 

G_DBUFFERING_OFF: 

	ld a, $fb 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR	
	call G_REPLAY

	ret 

G_INFO_ON: 

	ld a, $f7 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR
	call G_REPLAY

	ret 

G_INFO_OFF: 

	ld a, $f6 
	ld bc, VDP
	out (c), a
	call delay

	call G_SYNC_CLEAR
	call G_REPLAY

	ret 


G_DRAW_LINE:

        ;; CALL G_DRAW_LINE ;DRAW a line from BC to DE to Graph Buffer

	push bc ; bc -> hl 	
	pop hl 

	push de
	push bc 
	push hl
	
	call delay 

	ld bc, VDP
	ld a, $a0
	out (c), a

	call delay 

	ld bc, VDP
	ld a, h
	out (c), a

	call delay 

	ld bc, VDP
	ld a, l
	out (c), a

	call delay 

	ld bc, VDP
	ld a, d
	out (c), a

	call delay

	ld bc, VDP
	ld a, e
	out (c), a

	call delay

	pop hl
	pop bc
	pop de 

	ret


G_START_CUBE_DRAW_TO_BUFFER:

	push bc

	;; set current colors -> buffer
	
	ld a, $e0	; background 
	ld bc, VDP
	out (c), a
	call delay

	ld a, (BCOL) 
	ld bc, VDP
	out (c), a
	call delay

	ld a, $82	; foreground 
	ld bc, VDP
	out (c), a
	call delay

	ld a, (COL)	
	ld bc, VDP
	out (c), a
	call delay

	;; clear screen -> buffer 

	ld a, $80 
	ld bc, VDP
	out (c), a
	call delay

	pop bc
	ret

G_SYNC_CLEAR:

	push bc

	ld a, $f5 ;; clear immediately, not buffered! 
	ld bc, VDP
	out (c), a
	call delay

	pop bc
	ret

G_CUBE_FINISHED_DRAW:

	push bc

	ld bc, VDP
	ld a, $84  ; draw bitmap fast if use_canvas 
	out (c), a

	call delay 

	ld bc, VDP ; enter, redraw command buffer 
	ld a, $ff
	out (c), a

	call delay 

	pop bc
	ret

G_REPLAY:

	push bc

	ld bc, VDP
	ld a, $fd ;; reset start index 
	out (c), a

	call delay 

	ld a, $ff ;; replay 
	ld bc, VDP
	out (c), a

	call delay

	pop bc
	ret


;------------------------------------


;Data Section
;------------
        
SHAPES:	
        DW CUBE
        
;Each point is a 16-bit, signed fixed point value in the format of 8.8
;   EG: -1.00 = FF00, 1.00 = 0100
;Where the first byte is the Integer Part and the second byte the Fraction part
; Data for the shape is as follows:
;		-	Number of Points
;		- 	Default Magnification Size
;		-	X0,Y0,Z0 and X1,Y1,Z1
;			- More Line Points
;
; The first two bytes of data is the total number of 3D points and the initial
; size of the magnification.  The next set of data are 6 Words (two bytes) of
; X, Y and Z data for two points.  These points are in Fixed Point 8.8 format
; and a line will be drawn between these points.  Include as many point pairs
; as indicated with the number of points data.

; NOTE: It is recommend to constrain all the points to be between -1.00 and 1.00

;Cube Data
CUBE:	
; Number of 3D Points and Default size
        DB 24, 1CH
; Bottom
        DW 0FF80H, 0FF80H, 0FF80H, 0080H, 0FF80H, 0FF80H ; (-0.5,-0.5,-0.5),(0.5,-0.5,-0.5)
        DW 0080H, 0FF80H, 0FF80H, 0080H, 0080H, 0FF80H ; (0.5,-0.5,-0.5),(0.5,0.5,-0.5)
        DW 0080H, 0080H, 0FF80H, 0FF80H, 0080H, 0FF80H ; (0.5,0.5,-0.5),(-0.5,0.5,-0.5)
        DW 0FF80H, 0080H, 0FF80H, 0FF80H, 0FF80H, 0FF80H ; (-0.5,0.5,-0.5),(-0.5,-0.5,-0.5)
; Top
        DW 0FF80H, 0FF80H, 0080H, 0080H, 0FF80H, 0080H ; (-0.5,-0.5,0.5),(0.5,-0.5,1)
        DW 0080H, 0FF80H, 0080H, 0080H, 0080H, 0080H ; (0.5,-0.5,0.5),(0.5,0.5,0.5)
        DW 0080H, 0080H, 0080H, 0FF80H, 0080H, 0080H ; (0.5,0.5,0.5),(-0.5,0.5,0.5)
        DW 0FF80H, 0080H, 0080H, 0FF80H, 0FF80H, 0080H ; (-0.5,0.5,0.5),(-0.5,-0.5,0.5)
; Front
        DW 0FF80H, 0FF80H, 0FF80H, 0FF80H, 0FF80H, 0080H ; (-0.5,-0.5,-0.5),(-0.5,-0.5,0.5)
        DW 0080H, 0FF80H, 0FF80H, 0080H, 0FF80H, 0080H ; (0.5,-0.5,-0.5),(0.5,-0.5,0.5)
; Back
        DW 0FF80H, 0080H, 0FF80H, 0FF80H, 0080H, 0080H ; (-0.5,0.5,-0.5),(-0.5,0.5,0.5)
        DW 0080H, 0080H, 0FF80H, 0080H, 0080H, 0080H ; (0.5,0.5,-0.5)(0.5,0.5,0.5)


	org 2000h

;Working RAM Area.  Place this area in RAM if needed.
POINTS:	
        DS 0130H 		;304 Bytes is enough for 50 3D Points (x,y,z)
POINT_COUNT:	
        DB 00H			;Number of points remaining to plot
OP1:	DW 0000H 		;Temporaly Operand 1
OP2:	DW 0000H 		;Temporaly Operand 2
OP3:	DW 0000H 		;Temporaly Operand 3
OP4:	DW 0000H 		;Temporaly Operand 4
        
DSPBFFR:
	DS     6               ;6 Bytes display buffer
RECORD:
	DS     256             ;256 Bytes record buffer
LENGTH:
	DB     00H	       ;Number of entries
INDEX:
	DB     00H	       ;Pointer to record buffer
PLAYBACK:
	DB     00H	       ;Playback on/off
DBUFFER:
	DB     01H	       ;Double buffering on/off
SHOWINFO:
	DB     01H	       ;Show buffer status on/off 
COL:
	DB     01H	       ;Color
BCOL:
	DB     01H	       ;Background Color
