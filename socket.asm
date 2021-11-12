	
;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'SOCKET', 0

;-------------------------------------------------------------------------------
; Dependencies
;-------------------------------------------------------------------------------
include_library '../usbdrvce/usbdrvce.asm'
include_library '../srldrvce/srldrvce.asm'

;-------------------------------------------------------------------------------
; v0 functions (not final, subject to change!)
;-------------------------------------------------------------------------------
export socket_open
export socket_settimeout
export socket_send
export socket_read
export socket_close


os_GetKey	:= $21D38
_puts       := $0207C0 

_indcallhl:
	jp	(hl)
	
_indcall   := 00015Ch

_atomic_load_increasing_32:
	pop	hl
	ex	(sp),iy			; iy = p
	push	hl
	ld	a,i
	di
	ld	de,(iy)			;         2R
	ld	c,(iy+3)		;  + 3F + 1R
	ld	hl,(iy)			;  + 3F + 3R
	ld	a,(iy+3)		;  + 3F + 1R
					; == 9F + 7R
					; == 57 cc
					;  + 9 * 19 cc = 171 cc (worst-case DMA)
					; = 228 cc
	jp	po,no_ei
	ei
no_ei:
	or	a,a
	sbc	hl,de
	sbc	a,c			; auhl = second value read
					;         - first value read
	ex	de,hl
	ld	e,c			; euhl = first value read
	ret
no_swap:
	add	hl,de
	adc	a,c
	ld	e,a			; euhl = second value read
	ret
	
socket_open:
	ld	hl, -4
	call	ti._frameset
	ld	hl, (ix + 6)
	ld	de, (ix + 9)
	ld	(_srl_buf), hl
	ld	(_srl_buf_size), de
	call	_cemu_check
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, .lbl_2
	ld	hl, -327680
	ld	de, L_.str
	ld	bc, 38
	push	bc
	push	de
	push	hl
	call	ti._memcpy
	pop	hl
	pop	hl
	pop	hl
	ld	a, 1
	ld	(_cemu_mode), a
.lbl_8:
	or	a, a
	sbc	hl, hl
	jq	.lbl_11
.lbl_2:
	ld	hl, (ix + 12)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_4
	push	hl
	call	usb_MsToCycles
	ld	a, e
	pop	de
	ld	(_sock_timeout), hl
	ld	(_sock_timeout+3), a
.lbl_4:
	call	srl_GetCDCStandardDescriptors
	ld	de, 36106
	push	de
	push	hl
	ld	hl, 0
	push	hl
	ld	hl, _handle_usb_event
	push	hl
	call	usb_Init
	pop	de
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_9
	call	usb_GetCycleCounter
	ld	(ix + -3), hl
	ld	(ix + -4), e
.lbl_6:
	call	usb_HandleEvents
	call	usb_GetCycleCounter
	ld	bc, (ix + -3)
	ld	a, (ix + -4)
	call	ti._lsub
	push	hl
	pop	iy
	ld	d, e
	ld	bc, (_sock_timeout)
	ld	a, (_sock_timeout+3)
	push	bc
	pop	hl
	ld	e, a
	call	ti._ladd
	lea	bc, iy + 0
	ld	a, d
	call	ti._lcmpu
	jq	c, .lbl_10
	ld	a, (_srl_ready)
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, .lbl_6
	jq	.lbl_8
.lbl_9:
	ld	hl, 2
	jq	.lbl_11
.lbl_10:
	ld	hl, 1
.lbl_11:
	ld	sp, ix
	pop	ix
	ret
	
_handle_usb_event:
	call	ti._frameset0
	ld	de, (ix + 6)
	ld	iy, 0
	ld	bc, 1
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_3
	ld	de, (ix + 9)
	ld	hl, (_srl_device)
	or	a, a
	sbc	hl, de
	jq	nz, .lbl_9
	ld	hl, _srl_device
	push	hl
	call	srl_Close
	ld	iy, 0
	pop	hl
	xor	a, a
.lbl_8:
	ld	(_srl_ready), a
	jq	.lbl_9
