/// Formatação e leitura de números no padrão brasileiro, sem depender de `intl`.
///
/// Compartilhado pelas telas para manter moeda, numeração e medidas
/// consistentes, aceitando vírgula nos valores digitados.
class Formato {
  const Formato._();

  /// 1234.5 -> "1.234,50"
  static String moeda(double valor) {
    final partes = valor.abs().toStringAsFixed(2).split('.');
    final buffer = StringBuffer();
    for (var i = 0; i < partes[0].length; i++) {
      if (i > 0 && (partes[0].length - i) % 3 == 0) buffer.write('.');
      buffer.write(partes[0][i]);
    }
    return '${valor < 0 ? '-' : ''}$buffer,${partes[1]}';
  }

  /// 1234.5 -> "R$ 1.234,50"
  static String real(double valor) => 'R\$ ${moeda(valor)}';

  /// 41.0 -> "41"   |   41.5 -> "41,5"
  static String numeracao(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1).replaceAll('.', ',');

  /// 26.5 -> "26,5 cm"
  static String cm(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} cm';

  /// Lê número digitado aceitando vírgula ou ponto. Devolve null se inválido.
  static double? lerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
}
