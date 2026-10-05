; Fusion OS - First Bootloader

bits 16
start:
	jmp start

times 510 - ($ - $$) db 0
dw 0xaa55
