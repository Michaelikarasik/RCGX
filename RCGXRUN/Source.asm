.model flat,stdcall 
option casemap:none 
include \masm32\include\windows.inc 
include \masm32\include\kernel32.inc 
include \masm32\include\comdlg32.inc 
include \masm32\include\user32.inc 
include \masm32\include\advapi32.inc 
includelib \masm32\lib\kernel32.lib 
includelib \masm32\lib\comdlg32.lib 
includelib \masm32\lib\user32.lib 
includelib \masm32\lib\advapi32.lib
include \masm32\include\masm32rt.inc
include data.inc
include macros.inc

.686
.data

arptr dword ?
arendptr dword ?
eipendptr dword ?
eipstartptr dword ?
esparstartptr dword ?
esparendptr dword ?
ediarendptr dword ?

debugarstartptr dword ?

survcontextset dword 0

postarcheckbuf dword 0cccccccch
postarlaststate dword 0cccccccch
prearlaststate dword 0cccccccch

isgame db 0

currentsurv byte ?
currentsurvlp dword my_survs.surv1db

debugstringbuf dword ?

livingsurvnum byte max_survs

AppName db "RCGX",0 
ofn OPENFILENAME <> 
FilterString db "Executable Files",0,"*.exe",0 
             db "All Files",0,"*.*",0,0 
ExitProc db "The debuggee exits",0 
NewThread db "A new thread is created",0 
EndThread db "A thread is destroyed",0 
ProcessInfo db "File Handle: %lx ",0dh,0Ah 
            db "Process Handle: %lx",0Dh,0Ah 
            db "Thread Handle: %lx",0Dh,0Ah 
            db "Image Base: %lx",0Dh,0Ah 
            db "Start offsetess: %lx",0 


.data? 
buffer db 512 dup(?) 
startinfo STARTUPINFO <> 
pi PROCESS_INFORMATION <> 
DBEvent DEBUG_EVENT <> 
ProcessId dd ? 
ThreadId dd ? 
align dword 
context CONTEXT <> 
RCGXSetupStartContext CONTEXT<>

.code

