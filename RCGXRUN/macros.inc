setupcontext macro survdblp

		mov ebx, survdblp

		;get the process context after surv setup
		invoke GetThreadContext,pi.hThread, addr [ebx.debugstruct].survcontext

		;get surv starting location
		mov eax, [ebx.debugstruct].survcontext.regEax
		mov [ebx.debugstruct].survcontext.regEip, eax

		;get surv stack start
		mov eax, [ebx.debugstruct].survcontext.regEsp
		mov [ebx.debugstruct].survcontext.regEbp, eax
		mov [ebx.debugstruct].stackend, eax
		sub eax, 01000h
		mov [ebx.debugstruct].stackstart, eax

		;get surv extra seg start
		mov eax, [ebx.debugstruct].survcontext.regEdi
		mov [ebx.debugstruct].exstart, eax
		add eax, 01000h
		mov [ebx.debugstruct].exend, eax
		sub eax, 02000h
		mov [ebx.debugstruct].segallocstart, eax

		mov [ebx.debugstruct].heavybombs, 2
		mov [ebx.debugstruct]. smartbombs, 1

		or [ebx.debugstruct].survcontext.regFlag, 100h	

endm

protectSurvSegs macro survdblp
	local PROTECTLOOP, NOTMYSURV, DOTHEPROTECT
	mov edx, survdblp

	mov ecx, max_survs
	mov ebx, offset my_survs.surv1db
	PROTECTLOOP:
	cmp ebx, edx
	jne NOTMYSURV

	;make current surv's segs' protect rights PAGE_READWRITE
	mov eax, 04h
	jmp DOTHEPROTECT

	NOTMYSURV: 
	;make survs that aren't the current surv's segs' protect rights PAGE_NOACESS
	mov eax, 01h

	DOTHEPROTECT:
	push ecx
	push edx
	push eax
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].stackstart, 0fffh, eax, trashpointer
	mov eax, [esp]
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].exstart, 0fffh, eax, trashpointer
	pop eax
	pop edx
	pop ecx
	add eax, SIZEOF debugstruct
	loop PROTECTLOOP
endm

heavyBombEdiArSectioning macro survdb
			local EDINOTABOVE, EDIOK
			mov eax, edi
			cmp eax, arendptr
			jl EDINOTABOVE
			cmp eax, ediarendptr
			jge EDINOTABOVE
			sub edi, 0ffffh
			EDINOTABOVE:
			add eax, 4
			cmp eax, arptr
			jg EDIOK
			add eax, 4
			cmp eax, arptr
			jl EDIOK
			add edi, 0ffffh
			EDIOK:
endm 

smartBombEdiSectioning macro survdblp
			local CHECKUNDERAR, CHECKABOVEEX, CHECKUNDEREX, CHECKABOVESTACK, CHECKUNDERSTACK, STOPSEARCHING, EDIOK
			mov ebx, survdblp
			mov eax, edi
			cmp eax, arendptr
			jl CHECKUNDERAR
			cmp eax, ediarendptr
			jge CHECKUNDERAR
			sub edi, 0ffffh
			jmp EDIOK

			CHECKUNDERAR:
			add eax, 4
			cmp eax, arptr
			jg CHECKABOVEEX
			add eax, 4
			cmp eax, arptr
			jl CHECKABOVEEX
			add edi, 0ffffh
			jmp EDIOK

			CHECKABOVEEX:
			mov eax, edi
			add eax, 4
			cmp eax, [ebx.debugstruct].exend
			jg CHECKUNDEREX
			add eax, 4
			cmp eax, [ebx.debugstruct].exend
			jl CHECKUNDEREX
			jmp STOPSEARCHING

			CHECKUNDEREX:
			mov eax, edi
			cmp eax, [ebx.debugstruct].exstart
			jge CHECKABOVESTACK
			add eax, 4
			cmp eax, [ebx.debugstruct].exstart
			jl CHECKABOVESTACK
			jmp STOPSEARCHING

			CHECKABOVESTACK:
			mov eax, edi
			add eax, 4
			cmp eax, [ebx.debugstruct].stackend
			jg CHECKUNDERSTACK
			add eax, 4
			cmp eax, [ebx.debugstruct].stackend
			jl CHECKUNDERSTACK
			jmp STOPSEARCHING

			CHECKUNDERSTACK:
			mov eax, edi
			cmp eax, [ebx.debugstruct].stackstart
			jge EDIOK
			add eax, 4
			cmp eax, [ebx.debugstruct].stackstart
			jl EDIOK
			jmp STOPSEARCHING

			STOPSEARCHING:
			xor ecx, ecx
			;jmp KEEPSEARCHING

			EDIOK:
