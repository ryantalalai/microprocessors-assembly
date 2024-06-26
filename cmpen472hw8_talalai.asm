***********************************************************************
*
* Title:          24 Hour Clock
*
* Objective:      CMPEN 472 Homework 8   (Exam 2)
*
* Revision:       V1.0  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          25 October 2023
*
* Programmer:     Ryan Joseph Talalai
*
* Company:        The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        RTI usage
*                 Typewriter program and 7-Segment display, at PORTB
*                 
*
* Algorithm:      Simple Serial I/O use, typewriter, RTIs
*
* Register use:	  A, B, X, CCR
*
* Memory use:     RAM Locations from $3000 for data, 
*                 RAM Locations from $3100 for program
*
*	Input:			    Parameters hard-coded in the program - PORTB, 
*                 Terminal connected over serial
* Output:         
*                 Terminal connected over serial
*                 PORTB bit 7 to bit 4, 7-segment MSB
*                 PORTB bit 3 to bit 0, 7-segment LSB
*
* Observation:    This is a menu-driven program that prints to and receives
*                 data from a terminal, and will do different things based 
*                 on user input, including changing the time and a typewriter 
*                 program that displays ASCII data on PORTB - 7-segment displays.
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        Entry        ; export 'Entry' symbol
            ABSENTRY    Entry        ; for assembly entry point

; include derivative specific macros
PORTB       EQU         $0001
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

;*******************************************************
; variable/data section
            ORG    $3000             ; RAMStart defined as $3000
                                     ; in MC9S12C128 chip

timeh       DS.B   1
timem       DS.B   1
times       DS.B   1
ctr2p5m     DS.W   1                 ; interrupt counter for 2.5 mSec. of time

half        DS.B   1                 ; used for determining when a second has passed
dec         DS.B   1                 ; stores the decimal input as hex
buff        DS.B   1

CCount      DS.B        $0001        ; Number of chars in buffer
CmdBuff     DS.B        $000D        ; The actual command buffer


;*******************************************************
; interrupt vector section
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
;            ORG    $3FF0             ; RTI interrupt vector setup for the CSM-12C128 board
            DC.W   rtiisr

;*******************************************************
; code section

            ORG    $3100
Entry
            LDS    #Entry         ; initialize the stack pointer

            LDAA   #%11111111   ; Set PORTB bit 0,1,2,3,4,5,6,7
            STAA   DDRB         ; as output
            STAA   PORTB        ; set all bits of PORTB, initialize

            ldaa   #$0C         ; Enable SCI port Tx and Rx units
            staa   SCICR2       ; disable SCI interrupts

            ldd    #$0002       ; Set SCI Baud Register = $0002 => 1M baud at 24MHz
;            ldd    #$000D       ; Set SCI Baud Register = $000D => 115200 baud at 24MHz
;            ldd    #$009C       ; Set SCI Baud Register = $009C => 9600 baud at 24MHz
            std    SCIBDH       ; SCI port baud rate change

            ldaa    #$00
            staa    PORTB           ; show 00 on the clock
            
            staa   timeh
            staa   timem
            staa   times

            ldx    #msg1           ; print the welcome message
            jsr    printmsg
            jsr    nextline

            ldx    #menu1          ; print the first menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu2          ; print the 2nd menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu3          ; print the 3rd menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu4          ; print the 4th menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu5          ; print the 5th menu line
            jsr    printmsg
            jsr    nextline
            
            bset   RTICTL,%00011001 ; set RTI: dev=10*(2**10)=2.555msec for C128 board
                                    ;      4MHz quartz oscillator clock
            bset   CRGINT,%10000000 ; enable RTI interrupt
            bset   CRGFLG,%10000000 ; clear RTI IF (Interrupt Flag)


            ldx    #0
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            cli                     ; enable interrupt, global

            clr    half             ; clear out the half counter
            clr    times
            clr    timem
            clr    timeh
            
main        
            jsr    nextline
            ldx    #prompt
            jsr    printmsg
            
            
            
            ldx    #semi
            jsr    printmsg
            
            
            ldx    #semi
            jsr    printmsg
            
            
            ldx    #cmdmsg
            jsr    printmsg
            
            
            
            
            ldx    #CmdBuff              ; cmd buffer init
            clr    CCount
            ldaa   #$0000

looop       jsr    CountAndDisplay ; if 0.5 second is up, toggle the LED

             

            jsr    getchar          ; type writer - check the key board
            tsta                    ;  if nothing typed, keep checking
            beq    looop
                                    ;  otherwise - what is typed on key board
            jsr    putchar          ; is displayed on the terminal window
            
            staa   1,X+               ; store char in buffer
            inc    CCount             ; 
            ldab   CCount
            cmpb   #$0C               ; max # chars in buffer is 11
            beq    Error              ; user filled the buffer
            cmpa   #CR
            bne    looop            ; if Enter/Return key is pressed, move the
            ldaa   #LF              ; cursor to next line
            jsr    putchar


            ldx    #CmdBuff           
            ldaa   1,X+   
CmdChk      

            cmpa   #$68              ; check for 'h'
            lbeq   h
            cmpa   #$6D              ; check for 'm'
            lbeq   m 
            cmpa   #$74              ; check for 't'
            lbeq   t
            cmpa   #$73               ; check for 's'            
            lbeq   s                  
            cmpa   #$71               ; check for 'q'            
            lbeq   ttyStart           ; typewriter

Error                                ; no recognized command entered, print err msg
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar

            ldx   #msg4              ; print the error message
            jsr   printmsg
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
            lbra  main               ; loop back to beginning, infinitely
           

t           ldaa  1,X+
            cmpa  #$20              ; ensure second character in input is space
            bne   Error             ; must be a space there
            clr   dec               ; clear out decimal variable
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$32              ; ensure digit is 2 or less
            bhi   Error
            
            beq   t2              
            
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$39              ; ensure digit is smaller than ":" (9 or below)
            bhi   Error
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec
            bra   t3
            
t2          suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error
            cmpa  #$33              ; ensure digit is 3 or less
            bhi   Error
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec  
                    
            
            
t3          staa  timeh             ; save hours
            clr   dec               ; clear out decimal variable
            

            ldaa  1,X+
            cmpa  #$3A              ; ensure next character in input is ':'
            bne   Error
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec
            
            staa  timem             ; save minutes
            clr   dec               ; clear out decimal variable
            
            
            ldaa  1,X+
            cmpa  #$3A              ; ensure next character in input is ':'
            bne   Error1
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   Error1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   Error1
            suba  #$30              ; ASCII number offset
            ldab  #1                ; weight of least sig digit
            mul                     ; A * #10, stored in D
            ldaa  dec
            aba                     ; add stored 10s place number with converted 1s place number
            staa  dec             
            
            staa  times             ; save seconds
            
            
            clr   half
            ldx   #$0000
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            
            lbra   main
            
Error1                                ; no recognized command entered, print err msg
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar

            ldx   #msg4              ; print the error message
            jsr   printmsg
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
            lbra  main               ; loop back to beginning, infinitely            
            
            


h           cmpb  #$02              ; check if command is max length.
            bne   Error1
            lbra  main
 

m           cmpb  #$02              ; check if command is max length.
            bne   Error1
            lbra  main
            
            
s           cmpb  #$02              ; check if command is max length.
            bne   Error1
            lbra  main            
            
            
                 
            
            
            
snextS      ldaa    times
            cmpa    #$32            ; if/else if/else chain to convert hex numbers to hex numbers that look like the appropriate decimal number
            blo     selseIf1
            adda    #$1E            ; if (times >= $32) print(times+$1E);
            bra     sprint           
            
selseIf1     cmpa    #$28            
            blo     selseIf2
            adda    #$18            ; else if (times >= $28) print(times+$18);
            bra     sprint
            
selseIf2     cmpa    #$1E
            blo     selseIf3
            adda    #$12            ; else if (times >= $1E) print(times+$12);
            bra     sprint
            
selseIf3     cmpa    #$14
            blo     selseIf4
            adda    #$0C            ; else if (times >= $14) print(times+$0C);
            bra     sprint            
            
selseIf4     cmpa    #$0A
            blo     sprint           ; branch to else case
            adda    #$06            ; else if (times >= $0A) print(times+$06);
            bra     sprint
            
sprint       staa    PORTB           ; show the number on PORTB                            
            lbra   main
            
