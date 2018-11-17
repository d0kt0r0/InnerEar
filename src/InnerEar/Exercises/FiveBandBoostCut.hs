{-# LANGUAGE DeriveDataTypeable #-}

module InnerEar.Exercises.FiveBandBoostCut (fiveBandBoostCutExercise) where

import Reflex
import Reflex.Dom
import Data.Map
import Data.List (elemIndex,findIndices)
import System.Random
import Text.JSON
import Text.JSON.Generic

import InnerEar.Widgets.Config
import InnerEar.Widgets.SpecEval
import InnerEar.Types.Data hiding (Time)
import InnerEar.Types.Sound
import InnerEar.Types.Score
import InnerEar.Types.MultipleChoiceStore
import Sound.MusicW hiding (Frequency)
import InnerEar.Types.Exercise
import InnerEar.Types.ExerciseId
import InnerEar.Types.Frequency
import InnerEar.Exercises.MultipleChoice
import InnerEar.Widgets.AnswerButton

type Config = Double

configs :: [Double]
configs = [10,6,3,2,1,-1,-2,-3,-6,-10]

-- configMap::Map String Config
-- configMap = fromList $ fmap (\x-> (show x ++ " dB",x)) configs

configMap::Map Int (String,Config)
configMap = fromList $ zip [0::Int,1..] $ fmap (\x-> (show x ++ " dB",x)) configs

newtype Answer = Answer { frequency :: Frequency } deriving (Eq,Ord,Data,Typeable)

instance Buttonable Answer where
  makeButton = showAnswerButton

instance Show Answer where
  show a = freqAsString $ frequency a

answers :: [Answer]
answers = [Answer $ F 155 "Bass (155 Hz)",Answer $ F 1125 "Low Mids (1125 Hz)",Answer $ F 3000 "High Mids (3 kHz)",
  Answer $ F 5000 "Presence (5 kHz)",Answer $ F 13000 "Brilliance (13 kHz)"]

renderAnswer :: Map String AudioBuffer -> Config -> (SourceNodeSpec,Maybe Time) -> Maybe Answer -> Synth ()
renderAnswer _ db (src, dur) (Just freq) = buildSynth $ do
  let env = maybe (return EmptyGraph) (unitRectEnv (Millis 1)) dur
  synthSource src >> gain (Db $ -10)
  biquadFilter $ Peaking (Hz $ freqAsDouble $ frequency freq) 1.4 (Db db)
  env
  destination
  maybeDelete (fmap (+Sec 0.2) dur)
renderAnswer _ db (src, dur) _ = buildSynth $ do
  let env = maybe (return EmptyGraph) (unitRectEnv (Millis 1)) dur
  synthSource src >> gain (Db $ -10) >> env >> destination
  maybeDelete (fmap (+Sec 0.2) dur)

instructions :: MonadWidget t m => m ()
instructions = el "div" $ do
  elClass "div" "instructionsText" $ text "In this exercise, a filter is applied to a specific region of the spectrum, either boosting or cutting the energy in that part of the spectrum by a specified amount. Your task is to identify which part of the spectrum has been boosted or cut. Challenge yourself and explore additional possibilities by trying cuts (instead of boosts) to the spectrum, and by trying more subtle boosts/cuts (dB values progressively closer to 0)."

displayEval :: MonadWidget t m => Dynamic t (Map Answer Score) -> Dynamic t (MultipleChoiceStore Config Answer) -> m ()
displayEval e _ = displayMultipleChoiceEvaluationGraph ("scoreBarWrapperFiveBars","svgBarContainerFiveBars","svgFaintedLineFiveBars", "xLabelFiveBars") "Session performance" "Hz" answers e

generateQ :: Config -> [ExerciseDatum] -> IO ([Answer],Answer)
generateQ _ _ = randomMultipleChoiceQuestion answers

sourcesMap:: Map Int (String,SoundSourceConfigOption)
sourcesMap = fromList $ [
    (0, ("Pink noise", Resource "pinknoise.wav" (Just $ Sec 2))),
    (1, ("White noise", Resource "whitenoise.wav" (Just $ Sec 2))),
    (2, ("Load a sound file", UserProvidedResource))
  ]

fiveBandBoostCutExercise :: MonadWidget t m => Exercise t m Config [Answer] Answer (Map Answer Score) (MultipleChoiceStore Config Answer)
fiveBandBoostCutExercise = multipleChoiceExercise
  3
  answers
  instructions
  (configWidget "fiveBandBoostCutExercise" sourcesMap 0 "Boost amount: " configMap) -- (dynRadioConfigWidget "fiveBandBoostCutExercise" sourcesMap 0  configMap)
  renderAnswer
  FiveBandBoostCut
  (configs!!0)
  (\_ _ -> return ())
  generateQ
  (const (0,2))
