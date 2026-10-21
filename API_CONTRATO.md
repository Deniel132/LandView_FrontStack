# Contrato da API — Provador Virtual (Automatize)

O que o **app Flutter espera** da API FastAPI. Se o backend mudar algo aqui, avisar quem faz o app
(ou ajustar `lib/models/` e `lib/services/api_service.dart`).

- Base URL local: `http://localhost:8000`
- Formato: JSON (UTF-8)
- **Sem barra no final** das rotas do contrato original (`/calcados`, não `/calcados/`).
- Na API atual, `/api/user/login` e `/api/user/` são rotas públicas.

## Autenticação — integração atual com `LandView_API`

O app foi adaptado ao repositório público atual: login em
`POST /api/user/login` com `email` e `password`, e criação de conta em
`POST /api/user/` com `email`, `password` e `role: "USER"`. O login retorna
uma string JSON contendo o token, e o cadastro aceita apenas e-mail e senha,
por isso a tela não pede nome. O Flutter retorna ao login após criar a conta.

O backend atual usa um token próprio sem expiração, não JWT, e não retorna os
dados completos do usuário no login. Ele já usa bcrypt para as senhas. O enum
do backend aceita o perfil `USER`.

No backend consultado, credenciais incorretas e e-mail duplicado lançam
`ValueError`, que pode virar erro `500` no FastAPI; o ideal é responder `401`
no login e `409` (ou `400`) no cadastro, ambos com `detail` em português.
Para Flutter Web, a origem CORS configurada no backend também precisa incluir a
origem local usada pelo navegador; `http://localhost:8000` não é a origem da
interface Flutter Web.

O restante desta seção descreve o contrato originalmente combinado, que ainda
não corresponde à implementação atual do backend.

### POST `/auth/login`

Pedido:

```json
{ "email": "vendedor@loja.com", "senha": "minha-senha" }
```

