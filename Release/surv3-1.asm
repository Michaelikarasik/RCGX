bits 32
mov ecx, 0xffffffff
add eax, end
xchg eax, edi
mov eax, 0xf3abf3ab
rep stosd
end: