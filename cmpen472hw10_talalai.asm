***********************************************************************
*
* Title:          Signal Wave Generation and Digital Clock Program
*
* Objective:      CMPEN 472 Homework 10
*
* Revision:       V1.2  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          08 November 2023
*
* Programmer:     Ryan Joseph Talalai
*
* Company:        Student at The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        RTI usage
*                 Typewriter program and 7-Segment display, at PORTB
*                 Terminal and Waveform generation
*                 
*
* Algorithm:      Simple Serial I/O use, typewriter, RTIs, OC6
*
* Register use:	  A, B, X, Y, CCR
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
*                 and generate different waveforms.
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

TIOS        EQU         $0040   ; Timer Input Capture (IC) or Output Compare (OC) select
TIE         EQU         $004C   ; Timer interrupt enable register
TCNTH       EQU         $0044   ; Timer free runing main counter
TSCR1       EQU         $0046   ; Timer system control 1
TSCR2       EQU         $004D   ; Timer system control 2
TFLG1       EQU         $004E   ; Timer interrupt flag 1
TC6H        EQU         $005C   ; Timer channel 2 register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

DATAmax     equ         2048    ; Data count maximum, 1024 constant

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
opcode      DS.B   1

CCount      DS.B        $0001        ; Number of chars in buffer
CmdBuff     DS.B        $000B        ; The actual command buffer

DecBuff     DS.B        $0006        ; used for decimal conversions
HCount      DS.B        $0001        ; number of ASCII characters for Hex conversion
DCount      DS.B        $0001        ; number of ASCII characters for Decimal

ctr125u     DS.W   1            ; 16bit interrupt counter for 125 uSec. of time

BUF         DS.B   6            ; character buffer for a 16bit number in decimal ASCII
CTR         DS.B   1            ; character buffer fill count

gwcount     DS.B   2
gtcount     DS.B   1
gtcount2    DS.B   1

sqcount     DS.B   1
sqflag      DS.B   1
gtflag      DS.B   1

carry       DS.B   1



;*******************************************************
; interrupt vector section
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
;            ORG    $3FF0             ; RTI interrupt vector setup for the CSM-12C128 board
            DC.W   rtiisr
            
            ORG     $FFE2       ; Timer channel 6 interrupt vector setup, on simulator
            DC.W    oc6isr

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
            jsr    nextline
            
            ldx    #menu1           
            jsr    printmsg         ; print menu with cmd instructions
            jsr    nextline
            
            ldx    #menu2           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu3           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu4           
            jsr    printmsg
            jsr    nextline
            jsr    nextline
            
            ldx    #menu5           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu6           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu7           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu8           
            jsr    printmsg
            jsr    nextline
            
            ldx    #menu9           
            jsr    printmsg
            jsr    nextline
            jsr    nextline
            
            ldx    #menu10           
            jsr    printmsg
            jsr    nextline
            jsr    nextline
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
            
            
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            
            
main        
            
            ldx    #CmdBuff
            clr    CCount
            clr    HCount
            jsr    clrBuff
                        
            ldx    #CmdBuff
            ldaa   #$0000
            

looop       
            jsr    CountAndDisplay
            
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
            lbhi   IError              ; user filled the buffer
            cmpa  #CR
            bne    looop            

            ldab  CCount
            cmpb  #$02               ; min # chars in buffer is 2, including Enter
            lblo   IError            

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
            
            cmpa   #$67               ; check for 'g'            
            lbeq   g
                       
            
IError                                ; no recognized command entered, print err msg            
            jsr   nextline
            ldx   #errmsg1              ; print the error message
            jsr   printmsg
            jsr   nextline
            jsr   nextline
            ldx   #prompt              ; print the error message
            jsr   printmsg
            
            
            lbra  main               ; loop back to beginning, infinitely
            
      
g           ldaa   1,X+
                         
            cmpa   #$77               ; check for 'w'            
            lbeq   g2
            cmpa   #$74               ; check for 't'            
            lbeq   g3
            cmpa   #$71               ; check for 'q'            
            lbeq   g4
            
            lbra   IError
            
            
g2          ldaa   1,X+
            cmpa   #$0D               ; check for 'CR'            
            lbeq   gw
            cmpa   #$32               ; check for '2'
            lbeq   g22
            
            lbra   IError

g22         ldaa   1,X+
            cmpa   #$0D               ; check for 'CR'            
            lbeq   gw2
            
            lbra   IError

