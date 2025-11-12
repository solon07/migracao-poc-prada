# Planejamento - Migração poc_prada

## 📅 Cronograma Estimado

| Fase | Atividade | Duração | Dependências |
|------|-----------|---------|--------------|
| 1 | Preparação e backup | 30min | EC2 stopped ✅ |
| 2 | Snapshot + AMI | 45min | Fase 1 |
| 3 | Export S3 | 60-90min | Fase 2 |
| 4 | Download + Conversão | 30-60min | Fase 3 |
| 5 | Criação VM Proxmox | 20min | Fase 4 |
| 6 | Config + Validação | 40min | Fase 5 |
| **TOTAL** | **~4-5h** | - | - |

## 🎯 Objetivos

### Primário
- [ ] Migrar EC2 poc_prada para VM funcional no Proxmox
- [ ] Manter configurações de rede e serviços
- [ ] Documentar processo completo

### Secundário
- [ ] Reduzir custo AWS (~$150/mês → $0)
- [ ] Criar runbook reproduzível
- [ ] Atualizar base conhecimento Claude

## ⚠️ Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Export AMI falhar | Baixa | Alto | Validar permissions IAM antes |
| Conversão VMDK corrompida | Média | Alto | Verificar checksum pós-download |
| Rede não funcionar pós-migração | Média | Médio | Documentar configs atuais |
| Espaço NVME insuficiente | Baixa | Alto | Verificar ~350GB livres |

## 📊 Estimativa de Recursos

### AWS S3
- **Espaço necessário**: ~100-150GB (AMI + export temp)
- **Tempo upload**: ~60-90min
- **Custo estimado**: ~$3-5 (temporário)

### Proxmox NVME
- **Espaço necessário**: ~300GB (imagem convertida)
- **Espaço disponível**: 1.56TB ✅

## 👥 Responsáveis
- **Execução**: Mateus Sturm
- **Validação**: Pedro Magalhães
- **Suporte**: Equipe Infra YOUX
