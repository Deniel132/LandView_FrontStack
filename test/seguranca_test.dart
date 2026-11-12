// Importa o pacote de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o modelo de calçado para testes de integridade e sanitização
import 'package:parte2_flutter/models/calcado.dart';
// Importa o modelo de usuário para validação de controle de acesso (RBAC)
import 'package:parte2_flutter/models/usuario.dart';
// Importa o serviço de comunicação com a API e exceções de segurança
import 'package:parte2_flutter/services/api_service.dart';
// Importa o gerenciador de sessão e tokens de autenticação
import 'package:parte2_flutter/services/sessao.dart';
// Importa o módulo de criptografia de senhas em trânsito
import 'package:parte2_flutter/utils/criptografia_senha.dart';
// Importa o mock do SharedPreferences para testes de limpeza de sessão
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Inicializa o mock do armazenamento local antes de cada teste
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sessao.instance.encerrar();
  });

  group('Testes de Segurança do Aplicativo (LandView Stock)', () {
    test('1. Criptografia de senha oculta texto puro e usa Nonce aleatório anti-replay', () {
      // Define uma senha sensível de teste
      const senhaOriginal = 'SenhaForte@2026!';

      // Gera duas cifras seguidas para a mesma senha
      final cifra1 = CriptografiaSenha.criptografar(senhaOriginal);
      final cifra2 = CriptografiaSenha.criptografar(senhaOriginal);

      // Garante que ambas possuem o prefixo de protocolo enc:v1:
      expect(cifra1.startsWith('enc:v1:'), isTrue);
      expect(cifra2.startsWith('enc:v1:'), isTrue);

      // Garante que a senha em texto puro não aparece em parte alguma da string cifrada
      expect(cifra1.contains(senhaOriginal), isFalse);

      // Garante que o Nonce aleatório torna cada pacote único na rede (proteção contra análise de tráfego)
      expect(cifra1, isNot(equals(cifra2)));

      // Confirma que ambas descriptografam exatamente para a senha original
      expect(CriptografiaSenha.descriptografar(cifra1), equals(senhaOriginal));
      expect(CriptografiaSenha.descriptografar(cifra2), equals(senhaOriginal));

      // Confirma que payloads corrompidos ou truncados são rejeitados com FormatException
      expect(
        () => CriptografiaSenha.descriptografar('enc:v1:123'),
        throwsA(isA<FormatException>()),
      );
    });

    test('2. Controle de Acesso por Perfil (RBAC: Proprietário vs Gerente vs Vendedor)', () {
      // Instancia um usuário com perfil de Proprietário (OWNER)
      const proprietario = Usuario(
        id: 1,
        nome: 'Proprietário Loja',
        email: 'dono@landview.com',
        perfil: 'OWNER',
      );

      // Instancia um usuário com perfil de Gerente (USER)
      const gerente = Usuario(
        id: 2,
        nome: 'Gerente Loja',
        email: 'gerente@landview.com',
        perfil: 'USER',
      );

      // Instancia um usuário com perfil de Vendedor (SELLER)
      const vendedor = Usuario(
        id: 3,
        nome: 'Vendedor Loja',
        email: 'vendedor@landview.com',
        perfil: 'SELLER',
      );

      // O Proprietário (OWNER) deve ter permissão total: gerencia produtos, exclui modelos e vê auditoria
      expect(proprietario.isOwner, isTrue);
      expect(proprietario.perfilRotulo, equals('Proprietário'));
      expect(proprietario.podeGerenciarProdutos, isTrue);
      expect(proprietario.podeExcluirProdutos, isTrue);
      expect(proprietario.podeVerAuditoria, isTrue);

      // O Gerente (USER) gerencia catálogo e estoque, mas NÃO pode excluir modelos nem acessar auditoria do dono
      expect(gerente.isManager, isTrue);
      expect(gerente.perfilRotulo, equals('Gerente'));
      expect(gerente.podeGerenciarProdutos, isTrue);
      expect(gerente.podeExcluirProdutos, isFalse);
      expect(gerente.podeVerAuditoria, isFalse);

      // O Vendedor (SELLER) realiza atendimento e vendas, sem permissões de gestão de catálogo ou auditoria
      expect(vendedor.isSeller, isTrue);
      expect(vendedor.perfilRotulo, equals('Vendedor'));
      expect(vendedor.podeGerenciarProdutos, isFalse);
      expect(vendedor.podeExcluirProdutos, isFalse);
      // O Proprietário principal com o e-mail mãe (admin@gmail.com) pode criar contas da equipe
      const mae = Usuario(
        id: 34,
        nome: 'admin',
        email: Usuario.emailMae,
        perfil: 'OWNER',
      );
      expect(mae.podeCriarContas, isTrue);

      // Outro Proprietário sem ser o e-mail mãe NÃO recebe permissão de criar contas
      expect(proprietario.podeCriarContas, isFalse);
      // Gerente e Vendedor também NÃO podem criar contas
      expect(gerente.podeCriarContas, isFalse);
      expect(vendedor.podeCriarContas, isFalse);
    });

    test('3. Isolamento de Sessão, Logout Seguro e Expiração de Token (401)', () {
      // Inicia uma sessão autenticada simulando login válido
      const usuario = Usuario(
        id: 10,
        nome: 'Arthur',
        email: 'arthur@landview.com',
        perfil: 'OWNER',
      );
      Sessao.instance.iniciar('token-secreto-jwt-123', usuario);

      // Verifica que a sessão está ativa
      expect(Sessao.instance.logado, isTrue);
      expect(Sessao.instance.token, equals('token-secreto-jwt-123'));

      // Executa logout e verifica limpeza imediata de credenciais em memória
      Sessao.instance.encerrar();
      expect(Sessao.instance.logado, isFalse);
      expect(Sessao.instance.token, isNull);
      expect(Sessao.instance.usuario, isNull);

      // Simula expiração forçada de token (erro 401 da API) e verifica revogação imediata
      var redirecionouLogin = false;
      Sessao.instance.aoExpirar = () => redirecionouLogin = true;
      Sessao.instance.iniciar('token-vencido', usuario);
      Sessao.instance.expirar();
      expect(Sessao.instance.logado, isFalse);
      expect(Sessao.instance.token, isNull);
      expect(redirecionouLogin, isTrue);
      Sessao.instance.aoExpirar = null;
    });

    test('4. Sanitização de URLs de imagem e bloqueio de estoque negativo', () {
      // Cria um calçado tentando injetar esquema javascript: na URL de imagem
      final calcadoMalicioso = Calcado(
        id: 99,
        nome: 'Teste XSS',
        marca: 'Nike',
        tipo: TipoCalcado.tenis,
        forma: FormaCalcado.padrao,
        preco: 199.90,
        estoque: 5,
        imagemUrl: 'javascript:alert(1)',
        tamanhos: Calcado.gerarTabelaPadrao(FormaCalcado.padrao),
      );

      // Garante que a validação bloqueia URLs que não sejam http/https ou data:image/
      expect(calcadoMalicioso.temImagemUrl, isFalse);
      expect(calcadoMalicioso.toJson()['imagem_url'], isNull);

      // Garante que tentar definir estoque negativo em uma numeração trava em zero (0)
      final aposAjusteNegativo = calcadoMalicioso.atualizarEstoqueDoTamanho(37, -50);
      final tam37 = aposAjusteNegativo.tamanhos.firstWhere((t) => t.numeracao == 37);
      expect(tam37.estoque, equals(0));
      expect(aposAjusteNegativo.estoque, greaterThanOrEqualTo(0));
    });

    test('5. Autenticação real rejeita senha incorreta com HTTP 401', () async {
      // Tenta autenticar com senha errada para uma conta existente
      await expectLater(
        () => ApiService.instance.login('vendedor@loja.com', 'senha_errada_999999'),
        throwsA(
          isA<ApiException>().having((e) => e.status, 'status HTTP', 401),
        ),
      );

      // Garante que nenhuma sessão ou token foi aberto após a tentativa falha
      expect(Sessao.instance.logado, isFalse);
      expect(Sessao.instance.token, isNull);
    });
  });
}
