library(sp); library(spdep); library(splm); library(plm)
library(RColorBrewer); library(classInt); library(lattice)
library(stargazer); library(sf); library(maptools); library(tmap) 
library(tmaptools); library(tidyverse); library(summarytools)
library(rgeoda); library(tidylog)

setwd("C:/Users/ggarci24/OneDrive - Universidad EAFIT/EAFIT/Cursos EAFIT")

# Datos sobre crimen por estados en EE.UU
data <- read.csv("./Econometr�a espacial/R/L7/Panel espaciales/crimes_ts.csv", header = TRUE, sep = ",", dec=".") %>%
        filter(!fipsstat %in% c(2, 15)) # Borrando Alaska y Hawaii
View(data)
freq(data$fipsstat)

# An�lisis de la tasa de muertes violentas (mur) para 1999
data_mur99 <- data |> 
  filter(year==99) |> select(fipsstat, state, mur)

plot_mur <- ggplot(data_mur99, aes(x = fct_reorder(state, mur), y = mur)) + 
  geom_segment(aes(x = fct_reorder(state, mur), xend = state,
                   y = 0, yend = mur), color = "gray75") + 
  geom_point(size = 2.5, aes(colour = mur)) +
  scale_colour_viridis_c("", limits = c(min(data_mur99$mur), max(data_mur99$mur)),
                         direction = -1) +
  geom_hline(yintercept = median(data_mur99$mur), colour = "#3D205E", alpha = 0.5) +
  annotate("text", label = paste0("median = ", round(median(data_mur99$mur),2)), 
           x = 15, y = round(median(data_mur99$mur),2), size = 3, alpha = 0.5,   
           colour = "#3D205E", angle = 90, vjust = 1, hjust = 1)   + 
  coord_flip(ylim = c(min(data_mur99$mur), max(data_mur99$mur))) + 
  labs(title = "Murder rate 1999", x = "", y = "") +
  theme(axis.title.x = element_text(size = 9),
        axis.text = element_text(size = 8),
        legend.key.size = unit(0.3, "cm"), 
        legend.key.width = unit(0.3,"cm"),
        legend.text=element_text(size=6),
        legend.position = c(0.9,0.5),
        legend.background = element_rect(fill=NA))
plot_mur

ggsave(plot=plot_mur, "./Econometria II Maestr�a Eco/R/2021-II/Tema 4/plot_mur.png",
       width = 7, height = 5, units = "in", dpi = 300)

# Cargando el mapa 
us <- st_read("./Econometria II Maestr�a Eco/ToDo/cb_2018_us_state_5m/cb_2018_us_state_5m.shp") %>%
      filter(!is.na(STUSPS) & !STUSPS %in% c('AK','HI','GU','AS','PR','VI', 'MP')) %>% # Eliminando los NA, Alaska, Hawaii, Guam, American Samoa, Puerto Rico, Islas Virgin
      mutate(fipsstat = as.numeric(STATEFP)) %>%
      arrange(fipsstat) %>% st_transform(crs = 4326)
  
View(us)
names(us)
plot(us)

tm_shape(us) +
  tm_polygons(col = 'gray95', border.col = "gray90") +
  tm_text("STUSPS", scale=.3)

ggplot(us) + 
  geom_sf(data=us, colour = "gray95", fill = "gray90") +
  geom_sf_text(aes(label = STUSPS), size=1.5, colour = "black") +
  theme_void()

# Pegando los datos al mapa, utilizando la llave FIPS
data99 <- data |> 
  filter(year==99)

us_merge <- left_join(us,data99)|> 
  select(STUSPS, fipsstat, state, mur)
View(us_merge)

# Mapiando rap
tm_shape(us_merge) +
  tm_polygons("mur",palette="Reds", id="fipsstat") + 
  tm_text("STUSPS", col="gray70", scale=.7) +
  tm_compass(type = "8star", position = c("right", "bottom")) +
  tm_scale_bar(breaks = c(0, 100, 200), text.size = 1)

ggplot(us_merge) + 
  geom_sf(aes(fill = mur), color = "gray95", size = 0.05) +
  geom_sf_text(aes(label = STUSPS), size=1.5, colour = "black") +
  scale_fill_viridis_c(direction = -1) +
  labs(fill="Murder in 1999") +
  theme_void() +
  theme(legend.position = c(.85,.2),
        legend.key.size = unit(0.3,"cm"),
        legend.text=element_text(size=3),
        legend.title=element_text(size=5))

