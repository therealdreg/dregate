
; ------------------- UNICODE support macros for MASM32 -------------------

comment * -----------------------------------------------
      macro to declare UNICODE string data in the .DATA
      section.
      SYNTAX:
      WSTR MyString,"This is a test"
      string length limit = 118 charachers
      control characters like < > etc .. cannot be used
      in the string.
      ------------------------------------------------- *
    WSTR MACRO iname,text:VARARG
        ustrng1 equ <>
        ustrng2 equ <>
        ustrng3 equ <>

        addstr1 equ <>
        addstr2 equ <>
        addstr3 equ <>
        cnt = 0

        slen SIZESTR <text>

      ;; ------------------------------------------------
      ;; test for errors in length or missing quotations
      ;; ------------------------------------------------
        if slen gt 118
          echo -----------------------
          echo *** STRING TOO LONG ***
          echo -----------------------
        .ERR
        EXITM
        endif

        qot1 SUBSTR <text>,1,1
        IFDIF qot1,<">
          echo -----------------------------
          echo *** MISSING LEADING QUOTE ***
          echo -----------------------------
        .ERR
        EXITM
        ENDIF

        qot2 SUBSTR <text>,slen,1
        IFDIF qot2,<">
          echo ------------------------------
          echo *** MISSING TRAILING QUOTE ***
          echo ------------------------------
        .ERR
        EXITM
        ENDIF

      ;; ------------------------------------------------
      ;; loop through the characters in the string adding
      ;; them in a WORD formatted form to the end of each
      ;; string depending on the length.
      ;; ------------------------------------------------
        nustr SUBSTR <text>,2,slen-2
      % FORC arg, <nustr>
          if cnt lt 1
            addstr1 CATSTR addstr1,<">,<arg>,<">
          elseif cnt lt 40
            addstr1 CATSTR addstr1,<,">,<arg>,<">
            
          elseif cnt lt 41
            addstr2 CATSTR addstr2,<">,<arg>,<">
          elseif cnt lt 80
            addstr2 CATSTR addstr2,<,">,<arg>,<">

          elseif cnt lt 81
            addstr3 CATSTR addstr3,<">,<arg>,<">
          elseif cnt lt 120
            addstr3 CATSTR addstr3,<,">,<arg>,<">
          endif
          cnt = cnt + 1
        ENDM

      ;; ------------------------------------------------
      ;; The following three blocks append the 00 to the
      ;; end of the string depending on how long it is
      ;; ------------------------------------------------
        if cnt lt 41
        addstr1 CATSTR addstr1,<,00>
        endif
          ustrng1 CATSTR ustrng1,<iname>,< dw >,addstr1
          ustrng1
        if cnt lt 41
          EXITM
        endif

        if cnt lt 81
          addstr2 CATSTR addstr2,<,00>
        endif
          ustrng2 CATSTR ustrng2,< dw >,addstr2
          ustrng2
        if cnt lt 81
          EXITM
        endif

        addstr3 CATSTR addstr3,<,00>
        ustrng3 CATSTR ustrng3,< dw >,addstr3
        ustrng3
    ENDM
    ;; -------------------------------------------------

  ; ******************************
  ; FUNCTION version of the above.
  ; ******************************
    uni$ MACRO text:VARARG

        LOCAL addstr1
        LOCAL iname

        ustrng1 equ <>
        ustrng2 equ <>
        ustrng3 equ <>

        addstr1 equ <>
        addstr2 equ <>
        addstr3 equ <>
        cnt = 0

        slen SIZESTR <text>

     ;; ------------------------------------------------
     ;; test for errors in length or missing quotations
     ;; ------------------------------------------------
        if slen gt 118
          echo -----------------------
          echo *** STRING TOO LONG ***
          echo -----------------------
        .ERR
        EXITM <>
        endif

        qot1 SUBSTR <text>,1,1
        IFDIF qot1,<">
          echo -----------------------------
          echo *** MISSING LEADING QUOTE ***
          echo -----------------------------
        .ERR
        EXITM <>
        ENDIF

        qot2 SUBSTR <text>,slen,1
        IFDIF qot2,<">
          echo ------------------------------
          echo *** MISSING TRAILING QUOTE ***
          echo ------------------------------
        .ERR
        EXITM <>
        ENDIF

      ;; ------------------------------------------------
      ;; loop through the characters in the string adding
      ;; them in a WORD formatted form to the end of each
      ;; string depending on the length.
      ;; ------------------------------------------------
        nustr SUBSTR <text>,2,slen-2
      % FORC arg, <nustr>
          if cnt lt 1
            addstr1 CATSTR addstr1,<">,<arg>,<">
          elseif cnt lt 40
            addstr1 CATSTR addstr1,<,">,<arg>,<">
            
          elseif cnt lt 41
            addstr2 CATSTR addstr2,<">,<arg>,<">
          elseif cnt lt 80
            addstr2 CATSTR addstr2,<,">,<arg>,<">

          elseif cnt lt 81
            addstr3 CATSTR addstr3,<">,<arg>,<">
          elseif cnt lt 120
            addstr3 CATSTR addstr3,<,">,<arg>,<">
          endif
          cnt = cnt + 1
        ENDM

        .data
      ;; ------------------------------------------------
      ;; The following three blocks append the 00 to the
      ;; end of the string depending on how long it is
      ;; ------------------------------------------------
        if cnt lt 41
        addstr1 CATSTR addstr1,<,00>
        endif
          ustrng1 CATSTR ustrng1,<iname>,< dw >,addstr1
          ustrng1
        if cnt lt 41
          .code
          goto mclbl
        endif

        if cnt lt 81
          addstr2 CATSTR addstr2,<,00>
        endif
          ustrng2 CATSTR ustrng2,< dw >,addstr2
          ustrng2
        if cnt lt 81
          .code
          goto mclbl
        endif

        addstr3 CATSTR addstr3,<,00>
        ustrng3 CATSTR ustrng3,< dw >,addstr3
        ustrng3
          .code

        :mclbl

        EXITM <OFFSET iname>

    ENDM
    ;; -------------------------------------------------
