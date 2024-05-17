***********************************************************************
*
* Title:          Calculator
*
* Objective:      CMPEN 472 Homework 7
*
* Revision:       V1.0  for CodeWarrior 5.2
*
* Date:	          16 October 2023
*
* Programmer:     Ryan Joseph Talalai
*
* Company:        Student at The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        Simple SCI Serial Port I/O and Demonstration
*                 Calculator
*                                  
*
* Algorithm:      Simple Serial I/O use, ASCII and hex conversions
*                 overflow check, negative check
*
* Register use:	  Accumulator A: Serial port data
*                 Accumulator B: Misc uses
*                 Register X:    Buffer
*                 Register Y:    Buffer
*
* Memory use:     RAM Locations from $3000 for data, 
*                 RAM Locations from $3100 for program
*
*	Input:          Terminal connected over serial port
*
* Output:         
*                 Terminal connected over serial port
*
*
* Observation:    Receives input from terminal window. Can perform
*                 simple arithmetic operations (+,-,*,/).
*                 Gives error on negative numbers, overflow, improper
*                 format. Only can operate on 4 digit numbers or less
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        pstart       ; export 'pstart' symbol
            ABSENTRY    pstart       ; for assembly entry point
  
* Symbols and Macros
PORTB       EQU         $0001        ; i/o port B addresses
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CR          EQU         $000D        ; carriage return, ASCII 'Return' key
LF          EQU         $000A        ; line feed, ASCII 'next line' character
SPACE       EQU         $0020        ; space character

***********************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
            ORG         $3000        ; Reserved RAM memory starting address 
                                     ;   for Data for CMPEN 472 class

CCount      DS.B        $0001        ; number of characters
HCount      DS.B        $0001        ; number of ASCII characters for Hex conversion
DCount      DS.B        $0001        ; number of ASCII characters for Decimal
DCount1     DS.B        $0001        ; number of digits in Num1
DCount2     DS.B        $0001        ; number of digits in Num2
Hex         DS.B        $0002        ; used to store number in hex

tempbuff1   DS.B        $0002        ; temp buffers for conversions
tempbuff2   DS.B        $0002

CmdBuff     DS.B        $000A        ; command buffer
DecBuff     DS.B        $0004        ; used for decimal conversions

Num1        DS.B        $0002        ; stores first  inputed number
Num2        DS.B        $0002        ; stores second inputed number
Num1ASCII   DS.B        $0004        ; Num1 in ASCII
Num2ASCII   DS.B        $0004        ; Num2 in ASCII
        
Opcode      DS.B        $0001        ; stores the operation code                            
err         DS.B        $0001        ; error flag
negFlag     DS.B        $0001        ; negative answer flag


; messages at the end of RAM

*
***********************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*
            ORG   $3100              ; Program start address, in RAM
pstart      LDS   #$3100             ; initialize the stack pointer

            LDAA  #%11111111         ; Set PORTB bit 0,1,2,3,4,5,6,7
            STAA  DDRB         

            LDAA  #%00000000
            STAA  PORTB              ; clear all bits of PORTB

            ldaa  #$0C               ; Enable SCI port Tx and Rx units
            staa  SCICR2             ; disable SCI interrupts

            ldd   #$0001             ; Set SCI Baud Register = $0001 => 2M baud at 24MHz (for simulation)
            std   SCIBDH             ; SCI port baud rate change
            
                                   
main        
            ldx   #prompt            ; print prompt
            jsr   printmsg
            
            ldx   #CmdBuff
            clr   CCount
            clr   HCount
            jsr   clrBuff            ; clear buffer
            ldx   #CmdBuff           ; initialize

cmdLoop     jsr   getchar            ; check for input
            cmpa  #$00               
            beq   cmdLoop
                                     
            cmpa  #CR
            beq   Enter
            jsr   putchar            

Enter       staa  1,X+               
            inc   CCount              
            ldab  CCount
            cmpb  #$0A               ; max number of characters in buffer is 10
            lbhi  Error              ; filled buffer
            cmpa  #CR
            bne   cmdLoop            
            
            
            ldab  CCount
            cmpb  #$04               ; min number of characterss in buffer is 4
            lblo  Error              ; not enough typed in terminal
            
            
