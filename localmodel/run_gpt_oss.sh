#!/bin/bash

# 🤖 GPT-OSS 统一运行脚本
# 作者: GPT-OSS 项目
# 版本: 2.0 (支持 YAML 配置)

# ==================== 配置区域 ====================
CONFIG_FILE="config.yaml"
LLAMA_CLI="./llama.cpp/build/bin/llama-cli"

# 默认参数（如果配置文件不存在时使用）
DEFAULT_MODEL_PATH="models/gpt-oss-20b-Q4_0.gguf"
DEFAULT_TOKENS=256
DEFAULT_TEMP=0.7
DEFAULT_TOP_P=0.9
DEFAULT_CONTEXT=4096

# ==================== 函数定义 ====================

# 读取 YAML 配置文件的简单函数
read_config() {
    local key="$1"
    local default_value="$2"
    
    if [ -f "$CONFIG_FILE" ]; then
        # 使用 grep 和 sed 简单解析 YAML，只返回第一个匹配
        local value=$(grep "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
        if [ -n "$value" ]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        echo "$default_value"
    fi
}

# 读取多行配置（如系统提示词）
read_multiline_config() {
    local section="$1"
    local key="$2"
    local default_value="$3"
    
    if [ -f "$CONFIG_FILE" ]; then
        # 查找指定 section 下的 key
        awk -v section="$section" -v key="$key" '
        BEGIN { in_section=0; in_key=0; content="" }
        /^[a-zA-Z_][a-zA-Z0-9_]*:/ { 
            if ($0 ~ "^" section ":") in_section=1; else in_section=0; in_key=0 
        }
        in_section && /^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*:/ {
            if ($0 ~ "^[[:space:]]+" key ":") {
                in_key=1; 
                sub(/^[[:space:]]*[^:]*:[[:space:]]*\|?[[:space:]]*/, "");
                if (length($0) > 0) content=$0 "\n"
            } else {
                in_key=0
            }
        }
        in_key && /^[[:space:]]+/ && !/^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*:/ {
            sub(/^[[:space:]]+/, "");
            content=content $0 "\n"
        }
        END { 
            if (length(content) > 0) {
                gsub(/\n$/, "", content);
                print content
            } else {
                print "'"$default_value"'"
            }
        }' "$CONFIG_FILE"
    else
        echo "$default_value"
    fi
}

# 加载配置
load_config() {
    # 模型配置
    MODEL_PATH=$(read_config "default_path" "$DEFAULT_MODEL_PATH")
    FALLBACK_MODELS=""
    
    # 生成参数
    TOKENS=$(read_config "max_tokens" "$DEFAULT_TOKENS")
    TEMP=$(read_config "temperature" "$DEFAULT_TEMP")
    TOP_P=$(read_config "top_p" "$DEFAULT_TOP_P")
    CONTEXT=$(read_config "context_length" "$DEFAULT_CONTEXT")
    
    # 界面配置
    SHOW_DETAILS=$(read_config "show_details" "true")
    SHOW_PARAMS=$(read_config "show_params" "true")
    USE_HARMONY=$(read_config "use_harmony_format" "true")
    
    # 提示符
    USER_PROMPT=$(read_config "user_prompt" "👤 你: ")
    
    # 当前预设模式
    CURRENT_PRESET="default"
}

# 应用预设配置
apply_preset() {
    local preset="$1"
    
    if [ -f "$CONFIG_FILE" ]; then
        # 读取预设配置
        local preset_temp=$(awk -v preset="$preset" '
        BEGIN { in_presets=0; in_preset=0 }
        /^presets:/ { in_presets=1; next }
        in_presets && /^[a-zA-Z_]/ { in_presets=0 }
        in_presets && $0 ~ "^[[:space:]]+" preset ":" { in_preset=1; next }
        in_presets && in_preset && /^[[:space:]]+[a-zA-Z_]/ && !/^[[:space:]]+[[:space:]]/ { in_preset=0 }
        in_presets && in_preset && /^[[:space:]]+temperature:/ { 
            sub(/^[[:space:]]*temperature:[[:space:]]*/, ""); print $0; exit 
        }' "$CONFIG_FILE")
        
        local preset_tokens=$(awk -v preset="$preset" '
        BEGIN { in_presets=0; in_preset=0 }
        /^presets:/ { in_presets=1; next }
        in_presets && /^[a-zA-Z_]/ { in_presets=0 }
        in_presets && $0 ~ "^[[:space:]]+" preset ":" { in_preset=1; next }
        in_presets && in_preset && /^[[:space:]]+[a-zA-Z_]/ && !/^[[:space:]]+[[:space:]]/ { in_preset=0 }
        in_presets && in_preset && /^[[:space:]]+max_tokens:/ { 
            sub(/^[[:space:]]*max_tokens:[[:space:]]*/, ""); print $0; exit 
        }' "$CONFIG_FILE")
        
        # 应用预设参数
        if [ -n "$preset_temp" ]; then
            TEMP="$preset_temp"
        fi
        if [ -n "$preset_tokens" ]; then
            TOKENS="$preset_tokens"
        fi
        
        CURRENT_PRESET="$preset"
        
        if [ "$SHOW_DETAILS" = "true" ]; then
            echo "✓ 已切换到预设模式: $preset"
            if [ "$SHOW_PARAMS" = "true" ]; then
                echo "  参数: tokens=$TOKENS, temp=$TEMP"
            fi
        fi
    fi
}

# 获取系统提示词
get_system_prompt() {
    local prompt_key="$1"
    local default_prompt="You are ChatGPT, a large language model trained by OpenAI.
Knowledge cutoff: 2024-06
Current date: 2025-01-27

Reasoning: high

# Valid channels: analysis, commentary, final. Channel must be included for every message."
    
    read_multiline_config "system_prompts" "$prompt_key" "$default_prompt"
}

# 获取开发者指令
get_developer_instruction() {
    local instruction_key="$1"
    local default_instruction="请用中文回答问题，保持友好和有帮助的语气。"
    
    read_multiline_config "developer_instructions" "$instruction_key" "$default_instruction"
}

show_help() {
    echo "🤖 GPT-OSS 运行脚本 v2.0"
    echo "========================"
    echo ""
    echo "使用方法:"
    echo "  ./run_gpt_oss.sh [选项] [问题]"
    echo ""
    echo "基本选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -t, --test          运行快速测试"
    echo "  -s, --simple        简单模式 (不使用 Harmony 格式)"
    echo "  -i, --interactive   强制进入交互模式"
    echo ""
    echo "参数选项:"
    echo "  -n, --tokens NUM    设置最大 token 数"
    echo "  --temp NUM          设置温度参数"
    echo "  --model PATH        指定模型文件路径"
    echo ""
    echo "预设模式:"
    echo "  -p, --preset MODE   使用预设配置模式"
    echo "    可用模式: default, coding, creative, academic, concise"
    echo ""
    echo "配置选项:"
    echo "  --config PATH       指定配置文件路径 (默认: config.yaml)"
    echo "  --show-config       显示当前配置"
    echo "  --list-presets      列出所有可用预设"
    echo ""
    echo "基本示例:"
    echo "  ./run_gpt_oss.sh \"你好，请介绍一下你自己\""
    echo "  ./run_gpt_oss.sh -i                    # 交互模式"
    echo "  ./run_gpt_oss.sh -t                    # 快速测试"
    echo ""
    echo "预设模式示例:"
    echo "  ./run_gpt_oss.sh -p coding \"如何实现快速排序？\""
    echo "  ./run_gpt_oss.sh -p creative \"写一首关于春天的诗\""
    echo "  ./run_gpt_oss.sh -p academic \"解释量子力学的基本原理\""
    echo ""
    echo "自定义参数示例:"
    echo "  ./run_gpt_oss.sh -n 100 --temp 0.3 \"请简短回答\""
    echo "  ./run_gpt_oss.sh -s \"1+1等于几？\"      # 简单模式"
    echo ""
    echo "配置文件:"
    echo "  编辑 config.yaml 文件可以自定义系统提示词、参数和预设模式"
    echo ""
}

show_config() {
    echo "📋 当前配置"
    echo "==========="
    echo ""
    echo "模型配置:"
    echo "  模型路径: $MODEL_PATH"
    echo ""
    echo "生成参数:"
    echo "  最大 tokens: $TOKENS"
    echo "  温度: $TEMP"
    echo "  Top-p: $TOP_P"
    echo "  上下文长度: $CONTEXT"
    echo ""
    echo "当前模式:"
    echo "  预设: $CURRENT_PRESET"
    echo "  Harmony 格式: $USE_HARMONY"
    echo ""
    echo "配置文件: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        echo "  状态: ✓ 存在"
    else
        echo "  状态: ⚠️  不存在，使用默认配置"
    fi
    echo ""
}

list_presets() {
    echo "📚 可用预设模式"
    echo "=============="
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "从配置文件读取的预设:"
        awk '
        BEGIN { in_presets=0 }
        /^presets:/ { in_presets=1; next }
        in_presets && /^[a-zA-Z_]/ { in_presets=0 }
        in_presets && /^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*:/ {
            preset = $1
            gsub(/:/, "", preset)
            gsub(/^[[:space:]]+/, "", preset)
            print "  • " preset
        }' "$CONFIG_FILE"
    else
        echo "配置文件不存在，可用的内置预设:"
        echo "  • default   - 默认对话模式"
        echo "  • coding    - 编程助手模式"
        echo "  • creative  - 创意写作模式"
        echo "  • academic  - 学术研究模式"
        echo "  • concise   - 简洁回答模式"
    fi
    echo ""
    echo "使用方法: ./run_gpt_oss.sh -p <预设名称> \"你的问题\""
    echo ""
}

check_environment() {
    # 自动选择可用的模型
    if [ ! -f "$MODEL_PATH" ]; then
        echo "⚠️  默认模型不存在，正在查找其他模型..."
        
        local fallback_list=""
        if [ -f "$CONFIG_FILE" ]; then
            fallback_list=$(awk '
            BEGIN { in_model=0; in_fallback=0 }
            /^model:/ { in_model=1; next }
            in_model && /^[a-zA-Z_]/ { in_model=0; in_fallback=0 }
            in_model && /^[[:space:]]+fallback_paths:/ { in_fallback=1; next }
            in_fallback {
                if ($0 ~ /^[[:space:]]*-/) {
                    line=$0
                    sub(/^[[:space:]]*-[[:space:]]*/, "", line)
                    gsub(/"/, "", line)
                    print line
                } else if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
                    next
                } else if ($0 ~ /^[[:space:]]+[a-zA-Z_]/) {
                    in_fallback=0
                }
            }' "$CONFIG_FILE")
        fi

        local found_model=""
        if [ -n "$fallback_list" ]; then
            local old_nullglob=$(shopt -p nullglob 2>/dev/null)
            shopt -s nullglob
            local fallback
            while IFS= read -r fallback; do
                [ -z "$fallback" ] && continue
                for candidate in $fallback; do
                    if [ -f "$candidate" ]; then
                        found_model="$candidate"
                        break 2
                    fi
                done
            done <<< "$fallback_list"
            if [ -n "$old_nullglob" ]; then
                eval "$old_nullglob"
            else
                shopt -u nullglob
            fi
        fi

        if [ -z "$found_model" ]; then
            for model in models/gpt-oss-*.gguf; do
                if [ -f "$model" ]; then
                    found_model="$model"
                    break
                fi
            done
        fi

        if [ -n "$found_model" ]; then
            MODEL_PATH="$found_model"
            echo "✓ 找到模型: $MODEL_PATH"
        fi
        
        if [ ! -f "$MODEL_PATH" ]; then
            echo "❌ 没有找到任何 GPT-OSS 模型文件"
            echo "请确保 models/ 目录下有 gpt-oss-*.gguf 文件"
            exit 1
        fi
    fi

    # 检查 llama-cli
    if [ ! -f "$LLAMA_CLI" ]; then
        echo "❌ llama-cli 不存在: $LLAMA_CLI"
        echo "请确保已正确编译 llama.cpp"
        exit 1
    fi
}

run_test() {
    echo "🧪 GPT-OSS 快速测试"
    echo "=================="
    
    echo ""
    echo "📝 测试 1: 简单问答"
    echo "问题: 你好"
    echo "回答:"
    run_chat "你好" false 30 0.7
    
    echo ""
    echo "📝 测试 2: 数学计算"  
    echo "问题: 1+1等于几？"
    echo "回答:"
    run_chat "1+1等于几？" false 20 0.3
    
    echo ""
    echo "✅ 测试完成"
}

create_harmony_prompt() {
    local user_message="$1"
    
    # 根据当前预设获取系统提示词和开发者指令
    local system_prompt_key="default"
    local instruction_key="default"
    
    # 如果使用了预设，从配置文件读取对应的 key
    if [ "$CURRENT_PRESET" != "default" ] && [ -f "$CONFIG_FILE" ]; then
        system_prompt_key=$(awk -v preset="$CURRENT_PRESET" '
        BEGIN { in_presets=0; in_preset=0 }
        /^presets:/ { in_presets=1; next }
        in_presets && /^[a-zA-Z_]/ { in_presets=0 }
        in_presets && $0 ~ "^[[:space:]]+" preset ":" { in_preset=1; next }
        in_presets && in_preset && /^[[:space:]]+[a-zA-Z_]/ && !/^[[:space:]]+[[:space:]]/ { in_preset=0 }
        in_presets && in_preset && /^[[:space:]]+system_prompt:/ { 
            sub(/^[[:space:]]*system_prompt:[[:space:]]*/, ""); 
            gsub(/"/, "", $0); 
            print $0; exit 
        }' "$CONFIG_FILE")
        
        instruction_key=$(awk -v preset="$CURRENT_PRESET" '
        BEGIN { in_presets=0; in_preset=0 }
        /^presets:/ { in_presets=1; next }
        in_presets && /^[a-zA-Z_]/ { in_presets=0 }
        in_presets && $0 ~ "^[[:space:]]+" preset ":" { in_preset=1; next }
        in_presets && in_preset && /^[[:space:]]+[a-zA-Z_]/ && !/^[[:space:]]+[[:space:]]/ { in_preset=0 }
        in_presets && in_preset && /^[[:space:]]+developer_instruction:/ { 
            sub(/^[[:space:]]*developer_instruction:[[:space:]]*/, ""); 
            gsub(/"/, "", $0); 
            print $0; exit 
        }' "$CONFIG_FILE")
        
        # 如果没有找到，使用预设名称作为 key
        if [ -z "$system_prompt_key" ]; then
            system_prompt_key="$CURRENT_PRESET"
        fi
        if [ -z "$instruction_key" ]; then
            instruction_key="$CURRENT_PRESET"
        fi
    fi
    
    local system_message=$(get_system_prompt "$system_prompt_key")
    local instructions=$(get_developer_instruction "$instruction_key")
    
    echo "<|start|>system<|message|>$system_message<|end|><|start|>developer<|message|># Instructions

$instructions

<|end|><|start|>user<|message|>$user_message<|end|><|start|>assistant<|message|>"
}

run_chat() {
    local prompt="$1"
    local use_harmony="$2"
    local tokens="$3"
    local temp="$4"
    
    if [ "$use_harmony" = "true" ]; then
        prompt=$(create_harmony_prompt "$prompt")
    fi
    
    echo ""
    echo "🤖 正在生成回答..."
    echo "模型: $(basename "$MODEL_PATH")"
    echo "参数: tokens=$tokens, temp=$temp"
    echo "================================"
    
    local effective_top_p="${TOP_P:-$DEFAULT_TOP_P}"
    local effective_context="${CONTEXT:-$DEFAULT_CONTEXT}"
    
    $LLAMA_CLI \
        -m "$MODEL_PATH" \
        -p "$prompt" \
        -n "$tokens" \
        --temp "$temp" \
        --top-p "$effective_top_p" \
        -c "$effective_context" \
        --no-display-prompt
    
    echo ""
    echo "================================"
    echo "✅ 生成完成"
}

# ==================== 主程序 ====================

# 解析命令行参数
SIMPLE_MODE=false
TEST_MODE=false
INTERACTIVE_MODE=false
SHOW_CONFIG_MODE=false
LIST_PRESETS_MODE=false
PRESET_MODE=""
USER_INPUT=""

# 首先加载配置
load_config

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        -s|--simple)
            SIMPLE_MODE=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE_MODE=true
            shift
            ;;
        -p|--preset)
            PRESET_MODE="$2"
            apply_preset "$PRESET_MODE"
            shift 2
            ;;
        -n|--tokens)
            TOKENS="$2"
            shift 2
            ;;
        --temp)
            TEMP="$2"
            shift 2
            ;;
        --model)
            MODEL_PATH="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            load_config  # 重新加载配置
            shift 2
            ;;
        --show-config)
            SHOW_CONFIG_MODE=true
            shift
            ;;
        --list-presets)
            LIST_PRESETS_MODE=true
            shift
            ;;
        -*)
            echo "❌ 未知选项: $1"
            echo "使用 -h 查看帮助"
            exit 1
            ;;
        *)
            USER_INPUT="$1"
            shift
            ;;
    esac
done

# 检查环境
check_environment

# 执行相应功能
if [ "$SHOW_CONFIG_MODE" = "true" ]; then
    show_config
elif [ "$LIST_PRESETS_MODE" = "true" ]; then
    list_presets
elif [ "$TEST_MODE" = "true" ]; then
    run_test
elif [ -n "$USER_INPUT" ]; then
    # 命令行模式
    if [ "$SIMPLE_MODE" = "true" ] || [ "$USE_HARMONY" = "false" ]; then
        run_chat "$USER_INPUT" false "$TOKENS" "$TEMP"
    else
        run_chat "$USER_INPUT" true "$TOKENS" "$TEMP"
    fi
else
    # 交互模式
    echo "🤖 GPT-OSS 交互模式"
    if [ "$SHOW_DETAILS" = "true" ]; then
        echo "使用模型: $(basename "$MODEL_PATH")"
        echo "当前预设: $CURRENT_PRESET"
        if [ "$SHOW_PARAMS" = "true" ]; then
            echo "参数: tokens=$TOKENS, temp=$TEMP"
        fi
    fi
    echo "输入 'help' 查看命令，'quit' 退出"
    echo "=================="
    
    while true; do
        echo ""
        read -p "$USER_PROMPT" input
        
        case "$input" in
            "quit"|"exit"|"退出")
                echo "👋 再见！"
                break
                ;;
            "help"|"帮助")
                echo "🔧 交互模式命令:"
                echo "  help                    - 显示此帮助"
                echo "  quit                    - 退出程序"
                echo "  config                  - 显示当前配置"
                echo "  presets                 - 列出可用预设"
                echo "  preset <模式>           - 切换预设模式"
                echo "  simple                  - 切换简单模式"
                echo "  harmony                 - 切换 Harmony 模式"
                echo "  tokens <数量>           - 设置 token 数量"
                echo "  temp <温度>             - 设置温度参数"
                echo ""
                echo "💬 直接输入问题开始对话"
                ;;
            "config")
                show_config
                ;;
            "presets")
                list_presets
                ;;
            preset\ *)
                preset_name=$(echo "$input" | cut -d' ' -f2-)
                if [ -n "$preset_name" ]; then
                    apply_preset "$preset_name"
                else
                    echo "❌ 请指定预设名称，例如: preset coding"
                fi
                ;;
            "simple")
                SIMPLE_MODE=true
                USE_HARMONY="false"
                echo "✓ 已切换到简单模式"
                ;;
            "harmony")
                SIMPLE_MODE=false
                USE_HARMONY="true"
                echo "✓ 已切换到 Harmony 模式"
                ;;
            tokens\ *)
                new_tokens=$(echo "$input" | cut -d' ' -f2-)
                if [[ "$new_tokens" =~ ^[0-9]+$ ]]; then
                    TOKENS="$new_tokens"
                    echo "✓ Token 数量已设置为: $TOKENS"
                else
                    echo "❌ 请输入有效的数字，例如: tokens 256"
                fi
                ;;
            temp\ *)
                new_temp=$(echo "$input" | cut -d' ' -f2-)
                if [[ "$new_temp" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                    TEMP="$new_temp"
                    echo "✓ 温度参数已设置为: $TEMP"
                else
                    echo "❌ 请输入有效的数字，例如: temp 0.7"
                fi
                ;;
            "")
                continue
                ;;
            *)
                if [ "$SIMPLE_MODE" = "true" ] || [ "$USE_HARMONY" = "false" ]; then
                    run_chat "$input" false "$TOKENS" "$TEMP"
                else
                    run_chat "$input" true "$TOKENS" "$TEMP"
                fi
                ;;
        esac
    done
fi
