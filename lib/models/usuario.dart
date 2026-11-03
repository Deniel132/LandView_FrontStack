/// Usuário autenticado (vendedor, proprietário ou usuário comum).
class Usuario {
  final int? id;
  final String nome;
  final String email;

  /// Perfil vindo da API (`SELLER`, `OWNER` ou `USER`). Pode ser nulo em
  /// contas antigas, criadas antes do backend ter perfis.
  final String? perfil;

  const Usuario({
    this.id,
    required this.nome,
    required this.email,
    this.perfil,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: (json['id'] as num?)?.toInt(),
        nome: json['nome'] as String,
        email: json['email'] as String,
        perfil: json['perfil'] as String?,
      );

  Usuario copyWith({int? id, String? nome, String? email, String? perfil}) =>
      Usuario(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        email: email ?? this.email,
        perfil: perfil ?? this.perfil,
      );

  /// Nome amigável do perfil para exibir na interface.
  String get perfilRotulo => rotuloPerfil(perfil);

  static String rotuloPerfil(String? perfil) {
    switch (perfil?.toUpperCase()) {
      case 'SELLER':
        return 'Vendedor';
      case 'OWNER':
        return 'Proprietário';
      case 'USER':
        return 'Usuário';
      default:
        return 'Perfil não definido';
    }
  }

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
