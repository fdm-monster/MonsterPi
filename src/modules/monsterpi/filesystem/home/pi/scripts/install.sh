#!/bin/bash
# FDM Monster One-Click Installer for Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/fdm-monster/fdm-monster-scripts/main/install/linux/install.sh | bash
#
# ============================================================================
# ENVIRONMENT VARIABLE OVERRIDES
# ============================================================================
# The following environment variables can be used to customize installation:
#
# FDMM_NODE_VERSION      - Node.js version to install (default: 24.12.0)
# FDMM_NPM_PACKAGE       - NPM package to install (default: @fdm-monster/server)
# FDMM_SERVER_PORT       - Server port (default: 4000)
# FDMM_INSTALL_DIR       - Installation directory (default: $HOME/.fdm-monster)
# FDMM_DATA_DIR          - Data directory (default $HOME/.fdm-monster-data)
# FDMM_INSTALL_URL       - Installer script URL (default: GitHub main branch)
# FDMM_OVERRIDE_ROOT     - Allow running as root (default: false, set to 'true' to override)
#
# Example:
#   FDMM_NODE_VERSION="22.11.0" FDMM_SERVER_PORT="3000" bash install.sh
#   FDMM_OVERRIDE_ROOT=true bash install.sh
# ============================================================================

set -e

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly CLI_VERSION="1.0.10"

# Configuration (see ENVIRONMENT VARIABLE OVERRIDES section above)
NODE_VERSION="${FDMM_NODE_VERSION:-24.12.0}"
NPM_PACKAGE="${FDMM_NPM_PACKAGE:-@fdm-monster/server}"
INSTALL_DIR="${FDMM_INSTALL_DIR:-$HOME/.fdm-monster}"
DEFAULT_PORT="${FDMM_SERVER_PORT:-4000}"
DATA_DIR="${FDMM_DATA_DIR:-$HOME/.fdm-monster-data}"
INSTALL_SCRIPT_URL="${FDMM_INSTALL_URL:-https://raw.githubusercontent.com/fdm-monster/fdm-monster-scripts/main/install/linux/install.sh}"
OVERRIDE_ROOT="${FDMM_OVERRIDE_ROOT:-false}"

# Helper functions
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
    ___________ __  ___   __  ___                 __
   / ____/ __ \/  |/  /  /  |/  /___  ____  _____/ /____  _____
  / /_  / / / / /|_/ /  / /|_/ / __ \/ __ \/ ___/ __/ _ \/ ___/
 / __/ / /_/ / /  / /  / /  / / /_/ / / / (__  ) /_/  __/ /
/_/   /_____/_/  /_/  /_/  /_/\____/_/ /_/____/\__/\___/_/

EOF
    echo -e "${NC}${GREEN}FDM Monster One-Click Installer${NC} ${YELLOW}($CLI_VERSION)${NC}\n${BLUE}https://fdm-monster.net${NC}\n"
    return 0
}

print_success() {
    local message="$1"
    echo -e "${GREEN}✓${NC} $message"
    return 0
}

print_error() {
    local message="$1"
    echo -e "${RED}✗${NC} $message"
    return 0
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}!${NC} $message"
    return 0
}

print_info() {
    local message="$1"
    echo -e "${BLUE}ℹ${NC} $message"
    return 0
}

check_root() {
    if [[ "$EUID" -eq 0 ]] && [[ "$OVERRIDE_ROOT" != "true" ]]; then
        print_error "Do not run as root"
        print_info "To override this check, set FDMM_OVERRIDE_ROOT=true"
        exit 1
    fi

    if [[ "$EUID" -eq 0 ]]; then
        print_warning "Running as root (override enabled)"
    fi

    return 0
}

validate_semver() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}✗${NC} Invalid semver format: $version (expected x.y.z format)"
        exit 1
    fi

    return 0
}

version_gt() {
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]]
    return 0
}

check_dependencies() {
    print_info "Checking required dependencies..."

    local MISSING_DEPS=()
    local REQUIRED_DEPS=("curl" "tar" "grep" "mkdir")

    for cmd in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            MISSING_DEPS+=("$cmd")
        fi
    done

    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${MISSING_DEPS[*]}"
        print_info "Please install the missing packages and try again"
        exit 1
    fi

    # Check sudo availability and permissions
    if command -v sudo &> /dev/null; then
        if ! sudo -n true 2>/dev/null; then
            print_warning "sudo requires password - you may be prompted during installation"
            # Test sudo access with password prompt
            if ! sudo -v; then
                print_error "sudo access required for systemd service management"
                exit 1
            fi
        fi
        print_success "sudo access verified"
    else
        print_warning "sudo not available - systemd service setup may fail"
    fi

    print_success "All required dependencies found"
    return 0
}

detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    [[ ! "$OS" =~ ^(linux|darwin) ]] && { print_error "Unsupported OS: $OS"; exit 1; }
    OS="linux"

    case $ARCH in
        x86_64|amd64) ARCH="x64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="armv7l" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    print_success "Detected platform: $OS/$ARCH"
    return 0
}

install_nodejs() {
    print_info "Installing Node.js $NODE_VERSION..."

    local NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${OS}-${ARCH}.tar.xz"
    local NODE_DIR="$INSTALL_DIR/nodejs"

    mkdir -p "$NODE_DIR"

    if ! curl -fsSL "$NODE_URL" | tar -xJ -C "$NODE_DIR" --strip-components=1; then
        print_error "Failed to download or extract Node.js"
        exit 1
    fi

    # Add to current session
    export PATH="$NODE_DIR/bin:$PATH"

    # Verify installation
    if [[ ! -f "$NODE_DIR/bin/node" ]] || [[ ! -x "$NODE_DIR/bin/node" ]]; then
        print_error "Node.js binary not found or not executable after installation"
        exit 1
    fi

    if [[ ! -f "$NODE_DIR/bin/npm" ]] || [[ ! -x "$NODE_DIR/bin/npm" ]]; then
        print_error "npm binary not found or not executable after installation"
        exit 1
    fi

    # Verify node can actually run
    if ! "$NODE_DIR/bin/node" --version &> /dev/null; then
        print_error "Node.js binary exists but cannot execute"
        exit 1
    fi

    local ACTUAL_VERSION=$("$NODE_DIR/bin/node" --version)
    print_success "Node.js $ACTUAL_VERSION installed and verified"
    return 0
}