endm 

handle_ints_new macro survdblp
	local HEAVYBOMBLOOP, ILLEGALINSTRUCTION, BOMBINGDONE, SMARTBOMBLOOP, KEEPSEARCHING, BOMBCHECKSTART, one, two
	mov ebx, survdblp
	invoke ReadProcessMemory, pi.hProcess, [ebx.debugstruct].survcontext.regEip, offset intcheckbuf, 2, NULL
	mov ax, intcheckbuf
	.if al == 0ceh || al == 0b9h || al == 060h
		jmp ILLEGALINSTRUCTION
	.elseif al == 0cdh
		mov edi, [ebx.debugstruct].survcontext.regEdi
		xor edx, edx

		;if edi is outside all permitted zones, kill player
		cmp edi, arptr
		jl one
		cmp edi, arendptr
		jb BOMBCHECKSTART
		one:
		cmp edi, [ebx.debugstruct].exstart
		jl two
		cmp edi, [ebx.debugstruct].exend
		jb BOMBCHECKSTART
		two:
		cmp edi, [ebx.debugstruct].stackstart
		jl ILLEGALINSTRUCTION
		cmp edi, [ebx.debugstruct].stackend
		jae ILLEGALINSTRUCTION

		BOMBCHECKSTART:
		;check if player used heavy bomb
		.if ah == 086h
			;if direction flag is set, move ebx to 4, else move to -4
			mov edx, [ebx.debugstruct].survcontext.regFlag
			and edx, 0400h
			neg edx
			sar edx, 7
			add edx, 4

			;make sure player has heavy bomb uses left
			cmp [ebx.debugstruct].heavybombs, 0
			je BOMBINGDONE
			;;setup heavy bombing value
			mov eax, [ebx.debugstruct].survcontext.regEax
			push ax
			mov eax, [ebx.debugstruct].survcontext.regEdx
			push ax
			mov eax, esp
			mov edi, [ebx.debugstruct].survcontext.regEdi
			mov ecx, 64 + 1 ;increment ecx to counter the decrement in the start of the loop

			;heavy bomb loop  to do until it either fails or finishes
			HEAVYBOMBLOOP:
			dec ecx
			;check if edi exited the arena and if it did bring it back
			push eax
			heavyBombEdiArSectioning(ebx)
			pop eax
			;write dx:ax to memory
			push eax
			push edx
			push ecx
			invoke WriteProcessMemory, pi.hProcess, edi, eax, 4, NULL	
			pop ecx
			pop edx
			test eax, eax
			jz ILLEGALINSTRUCTION
			pop eax
			;if succeeded add to edi according to direction flag and loop
			add edi, edx
			test ecx, ecx
			jnz HEAVYBOMBLOOP

			mov [ebx.debugstruct].survcontext.regEdi, edi
			dec [ebx.debugstruct].heavybombs

		.elseif ah == 087h
			;if direction flag is set, move ebx to 1, else move to -1
			mov edx, [ebx.debugstruct].survcontext.regFlag
			and edx, 0400h
			neg edx
			sar edx, 7
			inc edx

			cmp [ebx.debugstruct].smartbombs, 0
			je BOMBINGDONE

			dec [ebx.debugstruct].smartbombs

			mov eax, [ebx.debugstruct].survcontext.regEdx
			shl eax, 16
			mov ecx, [ebx.debugstruct].survcontext.regEax
			mov ax, cx

			mov ecx, 0ffffh + 1 ;increment ecx to counter the decrementing at the start of the loop
			mov edi, [ebx.debugstruct].survcontext.regEdi

			SMARTBOMBLOOP:
			dec ecx
			push eax
			smartBombEdiSectioning(ebx)
			pop eax

			push eax
			push edx
			push ecx
			invoke ReadProcessMemory, pi.hProcess, edi, offset debugstringbuf, 4, NULL
			pop ecx
			pop edx
			pop eax
			cmp eax, debugstringbuf
			jne KEEPSEARCHING
			mov eax, [ebx.debugstruct].survcontext.regEcx
			shl eax, 16
			mov ecx, [ebx.debugstruct].survcontext.regEbx
			mov ax, cx
			push eax
			mov eax, esp
			invoke WriteProcessMemory, pi.hProcess, edi, eax, 4, NULL
			xor ecx, ecx

			KEEPSEARCHING:
			add edi, edx
			test ecx, ecx
			jnz SMARTBOMBLOOP

			jmp BOMBINGDONE
			
		.else
			ILLEGALINSTRUCTION:
			mov [ebx.debugstruct].isdead, 1
		.endif

		BOMBINGDONE:	
		add [ebx.debugstruct].survcontext.regEip, 2
		mov esi, ebx
		mov edi, offset context
		mov ecx, SIZEOF CONTEXT
		rep movsb	
		jmp survswitch
	.else
		
	.endif
