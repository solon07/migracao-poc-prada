# Runbook - Migração poc_prada EC2 → Proxmox

> **⚠️ ATENÇÃO**: Siga os passos na ordem. Cada etapa possui validação obrigatória.

## 🔍 Pré-requisitos

### Checklist Inicial
- [ ] EC2 poc_prada está **stopped** (confirmar no console)
- [ ] AWS CLI configurado com credenciais YOUX
- [ ] Acesso SSH ao Proxmox sp1-sd-gt4w-1
- [ ] Bucket S3 `migracao-ec2-proxmox` acessível
- [ ] ~350GB livres no storage NVME Proxmox

### Validações
```bash
# Verificar EC2 stopped
aws ec2 describe-instances \
  --instance-ids i-06dffc5a34a6c60fbe \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
# Esperado: stopped

# Verificar acesso S3
aws s3 ls s3://migracao-ec2-proxmox/
# Esperado: listar pastas chronos-export/ e exports/

# Verificar espaço Proxmox
ssh root@192.168.100.10 "df -h /mnt/pve/NVME | tail -1"
# Esperado: >350GB disponíveis
```

---

## 📦 FASE 1: Preparação da EC2

### 1.1 - Backup Configurações Atuais
```bash
# Obter detalhes completos da instância
aws ec2 describe-instances \
  --instance-ids i-06dffc5a34a6c60fbe \
  --output json > exports/ec2-full-details.json

# Backup security groups
aws ec2 describe-security-groups \
  --group-ids sg-02844529da9ffa812 \
  --output json > exports/security-groups.json

# Listar volumes anexados
aws ec2 describe-volumes \
  --volume-ids vol-0d784751235375b31 \
  --output json > exports/volume-details.json
```

**✅ Validação**: Conferir arquivos criados em `exports/`

### 1.2 - Documentar Serviços Críticos
```bash
# Se houver acesso SSH à instância (antes de desligar):
# ssh -i ~/.ssh/poc_prada.pem ubuntu@3.226.123.214

# Listar serviços ativos
systemctl list-units --type=service --state=running > exports/services-running.txt

# Backup configurações rede
cp /etc/netplan/*.yaml exports/netplan-backup.yaml

# Lista de pacotes instalados
dpkg -l > exports/packages-installed.txt
```

---

## 📸 FASE 2: Criação do Snapshot

### 2.1 - Criar Snapshot do Volume
```bash
# Criar snapshot
SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id vol-0d784751235375b31 \
  --description "Snapshot poc_prada para migração Proxmox - $(date +%Y%m%d)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=poc-prada-migration},{Key=Purpose,Value=proxmox-migration}]' \
  --query 'SnapshotId' \
  --output text)

echo "Snapshot ID: $SNAPSHOT_ID"
echo $SNAPSHOT_ID > exports/snapshot-id.txt

# Aguardar conclusão
aws ec2 wait snapshot-completed --snapshot-ids $SNAPSHOT_ID
echo "✅ Snapshot concluído!"
```

**⏱ Tempo estimado**: 15-30min (depende do tamanho)

**✅ Validação**:
```bash
aws ec2 describe-snapshots --snapshot-ids $SNAPSHOT_ID --query 'Snapshots[0].State'
# Esperado: "completed"
```

### 2.2 - Criar AMI do Snapshot
```bash
# Criar AMI
AMI_ID=$(aws ec2 register-image \
  --name "poc-prada-migration-$(date +%Y%m%d-%H%M)" \
  --description "AMI poc_prada para migração Proxmox" \
  --architecture x86_64 \
  --root-device-name /dev/sda1 \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"$SNAPSHOT_ID\",\"VolumeType\":\"gp3\"}}]" \
  --virtualization-type hvm \
  --ena-support \
  --query 'ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"
echo $AMI_ID > exports/ami-id.txt
```

**✅ Validação**:
```bash
aws ec2 describe-images --image-ids $AMI_ID --query 'Images[0].State'
# Esperado: "available"
```

---

## 📤 FASE 3: Export para S3

### 3.1 - Configurar IAM Role (se necessário)
```bash
# Verificar role vmimport existe
aws iam get-role --role-name vmimport 2>/dev/null || echo "❌ Role não existe - criar manualmente"
```

**⚠️ Se role não existir**: Siga doc AWS para criar role `vmimport` com trust policy adequada.

### 3.2 - Iniciar Export
```bash
# Iniciar export task
EXPORT_TASK_ID=$(aws ec2 export-image \
  --image-id $AMI_ID \
  --disk-image-format VMDK \
  --s3-export-location S3Bucket=migracao-ec2-proxmox,S3Prefix=exports/poc-prada/ \
  --query 'ExportImageTaskId' \
  --output text)

echo "Export Task ID: $EXPORT_TASK_ID"
echo $EXPORT_TASK_ID > exports/export-task-id.txt
```

### 3.3 - Monitorar Progresso
```bash
# Loop de monitoramento
while true; do
  STATUS=$(aws ec2 describe-export-image-tasks \
    --export-image-task-ids $EXPORT_TASK_ID \
    --query 'ExportImageTasks[0].[Status,Progress]' \
    --output text)
  
  echo "[$(date +%H:%M:%S)] Status: $STATUS"
  
  if echo "$STATUS" | grep -q "completed"; then
    echo "✅ Export concluído!"
    break
  elif echo "$STATUS" | grep -q "failed"; then
    echo "❌ Export falhou!"
    exit 1
  fi
  
  sleep 60
done
```

**⏱ Tempo estimado**: 60-90min

**✅ Validação**:
```bash
aws s3 ls s3://migracao-ec2-proxmox/exports/poc-prada/ --recursive
# Esperado: arquivo .vmdk listado
```

---

## ⬇️ FASE 4: Download e Conversão

### 4.1 - Download do S3
```bash
# Criar diretório temporário
mkdir -p exports/temp

# Download VMDK
aws s3 cp s3://migracao-ec2-proxmox/exports/poc-prada/ exports/temp/ --recursive

# Verificar arquivo
ls -lh exports/temp/*.vmdk
```

**⏱ Tempo estimado**: 30-60min (depende da conexão)

### 4.2 - Conversão VMDK → QCOW2
```bash
# Instalar qemu-utils se necessário
sudo apt install qemu-utils -y

# Converter
VMDK_FILE=$(ls exports/temp/*.vmdk | head -1)
qemu-img convert -f vmdk -O qcow2 -p \
  "$VMDK_FILE" \
  exports/poc-prada.qcow2

# Verificar integridade
qemu-img check exports/poc-prada.qcow2
```

**✅ Validação**:
```bash
qemu-img info exports/poc-prada.qcow2
# Verificar: formato qcow2, tamanho virtual ~300GB
```

---

## 🖥️ FASE 5: Criação da VM no Proxmox

### 5.1 - Upload da Imagem
```bash
# SCP para Proxmox
scp exports/poc-prada.qcow2 root@192.168.100.10:/var/lib/vz/images/

# SSH no Proxmox para continuar
ssh root@192.168.100.10
```

### 5.2 - Criar VM
```bash
# No Proxmox node
VMID=103

# Criar VM base
qm create $VMID \
  --name poc-prada \
  --memory 16384 \
  --cores 4 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26 \
  --agent 1 \
  --onboot 1

# Importar disco
qm importdisk $VMID /var/lib/vz/images/poc-prada.qcow2 NVME

# Configurar disco como boot
qm set $VMID --scsi0 NVME:vm-$VMID-disk-0
qm set $VMID --boot c --bootdisk scsi0

# Configurar console
qm set $VMID --serial0 socket --vga serial0
```

**✅ Validação**:
```bash
qm config $VMID
# Conferir configurações aplicadas
```

---

## ⚙️ FASE 6: Configuração Pós-Migração

### 6.1 - Iniciar VM e Acessar
```bash
# Iniciar VM
qm start $VMID

# Aguardar boot (2-3 min)
sleep 180

# Acessar console
qm terminal $VMID
```

### 6.2 - Configurar Rede
```bash
# Dentro da VM
# Editar netplan
nano /etc/netplan/50-cloud-init.yaml

# Exemplo config estática:
---
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 192.168.100.XXX/24  # Definir IP disponível
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses:
          - 187.108.193.3
          - 187.108.193.4

# Aplicar
netplan apply
```

### 6.3 - Instalar QEMU Guest Agent
```bash
apt update
apt install qemu-guest-agent -y
systemctl enable --now qemu-guest-agent
```

### 6.4 - Validações Finais
```bash
# Testar conectividade
ping -c 4 8.8.8.8
ping -c 4 google.com

# Verificar serviços
systemctl status

# Testar acesso SSH externo
# (do seu terminal local)
ssh usuario@192.168.100.XXX
```

---

## ✅ Checklist Pós-Migração

- [ ] VM iniciando corretamente
- [ ] Rede configurada e funcional
- [ ] Serviços críticos rodando
- [ ] QEMU Guest Agent instalado
- [ ] Backup configs antigas arquivado
- [ ] DNS resolvendo
- [ ] SSH acessível
- [ ] Disco com espaço adequado
- [ ] Documentação atualizada
- [ ] Issue GitLab #1794 fechada

---

## 🧹 Limpeza
```bash
# Após validação bem-sucedida (aguardar 1 semana):

# AWS - Deletar recursos temporários
aws ec2 deregister-image --image-id $AMI_ID
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID

# S3 - Limpar exports
aws s3 rm s3://migracao-ec2-proxmox/exports/poc-prada/ --recursive

# Local - Remover arquivos grandes
rm -rf exports/temp/
rm exports/poc-prada.qcow2

# AWS - Terminar EC2 original
aws ec2 terminate-instances --instance-ids i-06dffc5a34a6c60fbe
```

---

## 🆘 Troubleshooting

Consultar [05-troubleshooting.md](05-troubleshooting.md)
