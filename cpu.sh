#!/usr/bin/env bash

# Colors (Using safe tput sequences)
RED=$(tput setaf 1 2>/dev/null || echo '\033[0;31m')
YELLOW=$(tput setaf 3 2>/dev/null || echo '\033[0;33m')
GREEN=$(tput setaf 2 2>/dev/null || echo '\033[0;32m')
BLUE=$(tput setaf 4 2>/dev/null || echo '\033[0;34m')
BOLD=$(tput bold 2>/dev/null || echo '\033[1m')
NC=$(tput sgr0 2>/dev/null || echo '\033[0m') # No Color

# Function to get CPU usage percentage
get_cpu_usage() {
    local prev_total=0 prev_idle=0
    local total=0 idle=0

    # Read initial values (atomic read)
    read -r _ prev_user prev_nice prev_system prev_idle prev_iowait prev_irq prev_softirq _ < /proc/stat
    prev_total=$((prev_user + prev_nice + prev_system + prev_idle + prev_iowait + prev_irq + prev_softirq))

    sleep 0.5

    # Read values after 0.5 second (atomic read)
    read -r _ user nice system idle iowait irq softirq _ < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq))

    # Calculate differences
    idle=$((idle - prev_idle))
    total=$((total - prev_total))
    if [[ $total -eq 0 ]]; then total=1; fi

    # Calculate CPU usage percentage
    echo $((100 * (total - idle) / total))
}

# Function to get memory usage percentage
get_mem_usage() {
    local total=0 used=0
    read -r _ total _ < <(grep MemTotal /proc/meminfo)
    read -r _ available _ < <(grep MemAvailable /proc/meminfo)
    used=$((total - available))
    echo $((100 * used / total))
}

# Function to display system info
display_system_info() {
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_mem_usage)
    local uptime=$(uptime -p | sed 's/up //')

    # Colorize based on usage
    local cpu_color=$GREEN
    [[ $cpu_usage -gt 70 ]] && cpu_color=$YELLOW
    [[ $cpu_usage -gt 90 ]] && cpu_color=$RED

    local mem_color=$GREEN
    [[ $mem_usage -gt 70 ]] && mem_color=$YELLOW
    [[ $mem_usage -gt 90 ]] && mem_color=$RED

    tput cup 0 0
    printf "${BOLD}=== System Monitoring Tool ===${NC}\n"
    printf "Uptime: %s | CPU: ${cpu_color}%3d%%${NC} | Memory: ${mem_color}%3d%%${NC} | ${BOLD}Press Ctrl+C to exit${NC}\n" "$uptime" "$cpu_usage" "$mem_usage"
    printf '%*s\n' "$(( $(tput cols) - 1 ))" '' | tr ' ' '-'
}

# Function to get terminal width
get_term_width() {
    tput cols
}

# Function to get terminal height
get_term_height() {
    tput lines
}

# Function to display processes
display_processes() {
    local term_width=$(get_term_width)
    local term_height=$(get_term_height)
    local pid_width=8
    local user_width=10
    local cpu_width=5
    local mem_width=5
    local vsz_width=8
    local rss_width=8
    local cmd_width=$((term_width - 53))
    [[ $cmd_width -lt 10 ]] && cmd_width=10

    local num_procs=$((term_height - 7))
    [[ $num_procs -lt 5 ]] && num_procs=5

    tput cup 3 0
    tput ed

    printf "${BOLD}%-${pid_width}s %-${user_width}s %6s %6s %${vsz_width}s %${rss_width}s %s${NC}\n" "PID" "USER" "%CPU" "%MEM" "VSZ" "RSS" "COMMAND"
    printf '%*s\n' "$((term_width - 1))" '' | tr ' ' '-'

    # Get processes sorted by CPU and memory usage, showing full command
    ps -eo pid,user:10,%cpu,%mem,vsz,rss,args --sort=-%cpu,-%mem | \
    awk -v pidw=$pid_width -v userw=$user_width -v cpuw=$cpu_width -v memw=$mem_width -v vszw=$vsz_width -v rssw=$rss_width -v cmdw=$cmd_width -v red="$RED" -v yellow="$YELLOW" -v nc="$NC" '
    NR==1 {next}
    {
        # Colorize high usage processes
        cpu_color = ($3 > 50) ? red : ($3 > 20) ? yellow : nc;
        mem_color = ($4 > 50) ? red : ($4 > 20) ? yellow : nc;

        # Extract command safely
        cmd = $0;
        for(i=1; i<=6; i++) sub(/^[ \t]*[^ \t]+[ \t]*/, "", cmd);

        # Sanitize command output to remove ANSI escapes and control characters
        gsub(/\x1b\[[0-9;]*[a-zA-Z]/, "", cmd);
        gsub(/[\x00-\x1F\x7F]/, "", cmd);

        # Truncate command at first space to hide sensitive arguments
        if (index(cmd, " ") > 0) {
            cmd = substr(cmd, 1, index(cmd, " ")-1) "[...]";
        }

        # Truncate command to avoid line wrap
        if (length(cmd) > cmdw) cmd = substr(cmd, 1, cmdw);

        # Format each field
        printf "%-" pidw "s %-" userw "s " cpu_color "%" cpuw ".1f%%" nc " " mem_color "%" memw ".1f%%" nc " %" vszw "s %" rssw "s %s\n",
            $1, $2, $3, $4, $5, $6, cmd
    }' | head -n "$num_procs"
}

# Main monitoring function
monitor_system() {
    # Set up terminal
    clear
    tput civis  # Hide cursor

    # Main monitoring loop
    while true; do
        display_system_info
        display_processes
        
        # Adaptive sleep based on system load
        local load=$(awk '{print $1}' /proc/loadavg)
        if (( $(echo "$load > 10" | bc -l) )); then
            sleep 5
        elif (( $(echo "$load > 5" | bc -l) )); then
            sleep 2
        else
            sleep 1
        fi
    done
}

# Clean up on exit
cleanup() {
    tput cnorm  # Restore cursor
    clear
    exit 0
}

# Trap Ctrl+C
trap cleanup INT TERM

# Start monitoring
monitor_system