endm

;handle_ints macro survdb
;	local HEAVYBOMBLOOP, ILLEGALINSTRUCTION, BOMBINGDONE, SMARTBOMBLOOP, KEEPSEARCHING, BOMBCHECKSTART, one, two
;	invoke ReadProcessMemory, pi.hProcess, survdb.survcontext.regEip, offset intcheckbuf, 2, NULL
;	mov ax, intcheckbuf
;	.if al == 0ceh || al == 0b9h || al == 060h
;		jmp ILLEGALINSTRUCTION
;	.elseif al == 0cdh
;		mov edi, survdb.survcontext.regEdi
;		xor edx, edx
;
;		;if edi is outside all permitted zones, kill player
;		cmp edi, arptr
;		jl one
;		cmp edi, arendptr
;		jb BOMBCHECKSTART
;		one:
;		cmp edi, survdb.exstart
;		jl two
;		cmp edi, survdb.exend
;		jb BOMBCHECKSTART
;		two:
;		cmp edi, survdb.stackstart
;		jl ILLEGALINSTRUCTION
;		cmp edi, survdb.stackend
;		jae ILLEGALINSTRUCTION
;
;		BOMBCHECKSTART:
;		;check if player used heavy bomb
;		.if ah == 086h
;			;if direction flag is set, move ebx to 4, else move to -4
;			mov ebx, survdb.survcontext.regFlag
;			and ebx, 0400h
;			neg ebx
;			sar ebx, 7
;			add ebx, 4
;
;			cmp survdb.heavybombs, 0
;			je BOMBINGDONE
;			;;setup heavy bomb
;			mov ecx, 64 + 1 ;increment ecx to counter the decrement in the start of the loop
;			mov eax, survdb.survcontext.regEax
;			mov edx, survdb.survcontext.regEdx
;			push ax
;			push dx
;			mov edx, esp
;			mov edi, survdb.survcontext.regEdi
;
;			;heavy bomb loop  to do until it either fails or finishes
;			HEAVYBOMBLOOP:
;			dec ecx
;			;check if edi exited the arena and if it did bring it back
;			heavyBombEdiArSectioning(survdb)
;			;write dx:ax to memory
;			push ecx
;			push edx
;			invoke WriteProcessMemory, pi.hProcess, edi, edx, 4, NULL	
;			pop edx
;			pop ecx
;			test eax, eax
;			jz ILLEGALINSTRUCTION
;			;if succeeded add to edi according to direction flag and loop
;			add edi, ebx
;			test ecx, ecx
;			jnz HEAVYBOMBLOOP
;
;			mov survdb.survcontext.regEdi, edi
;			dec survdb.heavybombs
;
;		.elseif ah == 087h
;			;if direction flag is set, move ebx to 1, else move to -1
;			mov ebx, survdb.survcontext.regFlag
;			and ebx, 0400h
;			neg ebx
;			sar ebx, 7
;			inc ebx
;
;			mov ecx, 04000h
;			cmp survdb.smartbombs, 0
;			je BOMBINGDONE
;
;			dec survdb.smartbombs
;
;			mov edx, survdb.survcontext.regEdx
;			shl edx, 16
;			mov eax, survdb.survcontext.regEax
;			mov dx, ax
;
;			mov edi, survdb.survcontext.regEdi
;
;			inc ecx ;inc ecx because decrementing ecx happens before the non loop jump acting as a loop so you it will loop one time less than the original value of ecx unless you increment it once
;			SMARTBOMBLOOP:
;			dec ecx
;			smartBombEdiSectioning(survdb)
;			
;			push edx
;			push ecx
;			invoke ReadProcessMemory, pi.hProcess, edi, offset debugstringbuf, 4, NULL
;			pop ecx
;			pop edx
;			cmp edx, debugstringbuf
;			jne KEEPSEARCHING
;			mov edx, survdb.survcontext.regEcx
;			shl edx, 16
;			mov eax, survdb.survcontext.regEbx
;			mov dx, ax
;			push edx
;			mov edx, esp
;			invoke WriteProcessMemory, pi.hProcess, edi, edx, 4, NULL
;			xor ecx, ecx
;
;			KEEPSEARCHING:
;			add edi, ebx
;			test ecx, ecx
;			jnz SMARTBOMBLOOP
;
;			jmp BOMBINGDONE
;			
;		.else
;			ILLEGALINSTRUCTION:
;			mov survdb.isdead, 1
;		.endif
;
;		BOMBINGDONE:
;		add survdb.survcontext.regEip, 2
;		mov esi, offset survdb.survcontext
;		mov edi, offset context
;		mov ecx, SIZEOF CONTEXT
;		rep movsb		
;		jmp survswitch
;	.else
;		
;	.endif
;endm

