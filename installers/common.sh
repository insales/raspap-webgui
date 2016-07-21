raspap_dir="/etc/raspap"
raspap_user="www-data"
webroot_dir="/var/www/raspap"

# Outputs a RaspAP INSTALL log line
function install_log() {
    echo -e "\033[1;32mRaspAP INSTALL: $*\033[m"
}

# Outputs a RaspAP INSTALL ERROR log line and exits with status code 1
function install_error() {
    echo -e "\033[1;37;41mRaspAP INSTALL ERROR: $*\033[m"
    exit 1
}

### NOTE: all the below functions are overloadable for system-specific installs
### NOTE: some of the below functions MUST be overloaded due to system-specific installs

# Runs a system software update to make sure we're using all fresh packages
function update_system_packages() {
    # OVERLOAD THIS
    install_error "No function definition for update_system_packages"
}

# Installs additional dependencies using system package manager
function install_dependencies() {
    # OVERLOAD THIS
    install_error "No function definition for install_dependencies"
}

# Verifies existence and permissions of RaspAP directory
function create_raspap_directories() {
    install_log "Creating RaspAP directories"
    if [ ! -d "$raspap_dir" ]; then
        sudo mkdir -p "$raspap_dir" || install_error "Unable to create directory '$raspap_dir'"
    fi

    sudo chown -R $raspap_user:$raspap_user "$raspap_dir" || install_error "Unable to change file ownership for '$raspap_dir'"
}

# Fetches latest files from github to webroot
function download_latest_files() {
    if [ ! -d "$webroot_dir" ]; then
        install_error "Web root directory doesn't exist"
    fi

    install_log "Cloning latest files from github"
    sudo git clone https://github.com/insales/raspap-webgui "$webroot_dir" || install_error "Unable to download files from github"
}

# Sets files ownership in web root directory
function change_file_ownership() {
    if [ ! -d "$webroot_dir" ]; then
        install_error "Web root directory doesn't exist"
    fi

    install_log "Changing file ownership in web root directory"
    sudo chown -R $raspap_user:$raspap_user "$webroot_dir" || install_error "Unable to change file ownership for '$webroot_dir'"
}

# Move configuration file to the correct location
function move_config_file() {
    if [ ! -d "$raspap_dir" ]; then
        install_error "'$raspap_dir' directory doesn't exist"
    fi

    install_log "Moving configuration file to '$raspap_dir'"
    sudo mv "$webroot_dir"/raspap.php "$raspap_dir" || install_error "Unable to move files to '$raspap_dir'"
    sudo chown -R $raspap_user:$raspap_user "$raspap_dir" || install_error "Unable to change file ownership for '$raspap_dir'"
}

function overwrite_nginx_config() {
  install_log "Moving nginx configuration file"
  sudo mv -f "$webroot_dir"/nginx.default.conf /etc/nginx/sites-available/default || install_error "Unable to overwrite nginx default site config"
}

function reload_nginx() {
  install_log "Reloading nginx"
  sudo systemctl reload nginx || install_error "Unable to reload nginx, config file may be corrupted"
}

# Adds www-data user to the sudoers file with restrictions on what the user can execute
function patch_system_files() {
    install_log "Patching system sudoers file"
    # patch /etc/sudoers file
    sudo bash -c 'echo "www-data ALL=(ALL) NOPASSWD:/sbin/ifdown wlan0,/sbin/ifup wlan0,/bin/cat /etc/wpa_supplicant/wpa_supplicant.conf,/bin/cp /tmp/wifidata /etc/wpa_supplicant/wpa_supplicant.conf,/sbin/wpa_cli scan_results, /sbin/wpa_cli scan,/bin/cp /tmp/hostapddata /etc/hostapd/hostapd.conf, /etc/init.d/hostapd start,/etc/init.d/hostapd stop,/etc/init.d/dnsmasq start, /etc/init.d/dnsmasq stop,/bin/cp /tmp/dhcpddata /etc/dnsmasq.conf, /sbin/shutdown -h now, /sbin/reboot" | (EDITOR="tee -a" visudo)' \
        || install_error "Unable to patch /etc/sudoers"
}

function install_complete() {
    install_log "Installation completed!"

    echo -n "The system needs to be rebooted as a final step. Rebooting."
    sudo shutdown -h now || install_error "Unable to execute shutdown"
}

function install_raspap() {
    update_system_packages
    install_dependencies
    create_raspap_directories
    clear_www_directory
    download_latest_files
    change_file_ownership
    move_config_file
    overwrite_nginx_config
    reload_nginx
    patch_system_files
    install_complete
}
