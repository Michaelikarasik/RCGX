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
	survptr dword 0
	stackptr dword ?
	exstart dword ?
	color dword ?
	survlength dword ?
snapstruct ends

seh struct
	prev dword ?
	handler dword ?
seh ends

debugstruct struct
	survcontext CONTEXT<>
	isdead dword 0
	stackstart dword ?
	stackend dword ?
	exstart dword ?
	exend dword ?
	segallocstart dword ?
	heavybombs dword 2
	smartbombs dword 1
	wincount dword 0
	affiliation dword ?
	afptr dword ?
	color dword ?
	survlength dword ?
debugstruct ends

surv_colors struct
	surv11 dword ?
	surv12 dword ?
	surv21 dword ?
	surv22 dword ?
	surv31 dword ?
	surv32 dword ?
	surv41 dword ?
	surv42 dword ?
surv_colors ends

all_snaps struct
	surv1snap snapstruct<>
	surv2snap snapstruct<>
	surv3snap snapstruct<>
	surv4snap snapstruct<>
	surv5snap snapstruct<>
	surv6snap snapstruct<>
	surv7snap snapstruct<>
	surv8snap snapstruct<>
all_snaps ends

teamscores struct
	team0 dword 0
	team1 dword 0
	team2 dword 0
	team3 dword 0
	team4 dword 0
teamscores ends

all_survs struct
	surv1db debugstruct<>
	surv2db debugstruct<>
	surv3db debugstruct<>
	surv4db debugstruct<>
	surv5db debugstruct<>
	surv6db debugstruct<>
	surv7db debugstruct<>
	surv8db debugstruct<>
all_survs ends

.data

allocedmemsize equ 020100h

ardif equ 10000h

stacksize equ 01000h
extrasegsize equ 01000h

max_survs equ 3 * 2

exandstackallocsize equ 01000h + stacksize + 01000h + extrasegsize + 01000h

setupstartstate db "sstartset", 0
arenaset db "arenaset", 0
newsurvset db "newsurvset", 0
startgame db "startgame", 0
findarenamsg db "findarena", 0

intcheckbuf word ?

trashpointer dword ?

startofallocptr dword ?

isdrawing dword 1

my_colors surv_colors<000ff0000h, 00000ff00h, 0000000ffh, 000ff5040h, 0007039d8h, 000294892h, 000583759h, 000295843h>
team_colors surv_colors<000cc0000h, 00000cc00h, 0000000cch, 000cccccch>
.data?

structured_handler seh<>

teamscorecount teamscores<>

my_snaps all_snaps<>
my_survs all_survs<>