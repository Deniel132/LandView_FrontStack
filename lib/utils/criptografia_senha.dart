// Importa biblioteca de conversão de texto UTF-8 e bytes
import 'dart:convert';
// Importa utilitários matemáticos e geradores de números aleatórios
import 'dart:math';
// Importa suporte a vetores de bytes Uint8List
import 'dart:typed_data';

/// Utilitário de segurança que realiza a criptografia da senha no cliente antes da transmissão HTTP.
///
/// Essa camada evita que a senha do usuário transite em texto puro (plain text) ou fique visível
/// nas ferramentas de inspeção de rede (DevTools / Network tab).
/// O backend FastAPI (`PasswordUtils.decrypt_client_password`) reverte esse formato antes de
/// aplicar o hash final bcrypt para persistência segura no banco.
class CriptografiaSenha {
  // Construtor privado para impedir instanciação da classe utilitária
  CriptografiaSenha._();

  // Prefixo identificador da versão do algoritmo de cifra
  static const String prefixo = 'enc:v1:';

  // Chave de cifra compartilhada de transporte alinhada com o backend LandView_API
  static const String _chavePadrao =
      'yEAMz6EQ0uo6YD7AM8dCZiGRkqfd9iFO1wqaObFj1VQ=';

  // Instância do gerador de números aleatórios
  static final Random _random = _criarRandom();

  // Cria gerador criptograficamente seguro com fallback para gerador padrão
  static Random _criarRandom() {
    try {
      // Tenta instanciar gerador seguro do sistema operacional
      return Random.secure();
    } catch (_) {
      // Fallback em plataformas que não suportam Random.secure
      return Random();
    }
  }

  /// Criptografa a senha pura transformando-a no formato `enc:v1:<nonce_hex><cipher_hex>`.
  static String criptografar(String senha, {String chave = _chavePadrao}) {
    // Se a senha já estiver criptografada, não repete a operação
    if (senha.startsWith(prefixo)) return senha;

    // Converte a chave compartilhada em bytes UTF-8
    final keyBytes = utf8.encode(chave);
    // Converte a senha em texto puro para bytes UTF-8
    final plainBytes = utf8.encode(senha);

    // Gera um vetor de inicialização (Nonce) aleatório de 8 bytes para garantir que a mesma senha gere cifras distintas
    final nonce = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      nonce[i] = _random.nextInt(256);
    }

    // Cria o array de bytes cifrados com o mesmo tamanho da senha original
    final cipher = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      // Calcula a máscara combinando chave, nonce e dispersão aritmética
      final mask =
          (keyBytes[i % keyBytes.length] ^ nonce[i % 8] ^ ((i * 31 + 17) & 0xFF)) &
          0xFF;
      // Aplica operação XOR entre o byte da senha e a máscara calculada
      cipher[i] = plainBytes[i] ^ mask;
    }

    // Inicia o buffer de texto com o prefixo identificador
    final buffer = StringBuffer(prefixo);

    // Converte e anexa os 8 bytes do nonce em formato hexadecimal de 2 caracteres
    for (final b in nonce) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }

    // Converte e anexa os bytes da cifra em formato hexadecimal de 2 caracteres
    for (final b in cipher) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }

    // Retorna a string final cifrada
    return buffer.toString();
  }

  /// Descriptografa um payload cifrado no formato `enc:v1:...` recuperando a senha original.
  static String descriptografar(String valor, {String chave = _chavePadrao}) {
    // Se não tiver o prefixo, retorna o valor inalterado
    if (!valor.startsWith(prefixo)) return valor;

    // Extrai o conteúdo hexadecimal após o prefixo
    final hex = valor.substring(prefixo.length);

    // Valida se possui tamanho mínimo (8 bytes nonce = 16 caracteres hex) e comprimento par
    if (hex.length < 16 || hex.length.isOdd) {
      throw const FormatException('Payload de senha criptografada inválido.');
    }

    // Aloca vetor de bytes para os dados hexadecimais brutos
    final raw = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < raw.length; i++) {
      raw[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    // Separa os primeiros 8 bytes como Nonce
    final nonce = raw.sublist(0, 8);
    // O restante dos bytes corresponde ao conteúdo criptografado
    final cipher = raw.sublist(8);
    // Codifica a chave em bytes UTF-8
    final keyBytes = utf8.encode(chave);
    // Aloca vetor de bytes para a senha decifrada
    final plain = Uint8List(cipher.length);

    // Inverte a máscara XOR para recompor os bytes originais
    for (var i = 0; i < cipher.length; i++) {
      final mask =
          (keyBytes[i % keyBytes.length] ^ nonce[i % 8] ^ ((i * 31 + 17) & 0xFF)) &
          0xFF;
      plain[i] = cipher[i] ^ mask;
    }

    // Decodifica os bytes recuperados em string UTF-8
    return utf8.decode(plain);
  }
}
