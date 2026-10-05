# Aplicativo Flutter — Provador Virtual

Aplicativo para consultar um catálogo de tênis e chuteiras, manter os modelos
cadastrados e solicitar uma recomendação de tamanho. A interface Flutter é o
cliente; a futura API em Python será responsável por persistir o catálogo e
calcular a recomendação.

## Como o código está organizado

```text
lib/
├── main.dart                 # Inicialização, tema e tela inicial
├── models/                   # Modelos Dart e conversão para/de JSON
├── screens/                  # Telas e fluxos de navegação
├── services/                 # Comunicação HTTP com a API
├── theme/                    # Cores, estilos e suporte aos temas
├── utils/                    # Formatação e funções reutilizadas
└── widgets/                  # Componentes visuais reutilizados

API_CONTRATO.md               # Rotas e formato JSON que o backend deve atender
```

### Responsabilidade de cada parte

- **`models/`** define `Calcado`, suas medidas e o resultado da recomendação.
  Os métodos `fromJson` e `toJson` fazem a conversão entre os objetos Dart e o
  contrato HTTP.
- **`screens/`** contém as telas de catálogo, cadastro/edição, detalhes e
  recomendação. As telas cuidam da interação e da validação visual, não do
  cálculo de tamanho.
- **`services/api_service.dart`** é o único ponto que monta URLs e envia
  requisições. Também traduz erros de conexão e respostas HTTP para mensagens
  que a interface consegue exibir. O envio de foto é multipart e separado do
  JSON do calçado.
- **`theme/`, `utils/` e `widgets/`** concentram, respectivamente, a aparência,
  formatação e componentes reaproveitáveis.

## Fluxo principal para apresentar

1. A tela inicial pede a lista à API, mostra o estado da conexão e permite
   pesquisar ou filtrar tênis e chuteiras.
2. O formulário de cadastro monta um `Calcado` e envia os dados à API.
3. A tela de detalhes mostra o modelo e sua tabela de medidas; nela é possível
   editar, excluir ou iniciar uma recomendação.
4. Na recomendação, o Flutter envia o identificador do calçado e as medidas do
   pé. O backend calcula o tamanho e devolve o resultado para a tela.

No cadastro, também é possível selecionar uma foto JPG, PNG ou WebP de até
5 MB no dispositivo/navegador. Ela aparece em pré-visualização e, ao salvar,
é enviada à API, que deve guardá-la e devolver a URL usada pelo catálogo. O
campo de URL continua como alternativa. O contrato descreve o endpoint
`POST /imagens`; ele precisa existir no backend Python para a seleção de fotos
ser persistida.

## Preparar e executar o Flutter

Na pasta `parte2-flutter`:

```bash
flutter pub get
flutter run -d chrome
```

O app assume que a API estará em `http://localhost:8000` no navegador. Para
usar outro endereço, passe `API_URL`:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

No emulador Android, o endereço padrão é `http://10.0.2.2:8000`, que aponta
para o computador hospedeiro. Em um celular físico, use o endereço IP local
do computador, por exemplo:

```bash
flutter run --dart-define=API_URL=http://192.168.0.10:8000
```

## Quando a API Python for criada

O backend deve ficar em uma pasta independente do app Flutter (por exemplo,
`api-python/` na raiz do projeto). Assim, cada parte mantém suas dependências e
comandos próprios. O contrato em [API_CONTRATO.md](API_CONTRATO.md) define os
endpoints, os campos JSON, o upload multipart de fotos, as mensagens de erro e
o comportamento esperado.

Antes de alterar um campo ou rota, atualize o contrato e coordene a mudança
com `lib/models/` e `lib/services/api_service.dart`. Para Flutter Web, habilite
CORS no backend e restrinja as origens ao ambiente necessário quando sair do
desenvolvimento.
