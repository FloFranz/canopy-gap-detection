#---------------------------------------------------------------------------------------
# Name:         merge_CHM_tiles.R
# Description:  This script merges individual raster CHM tiles into one big raster file.
#               Pixels below 0.1 m are set to 0. NA values are filled.
#               The resulting CHM is written to disk.
# Contact:      florian.franz@nw-fva.de
#---------------------------------------------------------------------------------------

# source setup script
source('src/setup.R', local = T)



# file path and name definitions
#--------------------------------

# input directory to CHM raster files
input_dir <- file.path(processed_data_dir, 'nDSMs')

# output directory to final CHM raster file
output_dir <- file.path(processed_data_dir, 'nDSMs')

# define file name of output CHM
output_file_name <- 'chm_solling_2023_als.tif'

# define output layer name
output_lyr_name <- 'chm_solling_2023_als'

#--------------------------------

# read CHM input raster files into one list
chm_files <- list.files(input_dir, pattern = '\\.tif$')
chms <- lapply(file.path(input_dir, chm_files), terra::rast)

# merge to one big raster file
chms_sprc <- terra::sprc(chms)
chm_merged <- terra::merge(chms_sprc)
chm_merged

# remove pixels less than 0.1 m (set to 0)
chm_merged[chm_merged < 0.1] <- 0
chm_merged

# fill NA values
fill.na <- function(x, i=5) {
  if (is.na(x)[i]) {
    return(mean(x, na.rm = TRUE))
  } else {
    return(x[i]) 
  }
}
w <- matrix(1,3,3)
chm_merged_filled <- terra::focal(chm_merged, w, fun = fill.na)

# write merged and filled CHM to disk
terra::writeRaster(chm_merged_filled,
                   file.path(output_dir, output_file_name),
                   names = output_lyr_name)
