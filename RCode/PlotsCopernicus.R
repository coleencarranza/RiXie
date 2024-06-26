library(ncdf4)
library(terra)
library(raster)
library(magrittr)
library(dplyr)
library(sf)

#---------------------------------------------
#Read climate data netcdf - water levels
#-----------------------------------------
#fucntion
ncdf2pts_watlev<-function(netcdf_file,crs){
  a<-nc_open(netcdf_file)
  # print(a) #to get info from netcdf file:
  lon <- ncvar_get(a,names(a$var)[grep("x_coord|longitude",names(a$var))])
  lat <- ncvar_get(a, names(a$var)[grep("y_coord|latitude",names(a$var))])
  var_nc <- ncvar_get(a,var)
  stations <- ncvar_get(a,"stations")
  
  
  #df to sf
  latlon = data.frame(lon=lon, lat=lat) %>%
    mutate(var_nc = var_nc) %>%
    rename_at(vars(var_nc), ~var) %>%
    st_as_sf(., coords = c("lon","lat"),crs=projcrs)
  
}


#--------------------------------------------------------------
#read EEZ shapefile for country coastal bounds
#from:https://www.marineregions.org/eez.php
#-------------------------------------------------------------
eez <-"/media/coleen/DDrive/A_UNDRR_GRAF/World_EEZ_v11_20191118/eez_v11.shp" %>%
  st_read()

#function #extract country bounds +  buffer:
country_eez<- function(iso, buffer){
eez %>% 
  filter(ISO_TER1 ==iso)%>%
  st_buffer(buffer)
  
}



#-------------------------------------------------------
#descriptive stats for water level
#-------------------------------------------------------
#water level stats:
#function
wat_lev_stats <- function(wat_level,projcrs,eez){
  wat_level %>%
    ncdf2pts_watlev(.,projcrs) %>%
    st_drop_geometry(st_filter(.,eez)) %>%
    summarise(across(
      .cols = is.numeric, 
      .fns = list(Mean = mean, SD = sd, Max = max, Min = min), na.rm = TRUE, 
      .names = "{col}_{fn}"
    ))
  
}

# #plot
# plot(st_geometry(land_buf5k))
# plot(st_geometry(pts),add=TRUE,col="red")


####################################################################################
#Read info on country shapefile
source("./AdminBoundaries.R")
#Country list
country<-adm_group$iso

#------------------------------------------------------
#Extract values for annual waterlevels:
#------------------------------------------------------
var<- "MSL"
local <-"/media/coleen/DDrive/A_UNDRR_GRAF/Results/CDS/CDS_water_level_change/"

climfil <- list.files(local, pattern = paste0("*",var), full.names = TRUE, recursive = TRUE)
yrs <-as.numeric(stringr::str_extract(climfil,"[[:digit:]]+"))  #gsub(".*?([0-9]+).*", "\\1", climfil))   

projcrs <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"
eez <-country_eez(country[[1]],5000)

#extract values:
wat_lev_years<-lapply(climfil, wat_lev_stats, projcrs, eez) %>%
  do.call("rbind",.) %>%
  mutate(Year = lubridate::ymd(yrs, truncated = 2L))


##----------------------------------------------------------------
# time series plots
#----------------------------------------------------------------
library(reshape2)
library(ggplot2)

df <- melt(wat_lev_years,  id.vars = 'Year', variable.name = 'Series')

# plot on same grid, each series colored differently -- 
# good if the series have same scale
ggplot(df, aes(Year,value)) + geom_line(aes(colour = Series))

