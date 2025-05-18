#!/bin/bash

# Basic setup
SCRIPT_NAME="fohshgir"
INSTALL_BASE_DIR="/opt/erfjab"
USERNAME="erfjab"
DEFAULT_BRANCH="master"
REPO_URL="https://github.com/${USERNAME}/${SCRIPT_NAME}.git"
DEFAULT_INSTANCE="default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simple logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Get instance name
get_instance_name() {
    local instance="$1"
    if [ -z "$instance" ]; then
        read -p "Enter instance name (default: $DEFAULT_INSTANCE): " instance
        instance=${instance:-$DEFAULT_INSTANCE}
    fi
    echo "$instance"
}

# Get paths for instance
get_instance_paths() {
    local instance="$1"
    echo -e "\n${BLUE}[INSTANCE: ${instance}]${NC}"
    INSTALL_DIR="${INSTALL_BASE_DIR}/${SCRIPT_NAME}/${instance}"
    SERVICE_FILE="/etc/systemd/system/${SCRIPT_NAME}_${instance}.service"
    LOG_FILE="${INSTALL_DIR}/${SCRIPT_NAME}.log"
    ENV_FILE="${INSTALL_DIR}/.env"
    ENV_EXAMPLE="${INSTALL_DIR}/.env.example"
}

# Check if running as root
check_root() {
    [ "$EUID" -eq 0 ] || error "This script must be run as root"
}

# Install required packages
install_deps() {
    log "Installing required packages..."
    apt update && apt install -y git python3 python3-pip python3-venv || error "Failed to install packages"
    export PIP_BREAK_SYSTEM_PACKAGES=1
    pip3 install uv || error "Failed to install uv"
    success "Dependencies installed"
}

# Setup installation directory
setup_dir() {
    log "Setting up installation directory..."
    if [ -d "${INSTALL_DIR}" ]; then
        warn "Instance directory already exists"
        read -p "Overwrite? (y/N) " choice
        case "$choice" in
            y|Y) rm -rf "${INSTALL_DIR}" ;;
            *) exit 0 ;;
        esac
    fi
    mkdir -p "${INSTALL_DIR}"
    success "Directory ready"
}

# Clone repository with branch support
clone_repo() {
    local branch=${1:-$DEFAULT_BRANCH}
    log "Cloning repository (branch: $branch)..."
    git clone -b "$branch" "$REPO_URL" "${INSTALL_DIR}" || {
        warn "Failed to clone branch $branch, trying default branch..."
        git clone "$REPO_URL" "${INSTALL_DIR}" || error "Failed to clone repository"
    }
    success "Repository cloned"
}

# Setup environment
setup_env() {
    log "Setting up environment..."
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            nano "$ENV_FILE"
        else
            warn ".env.example not found, creating empty .env file"
            touch "$ENV_FILE"
            nano "$ENV_FILE"
        fi
    else
        log "Using existing .env file"
    fi
    success "Environment setup complete"
}

# Create systemd service
create_service() {
    log "Creating systemd service..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=$SCRIPT_NAME Service (Instance: $INSTANCE)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=uv run main.py
Restart=always
RestartSec=3
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$(basename "$SERVICE_FILE")"
    success "Service created"
}

# Service management
service_action() {
    local action="$1"
    local service_name="$(basename "$SERVICE_FILE")"
    
    case "$action" in
        start)
            systemctl start "$service_name" && success "Service started" || error "Failed to start"
            ;;
        stop)
            systemctl stop "$service_name" && success "Service stopped" || warn "Not running"
            ;;
        restart)
            systemctl restart "$service_name" && success "Service restarted" || error "Failed to restart"
            ;;
        status)
            systemctl status "$service_name"
            ;;
        *)
            error "Invalid action"
            ;;
    esac
}

# Install script management
script_management() {
    case $1 in
        install)
            log "Installing management script..."
            cp "$0" "/usr/local/bin/${SCRIPT_NAME}"
            chmod +x "/usr/local/bin/${SCRIPT_NAME}"
            success "Management script installed to /usr/local/bin/${SCRIPT_NAME}"
            ;;
        uninstall)
            log "Removing management script..."
            rm -f "/usr/local/bin/${SCRIPT_NAME}"
            success "Management script removed"
            ;;
        update)
            log "Updating management script..."
            curl -sL "https://raw.githubusercontent.com/${USERNAME}/${SCRIPT_NAME}/${BRANCH}/install.sh" -o "$0"
            chmod +x "$0"
            cp "$0" "/usr/local/bin/${SCRIPT_NAME}"
            success "Management script updated"
            ;;
        *)
            error "Invalid script action"
            ;;
    esac
}