ggsave("./Econometria II Maestr�a Eco/R/2021-II/Tema 4/map_rap.png",
       width = 10, height = 9, units = "cm", dpi = 300)

tmap_mode("view")
tm_shape(us_merge) +
  tm_polygons("mur", title="Murder in 1999", palette="Reds", id="NAME", n=4,style="equal") + 
  tm_text("STUSPS", col="gray95", scale=.9) + 
  tm_basemap(server="http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",alpha=0.5) +
  tm_view(view.legend.position = c("right", "bottom"))

tm_shape(us_merge) +
  tm_polygons("mur", title="Murder in 1999", palette="Reds", id="NAME", breaks=c(1.5,13,24,47)) + 
  tm_text("STUSPS", col="gray95", scale=.9) + 
  tm_basemap(server="http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",alpha=0.5) +
  tm_view(view.legend.position = c("right", "bottom"))

tmap_mode("plot")
tmap_save(filename = "./Econometria II Maestr�a Eco/R/2021-II/Tema 4/mymap.png",
          units = "cm", dpi = 300)

# Webs de mapas: https://geocompr.robinlovelace.net/adv-map.html
#                https://spatialanalysis.github.io/lab_tutorials/4_R_Mapping.html

# Construyendo la matriz de pesos espaciales tipo Queen
nb <- poly2nb(us,queen=T)
nb

We <- nb2listw(nb, style="W")
names(We)
We$weights

# Graficando la contiguidad
cnt <- st_centroid(us, of_largest_polygon = T) # construyendo los centroides
centroides <- cnt %>% st_coordinates()

line_nb <- nb2lines(nb, coords = centroides, proj4string = 4326, as_sf = T)

tm_shape(us)+tm_borders()+
  tm_shape(cnt)+tm_dots(col = 'red', size = 0.5)+
  tm_shape(line_nb) + tm_lines(col = 'navy')

ggplot() +
  geom_sf(data=us, colour = "gray95", fill = "gray90") +
  geom_sf(data=cnt, color="red")  +
  geom_sf(data = line_nb, fill = "grey40", size=.4) +
  theme_void()

# ESDA
# Contraste global de autocorrelaci�n espacial
# I de Moran
us_merge$lmur <- log(us_merge$mur)
moran.test(us_merge$lmur, We)
moran.mc(us_merge$lmur, listw=We, nsim=9999)

# Scatterplot de Moran
# Opci�n 1
# Forma sin editar
mp <- moran.plot(as.vector(scale(us_merge$lmur)), We,
           labels=as.character(us_merge$state), pch=19)

moran.plot(as.vector(scale(us_merge$lmur)), We, labels=as.character(us_merge$state),
           xlim=c(-4,4), ylim=c(-4,4), pch=19, xlab="Log murder", 
           ylab="Spatial lag Log murder")
title("Moran scatterplot")
text(x=2.5, y=-3,"Moran's I=0.4637",cex=.7)
text(x=2.5, y=-3.6,"P-value=0.000",cex=.7)

# Opci�n 2
us_merge$st_lmur <- scale(us_merge$lmur)
us_merge$lag_st_lmur <- lag.listw(We, us_merge$st_lmur)
scatt_imoran <- ggplot(us_merge, aes(x=st_lmur, y=lag_st_lmur)) + 
                        geom_point(shape=1, size=1) + 
                        geom_smooth(formula=y ~ x, method="lm", se=F) + 
                        geom_hline(yintercept=0, lty=2) + 
                        geom_vline(xintercept=0, lty=2) + 
                        theme_minimal() +
                        geom_point(data=mp[mp$is_inf,], aes(x=x, y=wx), shape=7, size=1) +
                        geom_text(data=mp[mp$is_inf,], aes(x=x, y=wx, label=labels, vjust=1), size=2) +
                        xlim(-2.5,4) + ylim(-4,3) +
                        xlab("Log murder") + 
                        ylab("Spatial lag Log murder") + 
                        theme(axis.title.y = element_text(size = rel(.6)),
                              axis.title.x = element_text(size = rel(.6))) +
                        annotate("text", x = 2, y = -3, label = "Moran's I = 0.4637", size=2) +
                        annotate("text", x=2, y=-3.3, label="P-value = 0.000", size=2)
scatt_imoran
ggsave("./Econometria II Maestr�a Eco/R/2021-II/Tema 4/scatt_imoran.png", 
       plot=scatt_imoran, width = 7, height = 4, units = "in", dpi = 300)

# Opci�n 3
us_merge <- us_merge %>%
            mutate(lisa_group = case_when(st_lmur>=0 & lag_st_lmur>=0 ~ "HH",
                                          st_lmur<0 & lag_st_lmur<0 ~ "LL",
                                          st_lmur>=0 & lag_st_lmur<0 ~ "HL",
                                          st_lmur<0 & lag_st_lmur>=0 ~ "LH"))
freq(us_merge$lisa_group)


scatt_imoran2 <- ggplot(us_merge,aes(st_lmur, lag_st_lmur)) +
  geom_smooth(formula=y ~ x, method="lm", se=F, size = .5) +
  geom_point(aes(st_lmur, lag_st_lmur, color = lisa_group), size=.5) +
  geom_text(aes(st_lmur, lag_st_lmur, label=STUSPS, vjust=1.8, color = lisa_group), size=1) +
  geom_vline(aes(xintercept = 0), lty = 2, alpha = 1/3) +
  geom_hline(aes(yintercept = 0), lty = 2, alpha = 1/3) + 
  labs(y = "Spatial lag Log murder",
       x = "Log murder", color=NULL) +
  theme_minimal() +
  scale_color_manual(values=c("red", "lightpink", "skyblue2","blue")) +
  theme(axis.title.y = element_text(size = rel(.5)),
        axis.title.x = element_text(size = rel(.5)),
        legend.text = element_text(size = 5),
        legend.spacing.x = unit(.01, 'cm'),
        axis.text=element_text(size=4),
        legend.key = element_rect(size = 2, color = 'white'),
        legend.key.size = unit(.5, 'lines')) +
  annotate("text", x = 2, y = -3, label = "Moran's I = 0.4637", size=1.5) +
  annotate("text", x=2, y=-3.2, label="P-value = 0.000", size=1.5) 
  
scatt_imoran2
ggsave("./Econometria II Maestr�a Eco/R/2021-II/Tema 4/scatt_imoran2.png", 
       plot=scatt_imoran2, width = 3, height = 2, units = "in", dpi = 300)

# Contrastes locales de autocorrelaci�n espacial
# Local I de Moran
# A positive value for Ii indicates that the unit is surrounded by units with similar values
lmoran <- localmoran(us_merge$lmur, We)
View(lmoran)
summary(lmoran)

# Plot local Moran
moran.map <- cbind(us_merge, lmoran)
names(moran.map)
View(moran.map[,c("STUSPS","state","mur","lmur","st_lmur","lag_st_lmur","Ii", "Pr.z...0.")])

mur_map <- tm_shape(moran.map) +
  tm_polygons("mur",
          border.col = "gray35",
          n = 5,
          style = "quantile",
          palette = "BuPu",
          title = "Murder rate") +
  tm_text("STUSPS", col="gray50", scale=.9)
mur_map

summary(moran.map$Ii)
Ii_mur <- tm_shape(moran.map) +
          tm_polygons("Ii",
              border.col = "gray35",
              breaks = c(-.5, 0, 3),
              pal = c("white", "skyblue"),
              labels = c("(-)", "(+)"),
              title = "Local moran stat") +
  tm_text("STUSPS", col="gray80", scale=.7)
Ii_mur

mur_maps <- tmap_arrange(mur_map,Ii_mur)
mur_maps
tmap_save(tm = mur_maps, 
          filename = "./Econometria II Maestr�a Eco/R/2021-II/Tema 4/mur_map.png",
          height = 10)

# Plot LISA clusters
# builds a data quadrant
moran.map$quad_sig <- NA

# high-high quadrant
moran.map[(moran.map$st_lmur >= 0 & 
             moran.map$lag_st_lmur >= 0) & 
           (moran.map$"Pr.z...0." <= 0.05), "quad_sig"] <- "high-high"

# low-low quadrant
moran.map[(moran.map$st_lmur <= 0 & 
             moran.map$lag_st_lmur <= 0) & 
            (moran.map$"Pr.z...0." <= 0.05), "quad_sig"] <- "low-low"

# high-low quadrant
moran.map[(moran.map$st_lmur >= 0 & 
             moran.map$lag_st_lmur <= 0) & 
            (moran.map$"Pr.z...0." <= 0.05), "quad_sig"] <- "high-low"

