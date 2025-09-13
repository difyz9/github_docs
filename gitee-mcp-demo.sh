#!/bin/bash

# Gitee Release API 演示脚本
# 此脚本演示如何使用 MCP Gitee 工具创建 Release

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 演示使用MCP Gitee工具创建Release
demo_mcp_release() {
    step "演示使用MCP Gitee工具创建Release"
    
    echo ""
    echo "此脚本演示如何使用 MCP (Model Context Protocol) Gitee 工具"
    echo "来自动化创建Gitee Release并上传文件。"
    echo ""
    
    # 这里是一个演示函数，展示如何使用MCP工具
    # 实际使用时，这些参数会被传递给MCP工具
    
    local owner="your_username"
    local repo="your_repository" 
    local tag_name="v1.0.0"
    local name="Release v1.0.0"
    local body="## Release v1.0.0

### 📦 新功能
- 添加了新的功能A
- 改进了性能
- 修复了已知问题

### 🐛 问题修复
- 修复了登录问题
- 解决了数据同步错误

### 📅 发布信息
- 发布时间: $(date '+%Y-%m-%d %H:%M:%S')
- 版本类型: 正式版本

### 📎 下载
请从下方附件下载对应平台的版本。"
    
    local target_commitish="master"
    
    info "准备创建Release，参数如下："
    echo "  仓库所有者: $owner"
    echo "  仓库名称: $repo"
    echo "  版本标签: $tag_name"
    echo "  版本名称: $name"
    echo "  目标分支: $target_commitish"
    echo ""
    
    # 这里模拟MCP工具调用
    step "调用 MCP Gitee Create Release 工具..."
    
    info "工具调用参数:"
    cat << EOF
{
  "owner": "$owner",
  "repo": "$repo", 
  "tag_name": "$tag_name",
  "name": "$name",
  "body": "$body",
  "target_commitish": "$target_commitish",
  "prerelease": false
}
EOF
    
    echo ""
    info "✅ 演示完成"
    echo ""
    echo "实际使用时，您需要:"
    echo "1. 配置真实的仓库信息"
    echo "2. 准备要上传的文件"
    echo "3. 设置Gitee访问令牌"
    echo "4. 调用相应的MCP工具函数"
}

# 显示使用MCP工具的步骤
show_mcp_usage() {
    step "MCP Gitee 工具使用指南"
    
    echo ""
    echo "📋 使用步骤:"
    echo ""
    echo "1️⃣ 激活Gitee工具"
    echo "   首先需要激活相关的Gitee工具集"
    echo ""
    echo "2️⃣ 准备Release信息"
    echo "   - 版本号 (tag_name)"
    echo "   - 版本名称 (name)"
    echo "   - 发布说明 (body)"
    echo "   - 目标分支 (target_commitish)"
    echo ""
    echo "3️⃣ 创建Release"
    echo "   调用 mcp_gitee_create_release 工具"
    echo ""
    echo "4️⃣ 验证结果"
    echo "   检查Release是否创建成功"
    echo ""
    
    echo "🔧 可用的MCP Gitee工具:"
    echo "  • mcp_gitee_create_release - 创建新的Release"
    echo "  • mcp_gitee_list_releases - 列出所有Release"
    echo ""
    
    echo "📖 工具文档:"
    echo "  Create Release: 创建新的Gitee Release"
    echo "  List Releases: 获取仓库的所有Release列表"
    echo ""
}

# 显示配置示例
show_config_example() {
    step "配置示例"
    
    echo ""
    echo "🔧 环境变量配置:"
    cat << 'EOF'
# 设置Gitee访问令牌
export GITEE_TOKEN="your_gitee_access_token"

# 设置仓库信息
export REPO_OWNER="your_username"
export REPO_NAME="your_repository"
EOF
    
    echo ""
    echo "📄 .env 文件示例:"
    cat << 'EOF'
GITEE_TOKEN=your_gitee_access_token_here
REPO_OWNER=your_username_or_organization  
REPO_NAME=your_repository_name
ARCHIVE_PATH=./dist/app-v1.0.0.zip
DEFAULT_VERSION=v1.0.0
TARGET_BRANCH=master
EOF
    
    echo ""
    echo "🚀 使用示例:"
    cat << 'EOF'
# 加载配置
source .env

# 使用MCP工具创建Release
# (这需要在支持MCP的环境中执行)
EOF
}

# 主函数
main() {
    echo "🚀 Gitee Release MCP 工具演示"
    echo "==============================="
    echo ""
    
    demo_mcp_release
    show_mcp_usage  
    show_config_example
    
    echo ""
    info "📚 更多信息:"
    echo "  • Gitee API文档: https://gitee.com/api/v5/swagger"
    echo "  • MCP协议文档: https://github.com/modelcontextprotocol/spec"
    echo "  • 示例脚本: gitee-release.sh, gitee-release-simple.sh"
    echo ""
}

# 执行主函数
main "$@"
