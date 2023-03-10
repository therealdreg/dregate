/*
MIT License

https://github.com/therealdreg/dregate

Copyright (c) [2022] by David Reguera Garcia aka Dreg 
dreg@fr33project.org
https://www.fr33project.org 
https://github.com/therealdreg
TW @therealdreg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

WARNING: BULLSHIT CODE X-)
*/

#include <stdio.h>

#include <Windows.h>

#include "comm.h"

#define TITLE_MSGB "APC injected by Dreg"
#define CONTN_MSGB "APC injected loop messagebox infinite"

#ifdef __cplusplus
extern "C" {
#endif
    void __stdcall    bad_call_farf_low(void);
    void __stdcall    good_call_farf_low(void);
    DWORD* __stdcall  get_pid_addr(void);
    DWORD* __stdcall  get_tid_addr(void);
    DWORD* __stdcall  get_addr_apc(void);
    void __stdcall    good_key(void);
#ifdef __cplusplus
}
#endif

BOOL enable_debug_priv(void)
{
    TOKEN_PRIVILEGES  token_priv;
    LUID              luid;
    HANDLE            this_token;

    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ALL_ACCESS, &this_token))
    {
        if (GetLastError() == ERROR_NO_TOKEN)
        {
            ImpersonateSelf(SecurityImpersonation);
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &this_token))
            {  
                return FALSE;
            }
        }
    }

    if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &luid))
    {
        return FALSE;
    }

    token_priv.PrivilegeCount = 1;
    token_priv.Privileges[0].Luid = luid;
    token_priv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    AdjustTokenPrivileges(this_token, FALSE, &token_priv, sizeof(TOKEN_PRIVILEGES), NULL, NULL);

    CloseHandle(this_token);

    if (GetLastError() != ERROR_SUCCESS)
    {
        return FALSE;
    }

    printf("OK get debug privilege\n");

    return TRUE;
}

int poc_inject(DWORD pid_inject)
{
    HANDLE          handle_proc; 
    DWORD           title_address;
    const char*     title = TITLE_MSGB;
    const char*     content = CONTN_MSGB; 
    size_t          title_len = sizeof(TITLE_MSGB);
    size_t          content_len = sizeof(CONTN_MSGB);
    BYTE*           new_memory;
    DWORD           content_addr;
    DWORD           func_address;
    HANDLE          handle_thread;
    int             i;
    DWORD*          aux;
    DWORD           tid  = 0;
    BYTE func_code[] = {
        0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90, // fixes disasm
        0x6a, 0x01, // push 1
        0x68, 0x69, 0x69, 0x69, 0x69, // push 0x69696969
        0xB8, 0x00, 0x00, 0x00, 0x00, // mov eax, &SleepEx
        0xFF, 0xD0, // call eax
        0xF4, // hlt <- this instructions should not be executed (it crash the process)
        // APC START (DELTA_DR3G) Just a MessageBoxA: 
        0x68, 0x00,0x00,0x00,0x00,                                    // <-+
        0x68, 0x00,0x00,0x00,0x00,                                    //   |
        0x68, 0x00,0x00,0x00,0x00,                                    //   |
        0x6A, 0x00,                                                   //   |
        0xB8, 0x00,0x00,0x00,0x00, // mov eax,, &MessageBoxA          //   |
        0xFF, 0xD0, // call eax                                       //   |
        0xEB, 0xE6 // jmp to push msgbox args... infinite loop        // --+
    };

    enable_debug_priv();

    handle_proc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid_inject);
    if (NULL == handle_proc)
    {
        printf("error open process last error: %d 0x%x\n", GetLastError(), GetLastError());
        return 1;
    }

    printf("handle process: 0x%x\n", handle_proc);

    new_memory = (BYTE*)VirtualAllocEx(handle_proc, 0, 1024, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    printf("new memory: %x\n", new_memory);

    title_address = (DWORD)new_memory;
    content_addr = title_address + title_len;
    func_address = content_addr + content_len;

    WriteProcessMemory(handle_proc, (LPVOID)title_address, (LPCVOID)title, title_len, 0);
    WriteProcessMemory(handle_proc, (LPVOID)content_addr, (LPCVOID)content, content_len, 0);
    *((DWORD*) (func_code + 16+9))  = MB_OK | MB_TOPMOST | MB_ICONWARNING;
    *((DWORD*) (func_code + 8+9))   = (DWORD) SleepEx;
    *((DWORD*) (func_code + 21+9))  = (DWORD) title_address;
    *((DWORD*) (func_code + 26+9))  = (DWORD) content_addr;
    *((DWORD*) (func_code + 33+9))  = (DWORD) MessageBoxA;
    WriteProcessMemory(handle_proc, (LPVOID)func_address, func_code, sizeof(func_code), 0);

    printf("Payload injected at 0x%x \n", func_address);
    for (i = 0; i < sizeof(func_code); i++)
    {
        printf("0x%02x ", func_code[i]);
    }
    puts("");

    handle_thread = CreateRemoteThread(handle_proc, 0, 0, (LPTHREAD_START_ROUTINE)func_address, 0, 0, &tid);
    Sleep(2000);

    *(get_addr_apc()) = (DWORD)func_address + 15 + 9;
    aux = get_pid_addr();
    *aux = pid_inject;
    printf("\nPID: %d 0x%x\n", *aux, *aux );
    aux = get_tid_addr();
    *aux = tid;
    printf("TID: %d 0x%x\n", *aux, *aux );
    printf("\nexecuting call far with good key, a msgbox (from APC via work item) is coming\n");
    Sleep(3000);
    good_call_farf_low();

    puts("\nPress enter to exit\n");
    getchar();

    ExitProcess(0);

    /*
        VirtualFreeEx(handle_proc, new_memory, 0, MEM_RELEASE);
        CloseHandle(handle_thread);
    */

    return 0;

}

void __cdecl user_mode_apc(void* arg1, void* arg2, void* arg3)
{
    printf("\nAPC (C part) executed! arg1: 0x%x arg2: 0x%x arg3: 0x%x\n", arg1, arg2, arg3);

    printf("\narg1 -> %c%c%c%c\n", ((char*)&arg1)[0], ((char*)&arg1)[1], ((char*)&arg1)[2], ((char*)&arg1)[3]);
    printf("\narg2 -> %c%c%c%c\n", ((char*)&arg2)[0], ((char*)&arg2)[1], ((char*)&arg2)[2], ((char*)&arg2)[3]);
    printf("\narg3 -> %c%c%c%c\n", ((char*)&arg3)[0], ((char*)&arg3)[1], ((char*)&arg3)[2], ((char*)&arg3)[3]);

    puts("\npress ENTER to close program\n");

    getchar();

    return;
}


void __cdecl usermode_apc_ioctl(void* arg1, void* arg2, void* arg3)
{
    printf("\nioctl APC executed! arg1: 0x%x arg2: 0x%x arg3: 0x%x\n", arg1, arg2, arg3);

    printf("\narg1 -> %c%c%c%c\n", ((char*)&arg1)[0], ((char*)&arg1)[1], ((char*)&arg1)[2], ((char*)&arg1)[3]);
    printf("\narg2 -> %c%c%c%c\n", ((char*)&arg2)[0], ((char*)&arg2)[1], ((char*)&arg2)[2], ((char*)&arg2)[3]);
    printf("\narg3 -> %c%c%c%c\n", ((char*)&arg3)[0], ((char*)&arg3)[1], ((char*)&arg3)[2], ((char*)&arg3)[3]);

    return;
}