# low-high quadrant
moran.map[(moran.map$st_lmur <= 0 & 
             moran.map$lag_st_lmur >= 0) & 
            (moran.map$"Pr.z...0." <= 0.05), "quad_sig"] <- "low-high"

# non-significant observations
moran.map[(moran.map$"Pr.z...0." > 0.05), "quad_sig"] <- "not signif."  

moran.map$quad_sig = factor(moran.map$quad_sig,
                            levels = c("high-high", 
                                       "low-low", 
                                       "high-low", 
                                       "low-high", 
                                       "not signif.")) # convert to factor

freq(moran.map$quad_sig)

Ii_sig_mur <- tm_shape(moran.map) +
  tm_polygons("quad_sig",
              border.col = "gray50",
              pal = c("red", "blue", "lightpink", "skyblue2", "white"),
              labels = c("High-High", "Low-Low", "High-Low", "Low-High", "Not Signif."),
              title = "LISA") +
  tm_text("STUSPS", col="gray80", scale=.7)
Ii_sig_mur

mur_maps <- tmap_arrange(mur_map,Ii_mur,Ii_sig_mur)
mur_maps
tmap_save(tm = mur_maps, 
          filename = "./Econometria II Maestr�a Eco/R/2021-II/Tema 4/mur_map.png",
          height = 11, width=7)

# Otra forma de hacer el LISA con rgeoda
# https://geodacenter.github.io/rgeoda/
#knn_w <- rgeoda::knn_weights(us_merge, k=6) # nearest neighborhs weights
w <- rgeoda::queen_weights(us_merge, order = 1)
lisa <- local_moran(w, us_merge["lmur"], # select only one column with data
                    permutations = 999,
                    permutation_method = "complete",
                    significance_cutoff = 0.05,
                    cpu_threads = 2,
                    seed = 123456789)
us_merge$cluster = as.factor(lisa$GetClusterIndicators())
levels(us_merge$cluster) = lisa$GetLabels()
us_merge %>% freq(cluster)
qtm(us_merge, fill = "cluster")

us_merge$cluster = factor(us_merge$cluster,
                           levels = c("High-High", 
                                      "High-Low",
                                      "Low-High",
                                      "Low-Low",
                                      "Not significant")) # convert to factor

ggplot() + geom_sf(data=us_merge, aes(fill = cluster), color=NA) +
  scale_fill_manual(values = c("red", "pink", "light blue", "dark blue", "grey95"), drop = FALSE) + 
  labs(fill = "LISA") +
  guides(fill=guide_legend(title.position = "top")) +
  theme(panel.background = element_rect(fill = "white"), #fondo del gr�fico
        legend.position = c(0.22, 0.2), #ubicacion de leyenda, dentro del gr�fico
        legend.key.size = unit(0.2, "cm"), #alto de rectangulo de referencia
        legend.key.width = unit(0.2,"cm"), #ancho de rectangulo de referencia
        legend.text=element_text(size=4), #tama�o de texto de leyenda
        legend.background = element_rect(fill=NA), #background de la leyenda
        legend.title=element_text(size=5), #tama�o t�tulo leyenda
        axis.text = element_blank(), #texto eje X e Y
        axis.ticks = element_blank()) #eje X e Y
ggsave("./Econometria II Maestr�a Eco/R/2021-II/Tema 4/Ii_sig_rap.png", 
       width = 6, height = 8, units = "in", dpi = 300)

# Modelos de regresi�n
# Ya que se va a trabajar con estructura panel, es m�s conveniente utilizar la funci�n pdata.frame
datapanel <- pdata.frame(data, c("fipsstat","year"))
summary(datapanel)
stargazer(datapanel, type = "text")
stargazer(datapanel[, c("mur","rap","rob")], type = "text", 
          covariate.labels = c("Murder rate", "RAP", "Robbery rate"))
View(datapanel)

# Estimaci�n panel sin efectos espaciales
# Pool
pooling <- plm(log(mur) ~ v_shall + densitym + rpcpi,
              data = datapanel, model= "pooling")
summary(pooling)

# Efectos fijos
fe <- plm(log(mur) ~ v_shall + densitym + rpcpi, effect = "individual",
          data = datapanel, model = "within")
summary(fe)
summary(fixef(fe))

# Efectos aleatorios
re <- plm(log(mur) ~ v_shall + densitym + rpcpi, effect = "individual",
          data = datapanel, model = "random")
summary(re)

stargazer(pooling, fe, re, title="Results", type = "text", 
          column.labels = c("Pool", "FE", "RE"), align=TRUE)

# Estimaci�n panel con efectos espaciales
# Efectos fijos
# Modelo SAR
sarfe <- spml(log(mur) ~ v_shall + densitym + rpcpi,
                 data = datapanel, listw = We, spatial.error="none", lag=TRUE, 
                 model = "within", effect = "individual", method = "eigen")
summary(sarfe)
print(effects(sarfe))

# Modelo SEM
semfe <- spml(log(mur) ~ v_shall + densitym + rpcpi,
                   data = datapanel, listw = We, lag = FALSE, 
                   spatial.error = "b", model = "within",
                   effect = "individual", method = "eigen")
summary(semfe)
print(effects(semfe))

# Modelo SAC-SARAR-SARMA
sararfe <- spml(log(mur) ~ v_shall + densitym + rpcpi,
                   data = datapanel, listw = We, lag = TRUE, 
                   spatial.error = "b", model = "within",
                   effect = "individual", method = "eigen")
summary(sararfe)
print(effects(sararfe))

# Modelo Spatial Durbin model
datapanel$wv_shall<-slag(datapanel$v_shall, We, 1)
datapanel$wdensitym<-slag(datapanel$densitym, We, 1)
datapanel$wrpcpi<-slag(datapanel$rpcpi, We, 1)
sdmfe <- spml(log(mur) ~ v_shall + densitym + rpcpi + 
                   wv_shall + wdensitym + wrpcpi,
                   data = datapanel, listw = We, lag = TRUE, 
                   spatial.error = "none", model = "within",
                   effect = "individual", method = "eigen")
summary(sdmfe)
print(effects(sdmfe))

# Modelo Spatial Durbin error model
sdemfe <- spml(log(mur) ~ v_shall + densitym + rpcpi + 
                wv_shall + wdensitym + wrpcpi,
              data = datapanel, listw = We, lag = FALSE, 
              spatial.error = "b", model = "within",
              effect = "individual", method = "eigen")
summary(sdemfe)
print(effects(sdemfe))

# Modelo SLX
slxfe <- plm(log(mur) ~ v_shall + densitym + rpcpi + 
                   wv_shall + wdensitym + wrpcpi,
                   data = datapanel, model = "within",
                   effect = "individual")
summary(slxfe)
summary(fixef(slxfe))

# Efectos aleatorios
# Modelo SAR
sarre <- spml(log(mur) ~ v_shall + densitym + rpcpi,
              data = datapanel, listw = We, spatial.error="none", lag=TRUE, 
              model = "random")
summary(sarre)

# Modelo SEM
semre <- spml(log(mur) ~ v_shall + densitym + rpcpi,
              data = datapanel, listw = We, lag = FALSE, 
              spatial.error = "b", model = "random")
summary(semre)

# Modelo SAC-SARAR-SARMA
sararre <- spml(log(mur) ~ v_shall + densitym + rpcpi,
                data = datapanel, listw = We, lag = TRUE, 
                spatial.error = "b", model = "random")
summary(sararre)

# Modelo Spatial Durbin model
sdmre <- spml(log(mur) ~ v_shall + densitym + rpcpi + 
                wv_shall + wdensitym + wrpcpi,
              data = datapanel, listw = We, lag = TRUE, 
              spatial.error = "none", model = "random")
summary(sdmre)

# Modelo Spatial Durbin error model
sdemre <- spml(log(mur) ~ v_shall + densitym + rpcpi + 
                 wv_shall + wdensitym + wrpcpi,
               data = datapanel, listw = We, lag = FALSE, 
               spatial.error = "b", model = "random")
summary(sdemre)

# Modelo SLX
slxre <- plm(log(mur) ~ v_shall + densitym + rpcpi + 
                  wv_shall + wdensitym + wrpcpi,
                data = datapanel, model = "random")
summary(slxre)

# Selecci�n del modelo
# Para seleccionar la m�s apropiada especificaci�n, se empieza del modelo sin
# autocorrelaci�n espacial y se implementa el test de Hausman y tests LM
summary(pooling)
summary(fe)
summary(re)

# Hausman test (plm)
phtest(fe, re)

# Hausman test robust to spatial autocorrelation (splm)
# SAR
sphtest(x = sarre, x2 = sarfe)

# SEM
sphtest(x = semre, x2 = semfe)

