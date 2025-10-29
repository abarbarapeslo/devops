# DEVOPS

# Configuração do GitHub no Fedora / EC2

Este documento descreve o passo a passo que foi seguido para autenticar, adicionar arquivos e enviar para o GitHub a partir de uma máquina Fedora/EC2, incluindo erros encontrados e soluções aplicadas.

---

## 1. Login no GitHub via CLI (`gh`)

### Passos:
#### 1. Instalar o GitHub CLI:
```bash
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh
```

---

#### 2. Autenticar com o GitHub CLI:
```
gh auth login
```
###### Selecionar GitHub.com > Protocolo: SSH > Método: Paste an authentication token

#### 3. Alterar o remote do repositório para usar porta 443:
```
git remote set-url origin ssh://git@ssh.github.com:443/USUARIO/NOME_DO_REPOSITORIO.git
```

#### 4. Criar um Personal Access Token (PAT) no GitHub com os seguintes escopos:

- repo [✅]
- read:org [✅]
- gist [✅]
- workflow [✅]

- admin:public_key [✅] (necessário para SSH)

#### 5. Verificar status do login: 
``` 
gh auth status
```

> ⚠️ Dica: Não use sudo para git push. Isso pode gerar erros de permissão da chave SSH.



