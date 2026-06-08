# Metodologia: Análise de Volatilidade Estocástica em Janelas de Quebra Estrutural — Ações da IBM

---

## 1. Visão Geral do Estudo

O estudo analisa a **dinâmica de volatilidade das ações da IBM** ao longo de múltiplos regimes de mercado, combinando detecção de quebras estruturais (Bai-Perron) com estimação bayesiana de volatilidade estocástica (SV-MCMC). O objetivo central é responder: *como os parâmetros estruturais da volatilidade — nível, persistência e erraticidade — se transformam antes, durante e depois de eventos de ruptura de mercado?*

O estudo é inteiramente baseado em dados intradiários e diários de preços de fechamento da IBM, extraídos de um arquivo CSV com frequência de 1 minuto.

---

## 2. Coleta e Pré-processamento dos Dados

### 2.1 Dados Brutos
Os dados são preços de fechamento intradiários da IBM com granularidade de 1 minuto, lidos de `IBM_data.csv`. Cada observação contém data, hora e preço de fechamento.

### 2.2 Filtragem do Horário de Pregão
O código aplica um filtro rigoroso sobre o horário de negociação para evitar efeitos de abertura e fechamento do mercado:

- São **excluídos** os primeiros 40 minutos após a abertura (9h00–9h39), pois esse período costuma apresentar volatilidade atípica de abertura.
- São **excluídas** as últimas observações próximas ao fechamento (a partir de 15h56).
- São mantidos apenas os dados entre 9h40 e 15h55.
- Dias com menos de 100 observações são descartados (pregões incompletos).

### 2.3 Cálculo dos Retornos de 1 Minuto
Os retornos são calculados como retornos aritméticos simples:

$$r_t = \frac{P_t - P_{t-1}}{P_{t-1}}$$

### 2.4 Tratamento de Outliers
Retornos com desvio superior a 10 desvios-padrão em relação à média são substituídos pelo último valor válido disponível (*last observation carried forward* — LOCF), usando a função `zoo::na.locf`. Isso remove picos extremos provavelmente causados por erros de dados.

### 2.5 Construção da Série Diária
A série intradiária é agregada para a frequência diária, tomando o último preço de fechamento de cada pregão. O retorno diário é calculado como:

$$r_t^{diário} = \frac{P_t^{close} - P_{t-1}^{close}}{P_{t-1}^{close}}$$

---

## 3. Detecção de Quebras Estruturais — Teste de Bai-Perron

### 3.1 Fundamento Teórico
O método de **Bai-Perron (1998, 2003)** generaliza o teste de Chow para a situação em que o número e a localização das quebras são desconhecidos. O modelo linear com $m$ quebras é:

$$y_t = \mathbf{x}_t' \boldsymbol{\beta}_j + \varepsilon_t, \quad t = T_{j-1}+1, \ldots, T_j, \quad j = 1,\ldots,m+1$$

Os pontos de quebra $T_1 < T_2 < \cdots < T_m$ são estimados **conjuntamente** pela minimização da soma dos quadrados dos resíduos dentro de cada segmento:

$$\{\hat{T}_1, \ldots, \hat{T}_m\} = \arg\min_{T_1,\ldots,T_m} \sum_{j=1}^{m+1} \sum_{t=T_{j-1}+1}^{T_j} (y_t - \bar{y}_j)^2$$

A busca é feita por **programação dinâmica** em tempo $O(n^2)$. O número ótimo de quebras é selecionado pelo critério BIC.

### 3.2 Transformação da Variável Dependente
A série aplicada ao Bai-Perron **não são os retornos em si**, mas sim $\log(r_t^2)$ — o logaritmo do quadrado dos retornos diários. Essa transformação é fundamental por duas razões:

1. **Linearização da volatilidade:** a decomposição $\log(r_t^2) = \log(\sigma_t^2) + \log(z_t^2)$ transforma a estrutura multiplicativa da volatilidade em aditiva, onde $\log(z_t^2)$ atua como ruído quasi-gaussiano com média conhecida.

2. **Estacionariedade:** $\log(r_t^2)$ é estacionário, tornando o procedimento de Bai-Perron válido estatisticamente.

Um pequeno offset ($10^{-10}$) é adicionado para evitar $\log(0)$ em casos de retorno nulo.

### 3.3 Parâmetro de Sensibilidade `h`
O parâmetro `h` controla o **tamanho mínimo de cada segmento** como fração do total de observações. O estudo usa `h = 0.05` como configuração principal (cada segmento deve ter ao menos 5% do total de observações). O código prevê também comparações com `h = 0.10` e `h = 0.01`, permitindo avaliar a robustez dos breakpoints identificados.

### 3.4 Resultado: Três Breakpoints Identificados
O modelo Bai-Perron identificou (ou foram fixados manualmente com base em resultados prévios) três datas de quebra estrutural na log-volatilidade da IBM:

| Evento | Data do Breakpoint | Contexto Econômico |
|--------|-------------------|-------------------|
| Evento 1 | 30/07/2003 | Período pré-crise do subprime |
| Evento 2 | 15/10/2007 | Início da turbulência financeira global / crise subprime |
| Evento 3 | 03/06/2009 | Instabilidade na recuperação pós-Lehman Brothers |

> **Nota metodológica:** o código contém um *override* manual (`bp_override`) que permite substituir os breakpoints calculados pelo modelo por datas pré-definidas. Isso indica que os resultados foram calibrados com base em conhecimento histórico prévio dos eventos de mercado.

---

## 4. Teste ARCH-LM: Verificação de Clustering de Volatilidade

### 4.1 Fundamento Teórico
O teste **ARCH-LM (Engle, 1982)** verifica se os resíduos ao quadrado apresentam autocorrelação, indicando heterocedasticidade condicional — ou seja, se períodos de alta volatilidade tendem a ser seguidos por mais alta volatilidade (*volatility clustering*).

O modelo ARCH($q$) postula:
$$\sigma_t^2 = \omega + \sum_{i=1}^{q} \alpha_i\,\varepsilon_{t-i}^2$$

A estatística de teste é:
$$LM = n \cdot R^2 \;\sim\; \chi^2(q)$$

### 4.2 Configuração
- **Defasagens:** $q = 5$ (capturando clustering de curto prazo — cinco dias de pregão)
- **Nível de significância:** $\alpha = 0.05$
- **Janelas:** 60 dias antes e 60 dias depois de cada breakpoint
- **Hipótese nula:** sem efeito ARCH (variância constante)

### 4.3 Propósito
A rejeição da hipótese nula confirma que a volatilidade ao redor de cada breakpoint é **heterocedástica**, validando economicamente a relevância dos pontos de quebra identificados pelo Bai-Perron e justificando o uso do modelo de volatilidade estocástica.

---

## 5. Construção das Janelas Temporais dos Eventos

Para cada um dos três breakpoints, a série diária é dividida em três janelas de análise de **60 dias de pregão** cada:

| Janela | Definição |
|--------|-----------|
| **Pre** | $[D - 60, D - 1]$ — 60 dias anteriores ao breakpoint |
| **During** | $[D, D + 60]$ — do breakpoint até 60 dias após |
| **Post** | $[D + 61, D + 120]$ — 60 dias subsequentes ao período "during" |

Isso gera **9 segmentos** ao todo (3 eventos × 3 fases), cada um com aproximadamente 60 observações diárias.

---

## 6. Variância Realizada, Bipower e Testes de Saltos

### 6.1 Variância Realizada (RV)
A variância realizada para cada segmento é calculada como a soma dos quadrados dos retornos diários:
$$RV = \sum_{t} r_t^2$$

### 6.2 Variação Bipower (BV)
A Variação Bipower, introduzida por Barndorff-Nielsen e Shephard (2004), é robusta à presença de saltos de preço:
$$BV = \left(\frac{\pi}{2}\right)^{-1} \sum_{t=2}^{T} |r_t| \cdot |r_{t-1}|$$

A diferença $RV - BV$ é usada como estimativa da **componente de salto** da variação total, com truncamento em zero para evitar valores negativos.

### 6.3 Inferência sobre Diferenças de RV
Para testar se a variância realizada muda significativamente entre janelas, o estudo usa dois métodos não-paramétricos:

- **Teste Permutacional (R = 2.000 reamostras):** testa se a diferença observada em $RV$ entre dois segmentos poderia ter ocorrido por acaso.
- **Bootstrap com IC BCA (R = 1.500 reamostras):** constrói intervalos de confiança bootstrap para cada $RV$ individual usando o método *bias-corrected and accelerated*.

### 6.4 Testes de Homogeneidade de Variância e Distribuição
- **Teste de Levene:** compara a dispersão dos retornos entre as três janelas (pré, durante e pós) dentro de cada evento, sendo robusto a desvios de normalidade.
- **Teste de Kolmogorov-Smirnov (KS):** compara as distribuições empíricas completas dos retornos entre pares de janelas, detectando diferenças não apenas na variância mas em toda a forma da distribuição.

---

## 7. Modelo de Volatilidade Estocástica (SV) — Estimação Bayesiana via MCMC

### 7.1 Especificação do Modelo
Para cada um dos **9 segmentos** (3 eventos × 3 fases), é estimado um modelo de **Volatilidade Estocástica (SV)** independente, com a seguinte especificação padrão:

**Equação de observação:**
$$r_t = \exp\left(\frac{h_t}{2}\right) \varepsilon_t, \quad \varepsilon_t \sim \mathcal{N}(0, 1)$$

**Equação de transição (log-volatilidade latente):**
$$h_t = \mu + \phi(h_{t-1} - \mu) + \sigma \eta_t, \quad \eta_t \sim \mathcal{N}(0, 1)$$

Os parâmetros estruturais são:
- $\mu$ — **nível médio** da log-volatilidade
- $\phi$ — **persistência** da volatilidade (coeficiente AR(1) do processo latente; $|\phi| < 1$ para estacionariedade)
- $\sigma$ — **volatilidade da volatilidade** (vol-of-vol), mensurando quão errática é a volatilidade

### 7.2 Estimação: MCMC Bayesiano com o pacote `stochvol`
Os 9 modelos são estimados com o pacote R `stochvol`, que implementa o **Sampler de Kastner & Frühwirth-Schnatter (2014)** — um amostrador MCMC altamente eficiente para modelos SV, baseado em amostragem auxiliar com mistura de normais (ASIS).

**Configuração do MCMC:**
- Número de draws: 5.000
- Burn-in: 1.000
- Thinning sistemático para no máximo 2.000 draws (para gestão de memória)

Os modelos estimados são salvos em arquivos `.rds` e reutilizados em execuções posteriores para evitar re-execução do MCMC.

### 7.3 Métricas Derivadas dos Parâmetros Posteriores
A partir das distribuições posteriores de $(\mu, \phi, \sigma)$ para cada segmento, são calculadas as seguintes métricas:

| Métrica | Fórmula | Interpretação |
|---------|---------|---------------|
| **Meia-vida do choque** | $\log(0.5)/\log(\phi)$ | Dias para um choque de volatilidade decair à metade |
| **Variância incondicional** | $\sigma^2 / (1 - \phi^2)$ | Variabilidade de longo prazo da log-vol |
| **Índice de previsibilidade** | $\phi / (1 + \sigma)$ | Razão entre persistência e erraticidade |
| **CV latente** | $\text{sd}(\exp(h_t)) / \text{mean}(\exp(h_t))$ | Coeficiente de variação da volatilidade latente dentro do segmento |

### 7.4 Volatilidade Anualizada Posterior
Para cada draw do MCMC, a volatilidade anualizada é calculada a partir dos estados latentes $h_t$:

$$\text{Vol}_{anual} = \sqrt{\text{mean}_t(\exp(h_t))} \times \sqrt{252}$$

Isso gera uma distribuição posterior completa da volatilidade anualizada para cada segmento, permitindo inferência bayesiana direta sobre incerteza paramétrica.

---

## 8. Análise Comparativa dos 9 Segmentos

### 8.1 Tabela Mestra de Parâmetros
Para cada um dos 9 segmentos, são reportadas as estatísticas posteriores (média, desvio-padrão, IC 95%) de $\mu$, $\phi$, $\sigma$, meia-vida, variância incondicional, índice de previsibilidade e CV latente.

### 8.2 Heatmap com Z-scores
As métricas são padronizadas por z-score dentro de cada variável para criar um heatmap comparativo dos 9 segmentos, facilitando a identificação visual de regimes distintos de volatilidade.

### 8.3 Plano de Previsibilidade (φ × σ)
Os 9 segmentos são plotados em um espaço bidimensional com $\phi$ no eixo Y e $\sigma$ no eixo X, dividido em quatro quadrantes:

| Quadrante | Característica |
|-----------|---------------|
| Alta vol / Previsível | $\phi$ alto, $\sigma$ baixo |
| Alta vol / Errática | $\phi$ alto, $\sigma$ alto |
| Baixa vol / Previsível | $\phi$ baixo, $\sigma$ baixo |
| Baixa vol / Errática | $\phi$ baixo, $\sigma$ alto |

### 8.4 Comparações Pairwise Bayesianas
A probabilidade posterior $P(\sigma_A > \sigma_B)$ é calculada para todos os 81 pares de segmentos, constituindo um teste bayesiano direto de diferença de erraticidade entre regimes.

### 8.5 Ranking Final
Os 9 segmentos são ordenados pelo índice de previsibilidade $\phi/(1+\sigma)$, e cada segmento recebe uma classificação de regime com base nos quadrantes do plano de previsibilidade.

---

## 9. Visualizações Produzidas

O estudo produz um conjunto extenso de visualizações diagnósticas e analíticas:

1. Série temporal de preços e retornos intradiários (1 min)
2. Boxplot dos retornos brutos
3. Série de $\log(r_t^2)$ com linhas dos breakpoints Bai-Perron
4. Comparação dos breakpoints para diferentes valores de `h`
5. Janelamentos coloridos (pre/during/post) sobre o preço diário
6. Estatística LM do teste ARCH-LM pré vs. pós breakpoint (gráfico de barras)
7. Plots diagnósticos MCMC para cada um dos 9 modelos SV
8. Volatilidade realizada acumulada por janela e evento
9. Densidades posteriores da volatilidade anualizada por evento (pré/during/pós)
10. Violin + boxplot posterior por evento
11. Comparação consolidada dos 3 eventos (média posterior + IC 95%)
12. Heatmap z-scored de perfis SV dos 9 segmentos
13. Plano de previsibilidade φ × σ (4 quadrantes)
14. Meia-vida dos choques por segmento (barras + IC 95%)
15. Nível médio μ vs. meia-vida (diagrama de dispersão)
16. Índice de previsibilidade vs. CV latente
17. Matriz pairwise $P(\sigma_A > \sigma_B)$
18. Distribuições posteriores de σ e φ para todos os segmentos

---

## 10. Síntese Metodológica

O estudo combina quatro camadas metodológicas complementares:

| Camada | Método | Propósito |
|--------|--------|-----------|
| **Detecção de regime** | Bai-Perron sobre $\log(r_t^2)$ | Identificar datas de mudança estrutural na log-volatilidade |
| **Validação dos breakpoints** | ARCH-LM (q=5) | Confirmar que os pontos de quebra têm relevância econômica |
| **Mensuração frequentista** | RV, BV, saltos, testes permutacionais, Levene, KS | Quantificar diferenças de variância e distribuição entre janelas |
| **Estimação bayesiana** | Modelo SV (MCMC) por segmento | Inferir a dinâmica latente da volatilidade (nível, persistência, erraticidade) |

A contribuição central do estudo está na combinação da detecção objetiva de quebras com a estimação dos **parâmetros estruturais da dinâmica de volatilidade** dentro de cada regime, permitindo uma caracterização mais rica do comportamento da volatilidade do que abordagens puramente baseadas em GARCH ou em medidas de dispersão realizadas.

---
---

# PROMPT PARA O CONSENSUS

> Copie e cole o texto abaixo diretamente no Consensus para busca de validação acadêmica:

---

**PROMPT:**

I am conducting a study on the stochastic volatility dynamics of IBM stock returns around structural break points. The methodology combines the Bai-Perron (1998, 2003) multiple structural break test with Bayesian estimation of Stochastic Volatility (SV) models via MCMC, using the `stochvol` R package (Kastner & Frühwirth-Schnatter, 2014). I would like to know whether this methodological combination is supported by the academic literature.

The specific approach is as follows:

1. Daily returns are computed from intraday 1-minute closing prices of IBM stock, with the first 40 minutes of trading excluded to avoid opening-effect bias.

2. The Bai-Perron structural break test is applied to the series log(r_t²) — the logarithm of squared daily returns — rather than to raw returns. The rationale is that this transformation linearizes the volatility structure (since log(r_t²) = log(σ_t²) + log(z_t²), where the second term acts as quasi-Gaussian noise) and makes the series approximately stationary, satisfying Bai-Perron's assumptions. Up to 3 simultaneous breaks are allowed, with minimum segment size h = 0.05.

3. The identified breakpoints define three time windows around each structural break: a pre-event window (60 trading days before), a during-event window (60 days starting from the break), and a post-event window (60 days after the during window). This yields 9 total segments (3 breakpoints × 3 phases).

4. For each of the 9 segments, an independent standard SV model is estimated via MCMC: r_t = exp(h_t/2)·ε_t and h_t = μ + φ(h_{t-1} − μ) + σ·η_t. The posterior distributions of μ (log-volatility level), φ (persistence), and σ (volatility-of-volatility) are used to characterize each regime.

5. Derived metrics include shock half-life (log(0.5)/log(φ)), unconditional variance (σ²/(1−φ²)), a predictability index (φ/(1+σ)), and the coefficient of variation of the latent variance states exp(h_t).

6. Supplementary frequentist tests include the ARCH-LM test (Engle, 1982) to validate volatility clustering around breakpoints, Realized Variance and Bipower Variation (Barndorff-Nielsen & Shephard, 2004) to decompose variance into continuous and jump components, permutation tests for RV differences, Levene's test for variance homogeneity, and Kolmogorov-Smirnov tests for distributional equality across windows.

**My questions for the literature search:**

(a) Is applying the Bai-Perron test to log(r_t²) a recognized and valid approach for detecting volatility regime changes in financial time series?

(b) Is the combination of Bai-Perron structural break detection with subsequent Bayesian SV model estimation a methodologically sound approach for regime-specific volatility analysis? Are there published studies that use a similar pipeline?

(c) Is the use of fixed symmetric event windows (pre/during/post) around statistically detected breakpoints — rather than using the full segmented series — a valid design choice? Does this introduce selection bias concerns?

(d) Are the derived metrics (predictability index φ/(1+σ), shock half-life) used in the academic SV literature as comparative measures across regimes?

(e) What are the main limitations or criticisms of this methodology in the literature?

Please retrieve peer-reviewed studies directly relevant to these questions.
