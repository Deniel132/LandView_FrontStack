/// Utilitário estático para formatação e conversão de valores numéricos no padrão brasileiro (pt-BR),
/// permitindo formatar moedas, numerações de calçados e medidas em centímetros sem dependências pesadas de bibliotecas externas.
class Formato {
  // Construtor privado para impedir a instanciação da classe
  const Formato._();

  /// Converte um valor numérico decimal em texto monetário com separador de milhar e centavos (Ex: 1234.5 -> "1.234,50")
  static String moeda(double valor) {
    // Separa a parte inteira da parte decimal arredondando para duas casas
    final partes = valor.abs().toStringAsFixed(2).split('.');
    // Cria um buffer otimizado para inserção dos pontos de milhar
    final buffer = StringBuffer();
    // Percorre cada caractere da parte inteira
    for (var i = 0; i < partes[0].length; i++) {
      // Insere um ponto a cada 3 dígitos da direita para a esquerda
      if (i > 0 && (partes[0].length - i) % 3 == 0) buffer.write('.');
      // Escreve o dígito atual
      buffer.write(partes[0][i]);
    }
    // Retorna a string final com sinal negativo (se houver), parte inteira e centavos separados por vírgula
    return '${valor < 0 ? '-' : ''}$buffer,${partes[1]}';
  }

  /// Converte o valor em texto monetário precedido pelo símbolo de Real brasileiro (Ex: 1234.5 -> "R$ 1.234,50")
  static String real(double valor) => 'R\$ ${moeda(valor)}';

  /// Formata a numeração do calçado omitindo o ".0" desnecessário (Ex: 41.0 -> "41" e 41.5 -> "41,5")
  static String numeracao(double n) =>
      // Se for número inteiro, exibe sem decimais; senão formata com 1 casa trocando ponto por vírgula
      n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1).replaceAll('.', ',');

  /// Formata uma medida linear em centímetros com uma casa decimal (Ex: 26.5 -> "26,5 cm")
  static String cm(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} cm';

  /// Faz o parse seguro de um texto digitado pelo usuário para double, aceitando vírgula ou ponto
  static double? lerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
}
