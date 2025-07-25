#!/bin/bash
# IronJump.sh - Unified Bastion Server & Endpoint Management Script
# Authors: Andrew Bindner & Carlota Bindner
# Special thanks and shout out to hdub-tech (github.com/hdub-tech) for so much support!
# Purpose: Configure, deploy, and manage IronJump Bastion Server and Endpoints
# Version: 1.0
# License: Private

# Global Variables - DO NOT CHANGE THESE! IRONJUMP WILL BREAK!
LOG_FILE="/var/log/ironjump.log"
IRONJUMP_SSH_GROUP="ironjump_users"
IRONJUMP_SRV_GROUP="ironjump_servers"
IRONJUMP_END_GROUP="ironjump_endpoints"
IRONJUMP_CHROOT_ENV="/home/ironjump"
PASSWORD_LENGTH="64"
PASSWORD_ROTATION="8"
SSH_CONF_IRONJUMP="/etc/ssh/sshd_config.d/zz-ironjump.conf"
SSH_CONF_IRONJUMP_BACKUP="/etc/ssh/sshd_config.d/zz-ironjump.conf.bak-$(date +%F-%H%M%S)"
SSH_CONF_SYSTEM="/etc/ssh/sshd_config"
SSH_CONF_SYSTEM_BACKUP="/etc/ssh/sshd_config.bak"
SSH_ENCRYPT_CONF="/etc/ssh/sshd_config.d/zz-ironjump-crypt.conf"
IRONJUMP_ROLE_FILE="/opt/IronJump/ironjump.role"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo privileges."
    exit 1
fi

#Save current directory and Migrate to IronJump working directory
if [[ ! -f /opt/IronJump/IronJump.sh ]]; then
    echo "The IronJump application and associated scripts must be located in /opt/IronJump folder. Please move IronJump and relaunch the application."
    exit 1
else
    OLDPWD=$(pwd)
    SCRIPT_DIR="/opt/IronJump"
    cd $SCRIPT_DIR
fi

# Check for functions file
if [[ -f ./functions ]]; then
    source ./functions
else
    echo "The functions file must be in the working directory to continue."
    exit 1
fi

# Check for AutoSSH files in /opt/IronJump/autossh
if [[ ! -f /opt/IronJump/autossh/configure ]]; then
    clear
    echo -e "[WARNING]\n---------"
    echo -e "IronJump may not have been downloaded correctly."
    echo -e "The AutoSSH folder is empty, which will is required"
    echo -e "for proper operation. It is likely that IronJump"
    echo -e "was incorrectly installed from Git. Please use the"
    echo -e "following commands when downloading from Git:"
    echo -e "\n\n  --> cd /opt/"
    echo -e "  --> git clone --recurse-submodules https://github.com/IronJump/IronJump.git"
    echo -e "  --> cd IronJump"
    echo -e "  --> chmod +x IronJump.sh"
    echo -e "\n\nIF you have installed AutoSSH already, this"
    echo -e "message can be ignored.\n"
    read -p "Press [ENTER] to continue." continue
fi

# Create Symbolic Link for IronJump
clear
if [[ ! -e /bin/ironjump ]]; then
    ln -s /opt/IronJump/IronJump.sh /bin/ironjump
    echo -e "\nA shortcut has been created for IronJump. You can now run \"sudo ironjump\" from anywhere on the command line."
    read -p "Press [ENTER] to continue to IronJump." continue
fi


### Menu Construction ###
nav_top_bar() {
    echo -e "========================================================\r\n"
}

nav_breaker_bar() {
    echo -e "\r\n--------------------------------------------------------"
}

nav_head_menu(){
    clear
    echo "IronJump SSH Management"
    nav_top_bar
    get_role_type
    echo -e "## Role:\t$current_role"
    f_os_identity
    nav_top_bar

}

nav_foot_menu() {
    echo -e "  S. SSH Monitor Live Connections"
    echo -e "  P. Previous Menu"
    echo -e "  M. Main Menu"
    echo -e "  R. Reboot Server"
    echo -e "  Q. Quit\r\n"
    read -p "Enter your choice: " choice
}

