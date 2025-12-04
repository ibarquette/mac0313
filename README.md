# Sistema de Agendamento de Monitorias

Sistema de banco de dados PostgreSQL para gerenciamento de sessões de tutoria entre alunos e monitores. Implementa um marketplace educacional com sistema de créditos, agendamentos, avaliações e comunicação integrada.

## Objetivo

O projeto modela um sistema completo de monitorias onde alunos podem agendar sessões de ensino com tutores (que também são alunos), gerenciar créditos, realizar pagamentos com descontos baseados em reputação, e avaliar a qualidade do atendimento.

## Arquitetura

### Modelo de Dados

O banco de dados é organizado em camadas hierárquicas:

**Camada Institucional**
- Institutos, cursos e disciplinas
- Relacionamento N:N entre cursos e disciplinas

**Camada de Usuários**
- `aluno`: usuário base com sistema de créditos
- `tutor`: subconjunto de alunos habilitados para ensinar
- `tutor_disciplina`: disciplinas que cada tutor pode lecionar
- `disponibilidade_tutor`: slots de horário disponíveis

**Sistema de Créditos**
- `pacote`: pacotes de créditos com preços
- `aluno_pacote`: histórico de compras
- Conversão: 1 crédito = 30 minutos de monitoria
- Desconto progressivo baseado na média de avaliações do aluno

**Fluxos de Agendamento**
```
pendente → confirmado → concluido
pendente → confirmado → cancelado
pendente → cancelado
```

- `agendamento`: solicitações com status (pendente/confirmado/cancelado/concluido)
- `aula`: criada apenas quando agendamento é marcado como concluído
- `assunto_agendamento` / `assunto_aula`: tópicos abordados
- `aluno_aula`: registro de participantes (suporta aulas em grupo)

**Comunicação e Feedback**
- `chat`: um por agendamento
- `mensagem`: histórico com versionamento
- `avaliacao`: notas de 0 a 5
- `denuncia`: sistema de reports

### Tipos Customizados

```sql
status_agendamento: pendente | confirmado | cancelado | concluido
status_denuncia: aberta | em_analise | fechada
modo_atendimento: online | presencial
```

## Funcionalidades Principais

### Stored Procedures

As operações críticas são implementadas como procedures para garantir integridade:

1. **`criar_agendamento`**: Cria solicitação de monitoria
   - Valida créditos do aluno
   - Verifica disponibilidade do tutor
   - Calcula créditos necessários (duração / 30 min)

2. **`confirmar_agendamento`**: Tutor aceita a solicitação
   - Debita créditos do aluno
   - Credita valor ao tutor

3. **`comprar_pacote`**: Compra de créditos
   - Descontos progressivos por média de avaliação:
     - ≥4.6: 20% de desconto
     - ≥4.1: 15% de desconto
     - ≥3.1: 10% de desconto
     - ≥2.1: 5% de desconto

4. **`finalizar_aula`**: Completa a monitoria
   - Muda status para concluído
   - Cria registro de aula
   - Auto-adiciona solicitante e tutor aos participantes

5. **`cancelar_agendamento`**: Cancela monitoria (com regras de reembolso)

6. **`adicionar_aluno_aula`**: Adiciona participante a aula em grupo

### Triggers

O sistema utiliza 5 triggers para validação:

- Verificação de conflitos de horário
- Validação de transições de status de agendamento
- Validação de localização do agendamento
- Restrição de mensagens apenas em agendamentos confirmados
- Restrição de edição para mensagens deletadas

### Views Analíticas

O sistema fornece 4 views para análises:

1. **`v_ranking_tutores`**: Ranking completo de tutores
   - Aulas concluídas, confirmadas e pendentes
   - Média de avaliações e quantidade de avaliações
   - Total de créditos ganhos

2. **`v_saldo_creditos_aluno`**: Gestão de créditos por aluno
   - Créditos totais disponíveis
   - Créditos reservados (agendamentos pendentes)
   - Créditos efetivamente disponíveis

3. **`v_historico_compras_pacotes`**: Histórico de compras
   - Preço pago vs preço original
   - Percentual de desconto aplicado
   - Avaliação média na época da compra

4. **`v_disciplinas_mais_procuradas`**: Estatísticas por disciplina
   - Quantidade de tutores disponíveis
   - Total de agendamentos e aulas concluídas
   - Média de avaliação da disciplina

## Configuração

### Pré-requisitos

- PostgreSQL 12+
- Python 3.8+ (para scripts de população)
- Dependências Python: pandas, sqlalchemy

### Instalação e População

**IMPORTANTE**: A ordem de execução é crítica. O banco deve ser populado ANTES de adicionar os triggers, caso contrário muitos registros serão rejeitados pelas validações.

```bash
# 1. Instalar dependências Python
pip install -r requirements.txt

# 2. Criar schema base
psql -U postgres -d nome_banco -f schema.sql

# 3. Popular banco de dados (PRIMEIRO!)
python populate_local.py
# O script é interativo e solicitará as credenciais do banco

# 4. Aplicar triggers (DEPOIS da população)
psql -U postgres -d nome_banco -f all_triggers.sql

# 5. Aplicar stored procedures
psql -U postgres -d nome_banco -f all_stored_procedures.sql

# 6. Aplicar views analíticas
psql -U postgres -d nome_banco -f all_views.sql
```

### Ordem de População (Automática)

O script `populate_local.py` respeita automaticamente a ordem correta de inserção:

```
instituto → numero_instituto → disciplina → curso → curso_disciplina →
aluno → tutor → tutor_disciplina → disponibilidade_tutor →
pacote → aluno_pacote → agendamento → aula →
assunto_agendamento → assunto_aula → chat → chat_aluno →
mensagem → avaliacao → denuncia → aluno_aula
```

## Estrutura de Arquivos

```
/
├── schema.sql                    # Definição completa do schema (21 tabelas)
├── all_triggers.sql              # Todos os triggers (5 triggers)
├── all_stored_procedures.sql     # Todas as procedures (6 procedures)
├── all_views.sql                 # Todas as views (4 views analíticas)
├── consultas.sql                 # 15 consultas de exemplo
├── operacoes.sql                 # 15 operações de exemplo
├── stored_procedures/            # Procedures individuais (análise detalhada)
├── triggers/                     # Triggers por módulo (análise detalhada)
├── populate_local.py             # Script de população (interativo)
├── dados_populacao.zip           # CSVs das 21 tabelas
├── requirements.txt              # Dependências Python (pandas, sqlalchemy)
├── TRIGGERS.md                   # Documentação completa dos triggers
├── STORED_PROCEDURES.md          # Documentação completa das procedures
├── analise_dados.qmd             # Análise estatística (Quarto)
└── analise_dados.pdf             # Análise estatística renderizada
```

## Regras de Negócio

### Créditos
- Saldo mínimo: 0 créditos
- Conversão fixa: 1 crédito = 30 minutos
- Duração mínima de agendamento: 30 minutos

### Transições de Status
- `pendente` pode ir para `confirmado` ou `cancelado`
- `confirmado` pode ir para `concluido` ou `cancelado`
- `concluido` e `cancelado` são estados finais

### Validações
- Horários: `h_inicio < h_fim`
- Modo presencial exige localização
- Modo online deve ter localização NULL
- Mensagens apenas em agendamentos confirmados
- Tutor não pode ter agendamentos sobrepostos

### Sistema de Desconto
- Aluno paga valor com desconto baseado em sua reputação
- Tutor recebe valor integral do crédito
- Desconto é aplicado no momento da compra do pacote
- Durante confirmação do agendamento, ambos recebem/pagam o mesmo valor em créditos

## Observações Importantes

### Limitações Conhecidas

**Criação de Agendamentos após População**: A stored procedure `criar_agendamento` pode gerar conflitos de ID após o banco ser populado, pois o ID do agendamento é SERIAL (auto-incremento). A procedure tentará inserir com IDs que já existem até encontrar um válido.

### Pastas de Análise

As pastas `stored_procedures/` e `triggers/` contêm os arquivos SQL separados por funcionalidade, facilitando análise e modificação individual. Para aplicação em produção, utilize os arquivos consolidados (`all_*.sql`).

## Consultas e Operações

O projeto inclui:
- **15 consultas SQL** (`consultas.sql`): Queries para análise e extração de dados
- **15 operações** (`operacoes.sql`): Exemplos de uso das stored procedures
- **Análise estatística** (`analise_dados.qmd/.pdf`): Análise exploratória dos dados populados

## Tecnologias

- **PostgreSQL 12+**: Sistema gerenciador de banco de dados
- **PL/pgSQL**: Linguagem para stored procedures e triggers
- **Python 3.8+**: Scripts de população
  - pandas: Manipulação de dados CSV
  - sqlalchemy: Conexão com banco de dados
- **Quarto**: Análise estatística e geração de relatórios

## Projeto Acadêmico

Desenvolvido para a disciplina MAC0313 - Introdução a Sistemas de Banco de Dados.
