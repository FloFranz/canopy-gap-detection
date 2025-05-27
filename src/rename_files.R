#' Rename point cloud and DTM files
#' 
#' Rename point clouds processed in Match-T and DTM files to the form dsm/dtm_32(x)(y).laz/las
#' depending on the input coordinate system.
#' 
#'
#' @param dir_path character string; path to the folder containing the point cloud/DTM files
#' @param epsg integer; EPSG code of the coordinate system
#' @param region character string; region name
#' 
#' @example 
#' dir_path <- path/to/input_data
#' epsg <- 25832
#' region <- 'solling'
#' 
#' @references 
#' Kirchhöfer, M., Beckschäfer, P., Adler, P., Ackermann, J. (2020). Walddaten für eine moderne, nachhaltige Forstwirtschaft. www.waldwissen.net

rename_files <- function(dir_path, epsg, region) {
  
  if (epsg == 25832) {
    
    index <- '32'
    posdiff <- 0

  } else if (epsg == 25833) {
    
    index <- '33'
    posdiff <- 0
    
  }
  
  dtm_pattern <- '[dD][gG][mM]1_[0-9]{6}_[0-9]{7}_dgm1\\.[laszLASZ]{3}'
  
  matcht_pattern <- paste0("grid_aoi_", "[0-9]{1}_[0-9]{7}_[0-9]{6}\\.[laszLASZ]{3}")
  
  for (file in list.files(dir_path)) {
    
    if (grepl(matcht_pattern, file)) {
      
      file_new <- paste0("DSM_", index, substr(file, 20, 22), substr(file, 12, 15), substr(file, nchar(file)-3, nchar(file)))
      
    } else if (grepl(dtm_pattern, file)) {
      
      file_new <- paste0("DTM_", index, substr(file, 6, 8), substr(file, 13, 16), substr(file, nchar(file)-3, nchar(file)))
      
    } else {
      
      print(paste("No match in", file, "found, no rename"))
      
      next
      
    }
    
    file.rename(file.path(dir_path, file), file.path(dir_path, file_new))
    print(paste("file", file, "renamed to", file_new))
    
  }
}
