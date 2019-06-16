bits 32
mov ecx, 0xffffffff
add eax, end
xchg eax, edi
mov eax, 0x11111111
rep stosd
end: