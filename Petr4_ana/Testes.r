
pkgs <- c(
  "dplyr", "ggplot2", "tidyr", "zoo", "xts", "forecast", "lubridate",
  "PerformanceAnalytics", "quantmod", "tseries", "FinTS", "stochvol",
  "fpp2", "fpp3", "parsnip", "rsample", "cowplot", "wavelets",
  "gridExtra", "broom", "rugarch"
  # "highfrequency", "modeltime", "timetk"  # descomente se precisar
)

if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

install_if_missing <- function(p) {
  if (!requireNamespace(p, quietly = TRUE)) {
    message("Instalando pacote: ", p)
    tryCatch(
      {
        install.packages(p)
      },
      error = function(e) {
        message("⚠️ Falhou no CRAN: ", p, " — tentando via GitHub (se disponível).")
        # casos especiais (pacotes de forecasting e high-frequency finance)
        if (p %in% c("fpp2", "fpp3")) {
          remotes::install_github("robjhyndman/fpp2")
          remotes::install_github("robjhyndman/fpp3")
        }
        if (p == "highfrequency") {
          remotes::install_github("jonathancornelissen/highfrequency")
        }
        if (p == "modeltime") {
          remotes::install_github("business-science/modeltime")
        }
        if (p == "timetk") {
          remotes::install_github("business-science/timetk")
        }
      }
    )
  } else {
    message("✔️ Já instalado: ", p)
  }
}
invisible(lapply(pkgs, install_if_missing))


install.packages(c("RcppArmadillo", "curl", "TTR", "quantmod", "tseries", "forecast"))

install.packages('nloptr')

library(ggplot2)
library(tidyr)
library(zoo)
library(xts)
library(forecast)
library(lubridate)
library(PerformanceAnalytics)
#library(highfrequency)         
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
library(wavelets)
library(gridExtra)
library(broom)
library(rugarch) 




os <- Sys.info()["sysname"]
if(os == "Windows") {
  dt.intra <- read.csv("D:/Code/R_studio/Petr4_ana/dt_1min_PETR4_2021_metatrader.csv", 
                       header = TRUE, stringsAsFactors = FALSE, 
                       sep = ";", dec = ",")
} else if(os == "Linux") {
  dt.intra <- read.csv("~/Documents/Coding/Statistics_in_R/Petr4_ana/dt_1min_PETR4_2021_metatrader.csv", 
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



plot(ret.1min, main="PETR4 Retornos 1min", col="black")
boxplot(as.double(ret.1min), main="Boxplot dos Retornos 1min")


par(mfrow=c(1,1))

plot.ts(ret.1min)
boxplot(as.double(ret.1min))

tseries::adf.test(ret.1min)
dados_xts <- xts(dt1[, c("Close.1min", "Ret.1min")], order.by = dt1$Period)

p2 = idx_min +10000
dados_xts$LogRet.1min <- log(1 + dados_xts$Ret.1min)

dados_xts <- na.omit(dados_xts)

calc_volatilidade_historica <- function(retornos, janela = 21) {
  vol_hist <- rollapply(retornos, width = janela, 
                        FUN = function(x) sd(x, na.rm = TRUE), 
                        by.column = TRUE, 
                        align = "right")
  return(vol_hist)
}

dados_xts$Vol_Hist_30min <- calc_volatilidade_historica(dados_xts$LogRet.1min, janela = 30)

minutos_ano <- 252 * 390
dados_xts$Vol_Anual <- dados_xts$Vol_Hist_30min * sqrt(minutos_ano)

volhist30min=dados_xts$Vol_Hist_30min

plot(volhist30min[1:10000], main = "Volatilidade (Janela 30 min) Pré queda", xlab = "Data", ylab = "Volatilidade")

plot(volhist30min[idx_min:p2], main = "Volatilidade (Janela 30 min) Pós queda", xlab = "Data", ylab = "Volatilidade")


log_ret_vec <- as.numeric(dados_xts$LogRet.1min)
ret_vec <- as.numeric(dados_xts$Ret.1min)

par(mfrow = c(1, 2))
acf(log_ret_vec[1:10000], main = "ACF - Log-Retornos Pré queda", na.action = na.pass)
pacf(log_ret_vec[1:10000], main = "PACF - Log-Retornos Pré queda", na.action = na.pass)

par(mfrow = c(1, 2))
acf(log_ret_vec[idx_min:p2], main = "ACF - Log-Retornos Pós queda", na.action = na.pass)
pacf(log_ret_vec[idx_min:p2], main = "PACF - Log-Retornos Pós queda", na.action = na.pass)

set.seed(123)
ret_vec <- as.numeric(ret.1min[1:10000])
sv_fit <- svsample(ret_vec, draws = 5000, burnin = 1000)


min = idx_max-2500
max = idx_max+7500
ret_vec2 <- as.numeric(ret.1min[min:max])
sv_fit2 <- svsample(ret_vec2, draws = 5000, burnin = 1000)


min2 = max+12000
max2 = min2+10000
ret_vec3 <- as.numeric(ret.1min[min2:max2])
sv_fit3 <- svsample(ret_vec3, draws = 5000, burnin = 1000)


plot(sv_fit, showobs = FALSE)
title(main = "Pré queda")
plot(sv_fit2, showobs = FALSE)
title(main = "Pós queda")
plot(sv_fit3, showobs = FALSE)
title(main = "Recuperação Pós queda")
plot(sv_fit_complt, showobs = FALSE)
title(main = "Completo")




rets <- dt1$Ret.1min
segments <- list(
  A = 1:10000,
  B = 11600:22600,
  C = 33600:43600
)
vol_list <- lapply(names(segments), function(seg_name) {
  idx <- segments[[seg_name]]
  r_seg <- rets[idx]
  vol_acum <- sqrt(cumsum(r_seg^2))
  data.frame(
    index   = idx,
    vol     = vol_acum,
    segment = seg_name
  )
})
df_vol <- bind_rows(vol_list)
ggplot(df_vol, aes(x = index, y = vol, color = segment)) +
  geom_line() +
  labs(
    title    = "Volatilidade Realizada Acumulada por Segmento de Índices",
    x        = "Índice",
    y        = "Volatilidade Realizada",
    color    = "Segmento"
  ) +
  theme_minimal()

rets <- dt1$Ret.1min
segments <- list(
  A = 1:10000,
  B = 11600:22600,
  C = 33600:43600
)

vol_list2 <- lapply(names(segments), function(seg_name) {
  idx   <- segments[[seg_name]]
  vol   <- sqrt(rets[idx]^2)
  data.frame(index = idx, vol = vol, segment = seg_name)
})
df_vol_inst <- bind_rows(vol_list2)

plot_segment <- function(df, seg_name) {
  df_sub <- df %>% filter(segment == seg_name)
  ggplot(df_sub, aes(x = index, y = vol)) +
    geom_line() +
    labs(
      title = paste0("Volatilidade Realizada – Segmento ", seg_name),
      x     = "Índice",
      y     = "Volatilidade Realizada (|Retorno|)"
    ) +
    ylim(0, 0.02)+
    theme_minimal()
}

plot_A <- plot_segment(df_vol_inst, "A")
plot_B <- plot_segment(df_vol_inst, "B")
plot_C <- plot_segment(df_vol_inst, "C")

plot_A  
plot_B  
plot_C  


h_mcmc <- sv_fit$latent[[1]]  
h_mat <- as.matrix(h_mcmc)     
dim(h_mat)                    
h_mean <- colMeans(h_mat)     
vol_est <- exp(h_mean / 2)   

time_index <- seq(
  from       = as.POSIXct("2021-01-01 09:31"),
  by         = "1 min",
  length.out = length(vol_est)
)


h_mcmc <- sv_fit2$latent[[1]]  
h_mat <- as.matrix(h_mcmc)     
dim(h_mat)                    
h_mean <- colMeans(h_mat)     
vol_est2 <- exp(h_mean / 2)   

time_index2 <- seq(
  from       = as.POSIXct("2021-01-01 09:31"),
  by         = "1 min",
  length.out = length(vol_est2)
)


h_mcmc <- sv_fit$latent[[1]]  
h_mat <- as.matrix(h_mcmc)     
dim(h_mat)                    
h_mean <- colMeans(h_mat)     
vol_est3 <- exp(h_mean / 2)   

time_index3 <- seq(
  from       = as.POSIXct("2021-01-01 09:31"),
  by         = "1 min",
  length.out = length(vol_est3)
)

h_mcmc <- sv_fit_complt$latent[[1]]  
h_mat <- as.matrix(h_mcmc)     
dim(h_mat)                    
h_mean <- colMeans(h_mat)     
vol_est_complt <- exp(h_mean / 2)   

time_index_complt <- seq(
  from       = as.POSIXct("2021-01-01 09:31"),
  by         = "1 min",
  length.out = length(vol_est_complt)
)

df_est <- data.frame(time = time_index, vol = vol_est)
df_est2 <- data.frame(time = time_index2, vol = vol_est2)
df_est3 <- data.frame(time = time_index3, vol = vol_est3)

par(mfrow = c(3, 1))
plot(df_est)
plot(df_est2)
plot(df_est3)


ggplot(df_est_complt, aes(x = time, y = vol)) +
  geom_line() +
  labs(
    title = "Volatilidade Estocástica (média posterior)",
    x     = "Tempo",
    y     = "σ̂_t"
  ) +
  theme_minimal()

df_test <- data.frame(
  time = dt1$Period,
  vol  = dt1$`Ret.1min`
)

compute_realized_vol <- function(df,
                                 return_col = "vol",
                                 time_col   = "time",
                                 window     = "5 mins") {
  df %>%
    mutate(ret2 = .data[[return_col]]^2) %>%
    mutate(time_window = floor_date(.data[[time_col]], unit = window)) %>%
    group_by(time_window) %>%
    summarise(
      realized_var = sum(ret2, na.rm = TRUE),
      vol = sqrt(realized_var),
      .groups = "drop"
    ) %>%
    rename(!!time_col := time_window)
}

df_rv5 <- compute_realized_vol(df_test,
                               return_col = "vol",
                               time_col   = "time",
                               window     = "5 mins")

tseries::adf.test(df_rv5$vol)


plot_wavelet_levels_modwt_hist <- function(df, levels = 12, df_name = "df_est") {
  
  filter_type <- "haar"
  max_possible_levels <- min(levels, floor(log2(nrow(df))))
  
  modwt_result <- modwt(df$vol, n.levels = max_possible_levels, boundary = "periodic")
  total_plots <- max_possible_levels + 2
  plots_list <- vector("list", total_plots)
  
  for (plot_idx in seq_len(total_plots)) {
    if (plot_idx == 1) {
      plots_list[[plot_idx]] <- ggplot(df, aes(x = time, y = vol)) +
        geom_line(color = "blue") +
        labs(title = paste(df_name, ": Série Original"), x = "Tempo", y = "Volatilidade") +
        theme_minimal()
      
    } else if (plot_idx == total_plots) {
      approx_modwt <- modwt_result
      for (j in seq_len(max_possible_levels)) approx_modwt@W[[j]][] <- 0
      approximation <- imodwt(approx_modwt)
      df_plot <- data.frame(time = df$time, value = approximation)
      
      plots_list[[plot_idx]] <- ggplot(df_plot, aes(x = time, y = value)) +
        geom_line(color = "red") +
        labs(title = paste(df_name, ": Aproximação (Nível", max_possible_levels, ")"),
             x = "Tempo", y = "Valor") +
        theme_minimal()
      
    } else {
      i <- plot_idx - 1
      detail_modwt <- modwt_result
      for (j in seq_len(max_possible_levels)) if (j != i) detail_modwt@W[[j]][] <- 0
      detail_series <- imodwt(detail_modwt)
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
  
  invisible(plots_list)
}

plot_wavelet_levels_modwt_hist(df_est, levels = 12, df_name = "PETR4")


plot_wavelet_levels_modwt_jumps <- function(df, levels = 15, df_name = "df_est", momento) {
  filter_type <- "haar"
  max_levels <- min(levels, floor(log2(nrow(df))))
  
  
  modwt_res <- modwt(df$vol, filter = filter_type, n.levels = max_levels, boundary = "reflection")
  total_plots <- max_levels + 2 
  plots <- vector("list", total_plots)
  
  for (idx in seq_len(total_plots)) {
    if (idx == 1) {
      p <- ggplot(df, aes(x = time, y = vol)) +
        geom_line(color = "blue") +
        labs(title = paste(df_name, ": Série Original"), x = "Tempo", y = "Volatilidade") +
        theme_minimal()
      
    } else if (idx == total_plots) {
      approx <- modwt_res
      for (j in seq_len(max_levels)) approx@W[[j]][] <- 0
      series_approx <- imodwt(approx)
      df_a <- data.frame(time = df$time, value = series_approx[1:nrow(df)])
      
      p <- ggplot(df_a, aes(x = time, y = value)) +
        geom_line(color = "red") +
        labs(title = paste(df_name, ": Aproximação (Nível", max_levels, ")"),
             x = "Tempo", y = "Valor") +
        theme_minimal()
      
    } else {
      i <- idx - 1
      detail <- modwt_res
      for (j in seq_len(max_levels)) if (j != i) detail@W[[j]][] <- 0
      series_det <- imodwt(detail)
      df_d <- data.frame(time = df$time, value = series_det[1:nrow(df)])
      Wj <- modwt_res@W[[i]]
      sigma_j <- median(abs(Wj), na.rm = TRUE) / 0.6745
      thr_j <- sigma_j * sqrt(2 * log(length(Wj)))
      jumps <- which(abs(Wj) > thr_j)
      jumps <- jumps[jumps <= nrow(df)]
      
      df_d$jumps <- NA
      df_d$jumps[jumps] <- df_d$value[jumps]
      
      p <- ggplot(df_d, aes(x = time, y = value)) +
        geom_line(color = "darkgreen") +
        geom_point(data = subset(df_d, !is.na(jumps)),
                   aes(x = time, y = jumps), color = "red", size = 2) +
        labs(title = paste(df_name, momento, ": Detalhe Nível", i, "com Saltos"),
             x = "Tempo", y = "Valor") +
        theme_minimal()
    }
    plots[[idx]] <- p
  }
  
  for (k in seq(1, length(plots), by = 2)) {
    p1 <- plots[[k]]
    p2 <- if ((k+1) <= length(plots)) plots[[k+1]] else NULL
    if (!is.null(p2)) {
      grid.arrange(p1, p2, nrow = 2)
    } else {
      print(p1)
    }
  }
  
  invisible(plots)
}

plot_wavelet_levels_modwt_jumps(df_est, levels = 12, df_name = "PETR4", momento = "Pré queda")

plot_wavelet_levels_modwt_jumps(df_est2, levels = 12, df_name = "PETR4", momento = "Durante a queda")

plot_wavelet_levels_modwt_jumps(df_est3, levels = 12, df_name = "PETR4", momento = "Pós queda")

detect_jumps_modwt <- function(df, levels = 12) {
  filter_type <- "haar"
  max_levels <- min(levels, floor(log2(nrow(df))))
  modwt_res <- modwt(df$vol, filter = filter_type, n.levels = max_levels, boundary = "reflection")
  jump_indices_list <- vector("list", max_levels)
  for (level in seq_len(max_levels)) {
    Wj <- modwt_res@W[[level]]
    sigma_j <- median(abs(Wj), na.rm = TRUE) / 0.6745
    thr_j <- sigma_j * sqrt(2 * log(length(Wj)))
    idx <- which(abs(Wj) > thr_j)
    jump_indices_list[[level]] <- idx[idx <= nrow(df)]
  }
  list(modwt = modwt_res, jumps = jump_indices_list)
}

model_jump_intensity <- function(df, jump_list, window = "hour", df_name = "df_est",momento) {
  intensity_plots <- list()
  for (level in seq_along(jump_list)) {
    idx <- jump_list[[level]]
    if (length(idx) == 0) next
    times <- df$time[idx]
    df_counts <- data.frame(time = times) %>%
      mutate(interval = floor_date(time, unit = window)) %>%
      count(interval)
    fit <- glm(n ~ 1, family = poisson, data = df_counts)
    lambda_hat <- exp(coef(fit))
    p <- ggplot(df_counts, aes(x = interval, y = n)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      geom_hline(yintercept = lambda_hat, linetype = "dashed", color = "red") +
      labs(title = paste(df_name, momento, ": Intensidade de Saltos - Nível", level),
           subtitle = paste("Lambda estimado =", round(lambda_hat, 3)),
           x = paste("Intervalo (", window, ")", sep = ""), y = "Contagem de Saltos") +
      theme_minimal()
    intensity_plots[[level]] <- p
  }
  plot_indices <- which(!sapply(intensity_plots, is.null))
  for (k in seq(1, length(plot_indices), by = 2)) {
    p1 <- intensity_plots[[plot_indices[k]]]
    p2 <- if ((k+1) <= length(plot_indices)) intensity_plots[[plot_indices[k+1]]] else NULL
    if (!is.null(p2)) {
      grid.arrange(p1, p2, nrow = 2)
    } else {
      print(p1)
    }
  }
  invisible(intensity_plots)
}

res <- detect_jumps_modwt(df_est, levels = 12)
model_jump_intensity(df_est, res$jumps, window = "hour", df_name = "PETR4",momento = "Pré queda")


res2 <- detect_jumps_modwt(df_est2, levels = 12)
model_jump_intensity(df_est2, res2$jumps, window = "hour", df_name = "PETR4",momento = "Durante a queda")

res3 <- detect_jumps_modwt(df_est3, levels = 12)
model_jump_intensity(df_est3, res3$jumps, window = "hour", df_name = "PETR4",momento = "Pós queda")

res <- detect_jumps_modwt(df_est2, levels = 12)
jumps_vec <- unlist(res$jumps)
jump_idx <- which(!is.na(jumps_vec) & jumps_vec != 0)
cat("Saltos detectados em", length(jump_idx), "instantes\n")
ret       <- df_est2$vol
ret_clean <- ret
ret_clean[jump_idx] <- 0

sv_fit_orig <- svsample(y = ret,       draws = 5000, burnin = 1000,
                        priormu = c(0,10), priorphi = c(20,1.1),
                        priorsigma = 1)
sv_fit_clean<- svsample(y = ret_clean, draws = 5000, burnin = 1000,
                        priormu = c(0,10), priorphi = c(20,1.1),
                        priorsigma = 1)

h_draws_orig  <- latent(sv_fit_orig)
h_draws_clean <- latent(sv_fit_clean)
h_mean_orig  <- colMeans(as.matrix(h_draws_orig))
h_mean_clean <- colMeans(as.matrix(h_draws_clean))
h_mean_orig  <- h_mean_orig[-1]
h_mean_clean <- h_mean_clean[-1]
sigma_orig  <- exp(h_mean_orig / 2)
sigma_clean <- exp(h_mean_clean / 2)
library(ggplot2)
p1 <- ggplot(data = data.frame(time = df_est$time, sigma = sigma_orig),
             aes(x = time, y = sigma)) +
  geom_line() +
  ggtitle("SV: Série Original (com saltos)") +
  xlab("Tempo") + ylab("σₜ")

p2 <- ggplot(data = data.frame(time = df_est$time, sigma = sigma_clean),
             aes(x = time, y = sigma)) +
  geom_line() +
  ggtitle("SV: Série Limpa (saltos zerados)") +
  xlab("Tempo") + ylab("σₜ")

library(gridExtra)
grid.arrange(p1, p2, nrow = 2)

spec_garch <- ugarchspec(
  variance.model     = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model         = list(armaOrder = c(0, 0), include.mean = FALSE),
  distribution.model = "std"
)

fit_garch_orig  <- ugarchfit(spec = spec_garch, data = ret,       solver = "hybrid")
fit_garch_clean <- ugarchfit(spec = spec_garch, data = ret_clean, solver = "hybrid")

aic_orig   <- infocriteria(fit_garch_orig)["Akaike"]
bic_orig   <- infocriteria(fit_garch_orig)["Bayes"]
aic_clean  <- infocriteria(fit_garch_clean)["Akaike"]
bic_clean  <- infocriteria(fit_garch_clean)["Bayes"]

resid_orig <- residuals(fit_garch_orig, standardize = TRUE)
acf(resid_orig, main = "ACF Resíduos Padronizados (Orig.)")
pacf(resid_orig, main = "PACF Resíduos Padronizados (Orig.)")