OpCheck                
            ldaa  #CR                ; Carriage Return
            jsr   putchar                                
            ldaa  #LF                ; Line Feed  
            jsr   putchar
            
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
            ldx   #equal
            jsr   printmsg           

            ldd   Hex
            jsr   h2ad               ; convert answer to ascii for printing on terminal
            ldaa  negFlag
            cmpa  #$01               ; check if answer should be negative
            bne   YEAT               
            ldx   #minus
            jsr   printmsg
            
YEAT        
            ldx   #DecBuff
            jsr   printmsg
            ldaa  #CR                ; Carriage Return
            jsr   putchar            
            ldaa  #LF                ; Line Feed                                 
            jsr   putchar            
            clr   negFlag            ; clear negative flag
            lbra  main

Error                                ; For unrecognized commands
            ldaa  #CR                ; Carriage Return
            jsr   putchar                                
            ldaa  #LF                ; Line Feed
            jsr   putchar
                        
            ldx   #errmsg1           ; prints error message
            jsr   printmsg
            ldaa  #CR                ; Carriage Return
            jsr   putchar            
            ldaa  #LF                ; Line Feed                                 
            jsr   putchar
            clr   err                ; reset error flag
            lbra  main               ; loop to main


OFError                             
            ldaa  #CR                ; Carriage Return
            jsr   putchar                                
            ldaa  #LF                ; Line Feed
            jsr   putchar
                       
            ldx   #errmsg2           ; prints overflow error message
            jsr   printmsg
            ldaa  #CR                ; Carriage Return
            jsr   putchar            
            ldaa  #LF                ; Line Feed                                 
            jsr   putchar
            clr   err                ; reset error flag
            lbra  main               ; loop to main
            
                        

;*************************************************************************
;*       SUBROUTINE SECTION BEGINS                                       *
;*************************************************************************

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
NULL           equ     $00
printmsg       psha                   ;Save registers
               pshx
printmsgloop   ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
               cmpa    #NULL
               beq     printmsgdone   ;end of string yet?
               jsr     putchar        ;if not, print character and do next
               bra     printmsgloop

printmsgdone   pulx 
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
putchar        brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
               staa  SCIDRL                      ; send a character
               rts
;***************end of putchar*****************


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


;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, otherwise return NULL
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
getchar        brclr SCISR1,#%00100000,getchar7
               ldaa  SCIDRL
               rts
getchar7       clra
               rts
;****************end of getchar**************** 



 ;***********clrBuff****************************
;* Program: Clear out command buff
;* Input:   
;* Output:  buffer filled with zeros
;* 
;* Registers modified: X,A,B,CCR
;* Algorithm: set each byte in CmdBuff to $00
;************************************************
clrBuff
            ldab    #$0A        
clrLoop
            cmpb    #$00        
            beq     clrReturn
            ldaa    #$00
            staa    1,X+        ; clear byte
            decb                
            bra     clrLoop     ; loop

clrReturn   rts                            
            
;****************end of clrBuff*****************************


 ;********************parse****************************
;* Program: parse input into Num1 and Num2
;* Input: 2 ASCII numbers with opcode in between 
;* 
;* Output: Num1 and Num2  
;* 
;* Registers modified: X,Y,A,B,CCR
;******************************************************

parse       ldx     #indent     
            jsr     printmsg    
            ldx     #CmdBuff       ; load the input from terminal
            ldy     #Num1ASCII     ; load Num1
            clrb                
                        
Num1Loop    ldaa    1,X+
            jsr     echoPrint               
            
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
            jsr     echoPrint   
            
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
h2ad            clr   HCount    
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


;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip

prompt         DC.B    'Ecalc>  ', $00
indent         DC.B    '        ', $00
equal          DC.B    '=', $00
minus          DC.B    '-', $00

errmsg1        DC.B    '        Invalid input format', $00
errmsg2        DC.B    '        Overflow error', $00



               END               ; last line of file
                                 