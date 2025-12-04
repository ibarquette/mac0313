# Documentação dos Triggers

Este documento descreve em detalhes todos os triggers do sistema de agendamento de monitorias.

---

## 1. trigger_validar_localizacao

### Descrição
Valida se a localização está preenchida corretamente de acordo com o modo de atendimento escolhido.

### Tabela
agendamento

### Momento
BEFORE INSERT OR UPDATE

### Regras de Negócio
1. Se o modo de atendimento é 'presencial', o campo localização deve estar preenchido e não pode ser NULL ou string vazia
2. Se o modo de atendimento é 'online', o campo localização DEVE ser NULL

### Validações
- Modo presencial sem localização retorna erro
- Modo presencial com localização vazia retorna erro
- Modo online com localização preenchida retorna erro

---

## 2. trigger_impedir_conflito_horario

### Descrição
Impede que um tutor tenha dois ou mais agendamentos com horários sobrepostos na mesma data.

### Tabela
agendamento

### Momento
BEFORE INSERT OR UPDATE

### Regras de Negócio
1. Verifica apenas agendamentos com status 'pendente' ou 'confirmado'
2. Agendamentos cancelados ou concluídos não bloqueiam novos horários
3. Detecta três tipos de sobreposição:
   - Novo agendamento começa durante outro existente
   - Novo agendamento termina durante outro existente
   - Novo agendamento engloba completamente outro existente
4. Em UPDATE, exclui o próprio registro da verificação

### Validações
- Tutor já tem agendamento no mesmo horário retorna erro

---

## 3. trigger_validar_transicao_status

### Descrição
Controla e valida as mudanças de status do agendamento, garantindo que apenas transições válidas sejam permitidas.

### Tabela
agendamento

### Momento
BEFORE UPDATE

### Regras de Negócio
Transições válidas por status:
- pendente pode mudar para: confirmado ou cancelado
- confirmado pode mudar para: concluido ou cancelado
- concluido não pode mudar (estado terminal)
- cancelado não pode mudar (estado terminal)

### Validações
- Transição inválida a partir de pendente retorna erro
- Transição inválida a partir de confirmado retorna erro
- Tentativa de alterar status concluído retorna erro
- Tentativa de alterar status cancelado retorna erro

---

## 4. trigger_validar_mensagem

### Descrição
Valida se um usuário pode enviar mensagem em um chat, verificando participação e status do agendamento.

### Tabela
mensagem

### Momento
BEFORE INSERT

### Regras de Negócio
1. O remetente deve fazer parte do chat (estar registrado em chat_aluno)
2. O agendamento deve estar no status 'confirmado'
3. Mensagens não podem ser enviadas em agendamentos pendentes, cancelados ou concluídos

### Validações
- Usuário não faz parte do chat retorna erro
- Agendamento não encontrado retorna erro
- Agendamento não está confirmado retorna erro

---

## 5. trigger_impedir_editar_mensagem_deletada

### Descrição
Impede que mensagens que foram marcadas como deletadas sejam editadas.

### Tabela
mensagem

### Momento
BEFORE UPDATE

### Regras de Negócio
1. Se o campo foi_deletada é TRUE, nenhum UPDATE é permitido
2. Mensagens deletadas devem permanecer no estado em que foram deletadas

### Validações
- Tentativa de editar mensagem deletada retorna erro