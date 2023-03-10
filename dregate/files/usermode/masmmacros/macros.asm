comment * -----------------------------------------------------------------
        Preprocessor code for high level language simulation in MASM32

                          Updated 4th November 2005
         ---------------------------------------------------------------- *

  ; *******************************************************************
  ; The following block of macros are macro functions that are designed
  ; to be called by other macros. In part they function as a library of
  ; components for writing other macros without having to repeatedly
  ; reproduce the same capacity. Effectively macro code reuse.
  ; *******************************************************************

  ; -----------------------------------------------------------
  ; This macro replaces quoted text with a DATA section OFFSET
  ; and returns it in ADDR "name" format. It is used by other
  ; macros that handle optional quoted text as a parameter.
  ; -----------------------------------------------------------
    reparg MACRO arg
      LOCAL nustr
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        .data
          nustr db arg,0        ;; write arg to .DATA section
        .code
        EXITM <ADDR nustr>      ;; append name to ADDR operator
      ELSE
        EXITM <arg>             ;; else return arg
      ENDIF
    ENDM

  ; -------------------------------------
  ; variation returns address in register
  ; so it can be assigned to a variable.
  ; -------------------------------------
    repargv MACRO arg
      LOCAL nustr
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        .data
          nustr db arg,0        ;; write arg to .DATA section
        .code
        mov eax, OFFSET nustr
        EXITM <eax>             ;; return data section offset in eax
      ELSE
        mov eax, arg
        EXITM <eax>             ;; else return arg
      ENDIF
    ENDM

  ; -----------------------------------------------------------
  ; replace a quoted string with its OFFSET in the data section
  ; -----------------------------------------------------------
    repargof MACRO arg
      LOCAL nustr
        quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        .data
          nustr db arg,0        ;; write arg to .DATA section
        .code
        EXITM <OFFSET nustr>    ;; append name to OFFSET operator
      ELSE
        EXITM <arg>             ;; else return arg
      ENDIF
    ENDM

  ; -------------------------------------------------------
  ; This is a parameter checking macro. It is used to test
  ; if a parameter in a macro is a quoted string when a
  ; quoted string should not be used as a parameter. If it
  ; is a user defined error message is displayed at
  ; assembly time so that the error can be fixed.
  ; -------------------------------------------------------
    tstarg MACRO arg
      quot SUBSTR <arg>,1,1
      IFIDN quot,<">            ;; if 1st char = "
        % echo arg ** QUOTED TEXT ERROR ** memory address expected
        .ERR
      ELSE
        EXITM <arg>             ;; else return arg
      ENDIF
    ENDM

  ; -----------------------------------------------
  ; count the number of arguments passed to a macro
  ; This is a slightly modified 1990 MASM 6.0 macro
  ; -----------------------------------------------
    argcount MACRO args:VARARG
      LOCAL cnt
      cnt = 0
      FOR item, <args>
        cnt = cnt + 1
      ENDM
      EXITM %cnt                ;; return as a number
    ENDM

  ; ---------------------------------------------------
  ; return an arguments specified in "num" from a macro
  ; argument list or "-1" if the number is out of range
  ; ---------------------------------------------------
    getarg MACRO num:REQ,args:VARARG
      LOCAL cnt, txt
      cnt = 0
      FOR arg, <args>
        cnt = cnt + 1
        IF cnt EQ num
          txt TEXTEQU <arg>     ;; set "txt" to content of arg num
          EXITM
        ENDIF
      ENDM
      IFNDEF txt
        txt TEXTEQU <-1>        ;; return -1 if num out of range
      ENDIF
      EXITM txt
    ENDM

  ; -------------------------
  ; determine an operand type
  ; -------------------------
    op_type MACRO arg:REQ
      LOCAL result
      result = opattr(arg)
        IF result eq 37         ;; label, either local or global
          EXITM %1
        ELSEIF result eq 42     ;; GLOBAL var
          EXITM %2
        ELSEIF result eq 98     ;; LOCAL  var
          EXITM %3
        ELSEIF result eq 36     ;; immediate operand or constant
          EXITM %4
        ELSEIF result eq 48     ;; register
          EXITM %5
        ELSEIF result eq 805    ;; local procedure in code
          EXITM %6
        ELSEIF result eq 933    ;; external procedure or API call
          EXITM %7
        ENDIF
      EXITM %0                  ;; anything else
    ENDM

    ; *************************************
    ; Return a register size in BYTES or  *
    ; 0 if the argument is not a register *
    ; *************************************
    regsize MACRO item
      LOCAL rv,ln
      rv = 0
      ln SIZESTR <item>
    
      IF ln EQ 2
        goto two
      ELSEIF ln EQ 3
        goto three
      ELSEIF ln EQ 4
        goto four
      ELSEIF ln EQ 5
        goto five
      ELSEIF ln EQ 6
        goto six
      ELSEIF ln EQ 8
        goto eight
      ELSE
        goto notreg
      ENDIF
    
    :two
      for arg,<al,ah,bl,bh,cl,ch,dl,dh>
        IFIDNI <arg>,<item>
          rv = 1
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
    
      for arg,<ax,bx,cx,dx,sp,bp,si,di>
        IFIDNI <arg>,<item>
          rv = 2
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
      goto notreg
    
    :three
      for arg,<eax,ebx,ecx,edx,esp,ebp,esi,edi>
        IFIDNI <arg>,<item>
          rv = 4
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
    
      for arg,<st0,st1,st2,st3,st4,st5,st6,st7>
        IFIDNI <arg>,<item>
          rv = 10
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
    
      for arg,<mm0,mm1,mm2,mm3,mm4,mm5,mm6,mm7>
        IFIDNI <arg>,<item>
          rv = 8
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
      goto notreg
    
    :four
      for arg,<xmm0,xmm1,xmm2,xmm3,xmm4,xmm5,xmm6,xmm7>
        IFIDNI <arg>,<item>
          rv = 16
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
      goto notreg
    
    :five
      for arg,<mm(0),mm(1),mm(2),mm(3),mm(4),mm(5),mm(6),mm(7)>
        IFIDNI <arg>,<item>
          rv = 8
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
    
      for arg,<st(0),st(1),st(2),st(3),st(4),st(5),st(6),st(7)>
        IFIDNI <arg>,<item>
          rv = 10
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
      goto notreg
    
    :six
      for arg,<xmm(0),xmm(1),xmm(2),xmm(3),xmm(4),xmm(5),xmm(6),xmm(7)>
        IFIDNI <arg>,<item>
          rv = 16
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF
      
    :eight
      for arg,<edx::eax,ecx::ebx>
        IFIDNI <arg>,<item>
          rv = 8
          EXITM
        ENDIF
      ENDM
      IF rv NE 0
        EXITM %rv
      ENDIF  
    
    :notreg
      EXITM %rv
    ENDM

;---------------------------------------------------

    issize MACRO var:req, bytes:req
        LOCAL rv
        rv = regsize(var) 
        IFE rv ; if not a register use SIZE 
            IF SIZE var EQ bytes
                EXITM <1>
            ELSE
                EXITM <0>
            ENDIF
        ELSE   ; it's a register       
            IF rv EQ bytes
                EXITM <1>        
            ELSE
                EXITM <0>
            ENDIF    
        ENDIF
    ENDM

; ----------------------------------------------

    isregister MACRO var:req
        IF regsize(var)
            EXITM <1>
        ELSE
            EXITM <0>
        ENDIF    
    ENDM    

  ; -----------------------------------------------------
  ; "catargs" takes 3 arguments.
  ; 1.  the NAME of the calling macro for error reporting
  ; 2.  the ADDRESS of the memory allocated for the text
  ; 3.  the ARGUMENTLIST of strings passed to the caller
  ; -----------------------------------------------------
    catargs MACRO mname,mem,args:VARARG
      LOCAL lcnt,var                        ;; LOCAL loop counter

      lcnt = argcount(args)                 ;; get the VARARG argument count
      REPEAT lcnt

      var equ repargof(getarg(lcnt,args))
      ;; -------------------------------------------------
      ;; if argument is a register, display error and stop
      ;; -------------------------------------------------
        IF op_type(repargof(getarg(lcnt,args))) EQ 4
          echo -------------------------------------------
        % echo Argument num2str(lcnt) INVALID OPERAND in mname
          echo ERROR Register or register return
          echo value not allowed in this context
          echo Valid options must be memory operands.
          echo They can occur in the following forms,
          echo *        1. quoted text
          echo *        2. zero terminated string address
          echo *        3. macro that returns an OFFSET
          echo *        4. built in character operators
          echo -------------------------------------------
        .err
        ENDIF
        IFIDN var,<lb>                      ;; ( notation
          IFNDEF @left_bracket@
            .data
              @left_bracket@ db "(",0
            .code
          ENDIF
          push OFFSET @left_bracket@
          goto overit
        ENDIF
        IFIDN var,<rb>                      ;; ) notation
          IFNDEF @right_bracket@
            .data
              @right_bracket@ db ")",0
            .code
          ENDIF
          push OFFSET @right_bracket@
          goto overit
        ENDIF
        IFIDN var,<la>                      ;; < notation
          IFNDEF @left_angle@
            .data
              @left_angle@ db "<",0
            .code
          ENDIF
          push OFFSET @left_angle@
          goto overit
        ENDIF
        IFIDN var,<ra>                      ;; > notation
          IFNDEF @right_angle@
            .data
              @right_angle@ db ">",0
            .code
          ENDIF
          push OFFSET @right_angle@
          goto overit
        ENDIF
        IFIDN var,<q>                       ;; quote notation
          IFNDEF @quote@
            .data
              @quote@ db 34,0
            .code
          ENDIF
          push OFFSET @quote@
          goto overit
        ENDIF
        IFIDN var,<n>                       ;; newline notation
          IFNDEF @nln@
            .data
              @nln@ db 13,10,0
            .code
          ENDIF
          push OFFSET @nln@
          goto overit
        ENDIF
        IFIDN var,<t>                       ;; tab notation
          IFNDEF @tab@
            .data
              @tab@ db 9,0
            .code
          endif
          push offset @tab@
          goto overit
        ENDIF
        push var                            ;; push current argument
      :overit
        lcnt = lcnt - 1
      ENDM

      push mem                              ;; push the buffer address
      push argcount(args)                   ;; push the argument count
      call szMultiCat                       ;; call the C calling procedure
      add esp, argcount(args)*4+8           ;; correct the stack
    ENDM

  ; ******************************************************
  ; num2str feeds a numeric macro value through a seperate
  ; macro to force a text return value. It is useful for
  ; displaying loop based debugging info and for display
  ; purposes with error reporting.
  ; NOTE :
  ; prefix the "echo" to display this result with "%"
  ; EXAMPLE :
  ; % echo num2str(arg)
  ; ******************************************************
    num2str MACRO arg
      EXITM % arg
    ENDM

  ; ********************************************************
  ; format a C style string complete with escape characters
  ; and return the offset of the result to the calling macro
  ; ********************************************************
    cfm$ MACRO txt:VARARG                       ;; format C style string
      LOCAL buffer,lbuf,rbuf,sln,flag1,tmp,notq
        flag1 = 0
        notq  = 0
        buffer equ <>
        lbuf equ <>
        rbuf equ <>
      FORC char,<txt>
        IFDIF <char>,<">                        ;; test if 1st char is a quote
          notq = 1
          EXITM                                 ;; exit with notq set to 1 if its not
        ENDIF
        EXITM                                   ;; else exit with notq set to 0
      ENDM
      IF notq EQ 1
        EXITM <txt>                             ;; return original arg if its not a quote
      ENDIF
      FORC char,<txt>
        IF flag1 NE 0                           ;; process characters preceded by the escape character
          IFIDN <char>,<n>
            buffer CATSTR buffer,<",13,10,">    ;; \n = newline
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<t>
            buffer CATSTR buffer,<",9,">        ;; \t = tab
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<\>
            buffer CATSTR buffer,<\>            ;; \\ = \
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<q>
            buffer CATSTR buffer,<",34,">       ;; \q = quote
            flag1 = 0
            goto lpend
          ENDIF
       ;; ---------------------
       ;; masm specific escapes
       ;; ---------------------
          IFIDN <char>,<l>
            buffer CATSTR buffer,<",60,">       ;; \l = <
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<r>
            buffer CATSTR buffer,<",62,">       ;; \r = >
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<x>
            buffer CATSTR buffer,<",33,">       ;; \x = !
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<a>
            buffer CATSTR buffer,<",40,">       ;; \a = (
            flag1 = 0
            goto lpend
          ENDIF
          IFIDN <char>,<b>
            buffer CATSTR buffer,<",41,">       ;; \b = )
            flag1 = 0
            goto lpend
          ENDIF
        ENDIF
        IFIDN <char>,<\>                        ;; trap the escape character and set the flag
          flag1 = 1
          goto lpend
        ENDIF
        buffer CATSTR buffer,<char>
    :lpend
      ENDM
    ;; ---------------------------------------------
    ;; strip any embedded <"",> characters sequences
    ;; ---------------------------------------------
        buffer CATSTR buffer,<,0,0,0>           ;; append trailing zeros
        cpos INSTR buffer,<"",>                 ;; test for leading junk
        IF cpos EQ 1
          buffer SUBSTR buffer,4                ;; chomp off any leading junk
        ENDIF
      :reloop
        cpos INSTR buffer,<"",>
          IF cpos EQ 0                          ;; if no junk left
            goto done                           ;; exit the loop
          ENDIF
        lbuf SUBSTR buffer,1,cpos-1             ;; read text before junk
        rbuf SUBSTR buffer,cpos+3               ;; read text after junk
        buffer equ <>                           ;; clear the buffer
        buffer CATSTR lbuf,rbuf                 ;; concantenate the two
        goto reloop                             ;; loop back and try again
      :done
        sln SIZESTR buffer
        buffer SUBSTR buffer,1,sln-4            ;; trim off tail padding
        .data
          tmp db buffer                         ;; write result to DATA section
        .code
        EXITM <OFFSET tmp>                      ;; return the DATA section OFFSET
    ENDM

    ; ----------------------------------------------------------------------
    ; A macro that encapsulates GetLastError() and FormatMessage() to return
    ; the system based error string for debugging API functions that return
    ; error information with the GetLastError() API call.
    ; ----------------------------------------------------------------------
      LastError$ MACRO
        IFNDEF @@_e_r_r_o_r_@@
          .data?
            @@_e_r_r_o_r_@@ db 1024 dup (?)
          .code
        ENDIF
        pushad
        pushfd
        invoke GetLastError
        mov edi,eax
        invoke FormatMessage,FORMAT_MESSAGE_FROM_SYSTEM,
                             NULL,edi,0,ADDR @@_e_r_r_o_r_@@,1024,NULL
        popfd
        popad
        EXITM <OFFSET @@_e_r_r_o_r_@@>
      ENDM

    ; --------------------------------------------
    ; the following two macros are for prototyping
    ; direct addresses with a known argument list.
    ; --------------------------------------------
      SPROTO MACRO func_addr:REQ,arglist:VARARG     ;; STDCALL version
        LOCAL lp,var
        .data?
          func_addr dd ?
        .const
        var typedef PROTO STDCALL arglist
        lp TYPEDEF PTR var
        EXITM <equ <(TYPE lp) PTR func_addr>>
      ENDM

      CPROTO MACRO func_addr:REQ,arglist:VARARG     ;; C calling version
        LOCAL lp,var
        .data?
          func_addr dd ?
        .const
        var typedef PROTO C arglist
        lp TYPEDEF PTR var
        EXITM <equ <(TYPE lp) PTR func_addr>>
      ENDM

  ; ------------------------------------------------------
  ; turn stackframe off and on for low overhead procedures
  ; ------------------------------------------------------
    stackframe MACRO arg
      IFIDN <on>,<arg>
        OPTION PROLOGUE:PrologueDef
        OPTION EPILOGUE:EpilogueDef
      ELSEIFIDN <off>,<arg>
        OPTION PROLOGUE:NONE
        OPTION EPILOGUE:NONE
      ELSE
        echo -----------------------------------
        echo ERROR IN "stackframe" MACRO
        echo Incorrect Argument Supplied
        echo Options 
        echo 1. off Turn default stack frame off
        echo 2. on  Restore stack frame defaults
        echo SYNTAX : frame on/off
        echo -----------------------------------
        .err
      ENDIF
    ENDM

  ; ----------------------------------------------------------------
  ; invoke enhancement. Add quoted text support to any procedure
  ; or API call by using this macro instead of the standard invoke.
  ; LIMITATION : quoted text must be plain text only, no ascii 
  ; values or macro reserved characters IE <>!() etc ..
  ; use SADD() or chr$() for requirements of this type.
  ; ----------------------------------------------------------------
    fn MACRO FuncName:REQ,args:VARARG
      arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                    ;; loop through all arguments
        arg CATSTR arg,<,reparg(var)>   ;; replace quotes and append arg
      ENDM
      arg                               ;; write the invoke macro
    ENDM

  ; ------------------------------------------------
  ; Function return value version of the above macro
  ; ------------------------------------------------
    rv MACRO FuncName:REQ,args:VARARG
      arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                    ;; loop through all arguments
        arg CATSTR arg,<,reparg(var)>   ;; replace quotes and append arg
      ENDM
      arg                               ;; write the invoke macro
      EXITM <eax>                       ;; EAX as the return value
    ENDM

  ; ---------------------------------------------------
  ; The two following versions support C style escapes.
  ; ---------------------------------------------------
    fnc MACRO FuncName:REQ,args:VARARG
      arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                    ;; loop through all arguments
        arg CATSTR arg,<,cfm$(var)>     ;; replace quotes and append arg
      ENDM
      arg                               ;; write the invoke macro
    ENDM

    rvc MACRO FuncName:REQ,args:VARARG
      arg equ <invoke FuncName>         ;; construct invoke and function name
      FOR var,<args>                    ;; loop through all arguments
        arg CATSTR arg,<,cfm$(var)>     ;; replace quotes and append arg
      ENDM
      arg                               ;; write the invoke macro
      EXITM <eax>                       ;; EAX as the return value
    ENDM


comment * ------------------------------------------
    jmp_table is used for arrays of label addresses
    MASM supports writing the label name directly
    into the .DATA section.
    EXAMPLE:
    jmp_table name,lbl1,lbl2,lbl3,lbl4
        ------------------------------------------ *
    jmp_table MACRO name,args:VARARG
      .data
        align 4
        name dd args
      .code
    ENDM

    ; *******************
    ; DATA DECLARATIONS *
    ; *******************

    ; -------------------------------------
    ; initialised GLOBAL value of any type
    ; -------------------------------------
      GLOBAL MACRO variable:VARARG
      .data
      align 4
        variable
      .code
      ENDM

    ; --------------------------------
    ; initialised GLOBAL string value
    ; --------------------------------
      STRING MACRO variable:REQ,args:VARARG
      .data
        variable db args,0
        align 4
      .code
      ENDM

    ; --------------------------------
    ; initialise floating point vaues
    ; --------------------------------
      FLOAT4 MACRO name,value
        .data
        align 4
          name REAL4 value
        .code
      ENDM

      FLOAT8 MACRO name,value
        .data
        align 4
          name REAL8 value
        .code
      ENDM

      FLOAT10 MACRO name,value
        .data
        align 4
          name REAL10 value
        .code
      ENDM

    ; **********************************************************
    ; function style macros for direct insertion of data types *
    ; **********************************************************

      FP4 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL4 value
        .code
        EXITM <vname>
      ENDM

      FP8 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL8 value
        .code
        EXITM <vname>
      ENDM

      FP10 MACRO value
        LOCAL vname
        .data
        align 4
          vname REAL10 value
        .code
        EXITM <vname>
      ENDM

    ; --------------------------------------------
    ; FLD does not accept immediate operands. These
    ; macros emulate loading an immediate value by
    ; loading the value into the .DATA section.
    ; EXAMPLE : fld8 1234.56789
    ; --------------------------------------------
      fld4 MACRO fpvalue
        LOCAL name
        .data
          name REAL4 fpvalue
          align 4
        .code
        fld name
      ENDM

      fld8 MACRO fpvalue
        LOCAL name
        .data
          name REAL8 fpvalue
          align 4
        .code
        fld name
      ENDM

      fld10 MACRO fpvalue
        LOCAL name
        .data
          name REAL10 fpvalue
          align 4
        .code
        fld name
      ENDM
    ; --------------------------------------------

    ; **********************************************
    ; The original concept for the following macro *
    ; was designed by "huh" from New Zealand.      *
    ; **********************************************

    ; ---------------------
    ; literal string MACRO
    ; ---------------------
      literal MACRO quoted_text:VARARG
        LOCAL local_text
        .data
          local_text db quoted_text,0
        align 4
        .code
        EXITM <local_text>
      ENDM
    ; --------------------------------
    ; string address in INVOKE format
    ; --------------------------------
      SADD MACRO quoted_text:VARARG
        EXITM <ADDR literal(quoted_text)>
      ENDM
    ; --------------------------------
    ; string OFFSET for manual coding
    ; --------------------------------
      CTXT MACRO quoted_text:VARARG
        EXITM <offset literal(quoted_text)>
      ENDM

    ; -----------------------------------------------------
    ; string address embedded directly in the code section
    ; -----------------------------------------------------
      CADD MACRO quoted_text:VARARG
        LOCAL vname,lbl
          jmp lbl
            vname db quoted_text,0
          align 4
          lbl:
        EXITM <ADDR vname>
      ENDM

    ; --------------------------------------------------
    ; Macro for placing an assembler instruction either
    ; within another or within a procedure call
    ; --------------------------------------------------

    ASM MACRO parameter1,source
      LOCAL mnemonic
      LOCAL dest
      LOCAL poz

      % poz INSTR 1,<parameter1>,< >             ;; get the space position
      mnemonic SUBSTR <parameter1>, 1, poz-1     ;; get the mnemonic
      dest SUBSTR <parameter1>, poz+1            ;; get the first argument

      mnemonic dest, source

      EXITM <dest>
    ENDM

    ; ------------------------------------------------------------
    ; Macro for nesting function calls in other invoke statements
    ; ------------------------------------------------------------
      FUNC MACRO parameters:VARARG
        invoke parameters
        EXITM <eax>
      ENDM

    ; -------------------------------------------
    ;             Pseudo mnemonics.
    ; These macros emulate assembler mnemonics
    ; but perform higher level operations not
    ; directly supported by the instruction set
    ; NOTE: The parameter order is the normal
    ; assembler order of,
    ; instruction/destination/source
    ; -------------------------------------------

    ; --------------------------
    ; szstring to szstring copy
    ; --------------------------
      cst MACRO arg1,arg2
        invoke szCopy,reparg(arg2),tstarg(arg1)
      ENDM

    ; ----------------------------
    ; memory to memory assignment
    ; ----------------------------
      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

    ; --------------------------------------------------
    ; memory to memory assignment using the EAX register
    ; --------------------------------------------------
      mrm MACRO m1, m2
        mov eax, m2
        mov m1, eax
      ENDM

    ; *******************************************
    ;             String Assign                 *
    ; Assign quoted text to a locally declared  *
    ; string handle (DWORD variable) in a proc  *
    ; to effectively have a LOCAL scope strings *
    ; EXAMPLE :                                 *
    ; sas MyVar,"This is an assigned string"    *
    ; *******************************************
      sas MACRO var,quoted_text:VARARG
        LOCAL txtname
        .data
          txtname db quoted_text,0
          align 4
        .code
        mov var, OFFSET txtname
      ENDM

    ; -----------------------------------
    ; create a font and return its handle
    ; -----------------------------------
      GetFontHandle MACRO fnam:REQ,fsiz:REQ,fwgt:REQ
        invoke RetFontHandle,reparg(fnam),fsiz,fwgt
        EXITM <eax>
      ENDM

  ; **************
  ; File IO Macros
  ; **************
  ; ---------------------------------------------------------------------
  ; create a new file with read / write access and return the file handle
  ; ---------------------------------------------------------------------
    fcreate MACRO filename
      invoke CreateFile,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM

  ; ------------------
  ; delete a disk file
  ; ------------------
    fdelete MACRO filename
      invoke DeleteFile,reparg(filename)
      EXITM <eax>
    ENDM

  ; ------------------------------
  ; flush open file buffer to disk
  ; ------------------------------
    fflush MACRO hfile
      invoke FlushFileBuffers,hfile
    ENDM

  ; -------------------------------------------------------------------------
  ; open an existing file with read / write access and return the file handle
  ; -------------------------------------------------------------------------
    fopen MACRO filename
      invoke CreateFile,reparg(filename),GENERIC_READ or GENERIC_WRITE,
                        NULL,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
      EXITM <eax>       ;; return file handle
    ENDM

  ; ------------------
  ; close an open file
  ; ------------------
    fclose MACRO arg:REQ
      invoke CloseHandle,arg
    ENDM

  ; ------------------------------------------------
  ; read data from an open file into a memory buffer
  ; ------------------------------------------------
    fread MACRO hFile,buffer,bcnt
      LOCAL var
      .data?
        var dd ?
      .code
      invoke ReadFile,hFile,buffer,bcnt,ADDR var,NULL
      mov eax, var
      EXITM <eax>       ;; return bytes read
    ENDM

  ; ----------------------------------------
  ; write data from a buffer to an open file
  ; ----------------------------------------
    fwrite MACRO hFile,buffer,bcnt
      LOCAL var
      .data?
        var dd ?
      .code
      invoke WriteFile,hFile,buffer,bcnt,ADDR var,NULL
      mov eax, var
      EXITM <eax>       ;; return bytes written
    ENDM

  ; ----------------------------------------------------
  ; write a line of zero terminated text to an open file
  ; ----------------------------------------------------
    fprint MACRO hFile:REQ,text:VARARG  ;; zero terminated text
      LOCAL var
      LOCAL pst
      .data?
        var dd ?
        pst dd ?
      .code
      mov pst, repargv(text)
      invoke WriteFile,hFile,pst,len(pst),ADDR var,NULL
      invoke WriteFile,hFile,chr$(13,10),2,ADDR var,NULL
    ENDM

  ; ---------------------------------
  ; write zero terminated text with C
  ; style formatting to an open file.
  ; ---------------------------------
    fprintc MACRO hFile:REQ,text:VARARG  ;; zero terminated text
      LOCAL var
      LOCAL pst
      .data?
        var dd ?
        pst dd ?
      .code
      mov pst, cfm$(text)
      invoke WriteFile,hFile,pst,len(pst),ADDR var,NULL
    ENDM

  ; ------------------------------------
  ; set the position of the file pointer
  ; ------------------------------------
    fseek MACRO hFile,distance,location
      IFIDN <location>,<BEGIN>
        var equ <FILE_BEGIN>
      ELSEIFIDN <location>,<CURRENT>
        var equ <FILE_CURRENT>
      ELSEIFIDN <location>,<END>
        var equ <FILE_END>
      ELSE
        var equ <location>
      ENDIF
      invoke SetFilePointer,hFile,distance,0,var
      EXITM <eax>               ;; return current file offset
    ENDM

  ; ------------------------------------------------
  ; set end of file at current file pointer location
  ; ------------------------------------------------
    fseteof MACRO hFile
      invoke SetEndOfFile,hFile
    ENDM

  ; -------------------------------
  ; return the size of an open file
  ; -------------------------------
    fsize MACRO hFile
      invoke GetFileSize,hFile,NULL
      EXITM <eax>
    ENDM

  ; ---------------------------------------
  ; extended formatting version writes text
  ; to the current file pointer location
  ; ---------------------------------------
    ftext MACRO hFile:REQ,args:VARARG
      push esi                              ;; preserve ESI
      mov esi, alloc(16384)                 ;; allocate 16k of buffer
      catargs ftext,esi,args                ;; write ALL args to a single string
      push eax                              ;; make 4 bytes on the stack
      invoke WriteFile,hFile,esi,len(esi),esp,NULL
      pop eax                               ;; release the 4 bytes
      free esi                              ;; free the memory buffer
      pop esi                               ;; restore ESI
    ENDM

  ; ----------------------------------------------------------
  ; function position macros that takes a DWORD parameter and
  ; returns the address of the buffer that holds the result.
  ; The return format is for use within the INVOKE syntax.
  ; ----------------------------------------------------------
    str$ MACRO DDvalue
      LOCAL rvstring
      .data
        rvstring db 20 dup (0)
        align 4
      .code
      invoke dwtoa,DDvalue,ADDR rvstring
      EXITM <ADDR rvstring>
    ENDM

    hex$ MACRO DDvalue
      LOCAL rvstring
      .data
        rvstring db 12 dup (0)
        align 4
      .code
      invoke dw2hex,DDvalue,ADDR rvstring
      EXITM <ADDR rvstring>
    ENDM

  ; *************************************************
  ; The following numeric to string conversions were
  ; written by Greg Lyon using the "sprintf" function
  ; in the standard C runtime DLL MSVCRT.DLL
  ; *************************************************

    ubyte$ MACRO ubytevalue:req
        ;; unsigned byte
        LOCAL buffer, ubtmp
        .data?
            ubtmp  BYTE ?
            buffer BYTE 4 dup(?)
        IFNDEF ubfmt    
        .data    
            ubfmt  BYTE "%hhu", 0
        ENDIF    
        .code
            IFE issize(ubytevalue, 1)
                echo ----------------------
                echo ubyte$ - requires BYTE
                echo ----------------------
                .ERR
            ENDIF               
            mov    buffer[0], 0
            IF isregister(ubytevalue)
                mov   ubtmp, ubytevalue
                movzx eax, ubtmp
            ELSE
                mov   al, ubytevalue
                movzx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR ubfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sbyte$ MACRO sbytevalue:req
        ;; signed byte
        LOCAL buffer, sbtmp
        .data?
            sbtmp  SBYTE ?
            buffer BYTE  8 dup(?)
        IFNDEF sbfmt     
        .data    
            sbfmt  BYTE "%hhd", 0
        ENDIF    
        .code
            IFE issize(sbytevalue, 1)
                echo -----------------------
                echo sbyte$ - requires SBYTE
                echo -----------------------
                .ERR
            ENDIF               
            mov    buffer[0], 0
            IF isregister(sbytevalue)
                mov   sbtmp, sbytevalue
                movsx eax, sbtmp
            ELSE     
                mov   al, sbytevalue
                movsx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR sbfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xbyte$ MACRO xbytevalue:req
        ;; unsigned hex byte
        LOCAL buffer, xbtmp
        .data?
            xbtmp  BYTE ?
            buffer BYTE 4 dup(?)
        IFNDEF xbfmt    
        .data    
            xbfmt  BYTE "%hhX", 0
        ENDIF    
        .code
            IFE issize(xbytevalue, 1)
                echo ----------------------
                echo xbyte$ - requires BYTE
                echo ----------------------
                .ERR
            ENDIF                
            mov buffer[0], 0
            IF isregister(xbytevalue)
                mov   xbtmp, xbytevalue
                movzx eax, xbtmp
            ELSE
                mov   al, xbytevalue
                movzx eax, al
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR xbfmt, eax 
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    uword$ MACRO uwordvalue:req
        ;; unsigned word
        LOCAL buffer, uwtmp
        .data?
            uwtmp  WORD ?
            buffer BYTE 8 dup(?)
        IFNDEF uwfmt    
        .data    
            uwfmt  BYTE "%hu", 0
        ENDIF    
        .code
            IFE issize(uwordvalue, 2)
                echo ----------------------
                echo uword$ - requires WORD
                echo ----------------------
                .ERR
            ENDIF            
            mov   buffer[0], 0
            IF isregister(uwordvalue)
                mov   uwtmp, uwordvalue
                movzx eax, uwtmp
            ELSE       
                mov   ax, uwordvalue
                movzx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR uwfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sword$ MACRO swordvalue:req
        ;; signed word
        LOCAL buffer, swtmp
        .data?
            swtmp  SWORD ? 
            buffer BYTE  8 dup(?)
        IFNDEF swfmt    
        .data    
            swfmt  BYTE "%hd", 0
        ENDIF    
        .code
            IFE issize(swordvalue, 2)
                echo -----------------------
                echo sword$ - requires SWORD
                echo -----------------------
                .ERR
            ENDIF            
            mov   buffer[0], 0
            IF isregister(swordvalue)
                mov   swtmp, swordvalue
                movsx eax, swtmp
            ELSE    
                mov   ax, swordvalue
                movsx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR swfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xword$ MACRO xwordvalue:req
        ;; unsigned hex word
        LOCAL buffer, xwtmp
        .data?
            xwtmp  WORD ?
            buffer BYTE 8 dup(?)
        IFNDEF xwfmt    
        .data    
            xwfmt  BYTE "%hX", 0
        ENDIF    
        .code
            IFE issize(xwordvalue, 2)
                echo ----------------------
                echo xword$ - requires WORD
                echo ----------------------
                .ERR
            ENDIF        
            mov   buffer[0], 0
            IF isregister(xwordvalue)
                mov   xwtmp, xwordvalue
                movzx eax, xwtmp
            ELSE               
                mov   ax, xwordvalue
                movzx eax, ax
            ENDIF    
            invoke crt_sprintf, ADDR buffer, ADDR xwfmt, eax
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    udword$ MACRO udwordvalue:req
        ;; unsigned dword
        LOCAL buffer, udtmp
        .data?
            udtmp  DWORD ?
            buffer BYTE  12 dup(?)
        IFNDEF udfmt    
        .data    
            udfmt  BYTE "%lu", 0
        ENDIF    
        .code
            IFE issize(udwordvalue, 4)
                echo ------------------------
                echo udword$ - requires DWORD
                echo ------------------------
                .ERR
            ENDIF    
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR udfmt, udwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sdword$ MACRO sdwordvalue:req
        ;; signed dword
        LOCAL buffer, sdtmp
        .data?
            sdtmp  SDWORD ?
            buffer BYTE   12 dup(?)
        IFNDEF sdfmt    
        .data    
            sdfmt BYTE "%ld", 0
        ENDIF    
        .code
            IFE issize(sdwordvalue, 4)
                echo -------------------------
                echo sdword$ - requires SDWORD
                echo -------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR sdfmt, sdwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xdword$ MACRO xdwordvalue:req
        ;; unsigned hex dword
        LOCAL buffer, xdtmp
        .data?
            xdtmp  DWORD ?
            buffer BYTE  12 dup(?)
        IFNDEF xdfmt    
        .data    
            xdfmt BYTE "%lX", 0
        ENDIF    
        .code
            IFE issize(xdwordvalue, 4)
                echo ------------------------
                echo xdword$ - requires DWORD
                echo ------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR xdfmt, xdwordvalue 
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    uqword$ MACRO uqwordvalue:req
        ;; unsigned qword
        LOCAL buffer
        .data?
            buffer BYTE 24 dup(?)
        IFNDEF uqwfmt    
        .data    
            uqwfmt BYTE "%I64u", 0
        ENDIF    
        .code
            IFE issize(uqwordvalue, 8)
                echo ------------------------
                echo uqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF        
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR uqwfmt, uqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    sqword$ MACRO sqwordvalue:req
        ;; signed qword
        LOCAL buffer
        .data?
            buffer BYTE 24 dup(?)
        IFNDEF sqwfmt    
        .data    
            sqwfmt BYTE "%I64d", 0
        ENDIF    
        .code
            IFE issize(sqwordvalue, 8)
                echo ------------------------
                echo sqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR sqwfmt, sqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    xqword$ MACRO xqwordvalue:req
        ;; unsigned hex qword
        LOCAL buffer
        .data?
            buffer BYTE 20 dup(?)
        IFNDEF xqwfmt    
        .data    
            xqwfmt BYTE "%I64X", 0
        ENDIF    
        .code
            IFE issize(xqwordvalue, 8)
                echo ------------------------
                echo xqword$ - requires QWORD
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR xqwfmt, xqwordvalue
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real4$ MACRO r4value:req
        LOCAL buffer, r8value, r4tmp
        .data?
            r4tmp   REAL4 ?
            r8value REAL8 ?
            buffer  BYTE  48 dup(?)
        IFNDEF r8fmt    
        .data
            r8fmt   BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r4value, 4)
                echo ------------------------
                echo real4$ - requires REAL4
                echo ------------------------
                .ERR
            ENDIF            
            IF isregister(r4value)
                push   r4value
                pop    r4tmp
                finit
                fld    r4tmp
            ELSE
                finit
                fld    r4value
            ENDIF    
            fstp   r8value
            fwait
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real8$ MACRO r8value:req
        LOCAL buffer
        .data?
            buffer BYTE 320 dup(?)
        IFNDEF r8fmt    
        .data    
            r8fmt  BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r8value, 8)
                echo ------------------------
                echo real8$ - requires REAL8
                echo ------------------------
                .ERR
            ENDIF            
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM
    
    ; ----------------------------------------------
    
    real10$ MACRO r10value:req
        LOCAL buffer, r8value
        .data?
            r8value REAL8 ?
            buffer  BYTE  320 dup(?)
        IFNDEF r8fmt    
        .data    
            r8fmt   BYTE "%lf", 0
        ENDIF    
        .code
            IFE issize(r10value, 10)
                echo -------------------------
                echo real10$ - requires REAL10
                echo -------------------------
                .ERR
            ENDIF        
            fld    r10value
            fstp   r8value
            fwait
            mov    buffer[0], 0
            invoke crt_sprintf, ADDR buffer, ADDR r8fmt, r8value
            EXITM <OFFSET buffer>
    ENDM

  ; ------------------------
  ; sscanf conversion macros
  ; ------------------------
    a2ub MACRO pStr:req
        LOCAL ub
        .data 
           ub BYTE 0    
        IFNDEF ubfmt   
        .const
            ubfmt BYTE "%hhu",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR ubfmt, ADDR ub
        EXITM <OFFSET ub>
    ENDM  
    ;---------------------------------------
    a2sb MACRO pStr:req
        LOCAL sb
        .data 
           sb SBYTE 0    
        IFNDEF sbfmt   
        .const
            sbfmt BYTE "%hhd",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR sbfmt, ADDR sb
        EXITM <OFFSET sb>
    ENDM  
    ;---------------------------------------
    h2ub MACRO pStr:req
        LOCAL ub
        .data 
           ub BYTE 0    
        IFNDEF xbfmt   
        .const
            xbfmt BYTE "%hhX",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR xbfmt, ADDR ub
        EXITM <OFFSET ub>
    ENDM  
    ;---------------------------------------
    a2uw MACRO pStr:req
        LOCAL uw
        .data 
           uw WORD 0    
        IFNDEF uwfmt   
        .const
            uwfmt BYTE "%hu",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR uwfmt, ADDR uw
        EXITM <OFFSET uw>
    ENDM   
    ;---------------------------------------
    a2sw MACRO pStr:req
        LOCAL sw
        .data 
           sw SWORD 0    
        IFNDEF swfmt   
        .const
            swfmt BYTE "%hd",0
        ENDIF  
        .code
        invoke crt_sscanf, pStr, ADDR swfmt, ADDR sw
        EXITM <OFFSET sw>
    ENDM   
    ;---------------------------------------
    h2uw MACRO pStr:req
        LOCAL uw
        .data 
           uw WORD 0    
        IFNDEF xwfmt   
        .const
            xwfmt BYTE "%hX",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR xwfmt, ADDR uw
        EXITM <OFFSET uw>
    ENDM   
    ;---------------------------------------
    a2ud MACRO pStr:req
        LOCAL ud
        .data 
            ud DWORD 0    
        IFNDEF udfmt   
        .const
            udfmt BYTE "%u",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR udfmt, ADDR ud
        EXITM <OFFSET ud>
    ENDM   
    ;---------------------------------------
    a2sd MACRO pStr:req
        LOCAL sd
        .data 
           sd SDWORD 0    
        IFNDEF sdfmt   
        .const
            sdfmt BYTE "%d",0
        ENDIF    
        .code
        invoke crt_sscanf, pStr, ADDR sdfmt, ADDR sd
        EXITM <OFFSET sd>
    ENDM   
    ;---------------------------------------
    h2ud MACRO pStr:req
        LOCAL ud
        .data 
            ud DWORD 0    
        IFNDEF xdfmt   
        .const
            xdfmt BYTE "%X",0
        ENDIF 
        .code
        invoke crt_sscanf, pStr, ADDR xdfmt, ADDR ud
        EXITM <OFFSET ud>    
    ENDM   
    ;---------------------------------------
    a2uq MACRO pStr:req
        LOCAL uq
        .data 
           align 8
           uq QWORD 0    
        IFNDEF uqfmt   
        .const
            uqfmt BYTE "%I64u",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR uqfmt, ADDR uq
        EXITM <OFFSET uq>
    ENDM   
    ;---------------------------------------
    a2sq MACRO pStr:req
        LOCAL sq
        .data 
           align 8
           sq QWORD ?    
        IFNDEF sqfmt   
        .const
            sqfmt BYTE "%I64d",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR sqfmt, ADDR sq
        EXITM <OFFSET sq>
    ENDM   
    ;-------------------------------------------
    h2uq MACRO pStr:req
        LOCAL uq
        .data 
           align 8
           uq QWORD 0    
        IFNDEF xqfmt   
        .const
            xqfmt BYTE "%I64X",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR xqfmt, ADDR uq
        EXITM <OFFSET uq>
    ENDM   
    ;---------------------------------------
    a2r4 MACRO pStr:req
        LOCAL r4
        .data
          r4 REAL4 0.0
        IFNDEF r4fmt   
        .const
            r4fmt BYTE "%f",0
        ENDIF   
        .code
        invoke crt_sscanf, pStr, ADDR r4fmt, ADDR r4 
        EXITM <OFFSET r4>
    ENDM   
    ;-------------------------------------------
    a2r8 MACRO pStr:req
        LOCAL r8
        .data
          align 8
          r8 REAL8 0.0
        IFNDEF r8fmt   
        .const
            r8fmt BYTE "%lf",0
        ENDIF
        .code
        invoke crt_sscanf, pStr, ADDR r8fmt, ADDR r8 
        EXITM <OFFSET r8>
    ENDM   
    ;--------------------------------------------
    a2r10 MACRO pStr:req
        LOCAL r8, r10
        .data
           align 16
           r10 REAL10 0.0
           r8  REAL8  0.0
        IFNDEF r8fmt   
        .data
            r8fmt BYTE "%lf",0
        ENDIF    
        .code
        invoke crt_sscanf, pStr, ADDR r8fmt, ADDR r8
        finit
        fld r8
        fstp r10
        EXITM <OFFSET r10>
    ENDM
    ;--------------------------------------------


    ; ******************************************************
    ; BASIC style conversions from string to 32 bit integer
    ; ******************************************************
      sval MACRO lpstring       ; string to signed 32 bit integer
        invoke atol, reparg(lpstring)
        EXITM <eax>
      ENDM

      uval MACRO lpstring       ; string to unsigned 32 bit integer
        invoke atodw, reparg(lpstring)
        EXITM <eax>
      ENDM

      val equ <uval>

      hval MACRO lpstring       ; hex string to unsigned 32 bit integer
        invoke htodw, reparg(lpstring)
        EXITM <eax>
      ENDM

    ; ********************************
    ; BASIC string function emulation
    ; ********************************
      add$ MACRO lpSource,lpAppend
        invoke szCatStr,tstarg(lpSource),reparg(lpAppend)
        EXITM <eax>
      ENDM

      append$ MACRO string,buffer,location
        invoke szappend,reparg(string),buffer,location
        EXITM <eax>
      ENDM

      chr$ MACRO any_text:VARARG
        LOCAL txtname
        .data
          txtname db any_text,0
        .code
        EXITM <OFFSET txtname>
      ENDM

      ptr$ MACRO buffer
        lea eax, buffer
        mov WORD PTR [eax], 0
        EXITM <eax>
      ENDM

      len MACRO lpString
        invoke szLen,reparg(lpString)
        EXITM <eax>
      ENDM

      istring MACRO spos,lpMainString,lpSubString
        invoke InString,spos,reparg(lpMainString),reparg(lpSubString)
        EXITM <eax>
      ENDM

      ucase$ MACRO lpString
        invoke szUpper,reparg(lpString)
        EXITM <eax>
      ENDM

      lcase$ MACRO lpString
        invoke szLower,reparg(lpString)
        EXITM <eax>
      ENDM

      left$ MACRO lpString,slen
        invoke szLeft,reparg(lpString),reparg(lpString),slen
        EXITM <eax>
      ENDM

      right$ MACRO lpString,slen
        invoke szRight,reparg(lpString),reparg(lpString),slen
        EXITM <eax>
      ENDM

      rev$ MACRO lpString
        invoke szRev,reparg(lpString),reparg(lpString)
        EXITM <eax>
      ENDM

      ltrim$ MACRO lpString
        invoke szLtrim,reparg(lpString),reparg(lpString)
        mov eax, ecx
        EXITM <eax>
      ENDM

      rtrim$ MACRO lpString
        invoke szRtrim,reparg(lpString),reparg(lpString)
        mov eax, ecx
        EXITM <eax>
      ENDM

      trim$ MACRO lpString
        invoke szTrim,reparg(lpString)
        mov eax, ecx
        EXITM <eax>
      ENDM

      remove$ MACRO src,substr
        invoke szRemove,reparg(src),reparg(src),reparg(substr)
        EXITM <eax>
      ENDM

      ustr$ MACRO DDvalue   ;; unsigned integer from string
        LOCAL rvstring
        .data
          rvstring db 20 dup (0)
        align 4
        .code
        ;; invoke dwtoa,DDvalue,ADDR rvstring
        invoke crt__ultoa,DDvalue,ADDR rvstring,10
        EXITM <OFFSET rvstring>
      ENDM

      sstr$ MACRO DDvalue   ;; signed integer from string
        LOCAL rvstring
        .data
          rvstring db 20 dup (0)
        align 4
        .code
        invoke dwtoa,DDvalue,ADDR rvstring
        ;; invoke ltoa,DDvalue,ADDR rvstring
        EXITM <OFFSET rvstring>
      ENDM

      uhex$ MACRO DDvalue   ;; unsigned DWORD to hex string
        LOCAL rvstring
        .data
          rvstring db 12 dup (0)
        align 4
        .code
        invoke dw2hex,DDvalue,ADDR rvstring
        EXITM <OFFSET rvstring>
      ENDM

comment * -------------------------------------------------------
        Each of the following macros has its own dedicated 260
        BYTE buffer. The OFFSET returned by each macro can be
        used directly in code but if the macro is called again
        the data in the dedicated buffer will be overwritten
        with the new result.

        mov str1, ptr$(buffer)
        mov str2, pth$()
        invoke szCopy str2,str1

        Empty brackets should be used with these macros as they
        take no parameters. pth$() CurDir$() etc ...
        ------------------------------------------------------- *

      pth$ MACRO            ;; application path OFFSET returned
        IFNDEF pth__equate__flag
        .data?
          pth__260_BYTE__buffer db MAX_PATH dup (?)
        .code
        pth__equate__flag equ <1>
        ENDIF
        invoke GetAppPath,ADDR pth__260_BYTE__buffer
        EXITM <eax>
      ENDM

      CurDir$ MACRO
        IFNDEF cdir__equate__flag
        .data?
          cdir__260_BYTE__buffer db MAX_PATH dup (?)
        .code
        cdir__equate__flag equ <1>
        ENDIF
        invoke GetCurrentDirectory,MAX_PATH,ADDR cdir__260_BYTE__buffer
        mov eax, OFFSET cdir__260_BYTE__buffer
        EXITM <eax>
      ENDM

      SysDir$ MACRO
        IFNDEF sys__equate__flag
        .data?
          sysdir__260_BYTE__buffer db MAX_PATH dup (?)
        .code
        sys__equate__flag equ <1>
        ENDIF
        invoke GetSystemDirectory,ADDR sysdir__260_BYTE__buffer,MAX_PATH
        mov eax, OFFSET sysdir__260_BYTE__buffer
        EXITM <eax>
      ENDM

      WinDir$ MACRO
        IFNDEF wdir__equate__flag
        .data?
          windir__260_BYTE__buffer db MAX_PATH dup (?)
        .code
        wdir__equate__flag equ <1>
        ENDIF
        invoke GetWindowsDirectory,ADDR windir__260_BYTE__buffer,MAX_PATH
        mov eax, OFFSET windir__260_BYTE__buffer
        EXITM <eax>
      ENDM

    ; ---------------------------------------------------------------
    ; Get command line arg specified by "argnum" starting at arg 1
    ; Test the return values with the following to determine results
    ; 1 = successful operation
    ; 2 = no argument exists at specified arg number
    ; 3 = non matching quotation marks
    ; 4 = empty quotation marks
    ; test the return value in ECX
    ; ---------------------------------------------------------------
      cmd$ MACRO argnum
        LOCAL argbuffer
        IFNDEF cmdflag
        .data?
          argbuffer db MAX_PATH dup (?)
        .code
        cmdflag equ 1
        ENDIF
        invoke GetCL,argnum, ADDR argbuffer
        mov ecx, eax
        mov eax, OFFSET argbuffer
        EXITM <eax>
      ENDM

  ; ******************************************
  ; DOS style directory manipulation macros  *
  ; The parameters passed to these directory *
  ; macros should be zero terminated string  *
  ; addresses.                               *
  ; ******************************************
      chdir MACRO pathname
        invoke SetCurrentDirectory,reparg(pathname)
      ENDM
      CHDIR equ <chdir>

      mkdir MACRO dirname
        invoke CreateDirectory,reparg(dirname),NULL
      ENDM
      MKDIR equ <mkdir>

      rndir MACRO oldname,newname
        invoke MoveFile,reparg(oldname),reparg(newname)
      ENDM
      RNDIR equ <rndir>

      rmdir MACRO dirname
        invoke RemoveDirectory,reparg(dirname)
      ENDM
      RMDIR equ <rmdir>

    ; **************************
    ; memory allocation macros *
    ; **************************

    comment * --------------------------------------------------    
            Two macros for allocating and freeing OLE memory.
            stralloc returns the handle/address of the string
            memory in eax. alloc$ acts in the same way but is
            used in the function position. strfree uses the
            handle to free memory after use.
    
            NOTE that you must use the following INCLUDE &
            LIB files with these two macros.
    
            include \MASM32\include\oleaut32.inc
            includelib \MASM32\LIB\oleaut32.lib
            -------------------------------------------------- *

      alloc$ MACRO ln
        invoke SysAllocStringByteLen,0,ln
        mov BYTE PTR [eax], 0
        EXITM <eax>
      ENDM

      free$ MACRO strhandle
        invoke SysFreeString,strhandle
      ENDM

      stralloc MACRO ln
        invoke SysAllocStringByteLen,0,ln
      ENDM

      strfree MACRO strhandle
        invoke SysFreeString,strhandle
      ENDM

comment * ------------------------------------------------
    The following 2 macros are for general purpose memory
    allocation where fine granularity in memory is required
    or where the memory attribute "execute" is useful.
    ------------------------------------------------------ *

      alloc MACRO bytecount
        invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,bytecount
        EXITM <eax>
      ENDM

      free MACRO hmemory
        invoke GlobalFree,hmemory
      ENDM

comment * ---------------------------------------------------------
        Heap allocation and deallocation macros. On later versions
        of Windows HeapAlloc() appears to be faster on small
        allocations than GlobalAlloc() using the GMEM_FIXED flag.
        --------------------------------------------------------- *

      halloc MACRO bytecount
        EXITM <rv(HeapAlloc,rv(GetProcessHeap),0,bytecount)>
      ENDM

      hsize MACRO hmem
        invoke HeapSize,rv(GetProcessHeap),0,hmem
        EXITM <eax>
      ENDM

      hfree MACRO memory
        invoke HeapFree,rv(GetProcessHeap),0,memory
      ENDM

    ; ************************************************************
    ;                       File IO macros                       *
    ; NOTE: With the address returned by InputFile that contains *
    ; the data in the file, it must be deallocated using the API *
    ; function GlobalFree().                                     *
    ; EXAMPLE: invoke GlobalFree,pMem                            *
    ; ************************************************************

      InputFile MACRO lpFile
      ;; ----------------------------------------------------------
      ;; The untidy data? names are to avoid duplication in normal
      ;; code. The two values are reused by each call to the macro
      ;; ----------------------------------------------------------
        IFNDEF ipf@@flag            ;; if the flag is not defined
          .data?
            ipf@__@mem@__@Ptr dd ?  ;; write 2 DWORD variables to
            ipf@__file__@len dd ?   ;; the uninitialised data section
          .code
          ipf@@flag equ <1>         ;; define the flag
        ENDIF
        invoke read_disk_file,reparg(lpFile),
               ADDR ipf@__@mem@__@Ptr,
               ADDR ipf@__file__@len
        mov ecx, ipf@__file__@len   ;; file length returned in ECX
        mov eax, ipf@__@mem@__@Ptr  ;; address of memory returned in EAX
        EXITM <eax>
      ENDM

      OutputFile MACRO lpFile,lpMem,lof
        invoke write_disk_file,reparg(lpFile),lpMem,lof
        EXITM <eax>
      ENDM

    ; -----------------------------------------
    ; common dialog file open and close macros.
    ; Return value in both is the OFFSET of a
    ; 260 byte dedicated buffer in the .DATA?
    ; section in EAX.
    ; -----------------------------------------
      OpenFileDlg MACRO hWin,hInstance,lpTitle,lpPattern
        invoke OpenFileDialog,hWin,hInstance,reparg(lpTitle),reparg(lpPattern)
        EXITM <eax>
      ENDM

      SaveFileDlg MACRO hWin,hInstance,lpTitle,lpPattern
        invoke SaveFileDialog,hWin,hInstance,reparg(lpTitle),reparg(lpPattern)
        EXITM <eax>
      ENDM

    ; ----------------------------------------------------------
    ; load a library and get the procedure address in one macro
    ; return value for the proc address in in EAX. Both DLL and
    ; procedure name are enclosed in quotation marks.
    ;
    ; EXAMPLE : LoadProcAddress "mydll.dll","myproc"
    ;           proc address in EAX
    ;           library handle in ECX
    ;
    ; EXAMPLE : mov lpProc, GetDllProc("mydll.dll","myproc")
    ;           library handle in ECX
    ; ----------------------------------------------------------

      LoadProcAddress MACRO libname_text1,procname_text2
        LOCAL library_name
        LOCAL proc_name
          .data
            library_name db libname_text1,0
            proc_name db procname_text2,0
          align 4
          .code
        invoke LoadLibrary,ADDR library_name
        mov ecx, eax
        invoke GetProcAddress,eax,ADDR proc_name
      ENDM

      GetDllProc MACRO libname_text1,procname_text2
        LOCAL library_name
        LOCAL proc_name
          .data
            library_name db libname_text1,0
            proc_name db procname_text2,0
          align 4
          .code
        invoke LoadLibrary,ADDR library_name
        mov ecx, eax
        invoke GetProcAddress,eax,ADDR proc_name
        EXITM <eax>
      ENDM

    ; **********************************
    ; control flow macro by Greg Falen *
    ; **********************************

    ; ----------------------
    ; Switch/Case emulation
    ; ----------------------
    $casflg equ <>
    $casvar equ <>
    $casstk equ <>
    
    switch macro _var:req, _reg:=<eax>
        mov _reg, _var
        $casstk catstr <_reg>, <#>, $casflg, <#>, $casstk
        $casvar equ _reg
        $casflg equ <0>         ;; 0 = emit an .if, 1 an .elseif
    endm
    
    case macro _args:vararg     ;; like Pascal: case id1. id4 .. id8, lparam, ...
                                ;; does an or (case1 || case2 || case3...)
      $cas textequ <>
      irp $v, <_args>         ;; for each case
          t@ instr <$v>, <..> ;; range ?
          if t@               ;; yes
              $LB substr <$v>, 1, t@-1                  ;; lbound = left portion
              $LB catstr <(>, $casvar, <!>=>, $LB, <)>  ;; ($casvar >= lbound)
              $UB substr <$v>, t@+2                     ;; ubound = right portion
              $UB catstr <(>, $casvar, <!<=>, $UB, <)>  ;; ($casvar <= ubound)
              $t catstr <(>, $LB, <&&> , $UB,<)>        ;; (($casvar >= $lb) && ($casvar <= $ub))
          else    ;; no, it's a value (var/const)
              $t catstr <(>, $casvar, <==>, <$v>, <)>   ;; ($casvar == value)
          endif
          $cas catstr <|| >, $t, $cas                   ;; or this case w/ others
      endm
      $cas substr $cas, 3 ;; lose the extra "|| " in front
        ifidn $casflg, <0> ;; 0 = 1'st case
            % .if $cas ;; emit ".if"
        else ;; all others
            % .elseif $cas ;; emit ".elseif"
        endif
        $casflg equ <1> ;; NOT 1'st
    endm
    
    default macro _default:vararg
        .else
        _default
    endm
    
    endsw macro _cmd:vararg
        ifidn $casstk, <>
            .err <Endsw w/o Switch>
        else
            t@ instr $casstk, <#>
            $casvar substr $casstk, 1, t@-1
            $casstk substr $casstk, t@+1
            t@ instr $casstk, <#>
            $casflg substr $casstk, 1, t@-1
            ifidn $casstk, <#>
                $casstk equ <>
            else
                $casstk substr $casstk, t@+1
            endif
            .endif
        endif
    endm

  ; --------------------------------------------------
  ; equates for name and case variation in macro names
  ; --------------------------------------------------
    Case equ <case>
    CASE equ <case>
    Switch equ <switch>
    SWITCH equ <switch>

    Endsw equ <endsw>
    EndSw equ <endsw>
    ENDSW equ <endsw>

    Select equ <switch>
    ;; select equ <switch>
    SELECT equ <switch>

    Endsel equ <endsw>
    endsel equ <endsw>
    ENDSEL equ <endsw>

    Default equ <default>
    DEFAULT equ <default>

    CaseElse equ <default>
    Caseelse equ <default>
    CASEELSE equ <default>
    caseelse equ <default>

comment * ------------------------------------------------
        The following macro system for a string comparison
        switch block was designed by Michael Webster.
        --------------------------------------------------
