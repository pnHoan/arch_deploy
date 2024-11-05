#!/bin/bash

# ------------------ CONFIGURATION SECTION ------------------

# Define the list of packages to install
PACKAGES=("vim" "git" "curl" "htop")  # Add other packages as needed

# Default config directory if not specified
DEFAULT_CONFIG_DIR="./my_config"
DEFAULT_CONFIG_DEST="~/.config"

# Define additional scripts to execute
SCRIPTS_TO_RUN=("post_install.sh" "setup_environment.sh")  # Add any other scripts here

# Skip confirmation for pacman installs only
SKIP_CONFIRMATION=false  # Set to true for automatic install without user confirmation for pacman only

# Define the log file location
LOG_FILE="./setup_log.txt"

# Set the maximum number of retries for failed packages
RETRY_COUNT=3

# ------------------ END CONFIGURATION SECTION ------------------

# Initialize log file
echo "Starting setup process at $(date)" > "$LOG_FILE"
declare -A STATUS_TRACKER  # Tracks the success or failure of each stage

# Trap to handle unexpected exits
trap 'echo "Script interrupted. Check $LOG_FILE for details." | tee -a "$LOG_FILE"; exit 1' INT TERM

# install Paru
function select_aur_helper() {
    # if command -v paru &> /dev/null && command -v yay &> /dev/null; then
    #     read -p "Both 'paru' and 'yay' found. Which AUR helper would you like to use? (paru/yay): " AUR_HELPER
    #     if [ "$AUR_HELPER" != "paru" ] && [ "$AUR_HELPER" != "yay" ]; then
    #         echo "Invalid selection. Defaulting to 'paru'." | tee -a "$LOG_FILE"
    #         AUR_HELPER="paru"
    #     fi
    # elif command -v paru &> /dev/null; then
    #     AUR_HELPER="paru"
    #     echo "Using 'paru' for AUR installation." | tee -a "$LOG_FILE"
    # elif command -v yay &> /dev/null; then
    #     AUR_HELPER="yay"
    #     echo "Using 'yay' for AUR installation." | tee -a "$LOG_FILE"
    # else
    #     echo "No AUR helper found. Please install 'yay' or 'paru'." | tee -a "$LOG_FILE"
    #     exit 1
    # fi
    if command -v paru &> /dev/null; then
      AUR_HELPER="paru"
    else
      local script="paru.sh"
      echo "Installing PARU ... " | tee -a "$LOG_FILE"
      if [ -f "${script}"]; then
        bash "${script}" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
          echo "$script ran successfully." | tee -a "$LOG_FILE"
        else
          echo "Warning: $script encountered an error but the process will continue." | tee -a "$LOG_FILE"
        fi
        else
          echo "Warning: Script $script not found." | tee -a "$LOG_FILE"
      fi
 
    fi
}

# Install predefined packages with retry mechanism and pacman priority
function install_packages() {
    echo "Starting package installation..." | tee -a "$LOG_FILE"
    local retries=0
    local packages_to_install=("${PACKAGES[@]}")
    local failed_packages=()

    # Ensure AUR helper is selected
    select_aur_helper

    while [ ${#packages_to_install[@]} -gt 0 ] && [ $retries -lt $RETRY_COUNT ]; do
        echo "Attempt $(($retries + 1)) of $RETRY_COUNT..." | tee -a "$LOG_FILE"
        failed_packages=()

        for pkg in "${packages_to_install[@]}"; do
            if pacman -Si "$pkg" &> /dev/null; then
                if [ "$SKIP_CONFIRMATION" = true ]; then
                    sudo pacman -S --noconfirm "$pkg" >> "$LOG_FILE" 2>&1
                else
                    sudo pacman -S "$pkg" | tee -a "$LOG_FILE"
                fi
            else
                echo "$pkg not found in pacman. Attempting to install from AUR with $AUR_HELPER..." | tee -a "$LOG_FILE"
                $AUR_HELPER -S "$pkg" | tee -a "$LOG_FILE"
            fi

            # Check if the package was installed
            if ! pacman -Q "$pkg" &> /dev/null; then
                failed_packages+=("$pkg")
            fi
        done

        if [ ${#failed_packages[@]} -eq 0 ]; then
            echo "Packages installed successfully." | tee -a "$LOG_FILE"
            STATUS_TRACKER["install_packages"]="SUCCESS"
            break
        else
            echo "The following packages failed to install: ${failed_packages[*]}" | tee -a "$LOG_FILE"
            packages_to_install=("${failed_packages[@]}")
            retries=$((retries + 1))
        fi
    done

    # Check if retry attempts were exhausted
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        echo "Package installation failed after $RETRY_COUNT attempts." | tee -a "$LOG_FILE"
        STATUS_TRACKER["install_packages"]="FAIL"
    else
        STATUS_TRACKER["install_packages"]="SUCCESS"
    fi
}

# Copy configuration files or folders
function copy_configs() {
    local src_dir="${1:-$DEFAULT_CONFIG_DIR}"
    local dest_dir="${2:-$DEFAULT_CONFIG_DEST}"

    echo "Applying configuration from $src_dir to $dest_dir..." | tee -a "$LOG_FILE"
    if [ -d "$src_dir" ]; then
        cp -r "$src_dir"/* "$dest_dir"
        echo "Copied all files from $src_dir to $dest_dir" | tee -a "$LOG_FILE"
        STATUS_TRACKER["apply_config"]="SUCCESS"
    else
        echo "Source directory $src_dir does not exist." | tee -a "$LOG_FILE"
        STATUS_TRACKER["apply_config"]="FAIL"
    fi
}

# Run additional scripts and log success/failure
function run_scripts() {
    echo "Running additional scripts..." | tee -a "$LOG_FILE"
    local all_success=true
    for script in "${SCRIPTS_TO_RUN[@]}"; do
        if [ -f "$script" ]; then
            bash "$script" >> "$LOG_FILE" 2>&1
            if [ $? -eq 0 ]; then
                echo "$script ran successfully." | tee -a "$LOG_FILE"
            else
                echo "Warning: $script encountered an error but the process will continue." | tee -a "$LOG_FILE"
                all_success=false
            fi
        else
            echo "Warning: Script $script not found." | tee -a "$LOG_FILE"
            all_success=false
        fi
    done
    if [ "$all_success" = true ]; then
        STATUS_TRACKER["run_scripts"]="SUCCESS"
    else
        STATUS_TRACKER["run_scripts"]="FAIL"
    fi
}

# Summary report
function report_summary() {
    echo -e "\nSetup Summary:" | tee -a "$LOG_FILE"
    for step in "${!STATUS_TRACKER[@]}"; do
        echo "$step: ${STATUS_TRACKER[$step]}" | tee -a "$LOG_FILE"
    done
}

# Main execution
function main() {
    install_packages
    copy_configs  # Calls function with default src and dest if no arguments
    run_scripts
    report_summary
    echo "Setup complete at $(date)." | tee -a "$LOG_FILE"
}

# Run main function
main

