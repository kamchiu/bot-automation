#!/usr/bin/env python3
"""
==============================================
HummingBot 配置生成器 v2策略 - 使用指南
==============================================

📋 使用步骤：
1. 准备 bots.csv 文件 - 包含机器人基本信息
   必需列：name
   可选列：config_file_name, script_config, proxy, connector, api_key, secret_key, password（用于自动凭证配置）
   示例：
   name,config_file_name,script_config,proxy,connector,api_key,secret_key,password
   bot1,v2_with_controllers.py,conf_hype.yml,http://proxy1:8080,backpack_perpetual,your_api_key,your_secret_key,your_password
   bot2,,,backpack_perpetual,,,

2. 准备 strategy.csv 文件 - 包含 v2 策略详细配置
   必需列：market, version
   可选列：amount, buy_spreads, sell_spreads, buy_amounts_pct, sell_amounts_pct 等
   注意：controllers 固定为 pmm_dynamic，scripts 固定为 market_making.pmm_dynamic_scripts
   示例：
   market,version,amount,buy_spreads
   BTC,0.1,2000,"1.6,2.4,3.3"

2.5. 准备 strategies-v1.csv 文件 - 包含 v1 策略详细配置（可选）
   必需列：version, market
   可选列：order_amount, leverage, bid_spread, ask_spread 等
   注意：使用 perpetual_market_making 模板
   示例：
   version,market,order_amount,leverage,bid_spread,ask_spread
   ads_20,APT,60,10,0.08,0.08

3. 准备模板文件：
   - templates/pmm_dynamic.yml - v2 策略模板（固定名称）
   - templates/market_making.pmm_dynamic_scripts.yml - v2 脚本模板（固定名称）
   - templates/perpetual_market_making.yml - v1 策略模板（固定名称）
   - templates/{connector}_connector.yml - connector配置模板（可选，会自动生成）

4. 运行命令：
   - 使用指定配置文件夹：python prepare.py <配置文件夹名>
   - 使用当前目录：python prepare.py

   示例：
   - python prepare.py ads_31  # 使用 ads_31 文件夹下的配置
   - python prepare.py ads_32  # 使用 ads_32 文件夹下的配置
   - python prepare.py         # 使用当前目录下的配置

🔧 特性：
- 智能文件变化检测（SHA256哈希）
- 自动生成机器人配置
- 双重策略文件系统（controllers + scripts）
- 🆕 自动connector凭证配置（HummingBot标准加密）
- 完整的目录结构创建

📁 输出结构：
<配置文件夹>/conf/botX/
├── controllers/               # v2 策略配置文件
│   └── conf_v2_apt_0.1.yml
├── scripts/                   # v2 脚本配置
│   └── conf_v2_apt_0.1.yml
├── strategies/                # v1 策略配置文件
│   └── ads_20_apt_perpetual_market_making.yml
├── connectors/               # 🆕 自动生成的connector配置
│   └── backpack_perpetual.yml
└── .password_verification    # 🆕 密码验证文件

<配置文件夹>/logs/botX/                    # 日志目录
<配置文件夹>/data/botX/                    # 数据目录
<配置文件夹>/docker-compose.override.yml   # Docker Compose 配置

🔐 凭证管理：
- 支持从bots.csv自动读取API凭证
- 使用HummingBot标准AES-128-CTR加密
- 每个bot独立的密码和凭证管理
- 安全存储，符合HummingBot原生格式

🚀 多服务器配置示例：
项目结构：
hummingbot-prepare/
├── prepare.py                    # 主脚本（可复用）
├── templates/                    # 模板文件夹
├── ads_31/                       # 服务器1配置
│   ├── bots.csv
│   ├── strategy.csv
│   └── strategies-v1.csv
├── ads_32/                       # 服务器2配置
│   ├── bots.csv
│   ├── strategy.csv
│   └── strategies-v1.csv
└── start-bot.sh                  # 启动脚本

使用方法：
1. 为每个服务器创建配置文件夹
2. 在每个文件夹下放置对应的CSV配置文件
3. 使用启动脚本：./start-bot.sh ads_31
4. 生成的文件会放在对应的服务器文件夹下

🚗 运行：
使用tmux管理多个容器：
   - 启动新窗口并运行特定bot: tmux new-window -n bot1 "docker compose up bot1 -d && docker attach bot1"
   - 切换窗口: Ctrl+B 然后按窗口编号(0-9)

"""




