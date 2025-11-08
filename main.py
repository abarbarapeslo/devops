# ==========================
# 📘 Importações necessárias
# ==========================
import os
import json
import time
from datetime import datetime, timezone
import boto3  # <--- 1. Importa a biblioteca da AWS

from fastapi import Depends, FastAPI
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
# 'databases' e 'aiosqlite' não são mais necessários se mudarmos 100% para SQLAlchemy sync
# from databases import Database 

# ========================================================
# ⚙️ 2. Configuração do Banco de Dados (Lógica Atualizada)
# ========================================================

# Tenta ler as três fontes de configuração, em ordem de prioridade:

# 1. MODO PRODUÇÃO (Fargate/ECS): Lê do Secrets Manager
db_creds_json_string = os.environ.get("DB_CREDS_JSON")

# 2. MODO DOCKER-COMPOSE (Local): Lê variáveis de ambiente individuais
db_host = os.environ.get("DB_HOST") 


if db_creds_json_string:
    # --- MODO 1: PRODUÇÃO ---
    print("Modo Produção: Lendo credenciais do Secrets Manager.")
    creds = json.loads(db_creds_json_string)
    
    DB_USER = creds['username']
    DB_PASS = creds['password']
    DB_HOST = creds['host']
    DB_PORT = creds['port']
    DB_NAME = creds['dbname']

    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(DATABASE_URL)

elif db_host:
    # --- MODO 2: DOCKER-COMPOSE ---
    print("Modo Docker-Compose: Conectando ao container PostgreSQL.")
    DB_USER = os.environ["DB_USER"]
    DB_PASS = os.environ["DB_PASS"]
    DB_NAME = os.environ["DB_NAME"]
    
    # A porta é 5432 padrão do Postgres
    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{db_host}:5432/{DB_NAME}"
    engine = create_engine(DATABASE_URL)

else:
    # --- MODO 3: FALLBACK LOCAL ---
    print("Modo Local (Fallback): Usando banco SQLite 'banco_de_dados.db'.")
    DATABASE_URL = "sqlite:///./banco_de_dados.db"
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

# ==================================
# 🧱 Definição da tabela (modelo ORM)
# ==================================
Base = declarative_base()

class Tabela(Base):
    __tablename__ = "tabela"
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String)
    idade = Column(Integer)

# ====================================
# 🚀 Inicialização da aplicação FastAPI
# ====================================
app = FastAPI()

# ==============================================
# ⚙️ 3. Configuração dos Clientes AWS (S3 e SES)
# ==============================================
# O boto3 vai usar a "Task Role" do IAM (definida no iam.tf)
# para se autenticar automaticamente. Sem chaves no código!
s3 = boto3.client("s3")
ses = boto3.client("ses")

# O Terraform vai injetar estas variáveis de ambiente no container
BUCKET_NAME = os.environ.get("BUCKET_NAME", "bucket-local-padrao")
SES_SENDER = os.environ.get("SES_SENDER_EMAIL", "sender@local.com")
SES_RECIPIENT = os.environ.get("SES_RECIPIENT_EMAIL", "recipient@local.com")


# =====================================
# 🗃️ Criação do banco e das sessões ORM
# =====================================
Base.metadata.create_all(bind=engine)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# =================================================
# 🔁 Função de dependência (gera uma sessão por vez)
# =================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ===============================
# 📌 Endpoints (rotas da API)
# ===============================

# 4. NOVO: Endpoint de Health Check (Saúde)
# O Load Balancer (ALB) vai chamar este endpoint para
# saber se a aplicação está "viva"
@app.get("/")
async def health_check():
    """
    Retorna 200 OK se a aplicação estiver no ar.
    """
    return {"status": "ok", "message": "Estou vivo!"}


# 5. NOVO: Endpoint /submit (Lógica do S3+SES)
@app.post("/submit")
async def criar_submissao(data: dict): # Recebe um JSON qualquer
    """
    Recebe um payload JSON, salva no S3 e notifica via SES.
    """
    try:
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        key = f"submissions/{ts}-{int(time.time()*1000)}.json"

        # 1. Salva no S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=json.dumps(data, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )

        # 2. Envia e-mail via SES
        subject = f"Nova submissão de formulário - {ts}"
        body_text = (
            f"Recebemos uma nova submissão.\n\n"
            f"Conteúdo:\n{json.dumps(data, indent=2, ensure_ascii=False)}\n\n"
            f"Arquivo salvo em: s3://{BUCKET_NAME}/{key}"
        )

        ses.send_email(
            Source=SES_SENDER,
            Destination={"ToAddresses": [SES_RECIENT]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {"Data": body_text, "Charset": "UTF-8"},
            },
        )

        return {"status": "ok", "s3_key": key}

    except Exception as e:
        print(f"Erro ao processar submissão: {e}")
        # Retorna um 500 (Server Error)
        return {"error": "Falha no processamento", "details": str(e)}, 500


# --- Endpoints antigos (CRUD) ---
# (Funcionarão normalmente, mas agora com PostgreSQL)

@app.post("/tabela")
async def criar_registro(nome: str, idade: int, db: Session = Depends(get_db)):
    novo_registro = Tabela(nome=nome, idade=idade)
    db.add(novo_registro)
    db.commit()
    db.refresh(novo_registro)
    return novo_registro

@app.get("/tabela")
async def listar_registros(db: Session = Depends(get_db)):
    registros = db.query(Tabela).all()
    return registros

@app.put("/tabela/{id}")
async def atualizar_registro(id: int, nome: str, idade: int, db: Session = Depends(get_db)):
    registro = db.query(Tabela).get(id)
    if not registro:
        return {"erro": "Registro não encontrado"}
    registro.nome = nome
    registro.idade = idade
    db.commit()
    db.refresh(registro)
    return registro