/// Modelo que mapeia o registro de saída de estoque para auditoria,
/// integrado com a rota `GET /stock-exit/` e `POST /stock-exit/` do backend FastAPI.
///
/// Como o backend devolve apenas as chaves estrangeiras (IDs numéricos),
/// os atributos [nomeProduto] e [emailUsuario] são enriquecidos pelo próprio
/// Flutter cruzando dados locais para facilitar a leitura humana nas telas.
class SaidaEstoque {
  /// Identificador único da transação de saída no banco de dados
  final int id;

  /// ID do produto (calçado) ao qual esta saída se refere
  final int idProduto;

  /// ID do usuário/vendedor que realizou a operação de baixa
  final int idUsuario;

  /// ID do registro de estoque vinculado
  final int idEstoque;

  /// Quantidade de unidades removidas ou vendidas
  final int quantidade;

  /// Nome legível do produto (enriquecido pelo frontend para exibição)
  final String? nomeProduto;

  /// E-mail do usuário que efetuou a baixa (enriquecido pelo frontend)
  final String? emailUsuario;

  /// Construtor imutável com os campos obrigatórios da API e os enriquecidos opcionais
  const SaidaEstoque({
    // ID da saída obrigatório
    required this.id,
    // ID do produto obrigatório
    required this.idProduto,
    // ID do usuário obrigatório
    required this.idUsuario,
    // ID do estoque obrigatório
    required this.idEstoque,
    // Quantidade de saída obrigatória
    required this.quantidade,
    // Nome do produto opcional
    this.nomeProduto,
    // E-mail do usuário opcional
    this.emailUsuario,
  });

  /// Converte o JSON vindo da rota `/stock-exit/` do backend FastAPI em uma instância de SaidaEstoque
  factory SaidaEstoque.fromJson(Map<String, dynamic> json) => SaidaEstoque(
        // Converte o campo 'id' numérico para inteiro
        id: (json['id'] as num).toInt(),
        // Converte a chave estrangeira 'id_product' para inteiro
        idProduto: (json['id_product'] as num).toInt(),
        // Converte a chave estrangeira 'id_user' para inteiro
        idUsuario: (json['id_user'] as num).toInt(),
        // Converte a chave estrangeira 'id_stock' para inteiro
        idEstoque: (json['id_stock'] as num).toInt(),
        // Converte a quantidade 'quantity' para inteiro
        quantidade: (json['quantity'] as num).toInt(),
      );

  /// Cria uma cópia deste registro permitindo preencher ou atualizar o nome do produto e e-mail
  SaidaEstoque copyWith({String? nomeProduto, String? emailUsuario}) =>
      SaidaEstoque(
        // Preserva o mesmo ID
        id: id,
        // Preserva o mesmo ID de produto
        idProduto: idProduto,
        // Preserva o mesmo ID de usuário
        idUsuario: idUsuario,
        // Preserva o mesmo ID de estoque
        idEstoque: idEstoque,
        // Preserva a mesma quantidade
        quantidade: quantidade,
        // Aplica o novo nome do produto ou mantém o anterior caso seja nulo
        nomeProduto: nomeProduto ?? this.nomeProduto,
        // Aplica o novo e-mail do usuário ou mantém o anterior caso seja nulo
        emailUsuario: emailUsuario ?? this.emailUsuario,
      );
}
