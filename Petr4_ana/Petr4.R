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
#library(modeltime)    
#library(timetk)      
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
par(mfrow=c(2,2))
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

par(mfrow=c(1,1))
plot(ret.1min, main="PETR4 Preço retorno 1min 2021", ylab="Preço", col="black")

set.seed(123)
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
plot(ret.1min[1:5000], main="PETR4 Retornos 1min 2021", ylab="Retorno", col="black")
plot(vol_xts, main="PETR4 Volatilidade Estocástica Estimada 1min 2021", 
     ylab="Volatilidade", col="blue")

# Calcular volatilidade realizada
realized_vol <- rollapply(ret.1min[1:5000]^2, width=30, FUN=function(x) sqrt(252*390*mean(x)), 
                          by.column=TRUE, align="right")
realized_vol <- na.omit(realized_vol)

par(mfrow=c(2,1))
plot(realized_vol, main="Volatilidade realizada", ylab="Volatilidade", col="red")

plot(vol_xts, col="blue", main ="Volatilidade Estocástica", ylab="Volatilidade" )

# Análise de clustering de volatilidade
par(mfrow=c(2,1))
acf(abs(ret_vec[1:5000]), main="ACF dos Retornos Absolutos")
pacf(abs(ret_vec[1:5000]), main="PACF dos Retornos Absolutos")

cat("\nTeste ARCH LM para efeitos ARCH:\n")
ArchTest(ret_vec, lags=10)

#separando os parametros

params_mat <- as.matrix(sv_fit$para)
params_df <- as_tibble(params_mat)
params_df <- params_df %>% select(-any_of(c("nu", "rho")))  

# Histograma dos parametros mu sigma e phi

par(mfrow = c(2,2))
hist(params_df[[1]], main = "Posterior de mu", xlab = "mu", breaks = 50)
hist(params_df[[2]], main = "Posterior de phi", xlab = "phi", breaks = 50)
hist(params_df[[3]], main = "Posterior de sigma", xlab = "sigma", breaks = 50)

df_long <- pivot_longer(params_df, cols = everything(),
                         names_to = "param", values_to = "value")

ggplot(df_long, aes(x = value)) +
  geom_histogram(bins = 50, fill = "skyblue", color = "black") +
  facet_wrap(~param, scales = "free", ncol = 2) +
  labs(title = "Distribuições Posteriores dos Parâmetros",
       x = "Valor", y = "Frequência") +
  theme_minimal()
























#divisão entre primeira e segunda parte depois da queda

# Converter para vetor numérico
max = idx_max+5000
ret_vec2 <- as.numeric(ret.1min[idx_max:max])
sv_fit2 <- svsample(ret_vec, draws = 5000, burnin = 1000)

par(mfrow=c(2,2))
plot(sv_fit2, showobs = FALSE)

# Extrair volatilidade estimada (média dos draws)

period = idx_max+4999
df_vol2 <- data.frame(volatility = sv_fit2[["latent0"]][[1]])
sv_vol_mean2 <- exp(df_vol2 / 2)
vol_xts2 <- xts(sv_vol_mean2, order.by = dt1$Period[idx_max:period])


# Gráficos dos retornos e volatilidade estimada
par(mfrow=c(2,1))
plot(ret.1min[idx_max:period], main="PETR4 Retornos 1min 2021", ylab="Retorno", col="black")
plot(vol_xts2, main="PETR4 Volatilidade Estocástica Estimada 1min 2021", 
    ylab="Volatilidade", col="blue")

# Calcular volatilidade realizada
realized_vol <- rollapply(ret.1min[idx_max:period]^2, width=30, FUN=function(x) sqrt(252*390*mean(x)), 
                          by.column=TRUE, align="right")
realized_vol <- na.omit(realized_vol)

par(mfrow=c(2,1))
plot(realized_vol, main="Volatilidade realizada", ylab="Volatilidade", col="red")

plot(vol_xts2, col="blue", main ="Volatilidade Estocástica", ylab="Volatilidade" )

# Análise de clustering de volatilidade


par(mfrow=c(2,1))
acf(abs(ret_vec2[1:5000]), main="ACF dos Retornos Absolutos")
pacf(abs(ret_vec2[1:5000]), main="PACF dos Retornos Absolutos")

cat("\nTeste ARCH LM para efeitos ARCH:\n")
ArchTest(ret_vec2, lags=10)

#separando os parametros

params_mat2 <- as.matrix(sv_fit2$para)
params_df2 <- as_tibble(params_mat2)
params_df2 <- params_df2 %>% select(-any_of(c("nu", "rho")))  

# Histograma dos parametros mu sigma e phi

par(mfrow = c(2,2))
hist(params_df2[[1]], main = "Posterior de mu", xlab = "mu", breaks = 50)
hist(params_df2[[2]], main = "Posterior de phi", xlab = "phi", breaks = 50)
hist(params_df2[[3]], main = "Posterior de sigma", xlab = "sigma", breaks = 50)

df_long2 <- pivot_longer(params_df2, cols = everything(),
                        names_to = "param", values_to = "value")

ggplot(df_long2, aes(x = value)) +
  geom_histogram(bins = 50, fill = "skyblue", color = "black") +
  facet_wrap(~param, scales = "free", ncol = 2) +
  labs(title = "Distribuições Posteriores dos Parâmetros",
      x = "Valor", y = "Frequência") +
  theme_minimal()



