***********************************************************************
*
* Title:          24 Hour Clock With Calculator
*
* Objective:      CMPEN 472 Homework 9
*
* Revision:       V2.0  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          01 November 2023
*
* Programmer:     Ryan Joseph Talalai
*
* Company:        Student at The Pennsylvania State University
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
*                 on user input. Change the clock time, display the time,
*                 and perform calculator operations
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
hms         DS.B   1

CCount      DS.B        $0001        ; Number of chars in buffer
CmdBuff     DS.B        $000B        ; The actual command buffer

DecBuff     DS.B        $0006        ; used for decimal conversions
DecBuffC    DS.B        $0006        ; used for decimal conversions
HCount      DS.B        $0001        ; number of ASCII characters for Hex conversion

DCount      DS.B        $0001        ; number of ASCII characters for Decimal
DCount1     DS.B        $0001        ; number of digits in Num1
DCount2     DS.B        $0001        ; number of digits in Num2
Hex         DS.B        $0002        ; used to store number in hex

tempbuff1   DS.B        $0002        ; temp buffers for conversions
tempbuff2   DS.B        $0002

Num1        DS.B        $0002        ; stores first  inputed number
Num2        DS.B        $0002        ; stores second inputed number
Num1ASCII   DS.B        $0005        ; Num1 in ASCII
Num2ASCII   DS.B        $0005        ; Num2 in ASCII

Opcode      DS.B        $0001        ; stores the operation code                            
err         DS.B        $0001        ; error flag
negFlag     DS.B        $0001        ; negative answer flag


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
            
            ldx    #menu6          ; print the 6 menu line
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
            
            ldx    #menu7          ; print the 7th menu line
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu8          ; print the 8th menu line
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
           
            ldx    #CmdBuff
            clr    CCount
            clr    HCount
            jsr    clrBuff
                        
            ldx    #CmdBuff
            ldaa   #$0000
            

looop       
            
            jsr    CountAndDisplay  ; if 0.5 second is up, toggle the LED

            jsr    getchar          ; type writer - check the key board
            tsta                    ;  if nothing typed, keep checking
            beq    looop               
            
            cmpa  #CR
            beq   noReturn
            jsr   putchar
            
noReturn    staa  1,X+               ; store char in buffer
            inc   CCount             ; 
            ldab  CCount
            cmpb  #$0B               ; max # chars in buffer is 11, including Enter
            lbhi   Error              ; user filled the buffer
            cmpa  #CR
            bne    looop            

            ldab  CCount
            cmpb  #$02               ; min # chars in buffer is 2, including Enter
            lblo   Error            
            
            

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
            lbeq   q                  ; typewriter
            
            jsr   parse              ; parse input
            ldaa  err                ; check for error 
            cmpa  #$01               
            lbeq  Error
            
            ldx   #Hex
            clr   1,X+
            clr   1,X+
            
            ldy   #Num1
            ldx   #Num1ASCII
            ldaa  DCount1
            staa  DCount
            jsr   ad2h               ; convert Num1 into hex
            ldaa  err                
            cmpa  #$01               
            lbeq  Error
            sty   Num1
            
            ldx   #Hex
            clr   1,X+
            clr   1,X+
            
            ldy   #Num2
            ldx   #Num2ASCII
            ldaa  DCount2
            staa  DCount
            jsr   ad2h               ; convert Num2 into hex
            ldaa  err                
            cmpa  #$01               ; branch if error
            lbeq  Error
            sty   Num2
            
            
            ldaa  Opcode             ; decide which operation to perform
            cmpa  #$00
            beq   AddOp
            cmpa  #$01
            beq   SubOp
            cmpa  #$02
            beq   MulOp
            cmpa  #$03
            beq   DivOp
            bra   Error              ; error, invalid opcode
            
AddOp       ldd   Num1               ; add Num1 and Num2
            addd  Num2            
            std   Hex                
            bra   PrintAnswer        ; branch to answer

SubOp       ldd   Num1               ; subtract Num2 from Num1
            cpd   Num2               
            blt   Negate             ; check for negative answer
            subd  Num2
            std   Hex
            bra   PrintAnswer
            
