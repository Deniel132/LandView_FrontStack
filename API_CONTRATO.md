# Contrato da API — Provador Virtual (Automatize)

Este documento descreve o que o **app Flutter espera** da API FastAPI.
Se o backend mudar algo aqui, avisar quem faz o app (ou ajustar `lib/models/` e `lib/services/api_service.dart`).

- Base URL local: `http://localhost:8000`
- Formato: JSON (UTF-8)
- **Sem barra no final** das rotas (`/calcados`, não `/calcados/`). Com barra o FastAPI responde 307 e o POST/PUT pode falhar no app.
- Recurso do CRUD: **Calçado** (modelo de tênis/chuteira da loja). Não é recurso "usuário", então não exige JWT.

## Objeto `Calcado`

```json
{
  "id": 1,
  "nome": "Mercurial Vapor 15",
  "marca": "Nike",
  "tipo": "chuteira",
  "forma": "estreita",
  "preco": 899.9,
  "imagem_url": "https://exemplo.com/foto.jpg",
  "tamanhos": [
    { "numeracao": 40, "comprimento_cm": 25.6 },
    { "numeracao": 41, "comprimento_cm": 26.3 },
    { "numeracao": 42, "comprimento_cm": 27.0 }
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
| `imagem_url` | string ou null | opcional |
| `tamanhos` | lista | pelo menos 1 item; `numeracao` aceita decimal (41.5) |

`comprimento_cm` é o **comprimento interno** do calçado naquela numeração, em centímetros.

## Endpoints

| Método | Rota | Corpo | Resposta de sucesso |
|---|---|---|---|
| GET | `/calcados` | — | `200` lista de `Calcado` |
| GET | `/calcados/{id}` | — | `200` `Calcado` |
| POST | `/calcados` | `Calcado` sem `id` | `201` `Calcado` com `id` |
| PUT | `/calcados/{id}` | `Calcado` sem `id` | `200` `Calcado` atualizado |
| DELETE | `/calcados/{id}` | — | `204` (ou `200`) |
| POST | `/recomendacoes` | ver abaixo | `200` recomendação |
| POST | `/imagens` | `multipart/form-data`, campo `arquivo` | `200` com `imagem_url` |

### POST `/imagens` — envio de foto do dispositivo

O Flutter permite selecionar uma foto JPG, PNG ou WebP de até 5 MB. A foto é
enviada separadamente do cadastro como `multipart/form-data`; não é convertida
em texto Base64 dentro do JSON do calçado. Isso evita aumentar o tamanho do
payload e permite que o backend controle onde os arquivos ficam armazenados.

Requisição (exemplo):

```bash
curl -X POST http://localhost:8000/imagens \
  -F "arquivo=@tenis.jpg"
```

Resposta:

```json
{
  "imagem_url": "/uploads/tenis-identificador.jpg"
}
```

`imagem_url` pode ser um caminho relativo servido pelo mesmo host da API ou
uma URL absoluta. O app transforma caminhos relativos em URLs usando `API_URL`.
O backend deve validar o conteúdo real e o tamanho do arquivo, armazenar a
imagem de forma persistente e disponibilizá-la por HTTP. Em FastAPI, o endpoint
multipart requer a dependência `python-multipart`; para desenvolvimento, os
arquivos podem ser servidos por uma rota estática de `/uploads`.

Depois do upload, o app usa a URL retornada no campo `imagem_url` do cadastro
JSON de `/calcados`. Assim, a imagem não depende do caminho local do celular ou
computador que a selecionou. O campo existente de URL continua disponível como
alternativa, sem upload.

**Importante:** esta rota ainda precisa ser implementada na API Python. Se ela
não existir, o app mostrará o erro do servidor e não concluirá o cadastro com
a foto; cadastrar sem foto ou informar uma URL continua usando os endpoints
atuais. Como o upload ocorre antes do cadastro, o backend pode futuramente
limpar imagens que não estejam vinculadas a um calçado.

### POST `/recomendacoes`

Pedido:

```json
{
  "calcado_id": 1,
  "medida_pe_cm": 26.2,
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
  "folga_cm": 0.7,
  "observacao": "Forma estreita: se o cliente tem o pé largo, considere o 42."
}
```

`alternativa`, `folga_cm` e `observacao` podem vir `null`/ausentes. O que o app mostra ao vendedor é `tamanho_recomendado` em destaque e o resto como apoio.

## Erros

O app lê o campo `detail` do FastAPI e mostra a mensagem na tela. Use o padrão:

```json
{ "detail": "Calçado não encontrado." }
```

| Situação | Status |
|---|---|
| id inexistente (GET/PUT/DELETE/recomendação) | `404` |
| corpo inválido | `422` (formato padrão do Pydantic; o app já trata) |
| regra de negócio violada | `400` com `detail` em texto claro |

Mensagens em português e claras, porque aparecem direto para o vendedor.

## CORS (só se o app rodar como Flutter Web)

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # em desenvolvimento
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Para celular físico ou emulador, subir o servidor com `uvicorn app.main:app --host 0.0.0.0 --port 8000`.

## Testes rápidos (curl)

```bash
# criar
curl -X POST http://localhost:8000/calcados -H "Content-Type: application/json" \
  -d '{"nome":"Mercurial Vapor 15","marca":"Nike","tipo":"chuteira","forma":"estreita","preco":899.9,"tamanhos":[{"numeracao":41,"comprimento_cm":26.3}]}'

# listar
curl http://localhost:8000/calcados

# recomendar
curl -X POST http://localhost:8000/recomendacoes -H "Content-Type: application/json" \
  -d '{"calcado_id":1,"medida_pe_cm":26.2,"numeracao_habitual":41}'
```