.lbl_3:
	ld	bc, 8
	ex	de, hl
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_9
	ld	l, 1
	ld	a, (_srl_ready)
	xor	a, l
	xor	a, l
	bit	0, a
	jq	nz, .lbl_9
	ld	hl, 8
	ld	de, 0
	push	hl
	push	de
	push	de
	call	usb_FindDevice
	ld	iy, 0
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_9
	ld	bc, 9600
	ld	iy, (_srl_buf)
	ld	de, (_srl_buf_size)
	push	bc
	ld	bc, -1
	push	bc
	push	de
	push	iy
	push	hl
	ld	hl, _srl_device
	push	hl
	call	srl_Open
	ld	iy, 0
	pop	de
	pop	de
	pop	de
	pop	de
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_9
	ld	a, 1
	jq	.lbl_8
.lbl_9:
	lea	hl, iy + 0
	pop	ix
	ret
	
socket_settimeout:
	call	ti._frameset0
	ld	l, (ix + 6)
	ld	h, (ix + 7)
	push	hl
	call	usb_MsToCycles
	ld	a, e
	pop	de
	ld	(_sock_timeout), hl
	ld	(_sock_timeout+3), a
	or	a, a
	sbc	hl, hl
	pop	ix
	ret
	
_serial_send:
	ld	hl, -6
	call	ti._frameset
	ld	de, (ix + 9)
	ld	bc, 3
	ld	(ix + -3), de
	ld	hl, (_srl_buf_size)
	or	a, a
	sbc	hl, de
	jq	c, .lbl_7
	ld	hl, _srl_device
	push	bc
	pea	ix + -3
	push	hl
	call	srl_Write
	ld	(ix + -6), hl
	pop	hl
	pop	hl
	pop	hl
	call	usb_HandleEvents
	ld	de, 3
	ld	hl, (ix + -6)
	or	a, a
	sbc	hl, de
	jq	nz, .lbl_6
	ld	hl, (ix + 6)
	ld	de, (ix + -3)
	push	de
	push	hl
	ld	hl, _srl_device
	push	hl
	call	srl_Write
	pop	de
	pop	de
	pop	de
	ld	de, 3
	add	hl, de
	ld	(ix + -6), hl
	call	usb_HandleEvents
	ld	de, (ix + -3)
	ld	hl, (ix + -6)
	or	a, a
	sbc	hl, de
	ld	hl, 0
	jq	z, .lbl_5
	ld	hl, 4
	jq	.lbl_5
.lbl_6:
	ld	bc, 4
.lbl_7:
	push	bc
	pop	hl
.lbl_5:
	ld	sp, ix
	pop	ix
	ret
	
_pipe_send:
	ld	hl, -3
	call	ti._frameset
	ld	hl, (ix + 9)
	ld	de, -327680
	ld	bc, L_.str.2
	ld	(ix + -3), hl
	push	hl
	push	bc
	push	de
	call	ti.sprintf
	pop	hl
	pop	hl
	pop	hl
	ld	hl, 3
	push	hl
	pea	ix + -3
	call	_cemu_send
	pop	hl
	pop	hl
	ld	hl, (ix + -3)
	push	hl
	ld	hl, (ix + 6)
	push	hl
	call	_cemu_send
	pop	hl
	pop	hl
	or	a, a
	sbc	hl, hl
	ld	sp, ix
	pop	ix
	ret
	
socket_send:
	ld	hl, -3
	call	ti._frameset
	ld	hl, (ix + 9)
	ld	bc, 0
	ld	a, (_cemu_mode)
	ld	e, 1
	xor	a, e
	bit	0, a
	jq	z, .lbl_2
	ld	de, 1
	ld	(ix + -3), de
	push	hl
	push	hl
	call	_serial_send
	jq	.lbl_3
.lbl_2:
	ld	de, (ix + 6)
	push	hl
	push	de
	ld	(ix + -3), bc
	call	_pipe_send
.lbl_3:
	pop	hl
	pop	hl
	ld	hl, (ix + -3)
	ld	sp, ix
	pop	ix
	ret
	
_usb_read_to_size:
	call	ti._frameset0
	ld	iy, (ix + 6)
	ld	hl, (ix + 9)
	ld	de, _srl_device
	ld	bc, (_bytes_read)
	add	iy, bc
	or	a, a
	sbc	hl, bc
	push	hl
	push	iy
	push	de
	call	srl_Read
	push	hl
	pop	de
	pop	hl
	pop	hl
	pop	hl
	ld	iy, (_bytes_read)
	add	iy, de
	ld	de, (ix + 9)
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	lea	hl, iy + 0
	jq	c, .lbl_2
	or	a, a
	sbc	hl, hl
