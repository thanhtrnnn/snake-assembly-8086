.MODEL SMALL
.STACK 100H

.DATA
    ; Define port addresses for the 8255 Programmable Peripheral Interface (PPI)
    ; These addresses might be specific to your hardware setup.
    PORT_OUT EQU 00H       ; Port Out address of the 8255 PPI, used for sending data to the 7-segment display.
    PORT_CON EQU 06H    ; Control Port address of the 8255 PPI, used for configuring the PPI.
                        ; Typical 8255 addressing: PORT_OUT=Base, PortB=Base+1, PortC=Base+2, Control=Base+3.
                        ; The values 00H and 06H suggest a non-standard or specific hardware mapping.

    DELAY_COUNT DW 1FFH ; Constant value used to create a delay. Adjust this to change display speed.
                         ; A larger value means a longer delay for each digit. 1FFFH initially set.

    ; Seven-segment display codes for digits 0-9.
    ; Assumes a common cathode display (a '0' turns the segment ON, '1' turns it OFF).
    ; Bit order: Bit 7 (MSB) = dp (decimal point), Bit 6 = g, Bit 5 = f, ..., Bit 0 (LSB) = a.
    ; dp is assumed to be OFF (set to 1).
    NUM DB 11000000B,  ; 0: Segments a,b,c,d,e,f ON (dp=1, g=1, f=0, e=0, d=0, c=0, b=0, a=0)
           11111001B,  ; 1: Segments b,c ON       (dp=1, g=1, f=1, e=1, d=1, c=0, b=0, a=1)
           10100100B,  ; 2: Segments a,b,d,e,g ON (dp=1, g=0, f=1, e=0, d=0, c=1, b=0, a=0)
           10110000B,  ; 3: Segments a,b,c,d,g ON (dp=1, g=0, f=1, e=1, d=0, c=0, b=0, a=0)
           10011001B,  ; 4: Segments b,c,f,g ON   (dp=1, g=0, f=0, e=1, d=1, c=0, b=0, a=1)
           10010010B,  ; 5: Segments a,c,d,f,g ON (dp=1, g=0, f=0, e=1, d=0, c=0, b=1, a=0)
           10000010B,  ; 6: Segments a,c,d,e,f,g ON (dp=1, g=0, f=0, e=0, d=0, c=0, b=1, a=0)
           11111000B,  ; 7: Segments a,b,c ON     (dp=1, g=1, f=1, e=1, d=1, c=0, b=0, a=0) - Corrected
           10000000B,  ; 8: Segments a,b,c,d,e,f,g ON (dp=1, g=0, f=0, e=0, d=0, c=0, b=0, a=0)
           10010000B   ; 9: Segments a,b,c,d,f,g ON (dp=1, g=0, f=0, e=1, d=0, c=0, b=0, a=0)

.CODE
MAIN PROC
    ; Initialize Data Segment (DS) register
    MOV AX, @DATA       ; Get the address of the .DATA segment
    MOV DS, AX          ; Set DS to this address

START_DISPLAY_CYCLE:
    ; Configure 8255 PPI: Port A as output
    MOV DX, PORT_CON    ; Load the Control Port address into DX
    MOV AL, 80H         ; Load the control word into AL.
                        ; 80H (10000000B) typically configures:
                        ; - Mode Set Flag = 1 (active)
                        ; - Group A (Port A and Port C upper) in Mode 0 (basic I/O)
                        ; - Port A as output
                        ; - Port C upper as output
                        ; - Group B (Port B and Port C lower) in Mode 0
                        ; - Port B as output
                        ; - Port C lower as output
                        ; This makes Port A an output port.
    OUT DX, AL          ; Send the control word to the 8255 Control Port

    ; Initialize for looping through the digits
    MOV CX, 10          ; Set loop counter to 10 (for digits 0 through 9)
    MOV SI, OFFSET NUM  ; Point SI (Source Index) register to the start of the NUM array

DISPLAY_NEXT_DIGIT:
    MOV BX, DELAY_COUNT ; Load the delay duration into BX for the current digit's display time

INNER_DELAY_LOOP:
    ; Display the current digit
    MOV AL, [SI]        ; Load the 7-segment code for the current digit (pointed to by SI) into AL
    MOV DX, PORT_OUT    ; Load the Port Out address into DX
    OUT DX, AL          ; Send the 7-segment code in AL to Port A, lighting up the LED segments

    ; Decrement delay counter
    DEC BX              ; BX = BX - 1
    JNZ INNER_DELAY_LOOP; Jump to INNER_DELAY_LOOP if BX is not zero (continue showing current digit)

    ; Move to the next digit
    INC SI              ; Increment SI to point to the next 7-segment code in the NUM array
    LOOP DISPLAY_NEXT_DIGIT ; Decrement CX; if CX is not zero, jump to DISPLAY_NEXT_DIGIT

    ; Restart the cycle from 0 to 9
    JMP START_DISPLAY_CYCLE ; After displaying all 10 digits, jump back to the beginning to repeat

MAIN ENDP

; End of the program
END MAIN