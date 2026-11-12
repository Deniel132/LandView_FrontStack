// Importa os componentes visuais do Flutter para testes de interface
import 'package:flutter/material.dart';
// Importa o pacote de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o modelo de usuário para simular sessão do e-mail mãe e de outros cargos
import 'package:parte2_flutter/models/usuario.dart';
// Importa a tela de criação de contas da equipe
import 'package:parte2_flutter/screens/criar_conta_page.dart';
// Importa a tela de login para validar remoção do botão público de cadastro
import 'package:parte2_flutter/screens/login_page.dart';
// Importa o gerenciador de sessão global para controle de autenticação nos testes
import 'package:parte2_flutter/services/sessao.dart';
// Importa o widget do menu da conta na AppBar
import 'package:parte2_flutter/widgets/logo_loja.dart';

void main() {
  // Limpa a sessão antes e depois de cada teste para manter isolamento completo
  setUp(() => Sessao.instance.encerrar());
  tearDown(() => Sessao.instance.encerrar());

  testWidgets('login não exibe opção pública de criar conta', (tester) async {
    // Renderiza a tela inicial de login
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    // Garante que o botão público de criação de conta foi removido da tela de login
    expect(find.text('Criar uma conta'), findsNothing);
    // Garante que o botão de entrar continua visível normalmente
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('menu do e-mail mãe exibe Criar nova conta e abre o cadastro', (
    tester,
  ) async {
    // Autentica com o e-mail mãe autorizado (Proprietário principal)
    Sessao.instance.iniciar(
      'token-mae',
      const Usuario(
        id: 34,
        nome: 'admin',
        email: Usuario.emailMae,
        perfil: 'OWNER',
      ),
    );

    // Renderiza uma AppBar contendo o menu da conta
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [MarcaAppBar()])),
      ),
    );

    // Abre o menu dropdown clicando no avatar circular da conta
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();

    // Verifica que a opção de criar nova conta aparece no menu do e-mail mãe
    expect(find.text('Criar nova conta'), findsOneWidget);

    // Toca em "Criar nova conta" e aguarda a navegação
    await tester.tap(find.text('Criar nova conta'));
    await tester.pumpAndSettle();

    // Confirma que a tela CriarContaPage foi aberta corretamente
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
  });

  testWidgets('menu de vendedor e gerente não exibe Criar nova conta', (
    tester,
  ) async {
    // Simula sessão logada de um gerente comum
    Sessao.instance.iniciar(
      'token-gerente',
      const Usuario(
        id: 2,
        nome: 'Gerente',
        email: 'gerente@loja.com',
        perfil: 'USER',
      ),
    );

    // Renderiza a AppBar com o menu da conta
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [MarcaAppBar()])),
      ),
    );

    // Abre o menu dropdown clicando no avatar
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();

    // Confirma que a opção de criar conta fica oculta para contas que não são o e-mail mãe
    expect(find.text('Criar nova conta'), findsNothing);
    expect(find.text('Alterar nome de exibição'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('bloqueia CriarContaPage diretamente para usuário sem permissão', (
    tester,
  ) async {
    // Simula sessão logada com um e-mail comum de proprietário diferente do e-mail mãe
    Sessao.instance.iniciar(
      'token-outro',
      const Usuario(
        id: 99,
        nome: 'Outro',
        email: 'outro@loja.com',
        perfil: 'OWNER',
      ),
    );

    // Renderiza a CriarContaPage diretamente
    await tester.pumpWidget(const MaterialApp(home: CriarContaPage()));

    // Confirma que a tela exibe bloqueio de acesso restrito ao e-mail mãe
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Criar conta'), findsNothing);
  });

  testWidgets('valida campos obrigatórios antes do cadastro', (tester) async {
    // Autentica com o e-mail mãe autorizado para habilitar o formulário
    Sessao.instance.iniciar(
      'token-mae',
      const Usuario(
        id: 34,
        nome: 'admin',
        email: Usuario.emailMae,
        perfil: 'OWNER',
      ),
    );

    // Renderiza a tela de cadastro de nova conta
    await tester.pumpWidget(const MaterialApp(home: CriarContaPage()));
    final botaoCriarConta = find.widgetWithText(ElevatedButton, 'Criar conta');
    await tester.ensureVisible(botaoCriarConta);
    await tester.pumpAndSettle();

    // Toca no botão de salvar sem preencher nenhum campo
    await tester.tap(botaoCriarConta);
    await tester.pumpAndSettle();

    // Verifica todas as mensagens de validação obrigatória
    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
    expect(find.text('Confirme sua senha'), findsOneWidget);
  });
}