ensure_nodejs() {
    local NODE_DIR="$INSTALL_DIR/nodejs"
    local NODE_BINARY="$NODE_DIR/bin/node"

    if [[ -f "$NODE_BINARY" ]]; then
        local CURRENT_VERSION=$("$NODE_BINARY" -v 2>/dev/null | sed 's/^v//')

        if [[ -z "$CURRENT_VERSION" ]]; then
            print_warning "Node.js binary found but version check failed. Reinstalling..."
            rm -rf "$NODE_DIR"
        elif version_gt "$NODE_VERSION" "$CURRENT_VERSION"; then
            print_warning "Node.js $CURRENT_VERSION detected, upgrading to $NODE_VERSION..."
            rm -rf "$NODE_DIR"
        else
            print_success "Node.js $CURRENT_VERSION detected (>= $NODE_VERSION)"
        fi
    fi

    [[ ! -f "$NODE_BINARY" ]] && install_nodejs

    # Ensure PATH is set for current and future sessions
    export PATH="$NODE_DIR/bin:$PATH"
    local SHELL_RC="$HOME/.bashrc"
    [[ -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.zshrc"
    grep -q "$INSTALL_DIR/nodejs/bin" "$SHELL_RC" 2>/dev/null || \
        echo "export PATH=\"$INSTALL_DIR/nodejs/bin:\$PATH\"" >> "$SHELL_RC"

    return 0
}

setup_yarn() {
    print_info "Setting up Yarn via corepack..."

    # Verify corepack is available
    if ! command -v corepack &> /dev/null; then
        print_error "corepack not found - it should be included with Node.js"
        exit 1
    fi

    # Enable corepack
    if ! corepack enable; then
        print_error "Failed to enable corepack"
        exit 1
    fi

    # Prepare yarn latest
    if ! corepack prepare yarn@stable --activate; then
        print_error "Failed to prepare yarn"
        exit 1
    fi

    # Verify yarn is available and working
    if ! command -v yarn &> /dev/null; then
        print_error "yarn not available after corepack setup"
        exit 1
    fi

    if ! yarn --version &> /dev/null; then
        print_error "yarn exists but cannot execute"
        exit 1
    fi

    local YARN_VERSION=$(yarn --version)
    print_success "Yarn $YARN_VERSION ready and verified"
    return 0
}

install_fdm_monster() {
    print_info "Installing $NPM_PACKAGE..."

    mkdir -p "$INSTALL_DIR" "$DATA_DIR/media" "$DATA_DIR/database"
    cd "$INSTALL_DIR"

    # Create package.json if it doesn't exist
    if [[ ! -f "package.json" ]]; then
        cat > package.json << EOF
{
  "name": "fdm-monster-install",
  "private": true,
  "dependencies": {}
}
EOF
    fi

    # Install the package
    if ! YARN_NODE_LINKER=node-modules yarn add "$NPM_PACKAGE"; then
        print_error "Failed to install $NPM_PACKAGE"
        exit 1
    fi

    # Verify installation
    local MAIN_DIR="$INSTALL_DIR/node_modules/$NPM_PACKAGE"
    if [[ ! -d "$MAIN_DIR" ]]; then
        print_error "Package directory $MAIN_DIR not found after installation"
        exit 1
    fi

    local MAIN_FILE="$INSTALL_DIR/node_modules/$NPM_PACKAGE/dist/index.js"
    if [[ ! -f "$MAIN_FILE" ]]; then
        print_error "Main entry file not found: $MAIN_FILE"
        exit 1
    fi

    # Verify package.json exists and can be read
    local PKG_JSON="$INSTALL_DIR/node_modules/$NPM_PACKAGE/package.json"
    if [[ ! -f "$PKG_JSON" ]]; then
        print_error "Package manifest not found: $PKG_JSON"
        exit 1
    fi

    # Get and verify installed version
    local INSTALLED_VERSION=$(node -p "require('./node_modules/$NPM_PACKAGE/package.json').version" 2>/dev/null)
    if [[ -z "$INSTALLED_VERSION" ]]; then
        print_error "Could not determine installed version"
        exit 1
    fi

    # Create .env file in data dir with environment variables
    local ENV_FILE="$DATA_DIR/.env"
    if [[ ! -f "$ENV_FILE" ]]; then
        cat > "$ENV_FILE" << EOF
NODE_ENV=development
SERVER_PORT=$DEFAULT_PORT
DATABASE_PATH=$DATA_DIR/database
MEDIA_PATH=$DATA_DIR/media
EOF
        print_success ".env file created at $DATA_DIR/.env"
    fi

    print_success "$NPM_PACKAGE $INSTALLED_VERSION installed and verified"
    return 0
}

create_systemd_service() {
    if ! command -v systemctl &> /dev/null; then
        print_warning "systemd not available, service won't auto-start on boot"
        return
    fi

    print_info "Creating systemd service..."

    local SERVICE_FILE="/etc/systemd/system/fdm-monster.service"
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=FDM Monster - 3D Printer Farm Manager
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$DATA_DIR
Environment="ENV_FILE=$DATA_DIR/.env"
ExecStart=$INSTALL_DIR/nodejs/bin/node $INSTALL_DIR/node_modules/$NPM_PACKAGE/dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable fdm-monster
    sudo systemctl start fdm-monster

    print_success "systemd service created and started"
    return 0
}

create_cli_wrapper() {
    print_info "Creating CLI wrapper..."

    local BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"

    # Try to copy the script, or download it if running from pipe
    if ! cp "$0" "$BIN_DIR/fdm-monster" 2>/dev/null; then
        if ! curl -fsSL "$INSTALL_SCRIPT_URL" -o "$BIN_DIR/fdm-monster"; then
            print_error "Failed to create CLI wrapper - could not download from $INSTALL_SCRIPT_URL"
            exit 1
        fi
    fi

    chmod +x "$BIN_DIR/fdm-monster"
    ln -sf "$BIN_DIR/fdm-monster" "$BIN_DIR/fdmm"

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        # Add to current session
        export PATH="$PATH:$BIN_DIR"

        # Persist for future sessions
        local SHELL_RC="$HOME/.bashrc"
        [[ -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.zshrc"
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"

        print_success "CLI created at $BIN_DIR/fdm-monster (alias: fdmm). To use immediately, copy and run:"
        echo ""
        echo -e "\033[1;32m    export PATH=\"$INSTALL_DIR/nodejs/bin:\$PATH:$BIN_DIR\"\033[0m"
        echo ""
        print_info "(Or restart your terminal)"
    else
        print_success "CLI created at $BIN_DIR/fdm-monster (alias: fdmm)"
    fi
    return 0
}

# CLI command handler
handle_command() {
    local command_arg="$1"
    case "$command_arg" in
        start)
            if command -v systemctl &> /dev/null; then
                sudo systemctl start fdm-monster
            else
                cd "$DATA_DIR"
                nohup "$INSTALL_DIR/nodejs/bin/node" "$INSTALL_DIR/node_modules/$NPM_PACKAGE/dist/index.js" > "$DATA_DIR/media/logs/fdm-monster.log" 2>&1 &
                echo "FDM Monster started (PID: $!)"
            fi
            ;;
        stop)
            if command -v systemctl &> /dev/null; then
                sudo systemctl stop fdm-monster
            else
                pkill -f "$NPM_PACKAGE/dist/index.js" || echo "FDM Monster not running"
            fi
            ;;
        restart)
            if command -v systemctl &> /dev/null; then
                sudo systemctl restart fdm-monster
            else
                $0 stop && sleep 2 && $0 start
            fi
            ;;
        status)
            if command -v systemctl &> /dev/null; then
                sudo systemctl status fdm-monster
            else
                if pgrep -f "$NPM_PACKAGE/dist/index.js" > /dev/null; then
                    print_success "FDM Monster is running (PID: $(pgrep -f "$NPM_PACKAGE/dist/index.js"))"
                    if curl -s "http://localhost:$DEFAULT_PORT" > /dev/null 2>&1; then
                        print_success "Service is responding at http://localhost:$DEFAULT_PORT"
                    else
                        print_warning "Process is running but not responding on port $DEFAULT_PORT"
                    fi
                else
                    print_error "FDM Monster is not running"
                    exit 1
                fi
            fi
            ;;
        logs)
            if command -v systemctl &> /dev/null; then
                journalctl -u fdm-monster -f
            else
                tail -f "$DATA_DIR/media/logs/fdm-monster.log"
            fi
            ;;
        upgrade)
            local TARGET_VERSION="$2"
            local VERSION_DISPLAY="latest version"

            # Validate version if specified
            if [[ -n "$TARGET_VERSION" ]]; then
                local MAJOR_VERSION=$(echo "$TARGET_VERSION" | cut -d'.' -f1)
                if [[ "$MAJOR_VERSION" =~ ^[0-9]+$ ]] && [[ "$MAJOR_VERSION" -lt 2 ]]; then
                    print_error "Cannot upgrade to version $TARGET_VERSION - minimum supported version is 2.0.0"
                    exit 1
                fi
                VERSION_DISPLAY="version $TARGET_VERSION"
            fi

            print_info "Upgrading FDM Monster to $VERSION_DISPLAY..."
            $0 stop
            cd "$INSTALL_DIR"

            # Install package with or without version
            if [[ -n "$TARGET_VERSION" ]]; then
                YARN_NODE_LINKER=node-modules yarn add "$NPM_PACKAGE@$TARGET_VERSION"
            else
                YARN_NODE_LINKER=node-modules yarn add "$NPM_PACKAGE"
            fi

            # Recreate systemd service with updated configuration
            create_systemd_service

            # Get and display installed version
            local INSTALLED_VERSION=$(node -p "require('./node_modules/$NPM_PACKAGE/package.json').version" 2>/dev/null || echo "unknown")
            print_success "Upgraded to version $INSTALLED_VERSION"
            ;;
        backup)
            local BACKUP_DIR="$HOME/.fdm-monster-backups"
            local TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            local BACKUP_FILE="$BACKUP_DIR/fdm-monster-$TIMESTAMP.tar.gz"

            mkdir -p "$BACKUP_DIR"

            if [[ ! -d "$DATA_DIR" ]]; then
                print_error "Data directory does not exist: $DATA_DIR"
                exit 1
            fi

            print_info "Backing up FDM Monster data..."
            tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                local SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
                print_success "Backup created: $BACKUP_FILE ($SIZE)"
            else
                print_error "Backup failed"
                exit 1
            fi
            ;;
        update-cli)
            local CUSTOM_URL="$2"
            local UPDATE_URL="${CUSTOM_URL:-$INSTALL_SCRIPT_URL}"

            print_info "Updating FDM Monster CLI (current: v$CLI_VERSION)..."
            if [[ -n "$CUSTOM_URL" ]]; then
                print_info "Using custom URL: $CUSTOM_URL"
            fi

            local BIN_DIR="$HOME/.local/bin"
            local TEMP_FILE="/tmp/fdm-monster-cli-update.sh"

            if ! curl -fsSL "$UPDATE_URL" -o "$TEMP_FILE"; then
                print_error "Failed to download CLI update from $UPDATE_URL"
                exit 1
            fi

            # Extract new version from downloaded script
            local NEW_VERSION=$(grep '^CLI_VERSION=' "$TEMP_FILE" | cut -d'"' -f2)

            mv "$TEMP_FILE" "$BIN_DIR/fdm-monster"
            chmod +x "$BIN_DIR/fdm-monster"
            ln -sf "$BIN_DIR/fdm-monster" "$BIN_DIR/fdmm"

            if [[ -n "$NEW_VERSION" ]]; then
                print_success "CLI updated successfully to v$NEW_VERSION"
            else
                print_success "CLI updated successfully"
            fi
            ;;
        version|--version|-v)
            echo "FDM Monster CLI v$CLI_VERSION"
            ;;
        install)
            print_banner
            check_root
            check_dependencies
            detect_platform
            ensure_nodejs
            setup_yarn
            install_fdm_monster
            create_systemd_service
            create_cli_wrapper
            wait_for_service
            print_instructions
            ;;
        uninstall)
            print_warning "Uninstalling FDM Monster..."
            $0 stop
            if command -v systemctl &> /dev/null; then
                sudo systemctl disable fdm-monster 2>/dev/null || true
                sudo rm -f /etc/systemd/system/fdm-monster.service
                sudo systemctl daemon-reload
            fi

            # Remove install directory and CLI
            rm -rf "$INSTALL_DIR"
            rm -f "$HOME/.local/bin/fdm-monster" "$HOME/.local/bin/fdmm"

            # Ask about data directory
            echo ""
            echo -e "${YELLOW}Do you want to remove the data directory?${NC}"
            echo -e "  ${BLUE}Location:${NC} $DATA_DIR"
            echo -e "  ${BLUE}Contains:${NC} databases, logs, uploaded files"
            read -p "Remove data directory? [y/N]: " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$DATA_DIR"
                print_success "FDM Monster uninstalled (including data)"
            else
                print_success "FDM Monster uninstalled (data preserved at $DATA_DIR)"
            fi
            ;;
        *)
            echo "FDM Monster CLI v$CLI_VERSION"
            echo ""
            echo "Usage: fdm-monster {install|start|stop|restart|status|logs|upgrade [version]|backup|update-cli [url]|version|uninstall}"
            echo "Alias: fdmm"
            echo ""
            echo "Commands:"
            echo "  install            - (Re)install FDM Monster"
            echo "  start              - Start FDM Monster"
            echo "  stop               - Stop FDM Monster"
            echo "  restart            - Restart FDM Monster"
            echo "  status             - Check if FDM Monster is running"
            echo "  logs               - View logs"
            echo "  upgrade [ver]      - Upgrade to latest or specified version"
            echo "  backup             - Backup data directory to ~/.fdm-monster-backups"
            echo "  update-cli [url]   - Update the CLI tool itself (optionally from custom URL)"
            echo "  version            - Show CLI version"
            echo "  uninstall          - Remove FDM Monster"
            echo ""
            echo "Examples:"
            echo "  fdmm install                              # (Re)install FDM Monster"
            echo "  fdmm status                               # Check status"
            echo "  fdmm backup                               # Create backup"
            echo "  fdmm upgrade                              # Upgrade to latest"
            echo "  fdmm upgrade x.y.z                        # Upgrade to specific version"
            echo "  fdmm update-cli                           # Update CLI tool from default URL"
            echo "  fdmm update-cli https://example.com/cli   # Update CLI from custom URL"
            echo "  fdmm version                              # Show CLI version"
            exit 1
            ;;
    esac

    return 0
}

