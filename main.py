from fastapi import Depends, FastAPI
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from databases import Database


# Caminho do arquivo do banco de dados (SQLite)
DATABASE_URL = "sqlite:///banco_de_dados.db"

# Cria a conexão assíncrona (não usamos neste exemplo, mas é útil futuramente)
database = Database(DATABASE_URL)

# Cria o "engine", que é o mecanismo de conexão do SQLAlchemy
# O parâmetro check_same_thread=False é necessário para o SQLite
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})


# "Base" é a classe mãe que o SQLAlchemy usa para criar tabelas
Base = declarative_base()

# Definimos uma tabela chamada "tabela" com 3 colunas
class Tabela(Base):
    __tablename__ = "tabela"  # nome da tabela no banco

    id = Column(Integer, primary_key=True, index=True)  # chave primária
    nome = Column(String)  # coluna de texto
    idade = Column(Integer)  # coluna numérica


app = FastAPI()


# Cria a tabela no banco de dados (se ainda não existir)
Base.metadata.create_all(bind=engine)

# Cria uma fábrica de sessões (conexões com o banco)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db():
    """
    Essa função cria uma conexão (sessão) com o banco de dados.
    O 'yield' é usado para entregar essa sessão à rota.
    Quando a requisição termina, a sessão é fechada automaticamente.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


#Criar um novo registro
@app.post("/tabela")
async def criar_registro(nome: str, idade: int, db: Session = Depends(get_db)):
    novo_registro = Tabela(nome=nome, idade=idade)
    db.add(novo_registro)
    db.commit()            # salva no banco
    db.refresh(novo_registro)  # atualiza o objeto com o ID gerado
    return novo_registro


#Ler (listar) todos os registros
@app.get("/tabela")
async def listar_registros(db: Session = Depends(get_db)):
    registros = db.query(Tabela).all()
    return registros


#Atualizar um registro existente
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

@app.delete("/tabela/{id}")
async def deletar_registro(id: int, db: Session = Depends(get_db)):
    registro = db.query(Tabela).get(id)

    if not registro:
        return {"erro": "Registro não encontrado"}

    db.delete(registro)
    db.commit()
    return {"mensagem": f"Registro com ID {id} deletado com sucesso!"}
