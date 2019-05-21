bits 32
mov dx, 0xab53
mov ax, 0x5353
mov edi, eax
add edi, here2
int 0x86
here2:
mov ebx, 0xffffffff
mov edi, eax
mov esp, eax
mov eax, 0xab535353
add edi, here
add esp, here
stosd
here: