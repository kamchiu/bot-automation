#!/bin/bash
# 配置管理函数库

# 验证配置文件夹
validate_config_folder() {
    local folder_name="$1"

    if [ -z "$folder_name" ]; then
        print_error "请提供配置文件夹名称"
        return 1
    fi

    if [ ! -d "$folder_name" ]; then
        print_error "找不到配置文件夹: $folder_name"
        return 1
    fi

    print_info "使用配置文件夹: $folder_name"
    return 0
}

# 检查必要的配置文件
check_required_files() {
    local config_folder="$1"
    local bots_csv="$config_folder/bots.csv"
    local prepare_script="prepare.py"

    # 检查bots.csv
    if ! check_file_exists "$bots_csv"; then
        return 1
    fi

    # 检查prepare.py
    if ! check_file_exists "$prepare_script"; then
        print_error "找不到根目录下的 $prepare_script 文件"
        return 1
    fi

    print_info "配置文件检查通过"
    return 0
}

# 运行prepare.py脚本
run_prepare_script() {
    local config_folder="$1"

    print_info "运行 prepare.py 生成配置文件..."
    print_info "配置文件夹: $config_folder"

    # 激活conda环境
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate hummingbot

    # 运行prepare.py
    python prepare.py "$config_folder"
    if [ $? -ne 0 ]; then
        print_error "prepare.py 执行失败"
        return 1
    fi

    print_info "配置文件生成完成"
    return 0
}

# 获取配置信息
get_config_info() {
    local config_folder="$1"
    local bots_csv="$config_folder/bots.csv"

    echo "配置信息:"
    echo "  配置文件夹: $config_folder"
    echo "  机器人配置: $bots_csv"
    echo "  准备脚本: prepare.py"
}
