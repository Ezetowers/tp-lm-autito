; Programa del control remoto
MASKLOWOR equ 00001111b
MASKLOWAND equ 11110000b
MASKHIGHAND equ 00001111b

SYNCWORD equ 10000000b
CANTREPSYNC equ 20

bseg at 0x30
; Si vale 1 le indica a la función SHIFTVEL que debe 
; hacer un right shift
flagVel: dbit 1
flagSyncVel: dbit 1

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
	; Inicializo el stack pointer en el primer registro del 
	; banco 1 debido a no utilizo este banco y al ser todas
	; las funciones del proyecto leafs, el stack no llega a 
	; ocupar más de dos o tres posiciones de memoria
	mov sp, #0x08
	; Primero habilito las interrupciones en el programa
	setb ex0
	setb ex1
	setb es
	setb ea
	; Habilito a las interrupciones externas para que se habiliten 
	; por flanco negativo
	setb it0
	setb it1
	; Guardo en el DPTR la posición de la tabla
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
	; que recibe en el puerto 2 y según eso enviar al autito 
	; para que dirección moverse
	mov P2, #11101111b
	; Pongo el flag de sincronización en 1 para avisarle al 
	; puerto serie que antes de empezar a enviar información 
	; mande las palabras de sincronismo
	setb flagSyncVel
	; Inicializo el valor de palabras de sincronización a enviar
	mov R6, #CANTREPSYNC
	setb TI
	jmp $

INTEX0ISR:
	; Pongo en un el flag de sincronización
	setb flagSyncVel
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 0, incremento y muestro 
	; si es que tengo que hacerlo
	cjne r0, #4, JMP11
	; Es igual a 4, no hago nada
	jmp FIN1
JMP11: 	
	; Espero un tiempo de 20ms. Si luego P3.2 = 1, 
	; entonces es un rebote y espero de nuevo hasta 
	; que P3.2 = 0
	call DELAY
	jb P3.2, JMP11
	; Pasé el primer rebote, incremento las velocidades y espero 
	; que el usuario suelte el botón
	call INCVEL
	inc R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero hasta que el usuario suelte el botón
	jnb P3.2, $
	; El usuario soltó el botón, hago lo mismo que arriba,
	; verifico que realmente lo haya soltado y no haya 
	; sido un rebote (a través de un DELAY) y luego
	; salgo 
JMP12:
	call DELAY
	jnb P3.2, JMP12
FIN1:
	reti
	
INTEX1ISR:
	; Pongo en un el flag de sincronización
	setb flagSyncVel
	mov R6, #CANTREPSYNC
	; Presionaron el pulsador 1, incremento y muestro 
	; si es que tengo que hacerlo
	cjne r0, #1, JMP21
	; Es igual a 1, no hago nada
	jmp FIN2
JMP21: 	
	; Espero un tiempo de 20ms. Si luego P3.3 = 1, 
	; entonces es un rebote y espero de nuevo hasta 
	; que P3.3 = 0
	call DELAY
	jb P3.3, JMP21
	; Pasé el primer rebote, incremento las velocidades y espero 
	; que el usuario suelte el botón
	call DECVEL
	dec R0
	mov A, R0
	movc A,@A+DPTR
	mov P1, A
	; Espero hasta que el usuario suelte el botón
	jnb P3.3, $
	; El usuario soltó el botón, hago lo mismo que arriba,
	; verifico que realmente lo haya soltado y no haya 
	; sido un rebote (a través de un DELAY) y luego
	; salgo 
JMP22:
	call DELAY
	jnb P3.3, JMP22
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
	
	DELAY:
	; Espero que pasen aproximadamente 50 ms para asegurarme 
	; que hayan pasado todos los rebotes
	; Cargo el temporizador para que desborde a los 300ms
	mov R5, #6
LOOP:
	djnz R5, LABEL
	; El contador llegó a cero, termino		 
	jmp FIN
LABEL:
	mov th0, #high(-10000)
	mov tl0, #low(-10000)
	; Lo activo y espero que pasen los 50 ms
	setb tr0
	jnb tf0, $
	; Pasaron los 50 ms, borro los flags del temporizador
	; y termino
	clr tr0
	clr tf0
	jmp LOOP
FIN:
	clr tr0
	clr tf0
	clr ie0
	ret								 

SHIFTVEL:
	; Este método se encarga de cambiar la velocidad del 
	; auto desplazando un bit entre 4.
	; Velocidades: 
	; 1110 -> 1
	; 1101 -> 2
	; 1011 -> 3
	; 0111 -> 4
	; Pongo en 1 la parte baja del puerto P2
	mov A, P2
	orl A, #MASKLOWOR
		
	; Shifteo a la izquierda o a la derecha según corresponda
	jnb flagVel, RSHIFT
	rl A
	jmp CONT
RSHIFT:
	rr A
CONT:
	; Ahora que ya hice el shift, escribo en el puerto
	mov P2, A
	ret
	 
INTPSISR:
	; Verifico que el flag de sincronismo este en 1
	jb flagSyncVel, SYNCRONIZE
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
	clr flagSyncVel
CONTSYNC:
	; Mando la palabra de sincronización
	mov A, #SYNCWORD
	jmp DSPSYNC

TABLA: db 01011111b, 00000110b, 00111011b, 00101111b, 01100110b, 01101101b, 01111101b, 00000111b, 01111111b, 01100111b
end	