g3          ldaa   1,X+
            cmpa   #$0D               ; check for 'CR'            
            lbeq   gt
            
            lbra   IError
            


g4          ldaa   1,X+
            cmpa   #$0D               ; check for 'CR'            
            lbeq   gq
            cmpa   #$32               ; check for '2'
            lbeq   g44
            
            lbra   IError
            
g44         ldaa   1,X+
            cmpa   #$0D               ; check for 'CR'            
            lbeq   gq2
            
            lbra   IError     
            
            

TError                                ; no recognized command entered, print err msg
            
            jsr   nextline
            ldx   #errmsg2              ; print the error message
            jsr   printmsg
            jsr   nextline
            ldx   #prompt              ; print the error message
            jsr   printmsg
            jsr   nextline
            ldx   #prompt              ; print the error message
            jsr   printmsg
            
            lbra  main               ; loop back to beginning, infinitely
                                  

t                       
            ldaa  1,X+
            cmpa  #$20              ; ensure second character in input is space
            bne   TError             ; must be a space there
            clr   dec               ; clear out decimal variable
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError
            cmpa  #$32              ; ensure digit is 2 or less
            bhi   TError
            
            beq   t2              
            
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError
            cmpa  #$39              ; ensure digit is smaller than ":" (9 or below)
            bhi   TError
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
            blo   TError
            cmpa  #$33              ; ensure digit is 3 or less
            bhi   TError
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
            bne   TError
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   TError1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   TError1
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
            bne   TError1
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError1
            cmpa  #$35              ; ensure digit is 5 or less
            bhi   TError1
            suba  #$30              ; ASCII number offset
            ldab  #10               ; weight of most sig digit
            mul                     ; A * #10, stored in D
            stab  dec               ; store result in dec.
            
            
            ldaa  1,X+
            cmpa  #$30              ; ensure digit is a number
            blo   TError1
            cmpa  #$39              ; ensure digit is smaller than 9
            bhi   TError1
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
            
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            
            lbra   main
            
TError1                                ; no recognized command entered, print err msg
            jsr   nextline
            ldx   #errmsg2              ; print the error message
            jsr   printmsg
            jsr   nextline
            ldx   #prompt              ; print the error message
            jsr   printmsg
            jsr   nextline
            ldx   #prompt              ; print the error message
            jsr   printmsg
            
            lbra  main               ; loop back to beginning, infinitely           
            
            


h           cmpb  #$02              ; check if command is max length.
            bne   HError
            staa  hms
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            lbra  main
 

m           cmpb  #$02              ; check if command is max length.
            bne   MError
            staa  hms
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            lbra  main
            
            
s           cmpb  #$02              ; check if command is max length.
            bne   SError
            staa  hms
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            lbra  main
            

            
HError      jsr    nextline
            ldx   #errmsg5              ; print the error message
            jsr   printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            
            lbra  main
            
            
MError      jsr    nextline
            ldx   #errmsg4              ; print the error message
            jsr   printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            
            lbra  main                        
            
SError      jsr    nextline
            ldx   #errmsg3              ; print the error message
            jsr   printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            jsr    nextline
            ldx    #prompt           ; print the prompt
            jsr    printmsg
            
            lbra  main
            
q           cmpb  #$02              ; check if command is max length.
            bne   SError
            lbra   ttyStart            
            
            
gw
            ldaa  #$00
            staa  opcode
            
            
            jsr   nextline
            ldx   #gwmsg              ; print the sawtooth message
            jsr   printmsg
            jsr   nextline
            jsr   nextline
            
            lbra  TI
            
            

            
            
            

gw2
            ldaa  #$01
            staa  opcode
            clr   gwcount
            clr   carry
            
            jsr   nextline
            ldx   #gw2msg              ; print the 100hz sawtooth message
            jsr   printmsg
            jsr   nextline
            jsr   nextline
            
            
            lbra  TI
            
          

gt
            ldaa  #$02
            staa  opcode
            clr   gtcount
            clr   gtflag
            
            jsr   nextline
            ldx   #gtmsg              ; print the triangle message
            jsr   printmsg
            jsr   nextline
            jsr   nextline

            
            lbra  TI
            
            

gq
            ldaa  #$03
            staa  opcode
            clr   sqcount
            clr   sqflag
            
            jsr   nextline
            ldx   #gqmsg              ; print square message
            jsr   printmsg
            jsr   nextline
            jsr   nextline
            ldx   #prompt
            jsr   printmsg
            
            lbra  TI
            
            

