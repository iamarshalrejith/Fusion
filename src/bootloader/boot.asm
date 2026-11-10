
org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 Header
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'       ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880            ; 2880 * 512 = 1.44 MB
bdb_media_descriptor_type: db 0F0h            ; F0 = 3.5-inch floppy
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sectors_count:    dd 0

;
; Extended Boot Record
;
ebr_drive_number:   db 0                 ; 0x00 = floppy, 0x80 = HDD
                    db 0                 ; Reserved
ebr_signature:      db 29h
ebr_volume_id:      db 12h, 34h, 56h, 78h
ebr_volume_label:   db 'FUSION OS  '    ; must be exactly 11 bytes
ebr_system_id:      db 'FAT12   '        ; 8 bytes

;
; Code goes here
;

start:
    jmp main

;
; Prints a string to the screen
; Parameters:
;   DS:SI -> Null-terminated string
;

puts:
    ; Save registers we will modify
    push si
    push ax

.loop:
    lodsb                   ; Load next character into AL
    or al, al                ; Check if character is null
    jz .done

    mov bh, 0
    mov ah, 0x0E             ; BIOS teletype output
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si
    ret

;
; Main
;

main:
    ; Setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Setup stack
    mov ss, ax
    mov sp, 0x7C00           ; Stack grows downwards

    ; Save BIOS boot drive number
    mov [ebr_drive_number], dl

    ; Read from floppy disk
    mov ax, 1                ; LBA = 1 (second sector)
    mov cl, 1                ; Read 1 sector
    mov bx, 0x7E00           ; Load data after bootloader
    call disk_read

    ; Print message
    mov si, msg_hello
    call puts

    cli                     ; disable interrupts, so cpu can't get out halt state
    hlt

;
; Error Handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16                 ; Wait for keypress
    jmp 0FFFFh:0             ; Reboot through BIOS

.halt:
    cli                     ; disable interrupts, so cpu can't get out halt state
    hlt

;
; Disk Routines
;

;
; Converts LBA address to CHS address
;
; Parameters:
;   AX = LBA address
;
; Returns:
;   CX[0-5]   = Sector number
;   CX[6-15]  = Cylinder
;   DH        = Head
;

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]
                            ; AX = LBA / SectorsPerTrack
                            ; DX = LBA % SectorsPerTrack

    inc dx                  ; Sector = (LBA % SectorsPerTrack) + 1
    mov cx, dx              ; CX = Sector

    xor dx, dx
    div word [bdb_heads]    ; AX = Cylinder
                            ; DX = Head

    mov dh, dl              ; DH = Head
    mov ch, al              ; CH = Cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah               ; Upper 2 cylinder bits into CL

    pop ax
    mov dl, al              ; Restore DL
    pop ax
    ret

;
; Reads sectors from a disk
;
; Parameters:
;   AX    = LBA address
;   CL    = Number of sectors to read (up to 128)
;   DL    = Drive number
;   ES:BX = Memory address to store data
;


disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    ; Save sector count
    push cx

    ; Convert LBA to CHS
    call lba_to_chs

    ; Restore sector count into AL
    pop ax

    ; Initialize retry counter
    mov di, 3

.retry:
    ; Set BIOS disk parameters
    mov ah, 02h
    mov dl, [ebr_drive_number]

    ; Save registers before BIOS call
    pusha

    stc
    int 13h

    jnc .done

    ; Restore registers after failed attempt
    popa

    ; Reset disk controller
    call disk_reset

    ; Decrease retry count
    dec di
    jnz .retry

.fail:
    jmp floppy_error

.done:
    popa

    ; Restore original registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret


;
; Resets disk controller
;
; Parameters:
;   DL = Drive number
;

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h

    jc floppy_error

    popa
    ret

;
; Messages
;

msg_hello:
    db "Hello from Fusion!", ENDL, 0

msg_read_failed:
    db "Read from disk failed!", ENDL, 0

;
; Boot signature and padding
;

times 510 - ($ - $$) db 0
dw 0AA55h
