{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Gen where

import Bound (instantiate1)
import Control.Applicative (Alternative (empty), (<|>))
import Control.Monad.Fresh (FreshT, MonadFresh (fresh), runFreshT)
import Control.Monad.Reader (MonadReader (ask, local), MonadTrans (lift), ReaderT (runReaderT))
import Control.Monad.State (MonadState (get, put), StateT)
import qualified Data.List as List
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromMaybe)
import Hedgehog (Gen, GenT, MonadGen)
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Internal.Gen as Gen
import qualified Hedgehog.Internal.Seed as Seed
import qualified Hedgehog.Internal.Tree as Tree
import qualified Hedgehog.Range as Range
import qualified STLC

-- | Monad transformer stack for term and type generation.
-- Notably, contains the @FreshT@ transformer for generating fresh variable names
-- and a @ReaderT@ for the environment of scoped typed @Var@s.
type GTyM a = ReaderT (Map STLC.Ty [STLC.Exp a]) (FreshT a Gen)

-- | Generate a type.
-- We cannot generate an expression without generating a type for it first.
genTy :: forall m. MonadGen m => m STLC.Ty
genTy =
  Gen.recursive
    Gen.choice
    [ -- non-recursive generators
      pure STLC.TInt
    ]
    [ -- recursive generators
      STLC.TArr <$> genTy <*> genTy
    ]

-- | Finalize generation by running the monad transformers for the environment
-- and the fresh variable name computation.
genWellTypedExp :: forall a. (Eq a, Enum a) => STLC.Ty -> Gen (STLC.Exp a)
genWellTypedExp ty' = runFreshT $ runReaderT (genWellTypedExp' ty') mempty

-- | Main recursive mechanism for genersating expressions for a given type.
genWellTypedExp' :: forall a. Eq a => STLC.Ty -> GTyM a (STLC.Exp a)
genWellTypedExp' ty' =
  Gen.shrink shrinkExp $
    genWellTypedPath ty'
      <|> Gen.recursive
        Gen.choice
        [ -- non-recursive generators
          genWellTypedExp'' ty'
        ]
        [ -- recursive generators
          genWellTypedApp ty',
          genWellTypedExp''' ty'
        ]

shrinkExp :: forall a. STLC.Exp a -> [STLC.Exp a]
shrinkExp (f STLC.:@ a) = case STLC.whnf f of
  STLC.Lam _ b -> [STLC.whnf (instantiate1 a b)]
  _ -> []
shrinkExp _ = []

-- | Pattern match on a given type and produce a corresponding term.
-- @Lam@ is generated from @Arr@ by first obtaining a fresh variable name for @Var@ and
-- then calling the @lam@ smart constructor on an expression that
-- was produced for an environment to which @Var@ was added.
-- A term of type @Nat@ is generated by converting a random integer through induction.
genWellTypedExp'' :: forall a. Eq a => STLC.Ty -> GTyM a (STLC.Exp a)
genWellTypedExp'' (STLC.TArr ty' ty'') = do
  uname <- fresh
  STLC.lam ty' uname <$> local (insertVar uname ty') (genWellTypedExp' ty'')
genWellTypedExp'' STLC.TInt = STLC.int <$> Gen.int (Range.linear 0 100)

genWellTypedExp''' :: forall a. Eq a => STLC.Ty -> GTyM a (STLC.Exp a)
genWellTypedExp''' STLC.TInt =
  Gen.choice
    [ STLC.Add <$> genWellTypedExp' STLC.TInt <*> genWellTypedExp' STLC.TInt,
      STLC.Sub <$> genWellTypedExp' STLC.TInt <*> genWellTypedExp' STLC.TInt,
      STLC.Mul <$> genWellTypedExp' STLC.TInt <*> genWellTypedExp' STLC.TInt,
      STLC.Neg <$> genWellTypedExp' STLC.TInt,
      STLC.Abs <$> genWellTypedExp' STLC.TInt,
      STLC.Sign <$> genWellTypedExp' STLC.TInt
    ]
genWellTypedExp''' ty' = genWellTypedExp' ty'

-- | Add @Var@ of given type to the given env so that it can be used for sampling later.
insertVar :: forall a. Eq a => a -> STLC.Ty -> Map STLC.Ty [STLC.Exp a] -> Map STLC.Ty [STLC.Exp a]
insertVar uname ty' =
  Map.insertWith (<>) ty' [STLC.Var uname] . fmap (List.filter (/= STLC.Var uname))

-- | Generate app by first producing type and value of the argument
-- and then generating a compatible @Lam@.
genWellTypedApp :: forall a. Eq a => STLC.Ty -> GTyM a (STLC.Exp a)
genWellTypedApp ty' = do
  tg <- genKnownTypeMaybe
  eg <- genWellTypedExp' tg
  let tf = STLC.TArr tg ty'
  ef <- genWellTypedExp' tf
  pure (ef STLC.:@ eg)

-- | Try to look up a known expression of the desired type from the environment.
-- This does not always succceed, throwing `empty` when unavailable.
genWellTypedPath :: forall a. STLC.Ty -> GTyM a (STLC.Exp a)
genWellTypedPath ty' = do
  paths <- ask
  case fromMaybe [] (Map.lookup ty' paths) of
    [] -> empty
    es -> Gen.element es

-- | Generate either known types from the environment or new types.
genKnownTypeMaybe :: forall a. GTyM a STLC.Ty
genKnownTypeMaybe = do
  known <- ask
  if Map.null known
    then genTy
    else
      Gen.frequency
        [ (2, Gen.element $ Map.keys known),
          (1, genTy)
        ]

sample' :: forall m a. Monad m => GenT m a -> StateT Seed.Seed m a
sample' gen =
  let go :: StateT Seed.Seed m a
      go = do
        seed <- get
        let (seed', seed'') = Seed.split seed
        put seed''
        Tree.NodeT x _ <- lift . Tree.runTreeT . Gen.evalGenT 30 seed' $ gen
        maybe go pure x
   in go
