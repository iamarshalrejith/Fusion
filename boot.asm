; Fusion OS - First Bootloader

bits 16
start:
	mov ah, 0x0e
	
	mov al, 'F'
	int 0x10

	mov al, 'u'
	int 0x10

	mov al, 's'
	int 0x10

	mov al, 'i'
	int 0x10
	
	mov al, 'o'
	int 0x10

	mov al, 'n'
	int 0x10

times 510 - ($ - $$) db 0
dw 0xaa55
