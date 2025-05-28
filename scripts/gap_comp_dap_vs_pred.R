#----------------------------------------------------------------------------
# Name:         gap_comp_dap_vs_pred.R
# Description:  Script compares DAP-based canopy gaps with those 
#               obtained by the model prediction and the 
#               reference ALS-based canopy gaps.
# Contact:      florian.franz@nw-fva.de
#----------------------------------------------------------------------------



# source setup script
source('src/setup.R', local = T)



# 01 - set file paths
#---------------------

# path to nDSMs
ndsm_path <- file.path(processed_data_dir, 'nDSMs_DAP')

# path to predicted gaps
pred_gaps_path <- output_dir

# path to DAP-based gaps
dap_gaps_path <- file.path(processed_data_dir, 'gap_polygons_DAP')

# path to test datasets
test_ds_path <- file.path(processed_data_dir, 'datasets')



# 02 - data reading
#-------------------

# predicted gap raster
pred_gap_raster <- terra::rast(file.path(pred_gaps_path, 'prediction_tile1_lev0.tif'))

# test datasets (with reference gap raster)
test_ds <- terra::rast(file.path(test_ds_path, 'test_ds_tile1_lev0.tif'))



# 03 - automatic canopy gap detection
#-------------------------------------

# define file names
dap_gap_raster_name <- file.path(dap_gaps_path, 'gap_raster_ndsm_test_tile1_lev0.tif')
ndsm_name <- file.path(ndsm_path, 'ndsm_test_tile1_lev0.tif')
canopy_gaps_ndsm_name <- 'ndsm_test_tile1_lev0'

if (!file.exists(dap_gap_raster_name)) {
  
  cat('detect gaps in DAP-CHM...\n')
  
  # read image_based nDSM
  ndsm <- terra::rast(ndsm_name)
  
  # source function for gap detection
  source('src/detect_gaps_multi_stage.R', local = T)
  
  # define height stages for multi-stage gap detection
  stages <- list(
    list(gap_height_threshold = 5, size = c(10, 5000), buffer_width = 20, percentile_threshold = 10),
    list(gap_height_threshold = 10, size = c(10, 5000), buffer_width = 20, percentile_threshold = 20),
    list(gap_height_threshold = 15, size = c(10, 5000), buffer_width = 20, percentile_threshold = 30)
  )
  
  # apply function to nDSM
  canopy_gaps_ndsm <- detect_gaps_multi_stage(
    chm = ndsm,
    stages = stages,
    output_dir = file.path(processed_data_dir, 'gap_polygons_DAP'),
    area_name = canopy_gaps_ndsm_name
  )
  
  # rasterize gap polygons
  canopy_gaps_ndsm$gap_value <- 1
  
  dap_gap_raster <- terra::rasterize(
    canopy_gaps_ndsm,
    test_ds,
    field = 'gap_value',
    background = 0
  )
  
  terra::writeRaster(dap_gap_raster, dap_gap_raster_name)
  
} else {
  
  cat('read existing DAP gap raster...\n')
  dap_gap_raster <- terra::rast(dap_gap_raster_name)
  
}

# 04 - gap validation
#---------------------------------------

dap_gap_raster
pred_gap_raster
test_ds

# select the reference gap raster
# from the test dataset
ref_gap_raster <- test_ds$gap_mask
ref_gap_raster

# crop reference gap raster (ALS) and DAP gap raster
# to predicted gap raster
ref_gap_raster <- terra::crop(ref_gap_raster, pred_gap_raster)
dap_gap_raster <- terra::crop(dap_gap_raster, pred_gap_raster)
ref_gap_raster
dap_gap_raster

# plot predicted, DAP-derived, and reference gap raster
par(mfrow = c(1,3))
terra::plot(ref_gap_raster, col = c('black', 'white'),
            main = 'reference (ALS-based)')
terra::plot(pred_gap_raster, col = c('black', 'white'),
            main = 'prediction')
terra::plot(dap_gap_raster, col = c('black', 'white'),
            main = 'DAP-based')



################################
### prediction vs. ALS-based ###
################################

# convert raster values to vectors
ref_gap_values <- as.vector(terra::values(ref_gap_raster))
pred_gap_values <- as.vector(terra::values(pred_gap_raster))

# generate confusion matrix
conf_matrix <- caret::confusionMatrix(as.factor(pred_gap_values), 
                                      as.factor(ref_gap_values),
                                      positive = '1')
print(conf_matrix)

# extract precision and recall
precision <- conf_matrix$byClass['Precision']
recall <- conf_matrix$byClass['Recall']

# F1-score
f1_score <- 2 * (precision * recall) / (precision + recall)

# IoU gaps
tp <- conf_matrix$table[2, 2]  # true positives
fp <- conf_matrix$table[2, 1]  # false positives
fn <- conf_matrix$table[1, 2]  # false negatives
iou <- tp / (tp + fp + fn)

# mean IoU
tn <- conf_matrix$table[1, 1]  # true negatives
mean_iou <- ((tp / (tp + fp + fn)) + (tn / (tn + fp + fn))) / 2

# print metrics
cat('Precision: ', precision, '\n')
cat('Recall: ', recall, '\n')
cat('F1-Score: ', f1_score, '\n')
cat('IoU for the canopy gap class: ', iou, '\n')
cat('Mean IoU: ', mean_iou, '\n')



