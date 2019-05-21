setupcontext macro survdb
		;get the process context after surv setup
		invoke GetThreadContext,pi.hThread, offset survdb.survcontext

		;get surv starting location
		mov eax, survdb.survcontext.regEax
		mov survdb.survcontext.regEip, eax

		;get surv stack start
		mov eax, survdb.survcontext.regEsp
		mov survdb.survcontext.regEbp, eax
		mov survdb.stackend, eax
		sub eax, 01000h
		mov survdb.stackstart, eax

		;get surv extra seg start
		mov eax, survdb.survcontext.regEdi
		mov survdb.exstart, eax
		add eax, 01000h
		mov survdb.exend, eax

		or survdb.survcontext.regFlag, 100h	

endm

handle_ints macro survdb
	local edinotabove, ediok, heavybombloop, edioutofbounds, inc_dec_edi
	invoke ReadProcessMemory, pi.hProcess, survdb.survcontext.regEip, offset intcheckbuf, 2, NULL
	mov ax, intcheckbuf
	.if al == 0ceh || al == 0b9h || al == 060h
		mov survdb.isdead, 1
		jmp survswitch
	.elseif al == 0cdh
		;if direction flag is set, move ebx to 4, else move to zero
		mov ebx, survdb.survcontext.regFlag
		and ebx, 0400h
		neg ebx
		sar ebx, 7
		add ebx, 4
		;check if player used heavy bomb
		.if ah == 086h
			;;setup heavy bomb
			mov ecx, 64
			mov eax, survdb.survcontext.regEax
			mov edx, survdb.survcontext.regEdx
			push ax
			push dx
			mov edx, esp
			mov edi, survdb.survcontext.regEdi

			;heavy bomb loop  to do until it either fails or finishes
			heavybombloop:
			;check if edi exited the arena and if it did bring it back
			mov eax, edi
			cmp eax, arendptr
			jl edinotabove
			cmp eax, ediarendptr
			jge edinotabove
			sub survdb.survcontext.regEdi, 0ffffh
			edinotabove:
			add eax, 4
			cmp eax, arptr
			jg ediok
			add eax, 4
			cmp eax, arptr
			jl ediok
			add survdb.survcontext.regEdi, 0ffffh
			ediok:
			;write dx:ax to memory
			push ecx
			push edx
			invoke WriteProcessMemory, pi.hProcess, edi, edx, 4, NULL	
			pop edx
			pop ecx
			test eax, eax
			jz edioutofbounds
			;if succeeded add to edi according to direction flag and loop
			add edi, ebx
			loop heavybombloop

			mov survdb.survcontext.regEdi, edi

			add survdb.survcontext.regEip, 2

		.elseif ah == 087h
			
		.else
			edioutofbounds:
			mov survdb.isdead, 1
		.endif

		mov esi, offset survdb.survcontext
		mov edi, offset context
		mov ecx, SIZEOF CONTEXT
		rep movsb		
		jmp survswitch
	.else
		
	.endif
endm

switch_survs MACRO lastsurv, nextsurv
	mov esi, offset context
	mov edi, offset lastsurv.survcontext
	mov ecx, SIZEOF CONTEXT
	rep movsb
	inc currentsurv
	handle_ints(nextsurv)
	invoke SetThreadContext,pi.hThread, offset nextsurv.survcontext 
endm