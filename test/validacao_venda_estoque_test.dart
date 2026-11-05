// Importa a biblioteca de testes de widgets e lógica do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o modelo principal de Calçado e MedidaTamanho
import 'package:parte2_flutter/models/calcado.dart';
// Importa o gerenciador de sessão e persistência
import 'package:parte2_flutter/services/sessao.dart';
// Importa suporte ao SharedPreferences com mock em memória para testes
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Garante a inicialização das bindings do Flutter para uso nos testes
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validação da Baixa de Estoque e Seleção de Quantidade', () {
    setUp(() {
      // Configura valores iniciais mockados no SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('1. descontarDoTamanho baixa com exatidão a quantidade vendida na numeração específica', () {
      // Cria uma grade com numerações 37, 38 e 39 com quantidades pré-definidas
      final gradeInicial = [
        const MedidaTamanho(numeracao: 37, comprimentoCm: 25.0, estoque: 5),
        const MedidaTamanho(numeracao: 38, comprimentoCm: 25.7, estoque: 8),
        const MedidaTamanho(numeracao: 39, comprimentoCm: 26.3, estoque: 7),
      ];

      // Instancia o calçado com total 20 (5 + 8 + 7)
      final calcado = Calcado(
        id: 99,
        nome: 'Tênis Teste Estoque',
        marca: 'Nike',
        tipo: TipoCalcado.tenis,
        forma: FormaCalcado.padrao,
        preco: 200.0,
        estoque: 20,
        tamanhos: gradeInicial,
      );

      // Simula uma venda de 3 unidades especificamente no tamanho 38
      final atualizado = calcado.descontarDoTamanho(38.0, 3);

      // O estoque total deve ter baixado de 20 para 17 (20 - 3 = 17)
      expect(atualizado.estoque, equals(17));

      // Localiza o tamanho 38 na nova grade
      final tam38 = atualizado.tamanhosComEstoque.firstWhere((t) => t.numeracao == 38.0);
      // O tamanho 38 deve ter baixado de 8 para exatamente 5 (8 - 3 = 5, não apenas 1)
      expect(tam38.estoque, equals(5));

      // Os outros tamanhos devem permanecer inalterados
      final tam37 = atualizado.tamanhosComEstoque.firstWhere((t) => t.numeracao == 37.0);
      expect(tam37.estoque, equals(5));
      final tam39 = atualizado.tamanhosComEstoque.firstWhere((t) => t.numeracao == 39.0);
      expect(tam39.estoque, equals(7));
    });

    test('2. Persistência da grade no SharedPreferences salva e restaura os tamanhos individuais', () async {
      // Define uma grade personalizada
      final gradeOriginal = [
        const MedidaTamanho(numeracao: 37, comprimentoCm: 25.0, estoque: 2),
        const MedidaTamanho(numeracao: 38, comprimentoCm: 25.7, estoque: 8),
      ];

      // Salva a grade no SharedPreferences para o calçado ID 100
      await Sessao.salvarGradeTamanhos(100, gradeOriginal);

      // Recupera a grade salva
      final gradeRecuperada = await Sessao.obterGradeTamanhos(100);

      // Valida que a grade recuperada não é nula
      expect(gradeRecuperada, isNotNull);
      // Valida que a quantidade de tamanhos é a mesma
      expect(gradeRecuperada!.length, equals(2));
      // Valida que o tamanho 38 preservou as 8 unidades
      expect(gradeRecuperada.firstWhere((t) => t.numeracao == 38.0).estoque, equals(8));
      // Valida que o tamanho 37 preservou as 2 unidades
      expect(gradeRecuperada.firstWhere((t) => t.numeracao == 37.0).estoque, equals(2));
    });
  });
}

