bits 32
mov ebx, 0xffffffff
mov esp, eax
add eax, here
xchg eax, edi
mov eax, 0xab535353
stosd
here: