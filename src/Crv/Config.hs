{- SPDX-FileCopyrightText: 2018-2019 Serokell <https://serokell.io>
 -
 - SPDX-License-Identifier: MPL-2.0
 -}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Crv.Config where

import Data.Aeson.Options (defaultOptions)
import Data.Aeson.TH (deriveFromJSON)
import Data.Yaml (FromJSON (..), decodeEither', prettyPrintParseException, withText)
import Instances.TH.Lift ()
import qualified Language.Haskell.TH.Syntax as TH
import System.FilePath.Posix ((</>))
import TH.RelativePaths (qReadFileBS)
import Time (KnownRatName, Second, Time, unitsP)

import Crv.System (CanonicalizedGlobPattern)

-- | Overall config.
data Config = Config
    { cTraversal    :: TraversalConfig
    , cVerification :: VerifyConfig
    }

-- | Config of repositry traversal.
data TraversalConfig = TraversalConfig
    { tcIgnored   :: [FilePath]
      -- ^ Folders, files in which we completely ignore.
    }

-- | Config of verification.
data VerifyConfig = VerifyConfig
    { vcAnchorSimilarityThreshold :: Double
    , vcExternalRefCheckTimeout   :: Time Second
    , vcVirtualFiles              :: [CanonicalizedGlobPattern]
      -- ^ Files which we pretend do exist.
    , vcNotScanned                :: [FilePath]
      -- ^ Folders, references in files of which we should not analyze.
    }

-----------------------------------------------------------
-- Default config
-----------------------------------------------------------

-- | Default config in textual representation.
--
-- Sometimes you cannot just use 'defConfig' because clarifying comments
-- would be lost.
defConfigText :: ByteString
defConfigText =
  $(TH.lift =<< qReadFileBS ("src-files" </> "def-config.yaml"))

defConfig :: HasCallStack => Config
defConfig =
  either (error . toText . prettyPrintParseException) id $
  decodeEither' defConfigText

-----------------------------------------------------------
-- Yaml instances
-----------------------------------------------------------

deriveFromJSON defaultOptions ''Config
deriveFromJSON defaultOptions ''TraversalConfig
deriveFromJSON defaultOptions ''VerifyConfig

instance KnownRatName unit => FromJSON (Time unit) where
    parseJSON = withText "time" $
        maybe (fail "Unknown time") pure . unitsP . toString
