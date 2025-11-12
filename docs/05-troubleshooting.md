# Troubleshooting - Migração poc_prada

## 🆘 Guia de Resolução de Problemas

---

## 🔴 Fase 1-2: Snapshot e AMI

### Erro: "You are not authorized to perform this operation"

**Causa**: Permissões IAM insuficientes

**Solução**:
```bash
# Verificar identity
aws sts get-caller-identity

# Verificar permissions necessárias:
# - ec2:CreateSnapshot
# - ec2:RegisterImage
# - ec2:DescribeSnapshots
# - ec2:DescribeImages

# Solicitar ao admin AWS ajuste de permissões
```

### Erro: Snapshot fica stuck em "pending"

**Causa**: Volume muito grande ou AWS API lenta

**Solução**:
```bash
# Aguardar até 60 minutos
# Monitorar:
watch -n 60 'aws ec2 describe-snapshots --snapshot-ids snap-XXXXX --query "Snapshots[0].Progress"'

# Se >2h sem progresso, cancelar e retentar:
aws ec2 delete-snapshot --snapshot-id snap-XXXXX
```

---

## 🔴 Fase 3: Export S3

### Erro: "InvalidRole" ao exportar AMI

**Causa**: Role `vmimport` não existe ou mal configurada

**Solução**: Ver seção completa em `docs/02-pre-requisitos.md` → "Problema: Role vmimport não existe"

### Erro: Export task falha com "ClientError"

**Causa**: Bucket S3 sem permissões adequadas para vmimport

**Solução**:
```bash
# Verificar bucket policy
aws s3api get-bucket-policy --bucket migracao-ec2-proxmox

# Adicionar policy se necessário:
cat > /tmp/bucket-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "vmimport",
      "Effect": "Allow",
      "Principal": {
        "Service": "vmie.amazonaws.com"
      },
      "Action": [
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::migracao-ec2-proxmox",
        "arn:aws:s3:::migracao-ec2-proxmox/*"
      ]
    }
  ]
}
POLICY

aws s3api put-bucket-policy \
  --bucket migracao-ec2-proxmox \
  --policy file:///tmp/bucket-policy.json
```

### Export extremamente lento

**Causa**: Disco grande (300GB) + network AWS

**Solução**: **Normal!** Export de 300GB pode levar 90-120min. Monitorar progresso:
```bash
while true; do
  aws ec2 describe-export-image-tasks \
    --export-image-task-ids $EXPORT_TASK_ID \
    --query 'ExportImageTasks[0].[Status,Progress,StatusMessage]' \
    --output table
  sleep 300  # Check cada 5min
done
```

---

## 🔴 Fase 4: Download e Conversão

### Download do S3 muito lento

**Causa**: Bandwidth WSL → AWS limitado

**Solução**: Usar EC2 temporária na mesma região
```bash
# Criar EC2 micro temporária us-east-1
# SSH na EC2 temp
aws s3 cp s3://migracao-ec2-proxmox/exports/poc-prada/ . --recursive

# Depois transferir via scp para seu WSL (rede AWS é rápida)
```

### Erro: "qemu-img: Could not open" ao converter

**Causa**: Arquivo VMDK corrompido ou incompleto

**Solução**:
```bash
# Verificar integridade
file exports/temp/*.vmdk
# Deve mostrar: "VMware4 disk image"

# Verificar tamanho vs S3
aws s3 ls s3://migracao-ec2-proxmox/exports/poc-prada/ --recursive \
  | grep vmdk

# Comparar tamanhos - devem ser idênticos
# Se diferente, re-download
```

### Conversão VMDK→QCOW2 falha

**Causa**: Espaço insuficiente ou formato VMDK não suportado

**Solução**:
```bash
# Verificar espaço
df -h exports/

# Tentar conversão com opções alternativas
qemu-img convert -f vmdk -O qcow2 \
  -o compat=1.1 \
  exports/temp/disk.vmdk \
  exports/poc-prada.qcow2

# Se persistir, tentar formato intermediário
qemu-img convert -f vmdk -O raw exports/temp/disk.vmdk exports/disk.raw
qemu-img convert -f raw -O qcow2 exports/disk.raw exports/poc-prada.qcow2
rm exports/disk.raw
```

---

## 🔴 Fase 5-6: Proxmox

### SCP para Proxmox falha / muito lento

**Causa**: Arquivo grande (>100GB)

**Solução**: Usar `rsync` com progresso
```bash
rsync -avzP --partial \
  exports/poc-prada.qcow2 \
  root@192.168.100.10:/var/lib/vz/images/

# Se interromper, reexecutar - continua de onde parou
```

### VM não aparece após `qm create`

**Causa**: VMID já existe ou erro no comando

**Solução**:
```bash
# Listar VMs
qm list | grep 103

# Se existir, remover
qm destroy 103

# Recriar com comando correto
qm create 103 --name poc-prada --memory 16384 --cores 4
```

### Erro: "unable to parse volume" ao importdisk

**Causa**: Arquivo QCOW2 em local errado ou corrompido

**Solução**:
```bash
# Verificar arquivo
ls -lh /var/lib/vz/images/poc-prada.qcow2
qemu-img info /var/lib/vz/images/poc-prada.qcow2

# Mover para pasta correta se necessário
mv /var/lib/vz/images/poc-prada.qcow2 /var/lib/vz/images/poc-prada.qcow2

# Importar novamente
qm importdisk 103 /var/lib/vz/images/poc-prada.qcow2 NVME
```

### VM não inicia - "no bootable device"

**Causa**: Disco não configurado como boot

**Solução**:
```bash
# Configurar boot
qm set 103 --boot order=scsi0
qm set 103 --bootdisk scsi0

# Verificar
qm config 103 | grep boot

# Reiniciar
qm stop 103
qm start 103
```

### Console não mostra nada após boot

**Causa**: Serial console não configurado

**Solução**:
```bash
# Configurar serial
qm set 103 --serial0 socket --vga serial0

# Ou usar VNC
qm set 103 --vga std

# Acessar via Proxmox UI
```

---

## 🔴 Pós-Migração: Rede

### Interface de rede não sobe

**Causa**: Driver virtio não carregado ou nome interface mudou

**Solução**:
```bash
# Dentro da VM via console
# Listar interfaces
ip link show

# Identificar nome (ex: ens18)
# Editar netplan com nome correto
sudo nano /etc/netplan/50-cloud-init.yaml

# Aplicar
sudo netplan apply
```

### DNS não resolve

**Causa**: Nameservers não configurados

**Solução**:
```bash
# Verificar resolv.conf
cat /etc/resolv.conf

# Configurar manualmente se necessário
sudo nano /etc/netplan/50-cloud-init.yaml

# Adicionar:
nameservers:
  addresses:
    - 187.108.193.3
    - 187.108.193.4

sudo netplan apply
```

### Sem acesso SSH externo

**Causa**: Firewall Proxmox ou VM bloqueando

**Solução**:
```bash
# No Proxmox node
# Verificar regras firewall
pvesh get /nodes/sp1-sd-gt4w-1/firewall/rules

# Dentro da VM
sudo ufw status
sudo ufw allow 22/tcp
```

---

## 🔴 Erros Diversos

### "No space left on device"

**Onde**: Durante download VMDK ou conversão

**Solução**:
```bash
# Limpar espaço
rm -rf exports/temp/*.vmdk  # Após conversão
docker system prune -a      # Se Docker instalado
sudo apt clean
sudo apt autoremove
```

### AWS CLI timeout

**Onde**: Durante describe-export-image-tasks

**Solução**:
```bash
# Aumentar timeout
aws configure set cli_read_timeout 300

# Ou usar --cli-read-timeout
aws ec2 describe-export-image-tasks \
  --cli-read-timeout 300 \
  --export-image-task-ids $EXPORT_TASK_ID
```

### SSH connection refused (Proxmox)

**Causa**: SSH desabilitado ou firewall

**Solução**:
```bash
# Via console físico Proxmox (se possível)
systemctl start sshd
systemctl enable sshd

# Ajustar firewall
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
```

---

## 📊 Logs Úteis

### AWS
```bash
# CloudTrail (se habilitado)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=i-06dffc5a34a6c60fbe \
  --max-results 50
```

### Proxmox
```bash
# Logs sistema
tail -f /var/log/syslog

# Logs VM específica
qm log 103

# Logs PVE daemon
journalctl -u pvedaemon -f
```

### Dentro da VM
```bash
# Logs boot
sudo journalctl -b

# Logs serviços
sudo journalctl -u nginx -f     # Exemplo

# Logs sistema
sudo tail -f /var/log/syslog
```

---

## 🆘 Rollback - Se Tudo Falhar

### Cenário: Migração falhou completamente

**Plano B**: Religar EC2 original
```bash
# AWS - Restart EC2
aws ec2 start-instances --instance-ids i-06dffc5a34a6c60fbe

# Aguardar inicialização
aws ec2 wait instance-running --instance-ids i-06dffc5a34a6c60fbe

# Verificar IP público
aws ec2 describe-instances \
  --instance-ids i-06dffc5a34a6c60fbe \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text

# Testar SSH
ssh -i ~/.ssh/poc_prada.pem ubuntu@<PUBLIC_IP>
```

**⚠️ IMPORTANTE**: EC2 original NÃO foi alterada durante migração - dados seguros!

---

## 📞 Escalar Problema

Se após troubleshooting não resolver:

1. **Documentar erro**:
   - Screenshot do erro
   - Comando executado
   - Output completo
   - Logs relevantes

2. **Criar issue no repositório**:
```bash
   # Link: https://github.com/solon07/migracao-poc-prada/issues
```

3. **Contatar Pedro Magalhães** (Slack/Email)

4. **Consultar documentação AWS**:
   - VM Import/Export: https://docs.aws.amazon.com/vm-import/
   - EC2 Troubleshooting: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-troubleshoot.html

5. **Comunidade Proxmox**:
   - Forum: https://forum.proxmox.com
   - Wiki: https://pve.proxmox.com/wiki/Main_Page
