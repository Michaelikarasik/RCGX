kill_surv macro survdblp
	local deathcheckloop
	mov ebx, survdblp
	mov [ebx.debugstruct].isdead, 1
	dec livingsurvnum
	mov eax, [ebx.debugstruct].afptr
	xor deathchart, eax
	mov [ebx.debugstruct].afptr, 0

	mov ecx, max_survs
	mov ebx, survlpinit

	deathcheckloop:
	mov eax, [ebx.debugstruct].afptr
	or deathchart, eax
	add ebx, sizeof debugstruct
	loop deathcheckloop
endm

UpdateMemoryChanges macro survdblp
	local bigcmploop, smallcmploop, notdrawing, nomessage, endofbigloop, endofsmallloop, firstrow, dosetpixel

	mov ebx, survdblp
	cmp isdrawing, 0
	jz notdrawing

	mov ebx, [ebx.debugstruct].color

	invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
	mov edi, debugarcheckptr
	mov esi, debugarstartptr
	mov ecx, 04000h
	bigcmploop:
	repe cmpsd
	je endofbigloop
	sub esi, 4
	sub edi, 4
	push ecx

	mov ecx, 4
	smallcmploop:
	repe cmpsb
	je endofsmallloop
	dec esi
	dec edi

	pushad
	mov eax, esi
	sub eax, debugarstartptr
	xor edx, edx
	cmp eax, 0100h
	jl firstrow
	mov ecx, 0100h
	div ecx
	jmp dosetpixel

	firstrow:
	xchg eax, edx
	dosetpixel:
	invoke SetPixel, hMemDC, edx, eax, ebx
	popad
	movsb
	test ecx, ecx
	jnz smallcmploop

	endofsmallloop:
	invoke InvalidateRect, arenahwnd, NULL, 0
	invoke UpdateWindow, arenahwnd
	pop ecx
	test ecx, ecx
	jnz bigcmploop

	endofbigloop:
	getWindowMessage

	notdrawing:
endm

finishupturn macro survdblp
	UpdateMemoryChanges survdblp
	jmp survswitch
endm

setupcontext macro survdblp
		local shiftloop, endofshiftloop
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

		;get survivor's affiliation num
		mov eax, [ebx.debugstruct].survcontext.regEbx
		mov [ebx.debugstruct].affiliation, eax
		mov [ebx.debugstruct].survcontext.regEbx, 0

		mov eax, [ebx.debugstruct].survcontext.regEdx
		mov [ebx.debugstruct].color, eax
		mov [ebx.debugstruct].survcontext.regEdx, 0

		mov eax, 1
		mov ecx, [ebx.debugstruct].affiliation
		test ecx, ecx
		jz endofshiftloop
		shiftloop:
		sal eax, 1
		loop shiftloop
		endofshiftloop:
		or deathchart, eax
		mov [ebx.debugstruct].afptr, eax

		mov [ebx.debugstruct].heavybombs, 2
		mov [ebx.debugstruct].smartbombs, 1
		mov [ebx.debugstruct].isdead, 0

		or [ebx.debugstruct].survcontext.regFlag, 100h	

endm

protectSurvSegs macro lastsurvdblp, nextsurvdblp
	local PROTECTLOOP, NOTMYSURV, DOTHEPROTECT
	push nextsurvdblp
	push lastsurvdblp
	pop ebx
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].stackstart, 0fffh, PAGE_NOACCESS, trashpointer
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].exstart, 0fffh, PAGE_NOACCESS, trashpointer

	pop ebx
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].stackstart, 0fffh, PAGE_READWRITE, trashpointer
	invoke VirtualProtectEx, pi.hProcess, [ebx.debugstruct].exstart, 0fffh, PAGE_READWRITE, trashpointer
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
	.if al == 0ceh || al == 060h
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
			kill_surv ebx
		.endif

		BOMBINGDONE:	
		add [ebx.debugstruct].survcontext.regEip, 2
		mov esi, ebx
		mov edi, offset context
		mov ecx, SIZEOF CONTEXT
		rep movsb	
		finishupturn ebx
	.else
		
	.endif
endm

