# Migração EC2 poc_prada → Proxmox VE

## 📊 Status: 🟡 Em Planejamento

### Objetivo
Migrar instância EC2 `poc_prada` (i-06dffc5a34a6c60fbe) para VM no Proxmox VE node `sp1-sd-gt4w-1`.

### Specs Origem (EC2)
- **Tipo**: t3.xlarge (4 vCPUs, ~16GB RAM)
- **OS**: Ubuntu 24.04 LTS (Noble)
- **Storage**: 300GB EBS
- **Status Atual**: Interrompido ✅

### Specs Destino (Proxmox)
- **VMID**: 103 (proposta)
- **Storage**: NVME
- **CPU**: 4 cores
- **RAM**: 16GB
- **Rede**: eth0 estático

### Referências
- Issue GitLab: #1794
- Migração Base 1: #1757 (chronos)
- Migração Base 2: #1755 (gitlab-runner-01)

### Timeline
- **Criação**: 12/11/2025
- **Previsão**: A definir
- **Conclusão**: -

---

## 📁 Estrutura do Projeto
```
migracao-poc-prada/
├── README.md                 # Este arquivo
├── docs/
│   ├── 01-planejamento.md   # Planejamento detalhado
│   ├── 02-pre-requisitos.md # Checklist pré-migração
│   ├── 03-runbook.md        # Passo a passo executável
│   ├── 04-pos-migracao.md   # Validações e configurações
│   └── 05-troubleshooting.md
├── scripts/
│   ├── backup-configs.sh    # Backup configurações EC2
│   ├── create-snapshot.sh   # Criar snapshot
│   ├── export-ami.sh        # Exportar AMI para S3
│   └── convert-vmdk.sh      # Conversão VMDK→QCOW2
├── exports/                 # AMI/VMDK exportados
├── assets/
│   └── screenshots/         # Prints de evidência
└── config/
    ├── ec2-specs.json       # Especificações EC2
    ├── proxmox-config.json  # Config destino Proxmox
    └── network-config.yaml  # Configuração rede
```

---

## 🔗 Links Rápidos
- [Runbook Completo](docs/03-runbook.md)
- [Issue GitLab #1794](https://gitlab.com/youx-group/infraestrutura/documentacao-infra/-/issues/1794)
- [AWS Console - poc_prada](https://console.aws.amazon.com/ec2/home?region=us-east-1#InstanceDetails:instanceId=i-06dffc5a34a6c60fbe)
- [Proxmox VE - sp1-sd-gt4w-1](https://192.168.100.10:8006)
