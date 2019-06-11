.model flat,stdcall 
option casemap:none 
include \masm32\include\windows.inc 
include \masm32\include\kernel32.inc 
include \masm32\include\comdlg32.inc 
include \masm32\include\user32.inc 
include \masm32\include\msvcrt.inc 
includelib \masm32\lib\kernel32.lib 
includelib \masm32\lib\comdlg32.lib 
includelib \masm32\lib\user32.lib 
includelib \masm32\lib\msvcrt.lib 
include \masm32\include\masm32rt.inc
include data.inc
include mylibs.inc
includelib drd.lib
include drd.inc

.686
.data

arptr DWORD ?
coderunptr DWORD ?
codewriteptr dword ?

file_handler HANDLE ?

snapptr DWORD ?

surv1handle DWORD ?

thread_run_ptr dword ?

exception_handler dword ?

.code

;update_changes proc
;	mov ecx, 0ffffh
;	mov edi, arptr
;	mov al, 0cch
;
;	checkloop:
;	repe scasb
;	stosb
;	loop checkloop
;
;	ret
;
;update_changes endp

;thread_snap proc, survsnap:DWORD
;	push eax
;	mov eax, survsnap
;	mov [eax + snst.ebxptr], ebx
;	pop ebx
;	mov [eax + snst.eaxptr], ebx
;	mov [eax + snst.edxptr], edx
;	mov [eax + snst.esiptr], esi
;	mov [eax + snst.espptr], esp
;	mov [eax + snst.ediptr], edi
;	mov [eax + snst.ebpptr], ebp
;
;	ret
;thread_snap endp


;load_snap proc survsnap:dword
;	mov eax, survsnap
;	mov ecx, [eax + snst.ecxptr]
;	mov edi, [eax + snst.ediptr]
;
;	leave
;	pop edx
;	leave 
;	pop ebx
;	mov esp, [eax + snst.espptr]
;	mov ebp, [eax + snst.ebpptr]
;	push ebx
;	push ebp
;	mov ebp, esp
;	push edx
;	push ebp
;	mov ebp, esp
;
;	mov ebx, [eax + snst.ebxptr]
;	mov edx, [eax + snst.edxptr]
;	mov esi, [eax + snst.esiptr]
;
;	mov eax, [eax + snst.eaxptr]
;
;	ret
;load_snap endp

;handle_exception proc ExceptionRecord:dword, EstablisherFrame:dword, ContextRecord:dword, DispatcherContext:dword
;	mov eax, ContextRecord
;	add eax, 156
;
;	;check if survivor moved last turn
;	mov edx, [eax + 28] ;eip
;	mov ebx, snapptr
;	add ebx, snst.survptr
;	mov ecx, [ebx]
;	sub ecx, ardif
;	.if edx == ecx ;if survivor stayed in place
;		
;	.endif
;
;	;updates survivor location
;	add edx,ardif
;	mov [ebx], edx
;
;	mov edi, [eax]
;	mov esi, [eax + 4]
;	mov ebx, [eax + 8]
;	mov edx, [eax + 12]
;	mov ecx, [eax + 16]
;	mov ebp, [eax + 24]
;	mov esp, [eax + 40]
;	mov eax, [eax + 20]
;
;	mov ebx, snapptr
;	invoke thread_snap, ebx
;
;	invoke update_changes
;
;	mov eax, thread_run_ptr
;	push snapptr
;	call eax
;
;handle_exception endp

;thread_run proc survsnap:dword
;	
;	invoke write_next_instruction, survsnap
;
;	mov eax, survsnap
;	mov ebx, eax
;	add eax, snst.survptr
;	mov eax, [eax]
;	sub eax, ardif
;	leave
;	push eax
;	push ebp
;	mov ebp, esp
;
;	invoke load_snap, ebx
;	ret
;thread_run endp

;thread_setup proc survsnap:dword
;	invoke OutputDebugString, offset newsurvset
;	invoke VirtualAlloc, 0, exandstackallocsize, MEM_COMMIT, PAGE_READWRITE
;	mov edi, eax
;	add edi, 01000h
;	push eax
;	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
;	pop eax
;	add eax, 02000h
;	push eax
;	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
;	pop eax
;	add eax, 02000h
;	push eax
;	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
;	pop esp
;
;	mov eax, survsnap
;	mov ebx, eax ;keep survsnap in ebx
;	add eax, snst.survptr
;	mov eax, [eax]
;	mov esi, arptr
;	xor ecx, ecx
;	xor ebx, ebx
;	xor edx, edx
;
;	db 0cch
;
;	ret
;	;invoke thread_run, survsnap
;thread_setup endp

reset_armain proc
	;fill up all allocated memory with illegal instructions
	mov edi, startofallocptr
	mov ebx, 4
	xor edx, edx
	mov eax, allocedmemsize
	div ebx
	mov ecx, eax
	mov eax, 0cccccccch
	rep stosd

	ret
reset_armain endp

new_surv_loc proc survsnaplp:dword
	;generate random number for a new survivor location
	RETRY:
	rdtsc
	xor edx, edx
	mov ebx, 0fcffh
	div ebx
	add edx, 0100h
	add edx, arptr
	mov ecx, max_survs
	mov ebx, offset my_snaps

	push edx
	LOCCHECKLOOP:
	cmp ebx, survsnaplp
	je FINISHLOCCHECKLOOP
	pop eax
	push eax
	sub eax, [ebx.snapstruct].survptr
	mov edx, eax
	sar edx, 31
	xor eax, edx
	sub eax, edx
	cmp eax, 512
	jb RETRY

	FINISHLOCCHECKLOOP:
	add ebx, sizeof snapstruct
	loop LOCCHECKLOOP
	pop eax

	ret
new_surv_loc endp

write_surv macro writeloc, filename
	mov file_handler, fopen(filename)
	mov eax, fread(file_handler, writeloc, 512)
	fclose file_handler 
endm

thread_setup_macro macro filename1, filename2, survsnap1, survsnap2, affiliation
	push ebp
	mov ebp, esp
	invoke new_surv_loc, offset survsnap1
	mov survsnap1.survptr, eax
	write_surv survsnap1.survptr, filename1

	mov eax, affiliation
	add eax, affiliation
	dec eax
	mov bx, 4
	mul bx
	mov ebx, offset my_colors
	add ebx, eax
	mov eax, [ebx]
	mov survsnap1.color, eax
	add ebx, 4
	mov eax, [ebx]
	mov survsnap2.color, eax

	invoke OutputDebugString, offset newsurvset
	invoke VirtualAlloc, 0, exandstackallocsize, MEM_COMMIT, PAGE_READWRITE
	mov edi, eax
	add edi, 01000h
	mov survsnap1.exstart, edi
	push eax
	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
	pop eax
	add eax, 02000h
	push eax
	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
	pop eax
	add eax, 02000h
	push eax
	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
	pop esp

	mov eax, survsnap1.survptr
	mov esi, arptr
	xor ecx, ecx
	mov edx, survsnap1.color
	mov ebx, affiliation
	db 0cch

	mov esp, ebp
	
	invoke new_surv_loc, offset survsnap2
	mov survsnap2.survptr, eax
	write_surv survsnap2.survptr, filename2

	mov eax, survsnap1.exstart
	mov survsnap2.exstart, eax

	invoke OutputDebugString, offset newsurvset
	invoke VirtualAlloc, 0, exandstackallocsize - 02000h, MEM_COMMIT, PAGE_READWRITE
	push eax
	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
	pop eax
	push eax
	add eax, 02000h
	invoke VirtualProtect, eax, 0fffh, PAGE_NOACCESS, offset trashpointer
	pop esp

	mov eax, survsnap2.survptr
	mov esi, arptr
	xor ecx, ecx
	mov edx, survsnap2.color
	mov ebx, affiliation 

	db 0cch

	mov esp, ebp
	pop ebp
	;invoke thread_run, survsnap
endm

main proc
	;allocate memory for the game
	invoke OutputDebugString, offset arenaset ;tell control code to listen in for the arena ptr 
	invoke VirtualAlloc , 0 , allocedmemsize, MEM_COMMIT, PAGE_EXECUTE_READWRITE ;allocate memory for the arena
	mov startofallocptr, eax
	mov ebx, eax
	add eax, ardif
	xor ax,ax
	mov arptr, eax
	db 0cch ;tell debugger to now check for the arena ptr

	invoke OutputDebugString, offset setupstartstate
	db 0cch ;tell debugger to remember this program state to reset to after each round

	;reset the arenas
	invoke reset_armain
	
	thread_setup_macro "surv1-1", "surv1-2", my_snaps.surv1snap, my_snaps.surv2snap, 1

	thread_setup_macro "surv2-1", "surv2-2", my_snaps.surv3snap, my_snaps.surv4snap, 2

	invoke OutputDebugString, offset startgame
	db 0cch ;tell debugger to start the game

	ret
main endp
end main