Resposta `200`:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "usuario": { "id": 1, "nome": "Maria Souza", "email": "vendedor@loja.com" }
}
```

Credenciais erradas: `401` com `{ "detail": "E-mail ou senha incorretos." }` (a mensagem aparece na tela de login).

### Rotas protegidas

O app envia `Authorization: Bearer <access_token>` em todas as outras rotas.
Token ausente, inválido ou vencido: `401` com `{ "detail": "Token inválido ou expirado." }`.
Ao receber 401 em rota protegida, o app **volta sozinho para a tela de login**.

Requisitos do enunciado: senhas salvas com **bcrypt** e token com expiração. O app não tem tela de
cadastro de usuário: crie as contas por script de seed ou pelo Swagger (`/docs`).

## Objeto `Calcado`

```json
{
  "id": 3,
  "nome": "Air Zoom Pegasus 40",
  "marca": "Nike",
  "tipo": "tenis",
  "forma": "padrao",
  "preco": 799.9,
  "estoque": 4,
  "imagem_url": null,
  "tamanhos": [
    { "numeracao": 40, "comprimento_cm": 26.9 },
    { "numeracao": 41, "comprimento_cm": 27.6 },
    { "numeracao": 42, "comprimento_cm": 28.2 }
  ]
}
```

| Campo | Tipo | Regras |
|---|---|---|
| `id` | int | gerado pelo banco; não vem no POST/PUT |
| `nome` | string | obrigatório |
| `marca` | string | obrigatório |
| `tipo` | string | `"tenis"` ou `"chuteira"` (sem acento) |
| `forma` | string | `"estreita"`, `"padrao"` ou `"larga"` (sem acento) |
| `preco` | number | maior que 0 |
| `estoque` | int | unidades disponíveis; 0 ou mais (se ausente, o app assume 0) |
| `imagem_url` | string ou null | opcional |
| `tamanhos` | lista | pelo menos 1 item; `numeracao` aceita decimal (41.5) |

`comprimento_cm` é o **comprimento interno** do calçado naquela numeração, em centímetros.
Deve crescer junto com a numeração.

## Endpoints do CRUD

| Método | Rota | Corpo | Resposta de sucesso |
|---|---|---|---|
| GET | `/calcados` | — | `200` lista de `Calcado` |
| GET | `/calcados/{id}` | — | `200` `Calcado` |
| POST | `/calcados` | `Calcado` sem `id` | `201` `Calcado` com `id` |
| PUT | `/calcados/{id}` | `Calcado` sem `id` | `200` `Calcado` atualizado |
| DELETE | `/calcados/{id}` | — | `204` (ou `200`) |
| POST | `/vendas` | `calcado_id`, `quantidade` | `201` registro da venda |

### POST `/vendas` — registrar venda e baixar estoque

O app envia o ID do calçado que está aberto na tela de detalhes e a quantidade
confirmada pelo vendedor. A API deve, em uma única transação, conferir o estoque,
criar o registro da venda e subtrair a quantidade do estoque. Assim a venda fica
associada ao produto correto e também alimenta `mais_vendidos` e `vendas_30_dias`
do dashboard. Não usar o endpoint de edição do catálogo para registrar vendas.

Pedido:

```json
{
  "calcado_id": 3,
  "quantidade": 2
}
```

Resposta `201`:

```json
{
  "id": 42,
  "calcado_id": 3,
  "quantidade": 2,
  "estoque_atual": 2,
  "data_venda": "2026-10-06T20:00:00Z"
}
```

A API deve rejeitar quantidade menor que 1 ou maior que o estoque disponível.
Para estoque insuficiente, retornar `400` com `detail` claro; para calçado
inexistente, `404`. A baixa do estoque precisa ser atômica para impedir que duas
vendas concorrentes deixem o estoque negativo. A rota exige autenticação JWT.

### POST `/imagens`

O cadastro pode enviar uma foto separadamente do JSON do calçado. A rota recebe
`multipart/form-data` no campo `arquivo` e responde com `{ "imagem_url": "..." }`.
O Flutter limita a seleção a JPG, PNG ou WebP de até 5 MB; o backend também deve
validar o conteúdo e o tamanho e servir a imagem em uma URL persistente.
Caminhos relativos são resolvidos com a URL base da API.

## Dashboard

### GET `/dashboard`

Alimenta a tela inicial do app. O cálculo é todo do backend; o app só exibe.

```json
{
  "resumo": {
    "total_modelos": 8,
    "unidades_em_estoque": 186,
    "vendas_30_dias": 85,
    "modelos_acabando": 2,
    "modelos_com_excesso": 2,
    "limite_estoque_baixo": 5,
    "limite_estoque_alto": 40
  },
  "mais_vendidos": [
    { "id": 3, "nome": "Air Zoom Pegasus 40", "marca": "Nike", "vendas": 19, "estoque": 4 }
  ],
  "estoque_baixo": [
    { "id": 5, "nome": "Wave Rider 27", "marca": "Mizuno", "vendas": 16, "estoque": 2 }
  ],
  "estoque_alto": [
    { "id": 6, "nome": "Ultraboost Light", "marca": "Adidas", "vendas": 5, "estoque": 55 }
  ]
}
```

Regras sugeridas (o app mostra os limites que a API devolver em `resumo`):

- `mais_vendidos`: os 5 modelos com mais vendas nos últimos 30 dias, do maior para o menor.
- `estoque_baixo`: modelos com `estoque <= limite_estoque_baixo`, do menor estoque para o maior.
- `estoque_alto`: modelos com `estoque >= limite_estoque_alto`, do maior estoque para o menor.
- `vendas` em cada item = unidades vendidas nos últimos 30 dias.

Para o dashboard refletir as vendas reais, o backend precisa persistir cada
registro recebido em `POST /vendas` e calcular os totais dos últimos 30 dias a
partir desses registros. O modo de demonstração do Flutter simula essas baixas
e vendas em memória; os dados somem ao fechar o app.

## Recomendação de tamanho

### POST `/recomendacoes`

Pedido:

```json
{
  "calcado_id": 3,
  "medida_pe_cm": 26.5,
  "numeracao_habitual": 41,
  "marca_habitual": "Adidas"
}
```

`numeracao_habitual` e `marca_habitual` são opcionais (o app omite quando vazios).

Resposta:

```json
{
  "tamanho_recomendado": 41,
  "alternativa": 42,
  "folga_cm": 1.1,
  "observacao": null
}
```

`alternativa`, `folga_cm` e `observacao` podem vir `null`/ausentes. O app mostra
`tamanho_recomendado` em destaque e o resto como apoio.

## Erros

O app lê o campo `detail` e mostra a mensagem direto na tela, então ela deve estar em português e
ser clara. Padrão:

```json
{ "detail": "Calçado não encontrado." }
```

| Situação | Status |
|---|---|
| credenciais erradas no login | `401` |
| token ausente, inválido ou vencido | `401` |
| id inexistente (GET/PUT/DELETE/recomendação) | `404` |
| corpo inválido | `422` (formato padrão do Pydantic ou `detail` em texto; o app trata os dois) |
| regra de negócio violada | `400` com `detail` em texto claro |

## CORS (só se o app rodar como Flutter Web)

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # em desenvolvimento
    allow_methods=["*"],
    allow_headers=["*"],   # inclui Authorization
)
```

Para celular físico ou emulador, subir o servidor com `uvicorn app.main:app --host 0.0.0.0 --port 8000`.

## Testes rápidos (curl)

```bash
# login (guarde o access_token)
curl -X POST http://localhost:8000/auth/login -H "Content-Type: application/json" \
  -d '{"email":"vendedor@loja.com","senha":"minha-senha"}'

# listar (com token)
curl http://localhost:8000/calcados -H "Authorization: Bearer SEU_TOKEN"

# dashboard
curl http://localhost:8000/dashboard -H "Authorization: Bearer SEU_TOKEN"

# recomendar
curl -X POST http://localhost:8000/recomendacoes \
  -H "Content-Type: application/json" -H "Authorization: Bearer SEU_TOKEN" \
  -d '{"calcado_id":3,"medida_pe_cm":26.5,"numeracao_habitual":41}'
```
