#------------------------------------------------------------------------------------
# Name:         lidar_preprocessing.R
# Description:  This script is intended to preprocess LiDAR point clouds
#               from the Solling overflight campaign in September 2023.
#               The function preprocess_lidar_files.R is used.
#               What the function is doing:
#               - renaming input files
#               - point cloud normalization
#               - filter values below -1m and above 55m.
#               - noise points are classified using IVF with resolution 5 and
#                 examining 3 x 3 x 3 = 27 neighboring voxels with max. 6 other points
#               - drop these classified noise points
#               - the normalized and filtered point clouds are written to disk
#               - calculation of a canopy height model (CHM) in 0.5 m resolution
#               - pits and spikes are filled in the CHM
#               - CHM is written to disk as individual files (tiles)
#               - renaming output files
#               25 cores were used to process the files.
# Contact:      florian.franz@nw-fva.de
#------------------------------------------------------------------------------------

# source setup script
source('src/setup.R', local = T)

# source function for lidar preprocessing
source('src/preprocess_lidar_files.R', local = T)

# apply the function
preprocess_lidar_files(
  input_dir = file.path(raw_data_dir, 'laz_ALS'),
  example_pattern = '2023_06_solling_32_XXX_YYYY.laz',
  output_dir_laz = file.path(processed_data_dir, 'laz_ALS'),
  output_dir_tif = file.path(processed_data_dir, 'nDSMs_ALS'),
  state = 'ni',
  rs_system = 'flugzeug',
  year = '2023',
  client = 'nlf',
  drop_z_below = -1,
  drop_z_above = 55,
  res_voxels = 5,
  n_points = 6L,
  res_chm = 0.5,
  n_cores = 25
)