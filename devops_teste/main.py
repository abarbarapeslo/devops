from fastapi import Depends, FastAPI
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from databases import Database

# cria uma conexão com o banco de dados
DATABASE_URL = 'sqlite:///banco_de_dados.db'
db = Database(DATABASE_URL)

# cria o engine (necessário para o SQLAlchemy criar tabelas e sessões)
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

# define o objeto base
Base = declarative_base()

class Tabela(Base):
    __tablename__ = 'tabela'

    id = Column(Integer, primary_key=True)
    nome = Column(String)
    idade = Column(Integer)

app = FastAPI()

# cria a tabela no banco de dados
Base.metadata.create_all(engine)

# cria uma sessão com o banco de dados
SessionLocal = sessionmaker(bind=engine)

# função de dependência para criar/fechar sessão
def get_db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

# endpoint para criar um novo registro
@app.post('/tabela')
async def criar_registro(nome: str, idade: int, session: Session = Depends(get_db)):  # type: ignore
    registro = Tabela(nome=nome, idade=idade)
    session.add(registro)
    session.commit()
    session.refresh(registro)
    return registro

# endpoint para ler os registros da tabela
@app.get('/tabela')
async def ler_registros(session: Session = Depends(get_db)):  # type: ignore
    resultado = session.query(Tabela).all()
    return resultado

# endpoint para atualizar um registro
@app.put('/tabela/{id}')
async def atualizar_registro(id: int, nome: str, idade: int, session: Session = Depends(get_db)):  # type: ignore
    registro = session.query(Tabela).get(id)
    if not registro:
        return {"erro": "Registro não encontrado"}
    registro.nome = nome
    registro.idade = idade
    session.commit()
    session.refresh(registro)
    return registro
