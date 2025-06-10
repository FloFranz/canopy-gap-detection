#-------------------------------------------------------------------------------
# Name:         dap_cloud_2_ndsm.R
# Description:  Script calculates normalized digital surface models (nDSM) 
#               from image-based point clouds previously generated 
#               via image-matching methods.
#               The processing is tile-based, where every tile is 1000 x 1000 m.
# Author:       Florian Franz
# Contact:      florian.franz@nw-fva.de
#-------------------------------------------------------------------------------

start.time <- Sys.time()



# source setup script
source('src/setup.R', local = T)



# 01 - set paths and parameters
#-------------------------------

# input path to point cloud tiles
point_clouds <- file.path(raw_data_dir, 'laz_DAP')

# input path to DTM tiles
dtm <- file.path(raw_data_dir, 'dtm_tiles')

# output path for nDSM .tif files
out_path_ndsm_tif <- file.path(processed_data_dir, 'nDSMs_DAP')

# output path for nDSM .laz files
out_path_ndsm_laz <- file.path(processed_data_dir, 'laz_DAP')

# EPSG code for input data coordinate system
# ERTS89/UTM Zone 32 N = 25832, ERTS89/UTM Zone 33 N = 25833
epsg <- 25832

# define region name
region <- 'solling'

# set minimum area (in %) required for a tile to be processed
min_area = 10



# 02 - preparations for calculations
#-----------------------------------

# remove empty files (< 1500 bytes)
files <- list.files(point_clouds)

for (f in files) {
  
  if (file.size(file.path(point_clouds, f)) < 1500) {
    
    file.remove(file.path(point_clouds, f))
    print('Empty point cloud files removed')
    
  }
}

# rename point clouds and DTM files
source('src/rename_files.R', local = T)

rename_files(dir_path = point_clouds,
             epsg = epsg,
             region = region)

rename_files(dir_path = dtm,
             epsg = epsg,
             region = region)

# *** list common tiles between DTM and point cloud
# create list of point clouds/DTM without filename extension and without DSM_/DTM_ ***

# create a list of point cloud files
point_list <- list.files(point_clouds, pattern = '\\.laz$|\\.las$', full.names = F)
point_list <- substr(point_list, 5, nchar(point_list) - 4)

# create a list of DTM files
dtm_list <- list.files(dtm, pattern = '\\.laz$|\\.las$', full.names = F)
dtm_list <- substr(dtm_list, 5, nchar(dtm_list) - 4)

# remove all .lax files in DTM directory
filelist <- list.files(dtm, pattern = '\\.lax$', full.names = T)
file.remove(filelist)

# identify file format of point cloud files
pc_format <- substr(list.files(point_clouds)[1],
                    nchar(list.files(point_clouds)[1]) - 3,
                    nchar(list.files(point_clouds)[1]))

# identify file format of DTM files
dtm_format <- substr(list.files(dtm)[1],
                     nchar(list.files(dtm)[1]) - 3,
                     nchar(list.files(dtm)[1]))

# find tiles that occur in point cloud and in DTM
common_list <- dplyr::intersect(point_list, dtm_list)

# list tiles in point cloud and DTM with DSM_/DTM_ and without filename extension
cloud_common <- paste0('DSM_', common_list)
dtm_common <- paste0('DTM_', common_list)

# create a list of file names in common_list
pc_common_tile_list <- file.path(point_clouds, paste0('DSM_', common_list, pc_format))

# print results
print(paste('point cloud format is', pc_format))
print(paste('point cloud list:', point_list))
print(paste('DTM format is', dtm_format))
print(paste('DTM list:', dtm_list))
print(paste('common list:', common_list))
print(paste('length common list:', length(common_list)))
print(paste('cloud common:', cloud_common))
print(paste('DTM common:', dtm_common))
print(paste("point cloud common tile list:", pc_common_tile_list))

# *** find files containing data for at least 10% of tile area ***

# reduce list of files to those that cover at least 100000 m2 (10 % of the tile area)
cat('finding files that are smaller than 10 % of the size of the biggest file',
    'to check if their data covers at least 10 % of tile area (100 000 sqm)')

file_sizes <- sapply(pc_common_tile_list, file.size)
threshold_size <- max(file_sizes) * 0.1

tiles_lasinfo <- character()

for (i in seq_along(pc_common_tile_list)) {
  
  if (file_sizes[i] < threshold_size) {
    
    tiles_lasinfo <- c(tiles_lasinfo, basename(pc_common_tile_list[i]))
    
  }
}

if (length(tiles_lasinfo) > 0) {
  
  cat("there are some small files:", paste(tiles_lasinfo, collapse = ", "))
  
  # check the area covered by each laz-file and include in list when area covered >= 100000 m2
  remove_list <- character()
  
  for (f in tiles_lasinfo) {
  
    filename <- file.path(point_clouds, f)
    las <- lidR::readLAS(filename)
    covered_area <- sum(terra::area(las))
    
    if (covered_area < 100000 * min_area / 100) {
      
      remove_list <- c(remove_list, substr(f, 5, nchar(f) - 4))
      
    }
  }
  
  # check if there were any "small files" that went through the 10 % area filter
  if (length(remove_list) == 0) {
    
    print('all small tiles cover enough area')
    
  } else {
    
    cat("some small tiles don't cover enough area and will be ignored:", paste(remove_list, collapse = ", "))
    
    # update common list removing tiles that do not cover enough area
    common_list <- setdiff(common_list, remove_list)
    cat("updated common list after removing files with not enough area cover:", paste(common_list, collapse = ", "))
  
    # from the new common list, update cloud, DTM, and point cloud tile list
    cloud_common <- paste0('DSM_', common_list)
    dtm_common <- paste0('DTM_', common_list)
    pc_common_tile_list <- file.path(point_clouds, paste0('DSM_', common_list, pc_format))
    
  }
  
} else {
  
  print('no small files')
  
}

