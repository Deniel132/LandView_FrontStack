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

A criação de novas contas fica restrita ao **e-mail mãe** (`admin@gmail.com`)
pelo menu da conta após o login (não há botão público na tela inicial).

| E-mail | Senha |
| --- | --- |
| `vendedor@loja.com` | `12345678` |
| `user2333@example.com` | `adm123` |

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

### Login, conta e permissões por cargo (RBAC)
- Login com verificação real de senha (senha errada é recusada com
  "E-mail ou senha incorretos"). A tela inicial exibe apenas o formulário de
  entrada (**sem criação pública de conta**).
- Criação de novas contas restrita ao **e-mail mãe (`admin@gmail.com`)**: ao
  acessar o menu do avatar no canto superior direito, aparece a opção **Criar
  nova conta**, permitindo cadastrar colaboradores em um dos **3 cargos internos
  da loja**:
  - **Vendedor(a) (`SELLER`)**: consulta o painel e o catálogo, utiliza o **Provador Virtual** e **registra vendas** (dando baixa automática no estoque).
  - **Gerente (`USER`)**: possui todas as permissões do vendedor e também pode **cadastrar novos modelos**, **editar modelos/preços** e **repor/ajustar o estoque** (inclusive pelo atalho `+5 un.` do painel e por numeração).
  - **Proprietário(a) (`OWNER`)**: acesso total irrestrito, sendo o único cargo autorizado a **excluir definitivamente modelos** do catálogo e visualizar o **Histórico de Auditoria de Saídas**.
- **Avatar da conta** no canto superior direito de todas as telas, com as
  iniciais do usuário. O menu mostra nome, cargo na loja (`Proprietário`,
  `Gerente` ou `Vendedor`), e-mail, **Alterar nome de exibição**, **Criar nova
  conta** (visível somente para o e-mail mãe `admin@gmail.com`) e **Sair**.
- Sessão expirada (401 da API) devolve o usuário automaticamente ao login.

### Navegação responsiva (Navbar)
- Barra de navegação fixa com acesso em 1 clique para **Painel**, **Catálogo**,
  **Provador** (com seletor direto de modelo) e **Saídas** (auditoria exclusiva
  do Proprietário).
- No computador (`>= 840 px`), a Navbar aparece integrada na barra superior; no
  celular Android/iOS, transforma-se automaticamente em uma `NavigationBar` fixa
  no rodapé.
- Ao tocar em qualquer modelo no **Painel**, um overlay de carregamento bloqueia
  cliques repetidos para evitar abertura duplicada de telas.

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
| `GET /dashboard/best-selling` | Lista dos 10 produtos mais vendidos (`total_sold` e `total_value`) |
| `GET /product/all` | Listagem completa de todos os produtos cadastrados na API |
| `GET /product/` | Busca paginada e filtrada de produtos (`page`, `page_size`, `name`, `active`, etc.) |
| `POST /product/` | Criação de produto com estoque inicial (`stock_item_dto`) e lista de fotos em Base64 (`images`) |
| `POST /images/product/{product_id}` | Cadastro de uma ou mais imagens em Base64 no bucket `product-images` |
| `GET /images/product/{product_id}/all` | Listagem de todas as imagens vinculadas a um produto |
| `GET /images/product/{product_id}` | Busca filtrada de imagens de um produto (`image_id`, `image_name`) |
| `DELETE /images/product/{product_id}/{image_id}` | Exclusão de imagem do bucket e da tabela `image` |
| `POST /stock-exit/` | Registro de saída / baixa de estoque por usuário |
| `GET /stock-exit/` | Histórico paginado de saídas de estoque (auditoria) |
| `GET/PUT/DELETE /product/{product_id}` | Consulta por ID, edição e exclusão de produtos |
| `GET/POST/PUT/DELETE /category/...` | Consulta, criação, alteração e exclusão de marcas/categorias |
| `GET/POST/PUT/DELETE /stock/...` | Estoque: criação, consulta, baixa de venda e ajuste |

### Banco Supabase (complementar)

A API fornece a listagem de produtos (`GET /product/all`), busca filtrada (`GET /product/`) e o ranking dos mais vendidos (`GET /dashboard/best-selling`). O app complementa com o Supabase da própria LandView_API para ler e gravar os metadados ricos de calçado (foto, forma anatômica e grade de medidas por tamanho):

| Tabela / função | Uso |
| --- | --- |
| `product`, `product_category`, `stock_product` | Listagem do catálogo e do painel |
| `stock_exit_register` | Contagem real de saídas/vendas por produto e auditoria |
| `stock_product.characteristics` | Forma do calçado (`estreita`, `padrao`, `larga`) |
| `stock_product.sub_characteristics` | JSON com tamanhos + estoque por tamanho e foto (`imagem_url`) |
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
│   ├── navegacao_page.dart       # Navbar responsiva (Painel, Catálogo, Provador, Saídas)
│   ├── criar_conta_page.dart     # Cadastro de conta (exclusivo do e-mail mãe)
│   ├── dashboard_page.dart       # Painel da loja
│   ├── catalogo_page.dart        # Catálogo, filtros e ordenação
│   ├── detalhe_page.dart         # Detalhe, venda, estoque por tamanho
│   ├── cadastro_page.dart        # Cadastro/edição de modelo e grade
│   ├── recomendacao_page.dart    # Provador (com ou sem calçado prévio)
│   └── saidas_page.dart          # Auditoria de saídas de estoque (Proprietário)
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
    ├── estados.dart              # Carregando, overlay, erro, vazio e avisos
    ├── logo_loja.dart            # Logo e avatar da conta (MarcaAppBar)
    └── pilula.dart               # Etiquetas de status

test/
├── fluxo_daniel_test.dart               # Teste ponta a ponta (cadastro, login, produto, venda e auditoria)
├── provador_estimativa_test.dart        # Estimativa do pé pela numeração habitual
├── validacao_venda_estoque_test.dart    # Validação de baixa por numeração e persistência no banco
├── seguranca_test.dart                  # Testes de segurança (criptografia, RBAC, sessão, sanitização e login)
├── models/api_models_test.dart          # Conversão de JSON e regras de negócio de modelos
└── widgets/
    ├── contato_loja_test.dart           # Asset do logo e rodapé
    ├── criar_conta_page_test.dart       # Restrição do e-mail mãe e validação de cadastro
    ├── dashboard_clique_duplo_test.dart # Bloqueio de cliques múltiplos e loading ao abrir produto
    ├── detalhe_venda_test.dart          # Fluxo de venda e baixa de estoque na tela de detalhe
    └── navegacao_navbar_test.dart       # Comportamento responsivo da Navbar (desktop/celular)
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
