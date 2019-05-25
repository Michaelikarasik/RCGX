bits 32
;jmp startofcode

;mov esp, eax
;here2:
;call here

startofcode:
mov esp, eax
here:
call here

;mov esp, eax
;here3:
;call here