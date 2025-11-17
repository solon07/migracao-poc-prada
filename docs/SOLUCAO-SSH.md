# Solução SSH - VM poc-prada (105)

## Problema
SSH externo falhando com "Permission denied (publickey)" mesmo com PasswordAuthentication yes configurado no arquivo principal /etc/ssh/sshd_config.

## Causa Raiz
**Arquivo drop-in sobrescrevendo configuração principal:**
- `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` continha `PasswordAuthentication no`
- Arquivos em `sshd_config.d/` têm precedência sobre configurações no arquivo principal
- Cloud-init (Ubuntu Cloud Image) criou esse arquivo automaticamente
- Resultado: `sshd -T` mostrava `passwordauthentication no` mesmo após editar arquivo principal

## Solução Aplicada

### 1. Diagnóstico
```bash
sudo sshd -T | grep passwordauthentication
# Retornou: passwordauthentication no

ls -la /etc/ssh/sshd_config.d/
# Encontrou: 60-cloudimg-settings.conf

cat /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
# Conteúdo: PasswordAuthentication no
```

### 2. Correção
```bash
# Backup
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-20251117-1716

# Remover arquivos drop-in conflitantes
sudo rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Adicionar configurações corretas no arquivo principal
sudo tee -a /etc/ssh/sshd_config > /dev/null <<'SSHEOF'
# === MIGRAÇÃO PROXMOX - Forçar autenticação por senha ===
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin no
ChallengeResponseAuthentication no
UsePAM yes
AuthenticationMethods password publickey
PermitEmptyPasswords no
SSHEOF

# Validar sintaxe e reiniciar
sudo sshd -t
sudo systemctl restart ssh
```

### 3. Prevenir Cloud-Init de Recriar
```bash
# Criar arquivo que impede cloud-init de gerenciar SSH
sudo tee /etc/cloud/cloud.cfg.d/99-disable-ssh-management.cfg > /dev/null <<'CLOUDEOF'
# Migração Proxmox - Desabilitar gestão SSH
ssh_deletekeys: false
ssh_genkeytypes: []
disable_root: false
ssh_pwauth: true
CLOUDEOF

sudo cloud-init clean --logs
```

## Validação
- [x] SSH do WSL: OK ✅
- [x] Senha funcional: OK ✅
- [x] Sudo via SSH: OK ✅
- [x] Serviços Docker: OK ✅ (5 containers rodando)
- [x] Conectividade internet: OK ✅

## Containers Validados
- prada_core (8000/tcp)
- prada_ui (3000/tcp)
- n8n (5678/tcp)
- postgres (5432/tcp)
- qgis-server (5555/tcp)

## Data: 17/11/2025
## Executor: Mateus Sturm
## Tempo resolução: ~15min