switch_survs macro lastsurvlp
	local notdead, NOTABOVEMAXSURV
	mov ebx, lastsurvlp
	mov esi, offset context
	mov edi, ebx
	add edi, debugstruct.survcontext
	mov ecx, sizeof CONTEXT
	rep movsb

	add ebx, sizeof debugstruct
	cmp ebx, offset my_survs + (sizeof debugstruct) * max_survs
	jl NOTABOVEMAXSURV
	mov ebx, offset my_survs
	NOTABOVEMAXSURV:
	mov currentsurvlp, ebx

	cmp [ebx.debugstruct].isdead, 0
	jne survswitch

	cmp livingsurvnum, 1
	je DOWIN

	protectSurvSegs(currentsurvlp)
	handle_ints_new(currentsurvlp)

	mov ebx, currentsurvlp
	invoke SetThreadContext,pi.hThread, addr [ebx.debugstruct].survcontext 
endm

;switch_survs MACRO lastsurv, nextsurv
;	mov esi, offset context
;	mov edi, offset lastsurv.survcontext
;	mov ecx, SIZEOF CONTEXT
;	rep movsb
;	inc currentsurv
;	cmp nextsurv.isdead, 0
;	jne survswitch
;
;	handle_ints_new(offset nextsurv)
;	invoke SetThreadContext,pi.hThread, offset nextsurv.survcontext 
;endm