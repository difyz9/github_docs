#!/bin/bash

# Gitee Release 发布脚本
# 使用方法: ./gitee-release.sh
# 作者: GitHub Copilot
# 版本: 1.0.0

set -e

# 配置变量 - 请根据您的项目修改这些值
GITEE_TOKEN="${GITEE_TOKEN}"      # 从环境变量读取，或在此处设置
REPO_OWNER="your_username"        # 替换为您的Gitee用户名或组织名
REPO_NAME="your_repository"       # 替换为您的仓库名
ARCHIVE_PATH="./dist.zip"         # 替换为您的压缩包路径
DEFAULT_VERSION="v1.0.0"          # 默认版本号
TARGET_BRANCH="master"            # 目标分支，默认为master

# Gitee API地址
GITEE_API_BASE="https://gitee.com/api/v5"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

print_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
🚀 Gitee Release 发布脚本

用法: $0 [选项]

选项:
  -t, --token TOKEN     Gitee访问令牌
  -o, --owner OWNER     仓库所有者用户名
  -r, --repo REPO       仓库名称
  -f, --file FILE       要上传的文件路径
  -v, --version VER     版本号 (如: v1.0.0)
  -b, --branch BRANCH   目标分支 (默认: master)
  -h, --help           显示此帮助信息

环境变量:
  GITEE_TOKEN          Gitee访问令牌
  
示例:
  $0 -t your_token -o username -r repo -f ./app.zip -v v1.0.0
  
  # 使用环境变量
  export GITEE_TOKEN=your_token
  $0 -o username -r repo -f ./app.zip

获取Gitee Token:
  1. 登录Gitee
  2. 进入 设置 → 私人令牌
  3. 生成新令牌，选择 'projects' 权限
  4. 复制生成的令牌

EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                GITEE_TOKEN="$2"
                shift 2
                ;;
            -o|--owner)
                REPO_OWNER="$2"
                shift 2
                ;;
            -r|--repo)
                REPO_NAME="$2"
                shift 2
                ;;
            -f|--file)
                ARCHIVE_PATH="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -b|--branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
}

# 检查必要工具和参数
check_requirements() {
    print_step "检查运行环境..."
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    # 检查jq（可选）
    if command -v jq &> /dev/null; then
        HAS_JQ=true
        print_info "✓ jq 已安装，将使用增强的JSON处理"
    else
        HAS_JQ=false
        print_warning "jq 未安装，建议安装以获得更好的体验: brew install jq"
    fi
    
    # 检查必要参数
    if [ -z "$GITEE_TOKEN" ]; then
        print_error "Gitee Token 未设置"
        echo "请使用 -t 参数或设置 GITEE_TOKEN 环境变量"
        echo "获取Token: https://gitee.com/profile/personal_access_tokens"
        exit 1
    fi
    
    if [ "$REPO_OWNER" = "your_username" ] || [ -z "$REPO_OWNER" ]; then
        print_error "请设置正确的仓库所有者 (-o 参数)"
        exit 1
    fi
    
    if [ "$REPO_NAME" = "your_repository" ] || [ -z "$REPO_NAME" ]; then
        print_error "请设置正确的仓库名称 (-r 参数)"
        exit 1
    fi
    
    print_success "环境检查完成"
}

# 验证Gitee Token
validate_token() {
    print_step "验证Gitee Token..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITEE_TOKEN" \
        "$GITEE_API_BASE/user")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" != "200" ]; then
        print_error "Token验证失败 (HTTP $http_code)"
        if [ "$HAS_JQ" = true ]; then
            local error_msg=$(echo "$body" | jq -r '.message // "未知错误"')
            print_error "错误信息: $error_msg"
        fi
        exit 1
    fi
    
    if [ "$HAS_JQ" = true ]; then
        local username=$(echo "$body" | jq -r '.login // "未知用户"')
        print_success "Token验证成功，当前用户: $username"
    else
        print_success "Token验证成功"
    fi
}

# 获取版本号
get_version() {
    if [ -n "$VERSION" ]; then
        print_info "使用指定版本: $VERSION"
        return
    fi
    
    print_step "获取版本号..."
    
    # 尝试从git tag获取最新版本
    if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        if [ -n "$latest_tag" ]; then
            print_info "检测到最新Git标签: $latest_tag"
        fi
    fi
    
    # 获取Gitee上的最新版本
    local releases_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITEE_TOKEN" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases?page=1&per_page=1")
    
    local http_code=$(echo "$releases_response" | tail -n1)
    local body=$(echo "$releases_response" | head -n -1)
    
    if [ "$http_code" = "200" ] && [ "$HAS_JQ" = true ]; then
        local latest_release=$(echo "$body" | jq -r '.[0].tag_name // empty')
        if [ -n "$latest_release" ]; then
            print_info "Gitee上的最新版本: $latest_release"
        fi
    fi
    
    read -p "请输入新版本号 (默认: $DEFAULT_VERSION): " VERSION
    
    if [ -z "$VERSION" ]; then
        VERSION="$DEFAULT_VERSION"
    fi
    
    # 确保版本号以v开头
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    print_success "将使用版本: $VERSION"
}

# 检查压缩包
check_archive() {
    print_step "检查打包文件..."
    
    if [ ! -f "$ARCHIVE_PATH" ]; then
        print_error "文件不存在: $ARCHIVE_PATH"
        print_info "请确保文件路径正确，或使用 -f 参数指定正确路径"
        exit 1
    fi
    
    local file_size=$(du -h "$ARCHIVE_PATH" | cut -f1)
    local file_name=$(basename "$ARCHIVE_PATH")
    
    print_success "文件检查完成: $file_name ($file_size)"
}

# 检查版本是否已存在
check_version_exists() {
    print_step "检查版本是否已存在..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITEE_TOKEN" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$VERSION")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_warning "版本 $VERSION 已存在"
        read -p "是否要删除并重新创建? [y/N]: " recreate
        
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            delete_existing_release
        else
            print_info "取消发布"
            exit 0
        fi
    elif [ "$http_code" = "404" ]; then
        print_success "版本检查完成，可以创建新版本"
    else
        print_warning "无法检查版本状态 (HTTP $http_code)，继续执行..."
    fi
}

# 删除已存在的release
delete_existing_release() {
    print_step "删除已存在的版本..."
    
    # 首先获取release ID
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITEE_TOKEN" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$VERSION")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" != "200" ]; then
        print_error "获取现有版本信息失败"
        return 1
    fi
    
    local release_id
    if [ "$HAS_JQ" = true ]; then
        release_id=$(echo "$body" | jq -r '.id')
    else
        release_id=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    fi
    
    if [ -z "$release_id" ] || [ "$release_id" = "null" ]; then
        print_error "无法获取release ID"
        return 1
    fi
    
    # 删除release
    local delete_response=$(curl -s -w "\n%{http_code}" -X DELETE \
        -H "Authorization: token $GITEE_TOKEN" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases/$release_id")
    
    local delete_code=$(echo "$delete_response" | tail -n1)
    
    if [ "$delete_code" = "204" ]; then
        print_success "已删除现有版本"
    else
        print_error "删除版本失败 (HTTP $delete_code)"
        return 1
    fi
}

# 创建release notes
create_release_notes() {
    local release_date=$(date '+%Y-%m-%d %H:%M:%S')
    local file_name=$(basename "$ARCHIVE_PATH")
    
    RELEASE_NOTES="## 🚀 Release $VERSION

### 📦 下载
请从下方的附件中下载最新版本。

### 📋 本次更新
- 请在此处添加具体的更新内容
- 新增功能或修复的问题
- 其他重要变更

### 📅 发布信息
- **发布时间**: $release_date
- **发布文件**: $file_name  
- **目标分支**: $TARGET_BRANCH

### 🔗 相关链接
- [仓库主页](https://gitee.com/$REPO_OWNER/$REPO_NAME)
- [问题反馈](https://gitee.com/$REPO_OWNER/$REPO_NAME/issues)

---
*此版本通过自动化脚本发布*"
}

# 确认发布信息
confirm_release() {
    print_step "发布确认"
    echo ""
    echo "📋 发布信息摘要:"
    echo "   仓库: $REPO_OWNER/$REPO_NAME"
    echo "   版本: $VERSION"
    echo "   文件: $ARCHIVE_PATH"
    echo "   分支: $TARGET_BRANCH"
    echo ""
    
    read -p "确认要创建此版本发布吗? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消发布"
        exit 0
    fi
}

# 创建Gitee Release
create_gitee_release() {
    print_step "创建Gitee Release..."
    
    create_release_notes
    
    # 构建请求数据
    local release_data
    if [ "$HAS_JQ" = true ]; then
        release_data=$(jq -n \
            --arg tag "$VERSION" \
            --arg name "Release $VERSION" \
            --arg body "$RELEASE_NOTES" \
            --arg target "$TARGET_BRANCH" \
            '{
                tag_name: $tag,
                name: $name,
                body: $body,
                target_commitish: $target,
                prerelease: false
            }')
    else
        # 不使用jq的备用方法
        release_data=$(cat <<EOF
{
  "tag_name": "$VERSION",
  "name": "Release $VERSION",
  "body": $(echo "$RELEASE_NOTES" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/^/"/' | sed 's/$/"/' ),
  "target_commitish": "$TARGET_BRANCH",
  "prerelease": false
}
EOF
)
    fi
    
    print_debug "正在发送API请求..."
    
    # 发送创建release的请求
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $GITEE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases" \
        -d "$release_data")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" != "201" ]; then
        print_error "创建Release失败 (HTTP $http_code)"
        if [ "$HAS_JQ" = true ]; then
            local error_msg=$(echo "$body" | jq -r '.message // "未知错误"')
            print_error "错误信息: $error_msg"
        else
            print_error "响应内容: $body"
        fi
        exit 1
    fi
    
    print_success "Release创建成功!"
    
    # 解析响应获取release信息
    if [ "$HAS_JQ" = true ]; then
        RELEASE_ID=$(echo "$body" | jq -r '.id')
        RELEASE_URL=$(echo "$body" | jq -r '.html_url')
    else
        RELEASE_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        RELEASE_URL=$(echo "$body" | grep -o '"html_url":"[^"]*' | cut -d'"' -f4)
    fi
    
    print_info "Release ID: $RELEASE_ID"
    
    # 上传附件
    upload_attachment
    
    print_success "🎉 发布完成!"
    print_info "🔗 查看发布: $RELEASE_URL"
}

# 上传附件到Release
upload_attachment() {
    print_step "上传附件..."
    
    local filename=$(basename "$ARCHIVE_PATH")
    
    print_info "正在上传: $filename"
    
    # 上传文件到Gitee Release
    local upload_response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $GITEE_TOKEN" \
        -F "file=@$ARCHIVE_PATH" \
        "$GITEE_API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases/$RELEASE_ID/attach_files")
    
    local upload_code=$(echo "$upload_response" | tail -n1)
    local upload_body=$(echo "$upload_response" | head -n -1)
    
    if [ "$upload_code" = "201" ]; then
        print_success "✅ 附件上传成功!"
        
        if [ "$HAS_JQ" = true ]; then
            local download_url=$(echo "$upload_body" | jq -r '.browser_download_url // .download_url // empty')
            if [ -n "$download_url" ]; then
                print_info "📎 下载链接: $download_url"
            fi
        fi
    else
        print_error "❌ 附件上传失败 (HTTP $upload_code)"
        if [ "$HAS_JQ" = true ]; then
            local error_msg=$(echo "$upload_body" | jq -r '.message // "未知错误"')
            print_error "错误信息: $error_msg"
        else
            print_error "响应内容: $upload_body"
        fi
        return 1
    fi
}

# 主函数
main() {
    echo "🚀 Gitee Release 发布工具"
    echo "========================="
    echo ""
    
    parse_arguments "$@"
    check_requirements
    validate_token
    get_version
    check_archive
    check_version_exists
    confirm_release
    create_gitee_release
    
    echo ""
    print_success "🎉 所有操作已完成!"
    echo ""
    echo "📚 使用小贴士:"
    echo "  • 可以使用 -h 参数查看完整帮助"
    echo "  • 建议将Token保存为环境变量"
    echo "  • 可以创建配置文件简化参数输入"
    echo ""
}

# 错误处理
trap 'print_error "脚本执行出错，请检查上述输出"; exit 1' ERR

# 执行主函数
main "$@"
