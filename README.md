# Portal MASA (`PORTAL_MASA_SAN`)

Portal institucional e administrativo da MASA Plásticos, contendo publicação de notícias, canal de denúncias/reclamações com protocolo e painel administrativo autenticado por JWT.

---

## Arquitetura e Tecnologias

- **Backend:** Node.js 18, Express, PostgreSQL (`pg`), JWT (`jsonwebtoken`), `bcrypt` e `multer` (upload de arquivos em `backend/uploads`).
- **Frontend:** HTML, CSS e JavaScript estáticos servidos pelo Express a partir de `frontend/public`.
- **Banco de Dados:** PostgreSQL 14 (`postgres:14`), inicializado automaticamente pelo `init.sql` na primeira execução do volume.
- **Proxy Reverso:** Nginx (`nginx:alpine`) fazendo proxy na porta `80` (desenvolvimento) e `443` (produção com SSL).

### Estrutura do Projeto

```text
PORTAL_MASA_SAN/
├── backend/                  # API Node.js/Express e uploads
│   ├── src/
│   │   ├── config/           # Conexão PostgreSQL e middleware de autenticação
│   │   ├── controllers/      # Regras de negócio (auth, news, reports)
│   │   ├── routes/           # Rotas da API (/api/auth, /api/news, /api/reports)
│   │   └── app.js            # Entrada da aplicação
│   ├── uploads/              # Imagens e documentos enviados
│   └── package.json
├── frontend/
│   └── public/               # Portal público (index.html) e painel admin (/admin)
├── nginx/
│   ├── nginx.conf            # Configuração HTTP (desenvolvimento)
│   ├── nginx.production.conf # Configuração HTTPS + rate limit (produção)
│   └── ssl/                  # Certificados SSL em produção (não versionados)
├── docker-compose.yml        # Orquestração dos serviços (app, db, nginx)
├── Dockerfile                # Build da imagem Node.js
├── init.sql                  # Schema e usuários iniciais do banco
└── .env                      # Variáveis de ambiente na raiz (não versionado)
```

---

## Pré-requisitos

### Com Docker (Recomendado)
- [Docker](https://www.docker.com/) e **Docker Compose** (`docker compose` ou `docker-compose`).

### Sem Docker (Execução Local)
- **Node.js 18+** e **npm**
- **PostgreSQL 14+**

---

## Configuração de Variáveis de Ambiente

Crie um arquivo `.env` na **raiz do projeto** (mesma pasta do `docker-compose.yml`).  
As variáveis `DB_PASSWORD` e `JWT_SECRET` são obrigatórias — sem elas o container do PostgreSQL não inicializa.

```env
DB_NAME=masa_portal
DB_USER=postgres
DB_PASSWORD=sua_senha_segura
JWT_SECRET=sua_chave_jwt_super_secreta
JWT_EXPIRES_IN=8h
```

> **Importante:** O arquivo `.env` está no `.gitignore` e nunca deve ser enviado ao repositório. Em produção, utilize senhas e segredos fortes.

---

## Como Executar com Docker

1. Certifique-se de ter criado o arquivo `.env` na raiz do projeto.
2. Suba os containers (build + execução em segundo plano):

```bash
docker compose up --build -d
```

*(Se sua instalação utilizar a versão legada do Compose, use `docker-compose` no lugar de `docker compose`.)*

3. Acesse no navegador:
   - **Portal público:** `http://localhost`
   - **Painel administrativo:** `http://localhost/admin/login.html`

> Por segurança, o `docker-compose.yml` não expõe a porta `5432` (PostgreSQL) nem a `3000` (Node.js) diretamente para o host — todo o acesso externo passa pelo Nginx na porta `80`/`443`.

### Comandos Úteis do Docker

```bash
# Verificar status dos containers
docker compose ps

# Acompanhar os logs em tempo real
docker compose logs -f

# Acompanhar apenas os logs da API ou do banco
docker compose logs -f app
docker compose logs -f db

# Parar os containers mantendo os dados do banco
docker compose down

# Parar e apagar volumes (ZERA o banco de dados e reexecuta o init.sql ao subir novamente)
docker compose down -v
```

---

## Como Executar Localmente (Sem Docker)

1. Crie o banco de dados no PostgreSQL local e execute o script inicial:

```bash
createdb -U postgres masa_portal
psql -U postgres -d masa_portal -f init.sql
```

2. Configure o arquivo `backend/.env`:

```env
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=masa_portal
DB_USER=postgres
DB_PASSWORD=sua_senha
JWT_SECRET=sua_chave_jwt_super_secreta
JWT_EXPIRES_IN=8h
UPLOAD_DIR=./uploads
```

3. Instale as dependências e inicie o servidor:

```bash
cd backend
npm install

# Desenvolvimento (com reload automático via nodemon)
npm run dev

# Ou produção
npm start
```

4. Acesse `http://localhost:3000` (e `http://localhost:3000/admin/login.html`).

---

## Restauração do Banco de Dados (`.dump`)

Os arquivos de backup `.dump` (por exemplo, `masa-2026-08-18-1136.dump`) são gerados no **formato customizado do PostgreSQL (`PGDMP` / `pg_dump -Fc`)**. Por isso, devem ser restaurados utilizando **`pg_restore`** (e não `psql`).

### 1. Restaurando no Banco em Docker (Recomendado)

Com os containers em execução (`docker compose up -d`), execute os comandos abaixo na raiz do projeto (funciona igualmente no **Windows PowerShell, CMD, Linux e macOS**):

```bash
# 1. Copie o arquivo .dump para dentro do container do banco
docker compose cp masa-2026-08-18-1136.dump db:/tmp/backup.dump

# 2. Restaure o backup no banco masa_portal
docker compose exec db pg_restore -U postgres -d masa_portal --clean --if-exists --no-owner --no-privileges /tmp/backup.dump

# 3. Remova o arquivo temporário de dentro do container
docker compose exec db rm /tmp/backup.dump
```

> **Atenção:**
> - Substitua `masa-2026-08-18-1136.dump` pelo nome do arquivo `.dump` que deseja restaurar.
> - Se você alterou `DB_USER` ou `DB_NAME` no `.env`, substitua `postgres` e `masa_portal` nos comandos acima pelos mesmos valores definidos no `.env`.
> - As flags `--clean --if-exists` removem as tabelas/objetos existentes antes de recriá-los com os dados do backup; `--no-owner --no-privileges` evita erros de permissão caso o usuário do ambiente original seja diferente.
> - Caso apareçam alertas pontuais do `pg_restore` ao tentar remover objetos que ainda não existiam, verifique se os dados foram importados normalmente com o passo abaixo.

#### Verificar se a restauração deu certo

```bash
docker compose exec db psql -U postgres -d masa_portal -c "\dt" -c "SELECT count(*) AS admins FROM admins; SELECT count(*) AS news FROM news; SELECT count(*) AS reports FROM reports;"
```

> **Dica sobre arquivos enviados (`uploads`):** O `.dump` restaura apenas os dados do banco (textos, usuários, protocolos e caminhos das imagens/anexos). Para que imagens de notícias e anexos de denúncias apareçam corretamente, mantenha também o backup da pasta `backend/uploads/`.

### 2. Restaurando em um PostgreSQL Local (Sem Docker)

```bash
pg_restore -h localhost -p 5432 -U postgres -d masa_portal --clean --if-exists --no-owner --no-privileges masa-2026-08-18-1136.dump
```

### 3. Como Gerar um Novo Backup (`.dump`) a partir do Docker

```bash
# Gera o dump em formato customizado dentro do container
docker compose exec db pg_dump -U postgres -Fc masa_portal -f /tmp/backup.dump

# Copia o arquivo gerado para a pasta atual no host
docker compose cp db:/tmp/backup.dump ./masa-backup.dump

# Remove o arquivo temporário do container
docker compose exec db rm /tmp/backup.dump
```

---

## Produção (HTTPS / SSL)

Para ambiente de produção:

1. Defina `DB_PASSWORD` e `JWT_SECRET` fortes no `.env` da raiz.
2. Coloque os certificados SSL (`fullchain.pem` e `privkey.pem`) na pasta `nginx/ssl/`.
3. Atualize o `docker-compose.yml` para montar `./nginx/nginx.production.conf:/etc/nginx/nginx.conf:ro` (ou substitua o conteúdo de `nginx/nginx.conf` pelo de `nginx/nginx.production.conf` ajustando o `server_name`).
4. Suba os serviços com `docker compose up --build -d`.

---

## Solução de Problemas Comuns

- **`Error: Database is uninitialized and superuser password is not specified.`**  
  O arquivo `.env` não existe na **raiz do projeto** ou a variável `DB_PASSWORD` está vazia. Crie o `.env` na raiz conforme a seção [Configuração de Variáveis de Ambiente](#configuração-de-variáveis-de-ambiente), execute `docker compose down -v` e depois `docker compose up --build -d`.

- **Erro de porta `80` já em uso ao subir o Nginx**  
  Outro serviço (IIS, Apache, outro Nginx) já está usando a porta `80`. Pare o serviço conflitante ou altere o mapeamento de portas no `docker-compose.yml` (por exemplo, `"8080:80"`).
