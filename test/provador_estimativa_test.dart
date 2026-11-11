// Importa o pacote de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o serviço da API onde fica a estimativa de medida do pé
import 'package:parte2_flutter/services/api_service.dart';

void main() {
  // Agrupa os testes da estimativa usada quando o cliente não sabe a medida do pé
  group('Provador Virtual - estimativa pela numeração habitual', () {
    test('Numeração 37 estima pé de 24 cm (palmilha 25 cm - folga 1 cm)', () {
      // Confere o ponto de partida da grade de referência
      expect(ApiService.estimarMedidaPe(37), 24.0);
    });

    test('Numeração 41 estima pé de aproximadamente 26,7 cm', () {
      // 25,0 + 4 x 0,667 = 27,67 cm de palmilha, menos 1 cm de folga
      expect(ApiService.estimarMedidaPe(41), 26.7);
    });

    test('Numerações maiores sempre estimam pés maiores', () {
      // Garante que a estimativa cresce junto com a numeração
      expect(
        ApiService.estimarMedidaPe(42),
        greaterThan(ApiService.estimarMedidaPe(41)),
      );
    });
  });
}

