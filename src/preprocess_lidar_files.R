#' Preprocess LiDAR files
#'
#' This function preprocesses LiDAR point cloud files. It first renames the input files according to a specified pattern,
#' then performs normalization, filtering, and rasterization. Finally, it renames parts of the output files.
#' Detailed information regarding the preprocessing steps (excluding renaming):
#' - Point clouds are normalized by triangulating the ground points and linearly interpolating the elevation of each point within each triangle.
#' - A first filter drop points below and above desired height values.
#' - Noise points are classified using Isolated Voxel Filter (IVF). Identifies points that have only a few other points in their surrounding.
#' - A second filter drop the points classified as noise.
#' - A canopy height model (CHM) is calculated from the normalized and filtered point clouds using point-to-raster method.
#' - Pits and spikes are filled in the CHM.
#' The lasR package is used for all this preprocessing steps. See https://github.com/r-lidar/lasR for further information.
#'
#' @param input_dir character. Path to the directory containing the input LAZ files.
#' @param example_pattern character.  User-defined pattern of the input LAZ file names with placeholders. The file names must include three digits for the x-coordinate and four digits for the y-coordinate.
#' @param output_dir_laz character. Path to the directory where the processed LAZ files should be saved.
#' @param output_dir_tif character. Path to the directory where the rasterized LAZ files (then TIF files) should be saved.
#' @param state character. Code representing the federal state (e.g., 'ni' for Lower Saxony).
#' @param rs_system character. The remote sensing system or platform used (e.g., 'flugzeug' for aircraft).
#' @param year character. The year of data acquisition.
#' @param client character. The client or organization for whom we have the LiDAR data (e.g., 'nlf' for Niedersaechsiche Landesforsten).
#' @param drop_z_below numeric. The lower threshold for dropping points in the normalized point cloud.
#' @param drop_z_above numeric. The upper threshold for dropping points in the normalized point cloud.
#' @param res_voxels numeric. Resolution of the voxels for classifying noise points using IVF.
#' @param n_points integer. The maximal number of 'other points' in the voxels for IVF.
#' @param res_chm numeric. The target resolution of the CHM raster.
#' @param n_cores integer. The number of cores to use for parallel processing (not use all!!!). Default uses half of the available cores.
#'
#' @examples
#' # Preprocess LiDAR files with specific parameters
#' preprocess_lidar_files(
#'   input_dir = 'K:/lidar/ni/flugzeug/2024/solling_nlf/punktwolke_roh/daten',
#'   example_pattern = '3dm_32_XXX_YYYY_1_ni_20240327.laz',
#'   output_dir_laz = 'K:/lidar/ni/flugzeug/2024/solling_nlf/punktwolke_normalisiert_klassifiziert_gefiltert/daten',
#'   output_dir_tif = 'K:/lidar/ni/flugzeug/2024/solling_nlf/raster_ndom/daten/kacheln',
#'   state = 'ni',
#'   rs_system = 'flugzeug',
#'   year = '2024',
#'   client = 'nlf',
#'   drop_z_below = -1,
#'   drop_z_above = 55,
#'   res_voxels = 5,
#'   n_points = 6L,
#'   res_chm = 0.5,
#'   n_cores = 25
#' )

# ensure required packages are installed and loaded
required_packages <- c('stringr', 'lasR')

for (pkg in required_packages) {
  if (!require(pkg, character.only = T)) {
    if (pkg == 'lasR') {
      install.packages('lasR', repos = 'https://r-lidar.r-universe.dev')
    } else {
      install.packages(pkg)
    }
    library(pkg, character.only = T)
  }
}