# *** ensure equal point spacing for input ***

# read las files
print('calculating point spacing')

las_files <- list.files(
  point_clouds, 
  pattern = paste0(cloud_common, pc_format, collapse = '|'), full.names = T
  )

las_files_list <- c()

for (i in seq_along(las_files)) {
  
  las_file <- las_files[i]
  las <- lidR::readLAS(las_file)
  las_files_list[[i]] <- las
  
}

# check point spacing
point_space_list <- c()

for (las_file in las_files_list) {
  
  point_space_list <- append(
    point_space_list,
    lidR::cloud_metrics(las_file, func = ~sqrt(1/lidR::density(las_file)))
    )
  
}

thinned_pc_list <- c()

for (i in seq_along(point_space_list)) {

  if (point_space_list[i] < 0.5) {

    print('thinning point clouds')

    thinned_pc <- lidR::decimate_points(las_files_list[[i]], lidR::highest(res = 0.5))
    thinned_pc_list <- append(thinned_pc_list, thinned_pc)

  } else {

    thinned_pc_list <- append(thinned_pc_list, las_files_list[[i]])

  }
}

print('thinning done')

rm(las_files_list)
gc()



# 03 - calculate nDSM
#---------------------------

# list common DTM files
dtm_files <- list.files(
  dtm,
  pattern = paste0(dtm_common, pc_format, collapse = '|'), full.names = T
  )

dtm_common_list <- c()

for (i in seq_along(dtm_files)) {
  
  dtm_file <- dtm_files[i]
  dtms <- lidR::readLAS(dtm_file)
  dtm_common_list[[i]] <- dtms
  
}

# rasterize the DTM files using invert distance weighting
dtm_raster_list <- lapply(dtm_common_list,
                          FUN = function(x)
                            lidR::rasterize_terrain(x,
                                                    res = 1,
                                                    algorithm = lidR::knnidw(),
                                                    use_class = 0))

# calculate nDSMs by normalizing the thinned point clouds with the DTM files
print('calculate nDSMs')

nlas_list <- mapply(FUN = function(x, y) lidR::normalize_height(x, y),
                    thinned_pc_list, dtm_raster_list)

# filter the normalized point clouds 
for (nlas in seq_along(nlas_list)) {
  
  print(paste("Processing nlas:", nlas))
  
  # remove points less than -1 and greater than 55
  nlas_list[[nlas]] <- lidR::filter_poi(nlas_list[[nlas]], Z > -1, Z < 55)
  
  # classify and remove isolated points (max. 40 points in a 10 x 10 x 10 voxcel)
  nlas_list[[nlas]] <- lidR::classify_noise(nlas_list[[nlas]],
                                            algorithm = lidR::ivf(res = 10,
                                                                  n = 40))
  
  nlas_list[[nlas]] <- lidR::filter_poi(nlas_list[[nlas]], Classification != 18)
  
  # classify and remove isolated points (max. 8 points in a 3 x 3 x 3 voxcel)
  nlas_list[[nlas]] <- lidR::classify_noise(nlas_list[[nlas]],
                                            algorithm = lidR::ivf(res = 3,
                                                                  n = 8))
  
  nlas_list[[nlas]] <- lidR::filter_poi(nlas_list[[nlas]], Classification != 18)
  
  # write the filtered normalized point clouds to disk
  tryCatch({
    
    lidR::writeLAS(
      nlas_list[[nlas]],
      file.path(out_path_ndsm_laz, paste0('n', cloud_common[nlas], pc_format))
      )
    
  }, error = function(e) {
    
    print(paste("Error occurred while writing the file:", e$message))
    
  })
}

# rasterization with point-to-raster algorithm
ndsm_list <- lapply(nlas_list, FUN = function(x) {
  
  tryCatch({
    
    lidR::rasterize_canopy(x, res = 0.5, algorithm = lidR::p2r(subcircle = 0.2, na.fill = lidR::tin()))
    
  }, error = function(e) {
    
    warning("Skipping file due to an error:", e$message)
    return()
    
  })
})

ndsm_list <- ndsm_list[!sapply(ndsm_list, is.null)]


# remove points less than 0.1 m (set to 0)
for (ndsm in seq_along(ndsm_list)) {
  
  ndsm_list[[ndsm]][ndsm_list[[ndsm]] < 0.1] <- 0
  
}

for (ndsm in seq_along(ndsm_list)) {
  
  terra::writeRaster(
    ndsm_list[[ndsm]],
    file.path(out_path_ndsm_tif, paste0('n', cloud_common[ndsm], '.tif')),
    overwrite = T)
  
}



# ------------------------------------------
end.time <- Sys.time()
time.taken <- end.time - start.time
time.taken

sessionInfo()