.model flat,stdcall 
option casemap:none 
WinMain proto :DWORD,:DWORD,:DWORD,:DWORD 
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
debugarcheckptr dword ?

survcontextset dword 0

postarcheckbuf dword 0cccccccch
postarlaststate dword 0cccccccch
prearlaststate dword 0cccccccch

isgame db 0

turncount dword 0
gamecount dword 0

currentsurv byte ?
survlpinit dword my_survs.surv1db.survcontext
currentsurvlp dword my_survs.surv1db.survcontext

debugstringbuf dword ?

livingsurvnum byte max_survs

deathchart dword 0

IDB_MAIN equ 1

max_turns equ 50000

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
playerscoretext db "team a score: aaaa", 0
arClassName db "arwinclass",0 
guiClassName db "guiwinclass", 0
arwc WNDCLASSEX <>
guiwc WNDCLASSEX <>

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
arHInstance HINSTANCE ? 
guiHInstance HINSTANCE ?
CommandLine LPSTR ?
msg MSG<> 
hBitmap dd ?
hMemDC HDC ?
hGuiDC HDC ?
arenahwnd HWND ?
guihwnd HWND ? 

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
		invoke VirtualAlloc , 0 , 010007h * 2, MEM_COMMIT, PAGE_EXECUTE_READWRITE
		mov debugarstartptr, eax
		add eax, 010007h
		mov debugarcheckptr, eax

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
		   .if DBEvent.dwDebugEventCode==1
				.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP && isgame != 0
					 or context.regFlag,0100h
					 mov edi, context.regEdi

					 cmp edi, arendptr
					 jl CHECKEDIUNDERARENA
					 cmp edi, ediarendptr
					 jl EDICHANGENEEDED
					 CHECKEDIUNDERARENA:
					 cmp edi, arptr
					 jge EDICHANGENOTNEEDED
					 cmp edi, esparstartptr
					 jl EDICHANGENOTNEEDED
					 EDICHANGENEEDED:
					 mov ebx, currentsurvlp
					 mov eax, [ebx.debugstruct].survcontext.regEdi
					 sub eax, edi
					 mov edi, eax
					 sal edi, 31
					 xor eax, edi
					 sub eax, edi
					 cmp eax, 4
					 jg EDICHANGENOTNEEDED
					 sub context.regEdi,010000h
					 EDICHANGENOTNEEDED:


					 mov eax, context.regEip
					 .if eax >= arendptr && eax <= eipendptr
						sub context.regEip, 010000h
					 .elseif eax < arptr && eax > eipstartptr
						add context.regEip, 010000h
					 .endif

					 check_arena_edges postarlaststate, arptr, arendptr
					 check_arena_edges prearlaststate, esparstartptr, esparendptr
				
					mov eax, context.regEsp
					.if eax < arptr && eax >= esparstartptr
						add context.regEsp, 010000h
					.endif

					finishupturn currentsurvlp

					survswitch:
					mov eax, currentsurvlp
					;check if start of new turn
					cmp eax, survlpinit
					jne NOTSTARTOFNEWTURN 
					inc turncount
					cmp turncount, max_turns
					jae DOWIN

					NOTSTARTOFNEWTURN:
					;check if currentsurvlp is above the max surv and reset it accordingly
					cmp eax, offset my_survs + (sizeof debugstruct) * max_survs
					jl NOTABOVEMAXSURV
					mov currentsurvlp, offset my_survs

					NOTABOVEMAXSURV:
					switch_survs currentsurvlp

					 invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					 .continue 
				
				.elseif isgame == 1
					mov ebx, currentsurvlp
					kill_surv ebx
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
				mov esi, offset setupstartstate
				repe cmpsb
				.if ecx == 0
					invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
					invoke WaitForDebugEvent, offset DBEvent, INFINITE 
					.if DBEvent.u.Exception.pExceptionRecord.ExceptionCode==EXCEPTION_BREAKPOINT
						invoke GetThreadContext,pi.hThread, offset RCGXSetupStartContext
					.endif
				.endif

				arenasetupstringcheck:
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
						mov eax, max_survs
						mov livingsurvnum, al
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarstartptr, 010007h, NULL
						invoke ReadProcessMemory, pi.hProcess, esparstartptr, debugarcheckptr, 010007h, NULL
					.endif
					jmp FOUNDMESSAGE
				.endif

				FOUNDMESSAGE:
				invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId, DBG_CONTINUE 
                .continue 
			.elseif DBEvent.dwDebugEventCode==EXIT_PROCESS_DEBUG_EVENT 
				.break
			.endif

		   invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId, DBG_EXCEPTION_NOT_HANDLED 
		.endw 
		invoke CloseHandle,pi.hProcess 
		invoke CloseHandle,pi.hThread 
	.endif 
	invoke ExitProcess, 0 

	DOWIN:
 	invoke SetThreadContext,pi.hThread, offset RCGXSetupStartContext
	endOfRoundPoints ;add points to each player

	inc gamecount
	mov ebx, offset survlpinit
	mov ecx, max_survs

	SEGSFREELOOP:
	mov eax, [ebx.debugstruct].segallocstart
	push ecx
	invoke VirtualFreeEx, pi.hProcess, eax, 0, MEM_RELEASE
	pop ecx
	add ebx, sizeof debugstruct
	loop SEGSFREELOOP

	mov eax, survlpinit
	mov currentsurvlp, eax
	mov isgame, 0
	mov turncount, 0

	.if (isdrawing)
		invoke LoadBitmap,arHInstance,IDB_MAIN 
		invoke SelectObject,hMemDC,eax
	.endif

	invoke ContinueDebugEvent, DBEvent.dwProcessId, DBEvent.dwThreadId,DBG_CONTINUE 
	jmp PROCESSALREADYOPENED