preprocess_lidar_files <- function(
    input_dir,
    example_pattern,
    output_dir_laz,
    output_dir_tif,
    state,
    rs_system,
    year,
    client,
    drop_z_below,
    drop_z_above,
    res_voxels,
    n_points,
    res_chm,
    n_cores = lasR::half_cores()) 
{
  
  start.time <- Sys.time()
  
  #----------------------------
  # step 1: rename input files
  #----------------------------
  
  # get all LAZ files in the input directory
  laz_files <- list.files(path = input_dir, pattern = '*.laz$', full.names = TRUE)
  
  # check if the files are already in the desired name format
  desired_pattern <- paste0(state, '_', rs_system, '_', year, '_laz_', client, '_\\d{6}_\\d{7}\\.laz')
  files_already_renamed <- all(grepl(desired_pattern, basename(laz_files)))
  
  if (!files_already_renamed) {
    
    # function to rename files according to the desired format
    rename_files <- function(old_file_name, pattern) {
      
      # extract file name
      old_name <- basename(old_file_name)
      
      # convert user pattern into a regex pattern by replacing XXX and YYYY
      regex_pattern <- gsub('XXX', '(\\\\d{3})', gsub('YYYY', '(\\\\d{4})', pattern))
      
      # match the pattern and extract the match
      match <- regexec(regex_pattern, old_name)
      match_result <- regmatches(old_name, match)
      
      # if no match is found, exit without printing
      if (length(match_result[[1]]) == 0) {
        return(NULL)
      }
      
      # extract the coordinates from the match result
      x_coord <- match_result[[1]][2]  # the second element is the matched XXX
      y_coord <- match_result[[1]][3]  # the third element is the matched YYYY
      
      # format coordinates
      x_coord_formatted <- sprintf('%06d', as.numeric(x_coord) * 1000)
      y_coord_formatted <- sprintf('%07d', as.numeric(y_coord) * 1000)
      
      # construct new file name using predefined components (state, rs_system, etc.)
      new_name <- paste0(state, '_', rs_system, '_', year, '_', 'laz', '_', client, '_', x_coord_formatted, '_', y_coord_formatted, '.laz')
      new_file_name <- file.path(input_dir, new_name)
      
      # rename the file and print successful renaming
      if (file.rename(file.path(input_dir, old_name), new_file_name)) {
        cat("file '", old_name, "' renamed to '", new_name, "'\n", sep = "")
      }
    }
    
    # apply the renaming function to all files
    invisible(lapply(laz_files, function(file) rename_files(file, example_pattern)))
    
  } else {
    
    cat("Files are already in the desired format. Skipping renaming step.\n")
    
  }
  
  #-------------------------------------------------
  # step 2: normalization, filtering, rasterization
  #-------------------------------------------------
  
  # normalization
  normalization <- lasR::normalize()
  
  # first filter: drop points below and above a specified threshold
  first_filter <- lasR::delete_points(
    filter = lasR::drop_z_below(drop_z_below) + lasR::drop_z_above(drop_z_above)
    )
  
  # classify noise
  noise_classification <- lasR::classify_with_ivf(
    res = res_voxels, n = n_points, class = 18L
    )
  
  # second filter: drop points classified as noise
  second_filter <- lasR::delete_points(
    filter = lasR::drop_noise()
    )
  
  # write normalized and filtered point clouds to disk
  write_laz <- lasR::write_las(
    ofile = file.path(output_dir_laz, '/*.laz')
    )
  
  # calculate CHM
  chm_generation <- lasR::chm(res = res_chm)
  
  # fill pits and spikes
  pitfill <- lasR::pit_fill(
    raster = chm_generation, ofile = file.path(output_dir_tif, '/*.tif')
    )
  
  # initialize and execute pipeline
  pipeline <- 
    normalization +
    first_filter +
    noise_classification +
    second_filter +
    write_laz +
    chm_generation +
    pitfill
  
  lasR::set_parallel_strategy(lasR::concurrent_files(ncores = n_cores))
  lasR::exec(pipeline, on = input_dir, progress = T)
  
  #-----------------------------
  # step 3: rename output files
  #-----------------------------
  
  # list all laz and tif files
  output_laz_files <- list.files(path = output_dir_laz, pattern = '*.laz$', full.names = T)
  output_tif_files <- list.files(path = output_dir_tif, pattern = '*.tif$', full.names = T)
  
  # function to rename laz files
  rename_laz_files <- function(file) {
    old_name <- basename(file)
    new_name <- stringr::str_replace(old_name, 'laz', 'laznorm')
    new_file <- file.path(output_dir_laz, new_name)
    file.rename(file, new_file)
    cat("output file '", old_name, "' renamed to '", new_name, "'\n", sep = "")
  }
  
  # function to rename tif files
  rename_tif_files <- function(file) {
    old_name <- basename(file)
    new_name <- stringr::str_replace(old_name, 'laz', 'lndom')
    new_file <- file.path(output_dir_tif, new_name)
    file.rename(file, new_file)
    cat("output file '", old_name, "' renamed to '", new_name, "'\n", sep = "")
  }
  
  # apply renaming functions to all laz and tif files
  lapply(output_laz_files, rename_laz_files)
  lapply(output_tif_files, rename_tif_files)
  
  end.time <- Sys.time()
  time.taken <- end.time - start.time
  time.taken
  
  return(time.taken)

}
