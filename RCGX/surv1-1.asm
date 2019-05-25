bits 32
mov dx, 0xffff
mov edi, eax
push eax
push eax
mov ax, 0xfbe8
int 0x87
pop edi
add edi, here
mov ebx, 0xffffffff
pop esp
mov eax, 0xab535353
add esp, here
stosd
here: