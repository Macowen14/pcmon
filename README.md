# PCMon - System Monitoring Agent

## Project Overview & Purpose

PCMon is a lightweight, terminal-based system monitoring solution designed for real-time observation of critical system resources. The agent provides comprehensive visibility into CPU utilization, memory consumption, process activity, and network traffic through an efficient terminal interface.

The project consists of two primary monitoring components:
- **CPU & Memory Monitor** (`cpu.sh`) - Tracks processor utilization, memory usage, and active processes
- **Network Monitor** (`netmon.sh`) - Monitors interface statistics and real-time traffic patterns

Designed for system administrators, DevOps engineers, and performance analysts, PCMon offers immediate insights into system health without requiring complex installation or resource-intensive GUI applications.

## Architecture & Key Components

### Core Architecture
```
┌───────────────────────────────────────────────────┐
│                   PCMon Agent                     │
├───────────────────┬───────────────────┬───────────┤
│   CPU Monitor     │  Network Monitor  │  Terminal │
│  (cpu.sh)         │  (netmon.sh)      │  Manager  │
└─────────┬─────────┴─────────┬─────────┴─────┬─────┘
          │                   │               │
┌─────────▼─────────┐ ┌───────▼───────┐ ┌─────▼─────┐
│ /proc/stat        │ │ /sys/class/  │ │ tput      │
│ /proc/meminfo     │ │ net/         │ │ ANSI      │
│ /proc/[pid]/stat  │ │ iproute2     │ │ Terminal  │
└───────────────────┘ └───────────────┘ └───────────┘
```

### Key Components

1. **Data Collection Layer**
   - `/proc` filesystem interface for CPU and memory metrics
   - `/sys/class/net/` interface for network statistics
   - `ps` command for process enumeration

2. **Processing Engine**
   - Differential analysis for rate calculations
   - Statistical aggregation
   - Threshold-based alerting

3. **Presentation Layer**
   - Terminal positioning via `tput`
   - ANSI color coding for visual alerts
   - Dynamic layout adjustment

4. **Control System**
   - Signal handling for graceful termination
   - Real-time refresh loop
   - Terminal state management

## Installation & Execution

### Prerequisites
- Linux-based operating system (tested on kernel 3.10+)
- Bash shell (version 4.0+ recommended)
- Core utilities: `awk`, `bc`, `tput`, `iproute2`
- Standard POSIX tools: `ps`, `date`, `sleep`

### Installation Steps

1. Clone the repository or download the monitoring scripts:
```bash
git clone https://github.com/Macowen14/pcmon.git
cd pcmon
```

2. Make scripts executable:
```bash
chmod +x cpu.sh netmon.sh
```

3. (Optional) Install system-wide:
```bash
sudo cp cpu.sh netmon.sh /usr/local/bin/
```

### Running the Agent

**CPU & Memory Monitor:**
```bash
./cpu.sh
```

**Network Monitor:**
```bash
./netmon.sh
```

**Run both monitors in parallel (recommended):**
```bash
./cpu.sh & ./netmon.sh
```

## Configuration Options

### Environment Variables

| Variable          | Description                          | Default Value |
|-------------------|--------------------------------------|---------------|
| `PCMON_REFRESH`   | Refresh interval in seconds          | 1             |
| `PCMON_CPU_THRESH`| CPU usage warning threshold (%)      | 90            |
| `PCMON_MEM_THRESH`| Memory usage warning threshold (%)   | 90            |
| `PCMON_PROC_LIMIT`| Maximum processes to display         | 20            |

### Model Settings

**CPU Monitor Configuration:**
```bash
# Adjust thresholds by setting environment variables
export PCMON_CPU_THRESH=85
export PCMON_MEM_THRESH=80
export PCMON_REFRESH=2
./cpu.sh
```

**Network Monitor Configuration:**
```bash
# Customize refresh rate
export PCMON_REFRESH=0.5
./netmon.sh
```

## Usage Examples & Workflow

