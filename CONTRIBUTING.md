# Contributing to z-rclone-mount-applete

Thank you for your interest in contributing to z-rclone-mount-applete! This document provides guidelines and instructions for contributing code, documentation, bug reports, and feature suggestions.

## Code of Conduct

Be respectful, inclusive, and professional. All contributors are expected to maintain a welcoming environment for everyone.

## How to Contribute

### 1. Reporting Bugs

**Before submitting a bug report:**
- Check existing issues to avoid duplicates
- Verify the bug still exists on the latest version
- Gather relevant information (version, system, error messages)

**When submitting a bug report, include:**
- Clear title summarizing the issue
- Detailed description with steps to reproduce
- Expected vs. actual behavior
- System information (OS, Rust version, architecture, DE)
- Error messages, logs, or stack traces
- Output of `systemctl --user status rclone-mount-tray.service`

### 2. Suggesting Features

**Feature suggestions should include:**
- Clear use case explaining why this feature is needed
- Detailed description of expected behavior
- Examples or mockups if applicable
- Discussion of potential implementation approaches
- Links to related discussions or features

### 3. Submitting Code Changes

#### Setup Your Development Environment

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Clone the repository
git clone git@github.com:pilakkat1964/z-rclone-mount-applete.git
cd z-rclone-mount-applete

# Build the project
cargo build --release

# Run tests
cargo test

# Verify setup
rustc --version
cargo --version
```

#### Development Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or for bug fixes:
   git checkout -b fix/issue-number-description
   ```

2. **Make your changes:**
   - Write clear, focused commits with descriptive messages
   - Follow Rust conventions and idioms
   - Add tests for new functionality
   - Update documentation as needed

3. **Run tests and checks:**
   ```bash
   # Run all checks
   cargo test               # Run tests
   cargo clippy             # Lint checking
   cargo fmt --check        # Check formatting
   cargo build --release    # Release build
   cargo audit              # Security audit
   cargo doc --open         # Generate and view docs
   ```

4. **Commit your changes:**
   ```bash
   git add [files]
   git commit -m "type: brief description

   More detailed explanation if needed.
   - Use bullet points for multiple changes
   - Reference issue numbers: fixes #123"
   ```

   **Commit message guidelines:**
   - Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `style:`, `chore:`
   - First line should be concise (50 chars or less)
   - Provide detailed explanation in the body
   - Reference related issues or PRs

5. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request:**
   - Clear title describing the change
   - Reference related issues (e.g., "Fixes #123")
   - Describe what changed and why
   - List any breaking changes
   - Include output from `cargo test` if relevant

#### Code Style Guidelines

**z-rclone-mount-applete follows these standards:**
- Follow Rust conventions and idioms
- Use `cargo fmt` for formatting (mandatory)
- Address all `cargo clippy` warnings
- Write tests for public APIs
- Document public items with doc comments
- Use meaningful error messages with `anyhow::Context`
- Keep error handling ergonomic with Result types
- Prefer async/await for I/O operations

**Important standards:**
- No `unwrap()` in production code (use `?` operator)
- Proper error context with `.context("message")`
- Use `tokio` for async operations
- Thread-safe state management with `Mutex<T>`
- Test error paths thoroughly

#### Testing Requirements

- Write unit tests for new modules
- Ensure all tests pass: `cargo test`
- Test error handling and edge cases
- Use meaningful assertions with context
- Add documentation examples in doc comments
- Test configuration parsing with various inputs
- Test systemd integration points
- Test mount detection and status checks

### 4. Documentation Contributions

Documentation improvements are valuable! You can contribute by:

- **Fixing typos and clarifying text** in existing docs
- **Adding examples** to API documentation or guides
- **Creating new guides** for integration and configuration
- **Improving architecture documentation** for developers
- **Adding visual diagrams** for system components
- **Adding code comments** for complex async operations

**Documentation guidelines:**
- Use clear, accessible language
- Include examples and code snippets
- Keep examples tested and up-to-date
- Use consistent formatting and terminology
- Link related documentation sections
- Maintain YAML front matter for Jekyll pages

## Project Structure

```
z-rclone-mount-applete/
├── src/
│   ├── main.rs                # 100 lines - Entry point
│   ├── mount_manager.rs       # 330 lines - Mount management
│   ├── systemd_manager.rs     # 90 lines - Systemd integration
│   └── tray_ui.rs            # 95 lines - UI layer
├── Cargo.toml                # Project manifest (v0.1.0)
├── Cargo.lock                # Dependency lock
├── README.md                 # Project overview (420 lines)
├── scripts/
│   ├── build.sh             # Build script
│   └── build-deb.sh         # Debian build script
├── debian/                  # Debian packaging
├── docs/                    # Comprehensive documentation (2,000+ lines)
│   ├── PROJECT_SUMMARY.md
│   ├── ARCHITECTURE.md      # Visual diagrams and flows
│   ├── QUICK_START.md
│   ├── TUTORIAL.md
│   ├── RUST_LEARNING_GUIDE.md
│   └── [more guides]
├── data/
│   ├── rclone-mount-tray.desktop
│   └── rclone-mount-tray.service
├── .github/workflows/       # CI/CD
├── README.md                # Project overview
└── AGENTS.md                # Agent documentation
```

## Building and Testing Locally

```bash
# Build debug binary (fast, larger)
cargo build

# Build release binary (optimized, ~975 KB)
cargo build --release

# Run tests
cargo test

# Check code quality
cargo clippy
cargo fmt --check
cargo audit

# Generate documentation
cargo doc --open

# Build Debian package
./scripts/build-deb.sh --clean

# Run the applet
./target/release/rclone-mount-tray

# Check systemd status (if installed)
systemctl --user status rclone-mount-tray.service
```

## Understanding the Codebase

### Module Structure (591 lines total)

1. **main.rs (100 lines)** - Application entry point
   - `App` struct for application state
   - Main event loop and refresh cycle (5 seconds)
   - Mount/unmount toggle handlers
   - Error recovery and graceful shutdown

2. **mount_manager.rs (330 lines)** - Core mount management
   - `MountConfig` - Single mount configuration
   - `MountStatus` - Enum: Mounted, Unmounted, Error
   - `MountInfo` - Combined config + status + size
   - `MountManager` - Central manager for all mounts
   - Configuration loading from TOML
   - Mount point status detection via /proc/mounts
   - Size calculation for mounted filesystems

3. **systemd_manager.rs (90 lines)** - Systemd integration
   - Async systemd service control
   - Start/stop mount operations
   - Query service status
   - Generate systemd service files
   - Daemon reload and lifecycle management

4. **tray_ui.rs (95 lines)** - System tray presentation
   - Mount status visualization
   - Menu display and user actions
   - Status indicators (Green/Orange/Red)

### Configuration System

**Mount Configuration File:**
- Location: `~/.config/rclone-mount-tray/mounts.toml`
- Format: TOML with `[[mounts]]` array

**Example Configuration:**
```toml
[[mounts]]
remote = "gdrive_pilakkat"
mount_point = "/home/user/gdrive_pilakkat"

[[mounts]]
remote = "s3_backup"
mount_point = "/home/user/s3_backup"
```

### Key Data Structures

**MountConfig** - Single mount configuration
- `remote`: Name of rclone remote
- `mount_point`: Filesystem location

**MountStatus** - Current mount state
- `Mounted`: Mount point is active
- `Unmounted`: Mount point not active
- `Error(String)`: Error message

**MountInfo** - Full mount information
- Config + Status + Size information
- Used for UI display and user actions

## Dependencies

**Key Crates:**
- `tokio` (async runtime and process management)
- `serde` (configuration serialization)
- `toml` (configuration file format)
- `tracing` (structured logging)
- `anyhow` (ergonomic error handling)
- `dirs` (cross-platform directory detection)

**Rationale:**
- `tokio`: Non-blocking async I/O for systemd operations
- `serde`: Robust configuration parsing
- `tracing`: Debugging and monitoring support
- `anyhow`: Clean error propagation with context

## Release Process

### Versioning

Uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes to API or configuration
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes and improvements

### Creating a Release

1. **Update version** in `Cargo.toml`
2. **Update changelog** in debian/changelog or git history
3. **Commit changes**: `git commit -m "chore: bump version to X.Y.Z"`
4. **Create git tag**: `git tag vX.Y.Z -m "Release vX.Y.Z"`
5. **Push to remote**: `git push origin master && git push origin vX.Y.Z`
6. **GitHub Actions will automatically:**
   - Run tests on Rust stable
   - Run clippy linting and security audit
   - Build for AMD64 (native) and ARM64 (cross-compile)
   - Build Debian packages for both architectures
   - Create GitHub Release with all artifacts
   - Publish to Crates.io

See `AGENTS.md` for detailed release procedures.

## Getting Help

- **Documentation**: See `docs/` folder - comprehensive guides
- **Quick Start**: See `docs/QUICK_START.md` (5-minute setup)
- **Tutorial**: See `docs/TUTORIAL.md` for step-by-step guide
- **Architecture**: See `docs/ARCHITECTURE.md` (visual diagrams)
- **API**: See `docs/api-reference.md` for code structure
- **Learning**: See `docs/RUST_LEARNING_GUIDE.md` for Rust concepts
- **Project**: See `AGENTS.md` for overall status
- **Issues**: Check existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions

## Important Notes

### Desktop Environment Support

**Tested Environments:**
- KDE Plasma 5.x / 6.x ✅
- GNOME 40+ (may need extension) ✅
- XFCE (with system tray) ✅

**Status Indicators:**
- 🟢 Green: All mounts active
- 🟡 Orange: Partial mounts active
- 🔴 Red: Error or unmounted

### Performance Characteristics

- **Binary Size**: ~975 KB (release, optimized)
- **Startup Time**: <500 ms
- **Memory Usage**: 20-30 MB (idle)
- **CPU Usage**: <1% (idle), <5% (during refresh)
- **Status Refresh**: 5-second cycle
- **Mount Detection**: 100-500 ms

### Integration Points

- **systemd**: User-level service management
- **rclone**: Reads configuration and controls mounts
- **Bash**: Compatible with existing mount scripts
- **Desktop**: .desktop file for application menu

## License

By contributing to z-rclone-mount-applete, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors are valued and recognized! We may mention contributors in:
- Release notes
- Project README
- Contributor list

Thank you for contributing to z-rclone-mount-applete! 🙏
