# sniffle_sonoff_autoflasher
Script to auto-detect the correct firmware type for Sonoff Zigbee USB Dongle Based on TI CC2652P + CP2102(N), download and flash the Sniffle Firmware.

Currently hardcoded to download/flash FW 1.10: https://github.com/nccgroup/Sniffle/releases/tag/v1.10.0

Sniffle Fork with DroneID Detection: https://github.com/bkerler/Sniffle

Compatible Dongle (Make sure Description says Based on TI CC2652P + CP2102N): https://a.co/d/679NcQk

## Use

1. Plug USB Dongle you want to flash into computer (suggest you do not have any other USB devices connected except keyboard/mouse)
2. Clone this repo
3. Make the script executable and run it:

`sudo chmod +x sonoffSniffleFlasher.sh && ./sonoffSniffleFlasher.sh`

## What the script does

1. Checks for system requirements, installs them if missing
2. Adds user to `dialout` group so it can communicate with USB devices
3. Detect the chip type to download the correct firmware (CP2102 (Non-N variant) Baud rate limited to 921600, most seem to use this slower chip sadly)
4. Confirm that the user wants to flash the new firmware to the device before we flash it


## Example Use

```
ℹ️  🔍 Checking for required system dependencies...
✅ 'usb-devices' is already installed.
✅ 'wget' is already installed.
✅ 'git' is already installed.
✅ 'python3' is already installed.
✅ ✅ All required system dependencies are installed.

ℹ️  🔍 Checking if pip3 is installed...
✅ pip3 is already installed.

ℹ️  🔍 Checking for required Python packages...
✅ All required Python packages are already installed.
✅ /home/myUser/.local/bin is already in PATH.
✅ User 'myUser' is already in the 'dialout' group.

ℹ️  🔍 Verifying that all dependencies are met after setup...
✅ ✅ All dependencies are confirmed after setup.

ℹ️  🔍 Detecting USB/UART bridge chip on Sonoff Zigbee 3.0 USB Dongle Plus...
✅ CP2102 (Non-N variant) detected. Baud rate limited to 921600.
📥 Do you want to download the appropriate firmware and flash it now? (y/n): y

ℹ️  📥 Downloading firmware from https://github.com/nccgroup/Sniffle/releases/download/v1.10.0/sniffle_cc1352p1_cc2652p1_1M.hex to /tmp/sniffle_firmware/sniffle_cc1352p1_cc2652p1_1M.hex ...
✅ Firmware downloaded successfully: /tmp/sniffle_firmware/sniffle_cc1352p1_cc2652p1_1M.hex

ℹ️  📥 Cloning cc2538-bsl project from https://github.com/sultanqasim/cc2538-bsl.git to /tmp/cc2538-bsl ...
Cloning into '/tmp/cc2538-bsl'...
remote: Enumerating objects: 496, done.
remote: Counting objects: 100% (173/173), done.
remote: Compressing objects: 100% (44/44), done.
remote: Total 496 (delta 154), reused 129 (delta 129), pack-reused 323 (from 2)
Receiving objects: 100% (496/496), 153.43 KiB | 5.11 MiB/s, done.
Resolving deltas: 100% (233/233), done.
✅ cc2538-bsl project cloned successfully.

ℹ️  📂 Moving firmware file /tmp/sniffle_firmware/sniffle_cc1352p1_cc2652p1_1M.hex to /tmp/cc2538-bsl ...
✅ Firmware file moved successfully.
⚠️  Are you sure you want to flash the firmware? This may brick your device if interrupted. (y/n): y

ℹ️  ⚡ Flashing firmware using cc2538-bsl...
sonoff
Opening port /dev/ttyUSB0, baud 500000
Reading data from sniffle_cc1352p1_cc2652p1_1M.hex
Your firmware looks like an Intel Hex file
Connecting to target...
CC1350 PG2.1 (7x7mm): 352KB Flash, 20KB SRAM, CCFG.BL_CONFIG at 0x00057FD8
Primary IEEE Address: 00:12:4B:00:2F:89:8C:FD
    Performing mass erase
Erasing all main bank flash sectors
    Erase done
Writing 360448 bytes starting at address 0x00000000
Write 104 bytes at 0x00057F980
    Write done                                
Verifying by comparing CRC32 calculations.
    Verified (match: 0x26e6c6f2)
✅ Firmware flashed successfully.

ℹ️  🗑️  Cleaning up downloaded firmware and cloned project...
✅ Cleanup completed.
✅ ✅ Operation completed successfully.
```
