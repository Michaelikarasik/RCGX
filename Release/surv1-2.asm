bits 32
mov esi, eax
add esi, extrasegexample
movsd
movsd
movsd
xchg edi,eax
add edi, here
mov ax, 0xab66
stosw
here:

extrasegexample:
mov ebx, 0xbbbbbbbb
pop esp
mov eax, 0xab535353
stosd
surv2here: