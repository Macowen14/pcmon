#!/usr/bin/env bash

# Function to get network interface information
get_network_info() {
    # Get all network interfaces (excluding lo)
    local interfaces=$(ls /sys/class/net | grep -v lo)

    # Print header
    printf "%-10s %-15s %-15s %-10s %-10s %-10s %-10s\n" "Interface" "IP Address" "MAC Address" "RX Bytes" "TX Bytes" "RX Packets" "TX Packets"
    echo "--------------------------------------------------------------------------------"

    # Process each interface
    for iface in $interfaces; do
        # Validate interface name to prevent command injection
        if [[ ! "$iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
            echo "Invalid interface name: $iface" >&2
            continue
        fi

        # Get IP address
        local ip=$(ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

        # Get MAC address
        local mac=$(cat /sys/class/net/$iface/address)

        # Get RX/TX bytes and packets
        local rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes)
        local tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes)
        local rx_packets=$(cat /sys/class/net/$iface/statistics/rx_packets)
        local tx_packets=$(cat /sys/class/net/$iface/statistics/tx_packets)

        # Format output
        printf "%-10s %-15s %-15s %-10s %-10s %-10s %-10s\n" "$iface" "$ip" "$mac" "$rx_bytes" "$tx_bytes" "$rx_packets" "$tx_packets"
    done
}

# Function to monitor network traffic in real-time
monitor_network() {
    local prev_rx=()
    local prev_tx=()
    local prev_time=0
    local interfaces=$(ls /sys/class/net | grep -v lo)

    # Initialize previous values
    for iface in $interfaces; do
        if [[ ! "$iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then continue; fi
        prev_rx[$iface]=$(cat /sys/class/net/$iface/statistics/rx_bytes)
        prev_tx[$iface]=$(cat /sys/class/net/$iface/statistics/tx_bytes)
    done
    prev_time=$(date +%s.%N)  # Get current time in seconds with nanoseconds

    # Clear screen and set up UI
    clear
    echo "=== Network Monitoring Tool ==="
    echo "Press Ctrl+C to exit"
    echo ""

    # Main monitoring loop
    while true; do
        # Store current position
        tput sc

        # Print static information
        get_network_info

        # Get current time and calculate time difference
        local curr_time=$(date +%s.%N)
        local time_diff=$(echo "$curr_time - $prev_time" | bc)
        prev_time=$curr_time

        # Print dynamic traffic information
        echo ""
        echo "Real-time Traffic:"
        printf "%-10s %-10s %-10s %-10s %-10s\n" "Interface" "RX KB/s" "TX KB/s" "RX MB/s" "TX MB/s"
        echo "------------------------------------------------------------"

        # Calculate and display traffic rates
        for iface in $interfaces; do
            if [[ ! "$iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then continue; fi
            
            local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
            local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)

            # Validate numeric input before bc processing to prevent injection
            if ! [[ "$rx" =~ ^[0-9]+$ ]] || ! [[ "$tx" =~ ^[0-9]+$ ]] || ! [[ "$time_diff" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                continue
            fi

            # Calculate differences in bytes safely using bc
            local rx_diff=$(echo "$rx - ${prev_rx[$iface]}" | bc)
            if (( $(echo "$rx_diff < 0" | bc -l) )); then rx_diff=0; fi

            local tx_diff=$(echo "$tx - ${prev_tx[$iface]}" | bc)
            if (( $(echo "$tx_diff < 0" | bc -l) )); then tx_diff=0; fi

            # Convert to KB/s (bytes/1024/time_diff)
            local rx_kbps=$(echo "scale=2; $rx_diff / 1024 / $time_diff" | bc)
            local tx_kbps=$(echo "scale=2; $tx_diff / 1024 / $time_diff" | bc)

            # Convert to MB/s (KB/1024)
            local rx_mbps=$(echo "scale=4; $rx_kbps / 1024" | bc)
            local tx_mbps=$(echo "scale=4; $tx_kbps / 1024" | bc)

            # Format output with proper decimal places
            printf "%-10s %-10.2f %-10.2f %-10.4f %-10.4f\n" "$iface" "$rx_kbps" "$tx_kbps" "$rx_mbps" "$tx_mbps"

            # Update previous values
            prev_rx[$iface]=$rx
            prev_tx[$iface]=$tx
        done

        # Restore position and wait
        tput rc
        
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

# Start monitoring
monitor_network
