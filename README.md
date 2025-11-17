# Migração EC2 poc_prada → Proxmox VE

## 📊 Status: ✅ **CONCLUÍDA** - 17/11/2025

### Objetivo
Migrar instância EC2 `poc_prada` (i-06dfc5a34a6c60fbe) para VM no Proxmox VE node `sp1-sd-gt4w-1`.

---

## ✅ Resultado Final

### Especificações VM Migrada
- **VMID**: 105
- **Nome**: poc-prada
- **Node**: sp1-sd-gt4w-1
- **IP**: 192.168.100.16/24
- **CPU**: 4 cores (KVM/QEMU)
- **RAM**: 16GB
- **Disco**: 300GB (NVME:105/vm-105-disk-1.raw)
- **OS**: Ubuntu 24.04.3 LTS (kernel 6.14.0-1016-aws)

### Serviços Validados ✅
- **Docker**: 5 containers rodando
  - `prada_core` - Backend (porta 8000)
  - `prada_ui` - Frontend (porta 3000)
  - `n8n` - Automação (porta 5678)
  - `postgres` - Database (porta 5432 interna)
  - `qgis-server` - GIS (porta 5555)
- **SSH**: Acesso externo funcional (chave + senha)
- **Rede**: IP estático, DNS resolvendo, internet OK
- **QEMU Guest Agent**: Ativo e comunicando com Proxmox

---

## 📈 Métricas da Migração

### Tempo Execução
- **Planejamento**: ~2h
- **Snapshot/Conversão**: ~4h
- **Upload/Criação VM**: ~1h30
- **Troubleshooting SSH**: ~15min
- **Validações finais**: ~45min
- **Total**: ~8h30min

### Estratégia Utilizada
Após falhas consecutivas com AWS Export AMI (travando em 80%), adotamos conversão direta:
1. Snapshot EBS → Volume temporário
2. Anexar volume a EC2 converter (i-0cdea8633067259d8)
3. Conversão RAW → QCOW2 comprimido (300GB → 103GB)
4. Upload rsync para Proxmox
5. Import disk com `qm importdisk`

### Problemas Resolvidos
1. **Export AMI AWS**: Substituído por conversão direta via EC2 temporária
2. **SSH Autenticação**: Cloud-init drop-in sobrescrevendo configs - removido `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`
3. **Espaço Proxmox**: Limpeza prévia liberou ~400GB no NVME

---

## 📊 Specs Origem vs Destino

| Componente | EC2 (t3.xlarge) | Proxmox VM 105 | Status |
|------------|-----------------|----------------|--------|
| **CPU** | 4 vCPUs Intel | 4 cores KVM | ✅ Equivalente |
| **RAM** | 16GB | 16GB | ✅ Equivalente |
| **Disco (IOPS)** | 3000 (gp3) | 50000+ (NVME) | ✅ **Melhor** |
| **Latência** | Variable cloud | <1ms local | ✅ **Melhor** |
| **Network** | 5 Gbps | 1 Gbps | ⚠️ Reduzido |
| **Custo/mês** | ~$150 USD | $0 | 💰 **100% economia** |

---

## 🔗 Documentação Completa

### Estrutura do Projeto
```
migracao-poc-prada/
├── README.md                    # Este arquivo
├── docs/
│   ├── 01-planejamento.md      # Cronograma e objetivos
│   ├── 02-pre-requisitos.md    # Checklist validações
│   ├── 03-runbook.md           # ⭐ Passo a passo executável
│   ├── 04-pos-migracao.md      # Configurações pós-migração
│   ├── 05-troubleshooting.md   # Resolução de problemas
│   └── SOLUCAO-SSH.md          # Fix cloud-init SSH
├── scripts/
│   ├── validate-prerequisites.sh
│   ├── backup-configs.sh
│   └── (outros scripts auxiliares)
├── assets/
│   └── screenshots/
│       └── pos-migracao/       # Evidências visuais
├── exports/
│   ├── ec2-full-details.json
│   ├── security-groups.json
│   └── volume-details.json
└── config/
    ├── ec2-specs.json
    └── proxmox-config.json
```

### Links Importantes
- **Issue GitLab**: [#1794](https://gitlab.com/youx-group/infraestrutura/documentacao-infra/-/issues/1794)
- **Repositório**: https://github.com/solon07/migracao-poc-prada
- **Proxmox**: https://192.168.100.10:8006 (VM 105)
- **AWS Console**: [poc_prada original](https://console.aws.amazon.com/ec2/home?region=us-east-1#InstanceDetails:instanceId=i-06dfc5a34a6c60fbe)

---

## 🎓 Lições Aprendidas

### ✅ O que Funcionou Bem
1. **Conversão Direta**: Usar EC2 temporária para conversão RAW→QCOW2 foi mais rápido e confiável que Export AMI
2. **Compressão QCOW2**: Reduziu arquivo de 300GB para 103GB, economizando ~65% de espaço e tempo de upload
3. **NVME Local**: Performance de disco muito superior ao EBS (50000+ IOPS vs 3000)
4. **Documentação Prévia**: Runbooks das migrações anteriores (chronos, gitlab-runner) agilizaram processo
5. **Cloud-init Disable**: Desabilitar gestão SSH evitou problemas futuros após updates

### ⚠️ Desafios Enfrentados
1. **AWS Export AMI Não Confiável**: Falhou consistentemente em 80% (converting) para volumes >100GB
2. **Cloud-init Sobrescrevendo Configs**: Drop-ins em `/etc/ssh/sshd_config.d/` têm precedência - sempre verificar
3. **Tempo Estimado**: Planejamos 4-5h mas levou ~8h30 devido a troubleshooting export

### 🔧 Melhorias para Próximas Migrações
1. **Partir direto para conversão EC2** em vez de tentar Export AMI para volumes >100GB
2. **Verificar drop-ins SSH** antes de editar arquivo principal (`ls /etc/ssh/sshd_config.d/`)
3. **Adicionar 30% de margem** nas estimativas de tempo para troubleshooting
4. **Automatizar limpeza cloud-init** com script pós-migração

---

## 📋 Recursos AWS Mantidos (Limpeza Pendente)

**⚠️ Aguardar 1 semana de validação antes de deletar:**

### AWS (us-east-1)
- ✅ **EC2 Converter**: i-0cdea8633067259d8 - **TERMINADA** ✅
- ⏳ **Snapshot**: snap-06362f3ce47c6ea1b (300GB) - Aguardando validação
- ⏳ **Volume**: vol-03c709a634de2aeba (300GB) - Aguardando validação  
- ⏳ **Bucket S3**: s3://migracao-ec2-proxmox/exports/ - Aguardando validação
- ⏳ **EC2 Original**: i-06dfc5a34a6c60fbe (stopped) - Aguardando validação

**Limpeza prevista para**: ~24/11/2025 (após 1 semana validação)

---

## 👤 Créditos

- **Planejamento**: Mateus Sturm
- **Execução**: Mateus Sturm  
- **Revisão**: Pedro Magalhães (pendente)
- **Suporte**: Equipe Infra YOUX GROUP
- **Baseado em**: Migrações anteriores chronos (#1757) e gitlab-runner-01 (#1755)

---

## 📞 Contato

**Mateus Sturm**  
Estagiário DevOps/Infra  
YOUX GROUP  
Email: mateus@youxgroup.com  
GitLab: @Mateus_Sturm

---

**Data Conclusão**: 17/11/2025 17:35 BRT  
**Versão**: 1.0 - Migração Concluída ✅