switch_survs macro lastsurvlp
	local notdead, NOTABOVEMAXSURV, CHANGETONEXTSURV
	mov ebx, lastsurvlp
	cmp [ebx.debugstruct].isdead, 0
	jne CHANGETONEXTSURV
	mov esi, offset context
	mov edi, ebx
	add edi, debugstruct.survcontext
	mov ecx, sizeof CONTEXT
	rep movsb

	CHANGETONEXTSURV:
	add ebx, sizeof debugstruct
	cmp ebx, offset my_survs + (sizeof debugstruct) * max_survs
	jl NOTABOVEMAXSURV
	mov ebx, offset my_survs
	NOTABOVEMAXSURV:
	push ebx
	protectSurvSegs currentsurvlp, ebx
	pop ebx
	mov currentsurvlp, ebx

	cmp [ebx.debugstruct].isdead, 0
	jne survswitch

	mov eax, [ebx.debugstruct].afptr
	cmp deathchart, eax
	je DOWIN

	handle_ints_new(currentsurvlp)

	mov ebx, currentsurvlp
	invoke SetThreadContext,pi.hThread, addr [ebx.debugstruct].survcontext 
endm

endOfRoundPoints macro
	local WINPOINTCHECKLOOP, SURVISDEAD1, SURVISDEAD2
	xor ebx, ebx ;ebx will be the counter for alive players
	mov eax, 100 ;will divide ax by bx to get points for each player
	mov ecx, max_survs
	mov edx, survlpinit
	
	WINPOINTCHECKLOOP:
	dec ecx
	cmp [edx.debugstruct].isdead, 0
	jnz SURVISDEAD1
	inc ebx
	SURVISDEAD1:
	add edx, sizeof debugstruct
	test ecx, ecx
	jnz WINPOINTCHECKLOOP

	xor edx, edx
	test bl, bl
	jz SURVISDEAD2
	div bl

	mov ecx, max_survs
	mov edx, survlpinit
	WINPOINTGIVELOOP:
	dec ecx
	cmp [edx.debugstruct].isdead, 0
	jnz SURVISDEAD2
	add [edx.debugstruct].wincount, eax
	SURVISDEAD2:
	add edx, sizeof debugstruct
	test ecx, ecx
	jnz WINPOINTGIVELOOP
endm

check_arena_edges macro lastState, lowerEdge, higherEdge
	invoke ReadProcessMemory, pi.hProcess, higherEdge, offset postarcheckbuf, 4, NULL
	mov ebx, lastState
	.if postarcheckbuf != ebx
		invoke WriteProcessMemory, pi.hProcess, lowerEdge, offset postarcheckbuf, 4, NULL
		mov ebx, postarcheckbuf
		mov lastState, ebx
	.else
		invoke ReadProcessMemory, pi.hProcess, lowerEdge, offset postarcheckbuf, 4, NULL
		.if postarcheckbuf != ebx
			invoke WriteProcessMemory, pi.hProcess, higherEdge, offset postarcheckbuf, 4, NULL
			mov ebx, postarcheckbuf
			mov lastState, ebx
		.endif
	.endif
endm

getWindowMessage macro
	local nomessage
	invoke PeekMessage, ADDR msg, NULL, 0,0,0 
	test eax, eax
	jz nomessage
    invoke GetMessage, ADDR msg,NULL,0,0 
    test eax, eax
	jz nomessage
    invoke TranslateMessage, ADDR msg 
    invoke DispatchMessage, ADDR msg 
	nomessage:
endm

openwindow macro windowclass
	local finishup, next1
	 mov ebx, offset windowclass
	 invoke RegisterClassEx, addr windowclass
	 cmp ebx, offset arwc
	 jne next1
	 INVOKE CreateWindowEx,NULL,ADDR ClassName,ADDR AppName,\ 
			   WS_OVERLAPPEDWINDOW xor WS_THICKFRAME xor WS_MAXIMIZEBOX,CW_USEDEFAULT,\ 
			   CW_USEDEFAULT,0110h,0127h,NULL,NULL,\ 
			   hInst,NULL
	 mov   arenahwnd,eax 
	 jmp finishup
	 next1:
	 finishup:
	 invoke ShowWindow, arenahwnd,SW_SHOWNORMAL 
	 invoke UpdateWindow, arenahwnd 
endm

loadDrd macro 
	invoke drd_init,1200,700,0
	invoke drd_imageLoadFile,offset res.bgpath,offset res.bg
	invoke drd_imageLoadFile,offset res.pathNoaStand0,offset res.noaStand0
	invoke drd_imageSetTransparent,offset res.noaStand0,0ffffffh
	invoke drd_imageLoadFile,offset res.pathNoaStand1,offset res.noaStand1
	invoke drd_imageSetTransparent,offset res.noaStand1,0ffffffh
	
	invoke drd_imageLoadFile,offset hd.tobi.stand,offset ram.tobi.stand
	invoke drd_imageSetTransparent,offset  ram.tobi.stand,0008000h
endm