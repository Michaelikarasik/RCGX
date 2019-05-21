bits 32
mov dx, 0xab53
mov edi, eax
mov ax, 0x5353
std
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