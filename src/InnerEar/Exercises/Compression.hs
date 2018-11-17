{-# LANGUAGE DeriveDataTypeable #-}

module InnerEar.Exercises.Compression (compressionExercise) where

import Reflex
import Reflex.Dom
import Data.Map
import Text.JSON
import Text.JSON.Generic

import Sound.MusicW
import InnerEar.Exercises.MultipleChoice
import InnerEar.Types.ExerciseId
import InnerEar.Types.Exercise
import InnerEar.Types.Score
import InnerEar.Types.MultipleChoiceStore
import InnerEar.Widgets.Config
import InnerEar.Widgets.SpecEval
import InnerEar.Types.Data hiding (Time)
import InnerEar.Types.Sound
import InnerEar.Widgets.AnswerButton

type Config = Double -- representing compression ratio, i.e. 2 = 2:1 compression ratio

configs :: [Config]
configs = [20,10,5,2,1.5]

configMap:: Map Int (String, Config)
configMap = fromList $ zip [(0::Int),1..] $ fmap (\x-> (show x++":1", x)) configs

data Answer = Answer Bool deriving (Eq,Ord,Data,Typeable)

instance Show Answer where
  show (Answer True) = "Compressed"
  show (Answer False) = "Not Compressed"

instance Buttonable Answer where
  makeButton = showAnswerButton

answers = [Answer False,Answer True]

renderAnswer::Map String AudioBuffer -> Config -> (SourceNodeSpec,Maybe Time)-> Maybe Answer -> Synth ()
renderAnswer _ ratio (src, dur) (Just (Answer True)) = buildSynth $ do
  let env = maybe (return EmptyGraph) (unitRectEnv (Millis 1)) dur
  synthSource src
  gain $ Db $ fromIntegral $ -10
  compressor (Db $ -20) (Db 0) (Db ratio) (Sec 0.003) (Sec 0.1)
  env
  destination
  maybeDelete (fmap (+Sec 0.2) dur)
renderAnswer _ _ (src, dur) _ = buildSynth $ do
  let env = maybe (return EmptyGraph) (unitRectEnv (Millis 1)) dur
  synthSource src >> gain (Db $ fromIntegral $ -10) >> env >> destination
  maybeDelete (fmap (+Sec 0.2) dur)

displayEval :: MonadWidget t m => Dynamic t (Map Answer Score) -> Dynamic t (MultipleChoiceStore Config Answer) -> m ()
displayEval e _ = displayMultipleChoiceEvaluationGraph ("scoreBarWrapper","svgBarContainer","svgFaintedLine", "xLabel") "Session Performance" "" answers e

generateQ :: Config -> [ExerciseDatum] -> IO ([Answer],Answer)
generateQ _ _ = randomMultipleChoiceQuestion [Answer False,Answer True]

instructions :: MonadWidget t m => m ()
instructions = el "div" $ do
  elClass "div" "instructionsText" $ text "In this exercise, a reference sound is either compressed or not and your task is to tell whether or not it has been compressed. The threshold of the compressor is set at -20 dBFS, and you can configure the exercise to work with smaller and smaller ratios for increased difficulty. Note that you must provide a source sound to use for the exercise (click on Browse to the right). Short musical excerpts that consistently have strong levels are recommended."


sourcesMap:: Map Int (String,SoundSourceConfigOption)
sourcesMap = singleton 0 ("Load a soundfile", UserProvidedResource)

compressionExercise :: MonadWidget t m => Exercise t m Config [Answer] Answer (Map Answer Score) (MultipleChoiceStore Config Answer)
compressionExercise = multipleChoiceExercise
  1
  answers
  instructions
  (configWidget "compressionExercise" sourcesMap 0 "Compression ratio:  " configMap) -- (dynRadioConfigWidget "fiveBandBoostCutExercise" sourcesMap 0  configMap)
  renderAnswer
  Compression
  (20)
  (\_ _ -> return ())
  generateQ
  (const (0,2))
