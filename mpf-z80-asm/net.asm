	org $1800

hex7seg		equ $0678
scan		equ $05fe
scan1		equ $0624
tone1		equ $05de
tone2       	equ $05e2
	    
vdp      	equ $00f0
x_res    	equ 128
y_res    	equ 160
	
SA              equ     00001000b       
SB              equ     00010000b       
SC              equ     00100000b       
SD              equ     10000000b       
SE              equ     00000001b       
SF              equ     00000100b       
SG              equ     00000010b       
DP              equ     01000000b       


	main:	 

	LD      IX,STEPSIZE
	ld 	hl,outbf
	ld	b, 6
	CALL    SCAN            ; Show this until a key is pressed

	ADD 10
	LD HL, STEP
	LD (HL), A

	LD      IX,COLOR
	ld 	hl,outbf
	ld	b, 6
	CALL    SCAN            ; Show this until a key is pressed
	
	LD HL, COL 
	LD (HL), A

	;;
	;; Init 
	;; 

	ld a, $fe 
	ld bc, vdp
	out (c), a
	call delay 

	ld a, $80 
	ld bc, vdp
	out (c), a
	call delay 

	call delay 
	call delay
	call delay
	call delay

	ld a, $ff 
	ld bc, vdp
	out (c), a

	call delay 
	call delay
	call delay
	call delay
	
	call delay 
	call delay
	call delay
	call delay

	;;
	;;
	;; 

	ld h, 0
	ld d, 0

	ld a, $82 
	ld bc, vdp
	out (c), a
	
	call delay 
	call delay
	call delay
	call delay
	
	ld a, (col)
	ld bc, vdp
	out (c), a
	
	call delay 
	call delay
	call delay
	call delay

	ld a, $ff
	ld bc, vdp
	out (c), a	

	;;
	;;
	;; 

	loop: 

	ld l, 0
	ld e, x_res - 1
	call line 

	ld a, d
	push hl
	ld hl, step
	add a, (hl)
	pop hl
	ld d, a

	cp y_res 
	jr c, loop

	ld d, 0 

	ld a, h
	push hl
	ld hl, step
	add a, (hl)
	pop hl 
	ld h, a

	cp y_res
	jr c, loop

	jp main

	;;;
	;;;
	;;;

	line: 

	push hl
	push de 
	call delay 

	ld bc, vdp
	ld a, $a0
	out (c), a

	call delay 

	ld bc, vdp
	ld a, h
	out (c), a

	call delay 

	ld bc, vdp
	ld a, l
	out (c), a

	call delay 

	ld bc, vdp
	ld a, d
	out (c), a

	call delay

	ld bc, vdp
	ld a, e
	out (c), a

	call delay

	ld bc, vdp
	ld a, $ff
	out (c), a

	call delay
	pop de
	pop hl 

	ret

	;;;
	;;;
	;;;


	delay: 
	    push de 
	    ld de, $0005
	    ld b,e          ; Number of loops is in DE
	    dec de          ; Calculate DB value (destroys B, D and E)
	    inc d
	delay1:
	    ; ... do something here
	    
	    djnz delay1
	    dec d
	    jp nz,delay1
	    
	    pop de 
	    
	    ret 

	;;;
	;;;
	;;;

	step:		DB 	1 
	col:		DB 	1 

	STEPSIZE:       DB     0
	                DB     0		      ;0 
	                DB     SA+SB+SG+SF+SE         ;p
	                DB     SA+SF+SG+SE+SD         ;E
	                DB     SF+SE+SD+SG            ;t
	                DB     SA+SF+SG+SC+SD         ;S
	COLOR:          DB     0
	                DB     SE+SG                  ;r
	                DB     SG+SE+SC+SD            ;o
	                DB     SF+SE                  ;l
	                DB     SG+SE+SC+SD            ;o
	                DB     SA+SF+SE+SD            ;C

	OUTBF:		DS     6               ;6 Bytes display buffer

	;;;
	;;;
	;;;

	end main
