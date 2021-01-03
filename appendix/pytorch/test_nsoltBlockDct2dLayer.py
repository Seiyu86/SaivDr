import itertools
import unittest
from parameterized import parameterized
import torch
import torch.nn as nn
import torch_dct as dct
import numpy as np
from nsoltBlockDct2dLayer import NsoltBlockDct2dLayer
from nsoltUtility import Direction

stride = [ [1, 1], [2, 2], [2, 4], [4, 1], [4, 4] ]
datatype = [ torch.float, torch.double ]
height = [ 8, 16, 32 ]
width = [ 8, 16, 32 ]
    
class NsoltBlockDct2dLayerTestCase(unittest.TestCase):
    """
    NSOLTBLOCKDCT2DLAYERTESTCASE
    
       ベクトル配列をブロック配列を入力:
          nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols) 
    
       コンポーネント別に出力:
          nSamples x nRows x nCols x nDecs
    
    Requirements: Python 3.7.x, PyTorch 1.7.x
    
    Copyright (c) 2020-2021, Shogo MURAMATSU
    
    All rights reserved.
    
    Contact address: Shogo MURAMATSU,
        Faculty of Engineering, Niigata University,
        8050 2-no-cho Ikarashi, Nishi-ku,
        Niigata, 950-2181, JAPAN
    
        http://msiplab.eng.niigata-u.ac.jp/
    """
    @parameterized.expand(
        list(itertools.product(stride))
    )
    def testConstructor(self,stride):
        # Expected values
        expctdName = 'E0'
        expctdDescription = "Block DCT of size " \
            + str(stride[Direction.VERTICAL]) + "x" \
            + str(stride[Direction.HORIZONTAL])

        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                name=expctdName
            )

        # Actual values
        actualName = layer.name
        actualDescription = layer.description

        # Evaluation
        self.assertTrue(isinstance(layer, nn.Module))        
        self.assertEqual(actualName,expctdName)
        self.assertEqual(actualDescription,expctdDescription)

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testPredictGrayScale(self,
            stride, height, width, datatype):
        atol = 1e-6

        # Parameters
        nSamples = 8
        nComponents = 1
        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)

        # Expected values
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        ndecs = np.prod(stride)
        # Block DCT (nSamples x nComponents x nrows x ncols) x decV x decH
        arrayshape = stride.copy()
        arrayshape.insert(0,-1)
        Y = dct.dct_2d(X.view(arrayshape),norm='ortho')
        # Rearrange the DCT Coefs. (nSamples x nComponents x nrows x ncols) x (decV x decH)
        A = permuteDctCoefs_(Y)
        expctdZ = A.view(nSamples,nrows,ncols,ndecs)

        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                name='E0'
            )
            
        # Actual values
        with torch.no_grad():
            actualZ = layer.forward(X)

        # Evaluation
        self.assertEqual(actualZ.dtype,datatype)         
        self.assertTrue(torch.isclose(actualZ,expctdZ,rtol=0.,atol=atol).all())
        self.assertFalse(actualZ.requires_grad)

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testForwardGrayScale(self,
        stride, height, width, datatype):
        atol=1e-6
            
        # Parameters
        nSamples = 8
        nComponents = 1
        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)

        # Expected values
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        ndecs = np.prod(stride)
        # Block DCT (nSamples x nComponents x nrows x ncols) x decV x decH
        arrayshape = stride.copy()
        arrayshape.insert(0,-1)
        Y = dct.dct_2d(X.view(arrayshape),norm='ortho')
        # Rearrange the DCT Coefs. (nSamples x nComponents x nrows x ncols) x (decV x decH)
        A = permuteDctCoefs_(Y)
        expctdZ = A.view(nSamples,nrows,ncols,ndecs)

        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                name='E0'
            )
            
        # Actual values
        actualZ = layer.forward(X)

        # Evaluation
        self.assertEqual(actualZ.dtype,datatype)         
        self.assertTrue(torch.isclose(actualZ,expctdZ,rtol=0.,atol=atol).all())
        self.assertTrue(actualZ.requires_grad)

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testPredictRgbColor(self,
        stride, height, width, datatype):
        atol=1e-6

        # Parameters
        nSamples = 8
        nComponents = 3 # RGB
        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)

        # Expected values
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        ndecs = np.prod(stride)

        # Block DCT (nSamples x nComponents x nrows x ncols) x decV x decH
        arrayshape = stride.copy()
        arrayshape.insert(0,-1)
        Y = dct.dct_2d(X.view(arrayshape),norm='ortho')
        # Rearrange the DCT Coefs. (nSamples x nComponents x nrows x ncols) x (decV x decH)
        A = permuteDctCoefs_(Y)
        Z = A.view(nSamples,nComponents,nrows,ncols,ndecs)
        expctdZr = Z[:,0,:,:,:]
        expctdZg = Z[:,1,:,:,:]
        expctdZb = Z[:,2,:,:,:]

        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                number_of_components=nComponents,
                name='E0'
            )
            
        # Actual values
        with torch.no_grad():        
            actualZr,actualZg,actualZb = layer.forward(X)

        # Evaluation
        self.assertEqual(actualZr.dtype,datatype)         
        self.assertEqual(actualZg.dtype,datatype)         
        self.assertEqual(actualZb.dtype,datatype)                 
        self.assertTrue(torch.isclose(actualZr,expctdZr,rtol=0.,atol=atol).all())
        self.assertTrue(torch.isclose(actualZg,expctdZg,rtol=0.,atol=atol).all())
        self.assertTrue(torch.isclose(actualZb,expctdZb,rtol=0.,atol=atol).all())                
        self.assertFalse(actualZr.requires_grad)
        self.assertFalse(actualZg.requires_grad)
        self.assertFalse(actualZb.requires_grad)

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testForwardRgbColor(self,
        stride, height, width, datatype):
        atol=1e-6

        # Parameters
        nSamples = 8
        nComponents = 3 # RGB
        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)

        # Expected values
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        ndecs = np.prod(stride)

        # Block DCT (nSamples x nComponents x nrows x ncols) x decV x decH
        arrayshape = stride.copy()
        arrayshape.insert(0,-1)
        Y = dct.dct_2d(X.view(arrayshape),norm='ortho')
        # Rearrange the DCT Coefs. (nSamples x nComponents x nrows x ncols) x (decV x decH)
        A = permuteDctCoefs_(Y)
        Z = A.view(nSamples,nComponents,nrows,ncols,ndecs)
        expctdZr = Z[:,0,:,:,:]
        expctdZg = Z[:,1,:,:,:]
        expctdZb = Z[:,2,:,:,:]

        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                number_of_components=nComponents,
                name='E0'
            )
            
        # Actual values
        actualZr,actualZg,actualZb = layer.forward(X)

        # Evaluation
        self.assertEqual(actualZr.dtype,datatype)         
        self.assertEqual(actualZg.dtype,datatype)         
        self.assertEqual(actualZb.dtype,datatype)                 
        self.assertTrue(torch.isclose(actualZr,expctdZr,rtol=0.,atol=atol).all())
        self.assertTrue(torch.isclose(actualZg,expctdZg,rtol=0.,atol=atol).all())
        self.assertTrue(torch.isclose(actualZb,expctdZb,rtol=0.,atol=atol).all())                
        self.assertTrue(actualZr.requires_grad)
        self.assertTrue(actualZg.requires_grad)
        self.assertTrue(actualZb.requires_grad)    

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testBackwardGrayScale(self,
        stride, height, width, datatype):
        atol = 1e-6

        # Parameters
        nSamples = 8
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        nDecs = np.prod(stride)
        nComponents = 1

        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)        
        # nSamples x nRows x nCols x nDecs
        dLdZ = torch.rand(nSamples,nrows,ncols,nDecs,dtype=datatype)

        # Expected values
        A = permuteIdctCoefs_(dLdZ,stride)
        Y = dct.idct_2d(A,norm='ortho')
        expctddLdX = Y.reshape(nSamples,nComponents,height,width)
        
        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                name='E0'
            )
            
        # Actual values
        Z = layer.forward(X)
        Z.backward(dLdZ)
        actualdLdX = X.grad

        # Evaluation
        self.assertEqual(actualdLdX.dtype,datatype)
        self.assertTrue(torch.isclose(actualdLdX,expctddLdX,rtol=0.,atol=atol).all())
        self.assertTrue(Z.requires_grad)

    @parameterized.expand(
        list(itertools.product(stride,height,width,datatype))
    )
    def testBackwardRgbColor(self,
        stride, height, width, datatype):
        atol = 1e-6

        # Parameters
        nSamples = 8
        nrows = np.ceil(height/stride[Direction.VERTICAL]).astype(int)
        ncols = np.ceil(width/stride[Direction.HORIZONTAL]).astype(int)
        nDecs = np.prod(stride)
        nComponents = 3 # RGB

        # Source (nSamples x nComponents x (Stride[0]xnRows) x (Stride[1]xnCols))
        X = torch.rand(nSamples,nComponents,height,width,dtype=datatype,requires_grad=True)        
        # nSamples x nRows x nCols x nDecs
        dLdZr = torch.rand(nSamples,nrows,ncols,nDecs,dtype=datatype)
        dLdZg = torch.rand(nSamples,nrows,ncols,nDecs,dtype=datatype)
        dLdZb = torch.rand(nSamples,nrows,ncols,nDecs,dtype=datatype) 
    
        # Expected values
        Ar = permuteIdctCoefs_(dLdZr,stride)
        Ag = permuteIdctCoefs_(dLdZg,stride)        
        Ab = permuteIdctCoefs_(dLdZb,stride)                
        Yr = dct.idct_2d(Ar,norm='ortho')
        Yg = dct.idct_2d(Ag,norm='ortho')
        Yb = dct.idct_2d(Ab,norm='ortho')
        expctddLdX = torch.cat((
            Yr.reshape(nSamples,1,height,width),
            Yg.reshape(nSamples,1,height,width),
            Yb.reshape(nSamples,1,height,width)),dim=1)
        
        # Instantiation of target class
        layer = NsoltBlockDct2dLayer(
                decimation_factor=stride,
                number_of_components=nComponents,                
                name='E0'
            )
            
        # Actual values
        Zr,Zg,Zb = layer.forward(X)
        Zr.backward(dLdZr,retain_graph=True)
        Zg.backward(dLdZg,retain_graph=True)
        Zb.backward(dLdZb,retain_graph=False)
        actualdLdX = X.grad

        # Evaluation
        self.assertEqual(actualdLdX.dtype,datatype)
        self.assertTrue(torch.isclose(actualdLdX,expctddLdX,rtol=0.,atol=atol).all())
        self.assertTrue(Zr.requires_grad)
        self.assertTrue(Zg.requires_grad)
        self.assertTrue(Zb.requires_grad)

