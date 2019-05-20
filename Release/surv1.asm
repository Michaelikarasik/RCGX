bits 32
mov ebx, 0xffffffff
mov edi, eax
mov esp, eax
mov eax, 0xab535353
add edi, here
add esp, here
stosd
here: