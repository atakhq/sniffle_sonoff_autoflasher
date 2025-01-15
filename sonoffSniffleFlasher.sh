#!/bin/bash

# flash_sonoff_dongle.sh
# A script to detect the USB/UART bridge chip on Sonoff Zigbee 3.0 USB Dongle Plus,
# install necessary dependencies, download the appropriate firmware to /tmp/,
# clone the cc2538-bsl project, move the firmware into the project folder,
# and flash it using the cc2538-bsl tool.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display error messages and exit
error_exit() {
    echo "❌ Error: $1" >&2
    exit 1
}

# Function to display informational messages
info() {
    echo "ℹ️  $1"
}

# Function to display success messages
success() {
    echo "✅ $1"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "'$1' command not found. Please install it and ensure it's in your PATH."
    fi
}

# Function to check if a Python package is installed
check_pip_package() {
    if ! pip3 show "$1" &> /dev/null; then
        return 1
    else
        return 0
    fi
}

# Function to check and install required system dependencies
check_dependencies() {
    info "🔍 Checking for required system dependencies..."
    REQUIRED_COMMANDS=("usb-devices" "wget" "git" "python3")
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            info "📦 '$cmd' not found. Installing '$cmd'..."
            sudo apt update
            case "$cmd" in
                python3)
                    sudo apt install -y python3 || error_exit "Failed to install python3."
                    ;;
                *)
                    sudo apt install -y "$cmd" || error_exit "Failed to install $cmd."
                    ;;
            esac
            success "'$cmd' installed successfully."
        else
            success "'$cmd' is already installed."
        fi
    done
    info "🔍 Checking for 'pip3'..."
    if ! command -v pip3 &> /dev/null; then
        info "'pip3' not found. It will be installed in the setup environment."
    else
        success "'pip3' is already installed."
    fi
    success "✅ All required system dependencies are installed."
}

# Function to check and install pip3 if necessary
install_pip3() {
    info "🔍 Checking if pip3 is installed..."
    if ! command -v pip3 &> /dev/null; then
        info "📦 pip3 not found. Installing pip3..."
        sudo apt update
        sudo apt install -y python3-pip || error_exit "Failed to install pip3."
        success "pip3 installed successfully."
    else
        success "pip3 is already installed."
    fi
}

# Function to check and install required Python packages
install_python_packages() {
    REQUIRED_PACKAGES=("pyserial" "intelhex")
    MISSING_PACKAGES=()

    info "🔍 Checking for required Python packages..."

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! check_pip_package "$package"; then
            MISSING_PACKAGES+=("$package")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        info "📦 Installing missing Python packages: ${MISSING_PACKAGES[*]}..."
        pip3 install --user "${MISSING_PACKAGES[@]}" || error_exit "Failed to install Python packages: ${MISSING_PACKAGES[*]}"
        success "Python packages installed successfully."
    else
        success "All required Python packages are already installed."
    fi
}

# Function to ensure ~/.local/bin is in PATH
ensure_local_bin_in_path() {
    LOCAL_BIN="$HOME/.local/bin"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        info "🔧 Adding $LOCAL_BIN to PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        # Also add to .profile for non-interactive shells
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
        # Export for current session
        export PATH="$HOME/.local/bin:$PATH"
        success "$LOCAL_BIN added to PATH."
    else
        success "$LOCAL_BIN is already in PATH."
    fi
}

# Function to add user to dialout group if not already a member
add_user_to_dialout() {
    if groups "$USER" | grep &>/dev/null "\bdialout\b"; then
        success "User '$USER' is already in the 'dialout' group."
    else
        info "🔧 Adding user '$USER' to the 'dialout' group..."
        sudo usermod -aG dialout "$USER" || error_exit "Failed to add user to 'dialout' group."
        success "User '$USER' added to 'dialout' group."

        # Refresh group memberships without logging out
        info "🔄 Refreshing group memberships..."
        # This will replace the current shell with a new one with updated group memberships
        exec sg dialout "$0 $@"
        # Note: The script will restart here with updated group memberships
    fi
}

# Function to check and install all environment setup
setup_environment() {
    install_pip3
    install_python_packages
    ensure_local_bin_in_path
    add_user_to_dialout
}

# Function to detect the chip type
detect_chip() {
    # Use awk to parse usb-devices output into blocks separated by blank lines
    # Look for blocks with Vendor=10c4 and Driver=cp210x
    usb_info=$(usb-devices | awk '
    BEGIN { RS="" }
    /Vendor=10c4/ && /Driver=cp210x/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /^ProdID=/) {
                split($i, a, "=")
                pid = a[2]
            }
        }
        print pid
    }')

    if [[ -z "$usb_info" ]]; then
        error_exit "No Sonoff Zigbee 3.0 USB Dongle Plus detected with Vendor ID=10c4 and Driver=cp210x. Please ensure your dongle is connected."
    fi

    # Now, usb_info should contain the PID
    pid="$usb_info"

    # Determine chip type based on PID
    case "$pid" in
        ea60)
            echo "✅ CP2102 (Non-N variant) detected. Baud rate limited to 921600."
            chip_type="CP2102"
            firmware_url="https://github.com/nccgroup/Sniffle/releases/download/v1.10.0/sniffle_cc1352p1_cc2652p1_1M.hex"
            baud_rate="921600"
            firmware_file="sniffle_cc1352p1_cc2652p1_1M.hex"
            ;;
        ea70)
            echo "✅ CP2102N (N variant) detected. Supports higher baud rates."
            chip_type="CP2102N"
            firmware_url="https://github.com/nccgroup/Sniffle/releases/download/v1.10.0/sniffle_cc1352p1_cc2652p1.hex"
            baud_rate="2000000"
            firmware_file="sniffle_cc1352p1_cc2652p1.hex"
            ;;
        *)
            error_exit "❌ Unrecognized Product ID (PID=0x$pid). Cannot determine chip type."
            ;;
    esac
}

