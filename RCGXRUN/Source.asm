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

isgame db 0

debugstringbuf dword ?

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
	    mov context.ContextFlags, CONTEXT_ALL
		mov surv1db.survcontext.ContextFlags, CONTEXT_ALL
		mov surv2db.survcontext.ContextFlags, CONTEXT_ALL
		mov surv3db.survcontext.ContextFlags, CONTEXT_ALL
		mov surv4db.survcontext.ContextFlags, CONTEXT_ALL

		;only for arena debug
		invoke VirtualAlloc , 0 , 010200h, MEM_COMMIT, PAGE_EXECUTE_READWRITE
		mov debugarstartptr, eax

		.while TRUE
		   invoke WaitForDebugEvent, offset DBEvent, INFINITE
		   invoke GetThreadContext,pi.hThread, offset context
		   .if DBEvent.dwDebugEventCode==1
				.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP
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
					pop ebx
					.if postarcheckbuf != ebx
						invoke WriteProcessMemory, pi.hProcess, arptr, offset postarcheckbuf, 4, NULL
						mov ebx, postarcheckbuf
					.else
						invoke ReadProcessMemory, pi.hProcess, arptr, offset postarcheckbuf, 4, NULL
						.if postarcheckbuf != ebx
							invoke WriteProcessMemory, pi.hProcess, arendptr, offset postarcheckbuf, 4, NULL
							mov ebx, postarcheckbuf
						.endif
					.endif
					pop eax
					push ebx
					push eax

					invoke ReadProcessMemory, pi.hProcess, esparendptr, offset postarcheckbuf, 4, NULL
					pop ebx
					.if postarcheckbuf != ebx
						invoke WriteProcessMemory, pi.hProcess, esparstartptr, offset postarcheckbuf, 4, NULL
						mov ebx, postarcheckbuf
					.else
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, offset postarcheckbuf, 4, NULL
						.if postarcheckbuf != ebx
							invoke WriteProcessMemory, pi.hProcess, esparendptr, offset postarcheckbuf, 4, NULL
							mov ebx, postarcheckbuf
						.endif
					.endif
					pop eax
					push ebx
					push eax
				
					mov eax, context.regEsp
					.if eax < arptr && eax >= esparstartptr
						add context.regEsp, 0ffffh
					.endif

					survswitch:
					.if currentsurv == 0
						switch_survs surv1db, surv2db
					.elseif currentsurv == 1
						switch_survs surv2db, surv1db;surv3db
					.elseif currentsurv == 2
						switch_survs surv3db, surv4db
					.elseif currentsurv == 3
						switch_survs surv4db, surv1db
					.endif
					mov al, 2
					.if currentsurv >= al
						mov currentsurv, 0
					.endif

					 invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					 invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
					 .continue 

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
				xor ecx, ecx
				mov cx, 4
				mov edi, offset debugstringbuf
				mov esi, offset arenaset
				repe cmpsb
				.if ecx == 0 ;if debug message is arenaset then copy the arena ptr to here
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						invoke GetThreadContext,pi.hThread, offset context
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
				.endif

				mov cx, 4
				mov edi, offset debugstringbuf
				mov esi, offset newsurvset
				repe cmpsb
				.if ecx == 0 ;if debug string is survset wait until it's set and put it in context
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						.if currentsurv == 0
							setupcontext(surv1db)
							inc currentsurv
						.elseif currentsurv == 1
							setupcontext(surv2db)								
							inc currentsurv
							invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
						.elseif currentsurv == 2
							setupcontext(surv3db)
							inc currentsurv
						.elseif currentsurv == 3
							setupcontext(surv4db)
							inc currentsurv	
						.endif

						mov al, max_survs
						.if currentsurv >= al
							mov currentsurv, 0
						.endif

					.endif
					inc survcontextset
				.endif

				mov cx, 4
				mov edi, offset debugstringbuf
				mov esi, offset startgame
				repe cmpsb
				.if ecx == 0 ;if debug string is startgame move process to surv 1 context
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						or surv1db.survcontext.regFlag, 0100h
						invoke SetThreadContext,pi.hThread, offset surv1db.survcontext
						mov ecx, postarcheckbuf
						push ecx
						mov dword ptr ebx, postarcheckbuf
						push ebx
						mov currentsurv, 0
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
					.endif
				.endif
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
run_debug endp


main proc
	invoke run_debug
main endp
end main