SYNTAX:

    switch$ string_address          ; adress of zero terminated string

      case$ "quoted text"           ; first string to test against
        ; your code here

      case$ "another quoted text"   ; optional additional quoted text
        ; your code here

      else$                         ; optional default processing
        ; default code here

    endsw$

        ------------------------------------------------ *

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; Macros for storing and retrieving text macros, based on
; the $casstk code from Greg Falen's Switch/Case macros.
; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    $text_stack$ equ <#>

    pushtext MACRO name:req
        $text_stack$ CATSTR <name>, <#>, $text_stack$
    ENDM

    poptext MACRO name:req
        LOCAL pos
        pos INSTR $text_stack$, <#>
        name SUBSTR $text_stack$, 1, pos-1
        $text_stack$ SUBSTR $text_stack$, pos+1
    ENDM

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; Macros to implement a string-comparison specific
; Switch/Case construct. Multiple instances and
; nesting supported.
; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    $test_val$ equ <>
    $end_sw$ equ <>
    $sw_state$ equ <>
    _sw_cnt_ = 0

    switch$ MACRO lpstring:REQ
        pushtext $test_val$                 ;; Preserve globals for previous Switch/Case.
        pushtext $sw_state$
        pushtext $end_sw$

        $test_val$ equ <lpstring>           ;; Copy string address for this Select/Case
                                            ;; to global so case$ can access it.             
        $sw_state$ equ <>                   ;; Set state global to starting value.
        _sw_cnt_ = _sw_cnt_ + 1             ;; Generate a unique exit label for this
        $end_sw$ CATSTR <end_sw>, %_sw_cnt_ ;; Select/Case and preserve it.
        pushtext $end_sw$
    ENDM

    case$ MACRO quoted_text:REQ
        ;; The case statements will be any statements between the case$ and the following case$,
        ;; else$, or endsw$.
        ;;
        ;; If this is a following case$, emit a jump to the exit label for this Select/Case and
        ;; terminate the .IF block.
        ;; --------------------------------
        IFIDN $sw_state$, <if>
          poptext $end_sw$                  ;; Because there could have been an intervening
          pushtext $end_sw$                 ;; Switch/Case we need to recover the correct
          jmp   $end_sw$                    ;; exit label for this Switch/Case.
          .ENDIF
        ENDIF
        ;; --------------------------------
        ;; Start a new .IF block and update the state global.
        .IF FUNC(szCmp, $test_val$, chr$(quoted_text)) != 0
        $sw_state$ equ <if>
    ENDM

    else$ MACRO
        IFIDN $sw_state$, <if>              ;; If following a case$, emit a jump to the exit
          poptext $end_sw$                  ;; label for this Select/Case and terminate the .IF
          pushtext $end_sw$                 ;; block. The jump is necessary, whenever the case
          jmp   $end_sw$                    ;; for the .IF block being terminated is true, to
          .ENDIF                            ;; bypass the else statements that follow.
          $sw_state$ equ <>                 ;; The state global must be updated to stop the
        ENDIF                               ;; endsw$ from terminatinmg the .IF block.
    ENDM

    endsw$ MACRO
        IFIDN $sw_state$, <if>              ;; If following a case$, terminate the .IF block.
          .ENDIF
        ENDIF

        poptext $end_sw$                    ;; Remove the exit label from the stack.

      $end_sw$:

        poptext $end_sw$                    ;; Recover gobals for previous Switch/Case.
        poptext $sw_state$
        poptext $test_val$
    ENDM

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

comment * ----------------------------------------------------
        The following macro system for a string comparison
        switch block was designed by Michael Webster. It has
        been slightly modified for case INSENSITIVE comparison.
        ----------------------------------------------------- *

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; Macros for storing and retrieving text macros, based on
; the $casstk code from Greg Falen's Switch/Case macros.
; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    $text_stacki$ equ <#>

    pushtexti MACRO name:req
        $text_stacki$ CATSTR <name>, <#>, $text_stacki$
    ENDM

    poptexti MACRO name:req
        LOCAL pos
        pos INSTR $text_stacki$, <#>
        name SUBSTR $text_stacki$, 1, pos-1
        $text_stacki$ SUBSTR $text_stacki$, pos+1
    ENDM

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; Macros to implement a string-comparison specific
; Switch/Case construct. Multiple instances and
; nesting supported.
; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    $test_vali$ equ <>
    $end_swi$ equ <>
    $sw_statei$ equ <>
    _sw_cnti_ = 0

    switchi$ MACRO lpstring:REQ
        pushtexti $test_vali$                ;; Preserve globals for previous Switch/Case.
        pushtexti $sw_statei$
        pushtexti $end_swi$

        $test_vali$ equ <lpstring>           ;; Copy string address for this Select/Case
                                             ;; to global so case$ can access it.             
        $sw_statei$ equ <>                   ;; Set state global to starting value.
        _sw_cnti_ = _sw_cnti_ + 1            ;; Generate a unique exit label for this
        $end_swi$ CATSTR <end_sw>, %_sw_cnt_ ;; Select/Case and preserve it.
        pushtexti $end_swi$
    ENDM

    casei$ MACRO quoted_text:REQ
        ;; The case statements will be any statements between the case$ and the following case$,
        ;; else$, or endsw$.
        ;;
        ;; If this is a following case$, emit a jump to the exit label for this Select/Case and
        ;; terminate the .IF block.
        ;; --------------------------------
        IFIDN $sw_statei$, <if>
          poptexti $end_swi$                 ;; Because there could have been an intervening
          pushtexti $end_swi$                ;; Switch/Case we need to recover the correct
          jmp   $end_swi$                    ;; exit label for this Switch/Case.
          .ENDIF
        ENDIF
        ;; --------------------------------
        ;; Start a new .IF block and update the state global.

        ;; *******************************************
        .if rv(Cmpi,$test_vali$,chr$(quoted_text)) == 0
        ;; *******************************************

        $sw_statei$ equ <if>
    ENDM

    elsei$ MACRO
        IFIDN $sw_statei$, <if>              ;; If following a case$, emit a jump to the exit
          poptexti $end_swi$                 ;; label for this Select/Case and terminate the .IF
          pushtexti $end_swi$                ;; block. The jump is necessary, whenever the case
          jmp   $end_swi$                    ;; for the .IF block being terminated is true, to
          .ENDIF                             ;; bypass the else statements that follow.
          $sw_statei$ equ <>                 ;; The state global must be updated to stop the
        ENDIF                                ;; endsw$ from terminatinmg the .IF block.
    ENDM

    endswi$ MACRO
        IFIDN $sw_statei$, <if>              ;; If following a case$, terminate the .IF block.
          .ENDIF
        ENDIF

        poptexti $end_swi$                   ;; Remove the exit label from the stack.

      $end_swi$:

        poptexti $end_swi$                   ;; Recover gobals for previous Switch/Case.
        poptexti $sw_statei$
        poptexti $test_vali$
    ENDM

; лллллллллллллллллллллллллллллллллллллллллллллллллллллллллл


    ; -------------------------------------------------------------------
    ; The following 2 macros are for limiting the size of a window while
    ; it is being resized. They are to be used in the WM_SIZING message.
    ; -------------------------------------------------------------------
    LimitWindowWidth MACRO wdth
        LOCAL label
        mov eax, lParam
        mov ecx, (RECT PTR [eax]).right
        sub ecx, (RECT PTR [eax]).left
        cmp ecx, wdth
        jg label
      .if wParam == WMSZ_RIGHT || wParam == WMSZ_BOTTOMRIGHT || wParam == WMSZ_TOPRIGHT
        mov ecx, (RECT PTR [eax]).left
        add ecx, wdth
        mov (RECT PTR [eax]).right, ecx
      .elseif wParam == WMSZ_LEFT || wParam == WMSZ_BOTTOMLEFT || wParam == WMSZ_TOPLEFT
        mov ecx, (RECT PTR [eax]).right
        sub ecx, wdth
        mov (RECT PTR [eax]).left, ecx
      .endif
      label:
    ENDM

    LimitWindowHeight MACRO whgt
        LOCAL label
        mov eax, lParam
        mov ecx, (RECT PTR [eax]).bottom
        sub ecx, (RECT PTR [eax]).top
        cmp ecx, whgt
        jg label
      .if wParam == WMSZ_TOP || wParam == WMSZ_TOPLEFT || wParam == WMSZ_TOPRIGHT
        mov ecx, (RECT PTR [eax]).bottom
        sub ecx, whgt
        mov (RECT PTR [eax]).top, ecx
      .elseif wParam == WMSZ_BOTTOM || wParam == WMSZ_BOTTOMLEFT || wParam == WMSZ_BOTTOMRIGHT
        mov ecx, (RECT PTR [eax]).top
        add ecx, whgt
        mov (RECT PTR [eax]).bottom, ecx
      .endif
      label:
    ENDM

    MsgBox MACRO hndl,txtmsg,titlemsg,styl
      invoke MessageBox,hndl,reparg(txtmsg),reparg(titlemsg),styl
    ENDM

  ; ------------------------------------------------------
  ; macro for concantenating strings using the szMultiCat
  ; procedure written by Alexander Yackubtchik.
  ;
  ; USAGE strcat buffer,str1,str2,str3 etc ...
  ; 
  ; buffer must be large enough to contain all of the
  ; strings to append. Limit is set by maximum line
  ; length in MASM.
  ; ------------------------------------------------------
    strcat MACRO arguments:VARARG
    LOCAL txt
    LOCAL pcount
        txt equ <invoke szMultiCat,>        ;; lead string
        pcount = 0
          FOR arg, <arguments>
            pcount = pcount + 1             ;; count arguments
          ENDM
        % pcount = pcount - 1               ;; dec 1 for 1st arg
        txt CATSTR txt,%pcount              ;; append number to lead string
          FOR arg, <arguments>
            txt CATSTR txt,<,>,reparg(arg)
          ENDM
        txt                                 ;; put result in code
    ENDM

  ; ----------------------------------------------
  ; this version is used in the function position
  ; ----------------------------------------------
    cat$ MACRO arguments:VARARG
      LOCAL txt
      LOCAL spare
      LOCAL pcount
        spare equ <>
          FOR arg, <arguments>
            spare CATSTR spare,tstarg(arg)  ;; test if 1st arg is quoted text
            EXITM                           ;; and produce error if it is
          ENDM
        txt equ <invoke szMultiCat,>        ;; lead string
        pcount = 0
          FOR arg, <arguments>
            pcount = pcount + 1             ;; count arguments
          ENDM
        % pcount = pcount - 1               ;; dec 1 for 1st arg
        txt CATSTR txt,%pcount              ;; append number to lead string
          FOR arg, <arguments>
            txt CATSTR txt,<,>,reparg(arg)
          ENDM
        txt                                 ;; put result in code
      EXITM <eax>
    ENDM

    ; ************************************
    ; console mode text input and output *
    ; ************************************

    cls MACRO                       ;; clear screen
      invoke ClearScreen
    ENDM

    print MACRO arg1:REQ,varname:VARARG      ;; display zero terminated string
        invoke StdOut,reparg(arg1)
      IFNB <varname>
        invoke StdOut,chr$(varname)
      ENDIF
    ENDM

    ccout MACRO text:VARARG
      invoke StdOut,cfm$(text)
    ENDM

comment * -----------------------------------------
        Extended version of "print" with additional
        character notation support.
        
          n = newline
          t = tab
          q = quote
          lb = (
          rb = )
          la = <
          ra = >

        ----------------------------------------- *

    cprint MACRO args:VARARG
      push esi
      mov esi, alloc(16384)
      catargs cprint,esi,args
      invoke StdOut,esi
      free esi
      pop esi
    ENDM

    write MACRO quoted_text:VARARG  ;; display quoted text
      LOCAL txt
      .data
        txt db quoted_text,0
        align 4
      .code
      invoke StdOut,ADDR txt
    ENDM

    loc MACRO xc,yc                 ;; set cursor position
      invoke locate,xc,yc
    ENDM

