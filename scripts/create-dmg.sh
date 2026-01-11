#!/bin/bash
#
# create-dmg.sh
# Builds, signs, creates DMG, notarizes, and staples for distribution
#
# Usage:
#   ./scripts/create-dmg.sh                    # Uses version from Xcode project
#   ./scripts/create-dmg.sh --version 1.2.3    # Override version
#   ./scripts/create-dmg.sh --skip-notarize    # Skip notarization (local testing)
#
# Required Environment Variables:
#   DEVELOPER_ID_APPLICATION      Developer ID Application certificate identity
#   APPLE_TEAM_ID                 Team ID
#
# Required for notarization (unless --skip-notarize):
#   APPLE_ID                      Apple ID for notarization
#   APPLE_APP_SPECIFIC_PASSWORD   App-specific password for notarization

set -euo pipefail

# Configuration
APP_NAME="ClaudeCodeUsage"
SCHEME="ClaudeCodeUsage"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="${PROJECT_ROOT}/ClaudeCodeUsage.xcodeproj"
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# Defaults
VERSION=""
SKIP_NOTARIZE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { log_error "$1"; exit 1; }

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build, sign, create DMG, notarize, and staple ClaudeCodeUsage for distribution.

Options:
    --version X.Y.Z     Override version number (default: read from Xcode project)
    --skip-notarize     Skip notarization step (for local testing)
    -h, --help          Show this help message

Required Environment Variables:
    DEVELOPER_ID_APPLICATION    Certificate identity (e.g., "Developer ID Application: Name (TEAMID)")
    APPLE_TEAM_ID               Apple Developer Team ID

Required for notarization:
    APPLE_ID                    Apple ID email
    APPLE_APP_SPECIFIC_PASSWORD App-specific password from appleid.apple.com

Examples:
    # Local testing without notarization
    export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
    export APPLE_TEAM_ID="TEAMID"
    ./scripts/create-dmg.sh --skip-notarize

    # Full release with notarization
    export APPLE_ID="you@example.com"
    export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
    ./scripts/create-dmg.sh --version 1.0.0
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --skip-notarize)
                SKIP_NOTARIZE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        die "Xcode command line tools not found. Install with: xcode-select --install"
    fi

    # Check create-dmg (sindresorhus version)
    if ! command -v create-dmg &> /dev/null; then
        die "create-dmg not found. Install with: brew install create-dmg"
    fi

    # Check required environment variables
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        die "DEVELOPER_ID_APPLICATION environment variable not set"
    fi

    if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
        die "APPLE_TEAM_ID environment variable not set"
    fi

    # Check notarization credentials if not skipping
    if [[ "$SKIP_NOTARIZE" == false ]]; then
        if [[ -z "${APPLE_ID:-}" ]]; then
            die "APPLE_ID environment variable not set (required for notarization)"
        fi
        if [[ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
            die "APPLE_APP_SPECIFIC_PASSWORD environment variable not set (required for notarization)"
        fi
    fi

    # Verify signing identity exists
    if ! security find-identity -v -p codesigning | grep -q "${DEVELOPER_ID_APPLICATION}"; then
        log_warn "Signing identity '${DEVELOPER_ID_APPLICATION}' not found in keychain"
        log_warn "Available identities:"
        security find-identity -v -p codesigning
        die "Please check your DEVELOPER_ID_APPLICATION value"
    fi

    log_info "Prerequisites OK"
}

get_version() {
    if [[ -n "$VERSION" ]]; then
        log_info "Using specified version: $VERSION"
        return
    fi

    # Extract version from Xcode project
    VERSION=$(xcodebuild -project "$PROJECT_FILE" -showBuildSettings 2>/dev/null | \
        grep "MARKETING_VERSION" | head -1 | awk '{print $3}')

    if [[ -z "$VERSION" ]]; then
        die "Could not determine version from Xcode project"
    fi

    log_info "Using version from Xcode project: $VERSION"
}

clean_build() {
    log_info "Cleaning previous build artifacts..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

build_archive() {
    log_info "Building archive..."

    xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        MARKETING_VERSION="$VERSION" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
        DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
        OTHER_CODE_SIGN_FLAGS="--options=runtime"

    if [[ ! -d "$ARCHIVE_PATH" ]]; then
        die "Archive failed - no archive created"
    fi

    log_info "Archive created: $ARCHIVE_PATH"
}

export_archive() {
    log_info "Exporting archive..."

    # Create ExportOptions.plist
    local export_options="${BUILD_DIR}/ExportOptions.plist"
    cat > "$export_options" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$export_options"

    if [[ ! -d "${EXPORT_PATH}/${APP_NAME}.app" ]]; then
        die "Export failed - no app bundle created"
    fi

    log_info "App exported: ${EXPORT_PATH}/${APP_NAME}.app"
}

create_dmg() {
    log_info "Creating DMG..."

    # create-dmg (sindresorhus version) creates nice DMG automatically
    # It outputs to the same directory as the app by default
    create-dmg \
        --overwrite \
        --identity="$DEVELOPER_ID_APPLICATION" \
        "${EXPORT_PATH}/${APP_NAME}.app" \
        "$BUILD_DIR"

    # Find the created DMG (includes version from app bundle)
    local created_dmg
    created_dmg=$(find "$BUILD_DIR" -maxdepth 1 -name "${APP_NAME}*.dmg" -type f | head -1)

    if [[ -z "$created_dmg" || ! -f "$created_dmg" ]]; then
        die "DMG creation failed"
    fi

    # Rename to stable name (no version - keeps download URL consistent)
    DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
    if [[ "$created_dmg" != "$DMG_PATH" ]]; then
        mv "$created_dmg" "$DMG_PATH"
    fi

    log_info "DMG created: $DMG_PATH"
}

sign_dmg() {
    log_info "Signing DMG..."

    codesign --force --sign "$DEVELOPER_ID_APPLICATION" \
        --options runtime \
        "$DMG_PATH"

    # Verify signature
    codesign --verify --verbose "$DMG_PATH"

    log_info "DMG signed successfully"
}

notarize_dmg() {
    if [[ "$SKIP_NOTARIZE" == true ]]; then
        log_warn "Skipping notarization (--skip-notarize specified)"
        return
    fi

    log_info "Submitting for notarization..."

    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait

    log_info "Stapling notarization ticket..."

    xcrun stapler staple "$DMG_PATH"

    log_info "Notarization complete"
}

verify_dmg() {
    log_info "Verifying DMG..."

    # Check Gatekeeper acceptance
    if spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH" 2>&1; then
        log_info "DMG passes Gatekeeper check"
    else
        log_warn "DMG may not pass Gatekeeper (expected if not notarized)"
    fi
}

main() {
    parse_args "$@"
    check_prerequisites
    get_version
    clean_build
    build_archive
    export_archive
    create_dmg
    sign_dmg
    notarize_dmg
    verify_dmg

    echo ""
    log_info "Release build complete!"
    log_info "DMG: ${DMG_PATH}"
    log_info "Size: $(du -h "$DMG_PATH" | cut -f1)"
}

main "$@"
