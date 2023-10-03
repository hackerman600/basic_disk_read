org 0x7C00
bits 16

jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2                    ; 2 * 9 * 512 = 9216 bytes exist in the fats.
bdb_dir_entries_count:      dw 0E0h                 ; 224 directory entries.
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter - 
ebr_volume_label:           db 'NANOBYTE OS'        ; 11 bytes, padded with spaces - define name of extended boot record. 
ebr_system_id:              db 'FAT12   '           ; 8 bytes - defines the type of secondary storage system

; goal of master boot record = read code needed to bootstrap the os. 
; stc jnc because if read operation is successful then carry flag is cleared.
; int 13 to read and reset the disk controller everytime the read operation fails.
; push all the registers before reading from disk then pop. interrupts can mess things up.
; 

start:
    jmp main


pushthem:
    push ss
    push es
    push cs
    push ds


show_on_screen:
    lodsb
    cmp al,0
    je pop_and_ret

    mov ah,0x0e
    int 0x10

    jmp show_on_screen     


pop_and_ret:
    pop ss
    pop es
    pop ds
    pop si

    ret
    

main:
    mov ax, 0
    mov ss, ax
    mov es, ax
    mov ds, ax
    mov bx, 0

    mov si, my_string
    call pushthem

    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
  
    call disk_read_attempts
    
    call halt


lba_to_chs:

    push ax
    
    xor dx, dx
    ;sector = LBA % s + 1 (cx bit 0-5)
    div word[bdb_sectors_per_track]
    inc dx
    mov cx, dx
    xor dx, dx

    ;cylinder = LBA / s / h (cx bit 6-15)
    div word[bdb_heads]
    mov ch, al
    shl ah, 6
    or cl, ah

    ;head = LBA / s % h (dh)
    mov dh, dl

    pop ax
    xor dl, dl
    pop ax
    ret


disk_read:

    ; set parameters in the prologue
    pusha
    ;mov ah, 0x02
    ;mov di, 3
    stc
    int 0x13    ;attempt to read.
    popa
    jnc show_success_msg
    

    ret


disk_read_attempts:

    ; create physical address 
    ;call lba_to_chs

    ;set the carry flag and disk read
    call disk_read
    
    ;if disk read fails
    call disk_reset

    inc bx
    cmp bx, 3
    je show_failed_msg


    jmp disk_read_attempts


disk_reset: 
    pusha
    mov ah, 0
    stc
    int 0x13
    popa
    jc show_failed_msg
    ret


show_success_msg:
    mov si, success_msg
    xor ax, ax
    jmp pushthem
    jmp halt


show_failed_msg:
    xor ax, ax
    mov si, failed_msg
    jmp pushthem
    jmp halt


halt:
    hlt
    cli
    
my_string:      db 'MyStr1ng',0
failed_msg:       db 'read operation has failed',0 
success_msg:        db 'read operation was a success',0 

times 510-($-$$) db 0
dw 0AA55h