plot_wavelet_levels_jumps <- function(df, levels = 12, df_name = "df_est") {
  
  filter_type <- "la12"
  max_possible_levels <- floor(log2(nrow(df)))
  levels_used <- min(levels, max_possible_levels)
  
  
  dwt_result <- dwt(df$vol, n.levels = levels_used)
  total_plots <- levels_used + 2
  plots_list <- vector("list", total_plots)
  
  for (plot_idx in seq_len(total_plots)) {
    if (plot_idx == 1) {
      plots_list[[plot_idx]] <- ggplot(df, aes(x = time, y = vol)) +
        geom_line(color = "blue") +
        labs(title = paste(df_name, ": Série Original"), x = "Tempo", y = "Volatilidade") +
        theme_minimal()
      
    } else if (plot_idx == total_plots) {
      approx_dwt <- dwt_result
      for (j in seq_len(levels_used)) approx_dwt@W[[j]][] <- 0
      approximation <- idwt(approx_dwt)
      df_plot <- data.frame(time = df$time, value = approximation[1:nrow(df)])
      
      plots_list[[plot_idx]] <- ggplot(df_plot, aes(x = time, y = value)) +
        geom_line(color = "red") +
        labs(title = paste(df_name, ": Aproximação (Nível", levels_used, ")"), x = "Tempo", y = "Valor") +
        theme_minimal()
      
    } else {
      i <- plot_idx - 1
      detail_dwt <- dwt_result
      for (j in seq_len(levels_used)) if (j != i) detail_dwt@W[[j]][] <- 0
      detail_dwt@V[[levels_used]][] <- 0
      detail_series <- idwt(detail_dwt)
      
      if (length(detail_series) > nrow(df)) {
        detail_series <- detail_series[1:nrow(df)]
      }
      
      df_plot <- data.frame(time = df$time, value = detail_series)
      
      Wj <- dwt_result@W[[i]]
      sigma_j <- median(abs(Wj - median(Wj))) / 0.6745
      lambda_j <- sqrt(2 * log(length(Wj))) * sigma_j * sqrt(2)
      jumps_idx <- which(abs(Wj) > lambda_j)
      
      jump_series <- rep(NA, nrow(df))
      jumps_idx_valid <- jumps_idx[jumps_idx <= nrow(df)]
      jump_series[jumps_idx_valid] <- detail_series[jumps_idx_valid]
      
      df_plot$jumps <- jump_series
      
      plots_list[[plot_idx]] <- ggplot(df_plot, aes(x = time, y = value)) +
        geom_line(color = "darkgreen") +
        geom_point(data = subset(df_plot, !is.na(jumps)), aes(x = time, y = jumps), color = "red", size = 1.5) +
        labs(title = paste(df_name, ": Detalhe Nível", i, "com Saltos"), x = "Tempo", y = "Valor") +
        theme_minimal()
    }
  }
  
  for (k in seq(1, length(plots_list), by = 2)) {
    p1 <- plots_list[[k]]
    p2 <- if ((k + 1) <= length(plots_list)) plots_list[[k + 1]] else NULL
    if (!is.null(p2)) {
      grid.arrange(p1, p2, nrow = 2)
    } else {
      print(p1)
    }
  }
  
  invisible(plots_list)
}

plot_wavelet_levels_jumps(df_est, levels = 12, df_name = "df_est")



{r}
plot_wavelet_levels_ggplot <- function(df, levels = 12, df_name = "df_est") {
  filter_type <- "la12"
  max_possible_levels <- floor(log2(nrow(df)))
  levels_used <- min(levels, max_possible_levels)
  
  
  dwt_result <- dwt(df$vol, n.levels = levels_used)
  total_plots <- levels_used + 2
  plots_list <- vector("list", total_plots)
  for (plot_idx in seq_len(total_plots)) {
    if (plot_idx == 1) {
      plots_list[[plot_idx]] <- ggplot(df, aes(x = time, y = vol)) +
        geom_line(color = "blue") +
        labs(title = paste(df_name, ": Série Original"), x = "Tempo", y = "Volatilidade") +
        theme_minimal()
      
    } else if (plot_idx == total_plots) {
      approx_dwt <- dwt_result
      for (j in seq_len(levels_used)) approx_dwt@W[[j]][] <- 0
      approximation <- idwt(approx_dwt)
      df_plot <- data.frame(time = df$time, value = approximation)
      
      plots_list[[plot_idx]] <- ggplot(df_plot, aes(x = time, y = value)) +
        geom_line(color = "red") +
        labs(title = paste(df_name, ": Aproximação (Nível", levels_used, ")"), x = "Tempo", y = "Valor") +
        theme_minimal()
      
    } else {
      i <- plot_idx - 1
      detail_dwt <- dwt_result
      for (j in seq_len(levels_used)) if (j != i) detail_dwt@W[[j]][] <- 0
      detail_dwt@V[[levels_used]][] <- 0
      detail_series <- idwt(detail_dwt)
      df_plot <- data.frame(time = df$time, value = detail_series)
      
      plots_list[[plot_idx]] <- ggplot(df_plot, aes(x = time, y = value)) +
        geom_line(color = "darkgreen") +
        labs(title = paste(df_name, ": Detalhe Nível", i), x = "Tempo", y = "Valor") +
        theme_minimal()
    }
  }
  
  for (k in seq(1, length(plots_list), by = 2)) {
    p1 <- plots_list[[k]]
    p2 <- if ((k + 1) <= length(plots_list)) plots_list[[k + 1]] else NULL
    if (!is.null(p2)) {
      grid.arrange(p1, p2, nrow = 2)
    } else {
      print(p1)
    }
  }
}

plot_wavelet_levels_ggplot(df_est, levels = 12, df_name = "df_est")