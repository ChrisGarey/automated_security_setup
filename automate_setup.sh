#!/bin/bash

# Function to make text blink
blink_text() {
  local text="$1"
  echo -e "\e[5m$text\e[0m"  # \e[5m enables blinking text, \e[0m resets it
}

# Function to list and ask to kill apt processes
list_and_kill_apt_processes() {
  apt_processes=($(pgrep -a apt))
  if [ ${#apt_processes[@]} -gt 0 ]; then
    clear
    echo -e "There are apt processes running:\n"
    for process in "${apt_processes[@]}"; do
      process_pid=$(echo "$process" | awk '{print $1}'\n)
      process_name=$(echo "$process" | awk '{print $2}'\n)
      echo -e "PID: $process_pid - Process: $process_name\n"
    done
    read -p "Do you want to kill these processes and continue? (yes/no): " kill_apt
    if [ "$kill_apt" = "yes" ]; then
      for process in "${apt_processes[@]}"; do
        process_pid=$(echo "$process" | awk '{print $1}')
        sudo kill "$process_pid"
      done
      echo -e "Killed apt processes.\n"
      sleep 1
    else
      clear
      echo "Please run this script again when other processes have completed."
      exit 1
    fi
  fi
}

# Display the blinking title
blink_text "$(figlet -f slant 'Cosmos Cyber Security Setup')"

# Check if the user has superuser privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with superuser privileges (sudo)."
  exit 1
fi

# Determine the Linux distribution (Debian, Ubuntu, or Mint)
if [ -f /etc/debian_version ]; then
  distribution="Debian"
elif [ -f /etc/lsb-release ]; then
  source /etc/lsb-release
  distribution="$DISTRIB_ID"
else
  echo "Unsupported distribution. This script supports Debian, Ubuntu, and Mint."
  exit 1
fi

# Function to wait for existing apt processes to complete
wait_for_apt() {
  while pgrep apt > /dev/null; do
    list_and_kill_apt_processes
    echo -e "Waiting for other apt processes to complete...\n"
    sleep 5
  done
}

# Function to update and upgrade the system
update_and_upgrade() {
  wait_for_apt
  apt update -y > /dev/null 2>&1 &
  local update_pid=$!

  # Continuously monitor the progress of the update process
  echo -e "\nUpdating in progress...\n"
  while ps | grep -q "[a]pt update"; do
    sleep 1
  done

  wait $update_pid

  if [ $? -eq 0 ]; then
    echo -e "System update: Done.\n"
  else
    echo "Failed to update the system."
    exit 1
  fi

  apt upgrade -y > /dev/null 2>&1 &
  local upgrade_pid=$!

  # Continuously monitor the progress of the upgrade process
  echo -e "\nUpgrading in progress...\n"
  while ps | grep -q "[a]pt upgrade"; do
    sleep 1
  done

  wait $upgrade_pid

  if [ $? -eq 0 ]; then
    echo -e "\nSystem upgrade: Done.\n"
  else
    echo "Failed to upgrade the system."
    exit 1
  fi
}


# Function to clone a GitHub repository using sudo
clone_repository() {
  local repo_name="$1"
  local repo_url="$2"
  local target_dir="$3"

  if [ -d "$target_dir" ] && [ -n "$(ls -A $target_dir)" ]; then
    echo -e "[$repo_name]\n$repo_name directory is not empty. Skipping."
  else
    echo -e "[$repo_name]\nCloning $repo_name wordlist repository..."
    sudo git clone --progress "$repo_url" "$target_dir"

    # Continuously monitor the progress of the clone process
    while ps | grep -q "[g]it clone"; do
      sleep 1
      clear
      echo -e "[$repo_name]\nCloning $repo_name: $percentage complete"
    done

    if [ $? -eq 0 ]; then
      echo -e "[$repo_name]\n$repo_name clone: Done."
      sleep 1
    else
      echo -e "[$repo_name]\nFailed to clone $repo_name repository."
      sleep 1
    fi
  fi
}

# Function to install seclists and other wordlist repositories
install_wordlists() {
  # Seclists
  clone_repository "Seclists" "https://github.com/danielmiessler/SecLists.git" "/usr/share/wordlists/seclists"

  # Probable Wordlists
  clone_repository "Probable-Wordlists" "https://github.com/berzerk0/Probable-Wordlists.git" "/usr/share/wordlists/Probable-Wordlists"

  # xajkep wordlists
  clone_repository "xajkep" "https://github.com/xajkep/wordlists.git" "/usr/share/wordlists/xajkep"

  # wpa2 wordlists
  clone_repository "wpa2-wordlists" "https://github.com/kennyn510/wpa2-wordlists.git" "/usr/share/wordlists/wpa2-wordlists"

  # trickiest wordlists
  clone_repository "trickiest" "https://github.com/trickest/wordlists.git" "/usr/share/wordlists/trickest"

  # Add more wordlist repositories here if needed
}

# Function to install common Kali Linux tools
install_kali_tools() {
  # List of common Kali Linux tools
  common_kali_tools=("nmap" "wireshark" "gobuster" "hydra" "john" "sqlmap" "hashcat" "aircrack-ng" "cowpatty")

  for tool in "${common_kali_tools[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$tool" 2>/dev/null | grep -q "install ok installed"; then
      echo -e "\nInstalling $tool..."
      apt install -y "$tool" > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo -e "\n[$tool installation: Done.]"
      else
        echo "Failed to install $tool."
      fi
    else
      echo -e "\n$tool is already installed. Skipping."
    fi
  done
}


# Function to install and enable UFW (Uncomplicated Firewall)
install_and_enable_ufw() {
  ufw --force enable > /dev/null 2>&1 &
  while ps | grep -q "[u]fw"; do
    sleep 1
    echo " "
    echo "UFW setup in progress..."
  done
}

# Main script
echo " "
echo "Automating system setup for $distribution..."
echo " "

# Update and upgrade the system
update_and_upgrade
echo "************************************"
echo "* System Update and Upgrade: Done. *"
echo "************************************"
echo " "
read -n 1 -r -s -p $'Press enter to continue...\n'
# Install common Kali Linux tools
install_kali_tools
echo " "
echo "***********************************************"
echo "* Common Kali Linux tools installation: Done. *"
echo "***********************************************"
echo " "
read -n 1 -r -s -p $'Press enter to continue...\n'
# Install seclists and other wordlist repositories
echo " "
install_wordlists
echo " "
echo "*********************************"
echo "* Wordlists Installation: Done. *"
echo "*********************************"
echo " "
read -n 1 -r -s -p $'Press enter to continue...\n'

# Install and enable UFW
echo " "
install_and_enable_ufw
echo " "
echo "****************************************"
echo "* UFW Installation and Enabling: Done. *"
echo "****************************************"
echo " "
read -n 1 -r -s -p $'Setup completed successfully. Press enter to exit...\n'
