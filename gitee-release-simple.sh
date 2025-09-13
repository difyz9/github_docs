#!/bin/bash

# 简化版Gitee Release发布脚本
# 适合快速发布使用

set -e

# 基本配置（请修改这些值）
GITEE_TOKEN="${GITEE_TOKEN:-}"         # 从环境变量获取
REPO_OWNER="${REPO_OWNER:-username}"   # 仓库所有者
REPO_NAME="${REPO_NAME:-repository}"   # 仓库名称
ARCHIVE_PATH="${ARCHIVE_PATH:-./dist.zip}"  # 打包文件路径

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 检查配置
check_config() {
    if [ -z "$GITEE_TOKEN" ]; then
        error "请设置GITEE_TOKEN环境变量"
        echo "获取方法: https://gitee.com/profile/personal_access_tokens"
        exit 1
    fi
    
    if [ "$REPO_OWNER" = "username" ] || [ "$REPO_NAME" = "repository" ]; then
        error "请在脚本中设置正确的REPO_OWNER和REPO_NAME"
        exit 1
    fi
    
    if [ ! -f "$ARCHIVE_PATH" ]; then
        error "文件不存在: $ARCHIVE_PATH"
        exit 1
    fi
    
    info "配置检查通过"
}

# 获取版本号
get_version() {
    read -p "请输入版本号 (如: v1.0.0): " VERSION
    if [ -z "$VERSION" ]; then
        error "版本号不能为空"
        exit 1
    fi
    
    # 确保以v开头
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    info "版本号: $VERSION"
}

# 创建Release
create_release() {
    info "创建Release..."
    
    local release_data="{
        \"tag_name\": \"$VERSION\",
        \"name\": \"Release $VERSION\",
        \"body\": \"## Release $VERSION\\n\\n### 下载\\n请从附件下载最新版本。\\n\\n发布时间: $(date '+%Y-%m-%d %H:%M:%S')\",
        \"target_commitish\": \"master\",
        \"prerelease\": false
    }"
    
    local response=$(curl -s -w "\\n%{http_code}" -X POST \
        -H "Authorization: token $GITEE_TOKEN" \
        -H "Content-Type: application/json" \
        "https://gitee.com/api/v5/repos/$REPO_OWNER/$REPO_NAME/releases" \
        -d "$release_data")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" != "201" ]; then
        error "创建Release失败 (HTTP $http_code)"
        echo "$body"
        exit 1
    fi
    
    # 获取Release ID（简单解析）
    RELEASE_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ -z "$RELEASE_ID" ]; then
        error "无法获取Release ID"
        exit 1
    fi
    
    info "Release创建成功 (ID: $RELEASE_ID)"
}

# 上传文件
upload_file() {
    info "上传文件: $(basename "$ARCHIVE_PATH")"
    
    local upload_response=$(curl -s -w "\\n%{http_code}" -X POST \
        -H "Authorization: token $GITEE_TOKEN" \
        -F "file=@$ARCHIVE_PATH" \
        "https://gitee.com/api/v5/repos/$REPO_OWNER/$REPO_NAME/releases/$RELEASE_ID/attach_files")
    
    local upload_code=$(echo "$upload_response" | tail -n1)
    
    if [ "$upload_code" = "201" ]; then
        info "文件上传成功!"
        info "查看Release: https://gitee.com/$REPO_OWNER/$REPO_NAME/releases/tag/$VERSION"
    else
        error "文件上传失败 (HTTP $upload_code)"
        echo "$(echo "$upload_response" | head -n -1)"
        exit 1
    fi
}

# 主流程
main() {
    echo "🚀 Gitee Release 快速发布"
    echo "========================"
    echo ""
    
    check_config
    get_version
    create_release
    upload_file
    
    echo ""
    info "✅ 发布完成!"
}

main "$@"
