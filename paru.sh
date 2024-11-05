#!/bin/bash

LOG_FILE="./paru_install_log.txt"

# Initialize log file
echo "Starting setup process at $(date)" > "$LOG_FILE"
declare -A STATUS_TRACKER  # Tracks the success or failure of each stage

# Trap to handle unexpected exits
trap 'echo "Script interrupted. Check $LOG_FILE for details." | tee -a "$LOG_FILE"; exit 1' INT TERM

sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
