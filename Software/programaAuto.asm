; Programa del auto

MVEL equ 11110000b
MDIR equ 00001111b
VALDIR1 equ 00001110b
VALDIR2 equ 00001101b
VALDIR3 equ 00001011b
VALDIR4 equ 00000111b

;
LENARRAYVEL equ 16
LENARRAYDIR equ 4

; Valores de carga de los temporizadores para generar las cuadradas
CTE1VEL1DIR1 equ -6000
CTE2VEL1DIR1 equ -4000
CTE1VEL1DIR2 equ -6000
CTE2VEL1DIR2 equ -4000
CTE1VEL1DIR3 equ -6000
CTE2VEL1DIR3 equ -4000
CTE1VEL1DIR4 equ -6000
CTE2VEL1DIR4 equ -4000
CTE1VEL2DIR1 equ -7000
CTE2VEL2DIR1 equ -3000
CTE1VEL2DIR2 equ -7000
CTE2VEL2DIR2 equ -3000
CTE1VEL2DIR3 equ -7000
CTE2VEL2DIR3 equ -3000
CTE1VEL2DIR4 equ -7000
CTE2VEL2DIR4 equ -3000
CTE1VEL3DIR1 equ -8000
CTE2VEL3DIR1 equ -2000
CTE1VEL3DIR2 equ -8000
CTE2VEL3DIR2 equ -2000
CTE1VEL3DIR3 equ -8000
CTE2VEL3DIR3 equ -2000
CTE1VEL3DIR4 equ -8000
CTE2VEL3DIR4 equ -2000
CTE1VEL4DIR1 equ -9900
CTE2VEL4DIR1 equ -100
CTE1VEL4DIR2 equ -9900
CTE2VEL4DIR2 equ -100
CTE1VEL4DIR3 equ -9900
CTE2VEL4DIR3 equ -100
CTE1VEL4DIR4 equ -9900
CTE2VEL4DIR4 equ -100

; Constante que indica la cantidad de veces que voy a chequear el dato proveniente del puerto serie
CANTREP equ 10

dseg at 0x30
; Variable en la cual voy a almacenar la posici�n de la tabla desde la cual
; leo los valores de carga de los temporizadores
pointerTable: ds 1
; Variable que guardar� la posici�n en el subarray de velocidades del valor
; de recarga del temporizador 
offsetDir: ds 1
; Variable auxiliar que utilizo para verificar que el dato recibido es correcto
flagData: ds 1

cseg at 0x00
	jmp PRINCIPAL
		
	org 0x23
PSISR:
	; Salto a la rutina de interrupci�n del puerto serie
	jmp INTPSISR

PRINCIPAL:
	; Habilitaci�n de interrupciones
	setb ea
	setb es
	clr RI
	; Configuro el temporizador 0 para generar las cuadradas en modo 1
	mov tmod, #0x01
	; Configuro el puerto serie para escuchar
	mov scon, #0x50
	; Utilizo el temporizador 1 para generar la tasa en baudios del puerto serie
	mov tmod, #0x21
	mov th1, #-24
	setb tr1
	; Inicializo al flag de Data en 0
	mov flagData, #0x00
	; Uso a R5 como contador para la verificaci�n del dato correcto proveniente del RF
	mov R5, #CANTREP
	; Espero a que se generen interrupciones externas del puerto serie
	jmp $
	 
INTPSISR:
	; Interrupci�n del puerto serie. Recibo una palabra y seg�n el valor le�do veo que acciono
	; Verifico que el dato que recibo sea correcto
	cjne R5, #CANTREP, NOFIRSTTIME
	; Es la primera vez que entra, leo el puerto y guardo el valor en R0
	mov R0, sbuf
NOFIRSTTIME:
	; Chequeo que el dato recibido sea correcto leyendo el puerto nuevamente y comparando los valores
	call CHECKDATA
	mov A, flagData
	cjne A, #-1, CONTPSISR
	; Es igual a -1 la comunicaci�n es erronea
	mov R5, #CANTREP
	JMP FINPSISR
CONTPSISR:
	; El dato recibido es correcto, verifico que la cantidad de veces que se haya 
	; recibido sea el dato sea la esperada
	djnz R5, FINPSISR
	; Le� CANTREP veces el mismo dato en la comunicaci�n, est� libre de errores
	mov P2, R0
	; Actualizo el estado de las velocidades
	call CHANGEVEL
	call CHANGEMOTORS
	clr RI
FINPSISR:
	reti

CHECKDATA:
	; Leo el dato del puerto serie y lo comparo con el primer dato le�do
	mov A, sbuf
	mov flagData, R0
	cjne A, flagData, ERRORCOM
	; Los datos son iguales, al comunicaci�n puede ser correcta
	mov flagData, #0
	jmp FINDATA
ERRORCOM:
	; El dato es erroneo, pongo un -1 en la bandera
	mov flagData, #-1
FINDATA:
	ret

CHANGEVEL:	
	mov A, R0
	; TODO: Falta validar el correcto estado de los bits de velocidad
	jnb acc.4, LVEL1
	jnb acc.5, LVEL2
	jnb acc.6, LVEL3
	jnb acc.7, LVEL4
FINVEL:
	ret 

LVEL1:
	mov pointerTable, #0
	jmp FINVEL
LVEL2:
	mov	pointerTable, #16
	jmp	FINVEL
LVEL3:
	mov pointerTable, #32
	jmp FINVEL
LVEL4:
	mov pointerTable, #48
	jmp FINVEL

CHANGEMOTORS:
	; Verifico que combinaci�n me lleg� en los bits de direcci�n. Primero borro los bits
	; de velocidad para poder comparar con las m�scaras correspondientes y luego activo
	; los motores seg�n lo recibido.
	mov A, R0
	anl A, #MDIR

	; Direcci�n 1: Acelerar hacia adelante
	; P1.2 = 1, P1.3 = 0, P1.0 = 1, P1.6 = 0
	cjne A, #VALDIR1,CASE2
	mov P1, #00110101b
	mov offsetDir, #0
	jmp GENCUADRADA

	; Direcci�n 2: Acelerar hacia atr�s
	; P1.2 = 0, P1.3 = 1, P1.0 = 0, P1.6 = 1
CASE2:
	cjne A, #VALDIR2, CASE3
	mov P1, #01111000b
	mov offsetDir, #4
	jmp GENCUADRADA

	; Direcci�n 3: Doblar a la Derecha
	; P1.2 = 1, P1.3 = 1, P1.0 = 1, P1.6 = 0
CASE3:
	cjne A, #VALDIR3, CASE4
	mov P1, #00111101b
	mov offsetDir, #8
	jmp GENCUADRADA

	; Direcci�n 4: Doblar a la Izquierda
	; P1.2 = 1, P1.3 = 0, P1.0 = 1, P1.6 = 1
CASE4:
	cjne A, #VALDIR4, DEFAULT
	mov P1, #01110101b
	mov offsetDir, #12
	call GENCUADRADA
DEFAULT:
	ret

GENCUADRADA:
	; Primero armo el valor del puntero de la tabla
	mov A, pointerTable
	add A, offsetDir
	mov R1, A
	mov DPH, #high(TABLE)
	mov DPL, #low(TABLE)
	; Leo el primer valor de carga y lo cargo en el temporizador
	movc A,@A+DPTR
	mov th0, A
	inc DPTR
	mov A, R1
	movc A,@A+DPTR
	mov tl0, A
	; Acciono al temporizador y espero a que pase la cuenta
	setb P1.1
	setb P1.7
	setb tr0
	jnb tf0, $
	clr tr0
	clr tf0
	; Termin�, cargo el otro valor de carga y realizo el mismo procedimiento
	inc DPTR
	mov A, R1
	movc A, @A+DPTR
	mov th0, A
	inc DPTR 
	mov A, R1
	movc A, @A+DPTR
	mov tl0, A
	clr P1.1 
	clr P1.7
	setb tr0
	jnb tf0, $
	clr tr0
	clr tf0
	ret

TABLE: dw CTE1VEL1DIR1, CTE2VEL1DIR2, CTE1VEL1DIR2, CTE2VEL1DIR2, CTE1VEL1DIR3, CTE2VEL1DIR3, CTE1VEL1DIR4, CTE2VEL1DIR4, CTE1VEL2DIR1, CTE2VEL2DIR2, CTE1VEL2DIR2, CTE2VEL2DIR2, CTE1VEL2DIR3, CTE2VEL2DIR3, CTE1VEL2DIR4, CTE2VEL2DIR4, CTE1VEL3DIR1, CTE2VEL3DIR2, CTE1VEL3DIR2, CTE2VEL3DIR2, CTE1VEL3DIR3, CTE2VEL3DIR3, CTE1VEL3DIR4, CTE2VEL3DIR4, CTE1VEL4DIR1, CTE2VEL4DIR2, CTE1VEL4DIR2, CTE2VEL4DIR2, CTE1VEL4DIR3, CTE2VEL4DIR3, CTE1VEL4DIR4, CTE2VEL4DIR4
end
