#!/bin/bash
#
# dev.sh - Unified Rust project development workflow
#
# Provides a consistent development workflow for Rust projects:
# - Environment setup (Rust toolchain)
# - Building and testing
# - Code quality checks (clippy, fmt)
# - Packaging (source archive, DEB)
# - Version control (review, commit, push)
# - GitHub release automation
#
# Usage:
#     ./scripts/dev.sh --help
#     ./scripts/dev.sh setup
#     ./scripts/dev.sh build
#     ./scripts/dev.sh test
#     ./scripts/dev.sh check
#     ./scripts/dev.sh package
#     ./scripts/dev.sh release --version 0.5.0
#     ./scripts/dev.sh full --version 0.5.0
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BUILD_DIR="${PROJECT_ROOT}/target"
readonly RELEASE_DIR="${BUILD_DIR}/release"

# Global flags
VERBOSE=false
DRY_RUN=false

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ $*${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}" >&2
}

# Execute command with logging
run_cmd() {
    local cmd=("$@")
    
    if [[ "$VERBOSE" == true || "$DRY_RUN" == true ]]; then
        log_info "$ ${cmd[*]}"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    if ! "${cmd[@]}"; then
        log_error "Command failed: ${cmd[*]}"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Setup development environment
setup_environment() {
    log_info "Setting up development environment..."
    
    # Check Rust installation
    if ! command_exists rustc; then
        log_error "Rust toolchain not found. Install from https://rustup.rs/"
        return 1
    fi
    
    local rust_version
    rust_version=$(rustc --version)
    log_success "Found: $rust_version"
    
    # Check Cargo
    if ! command_exists cargo; then
        log_error "Cargo not found"
        return 1
    fi
    
    local cargo_version
    cargo_version=$(cargo --version)
    log_success "Found: $cargo_version"
    
    # Update Rust (recommended but optional)
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Updating Rust toolchain..."
        run_cmd rustup update
    fi
    
    # Install useful tools
    log_info "Checking for additional tools..."
    
    # cargo-deb for Debian packaging
    if ! command_exists cargo-deb; then
        log_warning "cargo-deb not found. Installing..."
        run_cmd cargo install cargo-deb
    else
        log_success "cargo-deb is installed"
    fi
    
    # cargo-clippy (usually included with Rust)
    if ! command_exists cargo-clippy; then
        log_info "Installing clippy..."
        run_cmd rustup component add clippy
    fi
    
    log_success "Development environment ready"
}

# Build the project
build_project() {
    local mode="release"
    local clean=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug) mode="debug"; shift ;;
            --clean) clean=true; shift ;;
            *) shift ;;
        esac
    done
    
    log_info "Building project ($mode mode)..."
    
    if [[ "$clean" == true ]]; then
        log_info "Cleaning previous build..."
        run_cmd cargo clean
    fi
    
    if [[ "$mode" == "release" ]]; then
        run_cmd cargo build --release
        log_success "Release binary: $RELEASE_DIR/$(cargo metadata --format-version=1 | grep '"name"' | head -1 | cut -d'"' -f4)"
    else
        run_cmd cargo build
        log_success "Debug binary: $BUILD_DIR/debug/$(cargo metadata --format-version=1 | grep '"name"' | head -1 | cut -d'"' -f4)"
    fi
}

# Run tests
run_tests() {
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose | -v) verbose=true; shift ;;
            *) shift ;;
        esac
    done
    
    log_info "Running tests..."
    
    if [[ "$verbose" == true ]]; then
        run_cmd cargo test -- --nocapture
    else
        run_cmd cargo test
    fi
    
    log_success "All tests passed"
}

# Code quality checks
check_code_quality() {
    log_info "Running code quality checks..."
    
    # Format check
    log_info "Checking code formatting..."
    if ! run_cmd cargo fmt -- --check; then
        log_warning "Code format issues found. Run 'cargo fmt' to fix."
    else
        log_success "Code formatting OK"
    fi
    
    # Clippy lint
    log_info "Running Clippy linter..."
    if ! run_cmd cargo clippy -- -D warnings; then
        log_warning "Clippy warnings found. Review and fix."
    else
        log_success "No Clippy warnings"
    fi
    
    # Security audit
    if command_exists cargo-audit; then
        log_info "Running security audit..."
        run_cmd cargo audit
    else
        log_warning "cargo-audit not installed. Run 'cargo install cargo-audit' for security checks."
    fi
}

# Format code
format_code() {
    log_info "Formatting code..."
    run_cmd cargo fmt
    log_success "Code formatted"
}

# Package the project
package_project() {
    local package_deb=true
    local package_source=true
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deb-only) package_source=false; shift ;;
            --source-only) package_deb=false; shift ;;
            *) shift ;;
        esac
    done
    
    log_info "Packaging project..."
    
    # Build release binary first
    build_project --clean
    
    if [[ "$package_source" == true ]]; then
        log_info "Creating source archive..."
        local project_name
        project_name=$(grep '^name' Cargo.toml | head -1 | cut -d'"' -f2)
        local version
        version=$(grep '^version' Cargo.toml | head -1 | cut -d'"' -f2)
        local archive_name="${project_name}-${version}-source.tar.gz"
        
        # Create archive
        run_cmd tar --exclude=target --exclude=.git --exclude=.github \
            -czf "$BUILD_DIR/$archive_name" -C "$PROJECT_ROOT/.." "$(basename "$PROJECT_ROOT")"
        
        log_success "Source archive: $BUILD_DIR/$archive_name"
    fi
    
    if [[ "$package_deb" == true ]]; then
        log_info "Creating Debian package..."
        
        # Check if debian/ directory exists
        if [[ ! -d "$PROJECT_ROOT/debian" ]]; then
            log_error "debian/ directory not found. Cannot create DEB package."
            return 1
        fi
        
        # Use cargo-deb for building
        run_cmd cargo deb
        
        # Get the resulting .deb file
        local deb_file
        deb_file=$(find "$BUILD_DIR" -name "*.deb" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        
        if [[ -f "$deb_file" ]]; then
            log_success "Debian package: $deb_file"
        fi
    fi
}

# Release workflow
release_project() {
    local version=""
    local stage=false
    local no_wait=false
    local timeout=600
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version) version="$2"; shift 2 ;;
            --stage) stage=true; shift ;;
            --no-wait) no_wait=true; shift ;;
            --timeout) timeout="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$version" ]]; then
        log_error "Version required: --version X.Y.Z"
        return 1
    fi
    
    log_info "Starting release workflow for v$version..."
    
    # Check git status
    if [[ ! $(git -C "$PROJECT_ROOT" status -s) == "" ]]; then
        log_warning "Working directory has uncommitted changes"
        read -p "Continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Release cancelled"
            return 1
        fi
    fi
    
    # Show what will be released
    log_info "Git status:"
    git -C "$PROJECT_ROOT" log --oneline -5
    echo
    
    # Verify Cargo.toml has correct version
    local toml_version
    toml_version=$(grep '^version' "$PROJECT_ROOT/Cargo.toml" | head -1 | cut -d'"' -f2)
    
    if [[ "$toml_version" != "$version" ]]; then
        log_warning "Cargo.toml version ($toml_version) differs from release version ($version)"
        read -p "Update Cargo.toml? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s/^version = .*/version = \"$version\"/" "$PROJECT_ROOT/Cargo.toml"
            log_success "Updated Cargo.toml to v$version"
        fi
    fi
    
    # Commit if needed
    if [[ -n $(git -C "$PROJECT_ROOT" status -s) ]]; then
        log_info "Staging changes..."
        read -p "Stage all changes? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_cmd git -C "$PROJECT_ROOT" add -A
            
            local commit_msg="chore: Release v$version"
            if [[ "$stage" == true ]]; then
                commit_msg="chore: Release v${version}-rc$(date +%s)"
            fi
            
            log_info "Commit message: $commit_msg"
            read -p "Confirm? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                run_cmd git -C "$PROJECT_ROOT" commit -m "$commit_msg"
            fi
        fi
    fi
    
    # Create git tag
    local tag_name="v$version"
    if [[ "$stage" == true ]]; then
        tag_name="v${version}-rc$(date +%s)"
    fi
    
    log_info "Creating git tag: $tag_name"
    read -p "Confirm? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Release cancelled"
        return 1
    fi
    
    run_cmd git -C "$PROJECT_ROOT" tag -a "$tag_name" -m "Release $tag_name"
    
    # Push to origin
    log_info "Pushing to origin..."
    read -p "Confirm push? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_cmd git -C "$PROJECT_ROOT" push origin master
        run_cmd git -C "$PROJECT_ROOT" push origin "$tag_name"
        log_success "Pushed to origin"
        
        if [[ "$no_wait" != true ]]; then
            log_info "Waiting for GitHub Actions workflow (max ${timeout}s)..."
            log_warning "Check: https://github.com/pilakkat1964/$(basename "$PROJECT_ROOT")/actions"
        fi
    else
        log_error "Release cancelled"
        return 1
    fi
    
    log_success "Release $tag_name initiated"
}

# Full release workflow
full_workflow() {
    local version=""
    local no_test=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version) version="$2"; shift 2 ;;
            --no-test) no_test=true; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$version" ]]; then
        log_error "Version required: --version X.Y.Z"
        return 1
    fi
    
    log_info "Starting full release workflow for v$version..."
    
    # Setup
    setup_environment || return 1
    
    # Build
    build_project --clean || return 1
    
    # Test (unless skipped)
    if [[ "$no_test" != true ]]; then
        run_tests || return 1
    fi
    
    # Code quality checks
    check_code_quality || log_warning "Code quality checks had warnings"
    
    # Package
    package_project || return 1
    
    # Release
    release_project --version "$version" || return 1
    
    log_success "Full workflow completed successfully!"
}

# Show help
show_help() {
    cat << 'EOF'
Rust Project Development Workflow

USAGE:
    ./scripts/dev.sh <COMMAND> [OPTIONS]

COMMANDS:
    setup               Set up development environment
    build               Build the project (release mode)
    test                Run test suite
    check               Run code quality checks (fmt, clippy, audit)
    format              Format code with rustfmt
    package             Create distribution packages (source + DEB)
    release             Create git tag and GitHub release
    full                Complete release workflow
    help                Show this help message

OPTIONS (global):
    --verbose, -v       Verbose output
    --dry-run           Preview commands without execution

BUILD OPTIONS:
    --debug             Debug build mode (default: release)
    --clean             Clean before building

TEST OPTIONS:
    --verbose, -v       Show test output

PACKAGE OPTIONS:
    --deb-only          Only create DEB package
    --source-only       Only create source archive

RELEASE OPTIONS:
    --version X.Y.Z     Release version (required)
    --stage             Create staging release
    --no-wait           Don't wait for GitHub Actions
    --timeout N         GitHub Actions timeout in seconds (default: 600)

EXAMPLES:
    ./scripts/dev.sh setup
    ./scripts/dev.sh build --clean
    ./scripts/dev.sh test --verbose
    ./scripts/dev.sh check
    ./scripts/dev.sh package
    ./scripts/dev.sh release --version 0.5.0
    ./scripts/dev.sh full --version 0.5.0

FULL WORKFLOW:
    Runs in sequence: setup → build → test → check → package → release

EOF
}

# Main entry point
main() {
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose | -v)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Get command
    local command="${1:-help}"
    shift || true
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Execute command
    case "$command" in
        setup)
            setup_environment "$@"
            ;;
        build)
            build_project "$@"
            ;;
        test)
            run_tests "$@"
            ;;
        check)
            check_code_quality "$@"
            ;;
        format)
            format_code "$@"
            ;;
        package)
            package_project "$@"
            ;;
        release)
            release_project "$@"
            ;;
        full)
            full_workflow "$@"
            ;;
        help | --help | -h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
