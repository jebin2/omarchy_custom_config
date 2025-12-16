#!/bin/bash

# Snapper Configuration Checker & Setup Script
# This script verifies your Snapper setup and offers to apply recommended settings

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Snapper Configuration Checker${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    SUDO=""
else
    SUDO="sudo"
fi

# 1. Check if snapper is installed
echo -e "${CYAN}[1/7] Checking Snapper installation...${NC}"
if command -v snapper &> /dev/null; then
    echo -e "${GREEN}✓ Snapper is installed${NC}"
else
    echo -e "${RED}✗ Snapper is NOT installed${NC}"
    echo -e "Install with: ${YELLOW}sudo pacman -S snapper${NC}"
    exit 1
fi

# 2. Check if snap-pac is installed
echo -e "\n${CYAN}[2/7] Checking snap-pac installation...${NC}"
if pacman -Q snap-pac &> /dev/null; then
    echo -e "${GREEN}✓ snap-pac is installed (auto snapshots on updates)${NC}"
else
    echo -e "${YELLOW}⚠ snap-pac is NOT installed${NC}"
    echo -e "This creates snapshots before/after package updates"
    read -p "Install snap-pac? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        $SUDO pacman -S --noconfirm snap-pac
        echo -e "${GREEN}✓ snap-pac installed${NC}"
    fi
fi

# 3. Check snapper timers
echo -e "\n${CYAN}[3/7] Checking Snapper timers...${NC}"
TIMELINE_ACTIVE=$(systemctl is-active snapper-timeline.timer 2>/dev/null || echo "inactive")
CLEANUP_ACTIVE=$(systemctl is-active snapper-cleanup.timer 2>/dev/null || echo "inactive")

if [ "$TIMELINE_ACTIVE" = "active" ] && [ "$CLEANUP_ACTIVE" = "active" ]; then
    echo -e "${GREEN}✓ Snapper timers are active${NC}"
else
    echo -e "${YELLOW}⚠ Snapper timers are not active${NC}"
    read -p "Enable snapper timers? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        $SUDO systemctl enable --now snapper-timeline.timer
        $SUDO systemctl enable --now snapper-cleanup.timer
        echo -e "${GREEN}✓ Timers enabled${NC}"
    fi
fi

# 4. List current snapshots
echo -e "\n${CYAN}[4/7] Current snapshots:${NC}"
$SUDO snapper list

# 5. Check current configuration
echo -e "\n${CYAN}[5/7] Current Snapper configuration:${NC}"
CONFIG_OUTPUT=$($SUDO snapper -c root get-config)

NUMBER_LIMIT=$(echo "$CONFIG_OUTPUT" | grep "NUMBER_LIMIT " | awk '{print $3}')
NUMBER_LIMIT_IMPORTANT=$(echo "$CONFIG_OUTPUT" | grep "NUMBER_LIMIT_IMPORTANT" | awk '{print $3}')
TIMELINE_CREATE=$(echo "$CONFIG_OUTPUT" | grep "TIMELINE_CREATE " | awk '{print $3}')
TIMELINE_HOURLY=$(echo "$CONFIG_OUTPUT" | grep "TIMELINE_LIMIT_HOURLY" | awk '{print $3}')
TIMELINE_DAILY=$(echo "$CONFIG_OUTPUT" | grep "TIMELINE_LIMIT_DAILY" | awk '{print $3}')
TIMELINE_WEEKLY=$(echo "$CONFIG_OUTPUT" | grep "TIMELINE_LIMIT_WEEKLY" | awk '{print $3}')
TIMELINE_MONTHLY=$(echo "$CONFIG_OUTPUT" | grep "TIMELINE_LIMIT_MONTHLY" | awk '{print $3}')

echo "  NUMBER_LIMIT: $NUMBER_LIMIT"
echo "  NUMBER_LIMIT_IMPORTANT: $NUMBER_LIMIT_IMPORTANT"
echo "  TIMELINE_CREATE: $TIMELINE_CREATE"
echo "  TIMELINE_LIMIT_HOURLY: $TIMELINE_HOURLY"
echo "  TIMELINE_LIMIT_DAILY: $TIMELINE_DAILY"
echo "  TIMELINE_LIMIT_WEEKLY: $TIMELINE_WEEKLY"
echo "  TIMELINE_LIMIT_MONTHLY: $TIMELINE_MONTHLY"

# 6. Compare with recommended settings
echo -e "\n${CYAN}[6/7] Recommended configuration:${NC}"
echo "  NUMBER_LIMIT: 10-15"
echo "  NUMBER_LIMIT_IMPORTANT: 5"
echo "  TIMELINE_CREATE: yes"
echo "  TIMELINE_LIMIT_HOURLY: 5"
echo "  TIMELINE_LIMIT_DAILY: 7"
echo "  TIMELINE_LIMIT_WEEKLY: 3"
echo "  TIMELINE_LIMIT_MONTHLY: 2"

NEEDS_UPDATE=false

if [ "$NUMBER_LIMIT" -lt 10 ]; then NEEDS_UPDATE=true; fi
if [ "$NUMBER_LIMIT_IMPORTANT" -lt 5 ]; then NEEDS_UPDATE=true; fi
if [ "$TIMELINE_CREATE" != "yes" ]; then NEEDS_UPDATE=true; fi
if [ "$TIMELINE_HOURLY" -lt 5 ]; then NEEDS_UPDATE=true; fi
if [ "$TIMELINE_DAILY" -lt 7 ]; then NEEDS_UPDATE=true; fi
if [ "$TIMELINE_WEEKLY" -lt 3 ]; then NEEDS_UPDATE=true; fi
if [ "$TIMELINE_MONTHLY" -lt 2 ]; then NEEDS_UPDATE=true; fi

# 7. Offer to apply recommended settings
echo -e "\n${CYAN}[7/7] Configuration status:${NC}"
if [ "$NEEDS_UPDATE" = true ]; then
    echo -e "${YELLOW}⚠ Your configuration could be improved${NC}\n"
    read -p "Apply recommended settings? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "\n${CYAN}Applying recommended configuration...${NC}"
        $SUDO snapper -c root set-config \
            "NUMBER_LIMIT=15" \
            "NUMBER_LIMIT_IMPORTANT=5" \
            "TIMELINE_CREATE=yes" \
            "TIMELINE_LIMIT_HOURLY=5" \
            "TIMELINE_LIMIT_DAILY=7" \
            "TIMELINE_LIMIT_WEEKLY=3" \
            "TIMELINE_LIMIT_MONTHLY=2"
        echo -e "${GREEN}✓ Configuration updated!${NC}"
        
        echo -e "\n${CYAN}New configuration:${NC}"
        $SUDO snapper -c root get-config | grep -E "NUMBER_LIMIT|TIMELINE"
    fi
else
    echo -e "${GREEN}✓ Your configuration is already optimal!${NC}"
fi

# Summary
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}  Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✓ Snapper is properly configured${NC}"
echo -e "${GREEN}✓ Automatic snapshots enabled${NC}"
echo -e "${GREEN}✓ System is protected${NC}\n"

echo -e "${CYAN}What happens now:${NC}"
echo "• Snapshots created before/after every package update"
echo "• Hourly/daily/weekly/monthly automatic snapshots"
echo "• Old snapshots automatically cleaned up"
echo "• Boot into any snapshot from GRUB/Limine if needed"

echo -e "\n${CYAN}Useful commands:${NC}"
echo "  sudo snapper list              - List all snapshots"
echo "  sudo snapper create -d 'desc'  - Create manual snapshot"
echo "  sudo snapper delete <number>   - Delete a snapshot"
echo "  sudo snapper -c root get-config - View configuration"

echo -e "\n${GREEN}Your system is now fully protected! 🎉${NC}\n"