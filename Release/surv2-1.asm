bits 32
again:
sub eax, 4
mov dword [eax], 0xdddddddd
jmp again
