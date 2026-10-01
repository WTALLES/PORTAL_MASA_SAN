FROM node:18

# Instala deps de build para nativos (bcrypt precisa)
RUN apt-get update && apt-get install -y build-essential python3 && rm -rf /var/lib/apt/lists/*

# Diretório de trabalho
WORKDIR /app/backend

# Copia package.json e lock PRIMEIRO (cacheia install)
COPY backend/package*.json ./

# Instala deps frescos no container (não do host)
RUN npm install --production

# Rebuild bcrypt para o ambiente Linux (fixa ELF header)
RUN npm rebuild bcrypt --build-from-source

# Agora copia o resto do código
COPY backend/ ./
COPY frontend/ ../frontend/

# Apenas variáveis não sensíveis ficam aqui
# Credenciais (DB_PASSWORD, JWT_SECRET) vêm do docker-compose via .env
ENV PORT=3000
ENV UPLOAD_DIR=./uploads

EXPOSE 3000
CMD ["node", "src/app.js"]