### Basic Monitoring Session

1. **Start monitoring in separate terminals:**
```bash
# Terminal 1
./cpu.sh

# Terminal 2
./netmon.sh
```

2. **Monitor specific interface:**
```bash
./netmon.sh eth0
```

3. **Adjust refresh rate dynamically:**
```bash
PCMON_REFRESH=0.1 ./cpu.sh
```

### Advanced Workflows

**System Health Check:**
```bash
# Check system health before deployment
./cpu.sh | tee system_health_$(date +%Y%m%d).log
```

**Performance Benchmarking:**
```bash
# Monitor during load testing
PCMON_REFRESH=0.2 ./cpu.sh & ./netmon.sh & \
  stress-ng --cpu 4 --timeout 60s
```

**Remote Monitoring:**
```bash
# Pipe output through SSH
./cpu.sh | ssh user@monitoring-server "cat > /var/log/pcmon/$(hostname).log"
```

### Integration with Other Tools

**Combine with `watch` for periodic checks:**
```bash
watch -n 5 './cpu.sh | head -n 5'
```

**Log to file with timestamp:**
```bash
while true; do
  ./cpu.sh | awk '{print strftime("%Y-%m-%d %H:%M:%S"), $0}'
  sleep 1
done > monitor.log
```

## Terminal Interface Guide

### CPU Monitor Display

```
System: hostname | Uptime: 2 days, 3:45
CPU:  45.2% (4 cores) | Memory:  3.2G/7.8G (41%)
───────────────────────────────────────────────────
  PID  USER     %CPU %MEM    VSZ    RSS COMMAND
 1234  root     12.5  2.1  12345  6789 /usr/bin/Xorg
 5678  user     8.2   1.8  98765  4321 /opt/app/server
```

### Network Monitor Display

```
Interface: eth0 (00:1a:2b:3c:4d:5e)
IP: 192.168.1.100
───────────────────────────────────────────────────
RX: 12.45 MB (123456 pkts) | TX:  8.76 MB (98765 pkts)
Rate:  1.23 Mbps (RX) |  0.87 Mbps (TX)
```

### Color Coding Legend

| Color   | CPU Usage | Memory Usage | Network Traffic |
|---------|-----------|--------------|-----------------|
| Green   | <70%      | <70%         | Normal          |
| Yellow  | 70-90%    | 70-90%       | Elevated        |
| Red     | >90%      | >90%         | Critical        |

## Best Practices

1. **For Production Systems:**
   - Run monitors in `screen` or `tmux` sessions
   - Log output to files for historical analysis
   - Set appropriate thresholds for your environment

2. **For Development:**
   - Use faster refresh rates (0.1-0.5s) for real-time debugging
   - Combine with profiling tools like `perf` or `strace`

3. **For Security:**
   - Run with least privileges necessary
   - Monitor script execution with `auditd`
   - Validate all inputs when modifying scripts

## Troubleshooting

**Common Issues:**

1. **Terminal Display Problems:**
   - Ensure terminal supports ANSI color codes
   - Try `export TERM=xterm-256color`
   - Reduce terminal size if display wraps

2. **Permission Errors:**
   - Run with `sudo` if accessing restricted `/proc` or `/sys` files
   - Check file permissions on system files

3. **Missing Commands:**
   - Install required packages:
     ```bash
     sudo apt-get install procps iproute2 bc
     ```

4. **High CPU Usage:**
   - Increase refresh interval with `PCMON_REFRESH`
   - Reduce number of displayed processes

## Extensibility

The monitoring framework is designed for easy extension:

1. **Add New Metrics:**
   - Create additional data collection functions
   - Add display sections to the main loop

2. **Custom Alerts:**
   - Implement threshold-based notifications
   - Add email/SMS alerting via external scripts

3. **Data Export:**
   - Add JSON/XML output options
   - Implement database logging

4. **Plugin System:**
   - Create modular monitoring components
   - Implement configuration-based loading