run_debug endp

start: 
 invoke GetModuleHandle, NULL 
 mov    arHInstance,eax 
 invoke GetCommandLine 
 mov    CommandLine,eax
 invoke WinMain, arHInstance,NULL,CommandLine, SW_SHOWDEFAULT
 invoke ExitProcess,eax

WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD 
 mov   arwc.cbSize,SIZEOF WNDCLASSEX 
 mov   arwc.style, CS_HREDRAW or CS_VREDRAW 
 mov   arwc.lpfnWndProc, OFFSET arWndProc 
 mov   arwc.cbClsExtra,NULL 
 mov   arwc.cbWndExtra,NULL 
 push  arHInstance 
 pop   arwc.hInstance 
 mov   arwc.hbrBackground,COLOR_WINDOW
 mov   arwc.lpszMenuName,NULL 
 mov   arwc.lpszClassName,OFFSET arClassName 
 invoke LoadIcon,NULL,IDI_APPLICATION 
 mov   arwc.hIcon,eax 
 mov   arwc.hIconSm,eax 
 invoke LoadCursor,NULL,IDC_ARROW 
 mov   arwc.hCursor,eax 

 cmp isdrawing, 0
 jz notopeningarenawindow
	openarwindow
 notopeningarenawindow:

 mov   guiwc.cbSize,SIZEOF WNDCLASSEX 
 mov   guiwc.style, CS_HREDRAW or CS_VREDRAW 
 mov   guiwc.lpfnWndProc, OFFSET guiWndProc
 mov   guiwc.cbClsExtra,NULL 
 mov   guiwc.cbWndExtra,NULL 
 push  guiHInstance 
 pop  guiwc.hInstance 
 mov  guiwc.hbrBackground,COLOR_WINDOW
 mov  guiwc.lpszMenuName,NULL 
 mov  guiwc.lpszClassName,OFFSET guiClassName 
 invoke LoadIcon,NULL,IDI_APPLICATION 
 mov   guiwc.hIcon,eax 
 mov   guiwc.hIconSm,eax 
 invoke LoadCursor,NULL,IDC_ARROW 
 mov   guiwc.hCursor,eax 

