bits 32
%define jump_gap 0x300
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
movsd
movsd
mov al, 0xa5 - 2
sub edi, 4 * 10
mov esi, eax
add esi, 1
xchg esi, edi

mov dword [eax], 0xd0ff
mov esp, eax
add sp, 200
call eax
endofcode:

extrasegcode:
movsd
sub ax, jump_gap
movsd
movsd
mov dword [eax], 0xd0ff
movsd
movsd
movsd
sub si, endofextracode - extrasegcode
sub di, jump_gap + (endofextracode - extrasegcode)
call eax
db 0xcc
endofextracode:

