pacotes <- c("DBI", "RPostgres", "dplyr", "purrr")

for (pacote in pacotes) {
  if (!require(pacote, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Instalando %s...\n", pacote))
    install.packages(pacote, quiet=TRUE)
    library(pacote, character.only = TRUE)
  }
}

cat("Todos os pacotes carregados!\n\n")

con <- dbConnect(
  RPostgres::Postgres(),
  host = "localhost",
  port = 5432,
  dbname = "postgredb",
  user = "postgres",
  password = "1234"
)

# Puxar todas as tabelas
dados <- dbListTables(con) |>
  set_names() |>
  map(~{
    cat(sprintf("Carregando tabela: %s\n", .x))
    dbReadTable(con, .x)
  })

dbDisconnect(con)

cat("Dados carregados com sucesso!\n")
map_int(dados, nrow)