.lbl_2:
	ld	(_bytes_read), hl
	lea	hl, iy + 0
	or	a, a
	sbc	hl, de
	jq	nc, .lbl_3
	ld	a, 0
	jq	.lbl_5
.lbl_3:
	ld	a, 1
.lbl_5:
	and	a, 1
	or	a, a
	sbc	hl, hl
	ld	l, a
	pop	ix
	ret
	
_pipe_read_to_size:
	call	ti._frameset0
	ld	bc, (ix + 9)
	ld	iy, 0
	ld	de, (_bytes_read)
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	jq	nc, .lbl_5
	ld	iy, (ix + 6)
	add	iy, de
	ld	hl, (ix + 9)
	or	a, a
	sbc	hl, de
	push	hl
	push	iy
	call	_cemu_get
	ld	bc, 0
	push	bc
	pop	iy
	push	hl
	pop	de
	pop	hl
	pop	hl
	ld	hl, (_bytes_read)
	add	hl, de
	ld	(_bytes_read), hl
	jq	.lbl_2
.lbl_5:
	ex	de, hl
.lbl_2:
	ld	de, (ix + 9)
	or	a, a
	sbc	hl, de
	jq	nc, .lbl_3
	lea	hl, iy + 0
	jq	.lbl_4
.lbl_3:
	ld	hl, 1
	ld	(_bytes_read), iy
.lbl_4:
	pop	ix
	ret
	
socket_read:
	ld	hl, -3
	call	ti._frameset
	ld	a, (_cemu_mode)
	ld	l, 1
	xor	a, l
	bit	0, a
	jq	nz, .lbl_2
	ld	hl, _pipe_read_to_size
	jq	.lbl_3
.lbl_2:
	ld	hl, _usb_read_to_size
.lbl_3:
	ld	(ix + -3), hl
	call	usb_HandleEvents
	ld	hl, (_socket_read.packet_size)
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	nz, .lbl_7
	ld	hl, 3
	push	hl
	ld	hl, (ix + 6)
	push	hl
	ld	hl, (ix + -3)
	call	_indcallhl
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	jq	z, .lbl_10
	ld	hl, (ix + 6)
	ld	hl, (hl)
	ld	(_socket_read.packet_size), hl
.lbl_10:
	xor	a, a
	jq	.lbl_11
.lbl_7:
	push	hl
	ld	hl, (ix + 6)
	push	hl
	ld	hl, (ix + -3)
	call	_indcallhl
	pop	de
	pop	de
	add	hl, bc
	or	a, a
	sbc	hl, bc
	ld	a, 0
	jq	z, .lbl_11
	ld	a, 1
	or	a, a
	sbc	hl, hl
	ld	(_socket_read.packet_size), hl
.lbl_11:
	pop	hl
	pop	ix
	ret
	
socket_close:
	ld	l, 1
	ld	a, (_cemu_mode)
	xor	a, l
	xor	a, l
	bit	0, a
	call	z, usb_Cleanup
	ld	a, 1
	ret
	
_bytes_read:
	rb	3

_srl_ready:
	rb	1

_cemu_mode:
	rb	1

_srl_buf:
	rb	3

_srl_buf_size:
	rb	3

_sock_timeout:
	dd	1000

L_.str:
	db	"CEmu pipe compatibility mode enabled",012o,000o

_srl_device:
	rb	39

L_.str.2:
	db	"sending %u bytes to CEmu pipe",012o,000o

_socket_read.packet_size:
	rb	3
 
 _printf_str1:
	db	"Size: %u\n",000o


check_cmd = 2
send_cmd = 3
get_cmd = 4

dbgext = 0xFD0000

_cemu_check:
	xor	a,a
	ld	hl,dbgext
	ld	(hl),check_cmd
	ret

_cemu_send:
	pop	de
	pop	hl
	pop	bc
	push	bc
	push	hl
	push	de

	ld	a,send_cmd
	ld	(dbgext),a

	push	bc
	pop	hl

	ret

_cemu_get:
	pop	hl
	pop	de
	pop	bc
	push	bc
	push	de
	push	hl

	ld	a,get_cmd
	ld	(dbgext),a

	push	bc
	pop	hl

	ret


boot_WaitShort  := 00003B4h
