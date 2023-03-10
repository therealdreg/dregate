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
	banner db 0ah, "cgateloop 1.1 by David Reguera Garcia aka Dreg", 0ah, "https://github.com/therealdreg/cagrackme", 0ah, "https://github.com/therealdreg/dregate" , 0ah, "dreg@fr33project.org", 0ah, "https://www.fr33project.org", 0ah, "https://github.com/therealdreg", 0ah, 0ah, 0
    ConsoleText db 0ah, "re executing call gates: this program will bsod (race condition), please wait a few mins",0ah, 0

.code 
start: 
	invoke StdOut, addr banner
    invoke GetCurrentThread
    invoke SetThreadAffinityMask, eax, 1
    invoke StdOut, addr ConsoleText
    invoke Sleep, 4000
    
    loopez:
    CALL_FAR 328h, 0, 0
    invoke StdOut, addr ConsoleText 
    jmp loopez
    
    invoke ExitProcess, NULL 

   

end start