#!/bin/bash

# Get hostname and timestamp as log file name
HOSTNAME=$(hostname | tr -cd '[:alnum:]_-')
LOGFILE="mellanox_nic_recovery_${HOSTNAME}_$(date +%Y%m%d_%H%M%S).log"

# Initialize log and record the info
echo "Mellanox NIC Recovery Script Log" > "$LOGFILE"
echo "Hostname: $HOSTNAME" >> "$LOGFILE"
echo "Log started at: $(date)" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# find Mellanox's PCIE BDF info by lspci
readarray -t mellanox_bdfs < <(lspci | grep -i "Mellanox Technologies Device 1021" | awk '{print $1}')

if [ ${#mellanox_bdfs[@]} -eq 0 ]; then
    echo "No Mellanox PCIe devices found." >> "$LOGFILE"
else
    echo "Detected Mellanox NICs:" >> "$LOGFILE"
    printf "%s\n" "${mellanox_bdfs[@]}" >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    for bdf in "${mellanox_bdfs[@]}"; do
        echo "Checking NIC at BDF $bdf:" >> "$LOGFILE"
        status=$(sudo mlxlink -d "$bdf" | grep -oP 'State\s+:\s*\K.*' | sed -r 's/\x1B\[[0-9;]*m//g; s/[ \t\r\n]*$//')
        echo "Checking NIC at BDF $bdf and current status is $status"
        if [[ "$status" != "Active" ]]; then
            echo "NIC is not Active (current state: $status). Attempting recovery..."
            echo "NIC is not Active (current state: $status). Attempting recovery..." >> "$LOGFILE"

            # try to reset port
            sudo mlxreg -d "$bdf" --set "admin_status=0xe,ase=1" --reg_name PMAOS --indexes "module=0,slot_index=0" -y >> "$LOGFILE" 2>&1
            sleep 5
            sudo mlxreg -d "$bdf" --set "admin_status=0x1,ase=1" --reg_name PMAOS --indexes "module=0,slot_index=0" -y >> "$LOGFILE" 2>&1
			sleep 5
			sudo mlxreg -d "$bdf" --set "admin_status=0xe,ase=1" --reg_name PMAOS --indexes "module=1,slot_index=0" -y >> "$LOGFILE" 2>&1
            sleep 5
            sudo mlxreg -d "$bdf" --set "admin_status=0x1,ase=1" --reg_name PMAOS --indexes "module=1,slot_index=0" -y >> "$LOGFILE" 2>&1
            sleep 2
			# check status again
            new_status=$(sudo mlxlink -d "$bdf" | grep -oP 'State\s+:\s*\K.*' | sed -r 's/\x1B\[[0-9;]*m//g; s/[ \t\r\n]*$//')
            if [[ "$new_status" == "Active" ]]; then
                echo "Recovery successful. New state: $new_status"
                echo "Recovery successful. New state: $new_status" >> "$LOGFILE"
            else
                echo "Recovery unsuccessful. State remains: $new_status"
                echo "Recovery unsuccessful. State remains: $new_status" >> "$LOGFILE"
            fi
        else
            echo "NIC is already Active." >> "$LOGFILE"
        fi
        sudo mlxlink -d "$bdf" -m -e -c --rx_fec_histogram --show_histogram --cable --dump >> "$LOGFILE"
        echo "-----------------------------" >> "$LOGFILE"
        echo "" >> "$LOGFILE"
    done
fi

echo "Script completed at: $(date)" >> "$LOGFILE"
echo "Log saved to: $LOGFILE"

# end operations
echo "Please check the log file for details: $LOGFILE"