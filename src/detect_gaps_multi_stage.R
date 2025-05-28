# detect_gaps_multi_stage.R

#' Detect and filter canopy gaps using a multi-height-stage approach
#'
#' This function detects and filters canopy gaps in a canopy height model (CHM)
#' through multiple height stages, then merges the filtered gaps from each stage into 
#' a single spatial object. It makes use of the ForestGapR package to detect the gaps.
#' The subsequent filtering considers the surrounding tree heights in a buffer around
#' each detected gap to ensure that 75% of the heights in the buffer are above a 
#' specified height percentile threshold. 
#' For the ForestGapR package see publication Silva et al. 2019, https://doi.org/10.1111/2041-210X.13211
#'
#' @param chm SpatRaster representing the canopy height model.
#' @param stages list of stages where each stage is a list containing:
#'        - gap_height_threshold: numeric value indicating the height threshold for gap detection.
#'        - size: numeric vector of length 2 indicating the minimum and maximum gap size.
#'        - buffer_width: numeric value indicating the width of the buffer around gaps.
#'        - percentile_threshold: numeric value indicating the height percentile threshold for filtering.
#' @param output_dir string representing the directory where the output files will be saved.
#' @param area_name string indicating the name of the area.
#' 
#' @return sf object containing the merged and filtered gaps.
#' @author Florian Franz

detect_gaps_multi_stage <- function(chm, stages, output_dir, area_name) {
  
  filter_gaps <- function(gap_raster, chm, buffer_width, percentile_threshold) {
    
    # convert gap raster to individual gap polygons
    cat('converting gap raster to individual gap polygons...\n')
    gap_polygons <- terra::as.polygons(gap_raster)
    
    # create buffer around each gap polygon
    cat('creating buffer around each gap polygon...\n')
    gaps_buffer <- terra::buffer(gap_polygons, width = buffer_width)
    
    # mask CHM with buffer
    cat('masking CHM with buffer...\n')
    buffer_area <- terra::mask(chm, gaps_buffer)
    
    # exclude gap area from buffer area
    cat('excluding gap area from buffer area...\n')
    buffer_area <- terra::mask(buffer_area, gap_polygons, inverse = T)
    
    # extract CHM values in buffer
    cat('extracting CHM values in buffer...\n')
    chm_buffer <- exactextractr::exact_extract(buffer_area, sf::st_as_sf(gaps_buffer))
    chm_buffer <- dplyr::bind_rows(
      lapply(seq_along(chm_buffer), function(i) {
        df <- chm_buffer[[i]]
        df <- df %>%
          dplyr::select(value)
        df$ID <- i
        return(df)
      }))
    names(chm_buffer)[1] <- 'chm_height'
    
    # calculate 25th percentile of CHM height in buffer area
    cat('calculating 25th percentile of CHM height in buffer area...\n')
    chm_buffer <- chm_buffer %>%
      dplyr::group_by(ID) %>%
      dplyr::summarize(quant25 = quantile(chm_height, probs = 0.25, na.rm = T))
    
    # filter gaps based on 25th percentile height
    cat('filtering gaps...\n')
    canopy_filter <- chm_buffer[(chm_buffer$quant25 <= percentile_threshold),]
    if (nrow(canopy_filter) == 0) {
      gaps_filtered <- gap_raster
    } else {
      canopy_filter$replace <- NA
      gaps_filtered <- terra::subst(gap_raster, from = canopy_filter$ID, to = canopy_filter$replace)
    }
    
    return(gaps_filtered)
  }
  
  # create empty list to store filtered gaps from each stage
  filtered_gaps <- list()
  
  # apply filtering for each stage
  for (i in seq_along(stages)) {
    stage <- stages[[i]]
    cat(sprintf('Processing stage %d: gap height threshold = %dm, percentile threshold = %dm\n', i, stage$gap_height_threshold, stage$percentile_threshold))
    gap_raster <- ForestGapR::getForestGaps(
      chm_layer = chm,
      threshold = stage$gap_height_threshold,
      size = stage$size
    )
    filtered_gaps[[i]] <- filter_gaps(gap_raster, chm, stage$buffer_width, stage$percentile_threshold)
    
    # convert filtered gaps from each stage to individual sf objects and write to disk
    cat(sprintf('converting and saving filtered gaps for stage %d...\n', i))
    gap_polygons <- terra::as.polygons(filtered_gaps[[i]], dissolve = T, na.rm = T, values = T)
    names(gap_polygons) <- 'gap_id'
    gaps_sf <- sf::st_as_sf(gap_polygons)
    gaps_sf_filename <- file.path(output_dir, paste0('gap_polys_', area_name, '_', stage$gap_height_threshold, '_', stage$percentile_threshold, '.gpkg'))
    sf::st_write(gaps_sf, gaps_sf_filename, delete_layer = T)
  }
  
  # merge filtered gaps from all stages
  cat('merging filtered gaps from all stages...\n')
  merged_gaps <- do.call(terra::merge, filtered_gaps)
  
  # convert merged raster to polygons
  cat('converting merged raster to polygons...\n')
  gaps_poly <- terra::as.polygons(merged_gaps, dissolve = T, na.rm = T, values = T)
  names(gaps_poly) <- 'gap_id'
  gaps_sf <- sf::st_as_sf(gaps_poly)
  
  # dissolve boundaries of overlapping polygons
  cat('dissolving boundaries of overlapping polygons...\n')
  dissolved_gaps <- sf::st_union(gaps_sf)
  dissolved_gaps <- sf::st_sf(geometry = dissolved_gaps)
  
  # ensure individual gap polygons
  cat('ensuring individual gap polygons...\n')
  dissolved_gaps_individual <- sf::st_cast(dissolved_gaps, "POLYGON") %>%
    dplyr::mutate(gap_id = row_number())
  
  # write final merged gap polygons as one file to disk
  cat('saving final layer to disk\n')
  final_output_filename <- file.path(output_dir, paste0('gap_polys_', area_name, '.gpkg'))
  sf::st_write(dissolved_gaps_individual, final_output_filename, delete_layer = T)
  
  cat('Processing done\n')
  
  return(dissolved_gaps_individual)
}
