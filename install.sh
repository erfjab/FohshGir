#!/bin/bash

# Basic setup
SCRIPT_NAME="fohshgir"
INSTALL_DIR="/opt/erfjab"
USERNAME="erfjab"
DEFAULT_BRANCH="master"
REPO_URL="https://github.com/${USERNAME}/${SCRIPT_NAME}.git"
SERVICE_FILE="/etc/systemd/system/${SCRIPT_NAME}.service"
LOG_FILE="${INSTALL_DIR}/${SCRIPT_NAME}/${SCRIPT_NAME}.log"
ENV_FILE="${INSTALL_DIR}/${SCRIPT_NAME}/.env"
ENV_EXAMPLE="${INSTALL_DIR}/${SCRIPT_NAME}/.env.example"

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

# Get current branch if exists
get_current_branch() {
    if [ -d "${INSTALL_DIR}/${SCRIPT_NAME}/.git" ]; then
        git -C "${INSTALL_DIR}/${SCRIPT_NAME}" rev-parse --abbrev-ref HEAD
    else
        echo "$DEFAULT_BRANCH"
    fi
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
    [ -d "$INSTALL_DIR" ] || mkdir -p "$INSTALL_DIR"
    if [ -d "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
        warn "Removing old installation..."
        rm -rf "${INSTALL_DIR}/${SCRIPT_NAME}"
    fi
    mkdir -p "${INSTALL_DIR}/${SCRIPT_NAME}"
    success "Directory ready"
}

# Clone repository with branch support
clone_repo() {
    local branch=${1:-$DEFAULT_BRANCH}
    log "Cloning repository (branch: $branch)..."
    git clone -b "$branch" "$REPO_URL" "${INSTALL_DIR}/${SCRIPT_NAME}" || {
        warn "Failed to clone branch $branch, trying default branch..."
        git clone "$REPO_URL" "${INSTALL_DIR}/${SCRIPT_NAME}" || error "Failed to clone repository"
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
Description=$SCRIPT_NAME Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/$SCRIPT_NAME
ExecStart=uv run main.py
Restart=always
RestartSec=3
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SCRIPT_NAME"
    success "Service created"
}

# Service management
service_action() {
    case $1 in
        start)
            systemctl start "$SCRIPT_NAME" && success "Service started" || error "Failed to start"
            ;;
        stop)
            systemctl stop "$SCRIPT_NAME" && success "Service stopped" || warn "Not running"
            ;;
        restart)
            systemctl restart "$SCRIPT_NAME" && success "Service restarted" || error "Failed to restart"
            ;;
        status)
            systemctl status "$SCRIPT_NAME"
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
    check_root
    install_deps
    setup_dir
    clone_repo "$branch"
    setup_env
    create_service
    service_action start
    script_management install
    success "Installation complete! (branch: $branch)"
}

# Update function with branch support - optimized version
update() {
    local branch=${1:-$(get_current_branch)}
    check_root
    log "Updating to branch: $branch"    
    service_action stop
    cd "${INSTALL_DIR}/${SCRIPT_NAME}" || error "Failed to enter installation directory"
    git fetch --all || error "Failed to fetch updates"
    git checkout "$branch" && git reset --hard "origin/$branch"
    success "Successfully updated to branch: $branch"
    service_action start
    success "Update complete! (branch: $branch)"
}

# Uninstall function
uninstall() {
    check_root
    log "Starting uninstallation..."
    service_action stop
    systemctl disable "$SCRIPT_NAME" 2>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -rf "${INSTALL_DIR}/${SCRIPT_NAME}"
    script_management uninstall
    success "Uninstallation complete"
}

# Show logs
show_logs() {
    [ -f "$LOG_FILE" ] && tail -f "$LOG_FILE" || error "Log file not found"
}

# Help message
show_help() {
    echo "Usage: $0 [command] [options]"
    echo "Commands:"
    echo "  install [branch]    - Install the application (optional: specify branch)"
    echo "  update [branch]     - Update the application (optional: specify branch)"
    echo "  uninstall           - Uninstall the application"
    echo "  start               - Start the service"
    echo "  stop                - Stop the service"
    echo "  restart             - Restart the service"
    echo "  status              - Show service status"
    echo "  logs                - Show application logs"
    echo "  script-install      - Install management script"
    echo "  script-uninstall    - Uninstall management script"
    echo "  script-update       - Update management script"
    echo "  help                - Show this help message"
}

# Main entry point with branch support
case "$1" in
    install)
        install "$2"
        ;;
    update)
        update "$2"
        ;;
    uninstall)
        uninstall
        ;;
    start|stop|restart|status)
        service_action "$1"
        ;;
    logs)
        show_logs
        ;;
    env)
        nano $ENV_FILE
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
    help)
        show_help
        ;;
    *)
        show_help
        ;;
esac