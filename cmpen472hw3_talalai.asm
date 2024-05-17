***************************************************************************************************
*
* Title: LED Light ON/OFF and Switch ON/OFF
*
* Objective: CMPEN472 Homework 3
*
* Date: 13 September 2023
*
* Programmer: Ryan Joseph Talalai
*
* Student at The Pennsylvania State University
* Electrical Engineering and Computer Science
*
* Revision: v2.0
*
* Algorithm: Simple parallel I/O use and time delay loop demo
*
* Register use: A accumulator: LED light on/off state and Switch 1 on/off state
*               B accumulator: LEVEL counter for loops
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
*              
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
Counter1   DC.W     $003B    ; X register count number for time delay

*
***************************************************************************************************
* Program Section: addresses used [ $3100 to $3FFF ] RAM memory
*

           ORG       $3100      ; Program start address in RAM
pstart     LDS       #$3100     ; initialize stack pointer

           LDAA      #%11111111 ; Must initialize to this for simulation 
           STAA      DDRB       ; set PORTB bit 4,5,6,7 as output
         
           LDAA      #%01000000 ;
           STAA      PORTB      ; turn OFF LED 1,2,4 ; turn ON LED 3 forever
         
mainLoop
           LDAA      PORTB           ; 
           ANDA      #%00000001      ; read switch 1 at PORTB bit 0
           BNE       p65LED1         ; if 1 (switch on ), run blinkLED1 65% light level
                                     ; if 0 (switch off), run blinkLED1 5% light level
                                                

           
p5LED1                                    ; LED 1 turns on for 0.05ms, then off for 0.95ms  
           
           LDAB      #$0005               ; set counter to 5 (on)
loop:      BSET      PORTB, %00010000     ; turn on LED 1 at PORTB bit 4
           JSR       delay10usec          ; wait for 10 usec 
           DECB                           ; decrease loop counter
           BNE       loop
           
           LDAB      #$005F               ; set counter to 95 (off)
loop1:     BCLR      PORTB, %00010000     ; turn off LED 1 at PORTB bit 4
           JSR       delay10usec          ; wait for 10 usec 
           DECB                           
           BNE       loop1
           
           BRA       mainLoop             ; loop forever
                   
           
           
                                          ; LED 1 turns on for 0.65ms, then off for 0.35ms
p65LED1                                   ; same loop as p5LED1 but different counter values

           LDAB    #$0041                 ; set counter to 65 (on)
loop2:     BSET    PORTB, %00010000       ; turn on LED 1 at PORTB bit 4
           JSR     delay10usec            ; wait for 10 usec 
           DECB                           ; decrease loop counter
           BNE     loop2     
           
           LDAB    #$0023                 ; set counter to 35 (off)
loop3:     BCLR    PORTB, %00010000       ; turn off LED 1 at PORTB bit 4
           JSR     delay10usec            ; wait for 10 usec 
           DECB                           
           BNE     loop3
           
           BRA     mainLoop               ; loop forever
            

***************************************************************************************************
* Subroutine Section: addresses used [ $3100 to $3FFF ] RAM memory
*
*
***************************************************************************************************
; delay10 usec subroutine
; comments
; delays LED blinking by 10 micro seconds
; counter of 59 gives proper time delay
*

delay10usec
             PSHX                   ; save X
             LDX   Counter1         ; long delay by
             
dly1Loop     
             DEX
             BNE   dly1Loop
             
             PULX                   ; restore X
             RTS                    ; return
             
*           
*
*
*
             end                    ; last line of a file         