comment * -------------------------------------

    use the "input" macro as follows,

    If you want a prompt use this version
    mov lpstring, input("Type text here : ")

    If you don't need a prompt use the following
    mov lpstring, input()

    NOTE : The "lpstring" is a preallocated
           DWORD variable that is either LOCAL
           or declared in the .DATA or .DATA?
           section. Any legal name is OK.

    LIMITATION : MASM uses < > internally in its
    macros so if you wish to use these symbols
    in a prompt, you must use the ascii value
    and not use the symbol literally.

    EXAMPLE mov var, input("Enter number here ",62," ")

    ------------------------------------------- *

    input MACRO prompt:VARARG
        LOCAL txt
        LOCAL buffer
      IFNB <prompt>
        .data
          txt db prompt, 0
          buffer db 128 dup (0)
          align 4
        .code
        invoke StdOut,ADDR txt
        invoke StdIn,ADDR buffer,LENGTHOF buffer
        invoke StripLF,ADDR buffer
        mov eax, offset buffer
        EXITM <eax>
      ELSE
        .data
          buffer db 128 dup (0)
          align 4
        .code
        invoke StdIn,ADDR buffer,LENGTHOF buffer
        invoke StripLF,ADDR buffer
        mov eax, offset buffer
        EXITM <eax>
      ENDIF
    ENDM

  ; --------------------------------------------------------
  ; exit macro with an optional return value for ExitProcess
  ; --------------------------------------------------------
    exit MACRO optional_return_value
      IFNDEF optional_return_value
        invoke ExitProcess, 0
      ELSE
        invoke ExitProcess,optional_return_value
      ENDIF
    ENDM

    ;; ------------------------------------------------------
    ;; display user defined text, default text or none if
    ;; NULL is specified and wait for a keystroke to continue
    ;; ------------------------------------------------------
    inkey MACRO user_text:VARARG
      IFDIF <user_text>,<NULL>                  ;; if user text not "NULL"
        IFNB <user_text>                        ;; if user text not blank
          print user_text                       ;; print user defined text
        ELSE                                    ;; else
          print "Press any key to continue ..." ;; print default text
        ENDIF
      ENDIF
      call wait_key
      print chr$(13,10)
    ENDM

    ;; ---------------------------------------------------
    ;; wait for a keystroke and return its scancode in EAX
    ;; ---------------------------------------------------
    getkey MACRO
      call ret_key
    ENDM

    SetConsoleCaption MACRO title_text:VARARG
      invoke SetConsoleTitle,reparg(title_text)
    ENDM

    GetConsoleCaption$ MACRO
      IFNDEF @@_console_caption_buffer_@@
      .data?
        @@_console_caption_buffer_@@ db 260 dup (?)
      .code
      ENDIF
      invoke GetConsoleTitle,ADDR @@_console_caption_buffer_@@,260
      EXITM <OFFSET @@_console_caption_buffer_@@>
    ENDM


    ; **************************
    ; Application startup code *
    ; **************************

      AppStart MACRO
        .code
        start:
        invoke GetModuleHandle, NULL
        mov hInstance, eax

        invoke GetCommandLine
        mov CommandLine, eax

        invoke InitCommonControls

        invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
        invoke ExitProcess,eax
      ENDM

    ; --------------------------------------------------------------
    ; Specifies processor, memory model & case sensitive option.
    ; The parameter "Processor" should be in the form ".386" etc..
    ; EXAMPLE : AppModel .586
    ; --------------------------------------------------------------
      AppModel MACRO Processor
        Processor             ;; Processor type
        .model flat, stdcall  ;; 32 bit memory model
        option casemap :none  ;; case sensitive
      ENDM

    ; --------------------------------------------
    ; The following two macros must be used as a
    ; pair and can only be used once in a module.
    ; Additional code for processing within the
    ; message loop can be placed between them.
    ;
    ; The single parameter passed to both macros
    ; is the name of the MSG structure and must be
    ; the same in both macros.
    ; --------------------------------------------

      BeginMessageLoop MACRO mStruct
        MessageLoopStart:
          invoke GetMessage,ADDR mStruct,NULL,0,0
          cmp eax, 0
          je MessageLoopExit
      ENDM

      EndMessageLoop MACRO mStruct
          invoke TranslateMessage, ADDR mStruct
          invoke DispatchMessage,  ADDR mStruct
          jmp MessageLoopStart
        MessageLoopExit:
      ENDM

    ; ********************************************
    ; align memory                               *
    ; reg has the address of the memory to align *
    ; number is the required alignment           *
    ; EXAMPLE : memalign esi, 16                 *
    ; ********************************************

      memalign MACRO reg, number
        add reg, number - 1
        and reg, -number
      ENDM

; ---------------------------------------------------------------------
;
; The GLOBALS macro is for allocating uninitialised data in the .DATA?
; section. It is designed to take multiple definitions to make
; allocating uninitialised data more intuitive while coding.
;
; EXAMPLE: GLOBALS item1 dd ?,\
;                  item2 dd ?,\
;                  item3 dw ?,\
;                  item4 db 128 dup (?)
;
; ---------------------------------------------------------------------

      GLOBALS MACRO var1,var2,var3,var4,var5,var6,var7,var8,var9,var0,
                    varA,varB,varC,varD,varE,varF,varG,varH,varI,varJ
        .data?
          align 4
          var1
          var2
          var3
          var4
          var5
          var6
          var7
          var8
          var9
          var0
          varA
          varB
          varC
          varD
          varE
          varF
          varG
          varH
          varI
          varJ
        .code
      ENDM

    ; **********************
    ; miscellaneous macros *
    ; **********************

      ShellAboutBox MACRO handle,IconHandle,quoted_Text_1,quoted_Text_2:VARARG
        LOCAL AboutTitle,AboutMsg,buffer

        .data
          align 4
          buffer db 128 dup (0)
          AboutTitle db quoted_Text_1,0
          AboutMsg   db quoted_Text_2,0
          align 4
        .code

        mov esi, offset AboutTitle
        mov edi, offset buffer
        mov ecx, lengthof AboutTitle
        rep movsb
        
        invoke ShellAbout,handle,ADDR buffer,ADDR AboutMsg,IconHandle
      ENDM

; ------------------------------------------------------------------
; macro for making STDCALL procedure and API calls.
; ------------------------------------------------------------------

    Scall MACRO name:REQ,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12, \
                     p13,p14,p15,p16,p17,p18,p19,p20,p21,p22

    ;; ---------------------------------------
    ;; loop through arguments backwards, push
    ;; NON blank ones and call the function.
    ;; ---------------------------------------

      FOR arg,<p22,p21,p20,p19,p18,p17,p16,p15,p14,p13,\
               p12,p11,p10,p9,p8,p7,p6,p5,p4,p3,p2,p1>
        IFNB <arg>    ;; If not blank
          push arg    ;; push parameter
        ENDIF
      ENDM

      call name       ;; call the procedure

    ENDM

    ; -------------------------------
    ; pascal calling convention macro
    ; left to right push
    ; -------------------------------
      Pcall MACRO name:REQ,items:VARARG
        LOCAL arg
        FOR arg,<items>
          push arg
        ENDM
          call name
      ENDM

    ; ---------------------------------------
    ; Append literal string to end of buffer
    ; ---------------------------------------
      Append MACRO buffer,text
        LOCAL szTxt
        .data
          szTxt db text,0
          align 4
        .code
        invoke szCatStr,ADDR buffer,ADDR szTxt
      ENDM

    ; ---------------------------
    ; Put ascii zero at 1st byte
    ; ---------------------------
      zero1 MACRO membuf
        mov membuf[0], 0
      ENDM

    ; -------------------------------------------
    ; put zero terminated string in .data section
    ; alternative to the szText MACRO
    ; -------------------------------------------
      dsText MACRO Name, Text:VARARG
      .data
        Name db Text,0
        align 4
      .code
      ENDM

    ; -------------------------------
    ; make 2 WORD values into a DWORD
    ; result in eax
    ; -------------------------------
      MAKEDWORD MACRO LoWord,HiWord
        mov ax, HiWord
        ror eax, 16
        mov ax, LoWord
      ENDM

    ; -----------------------------
    ; return IMMEDIATE value in eax
    ; -----------------------------
      retval MACRO var
        IF var EQ 0
          xor eax, eax  ;; slightly more efficient for zero
        ELSE
          mov eax, var  ;; place value in eax
        ENDIF
        ret
      ENDM

    ; ------------------------
    ; inline memory copy macro
    ; ------------------------
      Mcopy MACRO lpSource,lpDest,len
        mov esi, lpSource
        mov edi, lpDest
        mov ecx, len
        rep movsb
      ENDM

    ; -----------------------------------
    ; INPUT red, green & blue BYTE values
    ; OUTPUT DWORD COLORREF value in eax
    ; -----------------------------------
      RGB MACRO red, green, blue
        xor eax, eax
        mov ah, blue    ; blue
        mov al, green   ; green
        rol eax, 8
        mov al, red     ; red
      ENDM

    ; ------------------------------------------------
    ; The following macro were written by Ron Thomas
    ; ------------------------------------------------
    ; Retrieves the low word from double word argument
    ; ------------------------------------------------
      LOWORD MACRO bigword  
        mov  eax,bigword
        and  eax,0FFFFh     ;; Set to low word 
      ENDM

    ; ----------------------
    ; fast lodsb replacement
    ; ----------------------
      lob MACRO
        mov al, [esi]
        inc esi
      ENDM

    ; ----------------------
    ; fast stosb replacement
    ; ----------------------
      stb MACRO
        mov [edi], al
        inc edi
      ENDM

    ; ----------------------------
    ; code section text insertion
    ; ----------------------------
      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      return MACRO arg
        mov eax, arg
        ret
      ENDM

      SingleInstanceOnly MACRO lpClassName
        invoke FindWindow,lpClassName,NULL
        cmp eax, 0
        je @F
          push eax
          invoke ShowWindow,eax,SW_RESTORE
          pop eax
          invoke SetForegroundWindow,eax
          mov eax, 0
          ret
        @@:
      ENDM

    ; macro encapsulates the MAX_PATH size buffer and returns its OFFSET

      DropFileName MACRO wordparam
        IFNDEF df@@name
          .data?
            dfname db MAX_PATH dup (?)
          .code
        df@@name equ 1
        ENDIF
        invoke DragQueryFile,wordparam,0,ADDR dfname,SIZEOF dfname
        EXITM <OFFSET dfname>
      ENDM


    ; returns the handle of a control where its ID is known

      hDlgItem MACRO pHwnd,ctlID
        LOCAL retval
        .data?
          retval dd ?
        .code
        invoke GetDlgItem,pHwnd,ctlID
        mov retval, eax
        EXITM <retval>
      ENDM

  ; ----------------------------------------
  ; chtype$() will accept either a BYTE sized
  ; register or the address of a BYTE as a
  ; memory operand.
  ; The result is returned in a memory operand
  ; as a BYTE PTR to the character class in the
  ; table.
  ; You would normally use this macro with
  ;
  ;     movzx ecx, chtype$([ebp+4])
  ;     cmp chtype$([esp+4]), 2
  ;     cmp chtype$(ah), dl
  ;
  ; ----------------------------------------
    chtype$ MACRO character
      IFNDEF chtyptbl
        EXTERNDEF chtyptbl:DWORD         ;; load table if not already loaded
      ENDIF
      movzx eax, BYTE PTR character      ;; zero extend character to 32 bit reg
      EXITM <BYTE PTR [eax+chtyptbl]>    ;; place the table access in a 32 bit memory operand
    ENDM

  ; ********************
  ; Line reading macros.
  ; ********************

    linein$ MACRO source,buffer,spos
      invoke readline,source,buffer,spos
      EXITM <eax>
    ENDM

    lineout$ MACRO source,buffer,spos,op_crlf
      invoke writeline,reparg(source),buffer,spos,op_crlf
      EXITM <eax>
    ENDM

    tstline$ MACRO lpstr
      invoke tstline,reparg(lpstr)
      EXITM <eax>
    ENDM

  ; -----------------------------------
  ; UNICODE string functions and macros
  ; -----------------------------------

    uadd$ MACRO wstr1,wstr2
      invoke ucCatStr,wstr1,wstr2
      EXITM <wstr1>
    ENDM

    uptr$ MACRO lpbuffer
      lea eax, lpbuffer
      mov WORD PTR [eax], 0
      EXITM <eax>
    ENDM

    ucmp$ MACRO wstr1,wstr2
      invoke ucCmp,wstr1,wstr2
      EXITM <eax>
    ENDM

    ucopy$ MACRO wstr1,wstr2
      invoke ucCopy,wstr1,wstr2
    ENDM

    ulen$ MACRO lpwstr
      invoke ucLen,lpwstr
      EXITM <eax>
    ENDM

    ulcase$ MACRO lpwstr
      invoke CharLowerBuffW,lpwstr,ulen$(lpwstr)
      EXITM <lpwstr>
    ENDM

    uucase$ MACRO lpwstr
      invoke CharUpperBuffW,lpwstr,ulen$(lpwstr)
      EXITM <lpwstr>
    ENDM

    uleft$ MACRO lpwstr,ccount
      invoke ucLeft,lpwstr,lpwstr,ccount
      EXITM <lpwstr>
    ENDM

    umid$ MACRO lpwstr,spos,ln
      invoke ucMid,lpwstr,lpwstr,spos,ln
      EXITM <lpwstr>
    ENDM

    uright$ MACRO lpwstr,ccount
      invoke ucRight,lpwstr,lpwstr,ccount
      EXITM <lpwstr>
    ENDM

    urev$ MACRO lpwstr
      invoke ucRev,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

    ultrim$ MACRO lpwstr
      invoke ucLtrim,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

    urtrim$ MACRO lpwstr
      invoke ucRtrim,lpwstr,lpwstr
      EXITM <lpwstr>
    ENDM

