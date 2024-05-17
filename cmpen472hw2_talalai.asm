***************************************************************************************************
*
* Title: LED Light Blinking
*
* Objective: CMPEN472 Homework 2
*
* Date: September 09 2023
*
* Programmer: Ryan Joseph Talalai
*
* Student at The Pennsylvania State University
* Electrical Engineering and Computer Science
*
* Revision: v2.0
*
* Algorithm: Single parallel I/O use and time delay loop demo
*
* Register use: A accumulator: LED light on/off state and Switch 1 on/off state
*               X,Y registers: Delay loop counters
*
* Memory use: RAM locations from $3000 for data
*             RAM locations from $3100 for program
*
* Input: Parameters hard coded in program (PORT B)
*        SWITCH 1 at PORT B bit 0
*        SWITCH 2 at PORT B bit 1
*        SWITCH 3 at PORT B bit 2
*        SWITCH 4 at PORT B bit 3
* 
* Output:   LED 1 at PORT B bit 4
*           LED 2 at PORT B bit 5
*           LED 3 at PORT B bit 6
*           LED 4 at PORT B bit 7
*
* Observation: This is a program that blinks LEDs and blinking period
*              can be changed with the delay loop counter value
*              
*              When running, LED 1 and LED 4 alternate blinking.
*              When switch 1 is pressed to ON, the 4 LEDs start blinking in sequence 4,3,2,1
*              When switch 1 is pressed to OFF, alternate blinking restarts
*              If switch 1 is turned OFF, the sequence will finish through, then go to alternating
*
* Comments: This program is developed and simulated using CodeWarrior IDE
*           and is targeted for a CSM-12C128 board
*
***************************************************************************************************
* Parameter Declaration Section
*
* Export Symbols
        XDEF      pstart ; export 'pstart' symbol
        ABSENTRY  pstart ; for assembly entry point
* Symbols and Macros
PORTA   EQU     $0000     ; i/o port addresses
PORTB   EQU     $0001
DDRA    EQU     $0002
DDRB    EQU     $0003     
***************************************************************************************************
* Data Section: addresses used [ $3000 to $30FF ] RAM memory
*

         ORG      $3000    ; reserved memory starting address       
Counter1 DC.W     $0100    ; X register count number for time delay
Counter2 DC.W     $00BF    ; Y register count number for time delay

*
***************************************************************************************************
* Program Section: addresses used [ $3100 to $3FFF ] RAM memory
*

           ORG       $3100      ; Program start address in RAM
pstart     LDS       #$3100     ; initialize stack pointer

           LDAA      #%11111111 ; Must initialize to this for simulation 
           STAA      DDRB       ; set PORTB bit 4,5,6,7 as output
         
           LDAA      #%00000000 ;
           STAA      PORTB      ; turn OFF LED 1,2,3,4
         
mainLoop
           LDAA      PORTB           ; 
           ANDA      #%00000001      ; read switch 1 at PORTB bit 0
           BNE       sw1pushed       ; if switch 1 is pushed, branch to sw1pushed code           
           
           BSET      PORTB,%10000000 ; turn ON LED 4 at PORTB bit 7
           BCLR      PORTB,%00010000 ; turn OFF LED 1 at PORTB bit 4
           JSR       delay1sec       ; Wait for 1 second
          
           BCLR      PORTB,%10000000 ; turn OFF LED 4 at PORTB bit 7
           BSET      PORTB,%00010000 ; turn ON LED 1 at PORTB bit 4
           JSR       delay1sec       ; Wait for 1 second           
               
          
           BRA       mainLoop
           
sw1pushed                            ; LED SEQUENCE --> 4,3,2,1 

           BSET      PORTB,%10000000 ; turn ON  LED 4 at PORTB bit 7
           BCLR      PORTB,%00010000 ; turn OFF LED 1 at PORTB bit 4
           JSR       delay1sec       ; Wait for 1 second
           
           BSET      PORTB,%01000000 ; turn ON  LED 3 at PORTB bit 6
           BCLR      PORTB,%10000000 ; turn OFF LED 4 at PORTB bit 7
           JSR       delay1sec       ; Wait for 1 second
           
           BSET      PORTB,%00100000 ; turn ON  LED 2 at PORTB bit 5
           BCLR      PORTB,%01000000 ; turn OFF LED 3 at PORTB bit 6
           JSR       delay1sec       ; Wait for 1 second
           
           BSET      PORTB,%00010000 ; turn ON  LED 1 at PORTB bit 4
           BCLR      PORTB,%00100000 ; turn OFF LED 2 at PORTB bit 5
           JSR       delay1sec       ; Wait for 1 second
           
           
           BRA       mainLoop    


***************************************************************************************************
* Subroutine Section: addresses used [ $3100 to $3FFF ] RAM memory
*
*
***************************************************************************************************
; delay1sec subroutine
; comments
; delays LED blinking by 1 second
*

delay1sec
             PSHY                   ; save Y
             LDY   Counter2         ; long delay by
             
dly1Loop     JSR   delayMS          ; total time delay = Y * delayMS
             DEY
             BNE   dly1Loop
             
             PULY                   ; restore Y
             RTS                    ; return
             
***************************************************************************************************
; delayMS subroutine
;
; This subroutine causes a few msec delay
;
; Input: a 16 bit count number in 'Counter1'
; Output: time delay, cpu cyle wasted
; Registers in use: X register, as counter
; Memory locations in use: a 16 bit inpute number at 'Counter1'
;
*

delayMS
           PSHX                   ; save X
           LDX    Counter1        ; short delay
           
dlyMSLoop  NOP                    ; total time delay = X * NOP
           DEX
           BNE    dlyMSLoop
           
           PULX                   ; restore X
           RTS                    ; return
*           
*
*
*
           end                    ; last line of a file         