gq2

            ldaa  #$04
            staa  opcode
            clr   sqcount
            clr   sqflag
            
            jsr   nextline
            ldx   #gq2msg              ; print 100Hz square message
            jsr   printmsg
            jsr   nextline
            jsr   nextline
            ldx   #prompt
            jsr   printmsg
            
            lbra  TI
            
            
TI          ldx     #msg5            ; print '> Set Terminal save file RxData3.txt'
            jsr     printmsg
            jsr     nextline

            ldx     #msg6            ; print '> Press Enter/Return key to start sawtooth wave'
            jsr     printmsg
            jsr     nextline

            jsr     delay1ms         ; flush out SCI serial port 
                                     ; wait to finish sending last characters
                                     
loop2
            jsr    CountAndDisplay
            jsr     getchar
            cmpa    #0
            beq     loop2
            cmpa    #CR
            bne     loop2           ; if Enter/Return key is pressed, move the

            jsr     nextline
            jsr     nextline                                     
            
            
            jsr     delay1ms
            ldx     #0               ; Enter/Return key hit
            stx     ctr125u
            jsr     StartTimer6oc

            CLI                      ; Interrupt enable, for Timer OC6 interrupt start


loop1024
            jsr    CountAndDisplay
            
            ldd     ctr125u
            cpd     #DATAmax         ; 2048 bytes will be sent, the receiver at Windows PC 
            bhs     loopTxON         ;   will only take 1024 bytes.
            bra     loop1024         ; set Terminal Cache Size to 10000 lines, update from 1000 lines

loopTxON
            LDAA    #%00000000
            STAA    TIE               ; disable OC6 interrupt

            jsr     nextline
            jsr     nextline

            ldx     #msg4            ; print '> Done!  Close Output file.'
            jsr     printmsg
            jsr     nextline
            jsr     nextline
            ldx     #prompt
            jsr     printmsg
             
            lbra  main                        


              
            
;
; Typewriter Program
;
ttyStart    
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

;***********Timer OC6 interrupt service routine***************
oc6isr
            
            ldd   #3000              ; 125usec with (24MHz/1 clock)
            addd  TC6H               ;    for next interrupt
            std   TC6H               ; 
            bset  TFLG1,%01000000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
            
            ldx    #opcode           
            ldaa   1,X+
                     
            cmpa   #$00              ; check for '0'
            lbeq   gwgen
            cmpa   #$01              ; check for '1'
            lbeq   gw2gen 
            cmpa   #$02               ; check for '2'            
            lbeq   gtgen
            cmpa   #$03              ; check for '3'
            lbeq   gqgen 
            cmpa   #$04               ; check for '4'            
            lbeq   gq2gen
            lbra    oc2done


gwgen              
  
            ldd   ctr125u
            ldx   ctr125u
            inx                      ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra                     ;   print ctr125u, only the last byte 
            jsr   pnum10             ;   to make the file RxData3.txt with exactly 1024 data
            
            
            lbra   oc2done
          
            
gw2gen                  
            
            ldx   #gwcount
            ldaa  1,X+
            inca
            staa  gwcount
            cmpa  #5
            lbeq  gwnext
            
            ldd   ctr125u
            ldx   ctr125u
            inx                      ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra                     ;   print ctr125u, only the last byte 
            jsr   pnum100hz             ;   to make the file RxData3.txt with exactly 1024 data
                       
            
            lbra   oc2done
            
            
gwnext            
            clr   gwcount
            
            ldd   ctr125u
            ldx   ctr125u
            inx                      ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra                     ;   print ctr125u, only the last byte 
            jsr   pnum100hz2             ;   to make the file RxData3.txt with exactly 1024 data
            inc   carry           
            
            lbra   oc2done
            
            
            

gtgen                   

            ldd   ctr125u
            ldx   ctr125u
            inx
                                     ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra
            
                                 ;   print ctr125u, only the last byte 
            jsr   pnumtriangle             ;   to make the file RxData3.txt with exactly 1024 data
            
            ldx   #gtcount
            ldaa  1,X+
            inca
            staa  gtcount
            cmpa  #0
            lbeq  gtext
                        
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gtext       
            ldx   #gtflag
            ldaa  1,X+
            cmpa  #01
            lbeq  gtzero

            ldab   #01
            stab  gtflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gtzero      ldab   #00
            stab  gtflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done

            


gqgen
            ldd   ctr125u
            ldx   ctr125u
            inx
                                     ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra
            
                                 ;   print ctr125u, only the last byte 
            jsr   pnum10sq             ;   to make the file RxData3.txt with exactly 1024 data
            
            ldx   #sqcount
            ldaa  1,X+
            inca
            staa  sqcount
            cmpa  #0
            lbeq  gqext
                        
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gqext       
            ldx   #sqflag
            ldaa  1,X+
            cmpa  #01
            lbeq  gqzero

            ldab   #01
            stab  sqflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gqzero      ldab   #00
            stab  sqflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done            
                 


gq2gen
            ldd   ctr125u
            ldx   ctr125u
            inx
                                     ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra
            
                                 ;   print ctr125u, only the last byte 
            jsr   pnum10sq             ;   to make the file RxData3.txt with exactly 1024 data
            
            ldx   #sqcount
            ldaa  1,X+
            inca
            staa  sqcount
            cmpa  #40
            lbeq  gqext2
                        
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gqext2       
            clr   sqcount
            ldx   #sqflag
            ldaa  1,X+
            cmpa  #01
            lbeq  gqzero2

            ldab   #01
            stab  sqflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done
            
gqzero2     ldab   #00
            stab  sqflag
            
            ldd   ctr125u
            ldx   ctr125u
            
            
            lbra   oc2done

            
            
             
oc2done     RTI

;***********end of Timer OC6 interrupt service routine********

;***************StartTimer6oc************************
;* Program: Start the timer interrupt, timer channel 6 output compare
;* Input:   Constants - channel 6 output compare, 125usec at 24MHz
;* Output:  None, only the timer interrupt
;* Registers modified: D used and CCR modified
;* Algorithm:
;             initialize TIOS, TIE, TSCR1, TSCR2, TC2H, and TFLG1
;**********************************************
StartTimer6oc
            PSHD
            LDAA   #%01000000
            STAA   TIOS              ; set CH6 Output Compare
            STAA   TIE               ; set CH6 interrupt Enable
            LDAA   #%10000000        ; enable timer, Fast Flag Clear not set
            STAA   TSCR1
            LDAA   #%00000000        ; TOI Off, TCRE Off, TCLK = BCLK/1
            STAA   TSCR2             ;   not needed if started from reset

            LDD    #3000            ; 125usec with (24MHz/1 clock)
            ADDD   TCNTH            ;    for first interrupt
            STD    TC6H             ; 

            BSET   TFLG1,%01000000   ; initial Timer CH6 interrupt flag Clear, not needed if fast clear set
            LDAA   #%01000000
            STAA   TIE               ; set CH6 interrupt Enable
            PULD
            RTS
;***************end of StartTimer2oc*****************


;***********pnum10***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum10          pshd                   ;Save registers
                pshx
                pshy
                clr     CTR            ; clear character count of an 8 bit number
                

                ldy     #BUF
pnum10p1        ldx     #10
                idiv
                beq     pnum10p2
                stab    1,y+
                inc     CTR
                tfr     x,d
                bra     pnum10p1

pnum10p2        stab    1,y+
                inc     CTR                        
;--------------------------------------

pnum10p3        ldaa    #$30                
                adda    1,-y
                jsr     putchar
                dec     CTR
                bne     pnum10p3
                jsr     nextline
                puly
                pulx
                puld
                rts
;***********end of pnum10********************

;***********pnumtriangle***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnumtriangle    pshd                   ;Save registers
                pshx
                pshy
                
                clr     CTR            ; clear character count of an 8 bit number
                
                ldx   #gtflag
                ldaa  1,X+
                cmpa  #01
                lbeq  gtpnum2
                
                bra   pnumnxt                
                
gtpnum2               
                
                comb                         ; take complement
                clra
                

pnumnxt          ldy     #BUF

pnum10p1t        ldx     #10
                idiv
                beq     pnum10p2t
                stab    1,y+
                inc     CTR
                tfr     x,d
                bra     pnum10p1t

pnum10p2t        stab    1,y+
                inc     CTR                        
;--------------------------------------

pnum10p3t        ldaa    #$30                
                adda    1,-y
                jsr     putchar
                dec     CTR
                bne     pnum10p3t
                jsr     nextline
                puly
                pulx
                puld
                rts
;***********end of pnumtriangle********************




;***********pnum100hz***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum100hz       pshd                   ;Save registers
                pshx
                pshy
                
                clr     CTR            ; clear character count of an 8 bit number
                
                ldy     #3
                emul
                addb    carry
                clra
                

                ldy     #BUF
