# Deep learning-based canopy gap detection using a cross-technological approach with airborne laser scanning and aerial imagery data

![](subareas_test_tile1.png)
*Canopy gap detection in three enlarged subareas (white rectangles).*

This repository contains code for forest canopy gap detection using a deep learning model trained on gaps automatically generated from Airborne Laser Scanning (ALS)-derived Canopy Height Models (CHMs), combined with spectral (True Digital Orthophotos) and height information from Digital Aerial Photogrammetry (DAP)-based CHMs. For further details, see the following paper:

Franz, F., Seidel, D., Beckschäfer, P., 2026. Deep learning-based canopy gap detection using a cross-technological approach with airborne laser scanning and aerial imagery data. *Ecol. Informatics.* 93, 103558. https://doi.org/10.1016/j.ecoinf.2025.103558.

The datasets to reproduce the analysis as well as the trained model are available on [Zenodo](https://zenodo.org/records/17829462).

## Folder structure

The project follows a structured organization for data, scripts, and outputs. Execute `src/setup.R` or `src/setup.py` to automatically create the required folder structure.

```
canopy-gap-detection/
├── data/
│   ├── raw_data/
│   │   ├── DOPs/                    # DOPs (aerial imagery)
│   │   ├── laz_ALS/                 # ALS point clouds (already ground classified)
│   │   ├── laz_DAP/                 # DAP based point clouds
│   │   ├── dtm_tiles/               # Digital terrain model point cloud tiles
│   │   └── test_tiles/              # Test data tiles extent
│   ├── processed_data/
│   │   ├── DOPs/                    # Processed DOPs
│   │   ├── nDSMs_ALS/               # Normalized digital surface models from ALS (raster files)
│   │   ├── nDSMs_DAP/               # Normalized digital surface models from DAP (raster files)
│   │   ├── laz_ALS/                 # Processed ALS point clouds
│   │   ├── laz_DAP/                 # Processed DAP point clouds
│   │   ├── datasets/                # Training and testing datasets
│   │   ├── models/                  # Trained deep learning model
│   │   ├── gap_polygons_ALS/        # Gap polygons derived from ALS data
│   │   └── gap_polygons_DAP/        # Gap polygons derived from DAP data
│   └── metadata/                    # Metadata and documentation files
├── src/                             # Functions and setup scripts
│   ├── setup.R                      # R setup script for folder creation
│   ├── setup.py                     # Python setup script for folder creation
│   ├── detect_gaps_multi_stage.R    # Multi-stage gap detection algorithm
│   ├── create_mosaic.R              # Function for mosaic creation from multiple tiles
│   ├── rename_files.R               # Utility script for file renaming
│   ├── preprocess_lidar_files.R     # Function for LiDAR data preprocessing
│   └── cidg.py                      # Image data generation for model training
├── scripts/                         # Analysis and processing scripts
│   ├── gap_generation.R             # Gap generation from ALS data
│   ├── gap_comp_dap_vs_pred.R       # Compare DAP vs prediction results
│   ├── model_train.ipynb            # Model training notebook
│   ├── prediction.ipynb             # Prediction and inference notebook
│   ├── test_data_preparation.ipynb  # Test dataset preparation
│   ├── train_data_preparation.ipynb # Training dataset preparation
│   ├── merge_CHM_tiles.R            # Merge ALS raster tiles
│   ├── dap_ndsm_mosaic_creation.R   # Create nDSM mosaics from DAP data
│   ├── dap_cloud_2_ndsm.R           # DAP point cloud processing
│   └── lidar_preprocessing.R        # ALS point cloud processing
└── output/                          # Results and output files
```

## Requirements

- R 4.4.0
- Python 3.10.12

## Citation

```
@article{FRANZ2026103558,
title = {Deep learning-based canopy gap detection using a cross-technological approach with airborne laser scanning and aerial imagery data},
journal = {Ecological Informatics},
volume = {93},
pages = {103558},
year = {2026},
issn = {1574-9541},
doi = {https://doi.org/10.1016/j.ecoinf.2025.103558},
url = {https://www.sciencedirect.com/science/article/pii/S1574954125005679},
author = {Florian Franz and Dominik Seidel and Philip Beckschäfer},
keywords = {Canopy gap detection, Deep learning, Airborne laser scanning, Digital aerial photogrammetry},
abstract = {Canopy gaps are crucial structural elements of forests, supporting biodiversity and influencing forest dynamics and ecosystem health. Airborne laser scanning (ALS) is commonly used for forest gap analysis and typically outperforms digital aerial photogrammetry (DAP), especially in detecting smaller gaps. However, ALS data availability remains limited compared to DAP. Given the broader availability and cost-effectiveness of DAP, this study aimed to overcome its technical drawbacks in canopy gap detection by applying a cross-technological approach with multiple data sources. This involves ALS-derived reference data fused with spectral and height information from DAP. We developed a deep learning-based method, employing a convolutional neural network (CNN), specifically the U-Net architecture, for detecting canopy gaps. The U-Net was trained using gap polygons automatically generated from ALS-derived canopy height models (CHMs), combined with true digital orthophotos (TDOPs) and DAP-based CHMs. Adding spectral information from TDOPs was intended to help detect shadows typically associated with smaller canopy gaps, which are often missed in DAP-based CHMs. The model was tested in the Solling, a forest area in a low mountain range in Central Germany. Performance was evaluated in independent test areas representing a gradient of structural heterogeneity. Overall, our model achieved moderate to high segmentation performance (IoU: 0.67–0.77; F1-score: 0.56–0.74). Once trained, it can be applied to image-derived inputs, improving canopy gap detection F1-score by on average 0.08 compared to using DAP-based CHMs alone. Our results demonstrate a novel approach for detecting canopy gaps without ALS data, suggesting applications across broader spatial and temporal scales.}
}
```