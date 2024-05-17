***************************************************************************************************
*
* Title: LED Light Dimming
*
* Objective: CMPEN472 Homework 4
*
* Date: 25 September 2023
*
* Programmer: Ryan Joseph Talalai
*
* Student at The Pennsylvania State University
* Electrical Engineering and Computer Science
*
* Revision: v1.0
*
* Algorithm: Simple parallel I/O use and time delay loop demo
*
* Register use: A accumulator: Counter
*               B accumulator: OFF counter
*               X register: Delay loop counter
*               Y register: LEVEL counter / ON counter
*
* Memory use: RAM locations from $3000 for data
*             RAM locations from $3100 for program
*
* Input: Parameters hard coded in program (PORT B)
*        
* 
* Output:   LED 1 at PORT B bit 4
*           LED 2 at PORT B bit 5
*           LED 3 at PORT B bit 6
*           LED 4 at PORT B bit 7
*
* Observation: This is a program that raises LED1 from 0% light level to 100% light level,
*              then dims LED1 from 100% light level to 0% light level
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
           STAA      PORTB      ; turn OFF LED 1,2,3,4 ; turn ON LED 3 forever
         
          
          
          
           LDY       #$0000     ; initialize LEVEL to zero
dimUP           
           STY       $3090
           JSR       dim1ms
           LDY       $3090
           INY  
           BEQ       dimUP      ; branch when LEVEL = 101
                                                


dimDOWN           
           STY       $3090
           JSR       dim1ms
           LDY       $3090
           DEY
           BNE       dimDOWN     ; branch when LEVEL = 0
           
           
           BRA       dimUP
           
           

            

***************************************************************************************************
* Subroutine Section: addresses used [ $3100 to $3FFF ] RAM memory
*
*
***************************************************************************************************
*

dim1ms
             LDAA      #$0064
             JSR       dim
             DECA
             BNE       dim1ms
             RTS
             
             
             
dim          STY       $3080                   ;store LEVEL, use as ON
             LDAB      $3080                   ;
             SUBB      #100                   ;set OFF to 100-ON
             
LEDON        BSET      PORTB,%00010000         ;turn on LED1
             

onLoop       
             JSR       delay10usec
             DEY
             BNE       onLoop
             
LEDOFF       BCLR      PORTB,%00010000         ;turn off LED1


offLoop      JSR       delay10usec
             DECB
             BNE       offLoop
             
return       RTS        
             
             
             

; delay10 usec subroutine
; comments
; delays LED blinking by 10 micro seconds
; counter of 59 gives proper time delay

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