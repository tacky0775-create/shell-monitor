#!/bin/bash

LOGFILE="/opt/monitor/logs/monitor.log"
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
MEMORY=$(free | awk '/Mem:/ {print int($3/$2*100)}')
DISK=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
DATE=$(date "+%Y-%m-%d %H:%M:%S")

echo "$DATE CPU:${CPU}% MEMORY:${MEMORY}% DISK:${DISK}%" >> "$LOGFILE"

if [ "$CPU" -gt 80 ]; then
    echo "$DATE WARNING: CPU usage is high." >> "$LOGFILE"
fi

if [ "$MEMORY" -gt 80 ]; then
    echo "$DATE WARNING: MEMORY usage is high." >> "$LOGFILE"
fi

if [ "$DISK" -gt 90 ]; then
    echo "$DATE WARNING: DISK usage is high." >> "$LOGFILE"
fi
