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

; This is the memory layout right before we pass exectution to the kernel

;         ~                        ~
;         |  Protected-mode kernel |
; 100000  +------------------------+
;         |  I/O memory hole	     |
; 0A0000	+------------------------+
;         |  Reserved for BIOS	   |	Leave as much as possible unused
;         ~                        ~
;         |  Command line		       |	(Can also be below the X+10000 mark)
; X+10000	+------------------------+
;         |  Stack/heap		         |	For use by the kernel real-mode code.
; X+08000	+------------------------+
;         |  Kernel setup		       |	The kernel real-mode code.
;         |  Kernel boot sector	   |	The kernel legacy boot sector.
; X       +------------------------+
;         |  Boot loader		       |	<- Boot sector entry point 0000:7C00
; 001000	+------------------------+
;         |  Reserved for MBR/BIOS |
; 000800	+------------------------+
;         |  Typically used by MBR |
; 000600	+------------------------+
;         |  BIOS use only	       |
; 000000	+------------------------+


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

; For more information see: https://www.kernel.org/doc/Documentation/x86/boot.txt
; Section **** RUNNING THE KERNEL
cli   ;Clear the interrupt flag
mov ax, 0x1000 ; Start of real mode 0x10000
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov sp, 0xe000 ; Top of the heap
jmp 0x1020:0

jmp $

; ================= functions ====================
;length in bytes into edx
; Load real mode (compressed kernel code)) from disk at
; 0x20000 and then move it at 0x100000
; Why ? because int 0x13 can only go up to 0x100000
; Why ? ask Intel
loader:
.loop:
    cmp edx, 127*512
    jl loader.part_2
    jz loader.finish

    mov ax, 0x7f ;count (127) because some bios only alow up to 127 sector at once
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
; Once we have loaded data from disk to 0x2000
; We need to move it to 0x100000 (Protected-mode kernel)
highmove:
    mov esi, 0x20000                 ;From
    mov edi, [highmove_addr]         ;TO
    mov edx, 512*127
    mov ecx, 0 ; pointer
.loop:
    mov eax, [esi]      ;From
    mov [edi], eax      ;To
    add esi, 4
    add edi, 4
    sub edx, 4
    jnz highmove.loop
    mov [highmove_addr], edi  ; Increase disk pointer
    ret

hddread:
    push eax
    mov [dap.count], ax ; num sectors
    mov [dap.offset], bx ;dest offset
    mov [dap.segment], cx ;dest segment
    mov edx, dword [hdd_pointer]
    mov dword [dap.lba_l], edx ; lba low bits
    add [hdd_pointer], ax
    mov ah, 0x42
    mov si, dap
    mov dl, 0x80 ; first hdd
    int 0x13
    pop eax
    ret

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
    hdd_pointer dd 1   

;boot sector magic
	times	510-($-$$)	db	0
	dw	0xaa55
