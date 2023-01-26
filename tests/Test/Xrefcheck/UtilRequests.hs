{- SPDX-FileCopyrightText: 2019 Serokell <https://serokell.io>
 -
 - SPDX-License-Identifier: MPL-2.0
 -}

module Test.Xrefcheck.UtilRequests
  ( checkLinkAndProgressWithServer
  , verifyLink
  , verifyReferenceWithProgress
  , checkMultipleLinksWithServer
  , checkLinkAndProgressWithServerDefault
  , verifyLinkDefault
  , verifyReferenceWithProgressDefault
  , withServer
  , VerifyLinkTestEntry (..)
  ) where

import Universum

import Control.Concurrent (forkIO, killThread)
import Control.Exception qualified as E
import Data.Map qualified as M
import Data.Set qualified as S
import Test.Tasty.HUnit (assertBool)
import Text.Interpolation.Nyan

import Xrefcheck.Config
import Xrefcheck.Core
import Xrefcheck.Progress
import Xrefcheck.Scan
import Xrefcheck.System
import Xrefcheck.Util
import Xrefcheck.Verify

withServer :: IO () -> IO () -> IO ()
withServer mock = E.bracket (forkIO mock) killThread . const

checkMultipleLinksWithServer
  :: IO ()
  -> IORef (S.Set DomainName)
  -> [VerifyLinkTestEntry]
  -> IO ()
checkMultipleLinksWithServer mock setRef entries =
  withServer mock $ do
    forM_ entries $ \VerifyLinkTestEntry {..} ->
      checkLinkAndProgress
        vlteConfigModifier
        setRef
        vlteLink
        vlteExpectedProgress
        vlteExpectationErrors

checkLinkAndProgressWithServer
  :: (Config -> Config)
  -> IORef (Set DomainName)
  -> IO ()
  -> Text
  -> Progress Int Text
  -> VerifyResult VerifyError
  -> IO ()
checkLinkAndProgressWithServer configModifier setRef mock link progress vrExpectation =
  withServer mock $
    checkLinkAndProgress configModifier setRef link progress vrExpectation

checkLinkAndProgress
  :: (Config -> Config)
  -> IORef (Set DomainName)
  -> Text
  -> Progress Int Text
  -> VerifyResult VerifyError
  -> IO ()
checkLinkAndProgress configModifier setRef link progress vrExpectation = do
  (result, progRes) <- verifyLink configModifier setRef link
  flip assertBool (result == vrExpectation)
    [int||
    Verification results differ: expected
    #{interpolateIndentF 2 (show vrExpectation)}
    but got
    #{interpolateIndentF 2 (show result)}
    |]
  flip assertBool (progRes `sameProgress` progress)
    [int||
    Expected the progress bar state to be
    #{interpolateIndentF 2 (show progress)}
    but got
    #{interpolateIndentF 2 (show progRes)}
    |]

checkLinkAndProgressWithServerDefault
  :: IORef (Set DomainName)
  -> IO ()
  -> Text
  -> Progress Int Text
  -> VerifyResult VerifyError
  -> IO ()
checkLinkAndProgressWithServerDefault = checkLinkAndProgressWithServer id

verifyLink
  :: (Config -> Config)
  -> IORef (S.Set DomainName)
  -> Text
  -> IO (VerifyResult VerifyError, Progress Int Text)
verifyLink configModifier setRef link = do
  let reference = Reference "" (Position Nothing) $ RIExternal $ ELUrl link
  progRef <- newIORef $ initVerifyProgress [reference]
  result <- verifyReferenceWithProgress configModifier reference setRef progRef
  progress <- readIORef progRef
  return (result, vrExternal progress)

verifyLinkDefault
  :: IORef (Set DomainName)
  -> Text
  -> IO (VerifyResult VerifyError, Progress Int Text)
verifyLinkDefault = verifyLink id

verifyReferenceWithProgress
  :: (Config -> Config)
  -> Reference
  -> IORef (S.Set DomainName)
  -> IORef VerifyProgress
  -> IO (VerifyResult VerifyError)
verifyReferenceWithProgress configModifier reference setRef progRef =
  fmap wrlItem <$> verifyReference
    (defConfig GitHub & cExclusionsL . ecIgnoreExternalRefsToL .~ []
                      & configModifier)
    FullMode setRef progRef (RepoInfo M.empty mempty) (mkRelPosixLink "") reference

verifyReferenceWithProgressDefault
  :: Reference
  -> IORef (Set DomainName)
  -> IORef VerifyProgress
  -> IO (VerifyResult VerifyError)
verifyReferenceWithProgressDefault = verifyReferenceWithProgress id

data VerifyLinkTestEntry = VerifyLinkTestEntry
  { vlteConfigModifier    :: Config -> Config
  , vlteLink              :: Text
  , vlteExpectedProgress  :: Progress Int Text
  , vlteExpectationErrors :: VerifyResult VerifyError
  }
