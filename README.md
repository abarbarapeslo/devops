# devops

# Configuração do GitHub no Fedora / EC2

Este documento descreve o passo a passo que foi seguido para autenticar, adicionar arquivos e enviar para o GitHub a partir de uma máquina Fedora/EC2, incluindo erros encontrados e soluções aplicadas.

---

## 1. Login no GitHub via CLI (`gh`)

### Passos:
1. Instalar o GitHub CLI:
```bash
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh


gh auth login
# Selecionar GitHub.com
# Protocolo: SSH
# Método: Paste an authentication token



gh auth login
# Selecionar GitHub.com
# Protocolo: SSH
# Método: Paste an authentication token


Criar um Personal Access Token (PAT) no GitHub com os seguintes escopos:

repo ✅
read:org ✅
gist ✅
workflow ✅

admin:public_key ✅ (necessário para SSH)

Colar o token quando solicitado pelo gh auth login.

Verificar status do login: 
gh auth status


