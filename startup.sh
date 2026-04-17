#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_separator() {
    echo "============================================"
}

check_architecture() {
    log_info "Checking system architecture..."
    ARCH=$(uname -m)
    OS=$(uname -s)
    
    echo "  OS: $OS"
    echo "  Architecture: $ARCH"
    
    case $ARCH in
        x86_64|amd64)
            log_success "Architecture: x86_64 (supported)"
            ;;
        aarch64|arm64)
            log_success "Architecture: ARM64 (supported)"
            ;;
        armv7l|armhf)
            log_warn "Architecture: ARM32 (may have limited support)"
            ;;
        *)
            log_warn "Architecture: $ARCH (unknown)"
            ;;
    esac
    print_separator
}

check_nodejs() {
    log_info "Checking Node.js environment..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed!"
        log_info "Please install Node.js: https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node -v)
    NPM_VERSION=$(npm -v)
    
    echo "  Node.js version: $NODE_VERSION"
    echo "  npm version: $NPM_VERSION"
    
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | tr -d 'v')
    if [ "$NODE_MAJOR" -lt 16 ]; then
        log_warn "Node.js version < 16, consider upgrading for better compatibility"
    else
        log_success "Node.js version is compatible"
    fi
    print_separator
}

check_git() {
    log_info "Checking Git..."
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version)
        echo "  $GIT_VERSION"
        log_success "Git is installed"
    else
        log_error "Git is not installed!"
        log_info "Please install Git for theme management"
        exit 1
    fi
    print_separator
}

check_and_init_theme() {
    log_info "Checking Hexo NexT theme..."
    
    THEME_DIR="themes/next"
    THEME_REPO="https://github.com/next-theme/hexo-theme-next.git"
    
    if [ -d "$THEME_DIR" ]; then
        if [ -f "$THEME_DIR/layout/_third-party/comments/disqus.njk" ]; then
            log_success "NexT theme is properly installed"
            THEME_VERSION=$(cd "$THEME_DIR" 2>/dev/null && git describe --tags --always 2>/dev/null || echo "unknown")
            echo "  Theme version: $THEME_VERSION"
        else
            log_warn "Theme directory exists but incomplete"
            log_info "Re-cloning theme..."
            rm -rf "$THEME_DIR"
            git clone "$THEME_REPO" "$THEME_DIR"
            log_success "Theme cloned successfully"
        fi
    else
        log_info "Theme directory not found"
        log_info "Cloning NexT theme from $THEME_REPO"
        git clone "$THEME_REPO" "$THEME_DIR"
        log_success "Theme cloned successfully"
    fi
    
    print_separator
}

install_dependencies() {
    log_info "Installing npm dependencies..."
    
    if [ -f "package-lock.json" ]; then
        log_info "Found package-lock.json, running npm ci for faster install..."
        npm ci
    else
        log_info "Running npm install..."
        npm install
    fi
    
    log_success "Dependencies installed successfully"
    print_separator
}

update_dependencies() {
    log_info "Checking for dependency updates..."
    
    log_info "Running npm update..."
    npm update
    
    log_success "Dependencies updated"
    
    if command -v ncu &> /dev/null; then
        log_info "npm-check-updates available for major version updates"
        echo "  Run 'ncu' to check for updates"
        echo "  Run 'ncu -u && npm install' to upgrade"
    else
        log_info "To check for major version updates:"
        echo "  npm install -g npm-check-updates"
        echo "  ncu"
        echo "  ncu -u && npm install"
    fi
    
    print_separator
}

clean_build() {
    log_info "Cleaning previous build..."
    npm run clean
    
    log_success "Clean completed"
}

generate_site() {
    log_info "Generating static files..."
    npm run build
    
    GENERATED_FILES=$(find public -type f | wc -l)
    log_success "Generated $GENERATED_FILES files"
    print_separator
}

start_dev_server() {
    log_info "Starting Hexo development server..."
    
    DEFAULT_PORT=4000
    
    # Check if port 4000 is available
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$DEFAULT_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_warn "Port $DEFAULT_PORT is already in use"
            log_info "Starting on alternative port 4001..."
            npm run server -- -p 4001
        else
            log_success "Starting server on port $DEFAULT_PORT"
            echo ""
            echo "  Local: http://localhost:$DEFAULT_PORT"
            echo "  Press Ctrl+C to stop"
            echo ""
            npm run server
        fi
    else
        # Windows: try default port, fallback if error
        log_info "Starting server (will auto-detect port availability)"
        echo ""
        echo "  Default: http://localhost:$DEFAULT_PORT"
        echo "  Alternative: http://localhost:4001 (if default port busy)"
        echo "  Press Ctrl+C to stop"
        echo ""
        npm run server || npm run server -- -p 4001
    fi
}

show_final_info() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}       Hexo Blog Environment Ready!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Blog Configuration:"
    echo "  - Theme: NexT (latest)"
    echo "  - Theme Config: _config.next.yml"
    echo "  - Main Config: _config.yml"
    echo ""
    echo "Next Steps:"
    echo "  1. Edit posts in source/_posts/"
    echo "  2. Run 'npm run build' to regenerate"
    echo "  3. Run 'npm run deploy' to publish"
    echo ""
    echo "Useful Commands:"
    echo "  - npm run clean    : Clean generated files"
    echo "  - npm run build    : Generate static files"
    echo "  - npm run server   : Start development server"
    echo "  - npm run deploy   : Deploy to GitHub Pages"
    echo ""
}

main() {
    clear
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}       Hexo Blog Startup Script${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${BLUE}Complete Environment Initialization${NC}"
    echo ""
    
    check_architecture
    check_nodejs
    check_git
    check_and_init_theme
    install_dependencies
    update_dependencies
    clean_build
    generate_site
    show_final_info
    start_dev_server
}

main "$@"