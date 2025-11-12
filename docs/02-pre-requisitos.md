# Pré-requisitos - Migração poc_prada

## ✅ Checklist Completa

### AWS
- [ ] **EC2 poc_prada está stopped**
```bash
  aws ec2 describe-instances \
    --instance-ids i-06dffc5a34a6c60fbe \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text
  # Esperado: stopped
```

- [ ] **AWS CLI configurado**
```bash
  aws sts get-caller-identity
  # Deve retornar Account ID: 592309313728
```

- [ ] **Permissões IAM adequadas**
  - EC2: CreateSnapshot, RegisterImage, ExportImage
  - S3: PutObject, GetObject, ListBucket
  - IAM: GetRole (verificar vmimport)

- [ ] **Role vmimport existe**
```bash
  aws iam get-role --role-name vmimport
  # Se falhar, criar role antes de export AMI
```

- [ ] **Bucket S3 acessível**
```bash
  aws s3 ls s3://migracao-ec2-proxmox/
  # Deve listar chronos-export/ e exports/
```

### Proxmox
- [ ] **Acesso SSH ao node sp1-sd-gt4w-1**
```bash
  ssh root@192.168.100.10 'hostname'
  # Esperado: sp1-sd-gt4w-1
```

- [ ] **Espaço suficiente no NVME**
```bash
  ssh root@192.168.100.10 "df -h /mnt/pve/NVME | tail -1"
  # Esperado: >350GB disponíveis
```

- [ ] **VMID 103 disponível**
```bash
  ssh root@192.168.100.10 "qm list | grep 103"
  # Esperado: sem output (VMID livre)
```

- [ ] **Ferramentas instaladas**
```bash
  ssh root@192.168.100.10 "which qemu-img"
  # Deve retornar caminho do binário
```

### Local
- [ ] **qemu-utils instalado (WSL)**
```bash
  which qemu-img || sudo apt install qemu-utils -y
```

- [ ] **Espaço em disco local**
```bash
  df -h ~/work/youx/projetos/migracao-poc-prada/exports
  # Esperado: >150GB livres (para VMDK temporário)
```

- [ ] **Conexão estável AWS**
```bash
  ping -c 4 ec2.us-east-1.amazonaws.com
  # Latência <100ms ideal
```

---

## 🔐 Credenciais Necessárias

### AWS
- **Profile**: default (ou especificar com `--profile`)
- **Region**: us-east-1
- **Account**: 592309313728

### Proxmox
- **Endereço**: 192.168.100.10:8006
- **Usuário**: root@pam
- **Senha**: (1Password / vault infra)

### SSH Keys
- **EC2**: `~/.ssh/poc_prada.pem` (se precisar acessar antes)
- **Proxmox**: `~/.ssh/id_rsa` (padrão)

---

## ⚠️ Validações Críticas

### Antes de Snapshot
```bash
# 1. Confirmar EC2 stopped
STATUS=$(aws ec2 describe-instances \
  --instance-ids i-06dffc5a34a6c60fbe \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

if [ "$STATUS" != "stopped" ]; then
  echo "❌ EC2 não está stopped! Parar antes de continuar."
  exit 1
fi

echo "✅ EC2 stopped - pode prosseguir"
```

### Antes de Export
```bash
# 2. Verificar role vmimport
aws iam get-role --role-name vmimport &>/dev/null
if [ $? -ne 0 ]; then
  echo "❌ Role vmimport não existe!"
  echo "Criar com: https://docs.aws.amazon.com/vm-import/latest/userguide/vmie_prereqs.html#vmimport-role"
  exit 1
fi

echo "✅ Role vmimport configurada"
```

### Antes de Conversão
```bash
# 3. Validar download completo
VMDK_FILE=$(ls exports/temp/*.vmdk 2>/dev/null | head -1)

if [ -z "$VMDK_FILE" ]; then
  echo "❌ Arquivo VMDK não encontrado!"
  exit 1
fi

echo "✅ VMDK encontrado: $VMDK_FILE"
echo "Tamanho: $(du -h "$VMDK_FILE" | cut -f1)"
```

---

## 🛠️ Troubleshooting Pré-requisitos

### Problema: Role vmimport não existe

**Solução**:
```bash
# 1. Criar trust policy
cat > /tmp/trust-policy.json << 'POLICY'
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
POLICY

# 2. Criar role policy
cat > /tmp/role-policy.json << 'POLICY'
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::migracao-ec2-proxmox",
            "arn:aws:s3:::migracao-ec2-proxmox/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
POLICY

# 3. Criar role
aws iam create-role \
  --role-name vmimport \
  --assume-role-policy-document file:///tmp/trust-policy.json

# 4. Anexar policy
aws iam put-role-policy \
  --role-name vmimport \
  --policy-name vmimport \
  --policy-document file:///tmp/role-policy.json

echo "✅ Role vmimport criada!"
```

### Problema: VMID 103 já existe

**Solução**: Escolher próximo disponível
```bash
ssh root@192.168.100.10 "qm list" | awk '{print $1}' | sort -n
# Usar próximo número livre (ex: 104)
```

---

## 📋 Script de Validação Automática
```bash
#!/bin/bash
# scripts/validate-prerequisites.sh

set -euo pipefail

echo "🔍 Validando pré-requisitos..."
ERRORS=0

# AWS CLI
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI não instalado"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ AWS CLI instalado"
fi

# EC2 Status
STATUS=$(aws ec2 describe-instances \
  --instance-ids i-06dffc5a34a6c60fbe \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "error")

if [ "$STATUS" == "stopped" ]; then
  echo "✅ EC2 stopped"
elif [ "$STATUS" == "error" ]; then
  echo "❌ Erro ao verificar EC2"
  ERRORS=$((ERRORS + 1))
else
  echo "⚠️  EC2 em estado: $STATUS (esperado: stopped)"
  ERRORS=$((ERRORS + 1))
fi

# S3 Bucket
if aws s3 ls s3://migracao-ec2-proxmox/ &>/dev/null; then
  echo "✅ Bucket S3 acessível"
else
  echo "❌ Bucket S3 inacessível"
  ERRORS=$((ERRORS + 1))
fi

# Proxmox SSH
if ssh -q root@192.168.100.10 exit; then
  echo "✅ Acesso SSH Proxmox OK"
else
  echo "❌ Sem acesso SSH ao Proxmox"
  ERRORS=$((ERRORS + 1))
fi

# Espaço NVME
SPACE=$(ssh root@192.168.100.10 "df /mnt/pve/NVME | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "0")
SPACE_GB=$((SPACE / 1024 / 1024))

if [ $SPACE_GB -gt 350 ]; then
  echo "✅ Espaço NVME: ${SPACE_GB}GB disponíveis"
else
  echo "❌ Espaço NVME insuficiente: ${SPACE_GB}GB (mínimo 350GB)"
  ERRORS=$((ERRORS + 1))
fi

# qemu-img
if command -v qemu-img &> /dev/null; then
  echo "✅ qemu-img instalado"
else
  echo "⚠️  qemu-img não instalado (instalar: sudo apt install qemu-utils)"
fi

# Resumo
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
  echo "✅ Todos pré-requisitos OK!"
  echo "Pode prosseguir com a migração."
  exit 0
else
  echo "❌ $ERRORS erro(s) encontrado(s)"
  echo "Corrigir antes de prosseguir."
  exit 1
fi
```

**Tornar executável**:
```bash
chmod +x scripts/validate-prerequisites.sh
```
