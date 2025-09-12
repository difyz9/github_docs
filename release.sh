#!/bin/bash

# GitHub Release 发布脚本 (使用GitHub CLI)
# 使用方法: ./release.sh

set -e

# 配置变量 - 请根据您的项目修改这些值
REPO="difyz9/hello_world"        # 替换为您的GitHub仓库 (格式: owner/repo)
ARCHIVE_PATH="./trans-video-x-windows-x64.zip"         # 替换为您的压缩包路径
DEFAULT_VERSION="v1.0.0"          # 默认版本号

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查必要工具
check_requirements() {
    print_step "Checking requirements..."
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed."
        echo "Please install it with: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated."
        echo "Please run: gh auth login"
        exit 1
    fi
    
    print_info "All requirements satisfied."
}

# 获取版本号
get_version() {
    print_step "Getting version..."
    
    # 尝试从git tag获取最新版本
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -n "$LATEST_TAG" ]; then
        print_info "Latest git tag: $LATEST_TAG"
        read -p "Enter new version (press Enter for $DEFAULT_VERSION): " VERSION
    else
        read -p "Enter version (press Enter for $DEFAULT_VERSION): " VERSION
    fi
    
    # 如果用户没有输入，使用默认版本
    if [ -z "$VERSION" ]; then
        VERSION="$DEFAULT_VERSION"
    fi
    
    # 确保版本号以v开头
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    print_info "Using version: $VERSION"
}

# 检查压缩包是否存在
check_archive() {
    print_step "Checking archive..."
    
    if [ ! -f "$ARCHIVE_PATH" ]; then
        print_error "Archive not found: $ARCHIVE_PATH"
        print_info "Please create your archive first, or update ARCHIVE_PATH in this script."
        exit 1
    fi
    
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    print_info "Archive found: $ARCHIVE_PATH ($ARCHIVE_SIZE)"
}

# 创建release notes
create_release_notes() {
    RELEASE_NOTES="## Release $VERSION

### 📦 Downloads
Download the archive from the assets below.

### 🔄 Changes
- Add your changes here
- Update this section with actual release notes

### 📅 Release Date
$(date '+%Y-%m-%d %H:%M:%S')

---
*This release was created automatically using the release script.*"
}

# 确认发布
confirm_release() {
    print_step "Release confirmation"
    echo "Repository: $REPO"
    echo "Version: $VERSION"
    echo "Archive: $ARCHIVE_PATH"
    echo ""
    
    read -p "Do you want to create this release? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Release cancelled."
        exit 0
    fi
}

# 创建GitHub Release
create_release() {
    print_step "Creating GitHub Release..."
    
    create_release_notes
    
    # 检查release是否已存在
    if gh release view "$VERSION" --repo "$REPO" &>/dev/null; then
        print_warning "Release $VERSION already exists."
        read -p "Do you want to delete and recreate it? [y/N]: " recreate
        
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            print_info "Deleting existing release..."
            gh release delete "$VERSION" --repo "$REPO" --yes
        else
            print_info "Release cancelled."
            exit 0
        fi
    fi
    
    # 创建release
    if gh release create "$VERSION" "$ARCHIVE_PATH" \
        --repo "$REPO" \
        --title "Release $VERSION" \
        --notes "$RELEASE_NOTES" \
        --latest; then
        
        print_info "✅ Release created successfully!"
        print_info "🔗 View at: https://github.com/$REPO/releases/tag/$VERSION"
    else
        print_error "❌ Failed to create release"
        exit 1
    fi
}

# 主函数
main() {
    echo "🚀 GitHub Release Publisher"
    echo "=========================="
    echo ""
    
    check_requirements
    get_version
    check_archive
    confirm_release
    create_release
    
    echo ""
    print_info "🎉 Release process completed successfully!"
}

# 执行主函数
main "$@"
