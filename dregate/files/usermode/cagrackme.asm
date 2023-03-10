; MIT License
; https://github.com/therealdreg/cagrackme
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

; SOLUTION:
; first code is:  0x69696969
; second code is: 0xFFFFFF00

loopcall equ <>
enabletf equ <>


include masminclude\masm32rt.inc 
includelib masmlib\kernel32.lib 
includelib masmlib\user32.lib

assume FS:nothing

CALL_FAR MACRO sel, _offset, rpl
    db 9ah
    dd offset _offset
    dw offset sel + rpl
ENDM

.data 
	banner db 0ah, "cagrackme 1.1 by David Reguera Garcia aka Dreg", 0ah, "https://github.com/therealdreg/cagrackme", 0ah, "https://github.com/therealdreg/dregate" , 0ah, "dreg@fr33project.org", 0ah, "https://www.fr33project.org", 0ah, "https://github.com/therealdreg", 0ah, 0ah, 0
    MsgBoxCaption  db "cagrackme 1.1 by Dreg",0 
    MsgBoxText       db "The real challenge is understand what the hell is hapenning inside x-)",0

    MsgBoxCaptionCG  db "call gate executed",0 
    MsgBoxTextCG       db "call gate executed",0

    ConsoleText db "re executing call gate",0ah, 0
    
    ConsoleTextEnableTf db "enabletf",0ah, 0

    ConsoleTextEnableLoop db "enableloop",0ah, 0

    ConsoleTextEnableEnterCode1 db "Enter code1: ", 0
    ConsoleTextEnableEnterCode2 db "Enter code2 (you can crash the OS if you dont understand): ", 0

    MsgBoxCaptionGS  db "Good serial!",0 
    MsgBoxTextGS     db "Good serial!",0

    str2 db "%X", 0

.data?

buffer      db 64 dup(?)

buffer2      db 64 dup(?)

.code 
start: 
	invoke StdOut, addr banner
    ifdef enabletf 
        invoke StdOut, addr ConsoleTextEnableTf 
    endif
    ifdef loopcall 
        invoke StdOut, addr ConsoleTextEnableLoop
    endif

    mov dword ptr [buffer], 0
    mov dword ptr [buffer2], -1
    invoke StdOut, addr ConsoleTextEnableEnterCode1 
    invoke  crt_scanf,ADDR str2,ADDR buffer

    cmp dword ptr [buffer], 69696969h
    jnz ouhgh

    invoke StdOut, addr ConsoleTextEnableEnterCode2
    invoke  crt_scanf,ADDR str2,ADDR buffer2

    ouhgh:
    invoke MessageBox, NULL, addr MsgBoxText, addr MsgBoxCaption, MB_SETFOREGROUND or MB_OK 

    invoke GetCurrentThread
    invoke SetThreadAffinityMask, eax, 1
    invoke Sleep, 1

    jmp ghui
    
    ;int 3

woha:    
    and eax, dword ptr [buffer2]
    mov ebx, 69696969h
    mov ecx, 69696969h
    mov edx, 69696969h
    mov esi, 69696969h
    mov edi, 69696969h

    mov ebp, esp
    xor esi, esi
    xor edi, edi
    mov si, ss
    mov di, cs
	
	push 69696969h
	push 69696969h
	push 69696969h
	push 9696969h
	push 69696969h
	push 69696969h
	push 69696969h

    ifdef enabletf
        pushf
        mov ecx, esp
        or word ptr[ecx+0], 0100H
        mov ecx, 69696969h
        popf
    endif
    
    CALL_FAR 330h, 0, 0

    ifdef enabletf
        JMP justes
    endif
    
    execit:
    ifdef loopcall
        invoke StdOut, addr ConsoleText
        jmp ghui
    else
        invoke MessageBox, NULL, addr MsgBoxTextCG, addr MsgBoxCaptionCG, MB_SETFOREGROUND or MB_OK
    endif
    
    justes:
    invoke ExitProcess, NULL 

    gbo:
    invoke MessageBox, NULL, addr MsgBoxTextGS, addr MsgBoxCaptionGS, MB_SETFOREGROUND or MB_OK
    jmp justes

    nops 600
    jmp gbo

    ghui:
    call nxt
    jmp execit
    nxt:
    pop eax
    jmp woha

end start