pnum10p1x        ldx     #10
                idiv
                beq     pnum10p2x
                stab    1,y+
                inc     CTR
                tfr     x,d
                bra     pnum10p1x

pnum10p2x        stab    1,y+
                inc     CTR                        
;--------------------------------------

pnum10p3x        ldaa    #$30                
                adda    1,-y
                jsr     putchar
                dec     CTR
                bne     pnum10p3x
                jsr     nextline
                puly
                pulx
                puld
                rts
;***********end of pnum100hz********************

;***********pnum100hz2***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum100hz2       pshd                   ;Save registers
                pshx
                pshy
                
                clr     CTR            ; clear character count of an 8 bit number
                
                ldy     #3
                emul
                addb    carry
                clra
                addb    #1
                

                ldy     #BUF
pnum10p1x2        ldx     #10
                idiv
                beq     pnum10p2x2
                stab    1,y+
                inc     CTR
                tfr     x,d
                bra     pnum10p1x2

pnum10p2x2        stab    1,y+
                inc     CTR                        
;--------------------------------------

pnum10p3x2        ldaa    #$30                
                adda    1,-y
                jsr     putchar
                dec     CTR
                bne     pnum10p3x2
                jsr     nextline
                puly
                pulx
                puld
                rts
;***********end of pnum100hz2********************


;***********pnum10sq***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum10sq        pshd                   ;Save registers
                pshx
                pshy
 
                ldx   #sqflag
                ldaa  1,X+
                cmpa  #01
                lbeq  sqpnum2
                
                ldaa  #$30
                jsr   putchar
                jsr   nextline
                puly
                pulx
                puld
                rts
                
                
sqpnum2         ldaa  #$32
                jsr   putchar
                ldaa  #$35
                jsr   putchar
                ldaa  #$35
                jsr   putchar
                jsr   nextline
                puly
                pulx
                puld
                rts              

;***********end of pnum10sq********************


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
            
cmd         
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

;****************delay1ms**********************
delay1ms:   pshx
            ldx   #$1000           ; count down X, $8FFF may be more than 10ms 
d1msloop    nop                    ;   X <= X - 1
            dex                    ; simple loop
            bne   d1msloop
            pulx
            rts
;****************end of delay1ms***************

;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip

msg1        DC.B    'Welcome to the Wave Generation and 24 hour clock Program!', $00
msg2        DC.B    '     You may type below:', $00
msg3        DC.B    '     Wave Generator and Clock stopped and Typewrite program started.', $00

msg4        DC.B    '> Done!  Close Output file.', $00
msg5        DC.B    '> Set Terminal save file RxData3.txt', $00
msg6        DC.B    '> Press Enter/Return key to start wave generation', $00

menu1       DC.B    'Input the letter t followed by a time in the format [hh:mm:ss] to set the time.', $00
menu2       DC.B    'Input the letter s to display  seconds.', $00
menu3       DC.B    'Input the letter m to display  minutes.', $00
menu4       DC.B    'Input the letter h to display    hours.', $00

menu5       DC.B    'Input command gw  to start  sawtooth        wave generation.', $00
menu6       DC.B    'Input command gw2 to start  100Hz sawtooth  wave generation.', $00
menu7       DC.B    'Input command gt  to start  triangle        wave generation.', $00
menu8       DC.B    'Input command gq  to start  square          wave generation.', $00
menu9       DC.B    'Input command gq2 to start  100Hz square    wave generation.', $00

menu10      DC.B    'Input the letter q to quit the program and boot typewriter.', $00

prompt      DC.B    '> ', $00


errmsg1     DC.B    '     Invalid input format', $00
errmsg2     DC.B    'Error> Invalid time format. Correct example => 00:00:00 to 23:59:59', $00
errmsg3     DC.B    'Error> Invalid command. ("s" for second display and "q" for quit)', $00
errmsg4     DC.B    'Error> Invalid command. ("m" for second display and "q" for quit)', $00
errmsg5     DC.B    'Error> Invalid command. ("h" for second display and "q" for quit)', $00

gwmsg       DC.B    '     sawtooth wave generation ....', $00
gw2msg      DC.B    '     sawtooth wave 100Hz generation ....', $00
gtmsg       DC.B    '     triangle wave generation ....', $00
gqmsg       DC.B    '     square wave generation ....', $00
gq2msg      DC.B    '     square wave 100Hz generation ....', $00


            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled