# 跨仓库发布快速设置指南

## 🚀 快速开始

### 1. 创建目标仓库
首先在GitHub上创建一个用于存放发布文件的仓库（仓库B）。

### 2. 获取GitHub Token
1. 访问 [GitHub Settings > Tokens](https://github.com/settings/tokens)
2. 点击 "Generate new token (classic)"
3. 选择权限：
   - ✅ `repo` (完整仓库权限)
   - ✅ `write:packages` (可选，用于包管理)
4. 复制生成的token

### 3. 配置源仓库（仓库A）
在源仓库的Settings > Secrets and variables > Actions中添加：

```
RELEASE_TOKEN = 你的GitHub token
TARGET_REPO = 目标仓库名称 (例如: username/releases)
```

### 4. 添加工作流文件
复制以下文件到源仓库的 `.github/workflows/` 目录：

**基础版本**：
```bash
cp cross-repo-release.yml 你的源仓库/.github/workflows/
```

**高级版本**：
```bash
cp advanced-cross-repo-release.yml 你的源仓库/.github/workflows/
```

### 5. 触发发布
有两种方式触发发布：

**方式1：创建tag**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**方式2：手动触发**
1. 在源仓库的Actions页面
2. 选择工作流
3. 点击"Run workflow"
4. 填写参数并运行

## 📋 配置检查清单

在使用前，请确保：

- [ ] 已创建目标仓库（仓库B）
- [ ] 已获取GitHub Personal Access Token
- [ ] 已在源仓库配置Secrets
- [ ] 已添加工作流文件
- [ ] 源仓库有构建脚本或产物
- [ ] Token有目标仓库的写权限

## 🛠️ 自定义配置

### 修改构建步骤
根据项目类型修改工作流中的构建部分：

**Node.js项目**：
```yaml
- name: Build project
  run: npm run build
```

**Python项目**：
```yaml
- name: Build project
  run: python -m build
```

**Go项目**：
```yaml
- name: Build project
  run: go build -o build/ ./...
```

### 修改打包内容
在工作流的"Create release package"步骤中修改：

```bash
# 复制构建产物
if [ -d "your-build-dir" ]; then
  cp -r your-build-dir/* release-package/
fi
```

## 🔧 测试方法

使用提供的演示脚本测试流程：

```bash
# 设置环境变量
export GITHUB_TOKEN=your_token_here

# 运行演示
./cross-repo-demo.sh --version v1.0.0 --target username/test-releases
```

## 📚 文件说明

| 文件 | 用途 |
|------|------|
| `cross-repo-release.yml` | 基础GitHub Actions工作流 |
| `advanced-cross-repo-release.yml` | 高级工作流，支持多项目类型 |
| `cross-repo-demo.sh` | 测试演示脚本 |
| `.env.cross-repo` | 配置文件模板 |
| `SETUP-GUIDE.md` | 本设置指南 |

## ❓ 常见问题

### Q: 工作流运行失败，提示"TARGET_REPO not configured"
A: 检查是否在源仓库的Secrets中正确配置了`TARGET_REPO`。

### Q: 提示权限不足
A: 确保GitHub Token有目标仓库的写权限，或者Token过期需要更新。

### Q: 构建失败
A: 检查构建命令和依赖是否正确配置，查看工作流日志了解具体错误。

### Q: 版本冲突
A: 确保版本号唯一，或在创建前删除已存在的同名release。

### Q: 目标仓库找不到
A: 检查仓库名称格式是否正确（owner/repo），仓库是否存在且有访问权限。

## 🔗 相关资源

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [GitHub CLI文档](https://cli.github.com/manual/)
- [Personal Access Token设置](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

## 📞 获取帮助

如果遇到问题：
1. 检查GitHub Actions工作流日志
2. 验证Secrets配置是否正确
3. 确认Token权限和有效性
4. 查看目标仓库是否存在且可访问
