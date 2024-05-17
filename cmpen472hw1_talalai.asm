********************************************************************************
*
* Title: StarFill
*
* Objective: CMPEN472 Homework 1
*
* Date: Aug. 25 2023
*
* Programmer: Ryan Joseph Talalai
*
* Student at The Pennsylvania State University
* Electrical Engineering and Computer Science
*
* Revision: v2.0
*
* Algorithm: Simple loop demo of HCS12 assembly program
*
* Register use: A accumulator: character data to be filled (*)
*               B accumulator: counter, number of filled memory locations
*               X register:    memory address pointer
*
* Memory use: RAM locations from $3000 to $30DD
*
* Input: No input, Parameters hard coded in program
* 
* Output: Data filled in memory locations from $3000 to $30DD (222 *'s)
*
* Observation: Program can be used as a loop template
*
* Comments: This program is developed and simulated using CodeWarrior IDE
*
********************************************************************************
* Parameter Declaration Section
*
* Export Symbols
        XDEF      pgstart ; export 'pgstart' symbol
        ABSENTRY  pgstart ; for assembly entry point
* Symbols and Macros
PORTA  EQU     $0000   ; i/o port addresses
PORTB   EQU     $0001
DDRA    EQU     $0002
DDRB    EQU     $0003     
********************************************************************************
* Data Section
*
       ORG      $3000    ; reserved memory starting address
       DS.B     $00DE    ; 222 memory locations reserved
       DC.B     $00DE    ; constant, star count = 222
*
********************************************************************************
* Program Section
*
         ORG       $3100   ; Program start address in RAM
pgstart  ldaa      #$2A    ; load '*' into accumulator A
         ldab      $30DE   ; load star counter into B
         ldx       #$3000  ; load address pointer into X
loop     staa      0,x     ; add star to address
         inx               ; point to next location in memory
         decb              ; decrease counter
         bne       loop    ; repeat loop if counter is not at zero
done     bra       done    ; task finished
                           ; do nothing
*
*
*
         END               ; last line of file 
********************************************************************************