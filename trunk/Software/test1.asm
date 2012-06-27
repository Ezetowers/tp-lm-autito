; Programa del control remoto
MASKLOWOR equ 00001111b
MASKLOWAND equ 11110000b
MASKHIGHAND equ 00001111b

SYNCWORD equ 01111111b
CANTREPSYNC equ 20

bseg at 0x30
; Si vale 1 le indica a la funci�n SHIFTVEL que debe 
; hacer un right shift
flagVel: dbit 1
flagSyncVel: dbit 1

cseg at 0x00
	jmp PRINCIPAL

	org 0x03
EX0ISR:
	; Salto a la rutina de interrupci�n externa 0
	jmp INTEX0ISR

	org 0x13
EX1ISR:
	; Salto a la rutina de interrupci�n externa 1
	jmp INTEX1ISR

	org 0x23
PSISR:
	jmp INTPSISR
	
	org 0x30
PRINCIPAL:							   
	; Primero habilito las interrupciones en el programa
	setb ex0
	setb ex1
	setb es
	setb ea
	; Habilito a las interrupciones externas para que se habiliten 
	; por flanco negativo
	setb it0
	setb it1
	; Guardo en el DPTR la posici�n de la tabla
	mov DPH, #high(TABLA)
	mov DPL, #low(TABLA)
	; Coloco un valor inicial en el puerto 1
	mov P1, #00000110b
	; Uso a R0 como contador
	mov R0, #1
	; Utilizo el temporizador 0 para generar delays y el 
	; temporizador 1 para generar la tasa en baudios del 
	; puerto serie (2400)
	mov scon, #0x50
	mov tmod, #0x21
	mov th1, #-24
	setb tr1
	; El programa principal del control tiene que censar lo 
	; que recibe en el puerto 2 y seg�n eso enviar al autito 
	; para que direcci�n moverse
	mov P2, #11101111b
	; Pongo el flag de sincronizaci�n en 1 para avisarle al 
	; puerto serie que antes de empezar a enviar informaci�n 
	; mande las palabras de sincronismo
	setb flagSyncVel
	; Inicializo el valor de palabras de sincronizaci�n a enviar
	mov R6, #CANTREPSYNC
	setb TI
	jmp $

INTEX0ISR:
	; Pongo en un el flag de sincronizaci�n
	setb flagSyncVel
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 0, incremento y muestro 
	; si es que tengo que hacerlo
	cjne r0, #4, JMP1
	; Es igual a 4, no hago nada
	jmp FIN1
JMP1: 	
	call INCVEL
	inc R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero hasta que el usuario suelte el bot�n
	jnb P3.2, $
	; El usuario solt� el bot�n, genero un delay para 
	; saltear los rebotes
	call DELAY
FIN1:
	reti

DELAY:
	; Espero que pasen aproximadamente 300 ms para asegurarme 
	; que hayan pasado todos los rebotes
	; Cargo el temporizador para que desborde a los 300ms
	mov R5, #31
LOOP:
	djnz R5, LABEL
	; El contador lleg� a cero, termino		 
	jmp FIN
LABEL:
	mov th0, #high(-10000)
	mov tl0, #low(-10000)
	; Lo activo y espero que pasen los 300 ms
	setb tr0
	jnb tf0, $
	; Pasaron los 300 ms, borro los flags del temporizador
	; y termino
	clr tr0
	clr tf0
	jmp LOOP
FIN:
	clr tr0
	clr tf0
	clr ie0
	ret
	
INTEX1ISR:
	; Pongo en un el flag de sincronizaci�n
	setb flagSyncVel
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 1, decremento y muestro si es 
	; que tengo que hacerlo
	cjne r0, #1, JMP2
	; Es igual a 1, no hago nada
	jmp FIN2
JMP2: 	
	call DECVEL
	dec R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero a que el usuario suelte el bot�n
	jnb P3.3, $
	; El usuario solt� el bot�n, genero un delay para 
	; saltear los rebotes
	call DELAY
FIN2:
	reti

INCVEL:
	setb flagVel
	call SHIFTVEL
	ret

DECVEL:
	clr flagVel
	call SHIFTVEL
	ret									 

SHIFTVEL:
	; Este m�todo se encarga de cambiar la velocidad del 
	; auto desplazando un bit entre 4.
	; Velocidades: 
	; 0001 -> 1
	; 0010 -> 2
	; 0100 -> 3
	; 1000 -> 4
	; Pongo en 1 la parte baja del puerto P2
	mov A, P2
	orl A, #MASKLOWOR
	; Complemento el dato
	cpl A
	; Shifteo a la izquierda o a la derecha seg�n corresponda
	jnb flagVel, RSHIFT
	rl A
	jmp CONT
RSHIFT:
	rr A
CONT:
	; Ahora que ya hice el shift, complemento y escribo en el puerto
	cpl A
	mov P2, A
	ret
	 
INTPSISR:
	; Verifico que el flag de sincronismo este en 1
	jnb flagSyncVel, SYNCRONIZE
	; Es igual a cero, no necesito sincronizar
	mov A, P2
	cpl A
DSPSYNC:
	mov sbuf, A
	clr TI
	reti

SYNCRONIZE:
	; Verifico cuantas palabras de sincronizaci�n se mandaron
	djnz R6, CONTSYNC
	; No salt�, mand� todas las palabras de sincronizac��n
	mov R6, #CANTREPSYNC
	clr flagSyncVel
CONTSYNC:
	; Mando la palabra de sincronizaci�n
	mov A, #SYNCWORD
	jmp DSPSYNC

TABLA: db 01011111b, 00000110b, 00111011b, 00101111b, 01100110b, 01101101b, 01111101b, 00000111b, 01111111b, 01100111b
end	