#!/bin/bash
#
# Setup script for AcmeApp development environment.
# Installs required tools: Homebrew, Tuist, Python 3.
#
# Usage:
#   ./Scripts/setup.sh          # Install all tools
#   ./Scripts/setup.sh --check  # Check what's installed (no changes)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
fi

print_status() {
    local status="$1"
    local name="$2"
    local version="${3:-}"

    if [[ "$status" == "ok" ]]; then
        if [[ -n "$version" ]]; then
            echo -e "${GREEN}✓${NC} $name ${BLUE}($version)${NC}"
        else
            echo -e "${GREEN}✓${NC} $name"
        fi
    elif [[ "$status" == "missing" ]]; then
        echo -e "${RED}✗${NC} $name ${YELLOW}(not installed)${NC}"
    elif [[ "$status" == "installing" ]]; then
        echo -e "${YELLOW}→${NC} Installing $name..."
    fi
}

check_homebrew() {
    if command -v brew &> /dev/null; then
        local version
        version=$(brew --version | head -1 | cut -d' ' -f2)
        print_status "ok" "Homebrew" "$version"
        return 0
    else
        print_status "missing" "Homebrew"
        return 1
    fi
}

install_homebrew() {
    print_status "installing" "Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    check_homebrew
}

check_tuist() {
    if command -v tuist &> /dev/null; then
        local version
        version=$(tuist version 2>/dev/null || echo "unknown")
        print_status "ok" "Tuist" "$version"
        return 0
    else
        print_status "missing" "Tuist"
        return 1
    fi
}

install_tuist() {
    print_status "installing" "Tuist"
    curl -Ls https://install.tuist.io | bash
    check_tuist
}

check_python() {
    if command -v python3 &> /dev/null; then
        local version
        version=$(python3 --version 2>/dev/null | cut -d' ' -f2)
        print_status "ok" "Python 3" "$version"
        return 0
    else
        print_status "missing" "Python 3"
        return 1
    fi
}

install_python() {
    print_status "installing" "Python 3 (via Homebrew)"
    brew install python3
    check_python
}

check_xcode_cli() {
    if xcode-select -p &> /dev/null; then
        print_status "ok" "Xcode Command Line Tools"
        return 0
    else
        print_status "missing" "Xcode Command Line Tools"
        return 1
    fi
}

install_xcode_cli() {
    print_status "installing" "Xcode Command Line Tools"
    xcode-select --install 2>/dev/null || true
    echo -e "${YELLOW}   ↳ Follow the prompt to complete installation${NC}"
}

# Main
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  AcmeApp Development Environment Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

if $CHECK_ONLY; then
    echo -e "${YELLOW}Check mode — no changes will be made${NC}"
    echo ""
fi

MISSING=()

# Check/Install Xcode CLI
if ! check_xcode_cli; then
    MISSING+=("xcode-cli")
    if ! $CHECK_ONLY; then
        install_xcode_cli
    fi
fi

# Check/Install Homebrew
if ! check_homebrew; then
    MISSING+=("homebrew")
    if ! $CHECK_ONLY; then
        install_homebrew
    fi
fi

# Check/Install Python 3
if ! check_python; then
    MISSING+=("python3")
    if ! $CHECK_ONLY; then
        install_python
    fi
fi

# Check/Install Tuist
if ! check_tuist; then
    MISSING+=("tuist")
    if ! $CHECK_ONLY; then
        install_tuist
    fi
fi

echo ""
echo -e "${BLUE}───────────────────────────────────────────${NC}"

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo -e "${GREEN}All tools are installed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  make          # Generate Xcode workspace"
    echo "  make bootstrap # Full setup with deps"
else
    if $CHECK_ONLY; then
        echo -e "${YELLOW}Missing tools: ${MISSING[*]}${NC}"
        echo ""
        echo "Run without --check to install:"
        echo "  make setup"
    else
        echo -e "${GREEN}Setup complete!${NC}"
    fi
fi

echo ""
