#!/usr/bin/env bash
set -x

ulimit -c unlimited
echo '/tmp/core.%e.%p.%t' | tee /proc/sys/kernel/core_pattern
