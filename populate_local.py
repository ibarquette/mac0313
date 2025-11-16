import zipfile
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
import getpass

ZIP_FILE_PATH = "dados_populacao_db_v2.zip"
SCHEMA_FILE_PATH = "schema.sql"

TABLE_ORDER = [
    "instituto", "numero_instituto", "disciplina", "curso", "curso_disciplina",
    "aluno", "tutor", "tutor_disciplina", "disponibilidade_tutor",
    "pacote", "aluno_pacote",
    "agendamento", "aula", "assunto_agendamento", "assunto_aula",
    "chat", "chat_aluno", "mensagem",
    "avaliacao", "denuncia", "aluno_aula"
]

def get_db_credentials():
    """Solicita as credenciais do banco de dados ao usuário."""
    print("=== Configuração de Conexão PostgreSQL ===")
    host = input("Host (padrão: localhost): ").strip() or "localhost"
    port = input("Porta (padrão: 5432): ").strip() or "5432"
    database = input("Nome do banco de dados: ").strip()
    user = input("Usuário: ").strip()
    password = getpass.getpass("Senha: ")
    
    return host, port, database, user, password

def create_engine_connection() -> Engine | None:
    """Cria e retorna a engine do SQLAlchemy."""
    host, port, database, user, password = get_db_credentials()
    
    connection_string = f"postgresql://{user}:{password}@{host}:{port}/{database}"
    
    try:
        engine = create_engine(connection_string)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print(f"\nConexão estabelecida com sucesso!\n")
        return engine
    except Exception as e:
        print(f"\nErro ao conectar ao banco de dados: {e}\n")
        return None

def create_schema(engine: Engine):
    """Lê o arquivo SQL e cria o esquema no banco."""
    print("Criando o esquema do banco de dados...")
    
    try:
        with open(SCHEMA_FILE_PATH, 'r', encoding='utf-8') as f:
            sql_schema = f.read()
        
        with engine.connect() as conn:
            conn.execute(text(sql_schema))
            conn.commit()
        
        print("Esquema criado com sucesso!\n")
        return True
    except FileNotFoundError:
        print(f"Erro: Arquivo {SCHEMA_FILE_PATH} não encontrado!\n")
        return False
    except Exception as e:
        print(f"Erro ao criar o esquema: {e}\n")
        return False

def populate_tables(engine: Engine):
    """Lê os CSVs do ZIP e popula as tabelas na ordem correta."""
    print("Iniciando a população das tabelas...")
    
    try:
        with zipfile.ZipFile(ZIP_FILE_PATH, 'r') as z:
            for table_name in TABLE_ORDER:
                csv_filename = f"{table_name}.csv"
                
                if csv_filename in z.namelist():
                    print(f"  -> Processando tabela: {table_name}")
                    
                    with z.open(csv_filename) as csv_file:
                        df = pd.read_csv(csv_file)
                        
                        df.to_sql(
                            table_name, 
                            engine, 
                            if_exists='append', 
                            index=False,
                            method='multi'
                        )
                        
                        print(f"{len(df)} linhas inseridas em {table_name}.")
                else:
                    print(f"Arquivo {csv_filename} não encontrado no ZIP. Pulando.")
        
        print("\nPopulação do banco de dados concluída com sucesso!")
        return True
        
    except FileNotFoundError:
        print(f"Erro: Arquivo ZIP não encontrado em {ZIP_FILE_PATH}")
        return False
    except Exception as e:
        print(f"Erro durante a população das tabelas: {e}")
        return False

def main():
    engine = create_engine_connection()
    if engine is None:
        return

    if not create_schema(engine):
        print("Falha ao criar o esquema. Abortando.")
        return

    populate_tables(engine)
    engine.dispose()

if __name__ == "__main__":
    main()