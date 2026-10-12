/// Usuário autenticado (vendedor da loja).
class Usuario {
  final int? id;
  final String nome;
  final String email;

  const Usuario({this.id, required this.nome, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: (json['id'] as num?)?.toInt(),
        nome: json['nome'] as String,
        email: json['email'] as String,
      );

  List<String> get _partes =>
      nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  String get primeiroNome => _partes.isEmpty ? nome : _partes.first;

  /// "Maria Souza" -> "MS"
  String get iniciais {
    final p = _partes;
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}