# Los resultados del test de Hausman est�ndar y el test de Hausman robusto a la
# autocorrelaci�n de los errores y lag lleva a rechazar la hip�tesis nula de
# ausencia de correlaci�n entre los efectos individuales y las variables explicatorias
# Para el resto del an�lisis emp�rico, el modelo de efectos fijos es escogido

# Tests LM
slmtest(log(mur) ~ v_shall + densitym + rpcpi, data=datapanel, listw = We, test="lml",
        model="within")

slmtest(log(mur) ~ v_shall + densitym + rpcpi, data=datapanel, listw = We, test="lme",
        model="within")

slmtest(log(mur) ~ v_shall + densitym + rpcpi, data=datapanel, listw = We, test="rlml",
        model="within")

slmtest(log(mur) ~ v_shall + densitym + rpcpi, data=datapanel, listw = We, test="rlme",
        model="within")

# Los test LM en un modelo de efectos fijos favorecen una espeficaci�n SAR
# Los test1 (SAR) y test2 (SEM) confirman el rechazo de la hip�tesis que
# estos dos t�rminos (tomados independientemente) son nulos. Sin embargo,
# se puede notar que el estad�stico para el SAR es mayor que para el SEM.
# Para poder concluir de una forma m�s cre�ble, los test robustos son usados
# en la presencia de la especificaci�n de la autocorrelaci�n espacial.
# Se observa que RLMlag y RLMerr son altamente significantes por lo que no es
# posible discriminar la estructura de la autocorrelaci�n espacial. Qu� hacer?
# - Estimar el SARAR
# - Elegir aquel con es estad�stico robusto m�s alto
# - Compara criterios de informaci�n
# - Seguir la propuesta de Elhorst (2010): Si el modelo MCO es rechazado en favor 
# del spatial lag model, spatial error model o en favor de ambos modelos, entonces
# el modelo Durbin espacial deber� ser estimado

# Si H0: theta = 0 y H0: theta + rho*beta = 0 son rechazadas =) modelo Durbin espacial

# Calculo de los efectos directos e indirectos
set.seed(123456789)
impacts <- impacts(sdmfe, listw = We) time=length(unique(datapanel$year))
summary(impacts, zstats=TRUE, short=TRUE)

# Otros test - Sin efectos espaciales
# Tests de poolability
# Ho: todos los interceptos son iguales
pool <- plm(log(mur) ~ v_shall + densitym + rpcpi, data = datapanel, model = "pooling")
summary(pool)
pooltest(pool, fe)

# Tests para efectos individuales y tiempo
plmtest(pool, effect = "individual", type = "bp")

# Comparando el pooling y el Within
pFtest(fe, pool)

# Test de efectos inobservables
# Ho: Var_effijos=0 -> Pooling
# Ha: Var_effijos<>0 -> efectos aleatorios
pwtest(log(mur) ~ v_shall + densitym + rpcpi, data = datapanel)

# Tests de Baltagi BH, Song SH, Koh W (2003). Testing Panel Data Regression Models with Spatial
# Error Correlation. Journal of Econometrics, 117, 123-150:
# LM1: Ho: Var_effijos=0: no efectos aleatorios asumiendo no correlaci�n espacial
# LM2: Ho: rho=0: no correlaci�n espacial asumiendo no efectos aleatorios
# SLM1: versi�n estandarizada de LM1
# SLM2: versi�n estandarizada de LM2
# LMH: Ho: rho=Var_effijos=0: no existen efectos espaciales ni efectos aleatorios
# CLMlambda: Ho: rho=0: no correlaci�n espacial asumiendo la posible existencia
# de efectos aleatorios (Var_effijos puede o no puede ser cero)
# CLMmu: Ho: Var_effijos=0: no efectos aleatorios asumiendo la posibilidad de correlaci�n espacial
# (rho puede o no puede ser cero)

LM1 <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
               data = datapanel, listw = We, test = "LM1")
LM1

SLM1 <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
                data = datapanel, listw = We, test = "LM1",
                standardize=TRUE)
SLM1


LM2 <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
               data = datapanel, listw = We, test = "LM2")
LM2

SLM2 <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
                data = datapanel, listw = We, test = "LM2",
                standardize=TRUE)
SLM2

LMH <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
               data = datapanel, listw = We, test = "LMH")
LMH

CLMlambda <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
                     data = datapanel, listw = We, test = "CLMlambda")
CLMlambda

CLMmu <- bsktest(x = log(mur) ~ v_shall + densitym + rpcpi, 
                 data = datapanel, listw = We, test = "CLMmu")
CLMmu
