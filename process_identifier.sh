#!/bin/bash

# Port Investigator Script
# Author: M3rlin
# Description: Scans for open ports and identifies services/processes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
check_command() {
	if ! command -v $1 &> /dev/null; then
		echo -e "${RED}Error: $1 is not installed. Please install it first.${NC}"
		exit 1
		fi
}

# Check dependencies
check_command "netstat"
check_command "lsof"
check_command "curl"
check_command "nmap"

# Function to scan local ports
scan_local_ports() {
	echo -e "${BLUE}=== SCANNING LOCAL OPEN PORTS ===${NC}"
	echo -e "${YELLOW}Listening TCP ports:${NC}"
	netstat -tuln | grep LISTEN | grep -v '127.0.0.1' | awk '{printf "%-8s %-15s %-10s\n", $1, $4, "0.0.0.0:*"}'
	netstat -tuln | grep LISTEN | grep '127.0.0.1' | awk '{printf "%-8s %-15s %-10s\n", $1, $4, "localhost:*"}'
	
	echo -e "\n${YELLOW}Listening UDP ports:${NC}"
	netstat -uln | grep LISTEN | awk '{printf "%-8s %-15s %-10s\n", $1, $4, "0.0.0.0:*"}'
}

# Function to identify processes on ports
identify_processes() {
	echo -e "\n${BLUE}=== IDENTIFYING PROCESSES ON PORTS ===${NC}"
	echo -e "${YELLOW}Processes using ports:${NC}"
	lsof -i -P -n | grep LISTEN | awk '{printf "%-8s %-15s %-30s %s\n", $1, $2, $8, $9}' | head -1
	lsof -i -P -n | grep LISTEN | awk '{printf "%-8s %-15s %-30s %s\n", $1, $2, $8, $9}' | tail -n +2
}

# Function for service enumeration
enumerate_services() {
	echo -e "\n${BLUE}=== SERVICE ENUMERATION ===${NC}"
	
	# Get all listening ports
	ports=$(netstat -tuln | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
	
	if [ -z "$ports" ]; then
		echo -e "${YELLOW}No open ports found for enumeration.${NC}"
		return
		fi
		
		echo -e "${YELLOW}Running detailed service detection on ports: $ports${NC}"
		nmap -sV -p $ports localhost
}

# Function to check web services
check_web_services() {
	echo -e "\n${BLUE}=== WEB SERVICE ANALYSIS ===${NC}"
	
	# Find HTTP/HTTPS ports
	web_ports=$(netstat -tuln | grep LISTEN | awk '{print $4}' | grep -E ':80$|:443$|:8080$|:8443$|:8888$|:9000$|:3000$|:3001$')
	
	for port_info in $web_ports; do
		port=$(echo $port_info | awk -F: '{print $NF}')
		echo -e "${YELLOW}Checking port $port:${NC}"
		
		# Try HTTP first
		if curl -s -I -m 5 "http://localhost:$port" > /tmp/curl_output 2>&1; then
			echo -e "${GREEN}HTTP service detected on port $port${NC}"
			grep -i "server:\|x-powered-by:\|content-type:" /tmp/curl_output || echo "No identifying headers found"
			# Try HTTPS
			elif curl -s -I -k -m 5 "https://localhost:$port" > /tmp/curl_output 2>&1; then
			echo -e "${GREEN}HTTPS service detected on port $port${NC}"
			grep -i "server:\|x-powered-by:\|content-type:" /tmp/curl_output || echo "No identifying headers found"
			else
				echo -e "${YELLOW}No web service detected on port $port${NC}"
				fi
				echo "---"
				done
				rm -f /tmp/curl_output
}

# Function to generate summary
generate_summary() {
	echo -e "\n${BLUE}=== SECURITY SUMMARY ===${NC}"
	echo -e "${YELLOW}Potentially sensitive services found:${NC}"
	
	# Check for common services that might need attention
	sensitive_ports=$(netstat -tuln | grep LISTEN | awk '{print $4}' | grep -E ':21$|:22$|:23$|:25$|:53$|:110$|:135$|:139$|:143$|:445$|:993$|:995$|:1433$|:3306$|:3389$|:5432$|:5900$|:27017$')
	
	if [ -n "$sensitive_ports" ]; then
		for port in $sensitive_ports; do
			echo -e "${RED}WARNING: Potentially sensitive service on $port${NC}"
			done
			else
				echo -e "${GREEN}No obviously sensitive services detected${NC}"
				fi
}

# Main execution
echo -e "${GREEN}Starting Port Investigation...${NC}"
echo -e "${YELLOW}Current time: $(date)${NC}"
echo -e "${YELLOW}Hostname: $(hostname)${NC}"
echo ""

scan_local_ports
identify_processes
enumerate_services
check_web_services
generate_summary

echo -e "\n${GREEN}Scan completed!${NC}"
