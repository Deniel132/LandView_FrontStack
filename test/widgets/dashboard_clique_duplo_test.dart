// Importa utilitário assíncrono Completer para simular latência da API nos testes
import 'dart:async';
// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';
// Importa o pacote de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o modelo do calçado retornado ao abrir um produto
import 'package:parte2_flutter/models/calcado.dart';
// Importa os modelos do painel da loja (Dashboard, ResumoDashboard, ItemDashboard)
import 'package:parte2_flutter/models/dashboard.dart';
// Importa o modelo de usuário logado
import 'package:parte2_flutter/models/usuario.dart';
// Importa a tela principal do painel da loja
import 'package:parte2_flutter/screens/dashboard_page.dart';
// Importa a tela de detalhes do produto
import 'package:parte2_flutter/screens/detalhe_page.dart';
// Importa o serviço de API para injetar callbacks de teste sem tráfego real
import 'package:parte2_flutter/services/api_service.dart';
// Importa o gerenciador de sessão global
import 'package:parte2_flutter/services/sessao.dart';

void main() {
  // Limpa os callbacks simulados e a sessão após cada teste
  tearDown(() {
    ApiService.dashboardTeste = null;
    ApiService.buscarTeste = null;
    Sessao.instance.encerrar();
  });

  testWidgets(
    'cliques repetidos em Mais vendidos exibem loading e abrem detalhe uma única vez',
    (tester) async {
      // Inicia sessão simulada para renderizar o painel da loja
      Sessao.instance.iniciar(
        'token-teste',
        const Usuario(
          id: 34,
          nome: 'admin',
          email: Usuario.emailMae,
          perfil: 'OWNER',
        ),
      );

      // Configura dados simulados do painel contendo um produto em Mais vendidos
      ApiService.dashboardTeste = () async => const Dashboard(
        resumo: ResumoDashboard(
          totalModelos: 1,
          unidadesEmEstoque: 10,
          vendas30Dias: 33,
          modelosAcabando: 0,
          modelosComExcesso: 0,
          limiteEstoqueBaixo: 5,
          limiteEstoqueAlto: 40,
        ),
        maisVendidos: [
          ItemDashboard(
            id: 10,
            nome: 'Mercurial Vapor 15 Academy',
            marca: 'Nike',
            vendas: 33,
            estoque: 10,
          ),
        ],
        estoqueBaixo: [],
        estoqueAlto: [],
      );

      // Controla manualmente quando a busca de detalhes responde e conta chamadas
      final buscarCompleter = Completer<Calcado>();
      var chamadasBuscar = 0;
      ApiService.buscarTeste = (id) {
        chamadasBuscar++;
        return buscarCompleter.future;
      };

      // Renderiza o DashboardPage
      await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
      await tester.pumpAndSettle();

      // Rola até o item ficar totalmente visível dentro da janela de teste (800x600)
      final itemMaisVendido = find.text('Mercurial Vapor 15 Academy');
      await tester.scrollUntilVisible(itemMaisVendido, 200);
      await tester.pumpAndSettle();
      expect(itemMaisVendido, findsOneWidget);

      // Simula vários cliques rápidos seguidos no mesmo item
      await tester.tap(itemMaisVendido);
      await tester.pump();
      await tester.tap(itemMaisVendido, warnIfMissed: false);
      await tester.pump();
      await tester.tap(itemMaisVendido, warnIfMissed: false);
      await tester.pump();
      await tester.tap(itemMaisVendido, warnIfMissed: false);
      await tester.pump();

      // Confirma que a tela/overlay de loading foi exibida e houve apenas 1 chamada na API
      expect(find.text('Abrindo produto...'), findsOneWidget);
      expect(chamadasBuscar, equals(1));

      // Completa a resposta simulada da API com os detalhes do calçado
      buscarCompleter.complete(
        Calcado(
          id: 10,
          nome: 'Mercurial Vapor 15 Academy',
          marca: 'Nike',
          tipo: TipoCalcado.chuteira,
          forma: FormaCalcado.estreita,
          preco: 429.90,
          estoque: 10,
          tamanhos: Calcado.gerarTabelaPadrao(FormaCalcado.estreita),
        ),
      );
      await tester.pumpAndSettle();

      // Confirma que o loading sumiu e abriu exatamente uma única tela de detalhes
      expect(find.text('Abrindo produto...'), findsNothing);
      expect(find.byType(DetalhePage), findsOneWidget);
    },
  );
}

