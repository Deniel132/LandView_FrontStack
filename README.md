# LandView Stock — Controle de Estoque (Flutter)

Sistema interno de **controle de estoque** da Land View Artigos Esportivos,
feito em Flutter. Ele é usado pela equipe da loja para gerenciar tênis e
chuteiras: cadastro de modelos, estoque por numeração, baixa de vendas,
reposição, indicadores do painel e recomendação de tamanho (provador).

O app é integrado à API **LandView_API** publicada no Render
(`https://landview-api.onrender.com`, repositório
[Deniel132/LandView_API](https://github.com/Deniel132/LandView_API)) e ao banco
Supabase usado por essa API. **Nenhuma alteração no backend é necessária** para
os recursos descritos aqui.

---

## Sumário

1. [Como executar](#como-executar)
2. [Modos de execução](#modos-de-execução)
3. [Funcionalidades](#funcionalidades)
4. [Estoque por tamanho](#estoque-por-tamanho)
5. [Segurança do login](#segurança-do-login)
6. [Integração com o backend](#integração-com-o-backend)
7. [Organização do código](#organização-do-código)
8. [Testes e análise](#testes-e-análise)
9. [Problemas comuns](#problemas-comuns)

---

## Como executar

Pré-requisitos: Flutter SDK (Dart `^3.8.1`) e Google Chrome.

Na pasta `parte2-flutter`:

```bash
flutter pub get
flutter run -d chrome --web-port=8000
```

> **Por que `--web-port=8000`?** O CORS da API no Render libera a origem
> `http://localhost:8000`. Rodando o Flutter Web nessa porta, o navegador aceita
> as respostas da API.

> **Atenção:** se a API Python local (`uvicorn`) também estiver rodando, ela
> ocupa a porta 8000 e o Flutter falha com
> `Failed to bind web development server ... port = 8000`. Nesse caso, pare o
> uvicorn ou rode o Flutter em outra porta (ex.: `--web-port=8080`). Veja
> [Problemas comuns](#problemas-comuns).

### Contas para login

| E-mail | Senha |
| --- | --- |
| `vendedor@loja.com` | `12345678` |
| `user2333@example.com` | `adm123` |

Também é possível criar uma conta nova pela tela **"Criar uma conta"**.

---

## Modos de execução

| Modo | Como ativar | O que acontece |
| --- | --- | --- |
| **Integrado (padrão)** | `flutter run -d chrome --web-port=8000` | Usa a API do Render + banco Supabase. Os dados são reais e compartilhados. |
| **API local** | `--dart-define=API_URL=http://localhost:8000` | Aponta para outra instância da API (o sufixo `/docs` é removido automaticamente). |

Se a chamada ao Render falhar por rede ou CORS, o
[`ApiService`](lib/services/api_service.dart) tenta automaticamente a API local
em `http://127.0.0.1:8000`.

> O Render no plano gratuito "dorme" quando fica parado. A primeira requisição
> pode demorar até ~1 minuto; o tempo limite das chamadas é de 35 s.

---

## Funcionalidades

### Login e conta
- Login com verificação real de senha (senha errada é recusada com
  "E-mail ou senha incorretos").
- Criação de conta pela tela **Criar uma conta**.
- **Avatar da conta** no canto superior direito de todas as telas, com as
  iniciais do usuário. O menu mostra nome, cargo na loja (`Proprietário`,
  `Gerente` ou `Vendedor`), e-mail, **Alterar nome de exibição** e **Sair**.
- Sessão expirada (401 da API) devolve o usuário automaticamente ao login.

### Painel da loja (dashboard)
- Saudação com o nome do usuário e data.
- Indicadores: modelos cadastrados, unidades em estoque, vendas dos últimos
  30 dias, modelos acabando e modelos em excesso.
- Listas **Mais vendidos**, **Estoque acabando** (até 5 un.) e
  **Estoque em excesso** (40 un. ou mais).
- Botão **+5 un.** em cada item de estoque acabando para repor sem sair do painel.
- Botão **Copiar resumo do painel** (texto pronto para colar no WhatsApp ou e-mail).

### Catálogo e estoque
- Busca por modelo ou marca e filtro por tipo (Tênis / Chuteiras).
- Filtros de situação: **Todos**, **Estoque baixo**, **Esgotados**, **Em excesso**.
- Ordenação: relevância, nome (A–Z), menor/maior estoque, menor/maior preço.
- Cabeçalho com total de modelos, unidades e **valor total em estoque**.
- Cada card mostra preço, faixa de numeração e cobertura da grade
  (ex.: `nº 37 a 45 (8/9 tam.)`).

### Detalhe do modelo
- Status do estoque: `Esgotado`, `Estoque baixo`, `Estoque elevado` ou `Disponível`.
- Ficha com preço, forma, estoque total, valor em estoque, **cobertura da grade**
  e **numerações esgotadas**.
- **Estoque por tamanho**: toque em uma numeração para ajustar só ela
  (veja a seção abaixo).
- **Registrar venda** escolhendo a numeração e a quantidade (atalhos
  1/2/3/5 un.), com o total da venda.
- **Ajustar estoque** total (−1, +1, +5, +10, zerar ou valor exato).
- **Copiar ficha de estoque**: estoque por tamanho e lista do que repor.
- Editar e excluir modelo.

### Cadastro / edição de modelo
- Nome, marca, preço, tipo, forma (estreita / padrão / larga) e foto
  (link ou arquivo do computador, até 5 MB).
- Tabela de medidas com **estoque por numeração**.
- **Preencher grade 37–45**: gera a grade padrão com as medidas em cm
  calculadas pela forma e distribui o estoque informado entre os tamanhos.
- **Limpar tabela** e edição/remoção individual de cada tamanho.

### Provador (recomendação de tamanho)
- Informa a medida do pé em cm (com atalhos de 24,5 a 28,5 cm), a numeração
  habitual e a marca habitual do cliente (opcionais).
- Mostra o tamanho recomendado, a alternativa, a folga em cm e a posição na
  grade do modelo.
- **Copiar recomendação** para enviar ao cliente.

### Interface
- Tema claro e escuro (botão no topo).
- Layout responsivo, com largura máxima para monitores grandes.
- Rodapé discreto: `LandView Stock · Sistema Interno de Controle de Estoque`.

---

## Estoque por tamanho

A API guarda **um estoque total por produto** (`stock.quantity`). Para ter
estoque por numeração sem mudar o backend, o app salva a quantidade de cada
tamanho junto com a tabela de medidas, nos metadados do estoque
(`stock_product.sub_characteristics`):

```json
{
  "tamanhos": [
    { "numeracao": 40, "comprimento_cm": 26.5, "estoque": 3 },
    { "numeracao": 41, "comprimento_cm": 27.2, "estoque": 0 }
  ],
  "imagem_url": "...",
  "vendas_30_dias": 12
}
```

Regras (em [`calcado.dart`](lib/models/calcado.dart)):

- O **estoque total** continua sendo a fonte oficial (`stock.quantity`) e é
  sempre igual à soma dos tamanhos.
- Modelos antigos, sem estoque por tamanho, têm o total **distribuído
  igualmente** entre as numerações até alguém ajustar manualmente.
- Ajustar um tamanho recalcula o total e atualiza a API
  (`atualizarEstoqueDoTamanho`).
- A venda desconta da numeração escolhida; se ela não tiver unidades
  suficientes, o restante sai das outras numerações (`descontarDoTamanho`).
- Ajustar o estoque total redistribui a diferença entre os tamanhos.

---

## Segurança do login

- A senha **não trafega em texto puro**: antes do envio, o app a transforma no
  formato `enc:v1:<hex>`
  ([`criptografia_senha.dart`](lib/utils/criptografia_senha.dart)). Na aba
  *Network* do DevTools aparece só o valor cifrado.
- O backend reverte esse formato (`PasswordUtils.decrypt_client_password`) e
  compara com o **hash bcrypt** salvo no banco.
- Se a rota de login do Render falhar com erro interno, o app valida pela
  função `verificar_login` do banco, que também confere o bcrypt. Senha errada
  é sempre recusada.

> [!NOTE]
> O `enc:v1` serve para esconder a senha no DevTools. A proteção do transporte
> continua sendo o HTTPS do Render. A chave fica no código do frontend, então
> isso não substitui o HTTPS.

---

## Integração com o backend

### Rotas da API no Render

| Rota | Uso no app |
| --- | --- |
| `POST /api/user/login` | Login (senha `enc:v1`) e geração do token de acesso |
| `POST /api/user/` | Criação de conta com perfil (`SELLER`, `OWNER`, `USER`) |
| `GET /api/user/{user_id}` | Consulta de dados do usuário por ID |
| `GET /dashboard/` | Destaques da API: produtos com menor (`lowest_stock`) e maior (`highest_stock`) estoque |
| `POST /stock-exit/` | Registro de saída / baixa de estoque por usuário |
| `GET /stock-exit/` | Histórico paginado de saídas de estoque (auditoria) |
| `GET/POST/PUT/DELETE /product/...` | Consulta, criação, edição e exclusão de produtos |
| `GET/POST/PUT/DELETE /category/...` | Consulta, criação, alteração e exclusão de marcas/categorias |
| `GET/POST/PUT/DELETE /stock/...` | Estoque: criação, consulta, baixa de venda e ajuste |

### Banco Supabase (complementar)

A API não tem rota de **listagem** de produtos/estoque nem campos para foto,
forma e tabela de medidas. Por isso o app lê e complementa direto no Supabase da
própria LandView_API:

| Tabela / função | Uso |
| --- | --- |
| `product`, `product_category`, `stock_product` | Listagem do catálogo e do painel |
| `stock_product.characteristics` | Forma do calçado (`estreita`, `padrao`, `larga`) |
| `stock_product.sub_characteristics` | JSON com tamanhos + estoque por tamanho, foto e vendas de 30 dias |
| `rpc/verificar_login` | Validação bcrypt de reserva no login |
| `rpc/criar_usuario_hash` | Criação de conta com hash bcrypt |

### Como os dados do app viram dados da API

| App (`Calcado`) | Backend |
| --- | --- |
| `nome`, `preco` | `product.product_name`, `product.unit_value` |
| `marca`, `tipo` | `product_category.category_name`, `category_type` |
| `estoque` (total) | `stock_product.quantity` |
| `forma` | `stock_product.characteristics` |
| `tamanhos`, `imagemUrl`, vendas | `stock_product.sub_characteristics` (JSON) |

Os indicadores do painel (mais vendidos, acabando, excesso) são calculados no
app a partir desses dados. O contrato detalhado está em
[`API_CONTRATO.md`](API_CONTRATO.md).

---

## Organização do código

```text
lib/
├── main.dart                     # Inicialização, tema claro/escuro, sessão expirada
├── config/
│   └── loja.dart                 # Nome da loja e caminho do logo
├── models/
│   ├── calcado.dart              # Calçado, tabela de medidas e estoque por tamanho
│   ├── dashboard.dart            # Resumo, listas do painel e extremos da API
│   ├── recomendacao.dart         # Resultado do provador
│   ├── saida_estoque.dart        # Registro de saída de estoque (GET /stock-exit/)
│   ├── usuario.dart              # Usuário logado e perfil (SELLER, OWNER, USER)
│   └── venda.dart                # Venda registrada
├── screens/
│   ├── login_page.dart           # Login
│   ├── criar_conta_page.dart     # Cadastro de conta
│   ├── dashboard_page.dart       # Painel da loja e auditoria de saídas
│   ├── catalogo_page.dart        # Catálogo, filtros e ordenação
│   ├── detalhe_page.dart         # Detalhe, venda, estoque por tamanho
│   ├── cadastro_page.dart        # Cadastro/edição de modelo e grade
│   └── recomendacao_page.dart    # Provador
├── services/
│   ├── api_service.dart          # Única porta de rede (Render + Supabase)
│   ├── api_exception.dart        # Erro padronizado da API
│   └── sessao.dart               # Token, usuário logado e cache local de grades
├── theme/
│   └── app_theme.dart            # Cores, tipografia e temas
├── utils/
│   ├── criptografia_senha.dart   # Formato enc:v1 da senha
│   └── formato.dart              # Moeda, numeração, cm e leitura de números
└── widgets/
    ├── cartao_calcado.dart       # Card do catálogo
    ├── contato_loja.dart         # Rodapé do sistema
    ├── estados.dart              # Carregando, erro, vazio e avisos
    ├── logo_loja.dart            # Logo e avatar da conta (MarcaAppBar)
    └── pilula.dart               # Etiquetas de status

test/
├── fluxo_daniel_test.dart               # Teste ponta a ponta (cadastro, login, produto, venda e auditoria)
├── validacao_venda_estoque_test.dart    # Validação de baixa por numeração e persistência no banco
├── seguranca_test.dart                  # Testes de segurança (criptografia, RBAC, sessão, sanitização e login)
├── models/api_models_test.dart          # Conversão de JSON e regras de negócio de modelos
└── widgets/
    ├── contato_loja_test.dart           # Asset do logo e rodapé
    ├── criar_conta_page_test.dart       # Tela de criar conta
    └── detalhe_venda_test.dart          # Fluxo de venda e baixa de estoque na tela de detalhe
```

Dependências principais: `http` (rede), `shared_preferences` (persistência local de sessão e preferências), `file_selector` (foto do computador) e `url_launcher`.

---

## Testes e análise

```bash
flutter analyze
flutter test
```

A suíte conta com testes unitários de modelos, testes de widgets e testes de integração ponta a ponta validando o fluxo real de cadastro, autenticação, estoque e auditoria de saídas.

---

## Problemas comuns

| Sintoma | Causa provável | Solução |
| --- | --- | --- |
| `Failed to bind web development server ... port = 8000` | A API Python local (uvicorn) já usa a porta 8000 | Pare o uvicorn (`Ctrl+C`) ou use `--web-port=8080` |
| Erro de CORS / "Não foi possível conectar à API" | Flutter rodando em porta diferente da liberada no Render | Rode com `--web-port=8000`, ou suba a API local e use `--dart-define=API_URL=http://localhost:8000` |
| Primeira tela demora muito | Render "acordando" | Aguarde ~1 minuto e clique em atualizar |
| "E-mail ou senha incorretos" com dados certos | Conta criada em outro banco ou senha antiga | Crie a conta de novo pela tela **Criar uma conta** |
| Nada aparece no catálogo | Banco sem produtos | Cadastre um modelo em **Novo modelo** |
