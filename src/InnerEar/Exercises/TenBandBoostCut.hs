{-# LANGUAGE DeriveDataTypeable #-}

module InnerEar.Exercises.TenBandBoostCut (tenBandBoostCutExercise) where

import Control.Monad (liftM)
import Reflex
import Reflex.Dom
import Data.Map
import Text.JSON
import Text.JSON.Generic

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
import InnerEar.Widgets.Config
import InnerEar.Widgets.Utility (radioWidget, safeDropdown)
import InnerEar.Widgets.AnswerButton

data FrequencyBand = AllBands | HighBands | MidBands | Mid8Bands | LowBands deriving (Eq,Ord,Data,Typeable, Read)

instance Show FrequencyBand where
  show (AllBands) = "Entire spectrum"
  show (HighBands) = "High Bands"
  show (MidBands) = "Mid Bands"
  show (Mid8Bands) = "Mid 8 Bands"
  show (LowBands) = "Low Bands"

frequencyBands :: [FrequencyBand]
frequencyBands = [AllBands, HighBands, Mid8Bands, MidBands, LowBands]

boostAmounts :: [Double]
boostAmounts = reverse [-10,-6,-3,-2,-1,1,2,3,6,10]

type Config = (FrequencyBand, Double) -- FrequencyBand and Boost/Cut amount

newtype Answer = Answer { frequency :: Frequency } deriving (Eq,Ord,Data,Typeable)

instance Show Answer where
  show a = freqAsString $ frequency a

instance Buttonable Answer where
  makeButton = showAnswerButton

answers :: [Answer]
answers = [
  Answer $ F 31 "31",Answer $ F 63 "63", Answer $ F 125 "125", Answer $ F 250 "250", Answer $ F 500 "500",
  Answer $ F 1000 "1k", Answer $ F 2000 "2k", Answer $ F 4000 "4k", Answer $ F 8000 "8k", Answer $ F 16000 "16k"]

renderAnswer :: Map String AudioBuffer -> Config -> (SourceNodeSpec, Maybe Time)-> Maybe Answer -> Synth ()
renderAnswer _ (_, boost) (src, dur) ans = buildSynth $ do
  synthSource src
  gain $ Db $ -10
  maybeSynth (\freq -> biquadFilter $ Peaking (Hz $ freqAsDouble $ frequency freq) 1.4 (Db boost)) ans
  destination
  maybeDelete (fmap (+ Millis 200) dur)

convertBands :: FrequencyBand -> [Answer]
convertBands AllBands = answers
convertBands HighBands = drop 5 answers
convertBands MidBands = take 5 $ drop 3 $ answers
convertBands Mid8Bands = take 8 $ drop 1 $ answers
convertBands LowBands = take 5 answers

instructions :: MonadWidget t m => m ()
instructions = el "div" $ do
  elClass "div" "instructionsText" $ text "In this exercise, a filter is applied to a specific region of the spectrum, either boosting or cutting the energy in that part of the spectrum by a specified amount. Your task is to identify which part of the spectrum has been boosted or cut. Challenge yourself and explore additional possibilities by trying cuts (instead of boosts) to the spectrum, and by trying more subtle boosts/cuts (dB values progressively closer to 0)."

generateQ :: Config -> [ExerciseDatum] -> IO ([Answer],Answer)
generateQ config _ = randomMultipleChoiceQuestion (convertBands $ fst config)

sourcesMap :: Map Int (String,SoundSourceConfigOption)
sourcesMap = fromList $ [
    (0, ("Pink noise", Resource "pinknoise.wav" (Just $ Sec 2))),
    (1, ("White noise", Resource "whitenoise.wav" (Just $ Sec 2))),
    (2, ("Load a sound file", UserProvidedResource))
  ]

displayEval :: MonadWidget t m => Dynamic t (Map Answer Score) -> Dynamic t (MultipleChoiceStore Config Answer) -> m ()
displayEval e _ = displayMultipleChoiceEvaluationGraph ("scoreBarWrapperTenBars","svgBarContainerTenBars","svgFaintedLineTenBars","xLabelTenBars") "Session Performance" "" answers e

-- temporary until config widget is changed to take a list/map of config parameters that can be changed
tenBandsConfigWidget :: MonadWidget t m => Dynamic t (Map String AudioBuffer) -> Config -> m (Dynamic t Config, Dynamic t (Maybe (SourceNodeSpec, Maybe Time)), Event t (), Event t ())
tenBandsConfigWidget sysResources c =  elClass "div" "configWidget" $ do
  config <- elClass "div" "tenBandsConfigWidget" $ do
    text "Spectrum Range: "
    (bands,_) <- safeDropdown (fst c) (fromList $ fmap (\x->(x,show x)) frequencyBands) (constDyn empty) never
    let boostMap = fromList $ zip [(0::Int),1..] boostAmounts
    let invertedBoostMap = fromList $ zip boostAmounts [(0::Int),1..]
    let initialVal = maybe 0 id $ Data.Map.lookup  (snd c) invertedBoostMap
    text "Boost/Cut amount: "
    boost <- liftM  _dropdown_value $ dropdown initialVal (constDyn $ fmap show boostMap) def
    boost' <- mapDyn (maybe 10 id . (flip Data.Map.lookup) boostMap) boost
    combineDyn (,) bands  boost'
  (source, playEv, stopEv) <- sourceSelectionWidget sysResources "tenBandBoostCutExercise" sourcesMap 0
  return (config, source, playEv, stopEv)

valueForBands :: FrequencyBand -> Double
valueForBands AllBands = 2 * 820/6
valueForBands HighBands = 0
valueForBands MidBands = 0
valueForBands Mid8Bands = 1 * 820/6
valueForBands LowBands = 0

valueForDb :: Double -> Double
valueForDb 10 = 0
valueForDb 6 = 1 * 820/6
valueForDb 3 = 2 * 820/6
valueForDb 2 = 3 * 820/6
valueForDb 1 = 4 * 820/6
valueForDb x | x <0 = valueForDb (x * (-1)) + 80

valueForConfig :: (FrequencyBand,Double) -> Double
valueForConfig (bands,db) = fromIntegral $ ceiling (valueForBands bands + valueForDb db) + 100

scoreForAnswer :: ((FrequencyBand, Double), Bool) -> Double
scoreForAnswer (c,True) = valueForConfig c
scoreForAnswer _ = 0

xpFunction :: XpFunction Config Answer -- MultipleChoiceStore c a -> (Int,Int)
xpFunction s | length (recentAnswers s) < 5 = (0,0)
xpFunction s | otherwise = (ceiling points,valueOfMostRecentConfig)
  where
    points = (/ fromIntegral (length (recentAnswers s))) $ sum $ fmap scoreForAnswer $ recentAnswers s
    valueOfMostRecentConfig = ceiling $ valueForConfig $ fst $ head $ recentAnswers s

tenBandBoostCutExercise :: MonadWidget t m => Exercise t m Config [Answer] Answer (Map Answer Score) (MultipleChoiceStore Config Answer)
tenBandBoostCutExercise = multipleChoiceExercise
  3
  answers
  instructions
  tenBandsConfigWidget
  renderAnswer
  TenBandBoostCut
  (AllBands, 10)
  displayEval
  generateQ
  xpFunction