;
; Typewriter Program
;
ttyStart    sei                      ; disable interrupts
            ldx   #msg3              ; print the first message, 'Hello'
            ldaa  #$DD
            staa  CCount
            jsr   printmsg
            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar

            ldx   #msg2              ; print the third message
            jsr   printmsg
                                                                                                            
            ldaa  #CR                ; move the cursor to beginning of the line
            jsr   putchar            ;   Cariage Return/Enter key
            ldaa  #LF                ; move the cursor to next line, Line Feed
            jsr   putchar
                 
tty         jsr   getchar            ; type writer - check the key board
            cmpa  #$00               ;  if nothing typed, keep checking
            beq   tty
                                     ;  otherwise - what is typed on key board
            jsr   putchar            ; is displayed on the terminal window - echo print

            staa  PORTB              ; show the character on PORTB

            cmpa  #CR
            bne   tty                ; if Enter/Return key is pressed, move the
            ldaa  #LF                ; cursor to next line
            jsr   putchar
            bra   tty


;subroutine section below

;***********RTI interrupt service routine***************
rtiisr      bset   CRGFLG,%10000000 ; clear RTI Interrupt Flag - for the next one
            ldx    ctr2p5m          ; every time the RTI occur, increase
            inx                     ;    the 16bit interrupt count
            stx    ctr2p5m
            
rtidone     RTI
;***********end of RTI interrupt service routine********

;***************CountAndDisplay***************
;* Program: increment half-second ctr if 0.5 second is up, handle seconds counting and display
;* Input:   ctr2p5m & times variables
;* Output:  ctr2p5m variable, times variable, 7Segment Displays
;* Registers modified: CCR, A, X
;* Algorithm:
;    Check for 0.5 second passed
;      if not 0.5 second yet, just pass
;      if 0.5 second has reached, then increment half and reset ctr2p5m 
;      if 1 second has been reached, then reset half and increment times and display times on 7seg displays
;**********************************************
CountAndDisplay   psha
            pshx

            ldx    ctr2p5m          ; check for 0.5 sec
;            cpx    #200             ; 2.5msec * 200 = 0.5 sec
;            cpx    #40
             cpx    #90               ; approx 1 sec             
            blo    done          ; NOT yet
            
            bra    YEAT
            
            
done        pulx
            pula
            rts            

YEAT        ldx    #0               ; 0.5sec is up,
            stx    ctr2p5m          ;     clear counter to restart
            
            
            ldaa    half            ; check if it's already been a second
            cmpa    #$01            ; if it's already 1, then we've just gone a whole second
            beq     second
            inc     half            ; it has not been a second yet. set half=1 because it has been 1/2 second so far
            lbra     done
            
           
            
            
            
            
second      


            clr     half            ; reset half second counter
            inc     times           ; increment seconds counter
            ldaa    times           ; check if 60sec have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd

next        clr     times           ; reset times to 0 if 60sec passed
            inc     timem
            
            ldaa    timem           ; check if 60sec have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd
            
            clr     timem
            inc     timeh
            
            ldaa    timeh           ; check if 60sec have passed
            cmpa    #$18            ; $3C == 60
            bne     cmd
            
            clr     timeh
            
cmd         ldx    #CmdBuff           
            ldaa   1,X+
                     
            cmpa   #$68              ; check for 'h'
            lbeq   nextH
            cmpa   #$6D              ; check for 'm'
            lbeq   nextM 
            cmpa   #$73               ; check for 's'            
            lbeq   nextS
            
nextS       ldaa    times
            cmpa    #$32            
            blo     SelseIf1
            adda    #$1E            ; if (times >= $32) print(times+$1E);
            bra     print           
            
SelseIf1     cmpa    #$28            
            blo     SelseIf2
            adda    #$18            ; else if (times >= $28) print(times+$18);
            bra     print
            
SelseIf2     cmpa    #$1E
            blo     SelseIf3
            adda    #$12            ; else if (times >= $1E) print(times+$12);
            bra     print
            
SelseIf3     cmpa    #$14
            blo     SelseIf4
            adda    #$0C            ; else if (times >= $14) print(times+$0C);
            bra     print            
            
SelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else if (times >= $0A) print(times+$06);
            bra     print                       
            
            
