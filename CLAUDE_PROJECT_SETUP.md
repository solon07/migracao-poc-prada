# Setup Claude Project - Migração poc_prada

## 🎯 Instruções para Configurar

### 1. Criar Novo Projeto Claude

1. Acesse Claude.ai
2. Clique em "Projects" (barra lateral)
3. "New Project"
4. **Nome**: `Migração poc_prada - EC2 → Proxmox`
5. **Descrição**: `Migração completa da instância AWS EC2 poc_prada (i-06dffc5a34a6c60fbe) para VM no Proxmox VE, com documentação runbook completo e scripts auxiliares`

### 2. Adicionar Arquivos à Base de Conhecimento

**Ordem recomendada** (arrastar arquivos nesta sequência):

1. ✅ `CLAUDE_PROJECT_KNOWLEDGE.md` (contexto geral)
2. ✅ `README.md` (overview projeto)
3. ✅ `docs/01-planejamento.md`
4. ✅ `docs/02-pre-requisitos.md`
5. ✅ `docs/03-runbook.md` ⭐ **PRINCIPAL**
6. ✅ `docs/04-pos-migracao.md`
7. ✅ `docs/05-troubleshooting.md`
8. ✅ `config/ec2-specs.json`
9. ✅ `config/proxmox-config.json`
10. ✅ Screenshots relevantes de `assets/screenshots/`

**⚠️ Limite**: Max ~200k tokens. Priorizar arquivos 1-7 se atingir limite.

### 3. Configurar Custom Instructions (Opcional)

Cole no campo "Custom Instructions" do projeto:
```
Você é um assistente especializado em migrações AWS EC2 → Proxmox VE. Este projeto documenta a migração da instância poc_prada.

CONTEXTO:
- Instância: EC2 i-06dffc5a34a6c60fbe (t3.xlarge, Ubuntu 24.04, 300GB)
- Destino: Proxmox node sp1-sd-gt4w-1, VMID 103
- Processo: Snapshot → AMI → Export S3 → Convert QCOW2 → Import Proxmox
- Referências: Migrações anteriores chronos (#1757) e gitlab-runner-01 (#1755)

COMPORTAMENTO:
- Sempre referenciar runbook (docs/03-runbook.md) para passos detalhados
- Incluir comandos completos e copiáveis
- Alertar sobre validações obrigatórias antes de cada fase crítica
- Consultar troubleshooting (docs/05-troubleshooting.md) para erros conhecidos
- Manter tom técnico, direto e orientado a ação

NUNCA:
- Pular validações de segurança (EC2 stopped, checksums, etc)
- Sugerir deletar recursos AWS antes de 1 semana de validação
- Assumir que pré-requisitos foram atendidos sem confirmar

SEMPRE:
- Confirmar fase atual da migração antes de orientar próximo passo
- Fornecer tanto comando quanto validação esperada
- Citar seção específica do runbook ao orientar
- Perguntar status do último comando antes de prosseguir
```

### 4. Testar Projeto

Perguntas de teste para validar conhecimento:

1. **"Qual o status atual da migração?"**
   - Esperado: Citar fase do README (Planejamento) e sugerir próximo passo

2. **"Como criar o snapshot?"**
   - Esperado: Referenciar Runbook Fase 2, comandos completos + validação

3. **"Erro: InvalidRole ao exportar AMI"**
   - Esperado: Consultar troubleshooting, fornecer solução role vmimport

4. **"Preciso configurar a rede pós-migração"**
   - Esperado: Referenciar docs/04-pos-migracao.md, template netplan

### 5. Workflow Recomendado

1. **Abrir projeto Claude** sempre que trabalhar na migração
2. **Iniciar sessão** com: "Status atual da migração poc_prada"
3. **Executar comandos** do runbook
4. **Reportar resultado** a Claude para continuar guidance
5. **Documentar desvios** caso algo não saia conforme esperado

---

## 🔗 Links Úteis

- **Repositório**: https://github.com/solon07/migracao-poc-prada
- **Issue GitLab**: https://gitlab.com/youx-group/infraestrutura/documentacao-infra/-/issues/1794
- **Runbook**: `docs/03-runbook.md`
- **AWS Console**: https://console.aws.amazon.com/ec2/home\?region\=us-east-1\#InstanceDetails:instanceId\=i-06dffc5a34a6c60fbe

---

## ✅ Checklist Setup Claude Project

- [ ] Projeto criado com nome correto
- [ ] CLAUDE_PROJECT_KNOWLEDGE.md adicionado
- [ ] README.md adicionado
- [ ] Todos docs/*.md adicionados
- [ ] Configs JSON adicionados
- [ ] Custom instructions configuradas (opcional)
- [ ] Projeto testado com perguntas validação
- [ ] Repositório GitHub linkado nas instruções

**Após setup**: Começar migração executando `./scripts/backup-configs.sh`
