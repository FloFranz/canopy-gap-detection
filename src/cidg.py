# import necessary libraries
import tensorflow as tf
import numpy as np
from sklearn.model_selection import train_test_split

# data generator for the model
# tiles a xr.Dataset into multiple tiles and returns them in batches (row-wise)
# splits the data into training/validation/test
# performs data augmentation by rotating the tiles (90, 180, and 270 degrees)
class CustomImageDataGenerator(tf.keras.utils.Sequence):
    
    def __init__(self, ds, tilesize, sampletype):
        
        self.ds         = ds
        self.tilesize   = tilesize
        self.ylen       = self.ds.y.size // tilesize
        self.xlen       = self.ds.x.size // tilesize
        self.sampletype = sampletype
        
    def __len__(self):
        
        return self.ylen

    def __getitem__(self, index):
        
        red   = self.ds.red[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        green = self.ds.green[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        blue  = self.ds.blue[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        nir   = self.ds.nir[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        ndsm  = self.ds.ndsm[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        gaps  = self.ds.gap_mask[index*self.tilesize:(index+1)*self.tilesize,:-(self.ds.x.size%self.tilesize)]
        
        rgbi_ndsm = np.array([red,green,blue,nir,ndsm]).transpose(1,2,0)
        gaps      = np.array(gaps)
        
        # split into tiles
        rgbi_ndsm_tiles  = np.array(np.split(rgbi_ndsm, self.xlen,axis=1))
        target_tiles     = np.array(np.split(gaps, self.xlen,axis=1))
        
        # depending on sampletype, return training, validation or test set (complete set)
        if self.sampletype == 'training' or self.sampletype == 'validation':
            
            rgbi_ndsm_tiles_tr, rgbi_ndsm_tiles_val, target_tiles_tr, target_tiles_val = train_test_split(rgbi_ndsm_tiles, target_tiles, shuffle=True, test_size=0.2, random_state=11)
            
            if self.sampletype == 'training':
                
                # data augmentation
                rgbi_ndsm_tiles_tr = np.concatenate((rgbi_ndsm_tiles_tr,
                                                     tf.image.rot90(image=rgbi_ndsm_tiles_tr),
                                                     tf.image.rot90(image=rgbi_ndsm_tiles_tr,k=2),
                                                     tf.image.rot90(image=rgbi_ndsm_tiles_tr,k=3)),
                                                    axis=0)

                target_tiles_tr    = np.concatenate((target_tiles_tr,
                                                     tf.image.rot90(np.expand_dims(target_tiles_tr,axis=-1))[:,:,:,0],
                                                     tf.image.rot90(np.expand_dims(target_tiles_tr,axis=-1),k=2)[:,:,:,0],
                                                     tf.image.rot90(np.expand_dims(target_tiles_tr,axis=-1),k=3)[:,:,:,0]),
                                                    axis=0)
                
                ng                 = np.random.RandomState(7)
                indexes            = ng.permutation(rgbi_ndsm_tiles_tr.shape[0])
                rgbi_ndsm_tiles_tr = rgbi_ndsm_tiles_tr[indexes]
                target_tiles_tr    = target_tiles_tr[indexes]
                
                return rgbi_ndsm_tiles_tr, target_tiles_tr
            
            else:
                
                return rgbi_ndsm_tiles_val, target_tiles_val
        
        if self.sampletype == 'test': 
            
            return rgbi_ndsm_tiles, target_tiles
        
        return None
