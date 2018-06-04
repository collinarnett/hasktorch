{-# LANGUAGE ScopedTypeVariables #-}
module Torch.Indef.Static.Tensor.Math.Reduce
  ( minall
  , maxall
  , medianall
  , sumall
  , prodall

  , Torch.Indef.Static.Tensor.Math.Reduce.min
  , Torch.Indef.Static.Tensor.Math.Reduce.max
  , median

  , min1d, minIndex1d
  , max1d, maxIndex1d
  , median1d, medianIndex1d

  , Torch.Indef.Static.Tensor.Math.Reduce.sum, rowsum, colsum
  , _prod

  ) where

import Data.Coerce
import System.IO.Unsafe

import Data.Maybe (fromJust)
import Torch.Indef.Index
import Torch.Indef.Static.Tensor
import Torch.Indef.Types
import qualified Torch.Indef.Dynamic.Tensor.Math.Reduce as Dynamic


minall :: Tensor d -> HsReal
minall t = Dynamic.minall (asDynamic t)

maxall :: Tensor d -> HsReal
maxall t = Dynamic.maxall (asDynamic t)

medianall :: Tensor d -> HsReal
medianall t = Dynamic.medianall (asDynamic t)

sumall :: Tensor d -> HsAccReal
sumall t = Dynamic.sumall (asDynamic t)

prodall :: Tensor d -> HsAccReal
prodall t = Dynamic.prodall (asDynamic t)

max, min, median
  :: (Dimensions d, KnownDim n) => Tensor d -> Idx dimval -> KeepDim -> (Tensor d, Maybe (IndexTensor '[n]))
max    = withKeepDim Dynamic._max
min    = withKeepDim Dynamic._min
median = withKeepDim Dynamic._median

max1d, min1d, median1d
  :: (KnownDim n) => Tensor '[n] -> KeepDim -> (Tensor '[n], Maybe (IndexTensor '[1]))
max1d    t = Torch.Indef.Static.Tensor.Math.Reduce.max t (Idx 0)
min1d    t = Torch.Indef.Static.Tensor.Math.Reduce.min t (Idx 0)
median1d t = median t (Idx 0)

maxIndex1d t    = fromJust . snd $ max1d t keep
minIndex1d t    = fromJust . snd $ min1d t keep
medianIndex1d t = fromJust . snd $ median1d t keep

_prod :: Tensor d -> Tensor d -> DimVal -> Maybe KeepDim -> IO ()
_prod r t = Dynamic._prod (asDynamic r) (asDynamic t)

-------------------------------------------------------------------------------

withKeepDim
  :: forall d n dimval . (Dimensions d, KnownDim n)
  => ((Dynamic, IndexDynamic) -> Dynamic -> DimVal -> Maybe KeepDim -> IO ())
  -> Tensor d -> Idx dimval -> KeepDim -> (Tensor d, Maybe (IndexTensor '[n]))
withKeepDim _fn t d k = unsafePerformIO $ do
  ret :: Tensor d <- new
  let ix :: IndexTensor '[n] = newIx
  _fn (asDynamic ret, longAsDynamic ix) (asDynamic t) (fromIntegral $ idxToWord d) (Just k)
  pure (ret, if coerce k then Just ix else Nothing)
{-# NOINLINE withKeepDim #-}


sum :: Dimensions d' => Tensor d -> DimVal -> KeepDim -> Tensor d'
sum t d k = unsafePerformIO $ do
  r <- new
  Dynamic._sum (asDynamic r) (asDynamic t) d (Just k)
  pure r
{-# NOINLINE sum #-}

rowsum :: (KnownDim2 r c) => Tensor '[r, c] -> (Tensor '[1, c])
rowsum t = Torch.Indef.Static.Tensor.Math.Reduce.sum t 0 keep

colsum :: (KnownDim2 r c) => Tensor '[r, c] -> (Tensor '[r, 1])
colsum t = Torch.Indef.Static.Tensor.Math.Reduce.sum t 0 keep