int dregate(void)
{
    HANDLE     handle_device;
    char       output_buffer[100] = { 0 };
    char       input_buffer[100] = { 0 };
    DWORD      bytes_returned = 0;
    DWORD*     aux = 0;

    do
    {
        Sleep(1000);
        handle_device = CreateFileW( L"\\\\.\\" DOS_DRV_NAME_W,
            GENERIC_READ | GENERIC_WRITE,
            0,
            NULL,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            NULL);

        if (INVALID_HANDLE_VALUE == handle_device)
        {
            printf ( "Error: CreatFile Failed : %d\n", GetLastError());
        }
    } while (INVALID_HANDLE_VALUE == handle_device);

    printf("Input Buffer Pointer = %p, Buf Length = %Iu\n", input_buffer, sizeof(input_buffer));
    printf("Output Buffer Pointer = %p Buf Length = %Iu\n", output_buffer, sizeof(output_buffer));

    (*((void**)input_buffer)) = usermode_apc_ioctl;
    strcpy(input_buffer + 5, "This String is from User Application; using METHOD_BUFFERED");
    printf("\nCalling DeviceIoControl METHOD_BUFFERED:\n");

    if (!DeviceIoControl(handle_device,
                        (DWORD) IOCTL_DIOCTL_METHOD_BUFFERED,
                        &input_buffer,
                        sizeof(input_buffer),
                        &output_buffer,
                        sizeof(output_buffer),
                        &bytes_returned,
                        NULL))
    {
        printf("Error in DeviceIoControl : %d", GetLastError());
        CloseHandle(handle_device);
        return 1;
    }

    printf("Out Buffer (%d): %s\n", bytes_returned, output_buffer);
    printf("\nwaiting for APC....\n");
    Sleep(2000);

    SleepEx(50000, TRUE);
    puts("\nwaiting 5 secs to continue....");
    Sleep(5000);

    //__asm { int 3 };
    printf("\nexecuting call far with bad key nothing will be happen\n");
    bad_call_farf_low();
    Sleep(2000);
    *(get_addr_apc()) = (DWORD)good_key;
    aux = get_pid_addr();
    *aux = GetCurrentProcessId();
    printf("PID: %d 0x%x\n", *aux, *aux );
    aux = get_tid_addr();
    *aux = GetCurrentThreadId();
    printf("TID: %d 0x%x\n", *aux, *aux );
    printf("\nexecuting call far with good key, a msgbox (from APC queued from a work item) is coming\n");
    Sleep(3000);
    good_call_farf_low();

    SleepEx(500000, TRUE);

    CloseHandle(handle_device);

    return 0;
}

int wmain(int argc, wchar_t* argv[], wchar_t* env[])
{
    int                  retf = 1;
    HANDLE               handle_mutex;
    DWORD                pid_inject = 0;
    PROCESS_INFORMATION  process_info = { 0 };
    STARTUPINFOA         si = { 0 };
    STARTUPINFOW         siw = { 0 };

    si.cb = sizeof(si);

    puts("\n\ndregate by Dreg https://github.com/therealdreg/dregate\n\n");

    handle_mutex = OpenMutexW(MUTEX_ALL_ACCESS, 0, L"dregate");

    if (!handle_mutex)
    {
        handle_mutex = CreateMutexW(0, 0, L"dregate");
    }
    else
    {
        MessageBoxW(NULL, L"Error other instance is running", L"Error other instance is running", MB_OK | MB_ICONERROR | MB_TOPMOST ); 
        return 1;
    }

    if (argc > 1)
    {
        if (wcsstr(L"-t", argv[1]) != NULL)
        {
            printf("executing notepad.exe\n");
            if (CreateProcessA(NULL, "notepad.exe", NULL, NULL, TRUE, 0, NULL, NULL, &si, &process_info))
            {
                puts("created!");
                pid_inject = process_info.dwProcessId;
                CloseHandle(process_info.hProcess);
                CloseHandle(process_info.hThread);
            }
        }
        else if (argc > 1 && wcsstr(L"-r", argv[1]) != NULL)
        {
            wprintf(L"executing %s as admin\n", argv[2]);
            if (CreateProcessW(NULL, argv[2], NULL, NULL, TRUE, 0, NULL, NULL, &siw, &process_info))
            {
                puts("done!");
                CloseHandle(process_info.hProcess);
                CloseHandle(process_info.hThread);
                return 0;
            }
            else
            {
                retf = 1;
                printf("error!\n GetLastError: %d 0x%X\n", GetLastError(), GetLastError());
                goto outf;
            }

        }
        else
        {
            pid_inject = _wtoi(argv[1]);
        }

        if (0 != pid_inject)
        {
            printf("\nPID to inject: %d 0x%x\n", pid_inject, pid_inject);
            retf = poc_inject(pid_inject);
        }
        else
        {
            printf("\nerror getting PID\n");
        }
    }
    else
    {
        retf = dregate();
    }

outf:
    puts("\npress enter to exit");

    getchar();

    return retf;
}