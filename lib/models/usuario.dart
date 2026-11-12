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

  /// Método estático que traduz a constante técnica da API para o cargo interno da loja em português
  static String rotuloPerfil(String? perfil) {
    // Avalia o texto do perfil em letras maiúsculas
    switch (perfil?.toUpperCase()) {
      // SELLER traduz para Vendedor
      case 'SELLER':
        return 'Vendedor';
      // USER (ou MANAGER) representa o cargo intermediário de Gerente da loja
      case 'USER':
      case 'MANAGER':
        return 'Gerente';
      // OWNER traduz para Proprietário
      case 'OWNER':
        return 'Proprietário';
      // Caso não corresponda a nenhum dos anteriores, exibe fallback
      default:
        return 'Vendedor';
    }
  }

  /// Serializa a entidade de Usuário em um mapa JSON para persistência local
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil,
      };

  /// Indica se o usuário é proprietário com acesso total irrestrito e auditoria
  bool get isOwner => perfil?.toUpperCase() == 'OWNER';

  /// Indica se o usuário ocupa o cargo de gerente operacional de catálogo e estoque
  bool get isManager =>
      perfil?.toUpperCase() == 'USER' || perfil?.toUpperCase() == 'MANAGER';

  /// Indica se o usuário é vendedor focado no atendimento, provador e registro de vendas
  bool get isSeller => perfil?.toUpperCase() == 'SELLER';

  /// Permissão para cadastrar novos modelos, editar dados e ajustar/repor quantidades de estoque (Proprietário e Gerente)
  bool get podeGerenciarProdutos => isOwner || isManager;

  /// E-mail principal ("e-mail mãe") autorizado a cadastrar novas contas de colaboradores no sistema.
  static const String emailMae = 'admin@gmail.com';

  /// Permissão restrita para excluir definitivamente um modelo do catálogo (exclusivo do Proprietário)
  bool get podeExcluirProdutos => isOwner;

  /// Permissão restrita para auditar o histórico geral de saídas e baixas por usuário (exclusivo do Proprietário)
  bool get podeVerAuditoria => isOwner;

  /// Permissão exclusiva do e-mail mãe (Proprietário principal) para cadastrar novos colaboradores da loja.
  bool get podeCriarContas =>
      // Exige que o usuário tenha cargo de Proprietário e seja exatamente o e-mail mãe cadastrado.
      isOwner && email.trim().toLowerCase() == emailMae;

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
