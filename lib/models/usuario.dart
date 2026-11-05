/// Representa o usuário logado no aplicativo (vendedor, gerente/proprietário ou usuário padrão),
/// contendo seus dados cadastrais, cargo e utilitários visuais de avatar.
class Usuario {
  /// Identificador numérico do usuário no banco de dados (pode ser nulo em sessões locais/demo)
  final int? id;

  /// Nome completo ou amigável do usuário exibido na interface
  final String nome;

  /// Endereço de e-mail utilizado no login e autenticação
  final String email;

  /// Papel/permissão retornado pela API (`SELLER`, `OWNER` ou `USER`).
  /// Pode ser nulo caso o usuário tenha sido criado em versões antigas sem controle de perfil.
  final String? perfil;

  /// Construtor imutável da entidade de Usuário
  const Usuario({
    // ID numérico opcional
    this.id,
    // Nome do usuário obrigatório
    required this.nome,
    // E-mail obrigatório
    required this.email,
    // Papel/perfil opcional
    this.perfil,
  });

  /// Desserializa um mapa JSON (vindo da API ou armazenamento local) em uma instância de Usuário
  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        // Converte o campo 'id' numérico para inteiro caso exista
        id: (json['id'] as num?)?.toInt(),
        // Extrai o nome como String
        nome: json['nome'] as String,
        // Extrai o e-mail como String
        email: json['email'] as String,
        // Extrai o perfil como String opcional
        perfil: json['perfil'] as String?,
      );

  /// Cria uma cópia deste usuário permitindo alterar campos específicos mantendo os demais
  Usuario copyWith({int? id, String? nome, String? email, String? perfil}) =>
      Usuario(
        // Atualiza o ID ou preserva o atual
        id: id ?? this.id,
        // Atualiza o nome ou preserva o atual
        nome: nome ?? this.nome,
        // Atualiza o e-mail ou preserva o atual
        email: email ?? this.email,
        // Atualiza o perfil ou preserva o atual
        perfil: perfil ?? this.perfil,
      );

  /// Getter que retorna o nome amigável e legível do perfil do usuário para exibir na interface
  String get perfilRotulo => rotuloPerfil(perfil);

  /// Método estático que traduz a constante técnica da API para o português
  static String rotuloPerfil(String? perfil) {
    // Avalia o texto do perfil em letras maiúsculas
    switch (perfil?.toUpperCase()) {
      // SELLER traduz para Vendedor
      case 'SELLER':
        return 'Vendedor';
      // OWNER traduz para Proprietário
      case 'OWNER':
        return 'Proprietário';
      // USER traduz para Usuário
      case 'USER':
        return 'Usuário';
      // Caso não corresponda a nenhum dos anteriores, exibe fallback
      default:
        return 'Perfil não definido';
    }
  }

  /// Serializa a entidade de Usuário em um mapa JSON para persistência local
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil,
      };

  /// Indica se o usuário é proprietário/gerente com acesso total administrativo
  bool get isOwner => perfil?.toUpperCase() == 'OWNER';

  /// Indica se o usuário é vendedor focado no atendimento e saídas
  bool get isSeller => perfil?.toUpperCase() == 'SELLER';

  /// Permissão para cadastrar, editar e excluir produtos do catálogo
  bool get podeGerenciarProdutos => isOwner;

  /// Permissão para visualizar a auditoria de saídas de estoque
  bool get podeVerAuditoria => isOwner;

  /// Separa o nome em palavras individuais, ignorando espaços múltiplos
  List<String> get _partes =>
      nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  /// Retorna apenas o primeiro nome do usuário (ex: "Arthur Beraldo" -> "Arthur")
  String get primeiroNome => _partes.isEmpty ? nome : _partes.first;

  /// Gera as iniciais do nome para renderização no avatar circular (ex: "Maria Souza" -> "MS")
  String get iniciais {
    // Obtém as partes do nome
    final p = _partes;
    // Se o nome estiver vazio, exibe uma interrogação
    if (p.isEmpty) return '?';
    // Se tiver apenas um nome, exibe a primeira letra maiúscula
    if (p.length == 1) return p.first[0].toUpperCase();
    // Se tiver dois ou mais nomes, pega a primeira letra do primeiro e do último nome
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}
