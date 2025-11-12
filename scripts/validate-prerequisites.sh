#!/bin/bash
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
if ssh -q -o ConnectTimeout=5 root@192.168.100.10 exit; then
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
