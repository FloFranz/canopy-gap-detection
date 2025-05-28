#----------------------------------------------------------------------------
# Name:         gap_generation.R
# Description:  Script automatically generates canopy gaps as reference
#               training and testing polygons for the deep learning model.
#               For this purpose, a multi-height-stage approach is applied 
#               to an airborne laserscanning (ALS)-based canopy 
#               height model (CHM) in 0.5 m resolution.
# Contact:      florian.franz@nw-fva.de
#----------------------------------------------------------------------------



# source setup script
source('src/setup.R', local = T)



# 01 - set file paths
#---------------------

chm_path <- file.path(processed_data_dir, 'nDSMs_ALS')
dop_path <- file.path(raw_data_dir, 'DOPs')
test_tiles_path <- file.path(raw_data_dir, 'test_tiles')



# 02 - data reading
#-------------------

# CHM
chm_solling <- terra::rast(file.path(chm_path, 'chm_solling_2023_als.tif'))
chm_solling

# DOPs
dop_train_files <- list.files(path = dop_path,
                              pattern = "dop_train_.*\\.tif$",
                              full.names = T)

dops_train <- list()

for (file in seq_along(dop_train_files)) {
  
  dops_train[[file]] <- terra::rast(dop_train_files[file])
  
}

dops_train



# 03 - data preparation
#-------------------------------------

# assign CRS to CHM (ETRS89 / UTM zone 32N) if it is different or not set
if (terra::crs(chm_solling) != 'EPSG:25832') {
  terra::crs(chm_solling) <- 'EPSG:25832'
}

# function to reduce resolution of DOPs
# to speed up further processing
resample_dops <- function(dops, factor) {
  
  resampled_dops <- lapply(dops, function(dop) {
    
    template <- terra::rast(dop)
    terra::res(template) <- terra::res(dop) * factor
    terra::resample(dop, template, method = 'bilinear')
    
  })
  
  return(resampled_dops)
  
}

# training area:
# 1. merge DOPs
# 2. crop CHM to the extent of the merged DOPs

# define output file paths
file_path_dops_train_merg <- file.path(processed_data_dir, 'DOPs', 'dops_train_merged.tif')
file_path_chm_train <- file.path(processed_data_dir, 'nDSMs_ALS', 'chm_train_als.tif')

if (!file.exists(file_path_dops_train_merg) || !file.exists(file_path_chm_train)) {
  
  cat('reduce resolution of DOPs...\n')
  resampled_dops_train <- resample_dops(dops_train, factor = 100)
  
  cat('merge DOPs...\n')
  dops_train_merged <- do.call(terra::merge, resampled_dops_train)
  terra::writeRaster(dops_train_merged, file_path_dops_train_merg, overwrite = T)
  
  cat('crop CHM to merged DOP extent...\n')
  chm_train <- terra::crop(chm_solling, dops_train_merged)
  terra::writeRaster(chm_train, file_path_chm_train, overwrite = T)
  
  cat('process completed\n')
  
} else {
  
  cat('load existing merged DOP and cropped CHM...\n')
  dops_train_merged <- terra::rast(file.path(file_path_dops_train_merg))
  chm_train <- terra::rast(file.path(file_path_chm_train))
  cat('files loaded successfully\n')
  
}

# testing area:
# just crop CHM to the extent of the test tiles (1x1 km)

# read test tile
test_tile <- terra::vect(file.path(test_tiles_path, 'tile_2.shp'))

# define output file path
file_path_chm_test <- file.path(processed_data_dir, 'nDSMs_ALS', 'chm_test_tile2_als.tif')

if (!file.exists(file_path_chm_test)) {
  
  cat('crop CHM to test tile extent...\n')
  chm_test <- terra::crop(chm_solling, test_tile)
  terra::writeRaster(chm_test, file_path_chm_test, overwrite = T)
  
  cat('process completed\n')
  
} else {
  
  cat('load existing cropped CHM...\n')
  chm_test <- terra::rast(file.path(file_path_chm_test))
  cat('file loaded successfully\n')
  
}

# quick overview
par_org <- par()
par(mfrow = c(1,2))
terra::plot(chm_train, col = viridis::viridis(50),
            main = 'CHM train area')
terra::plotRGB(dops_train_merged, r = 1, g = 2, b = 3,
               stretch = 'lin', axes = T, mar = 3,
               main = 'DOP train area')
par(par_org)

par_org <- par()
par(mfrow = c(1,2))
terra::plot(chm_test, col = viridis::viridis(50),
            main = 'CHM test area')
terra::plotRGB(dop_test, r = 1, g = 2, b = 3,
               stretch = 'lin', axes = T, mar = 3,
               main = 'DOP test area')
par(par_org)



# 04 - automatic canopy gap detection
#-------------------------------------

# source function for gap detection
source('src/detect_gaps_multi_stage.R', local = T)

# define height stages for multi-stage gap detection
stages <- list(
  list(gap_height_threshold = 5, size = c(10, 5000), buffer_width = 20, percentile_threshold = 10),
  list(gap_height_threshold = 10, size = c(10, 5000), buffer_width = 20, percentile_threshold = 20),
  list(gap_height_threshold = 15, size = c(10, 5000), buffer_width = 20, percentile_threshold = 30)
)

# apply function to chm_train and chm_test
canopy_gaps_train <- detect_gaps_multi_stage(
  chm = chm_train,
  stages = stages,
  output_dir = file.path(processed_data_dir, 'gap_polygons_ALS'),
  area_name = 'train'
)

canopy_gaps_test <- detect_gaps_multi_stage(
  chm = chm_test,
  stages = stages,
  output_dir = file.path(processed_data_dir, 'gap_polygons_ALS'),
  area_name = 'test_tile2'
)

# quick overview
par_org <- par()
par(mfrow = c(1,2))
terra::plot(chm_train, col = viridis::viridis(50))
terra::plot(canopy_gaps_train$geometry,
            border = 'red',
            lwd = 0.5,
            add = T)
terra::plot(chm_test, col = viridis::viridis(50))
terra::plot(canopy_gaps_test$geometry,
            border = 'red',
            lwd = 0.5,
            add = T)
par(par_org)