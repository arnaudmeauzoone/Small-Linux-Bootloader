;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.

[BITS 16]
org	0x7c00

mov ax, 0x1000 ; segment for kernel load (mem off 0x10000)
mov	es, ax


mov [dap.count], byte 1 ; num sectors
mov [dap.offset],byte 0 ;dest offset
mov [dap.segment],word es ;dest segment
mov [dap.lba_l],dword 0x01 ;lba low bits
mov ah, 0x42
mov si, dap
mov dl, 0x80 ; first hdd
int 0x13

add	[hdd_pointer], byte 1		; update hdd offset pointer

;read_kernel_setup


mov al, [es:0x1F1] ; no of sectors
mov [dap.count], al ; num sectors
mov [dap.offset],word 512 ;dest offset
mov [dap.segment],word es ;dest segment
mov [dap.lba_l],dword 0x02 ;lba low bits
mov ah, 0x42
mov si, dap
mov dl, 0x80 ; first hdd
int 0x13

add	[hdd_pointer], eax		; update hdd offset pointer

mov byte [es:0x1fa], 0xffff ;video mode
mov byte [es:0x210], 0xe1 ;loader type
mov byte [es:0x211], 0x81 ;heap use? !! SET Bit5 to Make Kern Quiet
mov word [es:0x224], 0xde00 ;head_end_ptr
mov byte [es:0x227], 0x01 ;ext_loader_type / bootloader id
mov dword [es:0x228], 0x1e000 ;cmd line ptr

;load_kernel
mov edx, [es:0x1f4] ; bytes to load
shl edx, 4
call loader



;load_initrd
mov eax, [highmove_addr] ; end of kernel and initrd load address
mov [es:0x218], eax
mov edx, [initRdSize] ; ramdisk size in bytes
mov [es:0x21c], edx ; ramdisk size into kernel header
call loader



;kernel_start
cli
mov ax, 0x1000
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov sp, 0xe000
jmp 0x1020:0

jmp $

; ================= functions ====================
;length in bytes into edx
; uses hddread [hdd_pointer] and highmove [highmove_addr] vars
;clobbers 0x2000 segment
loader:
.loop:
    cmp edx, 127*512
    jl loader.part_2
    jz loader.finish

    mov ax, 0x7f ;count
    xor bx, bx ; offset
    mov cx, 0x2000 ; seg
    push edx
    call hddread
    call highmove
    pop edx
    sub edx, 127*512

    jmp loader.loop

.part_2:   ; load less than 127*512 sectors
    shr edx, 9  ; divide by 512
    inc edx     ; increase by one to get final sector if not multiple - otherwise just load junk - doesn't matter
    mov ax, dx
    xor bx,bx
    mov cx, 0x2000
    call hddread
    call highmove

.finish:
    ret

highmove_addr dd 0x100000
; source = 0x2000
; count = 127*512  fixed, doesn't if matter we copy junk at end
; don't think we can use rep movsb here as it wont use EDI/ESI in unreal mode
highmove:
    mov esi, 0x20000
    mov edi, [highmove_addr]
    mov edx, 512*127
    mov ecx, 0 ; pointer
.loop:
    mov eax, [ds:esi]
    mov [ds:edi], eax
    add esi, 4
    add edi, 4
    sub edx, 4
    jnz highmove.loop
    mov [highmove_addr], edi
    ret

hddread:
    push eax
    mov [dap.count], ax
    mov [dap.offset], bx
    mov [dap.segment], cx
    mov edx, dword [hdd_pointer]
    mov dword [dap.lba_l], edx
    ;and eax, 0xffff
    ;add edx, eax       ; update hdd offset pointer
    add [hdd_pointer], ax
    mov ah, 0x42
    mov si, dap
    mov dl, 0x80 ; first hdd
    int 0x13
    pop eax
    ret

  ;   push	edx
	; mov	[dap.count], ax
	; mov	[dap.offset], bx
	; mov	[dap.segment], cx
	; mov	edx, [hdd_pointer]
	; mov	[dap.lba_l], edx
	; add	[hdd_pointer], eax		; update current_lba
	; mov	ah, 0x42
	; mov	si, dap
	; mov	dl, 0x80			; first hard disk
	; int	0x13
	; pop	edx
	; ret

dap:
    db 0x10 ; size
    db 0 ; unused
.count:
    dw 0 ; num sectors
.offset:
    dw 0 ;dest offset
.segment:
    dw 0 ;dest segment
.lba_l:
    dd 0 ; lba low bits
.lba_h:
    dd 0 ; lba high bits

; config options
    cmdLine db "auto",0
    cmdLineLen equ $-cmdLine
    initRdSize dd initRdSizeDef ;From build.sh
    hdd_pointer dd 1   ;start address for kernel - subsequent calls are sequential

;boot sector magic
	times	510-($-$$)	db	0
	dw	0xaa55
