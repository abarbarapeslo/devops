from fastapi import FastAPI



app = FastAPI()

@app.get('/')
def get():
    return { 'message: Bem vindo(a) Getpage'}

@app.post('/page')
def post():
    return { 'message: Bem vindo(a) Postpage'}

@app.delete('/delete')
def delet():
    return { 'message: Bem vindo(a) Deletepage'}