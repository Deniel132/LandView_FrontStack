// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';
// Importa o pacote de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o ponto de entrada do app para validar alternância de tema claro/escuro
import 'package:parte2_flutter/main.dart';
// Importa os modelos do painel da loja
import 'package:parte2_flutter/models/dashboard.dart';
// Importa o modelo de usuário para simular perfis distintos
import 'package:parte2_flutter/models/usuario.dart';
// Importa a shell de navegação responsiva com Navbar
import 'package:parte2_flutter/screens/navegacao_page.dart';
// Importa o serviço de API para injetar dados simulados sem tráfego real
import 'package:parte2_flutter/services/api_service.dart';
// Importa o gerenciador de sessão global
import 'package:parte2_flutter/services/sessao.dart';
// Importa o botão reutilizável de alternância de tema
import 'package:parte2_flutter/widgets/logo_loja.dart';

void main() {
  // Limpa sessão, mocks de API e tema após cada teste
  tearDown(() {
    ApiService.dashboardTeste = null;
    ApiService.listarTeste = null;
    ApiService.listarSaidasTeste = null;
    MyApp.themeNotifier.value = ThemeMode.light;
    Sessao.instance.encerrar();
  });

  /// Configura respostas instantâneas simuladas para todas as abas da Navbar
  void configurarMocksNavbar() {
    ApiService.dashboardTeste = () async => const Dashboard(
      resumo: ResumoDashboard(
        totalModelos: 2,
        unidadesEmEstoque: 15,
        vendas30Dias: 5,
        modelosAcabando: 0,
        modelosComExcesso: 0,
        limiteEstoqueBaixo: 5,
        limiteEstoqueAlto: 40,
      ),
      maisVendidos: [],
      estoqueBaixo: [],
      estoqueAlto: [],
    );
    ApiService.listarTeste = () async => const [];
    ApiService.listarSaidasTeste = () async => const [];
  }

  testWidgets('exibe NavigationBar inferior no celular para o Proprietário', (
    tester,
  ) async {
    // Simula resolução típica de smartphone Android
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    configurarMocksNavbar();
    Sessao.instance.iniciar(
      'token-owner',
      const Usuario(
        id: 34,
        nome: 'admin',
        email: Usuario.emailMae,
        perfil: 'OWNER',
      ),
    );

    // Renderiza a NavegacaoPage
    await tester.pumpWidget(const MaterialApp(home: NavegacaoPage()));
    await tester.pumpAndSettle();

    // Confirma que a NavigationBar inferior aparece com os 4 destinos do Proprietário
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Painel'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Provador'), findsOneWidget);
    expect(find.text('Saídas'), findsOneWidget);
    // Confirma que o botão de alternar tema claro/escuro também está presente
    expect(find.byType(BotaoAlternarTema), findsOneWidget);
  });

  testWidgets('alterna tema claro e escuro pelo BotaoAlternarTema', (
    tester,
  ) async {
    configurarMocksNavbar();
    Sessao.instance.iniciar(
      'token-tema',
      const Usuario(
        id: 1,
        nome: 'admin',
        email: Usuario.emailMae,
        perfil: 'OWNER',
      ),
    );

    // Inicia no tema claro usando a mesma configuração de tema do MyApp
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: MyApp.themeNotifier,
        builder: (_, modo, __) => MaterialApp(
          themeMode: modo,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const NavegacaoPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(MyApp.themeNotifier.value, ThemeMode.light);

    // Toca no botão de alternar tema e valida a mudança para tema escuro
    await tester.tap(find.byType(BotaoAlternarTema));
    await tester.pumpAndSettle();
    expect(MyApp.themeNotifier.value, ThemeMode.dark);

    // Toca novamente e valida o retorno para tema claro
    await tester.tap(find.byType(BotaoAlternarTema));
    await tester.pumpAndSettle();
    expect(MyApp.themeNotifier.value, ThemeMode.light);
  });

  testWidgets(
    'exibe Navbar horizontal superior no desktop e oculta Saídas para vendedor',
    (tester) async {
      // Simula resolução widescreen de computador/navegador
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      configurarMocksNavbar();
      Sessao.instance.iniciar(
        'token-seller',
        const Usuario(
          id: 5,
          nome: 'Vendedor',
          email: 'vendedor@loja.com',
          perfil: 'SELLER',
        ),
      );

      // Renderiza a NavegacaoPage em largura de desktop
      await tester.pumpWidget(const MaterialApp(home: NavegacaoPage()));
      await tester.pumpAndSettle();

      // Em desktop (>= 840px) não exibe barra inferior, mas exibe os 3 botões no topo
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Painel'), findsOneWidget);
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Provador'), findsOneWidget);
      // Vendedor não possui acesso à aba de auditoria de saídas
      expect(find.text('Saídas'), findsNothing);
    },
  );
}

