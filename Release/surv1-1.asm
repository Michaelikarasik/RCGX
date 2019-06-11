bits 32
mov dx, 0xffff
mov esi, edi
mov edi, eax
add edi, here
push edi
mov ax, 0xfbe8
;int 0x86
mov edi, [esp]
movsd
movsd
movsd
here: