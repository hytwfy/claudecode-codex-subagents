# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cross-platform setup assets: PowerShell, CMD, and shell installers plus `AGENT_SETUP.md`.
- A Claude Code marketplace manifest for standard marketplace installation.

### Changed
- Updated Chinese and English installation instructions for HTTPS marketplace URLs, platform-specific installers, automatic setup, and namespaced plugin commands.

## [2.0.0] - 2025-11-07

### Changed (Breaking)
- 🎉 **重构为标准 Claude Code Plugin 格式**
- 项目结构重组：
  - 添加 `.claude-plugin/plugin.json` 元数据文件
  - 移动命令文件到 `commands/` 目录
  - 支持通过 `/plugin install` 安装
- 安装方式更新：
  - 推荐使用 Plugin 安装方式
  - 保留手动安装方式作为备选
  - 更新所有 README 文档的安装说明

### Added
- Plugin 管理支持：
  - 通过 `/plugin install CoderMageFox/claudecode-codex-subagents` 安装
  - 通过 `/plugin enable/disable` 管理
  - 通过 `/plugin validate` 验证结构
- 标准化 Plugin 元数据（plugin.json）
  - 包含版本、作者、许可证等信息
  - 声明 MCP 服务器依赖
  - 定义所需权限
- 自动安装中英文双版本命令

## [1.0.0] - 2025-11-07

### Added
- Initial release of Codex Subagents plugin
- Parallel agent orchestration with max 3 agents per batch
- Chain processing for >3 agents with automatic batching
- Comprehensive logging system to `.codex-temp/[timestamp]/`
- Real-time progress tracking via TodoWrite integration
- Full i18n support (Chinese and English)
  - `codex-subagents.md` - Default Chinese version
  - `codex-subagents-en.md` - English version
- Complete documentation
  - README.md (Chinese with language switcher)
  - README-en.md (English)
  - README-zh.md (Chinese)
- Quality validation gates
  - Pre-merge checks
  - Compilation validation
  - Static analysis (lint, type-check)
  - Test execution
  - Code quality checks
- Multiple task decomposition strategies
  - File-based decomposition
  - Feature-based decomposition
  - Layer-based decomposition
- Intelligent merge strategies
  - Direct merge (no conflicts)
  - Sequential integration (with dependencies)
  - Conflict resolution (overlapping changes)
  - Incremental validation (high-risk scenarios)
- Detailed agent logging with timestamps and function names
- Batch execution progress reporting
- Error handling and retry mechanisms

### Documentation
- Installation guide with 3 methods (manual, git clone, curl)
- Usage examples and best practices
- Workflow documentation
- Troubleshooting guide
- Performance optimization tips
- Contributing guidelines (CONTRIBUTING.md)
- Code of Conduct (CODE_OF_CONDUCT.md)

### Infrastructure
- MIT License
- .gitignore for temporary files and logs
- GitHub badges (License, Stars, Issues, PRs Welcome)

[Unreleased]: https://github.com/CoderMageFox/claudecode-codex-subagents/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/CoderMageFox/claudecode-codex-subagents/releases/tag/v1.0.0