wait_for_service() {
    print_info "Waiting for FDM Monster to start..."

    for i in {1..10}; do
        if curl -s "http://localhost:$DEFAULT_PORT" > /dev/null 2>&1; then
            print_success "FDM Monster is ready!"
            return 0
        fi
        sleep 1
    done

    print_warning "Service did not respond within 10 seconds"
    print_info "Checking service status..."
    echo ""

    if command -v systemctl &> /dev/null; then
        sudo systemctl status fdm-monster --no-pager
    else
        if pgrep -f "$NPM_PACKAGE/dist/index.js" > /dev/null; then
            print_info "Process is running (PID: $(pgrep -f "$NPM_PACKAGE/dist/index.js"))"
            print_info "Service may still be initializing"
        else
            print_error "Process is not running"
        fi
    fi

    echo ""
    print_info "Check logs with: fdm-monster logs"
    return 0
}

get_network_addresses() {
    # Get all non-loopback IPv4 addresses
    if command -v ip &> /dev/null; then
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'
    elif command -v hostname &> /dev/null; then
        hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$'
    fi

    return 0
}

print_instructions() {
    # Get installed version
    local INSTALLED_VERSION=$(cd "$INSTALL_DIR" && node -p "require('./node_modules/$NPM_PACKAGE/package.json').version" 2>/dev/null || echo "unknown")

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  FDM Monster v$INSTALLED_VERSION is ready!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}Access FDM Monster at:${NC}"
    echo -e "    ${GREEN}http://localhost:$DEFAULT_PORT${NC}"

    # Show network addresses if available
    local ADDRESSES=$(get_network_addresses)
    if [[ -n "$ADDRESSES" ]]; then
        while IFS= read -r addr; do
            [[ -n "$addr" ]] && echo -e "    ${GREEN}http://$addr:$DEFAULT_PORT${NC}"
        done <<< "$ADDRESSES"
    fi

    echo ""
    echo -e "  ${BLUE}Management commands:${NC} ${YELLOW}(use 'fdm-monster' or 'fdmm' - CLI v$CLI_VERSION)${NC}"
    echo -e "    ${YELLOW}fdmm install${NC}              - (Re)install FDM Monster"
    echo -e "    ${YELLOW}fdmm start${NC}                - Start FDM Monster"
    echo -e "    ${YELLOW}fdmm stop${NC}                 - Stop FDM Monster"
    echo -e "    ${YELLOW}fdmm restart${NC}              - Restart FDM Monster"
    echo -e "    ${YELLOW}fdmm status${NC}               - Check if FDM Monster is running"
    echo -e "    ${YELLOW}fdmm logs${NC}                 - View logs"
    echo -e "    ${YELLOW}fdmm upgrade [version]${NC}    - Upgrade to latest or specified version"
    echo -e "    ${YELLOW}fdmm backup${NC}               - Backup data directory"
    echo -e "    ${YELLOW}fdmm update-cli [url]${NC}     - Update CLI tool (optionally from custom URL)"
    echo -e "    ${YELLOW}fdmm version${NC}              - Show CLI version"
    echo -e "    ${YELLOW}fdmm uninstall${NC}            - Remove FDM Monster"
    echo ""
    echo -e "  ${BLUE}Data directory:${NC} $DATA_DIR"
    echo -e "  ${BLUE}Install directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "  ${BLUE}Documentation:${NC} https://docs.fdm-monster.net"
    echo -e "  ${BLUE}Discord:${NC} https://discord.gg/mwA8uP8CMc"
    echo -e "  ${BLUE}Github Issues:${NC} https://github.com/fdm-monster/fdm-monster/issues"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    return 0
}

# Main function - handles both install and CLI commands
main() {
    validate_semver "$NODE_VERSION"

    # If called with a command argument, handle it as CLI
    if [[ $# -gt 0 ]]; then
        handle_command "$@"
        exit $?
    fi

    # Otherwise, run installer
    print_banner
    check_root
    check_dependencies
    detect_platform
    ensure_nodejs
    setup_yarn
    install_fdm_monster
    create_systemd_service
    create_cli_wrapper
    wait_for_service
    print_instructions

    return 0
}

# Run main function with all arguments
main "$@"

