#-------------------------------------------------------------
# Name:         setup.py
# Description:  Script sets up a working environment,
#               defines file paths for data import and output.
# Author:       Florian Franz
# Contact:      florian.franz@nw-fva.de
#-------------------------------------------------------------

from pathlib import Path

def make_folders():
    
    # 01 - setup working environment
    # --------------------------------

    # create directory called 'data' with subdirectories
    # 'raw_data', 'processed_data', and 'metadata'
    base_dir = Path.cwd().parent

    data_directories = [
        base_dir / 'data' / 'raw_data' / 'DOPs',
        base_dir / 'data' / 'raw_data' / 'laz_ALS',
        base_dir / 'data' / 'raw_data' / 'laz_DAP',
        base_dir / 'data' / 'raw_data' / 'dtm_tiles',
        base_dir / 'data' / 'raw_data' / 'test_tiles',
        base_dir / 'data' / 'processed_data' / 'DOPs',
        base_dir / 'data' / 'processed_data' / 'nDSMs_ALS',
        base_dir / 'data' / 'processed_data' / 'nDSMs_DAP',
        base_dir / 'data' / 'processed_data' / 'laz_ALS',
        base_dir / 'data' / 'processed_data' / 'laz_DAP',
        base_dir / 'data' / 'processed_data' / 'datasets',
        base_dir / 'data' / 'processed_data' / 'models',
        base_dir / 'data' / 'processed_data' / 'gap_polygons_ALS',
        base_dir / 'data' / 'processed_data' / 'gap_polygons_DAP',
        base_dir / 'data' / 'metadata'
    ]

    for directory in data_directories:
        directory.mkdir(parents=True, exist_ok=True)
        print(f'created directory {directory.relative_to(base_dir)}')

    # create other necessary directories
    other_directories = [
        base_dir / 'src',
        base_dir / 'scripts',
        base_dir / 'output'
    ]

    for directory in other_directories:
        directory.mkdir(parents=True, exist_ok=True)
        print(f'created directory {directory.relative_to(base_dir)}')

    # 02 - file path definitions
    # ---------------------------

    # define raw data directory
    raw_data_dir = base_dir / 'data' / 'raw_data'

    # define processed data directory
    processed_data_dir = base_dir / 'data' / 'processed_data'

    # define output directory
    output_dir = base_dir / 'output'

    return raw_data_dir, processed_data_dir, output_dir
