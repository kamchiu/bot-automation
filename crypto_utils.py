"""
HummingBot标准兼容加密模块
完全基于HummingBot官方实现，使用eth_keyfile库确保100%兼容性
支持与HummingBot完全兼容的凭证加密存储和密码验证
"""

import binascii
import json
import os
from typing import Dict, Any

# 使用HummingBot标准的eth_keyfile依赖
from eth_keyfile.keyfile import (
    DKLEN,
    _pbkdf2_hash,
    encrypt_aes_ctr,
    get_default_work_factor_for_kdf,
    encode_hex_no_prefix,
    keccak,
    big_endian_to_int,
    Random
)
from eth_account import Account


class HummingBotCryptoManager:
    """
    HummingBot标准加密管理器
    完全复制HummingBot的config_crypt.py实现
    确保与HummingBot ETH keyfile v3格式100%兼容
    """

    def __init__(self, password: str):
        """
        初始化加密管理器
        Args:
            password: 用户密码（字符串格式）
        """
        self._password = password
        self.password_bytes = password.encode('utf-8')

    def encrypt_secret_value(self, attr: str, value: str) -> str:
        """
        加密机密值（复制HummingBot的ETHKeyFileSecretManger.encrypt_secret_value实现）
        Args:
            attr: 属性名称（用于错误信息）
            value: 要加密的值
        Returns:
            十六进制编码的加密字符串
        """
        if self._password is None:
            raise ValueError(f"Could not encrypt secret attribute {attr} because no password was provided.")

        password_bytes = self._password.encode()
        value_bytes = value.encode()
        keyfile_json = self._create_v3_keyfile_json(value_bytes, password_bytes)
        json_str = json.dumps(keyfile_json)
        encrypted_value = binascii.hexlify(json_str.encode()).decode()
        return encrypted_value

    def decrypt_secret_value(self, attr: str, value: str) -> str:
        """
        解密机密值（复制HummingBot的ETHKeyFileSecretManger.decrypt_secret_value实现）
        Args:
            attr: 属性名称（用于错误信息）
            value: 十六进制编码的加密字符串
        Returns:
            解密后的原始字符串
        """
        if self._password is None:
            raise ValueError(f"Could not decrypt secret attribute {attr} because no password was provided.")

        value_bytes = binascii.unhexlify(value)
        decrypted_value = Account.decrypt(value_bytes.decode(), self._password).decode()
        return decrypted_value

    def _create_v3_keyfile_json(self, message_to_encrypt: bytes, password: bytes, kdf="pbkdf2", work_factor=None) -> Dict[str, Any]:
        """
        完全复制HummingBot的_create_v3_keyfile_json函数
        创建ETH keyfile v3格式的加密JSON
        """
        salt = Random.get_random_bytes(16)

        if work_factor is None:
            work_factor = get_default_work_factor_for_kdf(kdf)

        if kdf == 'pbkdf2':
            derived_key = _pbkdf2_hash(
                password,
                hash_name='sha256',
                salt=salt,
                iterations=work_factor,
                dklen=DKLEN,
            )
            kdfparams = {
                'c': work_factor,
                'dklen': DKLEN,
                'prf': 'hmac-sha256',
                'salt': encode_hex_no_prefix(salt),
            }
        elif kdf == 'scrypt':
            # 如果需要scrypt支持，可以添加
            raise NotImplementedError("Scrypt KDF not implemented in this version")
        else:
            raise NotImplementedError("KDF not implemented: {0}".format(kdf))

        # 使用HummingBot标准的IV生成和AES加密
        iv = big_endian_to_int(Random.get_random_bytes(16))
        encrypt_key = derived_key[:16]
        ciphertext = encrypt_aes_ctr(message_to_encrypt, encrypt_key, iv)

        # 使用HummingBot标准的MAC计算（Keccak-256，不是SHA3-256）
        mac = keccak(derived_key[16:32] + ciphertext)

        return {
            'crypto': {
                'cipher': 'aes-128-ctr',
                'cipherparams': {
                    'iv': encode_hex_no_prefix(iv.to_bytes((iv.bit_length() + 7) // 8 or 1, "big")),
                },
                'ciphertext': encode_hex_no_prefix(ciphertext),
                'kdf': kdf,
                'kdfparams': kdfparams,
                'mac': encode_hex_no_prefix(mac),
            },
            'version': 3,
            'alias': '',  # HummingBot标准要求包含alias字段
        }

    def encrypt(self, value: str) -> str:
        """
        加密字符串值的便捷方法
        Args:
            value: 要加密的字符串
        Returns:
            十六进制编码的加密字符串
        """
        return self.encrypt_secret_value("generic", value)

    def decrypt(self, encrypted_hex: str) -> str:
        """
        解密十六进制编码字符串的便捷方法
        Args:
            encrypted_hex: 十六进制编码的加密字符串
        Returns:
            解密后的原始字符串
        """
        return self.decrypt_secret_value("generic", encrypted_hex)

    def create_password_verification(self) -> str:
        """
        创建HummingBot标准密码验证字符串
        返回加密的"HummingBot"字符串，用于密码验证
        """
        return self.encrypt("HummingBot")

    def validate_password(self, encrypted_verification: str) -> bool:
        """
        验证密码是否正确
        Args:
            encrypted_verification: 加密的密码验证字符串
        Returns:
            密码是否正确
        """
        try:
            decrypted_word = self.decrypt(encrypted_verification)
            return decrypted_word == "HummingBot"
        except ValueError as e:
            if str(e) != "MAC mismatch":
                raise e
            return False
        except Exception:
            return False


# 为了保持向后兼容性，保留旧的类名
CustomCryptoManager = HummingBotCryptoManager


def store_password_verification(secrets_manager: HummingBotCryptoManager, file_path: str):
    """
    存储密码验证文件（复制HummingBot的store_password_verification逻辑）
    Args:
        secrets_manager: 加密管理器实例
        file_path: 密码验证文件路径
    """
    PASSWORD_VERIFICATION_WORD = "HummingBot"
    encrypted_word = secrets_manager.encrypt_secret_value(PASSWORD_VERIFICATION_WORD, PASSWORD_VERIFICATION_WORD)
    with open(file_path, "w") as f:
        f.write(encrypted_word)


def validate_password_from_file(secrets_manager: HummingBotCryptoManager, file_path: str) -> bool:
    """
    从文件验证密码（复制HummingBot的validate_password逻辑）
    Args:
        secrets_manager: 加密管理器实例
        file_path: 密码验证文件路径
    Returns:
        密码是否正确
    """
    PASSWORD_VERIFICATION_WORD = "HummingBot"

    try:
        with open(file_path, "r") as f:
            encrypted_word = f.read().strip()

        decrypted_word = secrets_manager.decrypt_secret_value(PASSWORD_VERIFICATION_WORD, encrypted_word)
        return decrypted_word == PASSWORD_VERIFICATION_WORD

    except ValueError as e:
        if str(e) != "MAC mismatch":
            raise e
        return False
    except Exception:
        return False


# 模块级别的便捷函数
def create_hummingbot_compatible_encryption(password: str) -> HummingBotCryptoManager:
    """
    创建HummingBot兼容的加密管理器
    Args:
        password: 用户密码
    Returns:
        配置好的加密管理器实例
    """
    return HummingBotCryptoManager(password)


if __name__ == "__main__":
    # 简单的测试和演示
    print("HummingBot标准兼容加密模块")
    print("=" * 50)

    # 创建加密管理器
    password = "test_password"
    manager = HummingBotCryptoManager(password)

    # 测试加密解密
    test_value = "HummingBot"
    encrypted = manager.encrypt(test_value)
    decrypted = manager.decrypt(encrypted)

    print(f"原始值: {test_value}")
    print(f"加密结果: {encrypted[:50]}...")
    print(f"解密结果: {decrypted}")
    print(f"测试结果: {'✅ 通过' if decrypted == test_value else '❌ 失败'}")