#!/usr/bin/env bash 

apt-cyg install make gcc-core gcc-g++ patch bzip2 perl tar xz automake cmake unzip zip

sh .conf.win64-vcpp

cmd.exe /c compile_vspart_bochs.bat