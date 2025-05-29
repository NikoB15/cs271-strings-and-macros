TITLE String Primitives and Macros     (Proj6_bransfim.asm)

; Author: Niko Bransfield
; Last Modified: 2023-11-27
; OSU email address: ONID_ID@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number: 6               Due Date: 2023-12-10
; Description: Prompts the user for 10 valid 32-bit signed integers, input as
;			   strings. Displays the numbers, their sum, and their average value.

INCLUDE Irvine32.inc

; =================================================
; Displays a prompt, then gets the user's keyboard
; input and saves it into a memory location.
; 
; Preconditions: Do not use EAX, ECX, or EDX 
;		as an argument
;
; Receives:
;		promptStr	= Address of the prompt message
;		userInput	= Address where the user input 
;					  should be stored
;		maxChars    = The maximum allowed length of
;				      the input string
;		bytesRead	= Address which will contain the
;					  number of chars entered
;
; Returns:
;		userInput = user keyboard input
;		bytesRead = number of characters entered
; =================================================
mGetString MACRO promptStr:REQ, userInput:REQ, maxChars:REQ, bytesRead:REQ
	push	eax
	push	ecx
	push	edx
	
	mov		edx, promptStr
	call	WriteString
	mov		edx, userInput
	mov		ecx, maxChars
	call	ReadString
	mov		bytesRead, eax

	pop		edx
	pop		ecx
	pop		eax
ENDM



; =================================================
; Prints the string at the specified memory location
; 
; Preconditions: Do not use EDX as an argument
;
; Receives:
;		string = Address of the string to print
; =================================================
mDisplayString MACRO string:REQ
	push	edx

	mov		edx, string
	call	WriteString

	pop		edx
ENDM




INPUT_COUNT = 10

.data
introMsg			BYTE	"   String Primitives & Macros            by Niko Bransfield",13,10,13,10,
							"Input ten integers and I'll print them back to you, along with",13,10,
							"their sum and average value.",13,10,13,10,0
inputPrompt			BYTE	"Please enter a signed integer: ",0
repeatPrompt		BYTE	"INVALID INPUT! What you entered either isn't an integer or can't be stored in 32 bits!",13,10,0
arrayDisplayMsg		BYTE	13,10,13,10,"You entered the following numbers:",13,10,0
arraySumMsg			BYTE	13,10,"The sum of these numbers is: ",0
arrayAverageMsg		BYTE	13,10,"The truncated average is: ",0
goodbyeMsg			BYTE	13,10,13,10,"Goodbye!",0
arrayDelimiter		BYTE	", ",0
userInput			BYTE	33 DUP(0)
intToStringBuffer	BYTE	12 DUP(0)
userNumber			SDWORD	0
intArray			SDWORD	INPUT_COUNT DUP(0)
intArraySum			SDWORD	?
intArrayAverage		SDWORD	?


.code
main PROC

	mDisplayString		OFFSET introMsg

; --------------------------------
; Get 10 numbers from the user and
; store them in an array
; --------------------------------
	mov		edi, OFFSET intArray
	mov		ecx, INPUT_COUNT
	cld
_inputLoop:
	; Get valid integer
	push	OFFSET inputPrompt
	push	OFFSET repeatPrompt
	push	OFFSET userInput
	push	LENGTHOF userInput
	push	OFFSET userNumber
	call	ReadVal

	; Store in array
	mov		eax, userNumber
	mov		[edi], eax
	add		intArraySum, eax			; Keep a running total of the input numbers
	add		edi, 4
	loop	_inputLoop

; -----------------
; Print the numbers
; -----------------
	mDisplayString		OFFSET arrayDisplayMsg

	mov		esi, OFFSET intArray
	mov		ecx, INPUT_COUNT
	cld
_printLoop:
	push	[esi]
	push	OFFSET intToStringBuffer
	push	LENGTHOF intToStringBuffer
	call	WriteVal
	add		esi, 4
	; Add a delimiter after every number
	; in the list except the last
	cmp		ecx, 1
	je		_skipDelim
	mDisplayString		OFFSET arrayDelimiter
_skipDelim:
	loop	_printLoop

; -------------------------
; Print the sum and average
; -------------------------
	; print sum
	mDisplayString		OFFSET arraySumMsg
	push	intArraySum
	push	OFFSET intToStringBuffer
	push	LENGTHOF intToStringBuffer
	call	WriteVal

	; calculate average
	cdq
	mov		eax, intArraySum
	mov		ebx, INPUT_COUNT
	idiv	ebx
	; print average
	mDisplayString		OFFSET arrayAverageMsg
	push	eax
	push	OFFSET intToStringBuffer
	push	LENGTHOF intToStringBuffer
	call	WriteVal

	mDisplayString		OFFSET goodbyeMsg

	Invoke ExitProcess,0	; exit to operating system
main ENDP




; =================================================
; Prompts the user for a 32-bit signed integer.
; If the entered text is invalid, prompts the user
; again until they input a valid number.
; Stores the resulting number in a memory variable.
; 
; Preconditions: Input array is of type BYTE and has
;		a length >= 13
;
; Postconditions: The input array and EFLAGS may be changed.
;
; Receives:
;		[ebp + 24]	= Address of the prompt message
;		[ebp + 20]	= Address of the "invalid input"
;					  message
;		[ebp + 16]	= Address of user input array
;		[ebp + 12]	= Length of user input array
;		[ebp + 8]	= Output address
;		MIN_INT and MAX_INT are global constants.
;
; Returns: The output address contains the valid
;		   user input
; =================================================
ReadVal PROC
	LOCAL	numberLength:DWORD, currentChar:BYTE, isNegative:SDWORD, digitOffset:SDWORD
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi

_startPrompt:
	mGetString		[ebp+24], [ebp+16], [ebp+12], numberLength
	
	; If the input is empty, retry
	cmp		numberLength, 0
	jz		_invalidInput

; -----------------------------------
; Check for a sign character (+ or -)
; at the beginning of the string
; -----------------------------------
	mov		esi, [ebp+16]
	mov		isNegative, 0
	mov		digitOffset, 0

	mov		al, [esi]
	cmp		al, '-'
	je		_isNegative
	cmp		al, '+'
	je		_hasSignChar
	jmp		_signChecked
_isNegative:
	inc		isNegative
_hasSignChar:
	; If the string has a sign char,
	; ignore that char moving forward
	mov		digitOffset, 1				; used for skipping the first element in the array
	dec		numberLength
_signChecked:

; -----------------------------
; Convert input chars to digits
; -----------------------------
	add		esi, digitOffset
	mov		edi, esi
	mov		ecx, numberLength
	cld

_charLoop:
	; Convert ASCII digits to numeric form
	lodsb
	cmp		al, 48
	jb		_invalidInput
	cmp		al, 57
	ja		_invalidInput
	sub		al, 48
	stosb
	loop	_charLoop

; ---------------------------------
; Build the integer from the digits
; ---------------------------------
	mov		esi, [ebp+16]
	add		esi, digitOffset

	mov		edi, [ebp+8]
	mov		eax, 0
	mov		[edi], eax					; clear the value in the output address
	mov		ecx, numberLength
	mov		ebx, 10
	cld

_intLoop:
	; Multiply current number by 10
	mov		eax, [edi]
	imul	ebx
	jo		_invalidInput				; Make sure our number can be stored as a 32-bit integer

	mov		[edi], eax
	; Add or subtract the next digit
	xor		eax, eax
	lodsb

	cmp		isNegative, 1
	je		_subtractDigit
	add		[edi], eax
	jo		_invalidInput				; Make sure our number can be stored as a 32-bit integer
	jmp		_finishDigit
_subtractDigit:
	sub		[edi], eax
	jo		_invalidInput				; Make sure our number can be stored as a 32-bit integer
_finishDigit:
	loop	_intLoop
	jmp		_endConversion

_invalidInput:
	; Write error message and prompt user again
	mDisplayString		[ebp+20]
	jmp		_startPrompt

_endConversion:

	pop		edi
	pop		esi
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	ret		20
ReadVal ENDP




; =================================================
; Converts a SDWORD into an ASCII string, using
; the provided array for compuation, and then
; prints the string to the user.
; 
; Preconditions: The provided array is of type BYTE
;		and has a length >= 12
;
; Postconditions: The array and EFLAGS may be changed.
;
; Receives:
;		[ebp + 16]	= SDWORD value
;		[ebp + 12]	= address of the array
;		[ebp + 8]	= size of the array
;
; =================================================
WriteVal PROC
	LOCAL	isNegative:BYTE
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi

	mov		eax, [ebp+16]
	mov		edi, [ebp+12]

; ------------------------------------
; Special Case: SDWORD == 0
; ------------------------------------
	cmp		eax, 0
	jne		_endZeroCheck
	mov		al, '0'
	mov		[edi], al
	jmp		_displayString
_endZeroCheck:

; ------------------------------------
; Check whether the SDWORD is negative
; ------------------------------------
	mov		isNegative, 0
	cmp		eax, 0
	jge		_endSignCheck
	inc		isNegative
_endSignCheck:

; -----------------------------------------
; Convert to a string of ASCII chars. We
; accomplish this by repeatedly dividing by
; 10 and taking the remainder. This gives
; the number in reverse order, so we also 
; store it in the array in reverse order.
; -----------------------------------------
	mov		ebx, 10
	; Start at the second-to-last array index and work backwards.
	add		edi, [ebp+8]
	sub		edi, 2
	std

_conversionLoop:
	cmp		eax, 0
	je		_endConversionLoop

	; Get next digit
	cdq
	idiv	ebx
	; Convert to ASCII and store in array
	push	eax
	
	; Ensure that the remainder is positive
	cmp		isNegative, 1
	jne		_alreadyPositive
	; Two's complement
	not		dl
	add		dl, 1

_alreadyPositive:
	mov		al, dl								; Remainder will always be between 0 and 9 at this point, so we only need to check DL
	add		al, 48
	stosb
	pop		eax
	jmp		_conversionLoop
_endConversionLoop:

; ----------------------------------------------
; Add a negative sign if the SDWORD was negative
; ----------------------------------------------
	cmp		isNegative, 1
	jne		_notNegative
	mov		al, '-'
	mov		[edi], al
	jmp		_displayString
_notNegative:
	inc		edi

_displayString:
	mDisplayString		edi

	pop		edi
	pop		esi
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	ret		12
WriteVal ENDP


END main