Negate      ldd   Num2               ; subtract Num1 from Num2 instead 
            subd  Num1
            std   Hex
            ldaa  #$01
            staa  negFlag            ; set negative flag
            bra   PrintAnswer            

MulOp       ldd   Num1               ; multiply Num1 by Num2
            ldy   Num2
            emul
            bcs   OFError            ; check for overflow
            cpy   #$00               
            bne   OFError                  
            std   Hex
            bra   PrintAnswer

DivOp       ldd   Num1               ; divide Num1 by Num2
            ldx   Num2
            cpx   #$0000             ; check for division by zero
            beq   Error
            idiv                     
            stx   Hex
            
PrintAnswer                          ; print the answer to calculation          

            ldd   Hex
            jsr   h2adC               ; convert answer to ascii for printing on terminal
            
            
DRAKE        
            jsr   CalcTerm            
            clr   negFlag            ; clear negative flag
            lbra  main            
            
            

Error                                ; no recognized command entered, print err msg
            

            ldx   #msg4              ; print the error message
            jsr   printmsg
            clr   err
            
            lbra  main               ; loop back to beginning, infinitely
            
OFError                             
                                   
            ldx   #errmsg2           ; prints overflow error message
            jsr   printmsg
            clr   err                ; reset error flag
            lbra  main               ; loop to main            
           

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
            ldx   #msg4              ; print the error message
            jsr   printmsg
            
            lbra  main               ; loop back to beginning, infinitely           
            
            


h           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
 

m           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
            
            
s           cmpb  #$02              ; check if command is max length.
            bne   Error1
            staa  hms
            lbra  main
            
q           cmpb  #$02              ; check if command is max length.
            bne   Error1
            bra   ttyStart                        
            
                
            
;
; Typewriter Program
;
ttyStart    jsr   nextline
            jsr   nextline
            sei                      ; disable interrupts
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
            cpx    #94               ; approx 1 sec             
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
            
            
            
next        ldaa    times           ; check if 60sec have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd

            clr     times           ; reset times to 0 if 60sec passed
            inc     timem
            
            ldaa    timem           ; check if 60min have passed
            cmpa    #$3C            ; $3C == 60
            bne     cmd
            
            clr     timem
            inc     timeh
            
            ldaa    timeh           ; check if 24 hours have passed
            cmpa    #$18            
            bne     cmd
            
            clr     timeh
            
cmd         jsr     Terminal
            ldx    #hms           
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

;***************Terminal***************
;Displays propmpts on terminal
;**********************************************
Terminal    

            pshx
            jsr    nextline
            ldx    #prompt
            jsr    printmsg
            
            ldd    timeh
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   hterm
            ldx   #zero
            jsr   printmsg
            
            
hterm       ldx    #DecBuff
            jsr    printmsg
            
            ldx    #semi
            jsr    printmsg
            
            ldd    timem
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   mterm
            ldx   #zero
            jsr   printmsg
            
mterm       ldx    #DecBuff
            jsr    printmsg
                                  
            
            ldx    #semi
            jsr    printmsg
            
            ldd    times
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   sterm
            ldx   #zero
            jsr   printmsg
            
sterm       ldx    #DecBuff
            jsr    printmsg
            
            ldx    #cmdmsg
            jsr    printmsg
            
            ldx    #CmdBuff
            jsr    printmsg
            
            
            
            pulx
            rts
            
            
;***************end of Terminal***************

;***************CalcTerm****************************
;Displays propmpts on terminal when calc is in use
;***************************************************
CalcTerm    

            pshx
            jsr    nextline
            ldx    #prompt
            jsr    printmsg
            
            ldd    timeh
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   hterm1
            ldx   #zero
            jsr   printmsg
            
            
hterm1      ldx    #DecBuff
            jsr    printmsg
            
            ldx    #semi
            jsr    printmsg
            
            ldd    timem
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   mterm1
            ldx   #zero
            jsr   printmsg
            
mterm1      ldx    #DecBuff
            jsr    printmsg
                                  
            
            ldx    #semi
            jsr    printmsg
            
            ldd    times
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            lsrd
            jsr    h2ad
            ldx    #DecBuff
            
            inx
            ldaa  1,X+
            cmpa  #$00              ; check for NULL
            bne   sterm1
            ldx   #zero
            jsr   printmsg
            
