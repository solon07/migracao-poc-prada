# Base de Conhecimento - Projeto Migração poc_prada

## 📖 Sobre Este Projeto

Documentação e execução da migração da instância EC2 `poc_prada` (AWS) para VM no Proxmox VE on-premise, seguindo processo validado nas migrações anteriores de `chronos` (#1757) e `gitlab-runner-01` (#1755).

---

## 🎯 Contexto Geral

### Objetivo da Migração
- **Redução de custos**: EC2 t3.xlarge custa ~$150/mês
- **Consolidação infra**: Centralizar VMs no Proxmox YOUX
- **Performance**: Storage NVME local vs EBS remoto

### Histórico de Migrações
1. **gitlab-runner-01** (Issue #1755) - ✅ Concluída 3 semanas atrás
   - VMID: 101
   - Tempo: ~5h
   - Lições: Validar IAM role vmimport antes de export
   
2. **chronos** (Issue #1757) - ✅ Concluída 2 semanas atrás
   - VMID: 102  
   - Tempo: ~5h
   - Credenciais documentadas no GitLab

---

## 🔧 Especificações Técnicas

### EC2 Origem
```json
{
  "instance_id": "i-06dfc5a34a6c60fbe",
  "name": "poc_prada",
  "type": "t3.xlarge",
  "vcpus": 4,
  "ram": "~16GB",
  "storage": "300GB gp3",
  "os": "Ubuntu 24.04 LTS Noble",
  "status": "stopped",
  "ip_public": "3.226.123.214",
  "ip_private": "172.31.87.181"
}
```

### Proxmox Destino
```json
{
  "node": "sp1-sd-gt4w-1",
  "vmid_proposto": 103,
  "storage": "NVME",
  "espaco_disponivel": "~1.56TB",
  "espaco_necessario": "~300GB",
  "acesso": "https://192.168.100.10:8006"
}
```

---

## 📋 Processo de Migração (Resumo)

### Fases
1. **Preparação** (30min)
   - Backup configs EC2
   - Validar pré-requisitos
   - Documentar serviços

2. **Snapshot + AMI** (45min)
   - Criar snapshot volume EBS
   - Registrar AMI do snapshot
   - Validar disponibilidade

3. **Export S3** (60-90min)
   - Export AMI formato VMDK
   - Upload bucket `migracao-ec2-proxmox`
   - Monitorar progresso

4. **Download + Conversão** (30-60min)
   - Download VMDK do S3
   - Converter VMDK → QCOW2
   - Validar integridade

5. **Criação VM** (20min)
   - Upload QCOW2 para Proxmox
   - Criar VM VMID 103
   - Importar disco

6. **Config Pós-Migração** (40min)
   - Configurar rede estática
   - Instalar qemu-guest-agent
   - Validar serviços

### Tempo Total Estimado
**4-5 horas** (execução + validações)

---

## ⚠️ Pontos Críticos

### Armadilhas Conhecidas
1. **IAM Role vmimport**: Verificar existência ANTES de export
2. **Tamanho S3**: AMI pode ocupar 1.5-2x tamanho disco (gzip)
3. **Conversão VMDK**: Sempre validar checksum pós-download
4. **Rede Proxmox**: IP estático deve ser configurado manualmente

### Validações Obrigatórias
- [ ] EC2 stopped antes snapshot
- [ ] Snapshot completado (não pending)
- [ ] Export task status = completed
- [ ] QCOW2 passa em `qemu-img check`
- [ ] VM boota no primeiro start
- [ ] Rede configurada e pingando

---

## 📊 Recursos AWS Necessários

### Permissões IAM
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:CreateSnapshot",
    "ec2:RegisterImage",
    "ec2:ExportImage",
    "ec2:DescribeImages",
    "ec2:DescribeSnapshots",
    "ec2:DescribeExportImageTasks",
    "s3:PutObject",
    "s3:GetObject",
    "s3:ListBucket"
  ],
  "Resource": "*"
}
```

### Bucket S3
- **Nome**: `migracao-ec2-proxmox`
- **Região**: us-east-1
- **Estrutura**: `/exports/poc-prada/`

---

## 🔗 Links Importantes

- **Issue GitLab**: [#1794](https://gitlab.com/youx-group/infraestrutura/documentacao-infra/-/issues/1794)
- **Runbook Completo**: `docs/03-runbook.md`
- **AWS Console EC2**: [poc_prada](https://console.aws.amazon.com/ec2/home?region=us-east-1#InstanceDetails:instanceId=i-06dfc5a34a6c60fbe)
- **Proxmox**: https://192.168.100.10:8006

---

## 🎓 Lições das Migrações Anteriores

### Do que funcionou (chronos/gitlab-runner)
- ✅ Validar IAM role ANTES de iniciar export
- ✅ Monitorar export task com loop automatizado
- ✅ Sempre fazer `qemu-img check` pós-conversão
- ✅ Documentar credenciais imediatamente pós-boot
- ✅ Manter EC2 stopped durante todo processo

### Do que melhorar
- ⚠️ Não deletar EC2 original até 1 semana de validação
- ⚠️ Sempre testar SSH antes de fechar issue
- ⚠️ Documentar portas abertas no security group

---

## 🆘 Troubleshooting Rápido

| Problema | Causa Provável | Solução |
|----------|----------------|---------|
| Export falha "InvalidRole" | Role vmimport inexistente | Criar role com trust policy |
| Download S3 lento | Bandwidth limitado | Executar de máquina AWS (EC2 temp) |
| VM não boota | Disco não configurado como boot | `qm set 103 --boot c --bootdisk scsi0` |
| Rede não funciona | Config netplan incorreta | Validar YAML syntax, aplicar netplan |
| QEMU agent offline | Não instalado na VM | `apt install qemu-guest-agent` |

---

## 📝 Comandos Úteis

### AWS CLI
```bash
# Status EC2
aws ec2 describe-instances --instance-ids i-06dfc5a34a6c60fbe \
  --query 'Reservations[0].Instances[0].State.Name' --output text

# Listar exports ativos
aws ec2 describe-export-image-tasks \
  --query 'ExportImageTasks[?Status!=`completed`]'

# Verificar bucket S3
aws s3 ls s3://migracao-ec2-proxmox/exports/ --recursive --human-readable
```

### Proxmox CLI
```bash
# Listar VMs
qm list

# Info VM específica
qm config 103

# Logs console
qm terminal 103

# Espaço storage
pvesm status
```

---

## 📦 Estrutura de Arquivos

### Exports Importantes
- `exports/ec2-full-details.json` - Backup completo specs EC2
- `exports/snapshot-id.txt` - ID snapshot criado
- `exports/ami-id.txt` - ID AMI registrada
- `exports/export-task-id.txt` - ID task export S3
- `exports/poc-prada.qcow2` - Imagem convertida (NÃO versionar)

### Documentação
- `docs/01-planejamento.md` - Cronograma e objetivos
- `docs/03-runbook.md` - ⭐ Passo a passo executável
- `docs/05-troubleshooting.md` - Resolução problemas

### Configs
- `config/ec2-specs.json` - Especificações origem
- `config/proxmox-config.json` - Configuração destino
- `config/network-config.yaml` - Template netplan

---

## 🔄 Status Atual

**Data**: 12/11/2025  
**Fase**: 🟡 Planejamento  
**Progresso**: 0% (setup inicial completo)  
**Próximo Step**: Executar `scripts/backup-configs.sh`

---

## 👤 Contatos

- **Executor**: Mateus Sturm (@Mateus_Sturm)
- **Revisor**: Pedro Magalhães
- **Suporte**: Equipe Infra YOUX

