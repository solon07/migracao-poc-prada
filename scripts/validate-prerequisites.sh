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

# AWS Credentials
if aws sts get-caller-identity &>/dev/null; then
  echo "✅ AWS credentials configuradas"
else
  echo "❌ AWS credentials não configuradas (executar: aws configure)"
  ERRORS=$((ERRORS + 1))
fi

# EC2 Status (só se credentials OK)
if aws sts get-caller-identity &>/dev/null; then
  STATUS=$(aws ec2 describe-instances \
    --instance-ids i-06dfc5a34a6c60fbe \
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
fi

# S3 Bucket (só se credentials OK)
if aws sts get-caller-identity &>/dev/null; then
  if aws s3 ls s3://migracao-ec2-proxmox/ &>/dev/null; then
    echo "✅ Bucket S3 acessível"
  else
    echo "❌ Bucket S3 inacessível"
    ERRORS=$((ERRORS + 1))
  fi
fi

# Proxmox SSH (removido BatchMode para aceitar senha)
if ssh -q -o ConnectTimeout=5 root@192.168.100.10 exit 2>/dev/null; then
  echo "✅ Acesso SSH Proxmox OK"
  
  # Espaço NVME (usando pvesm)
  SPACE_INFO=$(ssh root@192.168.100.10 "pvesm status | grep NVME" 2>/dev/null || echo "")
  
  if [ -n "$SPACE_INFO" ]; then
    # Extrai o valor "Available" em KB e converte para GB
    SPACE_KB=$(echo "$SPACE_INFO" | awk '{print $6}')
    SPACE_GB=$((SPACE_KB / 1024 / 1024))
    
    if [ $SPACE_GB -gt 350 ]; then
      echo "✅ Espaço NVME: ${SPACE_GB}GB disponíveis"
    else
      echo "❌ Espaço NVME insuficiente: ${SPACE_GB}GB (mínimo 350GB)"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "⚠️  Não foi possível verificar espaço NVME"
  fi
else
  echo "❌ Sem acesso SSH ao Proxmox"
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