# Function to download firmware to /tmp/
download_firmware() {
    local url="$1"
    local output_dir="/tmp/sniffle_firmware"
    local output_file="$output_dir/$(basename "$url")"

    # Create the output directory if it doesn't exist
    mkdir -p "$output_dir"

    info "📥 Downloading firmware from $url to $output_file ..."
    wget -q -O "$output_file" "$url" || error_exit "❌ Failed to download firmware."
    success "Firmware downloaded successfully: $output_file"

    # Export the path for use in flashing
    downloaded_firmware="$output_file"
}

# Function to clone the cc2538-bsl project
clone_bsl_project() {
    local repo_url="https://github.com/sultanqasim/cc2538-bsl.git"
    local clone_dir="/tmp/cc2538-bsl"

    if [[ -d "$clone_dir" ]]; then
        info "🗃️  Removing existing cc2538-bsl directory at $clone_dir ..."
        rm -rf "$clone_dir" || error_exit "❌ Failed to remove existing $clone_dir directory."
    fi

    info "📥 Cloning cc2538-bsl project from $repo_url to $clone_dir ..."
    git clone "$repo_url" "$clone_dir" || error_exit "❌ Failed to clone cc2538-bsl repository."
    success "cc2538-bsl project cloned successfully."

    # Export the clone directory for use in flashing
    bsl_project_dir="$clone_dir"
}

# Function to move firmware into the bsl project directory
move_firmware() {
    local firmware_source="$1"
    local destination_dir="$2"

    info "📂 Moving firmware file $firmware_source to $destination_dir ..."
    mv "$firmware_source" "$destination_dir/" || error_exit "❌ Failed to move firmware file."
    success "Firmware file moved successfully."
}

# Function to flash firmware using cc2538-bsl
flash_firmware() {
    local project_dir="$1"
    local firmware_file="$2"
    local baud="$3"
    local serial_port="/dev/ttyUSB0"

    info "⚡ Flashing firmware using cc2538-bsl..."

    # Navigate to the project directory
    cd "$project_dir" || error_exit "❌ Failed to navigate to $project_dir."

    # Execute the flashing command
    python3 cc2538-bsl.py -p "$serial_port" --bootloader-sonoff-usb -ewv "$firmware_file" || error_exit "❌ Failed to flash firmware."

    success "Firmware flashed successfully."
}

# Function to clean up downloaded firmware and cloned project (optional)
cleanup() {
    local firmware_file="$1"
    local project_dir="$2"

    info "🗑️  Cleaning up downloaded firmware and cloned project..."
    rm -f "$firmware_file" || echo "⚠️  Failed to remove $firmware_file."
    rm -rf "$project_dir" || echo "⚠️  Failed to remove $project_dir."
    success "Cleanup completed."
}

# Function to check and install all environment setup
setup_environment() {
    install_pip3
    install_python_packages
    ensure_local_bin_in_path
    add_user_to_dialout
}

# Main Execution Flow

# Step 1: Check for required dependencies
check_dependencies

# Step 2: Setup Environment
setup_environment

# Step 3: Check for remaining required dependencies (excluding pip3 and Python packages as they are handled)
check_dependencies_post_setup() {
    info "🔍 Verifying that all dependencies are met after setup..."
    REQUIRED_COMMANDS=("usb-devices" "wget" "git" "python3" "pip3")
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        check_command "$cmd"
    done
    success "✅ All dependencies are confirmed after setup."
}
check_dependencies_post_setup

# Step 4: Detect USB/UART bridge chip
info "🔍 Detecting USB/UART bridge chip on Sonoff Zigbee 3.0 USB Dongle Plus..."
detect_chip

# Step 5: Ask user if they want to download and flash the firmware
read -p "📥 Do you want to download the appropriate firmware and flash it now? (y/n): " user_choice

case "$user_choice" in
    [Yy]* )
        # Download firmware to /tmp/
        download_firmware "$firmware_url"

        # Clone the cc2538-bsl project
        clone_bsl_project

        # Move firmware into the bsl project directory
        move_firmware "$downloaded_firmware" "$bsl_project_dir"

        # Confirm before flashing
        read -p "⚠️  Are you sure you want to flash the firmware? This may brick your device if interrupted. (y/n): " confirm_flash
        case "$confirm_flash" in
            [Yy]* )
                # Flash the firmware
                flash_firmware "$bsl_project_dir" "$firmware_file" "$baud_rate"

                # Optional: Clean up after successful flashing
                cleanup "$bsl_project_dir/$firmware_file" "$bsl_project_dir"
                ;;
            * )
                info "🚫 Firmware flashing canceled by user."
                # Optionally, clean up downloaded firmware and cloned project
                cleanup "$downloaded_firmware" "$bsl_project_dir"
                exit 0
                ;;
        esac
        ;;
    [Nn]* )
        info "🚫 Firmware download and flashing skipped."
        exit 0
        ;;
    * )
        error_exit "❌ Invalid input. Exiting."
        ;;
esac

success "✅ Operation completed successfully."