###############################
### DAP-based vs. ALS-based ###
###############################

# convert raster values to vectors
ref_gap_values <- as.vector(terra::values(ref_gap_raster))
dap_gap_values <- as.vector(terra::values(dap_gap_raster))

# generate confusion matrix
conf_matrix <- caret::confusionMatrix(as.factor(dap_gap_values), 
                                      as.factor(ref_gap_values),
                                      positive = '1')
print(conf_matrix)

# extract precision and recall
precision <- conf_matrix$byClass['Precision']
recall <- conf_matrix$byClass['Recall']

# F1-score
f1_score <- 2 * (precision * recall) / (precision + recall)

# IoU gaps
tp <- conf_matrix$table[2, 2]  # true positives
fp <- conf_matrix$table[2, 1]  # false positives
fn <- conf_matrix$table[1, 2]  # false negatives
iou <- tp / (tp + fp + fn)

# mean IoU
tn <- conf_matrix$table[1, 1]  # true negatives
mean_iou <- ((tp / (tp + fp + fn)) + (tn / (tn + fp + fn))) / 2

# print metrics
cat('Precision: ', precision, '\n')
cat('Recall: ', recall, '\n')
cat('F1-Score: ', f1_score, '\n')
cat('IoU for the canopy gap class: ', iou, '\n')
cat('Mean IoU: ', mean_iou, '\n')



###################################
### histograms of the gap sizes ###
###################################

# identify patches in gap rasters
pred_patches <- terra::patches(pred_gap_raster, zeroAsNA = T)
dap_patches <- terra::patches(dap_gap_raster, zeroAsNA = T)
ref_patches <- terra::patches(ref_gap_raster, zeroAsNA = T)

# calculate gap sizes (area) for each patch
pred_gap_areas <- terra::freq(pred_patches)
dap_gap_areas <- terra::freq(dap_patches)
ref_gap_areas <- terra::freq(ref_patches)

# add area in m² (count * resolution)
pred_gap_areas$area <- pred_gap_areas$count * terra::res(pred_patches)[1] * terra::res(pred_patches)[2]
dap_gap_areas$area <- dap_gap_areas$count * terra::res(dap_patches)[1] * terra::res(dap_patches)[2]
ref_gap_areas$area <- ref_gap_areas$count * terra::res(ref_patches)[1] * terra::res(ref_patches)[2]

# combine gap sizes into a single data frame and filter out areas < 10 m² and >= 100 m²
ref_gap_df <- data.frame(GapSize = ref_gap_areas$area, Source = 'ALS-based') %>%
  filter(GapSize >= 10 & GapSize <= 100)

dap_gap_df <- data.frame(GapSize = dap_gap_areas$area, Source = 'DAP-based') %>%
  filter(GapSize >= 10 & GapSize <= 100)

pred_gap_df <- data.frame(GapSize = pred_gap_areas$area, Source = 'Prediction') %>%
  filter(GapSize >= 10 & GapSize <= 100)

combined_gap_df <- rbind(ref_gap_df, pred_gap_df, dap_gap_df)

# reorder 'Source' factor levels to make reference appear first
combined_gap_df$Source <- factor(combined_gap_df$Source, levels = c('ALS-based', 'DAP-based', 'Prediction'))

# plot histograms
ggplot(combined_gap_df, aes(x = GapSize, fill = Source)) +
  geom_histogram(color = NA, breaks = seq(10, 100, by = 5), position = 'identity') +
  scale_x_continuous(breaks = seq(10, 100, by = 10)) +
  scale_fill_manual(values = c(
    'ALS-based' = '#0072B2', 
    'DAP-based' = '#009E73', 
    'Prediction' = '#E69F00'
    )) + 
  labs(x = 'Gap size (m²)',
       y = 'Frequency',
       fill = '') +
  facet_wrap(~ Source, ncol = 1, scales = 'fixed', strip.position = 'bottom') +
  theme_minimal() +
  theme(
    text = element_text(size = 10, family = 'Times New Roman'),
    legend.position = 'bottom',
    strip.background = element_blank(),
    strip.text = element_blank(),
    panel.spacing = unit(1, 'lines'),
    plot.title = element_text(face = 'bold', hjust = 0.5),
  ) +
  coord_cartesian(ylim = c(0, 150))

# count number of total gaps
# and gaps less or equal 50 m²
gap_proportions <- combined_gap_df %>%
  dplyr::group_by(Source) %>%
  dplyr::summarise(
    total_gaps = n(),
    small_gaps = sum(GapSize <= 50),
    proportion = small_gaps / total_gaps
  )

print(gap_proportions)

# extract ALS-based values
als_gaps <- gap_proportions %>%
  dplyr::filter(Source == 'ALS-based') %>%
  dplyr::select(total_gaps, small_gaps)

# add relative proportions
gap_proportions <- gap_proportions %>%
  dplyr::mutate(
    total_gaps_relative = ifelse(Source == 'ALS-based', 1, total_gaps / als_gaps$total_gaps),
    small_gaps_relative = ifelse(Source == 'ALS-based', 1, small_gaps / als_gaps$small_gaps)
  )

print(gap_proportions)