import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Criptografa a senha no frontend antes do envio na requisição HTTP,
/// evitando que a senha em texto puro fique visível na aba Network do DevTools.
/// O backend (`PasswordUtils.decrypt_client_password`) reverte esse formato
/// antes de validar ou gerar o hash bcrypt.
class CriptografiaSenha {
  CriptografiaSenha._();

  static const String prefixo = 'enc:v1:';
  static const String _chavePadrao =
      'yEAMz6EQ0uo6YD7AM8dCZiGRkqfd9iFO1wqaObFj1VQ=';

  static final Random _random = _criarRandom();

  static Random _criarRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Transforma a senha em texto puro no payload criptografado `enc:v1:<hex>`.
  static String criptografar(String senha, {String chave = _chavePadrao}) {
    if (senha.startsWith(prefixo)) return senha;

    final keyBytes = utf8.encode(chave);
    final plainBytes = utf8.encode(senha);
    final nonce = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      nonce[i] = _random.nextInt(256);
    }

    final cipher = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      final mask =
          (keyBytes[i % keyBytes.length] ^ nonce[i % 8] ^ ((i * 31 + 17) & 0xFF)) &
          0xFF;
      cipher[i] = plainBytes[i] ^ mask;
    }

    final buffer = StringBuffer(prefixo);
    for (final b in nonce) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    for (final b in cipher) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Reverte `enc:v1:<hex>` para a senha original (usado em testes e validação).
  static String descriptografar(String valor, {String chave = _chavePadrao}) {
    if (!valor.startsWith(prefixo)) return valor;

    final hex = valor.substring(prefixo.length);
    if (hex.length < 16 || hex.length.isOdd) {
      throw const FormatException('Payload de senha criptografada inválido.');
    }

    final raw = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < raw.length; i++) {
      raw[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    final nonce = raw.sublist(0, 8);
    final cipher = raw.sublist(8);
    final keyBytes = utf8.encode(chave);
    final plain = Uint8List(cipher.length);

    for (var i = 0; i < cipher.length; i++) {
      final mask =
          (keyBytes[i % keyBytes.length] ^ nonce[i % 8] ^ ((i * 31 + 17) & 0xFF)) &
          0xFF;
      plain[i] = cipher[i] ^ mask;
    }

    return utf8.decode(plain);
  }
}

