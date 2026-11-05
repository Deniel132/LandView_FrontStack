/// Concentra as informações institucionais, dados de contato e caminhos de assets da loja,
/// centralizando esses valores para fácil manutenção em todo o aplicativo.
class Loja {
  // Construtor privado para impedir que a classe seja instanciada, pois possui apenas membros estáticos
  const Loja._();

  // Nome fantasia resumido da marca exibido nas barras de navegação e telas
  static const nome = 'LandView Stock';

  // Razão social ou nome institucional completo da empresa
  static const nomeCompleto = 'Land View Artigos Esportivos';

  // Nome do produto de software (sistema interno de gestão)
  static const produto = 'LandView Stock';

  // Endereço físico da loja física para exibição informativa
  static const endereco = 'Avenida São Paulo 743, Loja i17';

  // Telefone formatado para visualização do usuário
  static const telefone = '(44) 99102-0051';

  // Telefone no formato internacional para links de discagem direta ou WhatsApp
  static const telefoneLink = '+5544991020051';

  // Nome de usuário do perfil oficial no Instagram
  static const instagram = '@landViewOficial';

  // URL completa para abrir o perfil da loja diretamente no navegador ou aplicativo
  static const instagramUrl = 'https://www.instagram.com/landviewoficial/';

  // Caminho local do arquivo de imagem com o logotipo oficial da empresa
  static const logoAsset = 'assets/logo.png';
}