def permuteDctCoefs_(x):
    cee = x[:,0::2,0::2].reshape(x.size(0),-1)
    coo = x[:,1::2,1::2].reshape(x.size(0),-1)
    coe = x[:,1::2,0::2].reshape(x.size(0),-1)
    ceo = x[:,0::2,1::2].reshape(x.size(0),-1)
    return torch.cat((cee,coo,coe,ceo),dim=-1)

def permuteIdctCoefs_(x,block_size):
    coefs = x.view(-1,np.prod(block_size))
    decY_ = block_size[Direction.VERTICAL]
    decX_ = block_size[Direction.HORIZONTAL]
    chDecY = np.ceil(decY_/2.).astype(int)
    chDecX = np.ceil(decX_/2.).astype(int)
    fhDecY = np.floor(decY_/2.).astype(int)
    fhDecX = np.floor(decX_/2.).astype(int)
    nQDecsee = chDecY*chDecX
    nQDecsoo = fhDecY*fhDecX
    nQDecsoe = fhDecY*chDecX
    cee = coefs[:,:nQDecsee]
    coo = coefs[:,nQDecsee:nQDecsee+nQDecsoo]
    coe = coefs[:,nQDecsee+nQDecsoo:nQDecsee+nQDecsoo+nQDecsoe]
    ceo = coefs[:,nQDecsee+nQDecsoo+nQDecsoe:]
    nBlocks = coefs.size(0)
    value = torch.zeros(nBlocks,decY_,decX_,dtype=x.dtype)
    value[:,0::2,0::2] = cee.view(nBlocks,chDecY,chDecX)
    value[:,1::2,1::2] = coo.view(nBlocks,fhDecY,fhDecX)
    value[:,1::2,0::2] = coe.view(nBlocks,fhDecY,chDecX)
    value[:,0::2,1::2] = ceo.view(nBlocks,chDecY,fhDecX)
    return value

if __name__ == '__main__':
    unittest.main()