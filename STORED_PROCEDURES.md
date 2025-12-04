# Documentação das Stored Procedures

Este documento descreve em detalhes todas as stored procedures do sistema de agendamento de monitorias.

---

## 1. criar_agendamento

### Descrição
Cria um novo agendamento de tutoria em status 'pendente', aguardando confirmação do tutor.

### Parâmetros
- p_nusp_solicitante (VARCHAR(20)) - NUSP do aluno que está solicitando a tutoria
- p_nusp_tutor (VARCHAR(20)) - NUSP do tutor que dará a tutoria
- p_data (DATE) - Data do agendamento
- p_h_inicio (TIME) - Horário de início
- p_h_fim (TIME) - Horário de término
- p_modo_atendimento (modo_atendimento) - 'online' ou 'presencial'
- p_localizacao (VARCHAR(200)) - Endereço (obrigatório se presencial, NULL se online)
- p_assuntos (TEXT[]) - Array com os assuntos que serão abordados

### Retorno
INTEGER - ID do agendamento criado

### Regras de Negócio
1. Duração mínima de 30 minutos
2. Sistema de créditos: 1 crédito = 30 minutos (sempre arredonda para cima)
3. O aluno deve ter créditos suficientes (mas não são debitados neste momento)
4. O tutor deve ter uma disponibilidade cadastrada que cubra todo o período solicitado
5. O status inicial é sempre 'pendente'
6. O campo 'preco' armazena quantos créditos serão necessários

### Validações
- Duração menor que 30 minutos retorna erro
- Aluno sem créditos suficientes retorna erro
- Tutor sem disponibilidade cadastrada retorna erro

### Triggers Relacionados
- trigger_impedir_conflito_horario - Impede que o tutor tenha agendamentos sobrepostos
- trigger_validar_localizacao - Valida localização conforme modo de atendimento

---

## 2. confirmar_agendamento

### Descrição
Confirma um agendamento pendente e realiza a transação de créditos entre aluno e tutor.

### Parâmetros
- p_id_agendamento (INTEGER) - ID do agendamento a ser confirmado
- p_nusp_tutor (VARCHAR(20)) - NUSP do tutor (para validação)

### Retorno
VOID

### Regras de Negócio
1. Só pode confirmar agendamentos em status 'pendente'
2. Debita os créditos do aluno
3. Credita os créditos ao tutor (mesmo valor)
4. O desconto já foi aplicado na compra do pacote
5. Muda o status de 'pendente' para 'confirmado'

### Validações
- Agendamento não encontrado retorna erro
- Agendamento não pertence ao tutor informado retorna erro
- Agendamento já foi processado retorna erro

### Triggers Relacionados
- trigger_validar_transicao_status - Garante transição válida de status

---

## 3. cancelar_agendamento

### Descrição
Cancela um agendamento (pendente ou confirmado). Se o agendamento já foi confirmado, reverte a transação de créditos.

### Parâmetros
- p_id_agendamento (INTEGER) - ID do agendamento a ser cancelado
- p_nusp_cancelador (VARCHAR(20)) - NUSP de quem está cancelando

### Retorno
VOID

### Regras de Negócio
1. Pode cancelar agendamentos em status 'pendente' ou 'confirmado'
2. Se o status era 'confirmado', reverte a transação:
   - Devolve créditos ao aluno
   - Retira créditos do tutor
3. Muda o status para 'cancelado' (estado terminal)

### Validações
- Agendamento não encontrado retorna erro
- Agendamento já concluído não pode ser cancelado
- Agendamento já cancelado não pode ser cancelado novamente

### Triggers Relacionados
- trigger_validar_transicao_status - Garante transição válida de status

---

## 4. comprar_pacote

### Descrição
Realiza a compra de um pacote de créditos, aplicando desconto baseado na média de avaliações do aluno.

### Parâmetros
- p_nusp (VARCHAR(20)) - NUSP do aluno comprador
- p_qtd_credito (INTEGER) - Quantidade de créditos do pacote

### Retorno
VOID

### Regras de Negócio
1. Sistema de descontos baseado na média de avaliações recebidas:
   - Média maior ou igual a 4.6: 20% de desconto
   - Média maior ou igual a 4.1: 15% de desconto
   - Média maior ou igual a 3.1: 10% de desconto
   - Média maior ou igual a 2.1: 5% de desconto
   - Média menor que 2.1: Sem desconto
2. Registra a compra na tabela aluno_pacote com o preço final (já com desconto)
3. Os créditos são adicionados instantaneamente à conta do aluno

### Validações
- Pacote não existe retorna erro

### Cálculo de Desconto
O preço final é calculado pela fórmula: Preço Base multiplicado por (1 - Desconto/100)

---

## 5. finalizar_aula

### Descrição
Finaliza um agendamento confirmado, transformando-o em uma aula concluída. Adiciona automaticamente o aluno solicitante e o tutor na lista de participantes.

### Parâmetros
- p_id_agendamento (INTEGER) - ID do agendamento a ser finalizado

### Retorno
VOID

### Regras de Negócio
1. Só pode finalizar agendamentos com status 'confirmado'
2. Cria um registro na tabela aula com os dados do agendamento
3. Adiciona automaticamente o aluno solicitante na tabela aluno_aula
4. Adiciona automaticamente o tutor na tabela aluno_aula
5. Muda o status de 'confirmado' para 'concluido' (estado terminal)

### Validações
- Agendamento não encontrado retorna erro
- Agendamento não está confirmado retorna erro

### Triggers Relacionados
- trigger_validar_transicao_status - Garante transição válida de status
- trigger_copiar_assuntos_aula - Copia automaticamente os assuntos de assunto_agendamento para assunto_aula

---

## 6. adicionar_aluno_aula

### Descrição
Adiciona uma lista de alunos extras a uma aula concluída (para registrar aulas em grupo).

### Parâmetros
- p_id_agendamento (INTEGER) - ID da aula
- p_nusps_alunos (VARCHAR(20)[]) - Array com os NUSPs dos alunos extras

### Retorno
VOID

### Regras de Negócio
1. Só pode adicionar alunos em aulas com status 'concluido'
2. Para cada aluno do array, realiza as seguintes validações:
   - Verifica se o aluno existe no sistema
   - Não permite adicionar o tutor como aluno
   - Não permite adicionar alunos duplicados
3. O processamento é tolerante: se um aluno for inválido, pula e continua com os próximos
4. Retorna um contador informando quantos alunos foram adicionados com sucesso

### Validações por Aluno
- Aluno não existe: pula e continua
- Aluno é o tutor: pula e continua
- Aluno já está na aula: pula e continua