invoke RegisterClassEx, addr guiwc
INVOKE CreateWindowEx,NULL,ADDR guiClassName,ADDR AppName,\ 
		   WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,\ 
		   CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,NULL,NULL,\ 
		   guiHInstance,NULL
mov   guihwnd,eax 
invoke ShowWindow, guihwnd,SW_SHOWNORMAL
invoke UpdateWindow, guihwnd

 invoke run_debug
 ret 
WinMain endp

arWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
   LOCAL ps:PAINTSTRUCT 
   LOCAL hdc:HDC 
   LOCAL rect:RECT 
   .if uMsg==WM_CREATE 
      invoke LoadBitmap,arHInstance,IDB_MAIN 
      mov hBitmap,eax 
      invoke BeginPaint,hWnd,addr ps 
	  invoke CreateCompatibleDC,eax
	  mov hMemDC, eax
	  invoke SelectObject,hMemDC,hBitmap 
   .elseif uMsg==WM_PAINT 
      invoke BeginPaint,hWnd,addr ps 
      mov    hdc,eax 
      invoke BitBlt,hdc,0,0,rect.right,rect.bottom,hMemDC,0,0,SRCCOPY 
      invoke EndPaint,hWnd,addr ps 
 .elseif uMsg==WM_DESTROY 
  invoke DeleteObject,hBitmap 
  invoke PostQuitMessage,NULL 
 .ELSE 
  invoke DefWindowProc,hWnd,uMsg,wParam,lParam 
  ret 
 .ENDIF 
 xor eax,eax 
 ret 
arWndProc endp 

guiWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
   LOCAL ps:PAINTSTRUCT 
   LOCAL hdc:HDC 
   LOCAL rect:RECT 
   LOCAL textrect:RECT 
   LOCAL myhbitmap:HBITMAP
   .if uMsg==WM_CREATE 
	  invoke BeginPaint,hWnd,addr ps 
      mov    hdc,eax
	  invoke GetClientRect,hWnd, ADDR textrect
	  invoke CreateCompatibleDC,hdc
	  mov hGuiDC, eax
	  invoke CreateCompatibleBitmap, hdc,textrect.right, textrect.bottom
	  invoke SelectObject,hGuiDC,eax
	  sub textrect.bottom, 50
	  mov eax, textrect.right
	  xor edx, edx
	  mov bx, 4
	  div bx
	  add textrect.left, eax
	  mov eax, textrect.right
	  xor edx, edx
	  mov bx, max_survs - 2
	  div bx
	  mov esi, eax
	  push 00030h ; 0x3000 = "0\0"
	  mov edi, esp	
	  push 06d616574h ;"team"
	  mov ebx, esp

	  drawtextloop:
	  inc byte ptr [edi]
      invoke DrawText, hGuiDC,ebx,-1, ADDR textrect, DT_SINGLELINE or DT_LEFT or DT_BOTTOM
	  add textrect.left, esi
	  cmp byte ptr [edi], 030h + (max_survs / 2)
	  jne drawtextloop

	  invoke BitBlt,hdc,0,0,rect.right,rect.bottom,hGuiDC,0,0,SRCCOPY 
   .elseif uMsg==WM_PAINT 
	  invoke BeginPaint,hWnd,addr ps 
      mov    hdc,eax 
	  invoke GetClientRect,hWnd, ADDR rect
      invoke BitBlt,hdc,0,0,rect.right,rect.bottom,hGuiDC,0,0,SRCCOPY 
      invoke EndPaint,hWnd,addr ps 
 .elseif uMsg==WM_DESTROY 
  invoke DeleteObject,hBitmap 
  invoke PostQuitMessage,NULL 
 .ELSE 
  invoke DefWindowProc,hWnd,uMsg,wParam,lParam 
  ret 
 .ENDIF 
 xor eax,eax 
 ret 
guiWndProc endp 
end start