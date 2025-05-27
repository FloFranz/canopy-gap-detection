#-------------------------------------------------------------------------------
# Name:         dap_ndsm_mosaic_creation.R
# Description:  Script creates a mosaic of individual DAP-based nDSM raster files.
# Author:       Florian Franz
# Contact:      florian.franz@nw-fva.de
#-------------------------------------------------------------------------------

# source setup script
source('src/setup.R', local = T)

# source function for creating mosaics
source('src/create_mosaic.R', local = T)

create_mosaic(
  ndsm_files = file.path(processed_data_dir, 'nDSMs_DAP'),
  out_path = file.path(processed_data_dir, 'nDSMs_DAP'),
  epsg = 'EPSG:25832',
  region = 'solling_train_area_lev2'
)
