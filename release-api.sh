#!/bin/bash

# GitHub Release 发布脚本 (使用GitHub API)
# 使用方法: ./release-api.sh

set -e

# 配置变量 - 请根据您的项目修改这些值
GITHUB_TOKEN="${GITHUB_TOKEN}"    # 从环境变量读取，或在此处设置
REPO_OWNER="username"             # 替换为仓库所有者
REPO_NAME="repository"            # 替换为仓库名
ARCHIVE_PATH="./dist.zip"         # 替换为压缩包路径
DEFAULT_VERSION="v1.0.0"          # 默认版本号

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查必要参数
check_requirements() {
    print_step "Checking requirements..."
    
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GitHub token is required."
        echo "Please set GITHUB_TOKEN environment variable or edit this script."
        echo "Get your token from: https://github.com/settings/tokens"
        exit 1
    fi
    
    if [ "$REPO_OWNER" = "username" ] || [ "$REPO_NAME" = "repository" ]; then
        print_error "Please update REPO_OWNER and REPO_NAME in this script."
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON parsing will be limited."
        echo "Consider installing jq with: brew install jq"
    fi
    
    print_info "Requirements check completed."
}

# 获取版本号
get_version() {
    print_step "Getting version..."
    
    read -p "Enter version (press Enter for $DEFAULT_VERSION): " VERSION
    
    if [ -z "$VERSION" ]; then
        VERSION="$DEFAULT_VERSION"
    fi
    
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    print_info "Using version: $VERSION"
}

# 检查压缩包
check_archive() {
    print_step "Checking archive..."
    
    if [ ! -f "$ARCHIVE_PATH" ]; then
        print_error "Archive not found: $ARCHIVE_PATH"
        exit 1
    fi
    
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    print_info "Archive found: $ARCHIVE_PATH ($ARCHIVE_SIZE)"
}

# 创建release
create_release() {
    print_step "Creating GitHub Release via API..."
    
    RELEASE_NAME="Release $VERSION"
    RELEASE_BODY="## Release $VERSION

### 📦 Downloads
Download the archive from the assets below.

### 🔄 Changes
- Add your changes here

### 📅 Release Date
$(date '+%Y-%m-%d %H:%M:%S')

---
*This release was created using GitHub API.*"

    # 创建release的JSON数据
    RELEASE_DATA=$(cat <<EOF
{
  "tag_name": "$VERSION",
  "name": "$RELEASE_NAME",
  "body": $(echo "$RELEASE_BODY" | jq -Rs .),
  "draft": false,
  "prerelease": false
}
EOF
)

    print_info "Creating release..."
    
    # 发送API请求创建release
    RELEASE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
        -d "$RELEASE_DATA")
    
    # 分离响应内容和状态码
    HTTP_CODE=$(echo "$RELEASE_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RELEASE_RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" != "201" ]; then
        print_error "Failed to create release. HTTP Code: $HTTP_CODE"
        echo "Response: $RESPONSE_BODY"
        exit 1
    fi
    
    print_info "Release created successfully!"
    
    # 解析响应获取上传URL和Release ID
    if command -v jq &> /dev/null; then
        UPLOAD_URL=$(echo "$RESPONSE_BODY" | jq -r '.upload_url' | sed 's/{?name,label}//')
        RELEASE_ID=$(echo "$RESPONSE_BODY" | jq -r '.id')
        RELEASE_HTML_URL=$(echo "$RESPONSE_BODY" | jq -r '.html_url')
    else
        # 不使用jq的备用方法
        UPLOAD_URL=$(echo "$RESPONSE_BODY" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')
        RELEASE_ID=$(echo "$RESPONSE_BODY" | grep -o '"id": [0-9]*' | head -1 | cut -d' ' -f2)
        RELEASE_HTML_URL=$(echo "$RESPONSE_BODY" | grep -o '"html_url": "[^"]*' | cut -d'"' -f4)
    fi
    
    if [ -z "$UPLOAD_URL" ]; then
        print_error "Failed to get upload URL from response"
        exit 1
    fi
    
    print_info "Release ID: $RELEASE_ID"
    
    # 上传文件
    upload_asset "$UPLOAD_URL"
    
    print_info "🔗 View release at: $RELEASE_HTML_URL"
}

# 上传资源文件
upload_asset() {
    local upload_url="$1"
    
    print_step "Uploading asset..."
    
    FILENAME=$(basename "$ARCHIVE_PATH")
    
    # 根据文件扩展名确定Content-Type
    case "$FILENAME" in
        *.zip)
            CONTENT_TYPE="application/zip"
            ;;
        *.tar.gz|*.tgz)
            CONTENT_TYPE="application/gzip"
            ;;
        *.tar)
            CONTENT_TYPE="application/x-tar"
            ;;
        *)
            CONTENT_TYPE="application/octet-stream"
            ;;
    esac
    
    print_info "Uploading $FILENAME ($CONTENT_TYPE)..."
    
    UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: $CONTENT_TYPE" \
        --data-binary @"$ARCHIVE_PATH" \
        "$upload_url?name=$FILENAME")
    
    HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "201" ]; then
        print_info "✅ Asset uploaded successfully!"
    else
        print_error "❌ Failed to upload asset. HTTP Code: $HTTP_CODE"
        echo "Response: $(echo "$UPLOAD_RESPONSE" | head -n -1)"
        exit 1
    fi
}

# 确认发布
confirm_release() {
    print_step "Release confirmation"
    echo "Repository: $REPO_OWNER/$REPO_NAME"
    echo "Version: $VERSION"
    echo "Archive: $ARCHIVE_PATH"
    echo ""
    
    read -p "Do you want to create this release? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Release cancelled."
        exit 0
    fi
}

# 主函数
main() {
    echo "🚀 GitHub Release Publisher (API Version)"
    echo "=========================================="
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
