bits 32
mov esi, eax
add esi, extrasegcode
movsd
movsd
movsd
movsd
movsd
movsd
movsd
movsd
sub edi, 4 * 8
mov esi, eax
add esi, 6
xchg esi, edi
mov al, 0xa5 - 7

mov dword [eax], 0xd0ff
mov esp, eax
add esp, 200
call eax
endofcode:

extrasegcode:
movsd
sub ax, 0x1000
movsd
movsd
mov dword [eax], 0xe8fbffff
movsd
mov byte [eax + 4], 0xff
movsd
mov edi, eax
movsd
movsd
sub esi, endofextracode - extrasegcode
call eax
endofextracode:

