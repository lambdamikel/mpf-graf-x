	org $1800

;------------------------------------------------------------------------
;
;  guess.asm
;
;  Number guessing game
;
;  Author : San Bergmans
;  Source : www.sbprojects.com
;  Date   : 25-1-2006
;
;------------------------------------------------------------------------
;
;  Human and computer will take turns to guess each other's secret number
;  in the range from 0 to 1023 (inclusive).
;
;------------------------------------------------------------------------


;------------------------------------------------------------------------
;  Constants
;------------------------------------------------------------------------

PLUS            EQU     $10            ;+ key           Guess higher
MINUS           EQU     $11            ;- key           Guess lower
GO              EQU     $12            ;GO key          Accept input
DATA            EQU     $14         ;DATA key        Give up, MPF next
DEL             EQU     $17            ;DEL key         Clear input
PC              EQU     $18            ;PC key          Cheat
REG             EQU     $1B            ;REG key         Restart program

SA              EQU     00001000B       ;Segment A
SB              EQU     00010000B       ;;Segment B
SC              EQU     00100000B       ;Segment C
SD              EQU     10000000B       ;Segment D
SE              EQU     00000001B       ;Segment E
SF              EQU     00000100B       ;Segment F
SG              EQU     00000010B       ;Segment G
DP              EQU     01000000B       ;Decimal point

;------------------------------------------------------------------------
;  Monitor routines
;------------------------------------------------------------------------

SCAN            EQU     $05FE          ;Scan display until a key pressed
SCAN1           EQU     $0624          ;Scan display once
HEX7            EQU     $0689          ;Convert digit to 7-segement
HEX7SG          EQU     $0678          ;Convert 2 hex digits to 7-segment
TONE            EQU     $05E4          ;Generate tone (C=freq, HL=cycles)
TONE1K          EQU     $05DE          ;Sound a 1kHz tone during (HL)

VDP      	EQU 	$00f0
MAXLINES	EQU	14
	
;------------------------------------------------------------------------
;  GUESS
;  Start of the program.
;  Now it's your turn to guess the secret number.
;  Enter your guess and press GO to see whether you should guess higher
;  (indicated by an H) or lower (indicated by an L)
;------------------------------------------------------------------------

GUESS:		CALL 	INIT_VDP

		ld hl, LINECOUNT
		ld (hl), 0
	
        	LD      A,R            
                LD      (SEED),A

AGAIN:          CALL    RANDOM         

                LD      IX,TEXT       
                XOR     A           
                LD      (INPUT),A
                LD      (INPUT+1),A
                LD      (DSPBFFR),A   
                LD      (COUNTER),A     
                
                CALL    INIT_SPEECH
                LD      HL, SPEECH1 
                CALL    SPEAK_STRING

LOOP1:        ;  Main loop during human tur
                CALL    SCAN            ; Show display until key pressed

                CP      10              ; Was it a digit key?
                JR      NC,NODIGIT      ; No!

                CALL    DEC2BIN         ; Add digit to input value
                JR      LOOP1           ; Show intermediate result!


NODIGIT:        CP      REG             ; Was it the REG key?
                JR      Z,GUESS         ; Yes! Restart the program

                CP      DEL             ; Was it the DEL key?
                JR      NZ,NOTDEL       ; No! Don't clear value
                XOR     A               ; Clear the input value
                LD      (INPUT),A
                LD      (INPUT+1),A
                CALL    SHOW_VAL        ; Show this value
                ;CALL    SPEAK_VAL       ; Speak Value 
                ;CALL    SHOW_VAL
                JR      LOOP1           ; And wait for input again!

NOTDEL:         CP      PC              ; Was it the PC key?
                JR      NZ,NOTPC        ; Nope!
                CALL    PEEK            ; Give us a peek at the secret!
                JR      LOOP1           ; And continue where we left off!

NOTPC:          CP      GO              ; Was it the GO key?
                JR      NZ,NOTGO        ; Nope!
                
                CALL    SPEAK_VAL       ; Speak Value 
                CALL    SHOW_VAL
                LD      HL,COUNTER      ; Increment try counter
                INC     (HL)
                JR      NZ,SKIP         ; No overflow!
                DEC     (HL)            ; Stop at ridiculous 255 tries
SKIP:           CALL    COMPARE         ; Compare input value to target
                LD      A, B            ;  Guessed the number?
                AND     A               ; (test flags)
                JR      NZ,LOOP1        ; Nope!
                JR      CORRECT         ; Yes!

NOTGO:          CP      DATA            ; DATA key?
                JR      NZ,LOOP1        ; Nope! Ignore the key then
                
                PUSH BC
                PUSH HL
                LD HL, SPEECH10
                CALL SPEAK_STRING 
                POP HL
                POP BC
                
                JP      COMPUTER        ; We give up, let the MPF try

TEXT:           DB     0
                DB     SA+SC+SD+SF+SG         ;S
                DB     SA+SC+SD+SF+SG         ;S
                DB     SA+SD+SE+SF+SG         ;E
                DB     SB+SC+SD+SE+SF         ;U
                DB     SA+SC+SD+SE+SF         ;G

;------------------------------------------------------------------------
;  CORRECT
;  We've guess the number correctly. Show YES and the number of tries now
;------------------------------------------------------------------------

CORRECT:        LD      C,68            ; Sound short beep
                LD      HL,47           ; (same as default system beep)
                CALL    TONE            ; Sound beep

                LD      A,(COUNTER)     ; Convert number of tries to
                CP      100             ; decimal & 7-segment, limited
                JR      C,SKIP1         ; to 99
                LD      A, 99
SKIP1:          LD      (INPUT),A
                XOR     A               ; Counter is only 1 byte, so clear
                LD      (INPUT+1),A     ; MSB
                CALL    SHOW_VAL
                
                PUSH    HL
                PUSH    BC 
                LD      HL, SPEECH4     ; Nice job - you got it! 
                CALL    SPEAK_STRING    ; You needed 
                LD      HL, SPEECH5     ; "n" 
                CALL    SPEAK_STRING    ; 
                LD      A, (INPUT)
                CALL    SPEAK_VAL
                LD      HL, SPEECH6
                CALL    SPEAK_STRING    ; tries. 
                POP BC
                POP HL
                CALL    SHOW_VAL 
                
                LD      A,SD+SE+SF+SG   ; Show "t" behind number of tries
                LD      (HL),A
                LD      HL,DSPBFFR+5    ; Show "YES." in front of counter
                LD      A,SB+SC+SD+SF+SG
                LD      (HL),A
                DEC     HL
                LD      A,SA+SD+SE+SF+SG
                LD      (HL),A
                DEC     HL
                LD      A,SA+SC+SD+SF+SG+DP
                LD      (HL),A
                CALL    SCAN            ; Show this until a key is pressed
                JP      COMPUTER        ; Now it's the MPF's turn to guess

;------------------------------------------------------------------------
;  DEC2BIN
;  A new digit was entered. Multiply previous input value by 10, then add
;  the new digit to form the updated input value.
;------------------------------------------------------------------------

DEC2BIN:        LD      B,A             ; Save new digit
                LD      A,(INPUT)       ; Get previous value
                LD      L,A
                LD      A,(INPUT+1)
                LD      H,A

                ADD     HL,HL           ; Multiply input value by 10
                JR      C,OVERFLOW      ; Number is too big!
                LD      D,H             ; (x * 10 = x * 2 + x * 8)
                LD      E,L
                ADD     HL,HL
                JR      C,OVERFLOW
                ADD     HL,HL
                JR      C,OVERFLOW
                ADD     HL,DE
                JR      C,OVERFLOW

                LD      A,B             ; Add new input digit to it
                ADD     A,L
                LD      (INPUT),A
                LD      A,0
                ADC     A,H
                LD      (INPUT+1),A
                JP      NC,SHOW_VAL     ; Digit added! Show current value

OVERFLOW:       LD      IX,ERROR        ; Show ERROR
                XOR     A               ; Clear the input value
                LD      (INPUT),A
                LD      (INPUT+1),A
                RET

ERROR:          DB     0
                DB     SE+SG                  ;r
                DB     SC+SD+SE+SG            ;o
                DB     SE+SG                  ;r
                DB     SE+SG                  ;r
                DB     SA+SD+SE+SF+SG         ;E

;------------------------------------------------------------------------
;  SHOW_VAL
;  Convert the value in INPUT to a 5 digit 7-segment number
;  Conversion is done by repeatedly subtracting 10000 from the initial
;  number for as long as it is possible. The number of successful
;  subtractions is the most significant decimal digit. Then 1000 is
;  repeatedly subtracted, etc, etc. Until finally a digit from 0 to 9
;  remains, which is the least significant digit.
;  At the same time we suppress leading zeroes, which makes it all look
;  much nicer.
;------------------------------------------------------------------------

SHOW_VAL:       LD      IX,DSPBFFR+5    ; Use display buffer for result
                LD      IY,DECADES      ; Point to the decades table

                LD      A,(INPUT)       ; Get value to be converted
                LD      L,A
                LD      A,(INPUT+1)
                LD      H,A

LOOP2:          LD      A,(IY)          ; Get current decade
                LD      E,A
                INC     IY
                LD      A,(IY)
                LD      D,A
                INC     IY              ; IY now points to next decade
                OR      E               ; Was end of table reached?
                JR      Z,END1          ; Yes!
                LD      B,0             ; Clear decade value

COUNT:          LD      A,L             ; Try to subtract decade from
                SUB     E               ; value
                LD      C,A             ; Temporarily save result
                LD      A,H
                SBC     A, D
                JR      C,EXIT          ; Didn't go!
                LD      H,A             ; Save new intermediate result
                LD      L,C
                INC     B               ; Increment decade counter
                JR      COUNT           ; Count as long as it goes!

EXIT:           LD      A,B             ; Save this digit's value
                LD      (IX),A

                DEC     IX              ; Point to next digit
                JR      LOOP2

END1:           LD      A,L             ; Last decade is in L now
                LD      (IX),A
                LD      IX,DSPBFFR      ; Reload display buffer pointer!

                LD      HL,DSPBFFR+5    ; Convert the 5 decimal digits to
                LD      B,4             ; 7-segment patterns (start left)
                LD      C,0             ; Leading 0's while this is 0

LOOP7:          LD      A,(HL)          ; Get a decimal digit
                OR      C               ; Leading 0?
                JR      Z,SKIP2         ; Yes! Skip this one
                LD      C,A             ; Set leading 0 flag now
                LD      A,(HL)
                CALL    HEX7            ; Convert digit to 7-segments
                LD      (HL),A          ; and store it in display buffer
		
SKIP2:          DEC     HL              ; Do next digit (to the right)
                DJNZ    LOOP7           ; Do 4 of the 5 digits this way
                LD      A,(HL)          ; Always display last digit,
                CALL    HEX7            ; even if the rest were all zeroes
                LD      (HL),A
                DEC     HL              ; Blank last digit
                LD      (HL),0

                RET

DECADES:        DW     10000
                DW     1000
                DW     100
                DW     10
                DW     0               ; Indicating end of conversion

;------------------------------------------------------------------------
;  RANDOM
;  Generate a pseudo random number between 0 and 1023
;------------------------------------------------------------------------

RANDOM:         LD      A,(SEED)        ; Get previous SEED value
                LD      L,A
                LD      A,(SEED+1)
                LD      H,A
                LD      D,L             ; Calculate pseudo random number
                LD      E,6
                SRL     D
                RR      E
                ADD     HL,DE
                LD      A,L             ; Save new SEED value
                LD      (SEED),A
                LD      A,H
                LD      (SEED+1),A
                LD      (HL),A

                LD      A,L             ; Save secret number now
                LD      (SECRET),A
                LD      A,H
                AND     00000011B       ; (limit number to 10 bits)
                LD      (SECRET+1),A
                RET

;------------------------------------------------------------------------
;  PEEK
;  The user pressed the PC key to cheat! Show the secret number for as
;  long the PC key is held down.
;------------------------------------------------------------------------

PEEK:           LD      HL,INPUT        ; Save current input value
                LD      E,(HL)
                INC     HL
                LD      D,(HL)
                PUSH    DE
                LD      A,(SECRET+1)    ; Copy secret to input in order to
                LD      (HL),A          ; be displayed
                DEC     HL
                LD      A,(SECRET)
                LD      (HL),A

                CALL    SHOW_VAL        ; Convert this value to 7-segments
                DEC     HL              ; Save right most display and then
                LD      A,(HL)          ; clear it
                PUSH    AF
                LD      (HL),0

LOOP3:          CALL    SCAN1           ; Display this value until the
                JR      NC,LOOP3        ; key is released!

                POP     AF              ; Restore right most display
                LD      (DSPBFFR),A

                POP     DE              ; Restore input value
                LD      HL,INPUT
                LD      (HL),E
                INC     HL
                LD      (HL),D

                CALL    SHOW_VAL        ; Convert this value to 7-segments
                RET

;------------------------------------------------------------------------
;  COMPARE
;  Compare the new input to the secret number. If the input is lower than
;  the secret number an H is displayed behind the input value. If the
;  input value is higher than the secret value an L is displayed. If
;  the input value matches the secret number register B will be 0 so that
;  main routine can take appropriate action.
;------------------------------------------------------------------------

COMPARE:        LD      HL,INPUT        ; Get input value
                LD      E,(HL)
                INC     HL
                LD      D,(HL)

                LD      HL,SECRET       ; Compare it to the secret value
                LD      A,(HL)
                SUB     E
                LD      B,A
                INC     HL
                LD      A,(HL)
                SBC     A,D
                JR      C,LOWER        ; We're too high!
                OR      B              ; See if we guessed correctly
                LD      B,A            ; (Use B as flag upon return)
                RET     Z              ; Got it!

HIGHER:          
                PUSH    HL
                PUSH    BC 
                LD      HL, SPEECH3    ; is too high. Try again. 
                CALL    SPEAK_STRING 
                POP     BC
                POP     HL
                
                LD      A,SB+SC+SE+SF+SG ; Display an H
                JR      DONE

LOWER:          PUSH    HL
                PUSH    BC 
                LD      HL, SPEECH2    ; is too low. Try again. 
                CALL    SPEAK_STRING
                POP     BC
                POP     HL
                
                LD      A,SD+SE+SF       ; Display an L

DONE:           LD      (DSPBFFR),A
                XOR     A                ; Clear input value for next guess
                LD      (INPUT),A
                LD      (INPUT+1),A
                RET

;------------------------------------------------------------------------
;  COMPUTER
;  Now it's the computer's turn to guess a secret number.
;  The computer uses successive approximation to guess the secret number.
;  Here's how it works:
;
;  Initial guess        1000000000      Higher (leave last bit set)
;  2nd guess            1100000000      Lower  (clear last bit)
;  3rd guess            1010000000      Higher (leave last bit set)
;  4th guess            1011000000      Lower  (clear last bit)
;  5th guess            1010100000      Lower  (clear last bit)
;  6th guess            1010010000      Higher (leave last bit set)
;  7th guess            1010011000      Higher (leave last bit set)
;  8th guess            1010011100      Lower  (clear last bit)
;  9th guess            1010011010      Higher (leave last bit set)
;  10th guess           1010011011      This must be the secret number!
;
;  You see that a mask bit shifts to the right after each guess. This bit
;  remains set if we have to guess higher, or is cleared if we have to
;  guess lower. Then it's shifted again, added to the previous result to
;  form the new guess.
;------------------------------------------------------------------------

COMPUTER:       LD      HL, SPEECH7
                CALL    SPEAK_STRING
    
                LD      HL,MASK         ; Set initial mask for successive
                XOR     A               ; approximation
                LD      (HL),A
                INC     HL
                LD      (HL),00000010B

                LD      HL,INPUT        ; Set initial accumulation value
                LD      (HL),A          ; (which is in fact our first
                INC     HL              ;  guess)
                LD      (HL),00000010B

                INC     A               ; Set guess counter to 1 because
                LD      (COUNTER),A     ; we'll start right away

                PUSH HL
                PUSH BC
                LD HL, SPEECH8
                CALL SPEAK_STRING 
                CALL SPEAK_VAL
                LD HL, SPEECHQ 
                CALL SPEAK_STRING
                POP BC
                POP HL

LOOP4:

                CALL    SHOW_VAL         ; Convert value to 7-segments
                LD      (HL),SA+SB+SE+SG  ; Display "?"
                CALL    SCAN              ; Show this guess

                CP      PLUS              ; Should we guess higher?
                JR      Z,HIGHER2         ; Yes! Next guess should be higher

                CP      MINUS             ; Should we guess lower?
                JR      Z,LOWER2          ; Yes! Next guess must be lower

                CP      DATA              ; DATA key?
                JR      Z,COMPUTER        ; Yes! Restart computer's turn

                CP      REG               ; REG key?
                JP      Z,GUESS           ; Restart entire game (user's turn)

                CP      GO                ; GO key?
                JR      Z,RIGHT           ; Yes! Guessed right, show tries

                JR      LOOP4             ; Ignore all other keys!

HIGHER2:       
                PUSH HL
                PUSH BC
                LD HL, SPEECH8H
                CALL SPEAK_STRING 
                CALL SPEAK_VAL
                LD HL, SPEECHQ 
                CALL SPEAK_STRING
                POP BC
                POP HL
                
                CALL    SHIFT_MASK      ; Shift approximation mask right
                CALL    ADDMASK         ; Add new mask
                
                
                JR      LOOP4           ; Show next try!
                
LOWER2:         

                PUSH HL
                PUSH BC
                LD HL, SPEECH8L
                CALL SPEAK_STRING 
                CALL SPEAK_VAL
                LD HL, SPEECHQ 
                CALL SPEAK_STRING
                POP BC
                POP HL

                LD      HL,INPUT        ; Undo last guess
                LD      A,(MASK)
                XOR     (HL)
                LD      (HL),A
                INC     HL
                LD      A,(MASK+1)
                XOR     (HL)
                LD      (HL),A

                CALL    SHIFT_MASK      ; Shift approximation mask right
                JR      C,END2          ; Run out of mask bits!
OK:             CALL    ADDMASK         ; Add new mask
                JR      LOOP4           ; Take next guess!

END2:           LD      HL,INPUT+1     ; Last bit was not supposed to
                LD      A,(HL)          ; be cleared unless the guess
                DEC     HL              ; is 0
                OR      (HL)
                JR      Z,OK            ; Was 0 indeed!
                INC     (HL)            ; Set b0 of the guess again
                JR      OK

RIGHT:          LD      A,(COUNTER)     ; Show number of tries
                LD      (INPUT),A
                XOR     A
                LD      (INPUT+1),A
                CALL    SHOW_VAL         ; Show this value
                
                PUSH    AF
                PUSH    HL
                PUSH    BC 
                LD  HL, SPEECH9
                CALL    SPEAK_STRING
                CALL    SPEAK_VAL
                LD      HL, SPEECH6
                CALL    SPEAK_STRING    ; tries. 
                POP BC
                POP HL
                POP AF
                CALL    SHOW_VAL
                
                LD      (HL),SD+SE+SF+SG ; Display "t"
                CALL    SCAN             ; Show this until next key press
                JP      GUESS            ; Then start all over again


ADDMASK:        LD      HL,INPUT         ; Combine accumulation value with
                LD      A,(MASK)         ; the new mask
                LD      B,A
                OR      (HL)
                LD      (HL),A
                INC     HL
                LD      A,(MASK+1)
                LD      C,A
                OR      (HL)
                LD      (HL),A
                LD      A,B             ; Was MASK 0?
                OR      C
                RET     Z               ; Yes! Don't increment counter!
                LD      HL,COUNTER      ; Increment guess counter
                INC     (HL)
                RET

;------------------------------------------------------------------------
;  SHIFT_MASK
;  Simple routine to right shift a 16-bit number
;------------------------------------------------------------------------

SHIFT_MASK:     LD      HL,MASK+1       ; Shift mask 1 bit to the right
                SRL     (HL)            ; starting with MSB of course
                DEC     HL
                RR      (HL)
                RET

;;
;; Speech Synthesizer Routines 
;; 

INIT_VDP:
	
	ld a, $fe 
	ld bc, vdp
	out (c), a
	call vdp_delay	

	ld a, $80 		; clear screen
	ld bc, vdp
	out (c), a
	call vdp_delay

	ld a, $ff 		; enter
	ld bc, vdp
	out (c), a

	call vdp_delay 
	call vdp_delay
	call vdp_delay
	call vdp_delay


	ld a, $82 		; text color
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, 7
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, $c0  		; text size 
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, 1
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, $c1  		; cursor 0,0 
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, 0
	ld bc, vdp
	out (c), a
	call vdp_delay 

	ld a, 0
	ld bc, vdp
	out (c), a
	call vdp_delay 
	
	ld a, $ff 		; enter
	ld bc, vdp
	out (c), a

	call vdp_delay 
	call vdp_delay
	call vdp_delay
	call vdp_delay
	
	call vdp_delay 
	call vdp_delay
	call vdp_delay
	call vdp_delay

	ret

	
INIT_SPEECH: 
                ld a, $ef
                ld bc, $00fe 
                out (c), a 
                
                ret
                
SPEAK_STRING:

		push hl
		call vdp_string
		pop hl 

SPEAK_STRING1:

                ld a, (hl)
                or a
                ret z 

	        cp '@'
	        jr z, SKIP_CHAR
	
                ld bc, $00fe 
                out (c), a
	        inc hl

	        jr SPEAK_STRING1

SKIP_CHAR:	
                ld bc, $00fe
	        ld a, ' ' 
        	out (c), a
                inc hl
                
                jr SPEAK_STRING1

VDP_NEXTLINE:

	push hl
	ld hl, LINECOUNT
	ld a, (hl)
	inc a
	ld (hl), a
	pop hl

	cp MAXLINES
	jr nz, NO_CLEARSCREEN

	push hl
	ld hl, LINECOUNT 
	ld (hl), 0
	call INIT_VDP
	
	pop hl

NO_CLEARSCREEN:	
	
	ret 
	
VDP_STRING:
	
	call VDP_NEXTLINE 
	
	ld bc, VDP
	ld a, $d0		
        out (c), a 		; println string

VDP_STRING1:

        ld a, (hl)
	cp '@'
	jr nz, NO_NEWLINE
	
	ld a, 0  		; zero-terminated string 
	ld bc, vdp
	out (c), a

	call vdp_delay
		
	ld a, $ff 		; newline; call recursively 
	ld bc, vdp
	out (c), a
	
	inc hl
	call VDP_STRING

	ret

NO_NEWLINE:	 

	ld bc, VDP 
        out (c), a
        inc hl
	
	call vdp_delay 

	or a
	jr nz, VDP_STRING1 

	ld a, 0  		; zero-terminated string 
	ld bc, vdp
	out (c), a
	
	ld a, $ff 		; enter
	ld bc, vdp
	out (c), a
	
	ret

	
SPEAK_A:

	push af
	
        ld bc, $00fe 		; output to Speech  
        out (c), a

	cp 13
	jr z, SPEAK_A1

	cp '.' 
	jr z, SPEAK_A1

	ld bc, VDP  		; output to VDP 
        out (c), a

SPEAK_A1:	

	pop af
        ret 

SPEAK_WAIT: 

                ;ld bc, $00fe 
                ;in a, (c) 
                ;cp 255
                ;jr nz, SPEAK_WAIT 
                
                ;ret 

VDP_DELAY: 
	    push de 
	    ld de, $0005
	    ld b,e          ; Number of loops is in DE
	    dec de          ; Calculate DB value (destroys B, D and E)
	    inc d
VDP_DELAY1:
	    ; ... do something here
	    
	    djnz VDP_DELAY1
	    dec d
	    jp nz,VDP_DELAY1
	    
	    pop de 
	    
	ret
	
	
WAIT:

                ld b,100
    
DELAY:
	            djnz DELAY

                ret 


SPEAK_VAL:	PUSH BC

		call VDP_NEXTLINE 

		ld bc, VDP
		ld a, $d1
        	out (c), a 		; print string command
		POP BC 

		LD      IX,DSPBFFR+5    ; Use display buffer for result
                LD      IY,DECADES      ; Point to the decades table

                LD      A,(INPUT)       ; Get value to be converted
                LD      L,A
                LD      A,(INPUT+1)
                LD      H,A

LOOP2A:         LD      A,(IY)          ; Get current decade
                LD      E,A
                INC     IY
                LD      A,(IY)
                LD      D,A
                INC     IY              ; IY now points to next decade
                OR      E               ; Was end of table reached?
                JR      Z,END1A          ; Yes!
                LD      B,0             ; Clear decade value

COUNTA:         LD      A,L             ; Try to subtract decade from
                SUB     E               ; value
                LD      C,A             ; Temporarily save result
                LD      A,H
                SBC     A, D
                JR      C,EXITA          ; Didn't go!
                LD      H,A             ; Save new intermediate result
                LD      L,C
                INC     B               ; Increment decade counter
                JR      COUNTA          ; Count as long as it goes!

EXITA:          LD      A,B             ; Save this digit's value
                LD      (IX),A

                DEC     IX              ; Point to next digit
                JR      LOOP2A

END1A:          LD      A,L             ; Last decade is in L now
                LD      (IX),A
                LD      IX,DSPBFFR      ; Reload display buffer pointer!

                LD      HL,DSPBFFR+5    ; Convert the 5 decimal digits to
                LD      B,4             ; 7-segment patterns (start left)
                LD      C,0             ; Leading 0's while this is 0

LOOP7A:         LD      A,(HL)          ; Get a decimal digit
                OR      C               ; Leading 0?
                JR      Z,SKIP2A        ; Yes! Skip this one
                
                LD      C,A             ; Set leading 0 flag now
                LD      A,(HL)
               
                ADD     A, '0'          ; ASC('0') = $30
                PUSH    BC
                CALL    SPEAK_WAIT
                CALL    SPEAK_A 
                POP     BC
		
SKIP2A:         DEC     HL              ; Do next digit (to the right)
                DJNZ    LOOP7A          ; Do 4 of the 5 digits this way
                
                LD      A,(HL)          ; Get a decimal digit
                ADD     A, '0'     
                PUSH    BC 
                CALL    SPEAK_WAIT
                CALL    SPEAK_A 

                ld bc, VDP  		; VDP needs 0 for string termination output to VDP 
                out (c), 0
                POP     BC 

                RET 
                
SPEAK_NOW:                
                
                LD      A,  '.'
                PUSH    BC
                CALL    SPEAK_WAIT
                CALL    SPEAK_A 
                POP     BC 
                
                LD      A, 13 
                PUSH    BC
                CALL    SPEAK_WAIT
                CALL    SPEAK_A 
        	POP     BC

                RET
                
                
SPEECH1 defb "Let us play a game!@I am thinking of a number@between 0 and 1,023.@Try to guess it@and use the GO key.", 13, 0
SPEECH2 defb " is too high.@Guess lower.", 13, 0
SPEECH3 defb " is too low.@Guess higher.", 13, 0 
SPEECH4 defb " is correct!@Great job.", 13, 0
SPEECH5 defb "You guessed ", 0
SPEECH6 defb " times.@Hit the GO key@to continue.", 13, 0 
SPEECH7 defb "Now, lets switch roles.@You will think of a number@between 0 and 1,023 and@I will try to guess it.@Use PLUS, MINUS, and GO@to answer me.", 13, 0 
SPEECH8 defb "My first guess is ", 0 
SPEECH8H defb "Alright, higher then.@So, how about ", 0 
SPEECH8L defb "Got it, lower then.@Now, how about ", 0
SPEECHQ defb  "?", 13, 0 
SPEECH9 defb "I got it, I am smart!@I guessed ", 0 
SPEECH10 defb "How lame, you are giving up?@OK.", 13, 0 
SPEECH11 defb "I am sorry,@I am giving up.", 13, 0


;------------------------------------------------------------------------
;  RAM locations
;  These locations are not included in the program code. This would allow
;  the program to be burned in ROM. No code is generated here, only the
;  labels get their appropriate values.
;------------------------------------------------------------------------

	org $2000

INPUT           DS     2               ;Input word value
SECRET          DS     2               ;Value to guess
SEED            DS     2               ;Random number seed
MASK            DS     2               ;Successive approximation mask
COUNTER         DS     1               ;Try counter
DSPBFFR         DS     6               ;6 Bytes display buffer
LINECOUNT	DB     1	       ;Line Counter
