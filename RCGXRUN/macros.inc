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
	invoke ReadProcessMemory, pi.hProcess, survdb.survcontext.regEip, offset intcheckbuf, 4, NULL
	mov ax, intcheckbuf
	.if al == 0ceh || al == 0b9h
		mov survdb.isdead, 1
		inc currentsurv
		jmp survswitch
	.elseif al == 0cdh
		;if direction flag is set, move ecx to 4 else move ecx to -4
		mov ecx, survdb.survcontext.regFlag
		and ecx, 0400h
		mov bl, 4
		ror cl, 1
		sar cl, 4
		or bl, cl
		;check if player used heavy bomb
		.if ah == 086h
			local bombptr:dword
			mov ecx, 64
			push ax
			push dx
			mov bombptr, esp
			mov edi, survdb.survcontext.regEdi
			heavybombloop:
			cmp edi, arendptr
			jl ediisok
			cmp edi, ediarendptr
			jge ediisok
			sub survdb.survcontext.regEdi, 0ffffh
			ediisok:
			invoke WriteProcessMemory, pi.hProcess, edi, bombptr, 4, NULL	
			add edi, bl
				
			.endif
		.elseif ah == 087h
			
		.else
			edioutofbounds:
			mov survdb.isdead, 1
		.endif
		inc currentsurv
		jmp survswitch
	.else
		
	.endif
endm

switch_survs MACRO lastsurv, nextsurv
	invoke GetThreadContext,pi.hThread, offset lastsurv.survcontext
	inc currentsurv
	invoke SetThreadContext,pi.hThread, offset nextsurv.survcontext 
endm