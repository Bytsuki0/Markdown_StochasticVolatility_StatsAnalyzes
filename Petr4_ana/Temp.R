library(dplyr)
library(ggplot2)
library(tidyr)
library(zoo)
library(xts)
library(forecast)
library(lubridate)
library(PerformanceAnalytics)
library(highfrequency)         
library(quantmod)    
library(tseries)     
library(FinTS)       
library(stochvol)  
library(fpp2)     
library(fpp3)       
library(modeltime)    
library(timetk)      
library(parsnip)      
library(rsample)      
library(cowplot)

# Leitura condicional do arquivo
os <- Sys.info()["sysname"]
if(os == "Windows") {
  dt.intra <- read.csv("D:/Code/R_studio/Petr4_ana/dt_1min_PETR4_2021_metatrader.csv", 
                       header = TRUE, stringsAsFactors = FALSE, 
                       sep = ";", dec = ",")
} else if(os == "Linux") {
  dt.intra <- read.csv("~/Documentos/Coding/Statistics_in_R/Petr4_ana/dt_1min_PETR4_2021_metatrader.csv", 
                       header = TRUE, stringsAsFactors = FALSE, 
                       sep = ";", dec = ",")
}

dt1 <- as_tibble(dt.intra) %>% 
  mutate(Period = ymd_hms(X)) %>%
  select(-X) %>% 
  filter(!(hour(Period) == 10 & minute(Period) < 20)) %>% 
  filter(hour(Period) < 17) %>% 
  filter(!(hour(Period) == 16 & minute(Period) > 54)) %>% 
  filter(!(date(Period) == "2021-02-17")) %>% 
  arrange(Period)

ret.1min <- as.xts(dt1$Ret.1min, order.by = dt1$Period)

# Teste ADF e visualizações iniciais
tseries::adf.test(ret.1min)
plot.ts(ret.1min)
boxplot(as.double(ret.1min))

# Identificar outliers
idx_min <- which.min(as.double(ret.1min))
idx_max <- which.max(as.double(ret.1min))

# Substituir outliers pela observação anterior
ret.1min[idx_min] <- ret.1min[idx_min - 1]
ret.1min[idx_max] <- ret.1min[idx_max - 1]

plot.ts(ret.1min)
boxplot(as.double(ret.1min))
tseries::adf.test(ret.1min) 

# Gráfico de retornos
plot(ret.1min, main="PETR4 Preço retorno 1min 2021", ylab="Preço", col="black")


# Converter para vetor numérico
ret_vec <- as.numeric(ret.1min[1:5000])
sv_fit <- svsample(ret_vec, draws = 5000, burnin = 1000)

par(mfrow=c(2,2))
plot(sv_fit, showobs = FALSE)

# Extrair volatilidade estimada (média dos draws)


df_vol <- data.frame(volatility = sv_fit[["latent0"]][[1]])
sv_vol_mean <- exp(df_vol / 2)
vol_xts <- xts(sv_vol_mean, order.by = dt1$Period[1:5000])


# Gráficos dos retornos e volatilidade estimada
par(mfrow=c(2,1))
plot(ret.1min[1:1000], main="PETR4 Retornos 1min 2021", ylab="Retorno", col="black")
plot(vol_xts[1:1000], main="PETR4 Volatilidade Estocástica Estimada 1min 2021", 
     ylab="Volatilidade", col="blue")

# Calcular volatilidade realizada (janela de 30 minutos)
realized_vol <- rollapply(ret.1min^2, width=30, FUN=function(x) sqrt(252*390*mean(x)), 
                          by.column=TRUE, align="right")
realized_vol <- na.omit(realized_vol)

par(mfrow=c(1,1))
plot(realized_vol, main="Comparação de Volatilidades", 
     ylab="Volatilidade", col="red")
lines(vol_xts[index(realized_vol)], col="blue")
legend("topright", legend=c("Volatilidade Realizada", "Volatilidade Estocástica"), 
       col=c("red", "blue"), lty=1)

# Análise de clustering de volatilidade
par(mfrow=c(2,1))
acf(abs(ret_vec), main="ACF dos Retornos Absolutos")
pacf(abs(ret_vec), main="PACF dos Retornos Absolutos")

cat("\nTeste ARCH LM para efeitos ARCH:\n")
ArchTest(ret_vec, lags=10)

#distribuição depois dos parâmetros
par(mfrow=c(2,2))
plot(sv_fit, param = "mu")
plot(sv_fit, param = "phi")
plot(sv_fit, param = "sigma")
plot(sv_fit, param = "nu")

# Construir dataframe com componentes de volatilidade
volatility_components <- data.frame(
  date = index(ret.1min),
  returns = as.numeric(ret.1min),
  sv_vol = sv_vol_mean,
  stringsAsFactors = FALSE
)

# Identificar períodos de alta volatilidade (top 5%)
high_vol_periods <- volatility_components %>%
  as_tibble() %>%
  mutate(date = as.POSIXct(date)) %>%
  filter(sv_vol > quantile(sv_vol, 0.95)) %>%
  arrange(date)

cat("\nPeríodos de volatilidade mais elevada (top 5%):\n")
print(head(high_vol_periods, 10))

# Resumo estatístico da volatilidade por hora do dia
vol_hour_summary <- volatility_components %>%
  as_tibble() %>%
  mutate(date = as.POSIXct(date),
         hour = hour(date)) %>%
  group_by(hour) %>%
  summarise(mean_vol = mean(sv_vol),
            median_vol = median(sv_vol),
            max_vol = max(sv_vol)) %>%
  arrange(desc(mean_vol))

cat("\nVolatilidade média por hora do dia:\n")
print(vol_hour_summary)

cat("\nEstatísticas descritivas da volatilidade estimada:\n")
summary(volatility_components$sv_vol)

par(mfrow=c(1,1))
hist(volatility_components$sv_vol, breaks=50, 
     main="Distribuição da Volatilidade Estocástica", 
     xlab="Volatilidade", col="lightblue")

# Salvar resultados para uso futuro
save(sv_fit, vol_xts, volatility_components, file = "PETR4_stochastic_volatility_results.RData")