# Main Menu
main_menu() {
    local choice
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. Root Server Management"
    echo "  2. Endpoint Device Management"
    echo "  3. Access Control Management"
    echo "  4. Change Role Type"
    nav_breaker_bar
    echo "  S. SSH Monitor Live Connections"
    echo "  R. Reboot Server"
    echo -e "  Q. Quit\r\n"
    read -p "Enter your choice: " choice
    case "$choice" in
        1)
            if [[ $current_role == "UNASSIGNED" ]] || [[ $current_role == "SERVER" ]] || [[ $current_role == "HYBRID" ]]; then
                root_server_mgmt_menu
                main_menu
            else
                nav_breaker_bar
                echo -e "This host is configured as an Endoint. Please use the Endpoint Device Management Menu."
                read -p "Press [ENTER] to continue." continue
                main_menu
            fi
            ;;
        2)
            if [[ $current_role == "UNASSIGNED" ]] || [[ $current_role == "ENDPOINT" ]] || [[ $current_role == "HYBRID" ]]; then
                endpoint_device_mgmt_menu
                main_menu
            else
                nav_breaker_bar
                echo -e "This host is configured as a Server. Please use the Root Server Management Menu."
                read -p "Press [ENTER] to continue." continue
                main_menu
            fi
            ;;
        3)
            if [[ $current_role == "SERVER" ]] || [[ $current_role == "HYBRID" ]]; then
                access_control_mgmt_menu
                main_menu
            else
                nav_breaker_bar
                if [[ $current_role == "UNASSIGNED" ]]; then
                    echo -e "This host has not been configured. Access Control is disabled."
                else
                    echo -e "This host is configured as an Endoint. Access Control is a Server or Hybrid function only."
                fi
                read -p "Press [ENTER] to continue." continue
                main_menu
            fi
            ;;
        4) change_role_type ; main_menu ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; main_menu ;;
    esac
}

#Root Server Management Menu
root_server_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu"
    echo -e "   --> Root Server Management\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. Configuration & Deployment Management"
    echo "  2. User Account Management"
    echo "  3. Endpoint Device Account Management"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) root_server_config_deploy_mgmt_menu ;;
        2) root_server_user_acct_mgmt_menu ;;
        3) root_server_endpoint_acct_mgmt_menu ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) main_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice; root_server_mgmt_menu ;;
    esac
}

root_server_config_deploy_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu"
    echo -e "   --> Root Server Management"
    echo -e "      --> Configuration & Deployment Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. View Configuration File"
    echo "  2. Modify Configuration File (Opens VI Editor)"
    echo "  3. Deploy an IronJump Root Server"
    echo "  4. Generate an Archive of Files and Logs"
    echo "  H. Harden SSH Service (Standalone Utility)"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) view_configuration ;;
        2) mod_configuration ;;
        3)
            if [[ -f $ironjump_role_file ]] && [[ $(cat $ironjump_role_file |awk '{print $NF}') == "SERVER" ]]; then
                echo -e "Server is already configured."
                nav_breaker_bar
                read -p "Press [ENTER] to return to Main Menu." continue
                main_menu
            else
                f_setup_ironjump
                main_menu
            fi
            ;;
        4) ironjump_archive ; main_menu ;;
        H|h) harden_ssh_service ; main_menu ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) root_server_mgmt_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice; root_server_config_deploy_mgmt_menu ;;
    esac
}

root_server_user_acct_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu"
    echo -e "   --> Root Server Management"
    echo -e "      --> User Account Management Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. List Current IronJump User Accounts"
    echo "  2. Create New IronJump User Account"
    echo "  3. Enable IronJump User Account"
    echo "  4. Disable Existing IronJump User Account"
    echo "  5. Delete Existing IronJump User Account"
    echo "  6. Change a IronJump User's SSH Public Key"
    echo "  7. Set Expiration of a IronJump User's Account"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) usr_mgmt_list ;;
        2) usr_mgmt_new ;;
        3) usr_mgmt_enable ;;
        4) usr_mgmt_disable ;;
        5) usr_mgmt_delete ;;
        6) usr_mgmt_mod_pubkey ;;
        7) usr_mgmt_set_expire ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) root_server_mgmt_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; root_server_user_acct_mgmt_menu ;;
    esac
}

