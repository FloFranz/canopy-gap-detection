#' Create Mosaic
#'
#' Build a virtual dataset (VRT) from several TIF files (DSM, nDSM, or DOP) and convert it to one TIF mosaic.
#'
#' @param dsm_files character. Path to the DSM files
#' @param ndsm_files charachter. Path to the nDSM files
#' @param dop_files character. Path to the DOP files
#' @param out_path character. Output path for DSM and nDSM mosaics
#' @param epsg character EPSG code for the output data coordinate system
#' @param region characrer. Name of the region for that mosaic is calculated
#'
#' @examples
#' # create DSM, nDSM, and DOP mosaics
#' dsm_files <- 'path/to/folder/with/DSMs'
#' ndsm_files <- 'path/to/folder/with/nDSMs'
#' dop_files <- 'path/to/folder/with/DOPs'
#' out_path <- 'path/to/output/mosaics'
#' epsg <- 'EPSG:25832'
#' region <- 'my_region'
#' 
#' create_mosaic(dsm_files, ndsm_files, dop_files, out_path, epsg, region)
#' 
#' # only create DOP mosaic
#' dop_files <- 'path/to/folder/with/DOPs'
#' out_path <- 'path/to/output/mosaic'
#' epsg <- 'EPSG:25832'
#' region <- 'my_region' 
#' 
#' create_mosaic(dop_files, out_path, epsg, region)

create_mosaic <- function(
    
    dsm_files = NULL, 
    ndsm_files = NULL,
    dop_files = NULL,
    out_path,
    epsg, 
    region
    
    ){
  
  # generate output names based on the region string
  output_names <- list(
    dsm_vrt = paste0("dsm_", region, ".vrt"),
    dsm_tif = paste0("dsm_", region, ".tif"),
    ndsm_vrt = paste0("ndsm_", region, ".vrt"),
    ndsm_tif = paste0("ndsm_", region, ".tif"),
    dop_vrt = paste0("dop_", region, ".vrt"),
    dop_tif = paste0("dop_", region, ".tif")
  )
  
  # process DSM files if provided
  if (!is.null(dsm_files)) {
    
    dsm_tiles <- list.files(dsm_files, pattern = '.tif$', full.names = T)
    gdalUtilities::gdalbuildvrt(dsm_tiles, file.path(out_path, output_names$dsm_vrt), a_srs = epsg)
    gdalUtilities::gdal_translate(file.path(out_path, output_names$dsm_vrt), file.path(out_path, output_names$dsm_tif),
                                  of = 'GTiff', a_srs = epsg,
                                  co = c(BIGTIFF = "YES", OVERVIEWS = "IGNORE_EXISTING"))
    
  }
  
  # process nDSM files if provided
  if (!is.null(ndsm_files)) {
    
    ndsm_tiles <- list.files(ndsm_files, pattern = '.tif$', full.names = T)
    gdalUtilities::gdalbuildvrt(ndsm_tiles, file.path(out_path, output_names$ndsm_vrt), a_srs = epsg)
    gdalUtilities::gdal_translate(file.path(out_path, output_names$ndsm_vrt), file.path(out_path, output_names$ndsm_tif),
                                  of = 'GTiff', a_srs = epsg,
                                  co = c(BIGTIFF = "YES", OVERVIEWS = "IGNORE_EXISTING"))
    
  }
  
  # process DOP files if provided
  if (!is.null(dop_files)) {
    
    dop_tiles <- list.files(dop_files, pattern = '.tif$', full.names = T)
    gdalUtilities::gdalbuildvrt(dop_tiles, file.path(out_path, output_names$dop_vrt), a_srs = epsg)
    gdalUtilities::gdal_translate(file.path(out_path, output_names$dop_vrt), file.path(out_path, output_names$dop_tif),
                                  of = 'GTiff', a_srs = epsg,
                                  co = c(BIGTIFF = "YES", OVERVIEWS = "IGNORE_EXISTING"))
    
  }
}