import csv
import os
import re
import sys
import hashlib
import shutil
import json
import yaml

# 添加当前目录到Python路径，以便导入HummingBot模块
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# 使用HummingBot标准兼容的加密功能
try:
    from crypto_utils import CustomCryptoManager
    HUMMINGBOT_AVAILABLE = True
    print("✅ 已加载HummingBot标准兼容加密模块")
except ImportError:
    print("❌ 加密模块不可用 - 请安装依赖: pip install -r requirements-crypto.txt")
    HUMMINGBOT_AVAILABLE = False

# 默认文件配置 - 输出到同级目录
DEFAULT_BOTS_CSV_FILE = 'bots.csv'  # 当前prepare目录下
DEFAULT_STRATEGY_CSV_FILE = 'strategy.csv'  # 当前prepare目录下
DEFAULT_STRATEGY_V1_CSV_FILE = 'strategies-v1.csv'  # v1策略配置
DEFAULT_YML_FILE = 'docker-compose.override.yml'  # 同级目录下
DEFAULT_TEMPLATES_DIR = 'templates'  # 当前prepare目录下的templates文件夹
DEFAULT_HASH_CACHE_FILE = '.csv_hashes.json'  # 当前prepare目录下
DEFAULT_CONF_OUTPUT_DIR = 'conf'  # 同级目录下的conf文件夹
DEFAULT_LOGS_OUTPUT_DIR = 'logs'  # 同级目录下的logs文件夹
DEFAULT_DATA_OUTPUT_DIR = 'data'  # 同级目录下的data文件夹

# 全局变量，将在main函数中根据参数设置
BOTS_CSV_FILE = DEFAULT_BOTS_CSV_FILE
STRATEGY_CSV_FILE = DEFAULT_STRATEGY_CSV_FILE
STRATEGY_V1_CSV_FILE = DEFAULT_STRATEGY_V1_CSV_FILE
YML_FILE = DEFAULT_YML_FILE
TEMPLATES_DIR = DEFAULT_TEMPLATES_DIR
HASH_CACHE_FILE = DEFAULT_HASH_CACHE_FILE
CONF_OUTPUT_DIR = DEFAULT_CONF_OUTPUT_DIR
LOGS_OUTPUT_DIR = DEFAULT_LOGS_OUTPUT_DIR
DATA_OUTPUT_DIR = DEFAULT_DATA_OUTPUT_DIR

SUB_DIRS = ['connectors', 'controllers', 'environment',
            'scripts', 'services', 'strategies']