nextM       ldaa    timem
            cmpa    #$32            
            blo     MelseIf1
            adda    #$1E            ; if (timem >= $32) print(timem+$1E);
            bra     print           
            
MelseIf1     cmpa    #$28            
            blo     MelseIf2
            adda    #$18            ; else if (timem >= $28) print(timem+$18);
            bra     print
            
MelseIf2     cmpa    #$1E
            blo     MelseIf3
            adda    #$12            ; else if (timem >= $1E) print(timem+$12);
            bra     print
            
MelseIf3     cmpa    #$14
            blo     MelseIf4
            adda    #$0C            ; else if (timem >= $14) print(timem+$0C);
            bra     print            
            
MelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else if (timem >= $0A) print(timem+$06);
            bra     print



            
print       staa    PORTB           ; show the number on PORTB                                                       
   
            pulx
            pula
            rts
            
            
nextH       ldaa    timeh
            cmpa    #$14
            blo     HelseIf4
            adda    #$0C            ; if (times >= $14) print(timeh+$0C);
            lbra     print           
                          
            
HelseIf4     cmpa    #$0A
            blo     print           ; branch to else case
            adda    #$06            ; else (times >= $0A) print(timeh+$06);
            lbra     print            
            
;***************end of CountAndDisplay***************




;***********printmsg***************************
;* Program: Output character string to SCI port, print message
;* Input:   Register X points to ASCII characters in memory
;* Output:  message printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Pick up 1 byte from memory where X register is pointing
;     Send it out to SCI port
;     Update X register to point to the next byte
;     Repeat until the byte data $00 is encountered
;       (String is terminated with NULL=$00)
;**********************************************
NULL            equ     $00
printmsg        psha                   ;Save registers
                pshx
printmsgloop    ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
                cmpa    #NULL
                beq     printmsgdone   ;end of string yet?
                bsr     putchar        ;if not, print character and do next
                bra     printmsgloop
printmsgdone    pulx 
                pula
                rts
;***********end of printmsg********************

;***************putchar************************
;* Program: Send one character to SCI port, terminal
;* Input:   Accumulator A contains an ASCII character, 8bit
;* Output:  Send one character to SCI port, terminal
;* Registers modified: CCR
;* Algorithm:
;    Wait for transmit buffer become empty
;      Transmit buffer empty is indicated by TDRE bit
;      TDRE = 1 : empty - Transmit Data Register Empty, ready to transmit
;      TDRE = 0 : not empty, transmission in progress
;**********************************************
putchar     brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
            staa  SCIDRL                      ; send a character
            rts
;***************end of putchar*****************

;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, other wise return NULL
;* Input:   none    
;* Output:  Accumulator A containing the received ASCII character
;*          if a character is received.
;*          Otherwise Accumulator A will contain a NULL character, $00.
;* Registers modified: CCR
;* Algorithm:
;    Check for receive buffer become full
;      Receive buffer full is indicated by RDRF bit
;      RDRF = 1 : full - Receive Data Register Full, 1 byte received
;      RDRF = 0 : not full, 0 byte received
;**********************************************

getchar     brclr SCISR1,#%00100000,getchar7
            ldaa  SCIDRL
            rts
getchar7    clra
            rts
;****************end of getchar**************** 

;****************nextline**********************
nextline    psha
            ldaa  #CR              ; move the cursor to beginning of the line
            jsr   putchar          ;   Cariage Return/Enter key
            ldaa  #LF              ; move the cursor to next line, Line Feed
            jsr   putchar
            pula
            rts
;****************end of nextline***************
;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip
msg1        DC.B    'Welcome to the 24 hour clock!', $00
msg3        DC.B    'Welcome to the TypeWriter Program!', $00
msg2        DC.B    'You may type below:', $00
msg4        DC.B    'Error> Invalid input', $00

prompt      DC.B    'Clock> ', $00
semi        DC.B    ':', $00
cmdmsg      DC.B    '     CMD> ', $00

menu1       DC.B    'Input the letter t followed by a time in the format hh:mm:ss to set the time.', $00
menu2       DC.B    'Input the letter s to display seconds.', $00
menu3       DC.B    'Input the letter m to display minutes.', $00
menu4       DC.B    'Input the letter h to display hours.', $00
menu5       DC.B    'Quit to the typewriter program by inputting the letter q.', $00

            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled