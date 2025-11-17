#!/bin/bash
INSTANCE_IP=$(cat exports/converter-instance-ip.txt)

echo "🔄 Monitorando conversão..."
echo "Verificando a cada 2min..."
echo ""

while true; do
  SIZE=$(ssh -i ~/.ssh/id_rsa ubuntu@$INSTANCE_IP 'ls -lh /home/ubuntu/poc-prada.qcow2 2>/dev/null | awk "{print \$5}"' 2>/dev/null || echo "N/A")
  PROCESS=$(ssh -i ~/.ssh/id_rsa ubuntu@$INSTANCE_IP 'pgrep qemu-img' 2>/dev/null)
  
  if [ -n "$PROCESS" ]; then
    echo "[$(date '+%H:%M:%S')] 🔄 Convertendo... Tamanho atual: $SIZE"
  else
    echo ""
    echo "[$(date '+%H:%M:%S')] ✅ Conversão COMPLETA!"
    echo "Tamanho final: $SIZE"
    break
  fi
  
  sleep 120
done