root_server_endpoint_acct_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu"
    echo -e "   --> Root Server Management"
    echo -e "      --> Endpoint Device Account Management Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. List Current Endpoint Device Accounts"
    echo "  2. Create New Endpoint Device Account"
    echo "  3. Enable New Endpoint Device Account"
    echo "  4. Disable Existing Endpoint Device Account"
    echo "  5. Delete Existing Endpoint Device Account"
    echo "  6. Change an Endpoint Device's SSH Public Key"
    echo "  7. Set Expiration of an Endpoint Device's Account"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) dev_mgmt_list ; root_server_endpoint_acct_mgmt_menu ;;
        2) dev_mgmt_new ; root_server_endpoint_acct_mgmt_menu ;;
        3) dev_mgmt_enable ;;
        4) dev_mgmt_disable ;;
        5) dev_mgmt_delete ;;
        6) dev_mgmt_mod_pubkey ;;
        7) dev_mgmt_set_expire ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) root_server_mgmt_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; root_server_endpoint_acct_mgmt_menu ;;
    esac
}


#Endpoint Device Management Menu
endpoint_device_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo "Navigation:"
    echo -e "--> Main Menu"
    echo -e "   --> Endpoint Device Management Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. Connect to IronJump Server (Only works on Linux & Mac)"
    echo "  2. Force an unscheduled permissions sync"
    echo "  3. Generate an Archive of Files and Logs"
    echo "  4. Harden SSH Service on this Endpoint (Standalone Utility)"
    echo -e "  D. SMELT this endpoint (Full Destruction - Not Recoverable)\r\n"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1)
            if [[ -f $ironjump_role_file ]] && [[ $(cat $ironjump_role_file |awk '{print $NF}') == "ENDPOINT" ]]; then
                echo -e "Endpoint is already configured. Remove ironjump.role file to re-register."
                nav_breaker_bar
                read -p "Press [ENTER] to return to Main Menu." continue
                main_menu
            else
                ep_connect
            fi
            ;;
        2) ep_force_sync ;;
        3) ironjump_archive ; main_menu ;;
        4) harden_ssh_service ; main_menu ;;
        D|d) ep_smelt_device ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) main_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; endpoint_device_mgmt_menu ;;
    esac
}

#Access Control Management Menu
access_control_mgmt_menu() {
    local choice
    clear
    nav_head_menu
    echo -e "Navigation:"
    echo -e "-->Main Menu"
    echo -e "   -->Access Control Management Menu\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. List All Current Assignments"
    echo "  2. Allow or Modify User Assignments"
    echo "  3. Revoke User Assignments"
    echo "  4. Allow/Revoke a User to All Endpoints (Mass Assignment)"
    echo "  5. Revoke 'ALL' Assignments"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) access_control_list_assignments ;;
        2) access_control_assign_user_menu ;;
        3) access_control_revoke_user_menu ;;
        4) access_control_mass_assignments ;;
        5) access_control_revoke_all_assignments ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) main_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; access_control_mgmt_menu ;;
    esac
}

access_control_assign_user_menu() {
    local choice
    clear
    echo -e "IronJump - Access Control Management - Allow/Modify"
    nav_top_bar
    echo -e "\nNavigation:"
    echo -e "-->Main Menu"
    echo -e "   -->Access Control Management Menu"
    echo -e "      --> Allow/Modify an Account\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. Individual Assignments by User"
    echo "  2. Individual Assignments by Endpoint"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) assignments_add_by_user ;;
        2) assignments_add_by_endpoint ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) access_control_mgmt_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; access_control_assign_user_menu ;;
    esac
}

access_control_revoke_user_menu() {
    local choice
    clear
    echo -e "IronJump - Access Control Management - Allow/Modify"
    nav_top_bar
    echo -e "\nNavigation:"
    echo -e "-->Main Menu"
    echo -e "   -->Access Control Management Menu"
    echo -e "      --> Revoke an Account\r\n"
    echo -e "Menu Selection:\n"
    echo "  1. Revoke Individual Assignments by User"
    echo "  2. Revoke Individual Assignments by Endpoint"
    nav_breaker_bar
    nav_foot_menu
    case $choice in
        1) assignments_revoke_by_user ;;
        2) assignments_revoke_by_endpoint ;;
        S|s) ssh_monitor ;;
        R|r) ast_reboot ;;
        P|p) access_control_mgmt_menu ;;
        M|m) main_menu ;;
        Q|q) cd $OLDPWD ; exit 0 ;;
        *) invalid_choice ; access_control_revoke_user_menu ;;
    esac
}

#Launch IronJump (__main__)
main_menu
