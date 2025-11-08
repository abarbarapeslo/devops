# 1️⃣ Escolhe imagem base oficial do Python
FROM python:3.11-slim

# 2️⃣ Define diretório de trabalho dentro do container
WORKDIR /app

# 3️⃣ Copia os arquivos de dependências
COPY requirements.txt .

# 4️⃣ Instala as dependências
RUN pip install --no-cache-dir -r requirements.txt

# 5️⃣ Copia o restante da aplicação
COPY . .

# 6️⃣ Expõe a porta usada pelo Uvicorn (8000)
EXPOSE 8000

# 7️⃣ Define o comando padrão para rodar a aplicação
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
