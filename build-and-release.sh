#!/bin/bash

# 构建和发布脚本 - 完整的自动化流程
# 这个脚本会自动构建项目、创建压缩包并发布到GitHub Release

set -e

# 配置变量
REPO="username/repository"        # 替换为您的GitHub仓库
PROJECT_DIR="."                   # 项目根目录
BUILD_DIR="./dist"               # 构建输出目录
ARCHIVE_NAME="release.zip"        # 压缩包名称
ARCHIVE_PATH="./$ARCHIVE_NAME"    # 压缩包路径

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 清理函数
cleanup() {
    if [ -f "$ARCHIVE_PATH" ]; then
        print_info "Cleaning up temporary files..."
        rm -f "$ARCHIVE_PATH"
    fi
}

# 设置trap来在脚本退出时清理
trap cleanup EXIT

# 检查必要工具
check_requirements() {
    print_step "Checking requirements..."
    
    local missing_tools=()
    
    if ! command -v gh &> /dev/null; then
        missing_tools+=("GitHub CLI (gh)")
    fi
    
    if ! command -v zip &> /dev/null; then
        missing_tools+=("zip")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Install GitHub CLI with: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated. Please run: gh auth login"
        exit 1
    fi
    
    print_info "All requirements satisfied."
}

# 获取版本号
get_version() {
    print_step "Determining version..."
    
    # 尝试从多个来源获取版本号
    VERSION=""
    
    # 1. 从package.json获取 (如果存在)
    if [ -f "package.json" ] && command -v jq &> /dev/null; then
        PKG_VERSION=$(jq -r '.version // empty' package.json 2>/dev/null || echo "")
        if [ -n "$PKG_VERSION" ]; then
            print_info "Found version in package.json: $PKG_VERSION"
            VERSION="v$PKG_VERSION"
        fi
    fi
    
    # 2. 从git tag获取最新版本
    if [ -z "$VERSION" ]; then
        LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        if [ -n "$LATEST_TAG" ]; then
            print_info "Latest git tag: $LATEST_TAG"
        fi
    fi
    
    # 3. 让用户输入版本号
    while [ -z "$VERSION" ]; do
        read -p "Enter version (e.g., v1.0.0): " VERSION
        if [ -z "$VERSION" ]; then
            print_warning "Version is required!"
        fi
    done
    
    # 确保版本号以v开头
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    print_info "Using version: $VERSION"
}

# 构建项目
build_project() {
    print_step "Building project..."
    
    # 检测项目类型并执行相应的构建命令
    if [ -f "package.json" ]; then
        print_info "Detected Node.js project"
        
        if [ -f "package-lock.json" ]; then
            npm ci
        elif [ -f "yarn.lock" ]; then
            yarn install --frozen-lockfile
        else
            npm install
        fi
        
        # 尝试运行构建脚本
        if npm run --silent 2>/dev/null | grep -q "build"; then
            npm run build
        else
            print_warning "No build script found in package.json"
        fi
        
    elif [ -f "Makefile" ]; then
        print_info "Detected Makefile project"
        make build || make all || print_warning "Make build failed"
        
    elif [ -f "go.mod" ]; then
        print_info "Detected Go project"
        go build -o build/ ./...
        
    elif [ -f "Cargo.toml" ]; then
        print_info "Detected Rust project"
        cargo build --release
        
    elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        print_info "Detected Python project"
        python -m pip install build
        python -m build
        
    else
        print_warning "Unknown project type. Skipping build step."
        print_info "Make sure your files are ready for packaging."
    fi
    
    print_info "Build completed."
}

# 创建压缩包
create_archive() {
    print_step "Creating archive..."
    
    # 删除旧的压缩包
    [ -f "$ARCHIVE_PATH" ] && rm -f "$ARCHIVE_PATH"
    
    # 确定要打包的内容
    local files_to_archive=()
    
    # 检查常见的构建输出目录
    for dir in "dist" "build" "target/release" "out"; do
        if [ -d "$dir" ]; then
            files_to_archive+=("$dir")
            print_info "Adding directory: $dir"
        fi
    done
    
    # 如果没有找到构建目录，询问用户
    if [ ${#files_to_archive[@]} -eq 0 ]; then
        print_warning "No standard build directories found."
        echo "Available files and directories:"
        ls -la
        echo ""
        read -p "Enter files/directories to archive (space-separated): " user_files
        IFS=' ' read -ra files_to_archive <<< "$user_files"
    fi
    
    # 创建压缩包
    if [ ${#files_to_archive[@]} -gt 0 ]; then
        zip -r "$ARCHIVE_PATH" "${files_to_archive[@]}"
        
        if [ -f "$ARCHIVE_PATH" ]; then
            ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
            print_info "Archive created: $ARCHIVE_PATH ($ARCHIVE_SIZE)"
        else
            print_error "Failed to create archive"
            exit 1
        fi
    else
        print_error "No files specified for archiving"
        exit 1
    fi
}

# 创建git tag (如果不存在)
create_git_tag() {
    print_step "Checking git tag..."
    
    if git rev-parse "$VERSION" >/dev/null 2>&1; then
        print_info "Tag $VERSION already exists"
    else
        print_info "Creating git tag: $VERSION"
        git tag -a "$VERSION" -m "Release $VERSION"
        
        read -p "Push tag to remote? [Y/n]: " push_tag
        if [[ ! "$push_tag" =~ ^[Nn]$ ]]; then
            git push origin "$VERSION"
            print_info "Tag pushed to remote"
        fi
    fi
}

# 生成release notes
generate_release_notes() {
    local notes="## Release $VERSION

### 📦 What's Included
- Built artifacts ready for deployment
- Source code snapshot

### 🔄 Changes"

    # 尝试从git log生成changelog
    if [ -n "$(git tag --list)" ]; then
        local last_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
        if [ -n "$last_tag" ]; then
            notes="$notes
$(git log --pretty=format:'- %s' $last_tag..HEAD)"
        fi
    fi
    
    notes="$notes

### 📅 Release Information
- **Version:** $VERSION
- **Date:** $(date '+%Y-%m-%d %H:%M:%S')
- **Archive:** $ARCHIVE_NAME
- **Size:** $(du -h "$ARCHIVE_PATH" | cut -f1)

---
*This release was created automatically using the build-and-release script.*"

    echo "$notes"
}

# 创建GitHub Release
create_release() {
    print_step "Creating GitHub Release..."
    
    local release_notes=$(generate_release_notes)
    
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
        --notes "$release_notes" \
        --latest; then
        
        print_info "✅ Release created successfully!"
        print_info "🔗 View at: https://github.com/$REPO/releases/tag/$VERSION"
    else
        print_error "❌ Failed to create release"
        exit 1
    fi
}

# 确认发布
confirm_release() {
    print_step "Release confirmation"
    echo "Repository: $REPO"
    echo "Version: $VERSION"
    echo "Archive: $ARCHIVE_PATH"
    
    if [ -f "$ARCHIVE_PATH" ]; then
        echo "Archive size: $(du -h "$ARCHIVE_PATH" | cut -f1)"
    fi
    
    echo ""
    read -p "Do you want to proceed with the release? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Release cancelled."
        exit 0
    fi
}

# 主函数
main() {
    echo "🏗️  Build and Release Automation"
    echo "================================"
    echo ""
    
    # 确保在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "This is not a git repository"
        exit 1
    fi
    
    check_requirements
    get_version
    
    # 询问是否需要构建
    read -p "Do you want to build the project before creating the release? [Y/n]: " build_choice
    if [[ ! "$build_choice" =~ ^[Nn]$ ]]; then
        build_project
    fi
    
    create_archive
    create_git_tag
    confirm_release
    create_release
    
    echo ""
    print_info "🎉 Build and release process completed successfully!"
}

# 执行主函数
main "$@"
