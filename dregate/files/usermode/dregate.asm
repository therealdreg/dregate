; MIT License
;
; https://github.com/therealdreg/dregate
;
; Copyright (c) [2022] by David Reguera Garcia aka Dreg 
; dreg@fr33project.org
; https://www.fr33project.org 
; https://github.com/therealdreg
; TW @therealdreg
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;
; WARNING: BULLSHIT CODE X-)

.486
.model flat, stdcall
option casemap:none 

assume FS:nothing

include masminclude\windows.inc 
include masminclude\kernel32.inc 
include masminclude\user32.inc 

includelib masmlib\kernel32.lib 
includelib masmlib\user32.lib

EXTERN user_mode_apc :PROC 

CALL_FAR_LOCT equ 330h


CALL_FAR MACRO sel, _offset, rpl
    db 9ah
    dd offset _offset
    dw offset sel + rpl
ENDM


DREGATECALLFAR MACRO arg1, arg2, arg3, arg4, arg5, arg6, arg7
	pushad
	pushfd
	
	call GetCurrentThread
	push 1
	push eax
	call SetThreadAffinityMask
	
	push 200
	call Sleep
	
	push ebp

	mov ebp, esp
	;int 3
	push arg7
	push arg6
	push arg5
	push arg4
	mov eax, arg3
	push [eax]
	mov eax, arg2
	push [eax]
	mov eax, arg1
	push [eax]

	pushf
	mov ecx, esp
	or word ptr[ecx+0], 0100h
    xor esi, esi
    xor edi, edi
    mov si, ss
    mov di, cs
    mov ebx, 69696969h
    mov ecx, 69696969h
    mov edx, 69696969h
	mov eax, skip_hlt
    popf

	CALL_FAR CALL_FAR_LOCT, 0, 0
	hlt

	skip_hlt:
	pop ebp

	popfd
	popad

	ret
ENDM

.data
    MsgBoxCaption  db "dregate by Dreg, good key!",0 
	buffer         db "3 APC params:                                                ", 0
	pid            db 0, 0, 0, 0
	tid            db 0, 0, 0, 0
	addrapc        db 0, 0, 0, 0
	dregishot      db 0, 0, 0, 0

.code

get_addr_apc PROC
	mov eax, offset addrapc
	ret
get_addr_apc ENDP

get_pid_addr PROC
	mov eax, offset pid
	ret
get_pid_addr ENDP

get_tid_addr PROC
	mov eax, offset tid
	ret
get_tid_addr ENDP

good_key PROC
	mov eax, [esp+4]
	mov dword ptr buffer + 15, eax
	mov eax, [esp+8]
	mov dword ptr buffer + 20, eax
	mov eax, [esp+12]
	mov dword ptr buffer + 25, eax

	push MB_OK or MB_TOPMOST or MB_ICONWARNING
	push offset MsgBoxCaption
	push offset buffer
	push 0
	call MessageBoxA
	push 0

	lea eax, [esp+16]
	push [eax]
	sub eax, 4
	push [eax]
	sub eax, 4
	push [eax]
	call user_mode_apc

	call ExitProcess
good_key ENDP

bad_call_farf_low PROC
	DREGATECALLFAR offset dregishot, offset dregishot, offset dregishot, 0, 0, 0, 0
bad_call_farf_low ENDP

good_call_farf_low PROC
	DREGATECALLFAR offset addrapc, offset pid, offset tid, 66h, 65h, 64h, 63h
good_call_farf_low ENDP



END