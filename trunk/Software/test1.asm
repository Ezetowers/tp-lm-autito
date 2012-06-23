; Programa del control remoto
MASKLOWOR equ 00001111b
MASKLOWAND equ 11110000b
MASKHIGHAND equ 00001111b
MVEL2 equ 11011111b
MVEL3 equ 10111111b
MVEL4 equ 01111111b

SYNCWORD equ 11111111b
CANTREPSYNC equ 20

dseg at 0x30
; Si vale 1 le indica a la función SHIFTVEL que debe hacer un right shift
flagVel: ds 1
flagSyncVel: ds 1

cseg at 0x00
	jmp PRINCIPAL

	org 0x03
EX0ISR:
	; Salto a la rutina de interrupción externa 0
	jmp INTEX0ISR

	org 0x13
EX1ISR:
	; Salto a la rutina de interrupción externa 1
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
	; Habilito a las interrupciones externas para que se habiliten por flanco negativo
	setb it0
	setb it1
	; Guardo en el DPTR la posición de la tabla
	mov DPH, #high(TABLA)
	mov DPL, #low(TABLA)
	; Coloco un valor inicial en el puerto 1
	mov P1, #00000110b
	; Uso a R0 como contador
	mov R0, #1
	; Utilizo el temporizador 0 para generar delays y el temporizador 1
	; para generar la tasa en baudios del puerto serie (2400)
	mov scon, #0x50
	mov tmod, #0x21
	mov th1, #-24
	setb tr1
	; El programa principal del control tiene que censar lo que recibe en el puerto 2
	; y según eso enviar al autito para que dirección moverse
	mov P2, #11101111b
	; Pongo el flag de sincronización en 1 para avisarle al puerto serie que antes de empezar a enviar
	; información mande las palabras de sincronismo
	mov flagSyncVel, #1
	; Inicializo el valor de palabras de sincronización a enviar
	mov R6, #CANTREPSYNC
	setb TI
	jmp $

INTEX0ISR:
	; Pongo en un el flag de sincronización
	mov flagSyncVel, #1
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 0, incremento y muestro si es que tengo que hacerlo
	cjne r0, #4, JMP1
	; Es igual a 4, no hago nada
	jmp FIN1
JMP1: 	
	call INCVEL
	inc R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero hasta que el usuario suelte el botón
	jnb P3.2, $
	; El usuario soltó el botón, genero un delay para saltear los rebotes
	call DELAY
FIN1:
	;setb ea
	reti

DELAY:
	; Espero que pasen aproximadamente 300 ms para asegurarme que hayan pasado todos los rebotes
	; Cargo el temporizador para que desborde a los 300ms
	mov R5, #31
LOOP:
	djnz R5, LABEL
	; El contador llegó a cero, termino		 
	jmp FIN
LABEL:
	mov th0, #high(-10000)
	mov tl0, #low(-10000)
	; Lo activo y espero que pasen los 300 ms
	setb tr0
	jnb tf0, $
	; Pasaron los 300 ms, borro los flags del temporizador y termino
	clr tr0
	clr tf0
	jmp LOOP
FIN:
	clr tr0
	clr tf0
	clr ie0
	ret
	
INTEX1ISR:
	; Pongo en un el flag de sincronización
	mov flagSyncVel, #1
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 1, decremento y muestro si es que tengo que hacerlo
	cjne r0, #1, JMP2
	; Es igual a 1, no hago nada
	jmp FIN2
JMP2: 	
	call DECVEL
	dec R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero a que el usuario suelte el botón
	jnb P3.3, $
	; El usuario soltó el botón, genero un delay para saltear los rebotes
	call DELAY
FIN2:
	;setb ea
	reti

INCVEL:
	mov flagVel, #1
	call SHIFTVEL
	ret

DECVEL:
	mov flagVel, #0
	call SHIFTVEL
	ret

SHIFTVEL:
	; Pongo en 1 la parte baja del P2
	mov A, P2
	orl A, #MASKLOWOR
	cpl A
	mov R2, flagVel
	cjne R2, #1, RSHIFT
	rl A
	jmp CONT
RSHIFT:
	rr A
CONT:
	cpl A
	anl A, #MASKLOWAND
	mov R2, A
	mov A, P2
	anl A, #MASKHIGHAND
	add A, R2									   
	; TODO: CORREGIR ESTO
	orl A, #00001111b
	mov P2, A
	ret
	 
INTPSISR:
	; Verifico que el flag de sincronismo este en 1
	mov A, flagSyncVel
	cjne A, #0, SYNCRONIZE 
	; Es igual a cero, no necesito sincronizar
	mov A, P2
	cpl A
DSPSYNC:
	mov sbuf, A
	clr TI
	reti

SYNCRONIZE:
	; Verifico cuantas palabras de sincronización se mandaron
	djnz R6, CONTSYNC
	; No salté, mandé todas las palabras de sincronizacíón
	mov R6, #CANTREPSYNC
	mov flagSyncVel, #0
CONTSYNC:
	; Mando la palabra de sincronización
	mov A, #SYNCWORD
	jmp DSPSYNC

TABLA: db 01011111b, 00000110b, 00111011b, 00101111b, 01100110b, 01101101b, 01111101b, 00000111b, 01111111b, 01100111b
end	
