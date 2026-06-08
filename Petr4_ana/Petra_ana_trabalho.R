# Análise Financeira e Séries Temporais para Dados de Ações
# Baseado no documento "calude.txt"

# Instalação de pacotes necessários (descomente se precisar instalar)
# install.packages(c("tseries", "forecast", "rugarch", "ggplot2", "dplyr", "zoo", 
#                   "xts", "PerformanceAnalytics", "TTR", "urca"))

# Carregando as bibliotecas
library(tseries)      # Para testes ADF e funções de séries temporais
library(forecast)     # Para modelagem ARIMA
library(rugarch)      # Para modelos GARCH
library(ggplot2)      # Para visualizações
library(dplyr)        # Para manipulação de dados
library(zoo)          # Para séries temporais
library(xts)          # Para séries temporais extensíveis
library(PerformanceAnalytics)  # Para cálculos financeiros
library(TTR)          # Para indicadores técnicos
library(urca)         # Para testes de raiz unitária
library(lubridate)    # Para manipulação de datas

# Lendo os dados
dados <- read.csv("D:/Code/R_studio/Petr4_ana/dt_1min_PETR4_2021_metatrader.csv", 
                  header = TRUE, stringsAsFactors = FALSE, 
                  sep = ";", dec = ",")

# Convertendo a coluna de data para o formato adequado
dados$X <- as.POSIXct(dados$X, format="%Y-%m-%d %H:%M:%S")

# Criando uma série temporal xts para análise
dados_xts <- xts(dados[, c("Close.1min", "Ret.1min")], order.by = dados$X)

# Filtrando dados para horário de negociação regular (opcional)
# Remover dados antes das 10:20 e após as 16:54
# dados_xts <- dados_xts[!(hour(index(dados_xts)) == 10 & minute(index(dados_xts)) < 20)]
# dados_xts <- dados_xts[hour(index(dados_xts)) < 17]
# dados_xts <- dados_xts[!(hour(index(dados_xts)) == 16 & minute(index(dados_xts)) > 54)]

# Identificação e tratamento de outliers (opcional)
# outliers_threshold <- 3 * sd(dados_xts$Ret.1min)
# extreme_returns <- which(abs(dados_xts$Ret.1min) > outliers_threshold)
# if(length(extreme_returns) > 0) {
#   for(i in extreme_returns) {
#     if(i > 1) dados_xts$Ret.1min[i] <- dados_xts$Ret.1min[i-1]
#   }
# }

# Visualizando os primeiros registros
head(dados_xts)

#---------------------------------------------------------------------------
# 1. FUNDAMENTOS DE ANÁLISE FINANCEIRA
#---------------------------------------------------------------------------

# 1.1 Retornos e Log-retornos
# Os retornos já estão calculados como "Ret.1min", mas vamos calcular também os log-retornos

# Se precisar calcular retornos a partir do Close.1min (caso não existam em Ret.1min)
# dados_xts$Ret.1min <- (dados_xts$Close.1min/lag(dados_xts$Close.1min, 1) - 1)

# Adicionando log-retornos a partir dos retornos existentes
dados_xts$LogRet.1min <- log(1 + dados_xts$Ret.1min)

# Alternativa: calcular diretamente dos preços (se preferir)
# dados_xts$LogRet.1min <- diff(log(dados_xts$Close.1min))

# Removendo NAs
dados_xts <- na.omit(dados_xts)

# 1.2 Medidas de Risco e Volatilidade

# Volatilidade histórica (desvio padrão dos retornos)
calc_volatilidade_historica <- function(retornos, janela = 21) {
  vol_hist <- rollapply(retornos, width = janela, 
                        FUN = function(x) sd(x, na.rm = TRUE), 
                        by.column = TRUE, 
                        align = "right")
  return(vol_hist)
}

# Calculando volatilidade histórica em janela móvel de 30 minutos
dados_xts$Vol_Hist_30min <- calc_volatilidade_historica(dados_xts$LogRet.1min, janela = 30)

# Volatilidade anualizada (considerando 252 dias de negociação, 390 minutos por dia)
minutos_ano <- 252 * 390
dados_xts$Vol_Anual <- dados_xts$Vol_Hist_30min * sqrt(minutos_ano)

# Gráfico de preços e volatilidade
par(mfrow = c(2, 1))
plot(dados_xts$Close.1min, main = "Preço de Fechamento", xlab = "Data", ylab = "Preço")
plot(dados_xts$Vol_Hist_30min, main = "Volatilidade (Janela 30 min)", xlab = "Data", ylab = "Volatilidade")

#---------------------------------------------------------------------------
# 2. SÉRIES TEMPORAIS EM FINANÇAS
#---------------------------------------------------------------------------

# 2.1 Definição e Estacionariedade

# Transformando dados xts em vetor para compatibilidade com testes
log_ret_vec <- as.numeric(dados_xts$LogRet.1min)
ret_vec <- as.numeric(dados_xts$Ret.1min)

# Teste ADF para verificar estacionariedade (H0: série não é estacionária)
adf_test <- adf.test(log_ret_vec)
print("Teste ADF para Log-Retornos:")
print(adf_test)

# Teste KPSS (complementar ao ADF) (H0: série é estacionária)
kpss_test <- kpss.test(log_ret_vec)
print("Teste KPSS para Log-Retornos:")
print(kpss_test)

# Visualizando ACF e PACF
par(mfrow = c(1, 2))
acf(log_ret_vec, main = "ACF - Log-Retornos", na.action = na.pass)
pacf(log_ret_vec, main = "PACF - Log-Retornos", na.action = na.pass)

# 2.2 Modelos ARIMA

# Identificação automática do modelo ARIMA
# Usamos o vetor para evitar problemas com xts
tryCatch({
  arima_auto <- auto.arima(log_ret_vec, seasonal = FALSE, 
                           stepwise = TRUE, approximation = FALSE)
  summary(arima_auto)
  
  # Diagnóstico de resíduos
  checkresiduals(arima_auto)
  
  # Previsão com ARIMA
  forecast_arima <- forecast(arima_auto, h = 30)  # Prever próximos 30 minutos
  plot(forecast_arima, main = "Previsão ARIMA para Log-Retornos", xlab = "Tempo", ylab = "Log-Retorno")
}, error = function(e) {
  cat("Erro na modelagem ARIMA:", e$message, "\n")
  # Alternativa: tentar com ordem específica
  arima_auto <- arima(log_ret_vec, order = c(1, 0, 1))
  summary(arima_auto)
})

#---------------------------------------------------------------------------
# 3. MODELOS DE VOLATILIDADE CONDICIONAL
#---------------------------------------------------------------------------

# 3.1 e 3.2 Modelos ARCH/GARCH

tryCatch({
  # Determinando a ordem ARMA para o GARCH
  arma_p <- ifelse(exists("arima_auto"), arima_auto$arma[1], 1)
  arma_q <- ifelse(exists("arima_auto"), arima_auto$arma[2], 1)
  
  # Especificação do modelo GARCH(1,1)
  garch_spec <- ugarchspec(
    variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
    mean.model = list(armaOrder = c(arma_p, arma_q), include.mean = TRUE),
    distribution.model = "std"  # Distribuição t de Student
  )
  
  # Ajuste do modelo GARCH
  garch_fit <- ugarchfit(garch_spec, log_ret_vec)
  print(garch_fit)
  
  # Previsão com GARCH
  garch_forecast <- ugarchforecast(garch_fit, n.ahead = 30)
  plot(garch_forecast)
}, error = function(e) {
  cat("Erro na modelagem GARCH:", e$message, "\n")
  cat("Tentando com especificação mais simples...\n")
  
  # Tentativa mais simples
  garch_spec <- ugarchspec(
    variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
    mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
    distribution.model = "norm"
  )
  tryCatch({
    garch_fit <- ugarchfit(garch_spec, log_ret_vec)
    print(garch_fit)
  }, error = function(e2) {
    cat("Ainda não foi possível ajustar o GARCH:", e2$message, "\n")
  })
})

# 3.3 EWMA (Volatilidade Exponencialmente Ponderada)

# Implementação da volatilidade EWMA
calc_ewma <- function(retornos, lambda = 0.94) {
  n <- length(retornos)
  ewma <- numeric(n)
  
  # Verificação do número de observações para inicialização
  if (n < 10) {
    ewma[1] <- var(retornos, na.rm = TRUE)  # Usar todas as observações disponíveis
  } else {
    ewma[1] <- var(retornos[1:min(10, n)], na.rm = TRUE)  # Usar as primeiras 10 observações
  }
  
  for (i in 2:n) {
    ewma[i] <- lambda * ewma[i-1] + (1-lambda) * retornos[i-1]^2
  }
  
  return(sqrt(ewma))  # Retorna desvio padrão
}

# Aplicando EWMA aos log-retornos
dados_xts$Vol_EWMA <- calc_ewma(as.numeric(dados_xts$LogRet.1min))

# Comparação entre volatilidades
plot(cbind(dados_xts$Vol_Hist_30min, dados_xts$Vol_EWMA), 
     main = "Comparação de Volatilidades", 
     legend.loc = "topright",
     col = c("blue", "red"))

#---------------------------------------------------------------------------
# 4. INDICADORES GRÁFICOS E VARIÁVEIS ESSENCIAIS
#---------------------------------------------------------------------------

# 4.1 Médias Móveis (MA)

# Simple Moving Average (SMA) - com tratamento de possíveis erros
tryCatch({
  dados_xts$SMA_10 <- SMA(dados_xts$Close.1min, n = 10)
  dados_xts$SMA_20 <- SMA(dados_xts$Close.1min, n = 20)
  
  # Exponential Moving Average (EMA)
  dados_xts$EMA_10 <- EMA(dados_xts$Close.1min, n = 10)
  dados_xts$EMA_20 <- EMA(dados_xts$Close.1min, n = 20)
  
  # Verificando quais colunas estão disponíveis para plotagem
  cols_to_plot <- c("Close.1min")
  if (!is.null(dados_xts$SMA_10)) cols_to_plot <- c(cols_to_plot, "SMA_10")
  if (!is.null(dados_xts$SMA_20)) cols_to_plot <- c(cols_to_plot, "SMA_20")
  if (!is.null(dados_xts$EMA_10)) cols_to_plot <- c(cols_to_plot, "EMA_10")
  if (!is.null(dados_xts$EMA_20)) cols_to_plot <- c(cols_to_plot, "EMA_20")
  
  # Definindo cores para gráfico
  cores <- c("black", "blue", "red", "green", "orange")[1:length(cols_to_plot)]
  
  # Visualizando preços e médias móveis
  if (length(cols_to_plot) > 1) {
    plot(merge(dados_xts[, cols_to_plot]),
         main = "Preço e Médias Móveis",
         col = cores,
         legend.loc = "topleft")
  } else {
    plot(dados_xts$Close.1min,
         main = "Preço",
         col = "black")
  }
}, error = function(e) {
  cat("Erro ao calcular médias móveis:", e$message, "\n")
  # Verificar se a coluna Close.1min existe
  if ("Close.1min" %in% colnames(dados_xts)) {
    plot(dados_xts$Close.1min, main = "Preço (sem médias móveis)")
  } else {
    cat("Coluna Close.1min não encontrada nos dados\n")
  }
})

# 4.3 Reversão à Média

# Indicador para detecção de reversão à média - Z-score
calc_zscore <- function(precos, janela = 21) {
  ma <- rollapply(precos, width = janela, FUN = mean, align = "right")
  sd <- rollapply(precos, width = janela, FUN = sd, align = "right")
  zscore <- (precos - ma) / sd
  return(zscore)
}

dados_xts$ZScore <- calc_zscore(dados_xts$Close.1min, janela = 30)

# 4.4 Variáveis Complementares

# RSI (Relative Strength Index)
dados_xts$RSI <- RSI(dados_xts$Close.1min, n = 14)

# MACD (Moving Average Convergence Divergence)
macd <- MACD(dados_xts$Close.1min, nFast = 12, nSlow = 26, nSig = 9)
dados_xts$MACD_Line <- macd$macd
dados_xts$Signal_Line <- macd$signal

# Beta (em relação a um índice, se disponível)
# Supondo que temos dados de um índice de mercado na mesma frequência
# dados_indice <- ... (carregue os dados do índice aqui)
# dados_xts$Beta <- rollapply(merge(dados_xts$LogRet.1min, dados_indice), 
#                            width = 30, 
#                            FUN = function(x) cov(x[,1], x[,2]) / var(x[,2]), 
#                            by.column = FALSE, 
#                            align = "right")

# Visualizando indicadores técnicos
par(mfrow = c(3, 1))
plot(dados_xts$Close.1min, main = "Preço", xlab = "Data", ylab = "Preço")
plot(dados_xts$RSI, main = "RSI", xlab = "Data", ylab = "RSI")
plot(merge(dados_xts$MACD_Line, dados_xts$Signal_Line), 
     main = "MACD", xlab = "Data", ylab = "MACD",
     col = c("blue", "red"))

#---------------------------------------------------------------------------
# 5. CHECKLIST DE ANÁLISE E RELATÓRIO FINAL
#---------------------------------------------------------------------------

# Gerando estatísticas descritivas
stats_descritivas <- data.frame(
  Métrica = c("Média", "Mediana", "Desvio Padrão", "Mínimo", "Máximo", "Assimetria", "Curtose"),
  Preço = c(
    mean(dados_xts$Close.1min),
    median(dados_xts$Close.1min),
    sd(dados_xts$Close.1min),
    min(dados_xts$Close.1min),
    max(dados_xts$Close.1min),
    skewness(dados_xts$Close.1min),
    kurtosis(dados_xts$Close.1min)
  ),
  Retorno = c(
    mean(dados_xts$Ret.1min),
    median(dados_xts$Ret.1min),
    sd(dados_xts$Ret.1min),
    min(dados_xts$Ret.1min),
    max(dados_xts$Ret.1min),
    skewness(dados_xts$Ret.1min),
    kurtosis(dados_xts$Ret.1min)
  ),
  LogRetorno = c(
    mean(dados_xts$LogRet.1min),
    median(dados_xts$LogRet.1min),
    sd(dados_xts$LogRet.1min),
    min(dados_xts$LogRet.1min),
    max(dados_xts$LogRet.1min),
    skewness(dados_xts$LogRet.1min),
    kurtosis(dados_xts$LogRet.1min)
  )
)

print(stats_descritivas)

# Cálculo de Value-at-Risk (VaR)
calc_var <- function(retornos, nivel_confianca = 0.95, janela = 30) {
  var_hist <- rollapply(retornos, width = janela, 
                        FUN = function(x) quantile(x, 1 - nivel_confianca), 
                        align = "right")
  return(var_hist)
}

dados_xts$VaR_95 <- calc_var(dados_xts$LogRet.1min, nivel_confianca = 0.95)

# Expected Shortfall (ES) ou Conditional VaR
calc_es <- function(retornos, nivel_confianca = 0.95, janela = 30) {
  es_hist <- rollapply(retornos, width = janela, 
                       FUN = function(x) {
                         var_level <- quantile(x, 1 - nivel_confianca)
                         mean(x[x <= var_level])
                       }, 
                       align = "right")
  return(es_hist)
}

dados_xts$ES_95 <- calc_es(dados_xts$LogRet.1min, nivel_confianca = 0.95)

# Teste de normalidade de Jarque-Bera
tryCatch({
  jarque_bera_test <- jarque.bera.test(as.numeric(dados_xts$LogRet.1min))
  print("Teste de Normalidade Jarque-Bera:")
  print(jarque_bera_test)
  
  # Gráfico QQ-Plot para verificar normalidade
  qqnorm(as.numeric(dados_xts$LogRet.1min))
  qqline(as.numeric(dados_xts$LogRet.1min), col = "red")
}, error = function(e) {
  cat("Erro no teste Jarque-Bera:", e$message, "\n")
  # Alternativa: tentar com teste Shapiro-Wilk
  cat("Tentando teste Shapiro-Wilk...\n")
  shapiro_test <- shapiro.test(as.numeric(dados_xts$LogRet.1min[1:min(5000, length(dados_xts$LogRet.1min))]))
  print(shapiro_test)
})

# Salvando os resultados em CSV
write.csv(data.frame(Data = index(dados_xts), coredata(dados_xts)), 
          file = "resultados_analise.csv", 
          row.names = FALSE)

# Resumo dos modelos e testes
cat("\n===== RESUMO DA ANÁLISE =====\n")

cat("\n1. TESTES DE ESTACIONARIEDADE\n")
if(exists("adf_test")) {
  cat("Teste ADF para Log-Retornos: p-valor =", adf_test$p.value, "\n")
  cat("Interpretação ADF: ", ifelse(adf_test$p.value < 0.05, 
                                    "Rejeita H0 - Série é estacionária", 
                                    "Não rejeita H0 - Série não é estacionária"), "\n")
}
if(exists("kpss_test")) {
  cat("Teste KPSS para Log-Retornos: p-valor =", kpss_test$p.value, "\n")
  cat("Interpretação KPSS: ", ifelse(kpss_test$p.value > 0.05, 
                                     "Não rejeita H0 - Série é estacionária", 
                                     "Rejeita H0 - Série não é estacionária"), "\n")
}

cat("\n2. MODELO ARIMA\n")
if(exists("arima_auto")) {
  tryCatch({
    cat("Ordem ARIMA identificada:", arima_auto$arma[1], arima_auto$arma[2], arima_auto$arma[5], "\n")
    cat("AIC:", AIC(arima_auto), "\n")
  }, error = function(e) {
    cat("Não foi possível extrair parâmetros ARIMA:", e$message, "\n")
  })
} else {
  cat("Modelo ARIMA não foi ajustado com sucesso\n")
}

cat("\n3. MODELO GARCH\n")
if(exists("garch_fit")) {
  tryCatch({
    cat("Coeficientes GARCH:\n")
    print(coef(garch_fit))
    
    # Teste de efeito ARCH nos resíduos
    if("residuals" %in% names(garch_fit@fit)) {
      arch_test <- arch.test(garch_fit)
      cat("Teste de efeito ARCH nos resíduos:")
      print(arch_test)
    }
  }, error = function(e) {
    cat("Não foi possível extrair informações do modelo GARCH:", e$message, "\n")
  })
} else {
  cat("Modelo GARCH não foi ajustado com sucesso\n")
}

cat("\n4. ESTATÍSTICAS DE RISCO\n")
if("VaR_95" %in% colnames(dados_xts)) {
  cat("VaR 95% (média):", mean(dados_xts$VaR_95, na.rm = TRUE), "\n")
}
if("ES_95" %in% colnames(dados_xts)) {
  cat("ES 95% (média):", mean(dados_xts$ES_95, na.rm = TRUE), "\n")
}
if("Vol_Anual" %in% colnames(dados_xts)) {
  cat("Volatilidade anualizada (média):", mean(dados_xts$Vol_Anual, na.rm = TRUE), "\n")
}

cat("\n5. TESTE DE NORMALIDADE\n")
if(exists("jarque_bera_test")) {
  cat("Jarque-Bera p-valor:", jarque_bera_test$p.value, 
      "- Distribuição normal:", ifelse(jarque_bera_test$p.value > 0.05, "Sim", "Não"), "\n")
} else if(exists("shapiro_test")) {
  cat("Shapiro-Wilk p-valor:", shapiro_test$p.value, 
      "- Distribuição normal:", ifelse(shapiro_test$p.value > 0.05, "Sim", "Não"), "\n")
} else {
  cat("Nenhum teste de normalidade foi executado com sucesso\n")
}

# Exibindo gráficos finais
par(mfrow = c(2, 2))
plot(dados_xts$Close.1min, main = "Preço de Fechamento")
plot(dados_xts$LogRet.1min, main = "Log-Retornos")
plot(dados_xts$Vol_Hist_30min, main = "Volatilidade Histórica (30 min)")
plot(merge(dados_xts$VaR_95, dados_xts$ES_95), 
     main = "Métricas de Risco", 
     col = c("blue", "red"))