.const

snst struct
	eaxptr dword 0
	ecxptr dword 4
	edxptr dword 8
	ebxptr dword 12
	espptr dword 16
	ebpptr dword 20
	esiptr dword 24
	ediptr dword 28
	survptr dword 32
	stackptr dword 36
	structlen dword 40
snst ends		 

snapstruct struct
	eaxptr dword ?
	ecxptr dword ?
	edxptr dword ?
	ebxptr dword ?
	espptr dword ?
	ebpptr dword ?
	esiptr dword ?
	ediptr dword ?
	survptr dword 0
	stackptr dword ?
snapstruct ends

seh struct
	prev dword ?
	handler dword ?
seh ends

debugstruct struct
	isdead dword 0
	stackstart dword ?
	stackend dword ?
	exstart dword ?
	exend dword ?
	survcontext CONTEXT<>
debugstruct ends

.data

allocedmemsize equ 020100h

ardif equ 10000h

stacksize equ 01000h
extrasegsize equ 01000h

arenaset db "arenaset", 0
newsurvset db "newsurvset", 0
startgame db "startgame", 0

findarenamsg db "findarena", 0

currentsurv byte ?
max_survs byte 4
intcheckbuf word ?

.data?
surv1snap snapstruct<>
surv2snap snapstruct<>
surv3snap snapstruct<>
surv4snap snapstruct<>

structured_handler seh<>

surv1db debugstruct<>
surv2db debugstruct<>
surv3db debugstruct<>
surv4db debugstruct<>