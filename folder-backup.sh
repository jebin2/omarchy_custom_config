#!/bin/bash

# Simple Folder Backup Script
# Backs up specific folders to USB drive

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Simple Folder Backup Tool${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Function to get human-readable size
get_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# 1. Show available external drives
echo -e "${CYAN}[1/4] Available external drives:${NC}"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -E "sda|sdb|sdc" || echo "No external drives detected"
echo ""

# Get USB mount point
echo -e "${YELLOW}Enter USB drive mount point:${NC}"
echo -e "${CYAN}Example: /run/media/jebin/JEBIN${NC}"
read -p "Path: " USB_MOUNT

if [ ! -d "$USB_MOUNT" ]; then
    echo -e "${RED}Directory $USB_MOUNT not found!${NC}"
    exit 1
fi

# Check available space
AVAILABLE_SPACE=$(df -BG "$USB_MOUNT" | tail -1 | awk '{print $4}' | sed 's/G//')
echo -e "${GREEN}✓ USB found with ${AVAILABLE_SPACE}GB available${NC}\n"

# 2. Select folder to backup
echo -e "${CYAN}[2/4] What do you want to backup?${NC}"
echo "  1) /home/jebin/git"
echo "  2) Custom folder path"
echo "  3) Multiple folders"
read -p "Choice [1-3]: " FOLDER_CHOICE

FOLDERS_TO_BACKUP=()

case $FOLDER_CHOICE in
    1)
        FOLDERS_TO_BACKUP=("/home/jebin/git")
        ;;
    2)
        echo -e "${YELLOW}Enter full path to folder:${NC}"
        read -p "Path: " CUSTOM_PATH
        if [ ! -d "$CUSTOM_PATH" ]; then
            echo -e "${RED}Folder not found!${NC}"
            exit 1
        fi
        FOLDERS_TO_BACKUP=("$CUSTOM_PATH")
        ;;
    3)
        echo -e "${YELLOW}Enter folder paths separated by spaces:${NC}"
        echo -e "${CYAN}Example: /home/jebin/git /home/jebin/Documents${NC}"
        read -p "Paths: " -a FOLDERS_TO_BACKUP
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Check folder sizes
echo -e "\n${CYAN}Calculating sizes...${NC}"
TOTAL_SIZE=0
for FOLDER in "${FOLDERS_TO_BACKUP[@]}"; do
    if [ -d "$FOLDER" ]; then
        SIZE=$(get_size "$FOLDER")
        echo "  $FOLDER: $SIZE"
    else
        echo -e "${RED}  ✗ $FOLDER not found${NC}"
    fi
done

# 3. Backup method
echo -e "\n${CYAN}[3/4] Select backup method:${NC}"
echo "  1) Compressed archive (.tar.gz) - Smaller, slower"
echo "  2) Direct copy (rsync) - Faster, keeps structure"
echo "  3) Incremental backup (rsync) - Updates existing backup"
read -p "Choice [1-3]: " BACKUP_METHOD

# Create backup directory
BACKUP_BASE="$USB_MOUNT/backups"
mkdir -p "$BACKUP_BASE"

# 4. Perform backup
echo -e "\n${CYAN}[4/4] Creating backup...${NC}\n"

BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
SUCCESS_COUNT=0
FAIL_COUNT=0

for FOLDER in "${FOLDERS_TO_BACKUP[@]}"; do
    if [ ! -d "$FOLDER" ]; then
        echo -e "${RED}✗ Skipping $FOLDER (not found)${NC}"
        ((FAIL_COUNT++))
        continue
    fi
    
    FOLDER_NAME=$(basename "$FOLDER")
    echo -e "${CYAN}Backing up: $FOLDER${NC}"
    
    case $BACKUP_METHOD in
        1)
            # Compressed archive
            BACKUP_FILE="$BACKUP_BASE/${FOLDER_NAME}_${BACKUP_DATE}.tar.gz"
            echo "  Creating archive: ${FOLDER_NAME}_${BACKUP_DATE}.tar.gz"
            
            if tar -czf "$BACKUP_FILE" -C "$(dirname "$FOLDER")" "$FOLDER_NAME" 2>/dev/null; then
                SIZE=$(get_size "$BACKUP_FILE")
                echo -e "${GREEN}  ✓ Backed up: $SIZE${NC}"
                
                # Create info file
                cat > "${BACKUP_FILE}.info" << EOF
Original Path: $FOLDER
Backup Date: $(date)
Backup Size: $SIZE
Method: Compressed Archive
Restore Command: tar -xzf $(basename "$BACKUP_FILE") -C /destination/
EOF
                ((SUCCESS_COUNT++))
            else
                echo -e "${RED}  ✗ Backup failed${NC}"
                ((FAIL_COUNT++))
            fi
            ;;
            
        2)
            # Direct copy
            BACKUP_DIR="$BACKUP_BASE/${FOLDER_NAME}_${BACKUP_DATE}"
            echo "  Copying to: ${FOLDER_NAME}_${BACKUP_DATE}/"
            
            if rsync -ah --info=progress2 "$FOLDER/" "$BACKUP_DIR/" 2>/dev/null; then
                SIZE=$(get_size "$BACKUP_DIR")
                echo -e "${GREEN}  ✓ Backed up: $SIZE${NC}"
                
                # Create info file
                cat > "${BACKUP_DIR}.info" << EOF
Original Path: $FOLDER
Backup Date: $(date)
Backup Size: $SIZE
Method: Direct Copy
Restore Command: rsync -a $(basename "$BACKUP_DIR")/ /destination/
EOF
                ((SUCCESS_COUNT++))
            else
                echo -e "${RED}  ✗ Backup failed${NC}"
                ((FAIL_COUNT++))
            fi
            ;;
            
        3)
            # Incremental backup
            BACKUP_DIR="$BACKUP_BASE/${FOLDER_NAME}_latest"
            echo "  Syncing to: ${FOLDER_NAME}_latest/"
            
            if rsync -ah --info=progress2 --delete "$FOLDER/" "$BACKUP_DIR/" 2>/dev/null; then
                SIZE=$(get_size "$BACKUP_DIR")
                echo -e "${GREEN}  ✓ Synced: $SIZE${NC}"
                
                # Update info file
                cat > "${BACKUP_DIR}.info" << EOF
Original Path: $FOLDER
Last Sync: $(date)
Backup Size: $SIZE
Method: Incremental Sync
Restore Command: rsync -a $(basename "$BACKUP_DIR")/ /destination/
EOF
                ((SUCCESS_COUNT++))
            else
                echo -e "${RED}  ✗ Sync failed${NC}"
                ((FAIL_COUNT++))
            fi
            ;;
    esac
    echo ""
done

# Create restore instructions
cat > "$BACKUP_BASE/RESTORE-INSTRUCTIONS.txt" << 'EOF'
========================================
HOW TO RESTORE YOUR BACKUPS
========================================

For .tar.gz archives:
---------------------
1. Navigate to where you want to restore
2. Extract the archive:
   tar -xzf backup_file.tar.gz

For directory backups:
----------------------
1. Copy back to original location:
   rsync -a backup_folder/ /home/jebin/original_location/

For incremental backups:
------------------------
1. Sync back:
   rsync -a folder_latest/ /home/jebin/original_location/

IMPORTANT:
----------
- Check .info files for original paths
- Test restores with a small file first
- Keep multiple backup versions
- Verify backup integrity regularly

Quick verification:
-------------------
For archives: tar -tzf backup.tar.gz | head
For folders: ls -la backup_folder/
EOF

# Summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Backup Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✓ Successful: $SUCCESS_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}✗ Failed: $FAIL_COUNT${NC}"
fi

TOTAL_BACKUP=$(get_size "$BACKUP_BASE")
echo -e "${CYAN}Total backup size: $TOTAL_BACKUP${NC}"
echo -e "${CYAN}Backup location: $BACKUP_BASE${NC}\n"

echo -e "${GREEN}Backups created:${NC}"
ls -lh "$BACKUP_BASE" | grep -v "^total" | grep -v "RESTORE"

echo -e "\n${CYAN}Files in backup location:${NC}"
find "$BACKUP_BASE" -maxdepth 1 -type f -o -type d | tail -n +2 | while read file; do
    echo "  $(basename "$file")"
done

echo -e "\n${YELLOW}Read RESTORE-INSTRUCTIONS.txt for restore steps${NC}"
echo -e "${GREEN}Backup complete! 🎉${NC}\n"

# Offer to create a quick restore script
read -p "Create quick restore script? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    RESTORE_SCRIPT="$BACKUP_BASE/quick-restore.sh"
    cat > "$RESTORE_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Quick Restore Script

echo "Available backups:"
ls -1 | grep -E "\.tar\.gz$|_[0-9]{8}"

echo ""
read -p "Enter backup name to restore: " BACKUP_NAME
read -p "Enter destination path: " DEST_PATH

if [[ $BACKUP_NAME == *.tar.gz ]]; then
    echo "Extracting $BACKUP_NAME to $DEST_PATH..."
    tar -xzf "$BACKUP_NAME" -C "$DEST_PATH"
else
    echo "Copying $BACKUP_NAME to $DEST_PATH..."
    rsync -a "$BACKUP_NAME/" "$DEST_PATH/"
fi

echo "Restore complete!"
SCRIPT_EOF
    
    chmod +x "$RESTORE_SCRIPT"
    echo -e "${GREEN}✓ Created quick-restore.sh${NC}"
fi

echo -e "\n${CYAN}Keep your USB drive safe!${NC} 💾\n"