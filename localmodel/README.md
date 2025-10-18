# GPT-OSS 项目

一个基于 llama.cpp 的 GPT-OSS 模型运行环境。

## 🚀 快速开始

### 1. 环境准备
```bash
# 确保已编译 llama.cpp
cd llama.cpp && make -j

# 确保模型文件存在
ls models/gpt-oss-*.gguf
```

### 2. 运行模型
```bash
# 给脚本执行权限
chmod +x run_gpt_oss.sh

# 交互模式（推荐）
./run_gpt_oss.sh -i

# 命令行模式
./run_gpt_oss.sh "你的问题"

# 使用预设模式
./run_gpt_oss.sh -p coding "写一个Python函数"

# 快速测试
./run_gpt_oss.sh -t

# 查看帮助
./run_gpt_oss.sh -h
```

## 📖 使用说明

### 命令行选项
- `-h, --help` - 显示帮助信息
- `-i, --interactive` - 交互模式
- `-t, --test` - 快速测试模式
- `-s, --simple` - 简单模式（不使用 Harmony 格式）
- `-p, --preset <模式>` - 使用预设模式
- `-n, --tokens <数量>` - 设置最大 token 数量（默认：256）
- `--temp <温度>` - 设置温度参数（默认：0.7）
- `--model <路径>` - 指定模型文件路径
- `--config <路径>` - 指定配置文件路径
- `--show-config` - 显示当前配置
- `--list-presets` - 列出可用预设

### 使用示例
```bash
# 交互模式（支持实时对话）
./run_gpt_oss.sh -i

# 使用预设模式
./run_gpt_oss.sh -p coding "写一个排序算法"
./run_gpt_oss.sh -p creative "写一首关于春天的诗"

# 使用自定义参数
./run_gpt_oss.sh -n 512 --temp 0.8 "解释量子计算的基本原理"

# 简单模式（更快的响应）
./run_gpt_oss.sh -s "今天天气怎么样？"

# 查看配置和预设
./run_gpt_oss.sh --show-config
./run_gpt_oss.sh --list-presets
```

### 交互模式命令
在交互模式中，你可以使用以下命令：
- `help` - 显示帮助信息
- `config` - 显示当前配置
- `presets` - 列出可用预设
- `preset <模式>` - 切换预设模式
- `simple` - 切换到简单模式
- `harmony` - 切换到 Harmony 模式
- `tokens <数量>` - 设置 token 数量
- `temp <温度>` - 设置温度参数
- `quit` - 退出程序

## ⚙️ 配置说明

### 配置文件 (config.yaml)
项目使用 YAML 配置文件管理所有参数：

```yaml
# 模型配置
model_path: "models/gpt-oss-20b-Q4_0.gguf"

# 生成参数
max_tokens: 256
temperature: 0.7
top_p: 0.9
context_length: 4096

# 预设模式
presets:
  coding:
    system_prompt: "你是一个专业的编程助手..."
    temperature: 0.3
    max_tokens: 512
  creative:
    system_prompt: "你是一个富有创意的写作助手..."
    temperature: 0.9
    max_tokens: 400
```

### 模型配置
- **默认模型**: `models/gpt-oss-20b-Q4_0.gguf`
- **自动检测**: 如果默认模型不存在，会自动查找其他 `gpt-oss-*.gguf` 文件

### 参数配置
- **max_tokens**: 256（生成的最大 token 数）
- **temperature**: 0.7（控制随机性，0.1-1.0）
- **top_p**: 0.9（核采样参数）
- **context_length**: 4096（上下文长度）
- **预设模式**: 针对不同场景优化的参数组合

### Harmony 格式
项目支持 Harmony 格式的提示，包含：
- **system** - 系统消息
- **developer** - 开发者指令
- **user** - 用户输入
- **assistant** - 模型回复

## 📁 项目结构
```
GPT-OSS/
├── run_gpt_oss.sh          # 主运行脚本
├── llama.cpp/              # llama.cpp 源码和编译文件
│   └── build/bin/llama-cli # 编译后的可执行文件
├── models/                 # 模型文件目录
│   └── gpt-oss-*.gguf     # GPT-OSS 模型文件
└── README.md              # 项目说明
```

## 🔧 故障排除

### 常见问题
1. **模型文件不存在**
   - 确保 `models/` 目录下有 `gpt-oss-*.gguf` 文件
   - 检查文件路径是否正确

2. **llama-cli 不存在**
   - 确保已正确编译 llama.cpp：`cd llama.cpp && make -j`
   - 检查 `llama.cpp/build/bin/llama-cli` 是否存在

3. **权限问题**
   - 给脚本执行权限：`chmod +x run_gpt_oss.sh`

4. **生成结果不理想**
   - 尝试调整温度参数：`--temp 0.3`（更确定）或 `--temp 0.9`（更创造性）
   - 增加 token 数：`-n 512`
   - 使用简单模式：`-s`

### 直接使用 llama-cli
如果脚本有问题，可以直接使用 llama-cli：
```bash
./llama.cpp/build/bin/llama-cli \
    -m models/gpt-oss-20b-Q4_0.gguf \
    -p "你的问题" \
    -n 256 \
    --temp 0.7
```

## 📊 性能参考
- **Q4_0 模型**: 约 12GB 内存，中等质量
- **Q8_0 模型**: 约 20GB 内存，高质量
- **生成速度**: 取决于硬件配置，通常 1-10 tokens/秒

---

**提示**: 首次运行建议使用 `./run_gpt_oss.sh -t` 进行快速测试，确保环境配置正确。

## 📋 目录

