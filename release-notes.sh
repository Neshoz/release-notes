#!/bin/bash

# Release Notes Generator
# Generates release notes from commit messages between two git references

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FILE=""
BASE_REF="development"
HEAD_REF="HEAD"
INCLUDE_AUTHORS=false
GROUP_BY_TYPE=false
VERSION=""

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate release notes from git commit messages.

OPTIONS:
    -b, --base REF          Base reference (default: development)
    -h, --head REF          Head reference (default: HEAD)
    -o, --output FILE       Output file (default: auto-generated from version)
    -v, --version VERSION   Version string (auto-detected from branch name if not provided)
    -a, --authors           Include commit authors
    -g, --group             Group commits by type (feat, fix, docs, etc.)
    --help                  Show this help message

EXAMPLES:
    # Generate notes for current branch (auto-detects version from branch name)
    $(basename "$0")
    
    # Generate notes for release-1.2.3 branch
    $(basename "$0") -h release-1.2.3
    
    # Specify version explicitly
    $(basename "$0") -v 2.0.0 -b development -h release-branch
    
    # Generate notes with authors and grouping
    $(basename "$0") -h release-1.2.3 -a -g

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--base)
            BASE_REF="$2"
            shift 2
            ;;
        -h|--head)
            HEAD_REF="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -a|--authors)
            INCLUDE_AUTHORS=true
            shift
            ;;
        -g|--group)
            GROUP_BY_TYPE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Verify references exist
if ! git rev-parse --verify "$BASE_REF" > /dev/null 2>&1; then
    echo -e "${RED}Error: Base reference '$BASE_REF' not found${NC}"
    exit 1
fi

if ! git rev-parse --verify "$HEAD_REF" > /dev/null 2>&1; then
    echo -e "${RED}Error: Head reference '$HEAD_REF' not found${NC}"
    exit 1
fi

# Auto-detect version from branch name if not provided
if [ -z "$VERSION" ]; then
    # Try to extract version from HEAD_REF (e.g., release-1.2.3 -> 1.2.3)
    if [[ "$HEAD_REF" =~ ^release-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        VERSION="${BASH_REMATCH[1]}"
        echo -e "${GREEN}Auto-detected version: $VERSION${NC}"
    elif [ "$HEAD_REF" = "HEAD" ]; then
        # If HEAD, try to get current branch name
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ "$CURRENT_BRANCH" =~ ^release-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            VERSION="${BASH_REMATCH[1]}"
            echo -e "${GREEN}Auto-detected version from current branch: $VERSION${NC}"
        fi
    fi
fi

# Set default output file based on version
if [ -z "$OUTPUT_FILE" ]; then
    if [ -n "$VERSION" ]; then
        OUTPUT_FILE="RELEASE_NOTES_v${VERSION}.md"
    else
        OUTPUT_FILE="RELEASE_NOTES.md"
    fi
fi

# Get commit range
COMMIT_RANGE="$BASE_REF..$HEAD_REF"

# Count commits
COMMIT_COUNT=$(git rev-list --count "$COMMIT_RANGE" 2>/dev/null || echo "0")

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}Warning: No commits found between $BASE_REF and $HEAD_REF${NC}"
    exit 0
fi

echo -e "${GREEN}Generating release notes...${NC}"
if [ -n "$VERSION" ]; then
    echo "Version: $VERSION"
fi
echo "Commits: $COMMIT_COUNT"
echo "Range: $BASE_REF..$HEAD_REF"
echo "Output: $OUTPUT_FILE"

# Start generating release notes
{
    if [ -n "$VERSION" ]; then
        echo "# Release Notes - Version $VERSION"
    else
        echo "# Release Notes"
    fi
    echo ""
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    if [ -n "$VERSION" ]; then
        echo "**Version:** $VERSION"
    fi
    echo "**Range:** \`$BASE_REF\` → \`$HEAD_REF\`"
    echo "**Total Commits:** $COMMIT_COUNT"
    echo ""
    
    if [ "$GROUP_BY_TYPE" = true ]; then
        # Group commits by conventional commit type
        echo "## Changes"
        echo ""
        
        # Features
        FEATURES=$(git log "$COMMIT_RANGE" --pretty=format:"%s|%an|%h" | grep -i "^feat" || true)
        if [ -n "$FEATURES" ]; then
            echo "### ✨ Features"
            echo ""
            while IFS='|' read -r msg author hash; do
                cleaned_msg=$(echo "$msg" | sed 's/^feat[:(].*[):] *//')
                if [ "$INCLUDE_AUTHORS" = true ]; then
                    echo "- $cleaned_msg (\`$hash\` by @$author)"
                else
                    echo "- $cleaned_msg (\`$hash\`)"
                fi
            done <<< "$FEATURES"
            echo ""
        fi
        
        # Bug fixes
        FIXES=$(git log "$COMMIT_RANGE" --pretty=format:"%s|%an|%h" | grep -i "^fix" || true)
        if [ -n "$FIXES" ]; then
            echo "### 🐛 Bug Fixes"
            echo ""
            while IFS='|' read -r msg author hash; do
                cleaned_msg=$(echo "$msg" | sed 's/^fix[:(].*[):] *//')
                if [ "$INCLUDE_AUTHORS" = true ]; then
                    echo "- $cleaned_msg (\`$hash\` by @$author)"
                else
                    echo "- $cleaned_msg (\`$hash\`)"
                fi
            done <<< "$FIXES"
            echo ""
        fi
        
        # Documentation
        DOCS=$(git log "$COMMIT_RANGE" --pretty=format:"%s|%an|%h" | grep -i "^docs" || true)
        if [ -n "$DOCS" ]; then
            echo "### 📚 Documentation"
            echo ""
            while IFS='|' read -r msg author hash; do
                cleaned_msg=$(echo "$msg" | sed 's/^docs[:(].*[):] *//')
                if [ "$INCLUDE_AUTHORS" = true ]; then
                    echo "- $cleaned_msg (\`$hash\` by @$author)"
                else
                    echo "- $cleaned_msg (\`$hash\`)"
                fi
            done <<< "$DOCS"
            echo ""
        fi
        
        # Chores
        CHORES=$(git log "$COMMIT_RANGE" --pretty=format:"%s|%an|%h" | grep -i "^chore" || true)
        if [ -n "$CHORES" ]; then
            echo "### 🔧 Chores"
            echo ""
            while IFS='|' read -r msg author hash; do
                cleaned_msg=$(echo "$msg" | sed 's/^chore[:(].*[):] *//')
                if [ "$INCLUDE_AUTHORS" = true ]; then
                    echo "- $cleaned_msg (\`$hash\` by @$author)"
                else
                    echo "- $cleaned_msg (\`$hash\`)"
                fi
            done <<< "$CHORES"
            echo ""
        fi
    else
        # Simple list of all commits
        echo "## Changes"
        echo ""
        
        if [ "$INCLUDE_AUTHORS" = true ]; then
            git log "$COMMIT_RANGE" --pretty=format:"- %s (\`%h\` by @%an)" --reverse
        else
            git log "$COMMIT_RANGE" --pretty=format:"- %s (\`%h\`)" --reverse
        fi
        echo ""
        echo ""
    fi
    
    # Contributors
    if [ "$INCLUDE_AUTHORS" = true ]; then
        echo "## Contributors"
        echo ""
        git log "$COMMIT_RANGE" --pretty=format:"%an" | sort -u | while read -r author; do
            echo "- @$author"
        done
        echo ""
    fi
    
} > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Release notes generated successfully!${NC}"
echo "File: $OUTPUT_FILE"