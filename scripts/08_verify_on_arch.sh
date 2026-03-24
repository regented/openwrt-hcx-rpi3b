#!/usr/bin/env bash
# Verify that the cloned repository is ready to use on Arch Linux.
#
# Run this ONCE after cloning to check for common issues:
#   - Missing execute permissions on scripts
#   - Windows \r line endings that would break bash
#   - Missing host tools needed by the build
#
# Usage: ./scripts/08_verify_on_arch.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ISSUES=0

echo ""
echo "==> Verifying repository health..."
echo ""

# ── 1. Check execute permissions on scripts ────────────────────────────
echo "--- Script permissions ---"
for script in "$PROJECT_DIR"/scripts/*.sh; do
    name=$(basename "$script")
    if [ ! -x "$script" ]; then
        printf "  ${YELLOW}WARN${NC}  %-35s %s\n" "$name" "not executable — run: chmod +x scripts/$name"
        ISSUES=$((ISSUES + 1))
    else
        printf "  ${GREEN}OK${NC}    %-35s %s\n" "$name" "executable"
    fi
done

# ── 2. Check for \r line endings ───────────────────────────────────────
echo ""
echo "--- Line endings ---"
CR_FILES=()

# Check .sh files
while IFS= read -r -d '' f; do
    if grep -qP '\r' "$f" 2>/dev/null; then
        CR_FILES+=("$f")
    fi
done < <(find "$PROJECT_DIR/scripts" -name '*.sh' -print0 2>/dev/null)

# Check Makefiles
while IFS= read -r -d '' f; do
    if grep -qP '\r' "$f" 2>/dev/null; then
        CR_FILES+=("$f")
    fi
done < <(find "$PROJECT_DIR/packages" -name 'Makefile' -print0 2>/dev/null)

# Check rootfs overlay files
while IFS= read -r -d '' f; do
    if [ -f "$f" ] && grep -qP '\r' "$f" 2>/dev/null; then
        CR_FILES+=("$f")
    fi
done < <(find "$PROJECT_DIR/files" -type f -print0 2>/dev/null)

if [ ${#CR_FILES[@]} -eq 0 ]; then
    printf "  ${GREEN}OK${NC}    No \\\\r (CRLF) line endings found\n"
else
    for f in "${CR_FILES[@]}"; do
        rel="${f#$PROJECT_DIR/}"
        printf "  ${YELLOW}WARN${NC}  %-35s %s\n" "$rel" "has \\r endings — fix: sed -i 's/\\r$//' $rel"
        ISSUES=$((ISSUES + 1))
    done
fi

# ── 3. Check host tools ───────────────────────────────────────────────
echo ""
echo "--- Host tools ---"

# tool:pacman-package
TOOLS=(
    "git:git"
    "make:make"
    "gcc:gcc"
    "g++:gcc"
    "wget:wget"
    "curl:curl"
    "python3:python"
    "perl:perl"
    "rsync:rsync"
    "file:file"
    "gawk:gawk"
    "gettext:gettext"
    "unzip:unzip"
    "swig:swig"
)

MISSING_PKGS=()
for entry in "${TOOLS[@]}"; do
    tool="${entry%%:*}"
    pkg="${entry#*:}"
    if command -v "$tool" &>/dev/null; then
        printf "  ${GREEN}OK${NC}    %-35s %s\n" "$tool" "found"
    else
        printf "  ${RED}MISS${NC}  %-35s %s\n" "$tool" "not found — sudo pacman -S $pkg"
        MISSING_PKGS+=("$pkg")
        ISSUES=$((ISSUES + 1))
    fi
done

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "========================================"
if [ "$ISSUES" -gt 0 ]; then
    printf "  ${YELLOW}%d issue(s) found.${NC}\n" "$ISSUES"
    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        # Deduplicate
        UNIQUE_PKGS=($(printf '%s\n' "${MISSING_PKGS[@]}" | sort -u))
        echo ""
        echo "  Install missing packages:"
        echo "    sudo pacman -S --needed ${UNIQUE_PKGS[*]}"
    fi
    echo ""
    echo "  Fix any issues above, then run:"
else
    printf "  ${GREEN}All checks passed.${NC}\n"
    echo ""
    echo "  Next step:"
fi
echo "    ./scripts/01_setup_buildenv.sh"
echo ""
