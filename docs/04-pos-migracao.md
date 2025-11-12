# Pós-Migração - Configurações e Validações

## 🎯 Objetivo

Garantir que a VM migrada está funcional, segura e pronta para produção.

---

## 📋 Checklist Essencial

### Fase 1: Validação Básica (Imediata)

- [ ] **VM inicializa sem erros**
```bash
  # No Proxmox
  qm start 103
  qm status 103
  # Esperado: status: running
```

- [ ] **Console acessível**
```bash
  qm terminal 103
  # Deve abrir console login
```

- [ ] **Sistema operacional íntegro**
```bash
  # Dentro da VM
  uname -a
  lsb_release -a
  # Confirmar Ubuntu 24.04 LTS
```

### Fase 2: Rede e Conectividade (10-15min)

- [ ] **Interface de rede detectada**
```bash
  ip addr show
  # Verificar interface ens18 ou similar
```

- [ ] **Configurar IP estático**
```bash
  # Editar netplan
  sudo nano /etc/netplan/50-cloud-init.yaml
  
  # Aplicar
  sudo netplan apply
  
  # Validar
  ip addr show ens18
```

- [ ] **Gateway respondendo**
```bash
  ping -c 4 192.168.100.1
```

- [ ] **DNS resolvendo**
```bash
  dig google.com
  nslookup google.com
```

- [ ] **Internet acessível**
```bash
  ping -c 4 8.8.8.8
  curl -I https://google.com
```

### Fase 3: Serviços e Aplicações (20-30min)

- [ ] **QEMU Guest Agent instalado**
```bash
  sudo apt update
  sudo apt install qemu-guest-agent -y
  sudo systemctl enable --now qemu-guest-agent
  sudo systemctl status qemu-guest-agent
```

- [ ] **Listar serviços em execução**
```bash
  systemctl list-units --type=service --state=running
  
  # Comparar com exports/services-running.txt (backup EC2)
```

- [ ] **Validar serviços críticos**
```bash
  # Exemplos (ajustar conforme aplicação):
  sudo systemctl status nginx      # Se houver
  sudo systemctl status postgresql # Se houver
  sudo systemctl status docker     # Se houver
  
  # Verificar portas
  sudo ss -tulpn | grep LISTEN
```

- [ ] **Verificar logs de boot**
```bash
  sudo journalctl -b -p err
  # Não deve ter erros críticos
```

### Fase 4: Storage e Performance (15min)

- [ ] **Espaço em disco adequado**
```bash
  df -h
  # Comparar com volume EC2 original (300GB)
```

- [ ] **I/O funcionando**
```bash
  # Teste básico escrita
  dd if=/dev/zero of=/tmp/testfile bs=1M count=1000 oflag=direct
  rm /tmp/testfile
```

- [ ] **Verificar montagens**
```bash
  mount | grep -v tmpfs
  cat /etc/fstab
```

### Fase 5: Segurança (10min)

- [ ] **SSH acessível externamente**
```bash
  # Do seu WSL
  ssh usuario@192.168.100.XXX
```

- [ ] **Atualizar sistema**
```bash
  sudo apt update
  sudo apt upgrade -y
```

- [ ] **Firewall configurado (se houver)**
```bash
  sudo ufw status
  # Ajustar regras conforme necessário
```

- [ ] **Trocar senhas/keys se necessário**
```bash
  # Se usar mesma key EC2, considerar regenerar
```

---

## 🔧 Configurações Recomendadas

### 1. Configurar Hostname
```bash
# Definir hostname
sudo hostnamectl set-hostname poc-prada

# Editar /etc/hosts
sudo nano /etc/hosts
# Adicionar:
# 127.0.1.1 poc-prada
```

### 2. Configurar NTP
```bash
# Verificar timezone
timedatectl

# Ajustar se necessário
sudo timedatectl set-timezone America/Sao_Paulo

# Verificar sincronização
timedatectl status
```

### 3. Otimizar para Proxmox/KVM
```bash
# Instalar virtio drivers (se não instalados)
sudo apt install linux-image-generic -y

# Habilitar serviços
sudo systemctl enable qemu-guest-agent
```

### 4. Configurar Backup (Proxmox)
```bash
# No Proxmox node
# Adicionar VM ao schedule backup
pvesh set /cluster/backup --schedule 'daily' \
  --vmid 103 \
  --storage NVME \
  --compress zstd \
  --mode snapshot
```

---

## 📊 Comparação EC2 vs Proxmox

### Performance Esperada

| Métrica | EC2 (t3.xlarge) | Proxmox (NVME) | Status |
|---------|-----------------|----------------|--------|
| CPU | 4 vCPUs | 4 cores | ✅ Equivalente |
| RAM | 16GB | 16GB | ✅ Equivalente |
| Disco (IOPS) | ~3000 (gp3) | 50000+ (NVME) | ✅ Melhor |
| Latência | Variable | <1ms local | ✅ Melhor |
| Network | 5 Gbps | 1 Gbps | ⚠️ Reduzido |

### Validar Performance
```bash
# CPU
lscpu
cat /proc/cpuinfo | grep "model name" | head -1

# RAM
free -h
cat /proc/meminfo | grep MemTotal

# Disco
sudo hdparm -Tt /dev/sda

# Rede (do WSL)
iperf3 -c 192.168.100.XXX -p 5201
```

---

## ✅ Checklist Final

### Documentação
- [ ] Atualizar `config/proxmox-config.json` com IP final
- [ ] Documentar credenciais em 1Password
- [ ] Tirar screenshots evidência (console, htop, etc)
- [ ] Atualizar README.md com status "Concluído"

### GitLab
- [ ] Adicionar comentário final na issue #1794
- [ ] Anexar prints de validação
- [ ] Marcar issue como "Done"
- [ ] Linkar para repositório GitHub

### Infra
- [ ] Atualizar inventário interno YOUX
- [ ] Notificar Pedro Magalhães (validação)
- [ ] Adicionar DNS se aplicável
- [ ] Configurar monitoramento (Grafana)

### Cleanup
- [ ] **AGUARDAR 1 SEMANA** antes de limpar AWS
- [ ] Após validação: executar limpeza (ver runbook seção Limpeza)
- [ ] Remover arquivos locais grandes (`exports/*.qcow2`)
- [ ] Commit final documentação

---

## 📸 Screenshots Recomendados

1. **Proxmox UI** - VM listada com status running
2. **Console VM** - `htop` rodando
3. **Rede** - `ip addr` e `ping google.com`
4. **Serviços** - `systemctl status` dos principais
5. **Disco** - `df -h` mostrando espaço
6. **Performance** - `htop` ou similar

Salvar em `assets/screenshots/pos-migracao/`

---

## 🆘 Problemas Comuns

### VM não inicia

1. Verificar config boot:
```bash
   qm config 103 | grep boot
   # Deve ser: boot: order=scsi0
```

2. Ver logs:
```bash
   qm log 103
```

### Rede não funciona

1. Verificar netplan syntax:
```bash
   sudo netplan --debug apply
```

2. Verificar interface:
```bash
   ip link show
   sudo ip link set ens18 up
```

### QEMU Agent offline

1. Reinstalar:
```bash
   sudo apt remove --purge qemu-guest-agent
   sudo apt install qemu-guest-agent
   sudo systemctl restart qemu-guest-agent
```

Consultar também: [05-troubleshooting.md](05-troubleshooting.md)