; д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д=ў=д

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    LOCALVAR equ <LOCAL>

    ; ----------------------------------
    ; macros for creating menu bar items
    ; ----------------------------------

    TxtItem MACRO tID, cID, strng
      mov tbb.iBitmap,   I_IMAGENONE
      mov tbb.idCommand, cID
      mov tbb.fsStyle,   BTNS_BUTTON or BTNS_AUTOSIZE
      mov tbb.iString,   tID
      invoke SendMessage,TBhWnd,TB_ADDBUTTONS,1,ADDR tbb
      fn SendMessage,TBhWnd,TB_ADDSTRING,0,strng
    ENDM

    ; ------------------------------

    TxtSeperator MACRO
      mov tbb.iBitmap,   I_IMAGENONE
      mov tbb.idCommand, 0
      mov tbb.fsStyle,   BTNS_SEP ;; or BTNS_AUTOSIZE   ; << extra spacing
      invoke SendMessage,TBhWnd,TB_ADDBUTTONS,1,ADDR tbb
    ENDM

    ; ------------------------------

    TB_BEGIND MACRO pHandle

    LOCALVAR TBhWnd    :DWORD
    LOCALVAR tbb       :TBBUTTON

      invoke CreateWindowEx,0,
                            chr$("ToolbarWindow32"),
                            NULL,
                            WS_CHILD or WS_VISIBLE or TBSTYLE_TOOLTIPS or \
                            TBSTYLE_FLAT or TBSTYLE_LIST or \
                            TBSTYLE_TRANSPARENT,
                            0,0,500,20,
                            pHandle,NULL,
                            hInstance,NULL
      mov TBhWnd, eax

      invoke SendMessage,TBhWnd,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
      invoke SendMessage,TBhWnd,TB_SETINDENT,5,0

      mov tbb.fsState,   TBSTATE_ENABLED
      mov tbb.dwData,    0
      mov tbb.iString,   0
    ENDM

    ; ------------------------------

    TB_BEGIN MACRO pHandle

    LOCALVAR TBhWnd    :DWORD
    LOCALVAR tbb       :TBBUTTON

      invoke CreateWindowEx,0,
                            chr$("ToolbarWindow32"),
                            NULL,
                            WS_CHILD or WS_VISIBLE or TBSTYLE_TOOLTIPS or \
                            TBSTYLE_FLAT or TBSTYLE_LIST or \
                            TBSTYLE_TRANSPARENT or CCS_NODIVIDER,
                            0,0,500,20,
                            pHandle,NULL,
                            hInstance,NULL
      mov TBhWnd, eax

      invoke SendMessage,TBhWnd,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
      invoke SendMessage,TBhWnd,TB_SETINDENT,5,0

      mov tbb.fsState,   TBSTATE_ENABLED
      mov tbb.dwData,    0
      mov tbb.iString,   0
    ENDM

    ; ------------------------------

    TB_END MACRO
      mov eax, TBhWnd
      ret
    ENDM

    ; ------------------------------

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

    date$ MACRO
      IFNDEF @_@_current_local_date_@_@
        .data?
          @_@_current_local_date_@_@ db 128 dup (?)
        .code
      ENDIF
      invoke GetDateFormat,LOCALE_USER_DEFAULT,DATE_LONGDATE,
                           NULL,NULL,ADDR @_@_current_local_date_@_@,128
      EXITM <OFFSET @_@_current_local_date_@_@>
    ENDM

    time$ MACRO
      IFNDEF @_@_current_local_time_@_@
        .data?
          @_@_current_local_time_@_@ db 128 dup (?)
        .code
      ENDIF
      invoke GetTimeFormat,LOCALE_USER_DEFAULT,NULL,NULL,NULL,
                           ADDR @_@_current_local_time_@_@,128
      EXITM <OFFSET @_@_current_local_time_@_@>
    ENDM

    env$ MACRO item
      invoke crt_getenv,reparg(item)
      EXITM <eax>
    ENDM

    setenv MACRO value
      invoke crt__putenv,reparg(value)
    ENDM

  ; --------------------------------------------------------
  ; useful macro for adding padding directly in source code.
  ; --------------------------------------------------------
    nops MACRO cnt:REQ
      REPEAT cnt
        nop
      ENDM
    ENDM

comment * -----------------------------------------------------------------

   NOTES on DDPROTO macro

   This macro is for producing prototypes for functions where the start
   address is known and the parameter count is known. It requires a named
   DWORD sized entry in the .DATA or .DATA? section which has the start
   address written to it before the function is called.

        EXAMPLE:
        .data?
          user32_msgbox dd ?            ; << The named variable

        msgbox DDPROTO(user32_msgbox,4) ; create prototype

        This is expanded to the following. The TYPEDEF refers to
        the macro "pr4" in the WINDOWS.INC file.

        pt4 TYPEDEF PTR pr4
        msgbox equ <(TYPE pt4) PTR user32_msgbox>

        The address must be written to the DWORD variable before it can
        be called. This can be LoadLibrary/GetProcAddress or it can be
        an address recovered from a virtual table in a DLL or any other
        viable means of obtaining the start address of a function to call.

        invoke msgbox,hWnd,ADDR message_text, ADDR title_text,MB_OK

        ----------------------------------------------------------------- *

      DDPROTO MACRO lpFunction,pcount
        LOCAL txt1,txt2
        txt1 equ <pr>
        txt1 CATSTR txt1,%pcount
        txt2 equ <pt>
        txt2 CATSTR txt2,%pcount
        txt2 TYPEDEF PTR txt1
        EXITM <equ <(TYPE txt2) PTR lpFunction>>
      ENDM

comment * ==================================================================

     The following macros create a text stack and retrieve text items from
     that stack.

 1.  pushtxt textitem   ; place text item on text stack
 2.  poptxt [lbl]       ; retrieve last text item and write it to the souce file
 3.  poptxt$()          ; return last text item on the stack to caller.

     Both versions of poptxt remove the item from the stack. The optional
     parameter "lbl" for the statement version "poptxt" writes a colon after the
     txt item in the source file so it is a label.

     ptdbg equ <1>   use this equate to display stack text items for debugging macros.

     NOTES : The text stack macros have been tested and are reliable but they are
     subject to undocumented behavour with the characteristics of at least some
     of the internal loop code and similar macro operators. The tested effect under
     a FOR loop is that the main equate that stores the text data as a stack is
     initialised back to an empty string when called from a FOR loop. Where you need loop
     code when using these text stack macros, you are safer using a label and testing
     the variable with an IF operator.

     var = 10               ;; set the variable to a value
   :label                   ;; write a macro label

     ; your macro code here

     var = var - 1          ;; decrement variable
     IF var NE 0            ;; test if its zero
       goto label           ;; jump back to label if its not
     ENDIF

     The mangled names for the string equate and the depth indicator are to reduce
     the chance of a name clash with other symbols used in the source file.

        ================================================================= *

    pushtxt MACRO arg
      IFNDEF @_txt_stack_@
        @_txt_stack_@ equ <>                        ;; allocate text buffer as equate
        @_s_d_i_@ = 0                               ;; allocate stack depth indicator
      ENDIF
      IFNDEF ptdbg
        ptdbg equ <0>                               ;; debug equate, set to 1 for display
      ENDIF
      @_txt_stack_@ CATSTR <arg^>,@_txt_stack_@     ;; prepend new arg to front of stack
      @_s_d_i_@ = @_s_d_i_@ + 1                     ;; increment depth counter
      IF ptdbg
      % echo arg
      ENDIF
    ENDM

    poptxt MACRO extra:VARARG                       ;; "extra" arg if used must be "lbl" (without quotes)
      LOCAL txt,num,sln
      nop
      num INSTR @_txt_stack_@,<^>                   ;; get 1st delimiter location
      num = num + 1
      txt SUBSTR @_txt_stack_@,1,num-2              ;; read text back off stack
      IF ptdbg
      % echo txt
      ENDIF
      @_s_d_i_@ = @_s_d_i_@ - 1                     ;; decrement stack item count
      IF @_s_d_i_@ NE 0                             ;; if stack depth NOT zero
        sln SIZESTR @_txt_stack_@                   ;; get current stack length
        @_txt_stack_@ SUBSTR @_txt_stack_@, \
                             num,sln-num+1          ;; remove current item from stack
      ELSE
        @_txt_stack_@ equ <>                        ;; empty the stack on last arg
      ENDIF
      IFIDNI <lbl>,<extra>
        txt CATSTR txt,<:>                          ;; append a colon if its a label
        txt                                         ;; then write txt to source file
      ELSE
        txt                                         ;; write txt to source file
      ENDIF
    ENDM

    poptxt$ MACRO
      LOCAL txt,num,sln
      num INSTR @_txt_stack_@,<^>                   ;; get 1st delimiter location
      num = num + 1
      txt SUBSTR @_txt_stack_@,1,num-2              ;; read text back off stack
      IF ptdbg
      % echo txt
      ENDIF
      @_s_d_i_@ = @_s_d_i_@ - 1                     ;; decrement stack item count
      IF @_s_d_i_@ NE 0                             ;; if stack depth NOT zero
        sln SIZESTR @_txt_stack_@                   ;; get current stack length
        @_txt_stack_@ SUBSTR @_txt_stack_@, \
                             num,sln-num+1          ;; remove current item from stack
      ELSE
        @_txt_stack_@ equ <>                        ;; empty the stack on last arg
      ENDIF
      EXITM <txt>
    ENDM

 ; *************************************************************************

  ; --------------------------------------
  ; save registers in left to right order.
  ; --------------------------------------
    pushr MACRO regs:VARARG
      LOCAL cnt,lpc,lbl
      cnt = argcount(regs)
      lpc = 0
    :lbl
      pushtxt getarg(lpc+1,regs)
      push getarg(lpc+1,regs)
      lpc = lpc + 1
      IF lpc NE cnt
        goto lbl
      ENDIF
    ENDM

  ; --------------------------------------------
  ; restore the same registers in reverse order.
  ; --------------------------------------------
    popr MACRO
      LOCAL lbl
    :lbl
      pop poptxt$()
      IF @_s_d_i_@ GT 0
        goto lbl
      ENDIF
    ENDM

 ; *************************************************************************

    MakeIP MACRO arg1,arg2,arg3,arg4
        mov ah, arg1
        mov al, arg2
        rol eax, 16
        mov ah, arg3
        mov al, arg4
      EXITM <eax>
    ENDM


comment * -------------------------------------------------

        The "uselib" macro allows names that are used for
        both include files and library file to be used in a
        list without extensions. Note the following order
        of include files where WINDOWS.INC should be
        included first then the main macro file BEFORE this
        macro is called.

        include \masm32\include\windows.inc
        include \masm32\macros\macros.asm
        uselib masm32,gdi32,user32,kernel32,Comctl32,comdlg32,shell32,oleaut32,msvcrt

        ------------------------------------------------- *

    uselib MACRO args:VARARG
      LOCAL acnt,buffer,var,lbl,libb,incc,buf1,buf2
      acnt = argcount(args)
      incc equ <include \masm32\include\>
      libb equ <includelib \masm32\lib\>
      var = 1
    :lbl
      buffer equ getarg(var,args)

      buf1 equ <>
      buf1 CATSTR buf1,incc,buffer,<.inc>
      buf1
      ;; % echo buf1

      buf2 equ <>
      buf2 CATSTR buf2,libb,buffer,<.lib>
      buf2
      ;; % echo buf2

      var = var + 1
      IF var LE acnt
        goto lbl
      ENDIF
    ENDM

  ; -----------------------------------------------