- [系统要求](#系统要求)
- [安装步骤](#安装步骤)
- [模型下载](#模型下载)
- [使用方法](#使用方法)
- [文件说明](#文件说明)
- [故障排除](#故障排除)

## 🖥️ 系统要求

- **操作系统**: macOS 12.0 或更高版本
- **硬件**: Apple Silicon (M1/M2/M3/M4) 推荐，Intel Mac 也支持
- **内存**: 至少 16GB RAM (20B 模型需要)
- **存储**: 至少 20GB 可用空间
- **工具**: 
  - Xcode Command Line Tools
  - Git
  - Python 3.9+

## 🚀 安装步骤

### 1. 安装系统依赖

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 验证安装
git --version
python3 --version
```

### 2. 克隆项目

```bash
git clone <your-repo-url>
cd GPT-OSS
```

### 3. 编译 llama.cpp (支持 Metal 加速)

```bash
# 克隆 llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# 创建构建目录
mkdir build
cd build

# 配置 CMake (启用 Metal 支持)
cmake .. -DLLAMA_METAL=ON -DCMAKE_BUILD_TYPE=Release

# 编译 (使用所有 CPU 核心)
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# 返回项目根目录
cd ../..
```

### 4. 安装 Python 依赖

```bash
# 安装 llama-cpp-python (支持 Metal)
pip3 install --user --force-reinstall --no-cache-dir \
  --verbose llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/metal

# 验证安装
python3 -c "import llama_cpp; print('✅ llama-cpp-python 安装成功')"
```

## 📦 模型下载

将 GPT-OSS 模型文件 (`.gguf` 格式) 放入 `models/` 目录：

```bash
mkdir -p models
# 将你的 gpt-oss-*.gguf 文件复制到 models/ 目录
```

支持的模型格式：
- `gpt-oss-20b-Q4_0.gguf` (推荐，兼容性最好)
- `gpt-oss-20b-Q4_K_M.gguf` (常用格式)
- `gpt-oss-20b-mxfp4.gguf` (实验性格式)

## 🎯 使用方法

### 快速测试

```bash
# 快速测试模型是否正常工作
python3 quick_gpt_oss_test.py
```

### 交互式聊天

```bash
# 启动交互式聊天
python3 gpt_oss_runner.py
```

### 在代码中使用

```python
from gpt_oss_runner import GPTOSSRunner

# 初始化运行器
runner = GPTOSSRunner("./models/gpt-oss-20b-Q4_0.gguf")

# 生成回答
response = runner.chat("你好，请介绍一下你自己。")
print(response)
```

### 高级用法

```python
# 自定义参数
response = runner.generate(
    prompt="请解释人工智能",
    max_tokens=512,
    temperature=0.7,
    top_p=0.9
)

# 使用 Harmony 格式
harmony_prompt = runner.create_harmony_prompt(
    user_message="你的问题",
    system_message="自定义系统消息",
    instructions="特殊指令"
)
response = runner.generate(harmony_prompt)
```

## 📁 文件说明

```
GPT-OSS/
├── README.md                 # 本文档
├── gpt_oss_runner.py        # 主要的模型运行器
├── harmony_test.py          # Harmony 格式测试脚本
├── quick_gpt_oss_test.py    # 快速测试脚本
├── models/                  # 模型文件目录
│   └── gpt-oss-*.gguf      # GPT-OSS 模型文件
└── llama.cpp/              # 编译的 llama.cpp
    └── build/bin/llama-cli # 核心二进制文件
```

### 核心文件功能

- **`gpt_oss_runner.py`**: 主要的 Python 包装器，提供简单的 API 来使用 GPT-OSS 模型
- **`harmony_test.py`**: 测试 Harmony 响应格式的脚本
- **`quick_gpt_oss_test.py`**: 快速验证模型是否正常工作

## 🔧 故障排除

### 常见问题

#### 1. 模型加载失败 "ggml type 39 (NONE)"

**原因**: 模型格式与 llama.cpp 版本不兼容

**解决方案**:
```bash
# 更新 llama.cpp 到最新版本
cd llama.cpp
git pull
cd build
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
```

#### 2. Metal 加速未启用

**检查方法**:
```bash
# 运行时应该看到 "Metal" 相关信息
./llama.cpp/build/bin/llama-cli -m models/gpt-oss-*.gguf -p "test" -n 1
```

**解决方案**:
```bash
# 重新编译，确保 Metal 支持
cd llama.cpp/build
cmake .. -DLLAMA_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
```

#### 3. 内存不足

**症状**: 模型加载时崩溃或系统卡死

**解决方案**:
- 使用更小的量化模型 (Q4_0 而不是 F16)
- 关闭其他应用程序释放内存
- 考虑使用更小的模型

#### 4. 生成速度慢

**优化建议**:
- 确保使用 Metal 加速 (Apple Silicon)
- 减少 `max_tokens` 参数
- 使用 Q4_0 量化格式
- 确保模型文件在 SSD 上

### 性能基准

在 Apple M4 上的典型性能：
- **加载时间**: 10-30 秒
- **生成速度**: 15-25 tokens/秒
- **内存使用**: 12-16 GB

## 🔄 更新

### 更新 llama.cpp

```bash
cd llama.cpp
git pull
cd build
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
```

### 更新 Python 依赖

```bash
pip3 install --user --upgrade llama-cpp-python
```

## 📝 许可证

本项目遵循相关开源许可证。请查看各组件的许可证文件。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 支持

如果遇到问题，请：
1. 查看本文档的故障排除部分
2. 检查 llama.cpp 官方文档
3. 提交 Issue 描述具体问题

---

**最后更新**: 2025-01-27
**版本**: 1.0.0