# Main installation with branch support
install() {
    local branch=${1:-$DEFAULT_BRANCH}
    INSTANCE=$(get_instance_name "$2")
    get_instance_paths "$INSTANCE"
    
    check_root
    install_deps
    setup_dir
    clone_repo "$branch"
    setup_env
    create_service
    service_action start
    success "Installation complete! (Instance: $INSTANCE, Branch: $branch)"
}

# Update function with branch support
update() {
    INSTANCE=$(get_instance_name "$2")
    get_instance_paths "$INSTANCE"
    local branch=${1:-$(git -C "$INSTALL_DIR" rev-parse --abbrev-ref HEAD)}
    
    check_root
    log "Updating instance: $INSTANCE (branch: $branch)"
    service_action stop
    cd "${INSTALL_DIR}" || error "Failed to enter installation directory"
    git fetch --all || error "Failed to fetch updates"
    git checkout "$branch" && git reset --hard "origin/$branch"
    service_action start
    success "Update complete! (Instance: $INSTANCE, Branch: $branch)"
}

# Uninstall function
uninstall() {
    INSTANCE=$(get_instance_name "$1")
    get_instance_paths "$INSTANCE"
    
    check_root
    log "Uninstalling instance: $INSTANCE"
    service_action stop
    systemctl disable "$(basename "$SERVICE_FILE")" 2>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -rf "${INSTALL_DIR}"
    success "Uninstallation complete for instance: $INSTANCE"
}

# Show logs
show_logs() {
    INSTANCE=$(get_instance_name "$1")
    get_instance_paths "$INSTANCE"
    [ -f "$LOG_FILE" ] && tail -f "$LOG_FILE" || error "Log file not found"
}

# List all instances
list_instances() {
    log "Available instances:"
    for dir in "${INSTALL_BASE_DIR}/${SCRIPT_NAME}"/*; do
        if [ -d "$dir" ]; then
            instance=$(basename "$dir")
            service_file="/etc/systemd/system/${SCRIPT_NAME}_${instance}.service"
            if [ -f "$service_file" ]; then
                status=$(systemctl is-active "${SCRIPT_NAME}_${instance}.service" 2>/dev/null || echo "inactive")
                echo -e "${GREEN}✓${NC} $instance (Status: $status)"
            else
                echo -e "${YELLOW}⚠${NC} $instance (No service file)"
            fi
        fi
    done
}

# Help message
show_help() {
    echo "Usage: $0 [command] [options] [instance]"
    echo "Commands:"
    echo "  install [branch] [instance] - Install new instance"
    echo "  update [branch] [instance]  - Update instance"
    echo "  uninstall [instance]        - Uninstall instance"
    echo "  start [instance]            - Start instance"
    echo "  stop [instance]             - Stop instance"
    echo "  restart [instance]          - Restart instance"
    echo "  status [instance]           - Show instance status"
    echo "  logs [instance]             - Show instance logs"
    echo "  list                        - List all instances"
    echo "  env [instance]              - Edit .env file"
    echo "  help                        - Show this help"
}

# Main entry point
case "$1" in
    install)
        install "$2" "$3"
        ;;
    update)
        update "$2" "$3"
        ;;
    uninstall)
        uninstall "$2"
        ;;
    start|stop|restart|status)
        INSTANCE=$(get_instance_name "$2")
        get_instance_paths "$INSTANCE"
        service_action "$1"
        ;;
    logs)
        show_logs "$2"
        ;;
    env)
        INSTANCE=$(get_instance_name "$2")
        get_instance_paths "$INSTANCE"
        nano "$ENV_FILE"
        ;;
    list)
        list_instances
        ;;
    help|"")
        show_help
        ;;
    script-install)
        script_management install
        ;;
    script-uninstall)
        script_management uninstall
        ;;
    script-update)
        script_management update
        ;;
    *)
        error "Invalid command. Use '$0 help' for usage."
        ;;
esac