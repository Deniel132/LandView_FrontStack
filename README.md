# Aplicativo Flutter — LandView Stock

Aplicativo Flutter para autenticação de vendedores, consulta do painel da loja,
manutenção do catálogo de tênis e chuteiras e recomendação de tamanho. A API
FastAPI persiste os dados e calcula as recomendações; o app também oferece um
modo de demonstração em memória para apresentar as telas sem backend.

Este diretório contém somente o aplicativo Flutter: não há servidor nem
implementação da API Python aqui. `lib/services/api_service.dart` é o cliente
Flutter preparado para consumir a API que será desenvolvida pelo outro grupo;
`API_CONTRATO.md` é apenas a documentação do formato combinado entre as partes.
Enquanto o backend não estiver pronto, o modo de demonstração fica ativo por
padrão e os botões usam dados locais em memória.

## Como o código está organizado

```text
lib/
├── main.dart                 # Inicialização, sessão, tema e tela de login
├── models/                   # Modelos Dart e conversão para/de JSON
├── screens/                  # Telas e fluxos de navegação
├── services/                 # Comunicação HTTP com a API
├── theme/                    # Cores, estilos e suporte aos temas
├── utils/                    # Formatação e funções reutilizadas
├── widgets/                  # Componentes visuais, logo e contato da loja
└── config/
    └── loja.dart             # Logo, Instagram, telefone e endereço

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
- **`config/loja.dart`** centraliza o nome, o endereço, o telefone, o Instagram
  e o caminho do logo para que os dados de contato possam ser alterados em um
  único lugar. O logo configurado é `assets/logo.png`.

## Fluxo principal para apresentar

1. A tela de login obtém o token JWT; as chamadas seguintes enviam esse token.
2. O painel consulta os indicadores da loja e abre o catálogo de calçados.
3. O catálogo permite pesquisar e filtrar tênis e chuteiras; o formulário de
   cadastro envia os dados e o estoque à API.
4. A tela de detalhes permite registrar uma venda informando a quantidade; o
   estoque é baixado automaticamente e o dashboard é atualizado ao voltar.
5. Também é possível editar, excluir ou iniciar uma recomendação.
6. Na recomendação, o Flutter envia o identificador do calçado e as medidas do
   pé. O backend calcula o tamanho e devolve o resultado para a tela.

Para registrar vendas reais, implemente no backend o endpoint `POST /vendas`
descrito em [API_CONTRATO.md](API_CONTRATO.md). A baixa do estoque e a gravação
da venda precisam ocorrer juntas na mesma transação. Sem esse endpoint, o
registro só funciona no modo demonstração.

No cadastro, também é possível selecionar uma foto JPG, PNG ou WebP de até
5 MB no dispositivo/navegador. Ela aparece em pré-visualização. Em modo de
demonstração, fica em memória e não exige API; com a API ativa, é enviada ao
backend, que deve guardá-la e devolver a URL usada pelo catálogo. O campo de
URL continua como alternativa. O contrato descreve o endpoint `POST /imagens`;
ele precisa existir no backend Python para a seleção de fotos ser persistida.

O logo Land View aparece na identificação do app e nas barras das telas. No
login há atalhos para o Instagram e o telefone; no fim do painel há também um
cartão de contato com Instagram, telefone e endereço. Se o dispositivo não
conseguir abrir um link, o valor correspondente é copiado e o app informa a
pessoa.

## Preparar e executar o Flutter

Na pasta `LandView_FrontStack`:

```bash
flutter pub get
```

O Flutter inicia em modo de demonstração por padrão em todas as plataformas:
as telas e os botões usam dados fictícios em memória, sem chamar uma API Python.
Execute no navegador:

```bash
flutter run -d chrome
```

No login, use qualquer e-mail válido e qualquer senha. Os dados são descartados
quando o app é fechado. Android, iOS e desktop também iniciam nesse modo.

Quando a API Python do grupo estiver pronta, desative o modo de demonstração
para conectar o Flutter Web:

```bash
flutter run -d chrome --dart-define=DEMO=false --dart-define=API_URL=http://localhost:8000
```

O repositório atual da API já expõe o login e a criação de conta em
`/api/user/login` e `/api/user/`; o Flutter usa essas rotas quando `DEMO=false`.
No cadastro, a API atual aceita e-mail e senha, sem nome. As outras telas ainda
dependem dos endpoints do contrato e podem precisar de ajustes no backend.

Para Android e outras plataformas, use o mesmo `DEMO=false`. O endereço padrão
é `http://localhost:8000`; no emulador Android é `http://10.0.2.2:8000`, que
aponta para o computador hospedeiro. Em um celular físico, use o endereço IP
local do computador, por exemplo:

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
