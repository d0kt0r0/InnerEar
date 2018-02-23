{-# LANGUAGE DeriveDataTypeable #-}

module InnerEar.Exercises.FrequencyEnvelope (frequencyEnvelopeExercise) where

import Reflex
import Reflex.Dom
import Data.Map
import Text.JSON
import Text.JSON.Generic

import Reflex.Synth.Types
import InnerEar.Exercises.MultipleChoice
import InnerEar.Types.ExerciseId
import InnerEar.Types.Exercise
import InnerEar.Types.Score
import InnerEar.Widgets.Config
import InnerEar.Widgets.SpecEval
import InnerEar.Types.Data
import InnerEar.Types.Frequency
import InnerEar.Types.Utility

type Similarity = Int
type Duration = Int
type Octaves = Double
type Config = (Similarity,Duration,Range)

similarities :: [Similarity]
similarities = [1,2,3,4]

durations :: [Duration]
durations = [1000,500,250,125,100,80,60,40,20]

octaves :: [Octave]
octaves = [8.0,4.0,2.0,1.0,0.5,1/6,1/12]

data Answer = Quicker | Linear | Slower
  deriving (Eq,Ord,Data,Typeable,Show)

answers = [Quicker,Linear,Slower]

getEnvelope :: Similarity -> Answer -> (Double -> Double)
getEnvelope s Quicker = riseToRiseAndFall $ quickerEnvelope (similarityToExp s)
getEnvelope s Linear = riseToRiseAndFall $ linearEnvelope (similarityToExp s)
getEnvelope s Slower = riseToRiseAndFall $ slowerEnvelope (similarityToExp s)

similarityToExp :: Int -> Double
similarityToExp 1 = 3
similarityToExp 2 = 2
similarityToExp 3 = 1.5
similarityToExp 4 = 1.25

slowerEnvelope :: Double -> Double -> Double
slowerEnvelope e x = x**e

linearEnvelope :: Double -> Double -> Double
linearEnvelope _ x = x

quickerEnvelope :: Double -> Double -> Double
quickerEnvelope e x = 1 - (slowerEnvelope e (1-x))

riseToRiseAndFall :: (Double -> Double) -> Double -> Double
riseToRiseAndFall f x | x <= 0.5 = f (x*2)
riseToRiseAndFall f x | x > 0.5 = f ((1-x)*2)

lowPitch :: Octave -> Double -- double is Frequency
lowPitch o = midicps $ 69-(o*12/2)

highPitch :: Octave -> Double -- double is Frequency
highPitch _ = midicps $ 69+(o*12/2)

actualEnvelope :: Config -> Answer -> Double -> Double
actualEnvelope (s,d,o) a = scaleRange (lowPitch o) (highPitch o) $ scaleDomain 0.0 d $ getEnvelope s a

scaleDomain :: Double -> Double -> (Double -> Double) -> Double -> Double
scaleDomain d1 d2 f x = f $ linlin d1 d2 0.0 1.0 x

scaleRange :: Double -> Double -> (Double -> Double) -> Double -> Double
scaleRange r1 r2 f x = linlin 0.0 1.0 r1 r2 $ f x

linlin :: Double -> Double -> Double -> Double -> Double -> Double
linlin in1 in2 out1 out2 x = linlin (x-in1)/(in2-in1)*(out2-out1)+out2

sampleEnvelope :: Int -> (Double -> Double) -> Duration -> [(Double,Double)]
sampleEnvelope r f d = fmap (f . (\x -> x * d / r)) $ [0, 1 .. (r-1)]

renderAnswer :: Config -> Source -> Maybe Answer -> Sound
renderAnswer c@(s,d,o) _ (Just a) = OurCoolSound e
  where e = sampleEnvelope 200 (actualEnvelope c a d) d
renderAnswer _ _ Nothing = NoSound

displayEval :: MonadWidget t m => Dynamic t (Map Answer Score) -> m ()
displayEval _ = return ()

generateQ :: Config -> [ExerciseDatum] -> IO ([Answer],Answer)
generateQ _ _ = randomMultipleChoiceQuestion answers

thisConfigWidget:: MonadWidget t m => Config -> m (Dynamic t Config, Dynamic t Source, Event t (Maybe a))
thisConfigWidget c@(s,d,o) = do
  text "Similarity: "
  simDropDown <- dropdown similarities (constDyn $ fromList $ zip similarities similarities) (DropdownConfig never (constDyn empty))
  text "Duration: "
  durDropDown <- dropdown durations (constDyn $ fromList $ zip durations durations) (DropdownConfig never (constDyn empty))
  text "Octaves: "
  octDropDown <- dropdown octaves (constDyn $ fromList $ zip octaves octaves) (DropdownConfig never (constDyn empty))
  conf <- (,,) <$> _dropdown_value simDropDown <*> _dropdown_value durDropDown <*> _dropdown_value octDropDown
  let source = constDyn $ NodeSource (SilentNode) (Just 1.0)
  return (conf, source, never)

instructions :: MonadWidget t m => m ()
instructions = el "div" $ do
  elClass "div" "instructionsText" $ text "Instructions placeholder"

frequencyEnvelopeExercise :: MonadWidget t m => Exercise t m Config [Answer] Answer (Map Answer Score)
frequencyEnvelopeExercise = multipleChoiceExercise
  2
  answers
  instructions
  thisConfigWidget
  renderAnswer
  FrequencyEnvelope
  (-10)
  displayEval
  generateQ