sterm1      ldx    #DecBuff
            jsr    printmsg
            
            ldx    #sspace
            jsr    printmsg
            
            ldx    #Num1ASCII
            jsr    printmsg
            
            ldaa  Opcode             ; decide which operation to perform
            cmpa  #$00
            beq   addsign
            cmpa  #$01
            beq   subsign
            cmpa  #$02
            beq   mulsign
            cmpa  #$03
            beq   divsign
            
                        
addsign     ldx    #add
            jsr    printmsg       
            bra    Num22
            
subsign     ldx    #minus
            jsr    printmsg
            bra    Num22

divsign     ldx    #divide
            jsr    printmsg
            bra    Num22

mulsign     ldx    #multiply
            jsr    printmsg
            

            
Num22       ldx    #Num2ASCII
            jsr    printmsg
            
            ldx    #equal
            jsr    printmsg
            
            ldaa  negFlag
            cmpa  #$01               ; check if answer should be negative
            bne   FREETORY               
            ldx   #minus
            jsr   printmsg      
            
FREETORY    ldx    #DecBuffC
            jsr    printmsg            
            
            pulx
            rts
            
            
;***************end of CalcTerm***************

;*********************ad2h*****************************
;* Program: converts ascii-formatted decimal (up to 4 digits) to hex
;*             
;* Input: decimal in ascii form, number of digits      
;* Output: hex number in buffer (#Hex) and Y          
;*          
;* Registers modified: X,Y,A,B   
;******************************************************
ad2h    

D4              ldaa    0,X          ; load first digit into A
                ldab    DCount       ; load number of digits into B
                cmpb    #$04         ; check for 4 digits
                bne     D3           ; branch if 3 or less
                dec     DCount  
                             
                
                suba    #$30         ; subtract ascii bias
                lsla                 ; shift left 3 times, multiply by 8
                lsla
                lsla
                staa    tempbuff1    ; store in tempbuff
                
                ldaa    0,X          ; reload into A
                suba    #$30
                lsla                 ; shift left 4 time, multiply by 16
                lsla
                lsla
                lsla
                adda    tempbuff1    ; add to tempbuff
                staa    tempbuff1    ; now has digit multiplied by 24
                             
                
                ldd     0,X          ; load digit into D
                lsrd                 ; shift right 8 times, gives leading zeros
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                subd    #$30         ; subtract ascii bias
                
                lsld                 ; shift left 10 times, multiply by 1024
                lsld
                lsld
                lsld
                lsld
                lsld
                lsld
                lsld
                lsld
                lsld
                std     tempbuff2    ; store in second buffer
                
                ldd     tempbuff1    ; load first buffer into D
                lsrd                 ; shift right to ensure leading zeros
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                lsrd
                std     tempbuff1    ; store back into first buffer
                
                ldd     tempbuff2    ; load second buffer into D
                subd    tempbuff1    ; subtracts digit multiplied by 1024 
                                     ; by digit multiplied by 24
                
                
                
                std     Hex          ; store digit multiplied by #1000 into Hex
                ldd     #$0          ; reset D
                                                
                inx                  
                ldaa    0,X          ; load next digit into A
                ldab    DCount       
                

D3              cmpb    #$03         ; check for 3 digits left
                bne     D2
                dec     DCount  
                suba    #$30         ; ascii bias
                ldab    #100         
                mul                  ; multiply A by #100, store in D
                addd    Hex          ; add D and Hex buffer
                std     Hex          ; store in Hex                
                inx
                ldaa    0,X         
                ldab    DCount  

D2              cmpb    #$02         ; check for 2 digits
                bne     D1
                dec     DCount  
                suba    #$30         
                ldab    #10     
                mul                  ; multiply A by #10
                addd    Hex
                std     Hex                     
                inx
                ldaa    0,X     
                ldab    DCount  
                
D1              cmpb    #$01         ; last digit
                bne     hconverror   ; branch to error, more than 4 digits
                dec     DCount  
                suba    #$30    
                ldab    #1       
                mul           
                addd    Hex
                std     Hex                     
                inx                
                ldy     Hex          ; load hex buffer into Y
               
                rts

hconverror      ldaa    #$01         ; error occured, set A to #1
                staa    err
                rts

;*********************end of ad2h*********************            

;*********************h2adC****************************
;* Program: converts a hex number to ascii decimal
;*             
;* Input:   hex number
;*     
;* Output:  number in ascii decimal 
;*          
;*          
;* Registers modified: A, B, X, CCR
;*   
;*****************************************************
h2adC            
                clr   HCount    
                cpd   #$00      ; check for $0
                lbeq  H0C
                ldy   #DecBuffC
                
HLoopC           ldx   #10       ; will be dividing by #10 using x reg
                idiv               
                  
                stab  1,Y+      ; get first digit
                inc   HCount    ; first divison
                tfr   X,D       
                tstb            ; check remainder for zero
                bne   HLoopC      
                
                
reverseC         ldaa  HCount    
                cmpa  #$05      ; check number of remainders
                beq   H4C
                cmpa  #$04
                beq   H3C        ; branch
                cmpa  #$03
                lbeq  H2C
                cmpa  #$02
                lbeq  H1C
                                ; if there is only one, convert and return
                ldx   #DecBuffC  
                ldaa  0,X       
                adda  #$30      
                staa  1,X+      ; store conversion
                ldaa  #$00      ; load/store NULL
                staa  1,X+      
                rts


H4C              ldx   #DecBuffC  ; H3,H2,H1 follow the same algorithm, just one less place
                ldaa  1,X+      ; load the 1s place remainder
                inx
                inx
                inx
                ldab  0,X       ; load the 10000s place remainder
                staa  0,X       
                ldx   #DecBuffC
                stab  0,X       
                
                inx             ; move to 1000s place
                ldaa  1,X+      ; load current 1000s place
                inx             ; skip current 100s place
                ldab  0,X       
                staa  0,X       
                ldx   #DecBuffC  ; reload buff
                inx             ; move to 1000s place
                stab  0,X       
                
                ldx   #DecBuffC  
                ldaa  0,X       ; load 10000s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 10000s place
                ldaa  0,X       ; load 1000s place
                adda  #$30      ; add ascii
                staa  1,X+      ; store converted 1000s place
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s place
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      ; load NULL
                staa  1,X+      
                rts


H3C              ldx   #DecBuffC
                ldaa  1,X+      ; load the 1s place remainder
                inx
                inx
                ldab  0,X       ; load the 1000s place remainder
                staa  0,X       
                ldx   #DecBuffC
                stab  0,X       ; put the 1000s place into the 1000s place
                
                inx             ; move to 100s place
                ldaa  1,X+      ; load current 100s place
                ldab  0,X       ; load current 10s place
                staa  0,X       
                ldx   #DecBuffC  
                inx             
                stab  0,X       
                
                ldx   #DecBuffC  
                ldaa  0,X       ; load 1000s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 1000s place
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s place
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts


H2C              ldx   #DecBuffC
                ldaa  1,X+      ; load the 1s place remainder
                inx
                ldab  0,X       ; load the 100s place remainder
                staa  0,X       
                ldx   #DecBuffC
                stab  0,X       
                
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s placeA
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts
                

H1C              ldx   #DecBuffC
                ldaa  1,X+      ; load the 1s place remainder
                ldab  0,X       ; load the 10s place remainder
                staa  0,X       
                ldx   #DecBuffC  
                stab  0,X       
                
                ldaa  0,X       ; load 10s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts

               
H0C              ldx   #DecBuffC  
                ldaa  #$30      
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+               
                rts

;******************end of h2adC************************

;*********************h2ad****************************
;* Program: converts a hex number to ascii decimal
;*             
;* Input:   hex number
;*     
;* Output:  number in ascii decimal 
;*          
;*          
;* Registers modified: A, B, X, CCR
;*   
;*****************************************************
h2ad            
                clr   HCount    
                cpd   #$00      ; check for $0
                lbeq  H0
                ldy   #DecBuff
                
HLoop           ldx   #10       ; will be dividing by #10 using x reg
                idiv               
                  
                stab  1,Y+      ; get first digit
                inc   HCount    ; first divison
                tfr   X,D       
                tstb            ; check remainder for zero
                bne   HLoop      
                
                
reverse         ldaa  HCount    
                cmpa  #$05      ; check number of remainders
                beq   H4
                cmpa  #$04
                beq   H3        ; branch
                cmpa  #$03
                lbeq  H2
                cmpa  #$02
                lbeq  H1
                                ; if there is only one, convert and return
                ldx   #DecBuff  
                ldaa  0,X       
                adda  #$30      
                staa  1,X+      ; store conversion
                ldaa  #$00      ; load/store NULL
                staa  1,X+      
                rts


H4              ldx   #DecBuff  ; H3,H2,H1 follow the same algorithm, just one less place
                ldaa  1,X+      ; load the 1s place remainder
                inx
                inx
                inx
                ldab  0,X       ; load the 10000s place remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       
                
                inx             ; move to 1000s place
                ldaa  1,X+      ; load current 1000s place
                inx             ; skip current 100s place
                ldab  0,X       
                staa  0,X       
                ldx   #DecBuff  ; reload buff
                inx             ; move to 1000s place
                stab  0,X       
                
                ldx   #DecBuff  
                ldaa  0,X       ; load 10000s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 10000s place
                ldaa  0,X       ; load 1000s place
                adda  #$30      ; add ascii
                staa  1,X+      ; store converted 1000s place
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s place
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      ; load NULL
                staa  1,X+      
                rts


H3              ldx   #DecBuff
                ldaa  1,X+      ; load the 1s place remainder
                inx
                inx
                ldab  0,X       ; load the 1000s place remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       ; put the 1000s place into the 1000s place
                
                inx             ; move to 100s place
                ldaa  1,X+      ; load current 100s place
                ldab  0,X       ; load current 10s place
                staa  0,X       
                ldx   #DecBuff  
                inx             
                stab  0,X       
                
                ldx   #DecBuff  
                ldaa  0,X       ; load 1000s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 1000s place
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s place
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts


H2              ldx   #DecBuff
                ldaa  1,X+      ; load the 1s place remainder
                inx
                ldab  0,X       ; load the 100s place remainder
                staa  0,X       
                ldx   #DecBuff
                stab  0,X       
                
                ldaa  0,X       ; load 100s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 100s place
                ldaa  0,X       ; load 10s placeA
                adda  #$30
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30      
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts
                

H1              ldx   #DecBuff
                ldaa  1,X+      ; load the 1s place remainder
                ldab  0,X       ; load the 10s place remainder
                staa  0,X       
                ldx   #DecBuff  
                stab  0,X       
                
                ldaa  0,X       ; load 10s place
                adda  #$30      ; add ascii bias
                staa  1,X+      ; store converted 10s place
                ldaa  0,X       ; load 1s place
                adda  #$30
                staa  1,X+      ; store converted 1s place
                ldaa  #$00      
                staa  1,X+      
                rts

               
H0              ldx   #DecBuff  
                ldaa  #$30      
                staa  1,X+      
                ldaa  #$00      
                staa  1,X+               
                rts

;******************end of h2ad************************



;********************parse****************************
;* Program: parse input into Num1 and Num2
;* Input: 2 ASCII numbers with opcode in between 
;* 
;* Output: Num1 and Num2  
;* 
;* Registers modified: X,Y,A,B,CCR
;*****************************************************
parse       ldx     #indent     
            jsr     printmsg    
            ldx     #CmdBuff       ; load the input from terminal
            ldy     #Num1ASCII     ; load Num1
            clrb                
                        
Num1Loop    ldaa    1,X+
            ;jsr     echoPrint               
            
            cmpa    #$39           ; check for error symbols
            bhi     parseErr    
            
            cmpa    #$30           ; check operator
            blo     OpChk       
            
            cmpb    #$04           ; max digit check
            bhi     parseErr    
            
            staa    1,Y+           ; store digit in arg1 buffer
            incb                   ; increment digit ctr
            bra     Num1Loop       ; loop

OpChk       cmpb    #$04           ; max four digits in Num1
            bhi     parseErr    
            tstb
            beq     parseErr       ; need at least 1 digit in Num1
            
            stab    DCount1        ; store number of digits
            clrb
            stab    0,Y         
            
AddChk      cmpa    #$2B           ; check for addition opcode
            bne     SubChk      
            ldaa    #$00        
            staa    Opcode      
            bra     Numb2
            
SubChk      cmpa    #$2D           ; check for subtraction opcode
            bne     MulChk     
            ldaa    #$01
            staa    Opcode      
            bra     Numb2
            
MulChk      cmpa    #$2A           ; check for multiplication opcode
            bne     DivChk      
            ldaa    #$02        
            staa    Opcode
            bra     Numb2
            
DivChk      cmpa    #$2F           ; check for division opcode
            bne     parseErr    
            ldaa    #$03        
            staa    Opcode
                                                         
Numb2       ldy     #Num2ASCII     ; load Num2

Num2Loop    ldaa    1,X+
            ;jsr     echoPrint   
            
            cmpa    #CR            ; if CR, end
            beq     Return       
            
            cmpa    #$39           ; check number
            bhi     parseErr    
            cmpa    #$30
            blo     parseErr
            
            cmpb    #$04           ; max four digits in Num2
            bhi     parseErr
            
            staa    1,Y+
            incb
            bra     Num2Loop
            
Return      cmpb    #$04           ; max four digits
            bhi     parseErr    
            tstb
            beq     parseErr       ; at least 1 digit
            
            stab    DCount2     
            clrb
            stab    0,Y             

            rts     
            
parseErr    ldaa    #$01
            staa    err
            rts                   
            
;***************end of parse*****************************


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


;***************echoPrint**********************
;* Program: makes calls to putchar but ends when CR is passed to it
;* Input:   ASCII char in A
;* Output:  1 char is displayed on the terminal window - echo print
;* Registers modified: CCR
;* Algorithm: if(A==CR) return; else print(A);
;**********************************************
echoPrint      cmpa       #CR       ; if A == CR, end of string reached
               beq        retEcho   ; return
               
               jsr        putchar
               
retEcho        rts
;***************end of echoPrint***************


;***********clrBuff****************************
;* Program: Clear out command buff
;* Input:   
;* Output:  buffer is filled with zeros
;* 
;* Registers modified: X,A,B,CCR
;* Algorithm: set each byte (11 total) in CmdBuff to NULL
;************************************************
clrBuff
            ldab    #$0B        ; number of bytes allocated
clrLoop
            cmpb    #$00        ; standard while loop
            beq     clrReturn
            ldaa    #$00
            staa    1,X+        ; clear current byte
            decb                ; B = B-1
            bra     clrLoop     ; loop thru whole buffer

clrReturn   rts                            
            
;***********end of clrBuff*****************************

;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip
msg1        DC.B    'Welcome to the 24 hour clock and Calculator!', $00
msg3        DC.B    'Clock and Calculator stopped. Welcome to the TypeWriter Program!', $00
msg2        DC.B    'You may type below:', $00
msg4        DC.B    '        Error> Invalid input', $00
errmsg2     DC.B    '        Error> Overflow', $00

prompt      DC.B    'Tcalc> ', $00
semi        DC.B    ':', $00
cmdmsg      DC.B    '                      CMD> ', $00
zero        DC.B    '0', $00
sspace      DC.B    '    ', $00

indent      DC.B    '        ', $00
equal       DC.B    '=', $00
minus       DC.B    '-', $00
multiply    DC.B    '*', $00
divide      DC.B    '/', $00
add         DC.B    '+', $00

menu1       DC.B    'Input the letter t followed by a time in the format [hh:mm:ss] to set the time.', $00
menu2       DC.B    'Input the letter s to display seconds.', $00
menu3       DC.B    'Input the letter m to display minutes.', $00
menu4       DC.B    'Input the letter h to display hours.', $00
menu5       DC.B    'Quit to the typewriter program by inputting the letter q.', $00
menu6       DC.B    'For example: t 16:34:43', $00
menu7       DC.B    'The Calculator can perform +,-,*,/ operations.', $00
menu8       DC.B    'Only operates on 2 numbers with max 4 digits each.', $00

            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled