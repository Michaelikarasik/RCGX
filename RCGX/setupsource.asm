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
ASSUME FS:NOTHING

;reset_arwrite proc
;	;fill up all allocated memory with illegal instructions
;	mov edi, codewriteptr
;	mov ebx, 4
;	xor edx, edx
;	mov eax, allocedmemsize
;	div ebx
;	mov ecx, eax
;	mov eax, 0cccccccch
;	rep stosd
;
;	ret
;reset_arwrite endp

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

;reset_arrun proc
;	;fill up all allocated memory with illegal instructions
;	mov edi, coderunptr
;	mov ebx, 4
;	xor edx, edx
;	mov eax, 010000h
;	div ebx
;	mov ecx, eax
;	mov eax, 0cccccccch
;	rep stosd
;
;	ret
;reset_arrun endp

update_changes proc
	mov ecx, 0ffffh
	mov edi, arptr
	mov al, 0cch

	checkloop:
	repe scasb
	stosb
	loop checkloop

	ret

update_changes endp

thread_snap proc, survsnap:DWORD
	push eax
	mov eax, survsnap
	mov [eax + snst.ebxptr], ebx
	pop ebx
	mov [eax + snst.eaxptr], ebx
	mov [eax + snst.edxptr], edx
	mov [eax + snst.esiptr], esi
	mov [eax + snst.espptr], esp
	mov [eax + snst.ediptr], edi
	mov [eax + snst.ebpptr], ebp

	ret
thread_snap endp

;write_next_instruction proc survsnap:dword
;	mov ebx, survsnap
;	add ebx, snst.survptr
;	invoke length_disasm, [ebx]
;	mov ecx, eax
;	mov esi, [ebx]
;	mov edi, esi
;	sub edi, ardif
;
;	rep movsb
;
;	ret
;write_next_instruction endp

load_snap proc survsnap:dword
	mov eax, survsnap
	mov ecx, [eax + snst.ecxptr]
	mov edi, [eax + snst.ediptr]

	leave
	pop edx
	leave 
	pop ebx
	mov esp, [eax + snst.espptr]
	mov ebp, [eax + snst.ebpptr]
	push ebx
	push ebp
	mov ebp, esp
	push edx
	push ebp
	mov ebp, esp

	mov ebx, [eax + snst.ebxptr]
	mov edx, [eax + snst.edxptr]
	mov esi, [eax + snst.esiptr]

	mov eax, [eax + snst.eaxptr]

	ret
load_snap endp

handle_exception proc ExceptionRecord:dword, EstablisherFrame:dword, ContextRecord:dword, DispatcherContext:dword
	mov eax, ContextRecord
	add eax, 156

	;check if survivor moved last turn
	mov edx, [eax + 28] ;eip
	mov ebx, snapptr
	add ebx, snst.survptr
	mov ecx, [ebx]
	sub ecx, ardif
	.if edx == ecx ;if survivor stayed in place
		
	.endif

	;updates survivor location
	add edx,ardif
	mov [ebx], edx

	mov edi, [eax]
	mov esi, [eax + 4]
	mov ebx, [eax + 8]
	mov edx, [eax + 12]
	mov ecx, [eax + 16]
	mov ebp, [eax + 24]
	mov esp, [eax + 40]
	mov eax, [eax + 20]

	mov ebx, snapptr
	invoke thread_snap, ebx

	invoke update_changes

	mov eax, thread_run_ptr
	push snapptr
	call eax

handle_exception endp

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


thread_setup proc survsnap:dword
	invoke OutputDebugString, offset newsurvset
	invoke VirtualAlloc, 0, exandstackallocsize, MEM_COMMIT, PAGE_READWRITE
	mov edi, eax
	add edi, 01000h
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

	mov eax, survsnap
	mov ebx, eax ;keep survsnap in ebx
	add eax, snst.survptr
	mov eax, [eax]
	mov esi, arptr
	xor ecx, ecx
	xor ebx, ebx
	xor edx, edx

	db 0cch

	ret
	;invoke thread_run, survsnap
thread_setup endp

new_surv_loc proc	
	;generate random number for a new survivor location
	retry:
	rdtsc
	xor edx, edx
	mov ebx, 0feffh
	div ebx
	add edx, 0100h
	add edx, arptr

	mov eax, edx
	mov ebx, surv1snap.survptr
	sub eax, ebx
	sub ebx, edx
	neg ebx

	mov ecx, edx
	mov edi, surv2snap.survptr
	sub ecx, edi
	sub edi, edx
	neg edi

	cmp eax, 512
	jl retry
	cmp ebx, 512
	jl retry
	cmp edx, 512
	jl retry
	cmp ecx, 512
	jl retry

	mov eax, edx
	mov ebx, surv3snap.survptr
	sub eax, ebx
	sub ebx, edx
	neg ebx

	mov ecx, edx
	mov edi, surv4snap.survptr
	sub ecx, edi
	sub edi, edx
	neg edi

	cmp eax, 512
	jl retry
	cmp ebx, 512
	jl retry
	cmp edx, 512
	jl retry
	cmp ecx, 512
	jl retry

	mov eax, edx
	ret
new_surv_loc endp

write_surv macro writeloc, filename
	mov file_handler, fopen(filename)
	mov eax, fread(file_handler, writeloc, 512)
	fclose file_handler 
endm

main proc

	;allocate memory for the game
	invoke OutputDebugString, offset arenaset
	invoke VirtualAlloc , 0 , allocedmemsize, MEM_COMMIT, PAGE_EXECUTE_READWRITE
	mov startofallocptr, eax
	mov ebx, eax
	add eax, ardif
	xor ax,ax
	mov arptr, eax
	db 0cch

	;reset the arenas
	invoke reset_armain
	
	invoke new_surv_loc
	mov surv1snap.survptr, eax
	write_surv surv1snap.survptr, "surv1-1"

	invoke new_surv_loc
	mov surv2snap.survptr, eax
	write_surv surv2snap.survptr, "surv2-1"

	invoke thread_setup, offset surv1snap 
	invoke thread_setup, offset surv2snap 

	;invoke new_surv_loc
	;mov surv3snap.survptr, eax
	;write_surv surv3snap.survptr, "surv3"
	;invoke thread_setup, offset surv3snap 
	;
	;invoke new_surv_loc
	;mov surv4snap.survptr, eax
	;write_surv surv4snap.survptr, "surv4"
	;invoke thread_setup, offset surv4snap 

	mov snapptr, offset surv1snap

	invoke OutputDebugString, offset startgame
	db 0cch

	ret
main endp
end main