def calculate_file_hash(file_path):
    """计算文件的SHA256哈希值"""
    if not os.path.exists(file_path):
        return None

    with open(file_path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def load_hash_cache():
    """加载哈希值缓存"""
    if os.path.exists(HASH_CACHE_FILE):
        try:
            with open(HASH_CACHE_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {}


def save_hash_cache(hashes):
    """保存哈希值缓存"""
    with open(HASH_CACHE_FILE, 'w') as f:
        json.dump(hashes, f, indent=2)


def check_files_changed():
    """检查CSV文件是否发生变化"""
    current_hashes = {
        'bots': calculate_file_hash(BOTS_CSV_FILE),
        'strategy': calculate_file_hash(STRATEGY_CSV_FILE),
        'strategies_v1': calculate_file_hash(STRATEGY_V1_CSV_FILE)
    }

    cached_hashes = load_hash_cache()

    # 如果任一文件不存在，返回变化状态
    if current_hashes['bots'] is None or current_hashes['strategy'] is None:
        return True, current_hashes

    # 比较哈希值
    changed = (
        current_hashes['bots'] != cached_hashes.get('bots') or
        current_hashes['strategy'] != cached_hashes.get('strategy') or
        current_hashes['strategies_v1'] != cached_hashes.get('strategies_v1')
    )

    return changed, current_hashes


def clean_generated_files():
    """清理自动生成的文件和目录"""
    print("检测到文件变化，清理旧配置...")

    # 删除 docker-compose.override.yml
    if os.path.exists(YML_FILE):
        os.remove(YML_FILE)
        print(f"已删除: {YML_FILE}")

    # strategies 目录不再使用，无需清理
    # if os.path.exists('strategies'):
    #     shutil.rmtree('strategies')
    #     print("已删除目录: strategies")

    # 清理生成的目录结构
    for root_dir_name in ['conf', 'logs', 'data']:
        # 构建实际路径（同级目录）
        root_dir = root_dir_name
        if os.path.exists(root_dir):
            # 只删除自动生成的子目录，保留手动创建的文件
            for item in os.listdir(root_dir):
                item_path = os.path.join(root_dir, item)
                if os.path.isdir(item_path) and item not in ['__pycache__']:
                    # 检查是否为自动生成的目录（包含标准子目录结构）
                    has_standard_dirs = any(
                        os.path.exists(os.path.join(item_path, subdir))
                        for subdir in SUB_DIRS
                    )
                    if has_standard_dirs:
                        shutil.rmtree(item_path)
                        print(f"已删除目录: {item_path}")


def load_template(template_type, strategy_name):
    """根据策略名加载对应的模板文件"""
    template_path = os.path.join(TEMPLATES_DIR, f"{strategy_name}.yml")

    if not os.path.exists(template_path):
        # 如果找不到特定策略的模板，尝试使用默认模板
        template_path = os.path.join(TEMPLATES_DIR, f"default_{template_type}.yml")
        if not os.path.exists(template_path):
            raise FileNotFoundError(f"找不到模板: {strategy_name}.yml 或 default_{template_type}.yml")

    with open(template_path, 'r', encoding='utf-8') as f:
        return f.read()


def render_template(template_content, variables):
    """使用变量渲染模板内容，支持数组格式转换"""
    def replace_match(match):
        var_name = match.group(1)
        value = variables.get(var_name, match.group(0))

        # 如果变量不存在，保留原占位符
        if value == match.group(0):
            return value

        # 检查是否需要转换为YAML数组格式
        value_str = str(value)
        # 检查三重引号或包含分隔符的情况
        if (value_str.startswith('"""') or
            any(separator in value_str for separator in [',', ';', '|'])):
            return convert_to_yaml_array(value_str)

        return value_str

    return re.sub(r'\$\{([^}]+)\}', replace_match, template_content)


def convert_to_yaml_array(value_str):
    """将CSV中的数组字符串转换为YAML数组格式"""
    # 清理三重引号格式
    cleaned_value = value_str.strip()
    if cleaned_value.startswith('"""') and cleaned_value.endswith('"""'):
        cleaned_value = cleaned_value[3:-3]
    elif cleaned_value.startswith('"') and cleaned_value.endswith('"'):
        cleaned_value = cleaned_value[1:-1]

    # 确定分隔符
    if ',' in cleaned_value:
        separator = ','
    elif ';' in cleaned_value:
        separator = ';'
    elif '|' in cleaned_value:
        separator = '|'
    else:
        return cleaned_value

    # 分割并清理数据
    items = [item.strip() for item in cleaned_value.split(separator)]

    # 转换为YAML数组格式
    yaml_array = '\n'.join(f'- {item}' for item in items if item)
    return yaml_array


def validate_csv_data(data, csv_file_name, required_fields):
    """验证CSV数据的必要字段"""
    for i, row in enumerate(data, start=2):  # 从第2行开始（第1行是标题）
        for field in required_fields:
            if not row.get(field, '').strip():
                print(f"错误: {csv_file_name} 第{i}行的'{field}'字段不能为空")
                sys.exit(1)


# ========== 凭证管理功能 ==========

def create_connector_config_template(connector_name):
    """为指定connector创建基础模板内容"""
    template_content = f"""#####################################
###   {connector_name} config   ###
#####################################

connector: {connector_name}

{connector_name}_api_key: ${{encrypted_api_key}}

{connector_name}_secret_key: ${{encrypted_secret_key}}
"""
    return template_content


def encrypt_credential(password, credential_value):
    """使用自实现的加密系统加密凭证"""
    if not HUMMINGBOT_AVAILABLE:
        return credential_value

    try:
        crypto_manager = CustomCryptoManager(password)
        encrypted_value = crypto_manager.encrypt(credential_value)
        return encrypted_value
    except Exception as e:
        print(f"加密凭证时出错: {e}")
        return credential_value


def generate_connector_configs(bots):
    """为每个机器人生成connector配置文件"""
    if not HUMMINGBOT_AVAILABLE:
        print("跳过connector配置生成（HummingBot标准加密模块不可用）")
        return

    print("使用HummingBot标准加密生成connector配置文件...")

    for bot in bots:
        bot_name = bot.get('name', '').strip()
        connector = bot.get('connector', '').strip()
        api_key = bot.get('api_key', '').strip()
        secret_key = bot.get('secret_key', '').strip()
        password = bot.get('password', '').strip()

        # 检查必要字段
        if not all([bot_name, connector, password]):
            print(f"跳过 {bot_name}：缺少必要的connector信息")
            continue

        # 如果没有API凭证，跳过
        if not api_key and not secret_key:
            print(f"跳过 {bot_name}：没有提供API凭证")
            continue

        try:
            # 创建密码验证文件
            crypto_manager = CustomCryptoManager(password)
            bot_conf_dir = os.path.join(CONF_OUTPUT_DIR, bot_name)
            password_verification_path = os.path.join(bot_conf_dir, '.password_verification')

            # 创建密码验证文件
            encrypted_verification = crypto_manager.create_password_verification()
            with open(password_verification_path, 'w') as f:
                f.write(encrypted_verification)

            # 加密API凭证
            encrypted_api_key = encrypt_credential(password, api_key) if api_key else ""
            encrypted_secret_key = encrypt_credential(password, secret_key) if secret_key else ""

            # 加载或创建connector模板
            template_path = os.path.join(TEMPLATES_DIR, f"{connector}_connector.yml")
            if os.path.exists(template_path):
                with open(template_path, 'r', encoding='utf-8') as f:
                    template_content = f.read()
            else:
                # 如果没有特定模板，创建通用模板
                template_content = create_connector_config_template(connector)
                print(f"使用自动生成的模板: {connector}")

            # 替换模板变量
            variables = {
                'encrypted_api_key': encrypted_api_key,
                'encrypted_secret_key': encrypted_secret_key,
                'connector': connector
            }

            rendered_content = render_template(template_content, variables)

            # 保存connector配置文件
            connector_config_path = os.path.join(CONF_OUTPUT_DIR, bot_name, 'connectors', f"{connector}.yml")
            with open(connector_config_path, 'w', encoding='utf-8') as f:
                f.write(rendered_content)

            print(f"已生成 {bot_name} 的 {connector} connector配置")

        except Exception as e:
            print(f"为 {bot_name} 生成connector配置时出错: {e}")
            continue


def generate_docker_compose(bots):
    """生成 docker-compose.override.yml 文件"""
    # 使用手动字符串拼接写入文件，确保正确的 YAML 格式
    with open(YML_FILE, 'w', encoding='utf-8') as f:
        f.write("# 自动生成的文件，请勿手动编辑\n")
        f.write("x-hb: &default\n")
        f.write("  image: backpack:latest\n")
        f.write("  build:\n")
        f.write("    context: .\n")
        f.write("    dockerfile: Dockerfile\n")
        f.write("  logging:\n")
        f.write("    driver: json-file\n")
        f.write("    options:\n")
        f.write("      max-size: 10m\n")
        f.write("      max-file: \"5\"\n")
        f.write("  tty: true\n")
        f.write("  stdin_open: true\n")
        f.write("  network_mode: host\n\n")
        f.write("services:\n")

        # 为每个机器人生成配置
        for bot in bots:
            # 检查 bot 是否为 None 或空字典
            if not bot:
                continue

            name = bot.get('name', '').strip()
            if not name:
                continue

            # 提取环境变量
            proxy = bot.get('proxy', '').strip()
            config_file_name = bot.get('config_file_name', '').strip()
            script_config = bot.get('script_config', '').strip()
            password = bot.get('password', '').strip()

            f.write(f"  {name}:\n")
            f.write("    <<: *default\n")
            f.write(f"    container_name: {name}\n")

            # 构建环境变量
            environment_vars = []
            if proxy:
                environment_vars.append(f"HTTPS_PROXY={proxy}")
                environment_vars.append(f"HTTP_PROXY={proxy}")
            if password:
                environment_vars.append(f"CONFIG_PASSWORD={password}")
            if config_file_name:
                environment_vars.append(f"CONFIG_FILE_NAME={config_file_name}")
            if script_config:
                environment_vars.append(f"SCRIPT_CONFIG={script_config}")

            if environment_vars:
                f.write("    environment:\n")
                for env_var in environment_vars:
                    f.write(f"      - {env_var}\n")

            f.write("    volumes:\n")
            f.write(f"      - ./conf/{name}:/home/hummingbot/conf\n")
            f.write(f"      - ./logs/{name}:/home/hummingbot/logs\n")
            f.write(f"      - ./data/{name}:/home/hummingbot/data\n")
            f.write("      - ./certs:/home/hummingbot/certs\n")
            f.write("      - ./scripts:/home/hummingbot/scripts\n")
            f.write("      - ./controllers:/home/hummingbot/controllers\n")
            f.write("\n")


# def create_directories(bots):
#     """为每个机器人创建必要的目录结构"""
#     for bot in bots:
#         name = bot.get('name', '').strip()
#         if not name:
#             continue

#         # 主目录
#         for root_dir, output_path in [('conf', CONF_OUTPUT_DIR), ('logs', LOGS_OUTPUT_DIR), ('data', DATA_OUTPUT_DIR)]:
#             os.makedirs(os.path.join(output_path, name), exist_ok=True)

#         # 子目录
#         for sub in SUB_DIRS:
#             os.makedirs(os.path.join(CONF_OUTPUT_DIR, name, sub), exist_ok=True)


def generate_v2_strategy_files(bots, strategies):
    """生成策略配置文件"""
    # 固定使用 pmm_dynamic 策略
    controllers = "pmm_dynamic"
    scripts = "market_making.pmm_dynamic_scripts"

    for strategy in strategies:
        market = strategy.get('market', '').strip()
        version = strategy.get('version', '').strip()

        if not all([market, version]):
            print(f"跳过策略（缺少必要字段）: {strategy}")
            continue

        controllers_fname = f"conf_v2_{version}_{market.lower()}.yml"
        scripts_fname = f"conf_v2_{version}_{market.lower()}.yml"

        # 为每个机器人生成配置文件
        for bot in bots:
            bot_name = bot.get('name', '').strip()
            if not bot_name:
                continue

            # 生成第一个文件：基于 controllers 的模板文件，保存到每个机器人的 controllers 目录
            try:
                controllers_file_path = os.path.join(CONF_OUTPUT_DIR, bot_name, 'controllers', controllers_fname)

                # 加载 controllers 模板（固定使用 pmm_dynamic）
                template_content = load_template('controllers', controllers)
                rendered_content = render_template(template_content, strategy)

                # 写入 controllers 策略文件到机器人的 controllers 目录
                with open(controllers_file_path, 'w', encoding='utf-8') as f:
                    f.write(rendered_content)

                print(f"已生成 controllers 策略文件: {controllers_file_path}")

            except FileNotFoundError as e:
                print(f"警告: {e}")
                print(f"跳过生成 controllers 文件: {controllers_fname}")
                continue
            except Exception as e:
                print(f"生成 controllers 文件时出错 {controllers_fname}: {e}")
                continue

            # 生成第二个文件：基于 scripts 的模板文件，保存到每个机器人的 scripts 目录
            try:
                scripts_file_path = os.path.join(CONF_OUTPUT_DIR, bot_name, 'scripts', scripts_fname)

                # 加载 scripts 模板（固定使用 market_making.pmm_dynamic_scripts）
                scripts_template_content = load_template('scripts', scripts)

                # 创建策略变量，包含策略文件路径（容器内路径）
                strategy_with_path = strategy.copy()
                strategy_with_path['strategy_file_path'] = f"{controllers_fname}"

                rendered_scripts_content = render_template(scripts_template_content, strategy_with_path)

                # 写入 scripts 文件
                with open(scripts_file_path, 'w', encoding='utf-8') as f:
                    f.write(rendered_scripts_content)

                print(f"已生成 scripts 文件: {scripts_file_path}")

            except FileNotFoundError as e:
                print(f"警告: {e}")
                print(f"跳过生成 scripts 文件: {scripts_fname}")
            except Exception as e:
                print(f"生成 scripts 文件时出错 {scripts_fname}: {e}")


def generate_v1_strategy_files(bots, v1_strategies):
    """生成 v1 策略配置文件（perpetual_market_making）"""
    # 加载 perpetual_market_making 模板
    template_path = os.path.join(TEMPLATES_DIR, 'perpetual_market_making.yml')

    if not os.path.exists(template_path):
        print(f"错误: 找不到 v1 策略模板文件: {template_path}")
        return

    with open(template_path, 'r', encoding='utf-8') as f:
        template_content = f.read()

    for strategy in v1_strategies:
        version = strategy.get('version', '').strip()
        market = strategy.get('market', '').strip()

        if not all([version, market]):
            print(f"跳过 v1 策略（缺少必要字段）: {strategy}")
            continue

        # 为每个机器人生成配置文件
        for bot in bots:
            bot_name = bot.get('name', '').strip()
            if not bot_name:
                continue

            # 生成文件名
            strategy_fname = f"conf_v1_{version}_{market.lower()}.yml"

            try:
                # 创建策略文件路径
                strategy_file_path = os.path.join(CONF_OUTPUT_DIR, bot_name, 'strategies', strategy_fname)

                # 渲染模板内容
                rendered_content = render_template(template_content, strategy)

                # 写入策略文件
                with open(strategy_file_path, 'w', encoding='utf-8') as f:
                    f.write(rendered_content)

                print(f"已生成 v1 策略文件: {strategy_file_path}")

            except Exception as e:
                print(f"生成 v1 策略文件时出错 {strategy_fname}: {e}")
                continue


def setup_paths(config_folder=None):
    """根据配置文件夹设置文件路径"""
    global BOTS_CSV_FILE, STRATEGY_CSV_FILE, STRATEGY_V1_CSV_FILE, YML_FILE
    global TEMPLATES_DIR, HASH_CACHE_FILE, CONF_OUTPUT_DIR, LOGS_OUTPUT_DIR, DATA_OUTPUT_DIR

    if config_folder:
        # 如果指定了配置文件夹，从该文件夹读取配置文件
        BOTS_CSV_FILE = os.path.join(config_folder, DEFAULT_BOTS_CSV_FILE)
        STRATEGY_CSV_FILE = os.path.join(config_folder, DEFAULT_STRATEGY_CSV_FILE)
        STRATEGY_V1_CSV_FILE = os.path.join(config_folder, DEFAULT_STRATEGY_V1_CSV_FILE)
        YML_FILE = os.path.join(config_folder, DEFAULT_YML_FILE)
        HASH_CACHE_FILE = os.path.join(config_folder, DEFAULT_HASH_CACHE_FILE)

        # 输出目录仍然在配置文件夹下
        CONF_OUTPUT_DIR = os.path.join(config_folder, DEFAULT_CONF_OUTPUT_DIR)
        LOGS_OUTPUT_DIR = os.path.join(config_folder, DEFAULT_LOGS_OUTPUT_DIR)
        DATA_OUTPUT_DIR = os.path.join(config_folder, DEFAULT_DATA_OUTPUT_DIR)

        # 模板目录仍在根目录
        TEMPLATES_DIR = DEFAULT_TEMPLATES_DIR
    else:
        # 使用默认路径（当前目录）
        BOTS_CSV_FILE = DEFAULT_BOTS_CSV_FILE
        STRATEGY_CSV_FILE = DEFAULT_STRATEGY_CSV_FILE
        STRATEGY_V1_CSV_FILE = DEFAULT_STRATEGY_V1_CSV_FILE
        YML_FILE = DEFAULT_YML_FILE
        TEMPLATES_DIR = DEFAULT_TEMPLATES_DIR
        HASH_CACHE_FILE = DEFAULT_HASH_CACHE_FILE
        CONF_OUTPUT_DIR = DEFAULT_CONF_OUTPUT_DIR
        LOGS_OUTPUT_DIR = DEFAULT_LOGS_OUTPUT_DIR
        DATA_OUTPUT_DIR = DEFAULT_DATA_OUTPUT_DIR


# ========== 主执行逻辑 ==========
def main():
    # 解析命令行参数
    config_folder = None
    if len(sys.argv) > 1:
        config_folder = sys.argv[1]
        if not os.path.isdir(config_folder):
            print(f"错误: 配置文件夹 '{config_folder}' 不存在")
            sys.exit(1)
        print(f"使用配置文件夹: {config_folder}")
    else:
        print("使用当前目录作为配置文件夹")

    # 设置文件路径
    setup_paths(config_folder)

    print("HummingBot 配置生成器 v2.0")
    print("=" * 50)

    # 检查必要文件是否存在
    if not os.path.exists(BOTS_CSV_FILE):
        print(f"错误: 找不到 {BOTS_CSV_FILE} 文件")
        sys.exit(1)

    if not os.path.exists(STRATEGY_CSV_FILE):
        print(f"错误: 找不到 {STRATEGY_CSV_FILE} 文件")
        sys.exit(1)

    # 检查文件是否发生变化
    files_changed, current_hashes = check_files_changed()

    if not files_changed:
        print("CSV 文件未发生变化，跳过重新生成")
        return

    # 如果文件有变化，清理旧配置
    if files_changed:
        clean_generated_files()

    # ---------- 1. 读取 bots.csv ----------
    print("读取 bots.csv...")
    bots = []
    with open(BOTS_CSV_FILE, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        bots = [row for row in reader]

        # 过滤空行和无效数据
        bots = [bot for bot in bots if bot and any(bot.values())]

        # 检查数据是否为空
        if not bots:
            print(f"错误: {BOTS_CSV_FILE} 文件为空")
            sys.exit(1)

        # 验证必要字段
        validate_csv_data(bots, BOTS_CSV_FILE, ['name'])

    print(f"读取到 {len(bots)} 个机器人配置")

    # ---------- 2. 读取 strategy.csv ----------
    print("读取 strategy.csv...")
    strategies = []
    with open(STRATEGY_CSV_FILE, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        strategies = [row for row in reader]

        # 过滤空行和无效数据
        strategies = [strategy for strategy in strategies if strategy and any(strategy.values())]

        # 检查数据是否为空
        if not strategies:
            print(f"错误: {STRATEGY_CSV_FILE} 文件为空")
            sys.exit(1)

        # 验证必要字段
        validate_csv_data(strategies, STRATEGY_CSV_FILE, ['market', 'version'])

    print(f"读取到 {len(strategies)} 个策略配置")

    # ---------- 2.5. 读取 strategies-v1.csv ----------
    v1_strategies = []
    if os.path.exists(STRATEGY_V1_CSV_FILE):
        print("读取 strategies-v1.csv...")
        with open(STRATEGY_V1_CSV_FILE, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            v1_strategies = [row for row in reader]

            # 过滤空行和无效数据
            v1_strategies = [strategy for strategy in v1_strategies if strategy and any(strategy.values())]

            if v1_strategies:
                # 验证必要字段
                validate_csv_data(v1_strategies, STRATEGY_V1_CSV_FILE, ['version', 'market'])
                print(f"读取到 {len(v1_strategies)} 个 v1 策略配置")
            else:
                print("strategies-v1.csv 文件为空，跳过 v1 策略生成")
    else:
        print("未找到 strategies-v1.csv 文件，跳过 v1 策略生成")

    # ---------- 3. 生成 docker-compose.override.yml ----------
    print("生成 docker-compose.override.yml...")
    generate_docker_compose(bots)

    # ---------- 4. 创建目录结构 ----------
    # print("创建目录结构...")
    # create_directories(bots)

    # strategies 目录不再需要，因为文件保存到各机器人的 controllers 目录
    # os.makedirs('strategies', exist_ok=True)

    # ---------- 5. 生成 v2 策略文件 ----------
    print("生成 v2 策略文件...")
    generate_v2_strategy_files(bots, strategies)

    # ---------- 5.5. 生成 v1 策略文件 ----------
    if v1_strategies:
        print("生成 v1 策略文件...")
        generate_v1_strategy_files(bots, v1_strategies)

    # ---------- 6. 生成connector配置文件 ----------
    if HUMMINGBOT_AVAILABLE:
        print("使用HummingBot标准加密生成connector配置文件...")
        generate_connector_configs(bots)
    else:
        print("跳过connector配置生成（请安装依赖：pip install -r requirements-crypto.txt）")

    # ---------- 7. 保存哈希缓存 ----------
    save_hash_cache(current_hashes)

    print("=" * 50)
    print("完成：所有配置文件和目录结构均已生成")


if __name__ == "__main__":
    main()