run_debug proc
	mov ofn.lStructSize,SIZEOF ofn 
	mov ofn.lpstrFilter, OFFSET FilterString 
	mov ofn.lpstrFile, OFFSET buffer 
	mov ofn.nMaxFile,512 
	mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY 
	invoke GetOpenFileName, offset ofn 
	.if eax==TRUE 
		invoke GetStartupInfo,offset startinfo 
		invoke CreateProcess, offset buffer, NULL, NULL, NULL, FALSE, DEBUG_PROCESS+ DEBUG_ONLY_THIS_PROCESS, NULL, NULL, offset startinfo, offset pi 

		;only for arena debug
		invoke VirtualAlloc , 0 , 010200h, MEM_COMMIT, PAGE_EXECUTE_READWRITE
		mov debugarstartptr, eax

		PROCESSALREADYOPENED:
		mov isgame, 0

	    mov context.ContextFlags, CONTEXT_ALL
		mov RCGXSetupStartContext.ContextFlags, CONTEXT_CONTROL

		mov ecx, max_survs
		mov eax, offset my_survs.surv1db.survcontext
		SURVCONTEXTSETLOOP:
		mov [eax.debugstruct].survcontext.ContextFlags, CONTEXT_ALL
		add eax, SIZEOF debugstruct
		loop SURVCONTEXTSETLOOP
				   invoke GetThreadContext,pi.hThread, offset context
		.while TRUE
		   invoke WaitForDebugEvent, offset DBEvent, INFINITE
		   invoke GetThreadContext,pi.hThread, offset context
		   .if DBEvent.dwDebugEventCode==1 && isgame != 0
				.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP
					 custominstructionreset:
					 or context.regFlag,0100h
					 mov edi, context.regEdi
					 .if edi >= arendptr && edi < ediarendptr
						sub edi, 0ffffh
						mov context.regEdi, edi
					 .endif

					 mov eax, context.regEip
					 .if eax >= arendptr && eax <= eipendptr
						sub context.regEip, 0ffffh
					 .elseif eax < arptr && eax > eipstartptr
						add context.regEip, 0ffffh
					 .endif

					invoke ReadProcessMemory, pi.hProcess, arendptr, offset postarcheckbuf, 4, NULL
					mov ebx, postarlaststate
					.if postarcheckbuf != ebx
						invoke WriteProcessMemory, pi.hProcess, arptr, offset postarcheckbuf, 4, NULL
						mov ebx, postarcheckbuf
						mov postarlaststate, ebx
					.else
						invoke ReadProcessMemory, pi.hProcess, arptr, offset postarcheckbuf, 4, NULL
						.if postarcheckbuf != ebx
							invoke WriteProcessMemory, pi.hProcess, arendptr, offset postarcheckbuf, 4, NULL
							mov ebx, postarcheckbuf
							mov postarlaststate, ebx
						.endif
					.endif

					mov ebx, prearlaststate

					invoke ReadProcessMemory, pi.hProcess, esparendptr, offset postarcheckbuf, 4, NULL
					.if postarcheckbuf != ebx
						invoke WriteProcessMemory, pi.hProcess, esparstartptr, offset postarcheckbuf, 4, NULL
						mov ebx, postarcheckbuf
						mov prearlaststate, ebx
					.else
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, offset postarcheckbuf, 4, NULL
						.if postarcheckbuf != ebx
							invoke WriteProcessMemory, pi.hProcess, esparendptr, offset postarcheckbuf, 4, NULL
							mov ebx, postarcheckbuf
							mov prearlaststate, ebx
						.endif
					.endif
				
					mov eax, context.regEsp
					.if eax < arptr && eax >= esparstartptr
						add context.regEsp, 0ffffh
					.endif

					survswitch:
					;check if currentsurvlp is above the max surv and reset it accordingly
					mov eax, currentsurvlp
					cmp eax, offset my_survs + (sizeof debugstruct) * max_survs
					jl NOTABOVEMAXSURV
					mov currentsurvlp, offset my_survs

					NOTABOVEMAXSURV:
					switch_survs currentsurvlp

					 invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					 invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
					 .continue 
				
				.elseif isgame == 1
					mov ebx, currentsurvlp
					mov [ebx.debugstruct].isdead, 1
					dec livingsurvnum
					jmp survswitch

				.elseif DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
					nop
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					.continue
				.elseif DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_ACCESS_VIOLATION
					nop
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					.continue

				.elseif DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_ILLEGAL_INSTRUCTION
					nop

				.endif

			.elseif DBEvent.dwDebugEventCode==OUTPUT_DEBUG_STRING_EVENT
				invoke ReadProcessMemory, pi.hProcess, DBEvent.u.DebugString.lpDebugStringData, offset debugstringbuf, 4, NULL

				mov ecx, 4
				mov edi, offset debugstringbuf
				mov esi, offset arenaset
				repe cmpsb
				.if ecx == 0 ;if debug message is arenaset then copy the arena ptr to here
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						invoke GetThreadContext,pi.hThread, offset context
						mov ebx, context.regEbx
						mov startofallocptr, ebx
						mov eax, context.regEax
						mov arptr, eax
						sub eax, 4
						mov esparstartptr, eax
						sub eax, 256 - 8
						mov eipstartptr, eax
						add eax, 0ffffh + 248
						mov esparendptr, eax
						add eax, 4
						mov arendptr, eax
						add eax, 4 
						mov ediarendptr, eax
						add eax, 252
						mov eipendptr, eax
					.endif
					jmp FOUNDMESSAGE
				.endif

				mov cx, 4
				mov edi, offset debugstringbuf
				mov esi, offset newsurvset
				repe cmpsb
 				.if ecx == 0 ;if debug string is survset wait until it's set and put it in context
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						setupcontext(currentsurvlp)
						add currentsurvlp, sizeof debugstruct
					.endif
					inc survcontextset
					jmp FOUNDMESSAGE
				.endif

				mov cx, 4
				mov edi, offset debugstringbuf
				mov esi, offset startgame
				repe cmpsb
				.if ecx == 0 ;if debug string is startgame move process to surv 1 context
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						or my_survs.surv1db.survcontext.regFlag, 0100h
						invoke SetThreadContext,pi.hThread, offset my_survs.surv1db.survcontext
						mov ecx, postarcheckbuf
						push ecx
						mov dword ptr ebx, postarcheckbuf
						push ebx
						mov currentsurvlp, offset my_survs.surv1db
						mov isgame, 1
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
					.endif
					jmp FOUNDMESSAGE
				.endif

				FOUNDMESSAGE:
				invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId, DBG_CONTINUE 
                .continue 
			.elseif DBEvent.dwDebugEventCode==EXIT_PROCESS_DEBUG_EVENT 
				.break
			.elseif DBEvent.dwDebugEventCode==CREATE_PROCESS_DEBUG_EVENT 
				  
			.elseif DBEvent.dwDebugEventCode==CREATE_THREAD_DEBUG_EVENT 
				
			.elseif DBEvent.dwDebugEventCode==EXIT_THREAD_DEBUG_EVENT 
				
			.endif
		   invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId, DBG_EXCEPTION_NOT_HANDLED 

		.endw 
		invoke CloseHandle,pi.hProcess 
		invoke CloseHandle,pi.hThread 
	.endif 
	invoke ExitProcess, 0 

	DOWIN:
;	invoke SetThreadContext,pi.hThread, offset RCGXSetupStartContext
	mov ebx, currentsurvlp
	inc [ebx.debugstruct].wincount
	mov ebx, offset my_survs.surv1db.survcontext
	mov ecx, max_survs
	SEGSFREELOOP:
	mov eax, [ebx.debugstruct].segallocstart
	push ecx
	invoke VirtualFreeEx, pi.hProcess, eax, 0, MEM_RELEASE
	pop ecx
	add ebx, sizeof debugstruct
	loop SEGSFREELOOP

	invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
	jmp PROCESSALREADYOPENED
run_debug endp


main proc
	invoke run_debug
main endp
end main