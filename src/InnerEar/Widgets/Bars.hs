module InnerEar.Widgets.Bars where

import Reflex
import Reflex.Dom
import Data.Map
import Reflex.Dom.Contrib.Widgets.Svg
import Control.Monad

import InnerEar.Widgets.Utility

rect :: MonadWidget t m => Dynamic t Int -> Dynamic t Int -> Dynamic t Float -> Dynamic t Float -> Dynamic t String -> Dynamic t String -> m ()
rect posX posY width height style transform= do
  posX' <- mapDyn (singleton "x" . show) posX
  posY' <- mapDyn (singleton "y" . show) posY
  width' <- mapDyn (singleton "width" . show) width
  height' <- mapDyn (singleton "height" . show) height
  style' <- mapDyn (singleton "style") style
  transform' <- mapDyn (singleton "transform") transform
  m <- mconcatDyn [posX', posY', width', height', style', transform']
  svgDynAttr "rect" m $ return()

--width and height are static

rectCSS :: MonadWidget t m => m ()
rectCSS = do
  svgClass "rect" "rects" $ return ()
{--
svgCssDynAttr :: MonadWidget t m => Text -> Dynamic t (Map Text Text) -> Text -> m a -> m a
svgCssDynAttr elementTag attrs class child = snd <$> svgDynAttr' (elementTag attrs) child

rectDynCSS :: MonadWidget t m => Dynamic t Int -> Dynamic t Int -> Dynamic t Float -> m ()
rectDynCSS posX posY height = do
    let rect = svgClass "rect" "rectStyle"
    posX' <- mapDyn (singleton "x" . show) posX
    posY' <- mapDyn (singleton "y" . show) posY
    height' <- mapDyn (singleton "height" . show) height
    m <- mconcatDyn [posX', posY', height' ,rect]
    svgDynAttr "rect" m $ return ()
--}
buttonLabels :: MonadWidget t m => String -> m ()
buttonLabels s = do
   elClass "div" "test" $ text (show s)
   return ()

drawBar ::  MonadWidget t m =>  Dynamic t Int -> m ()
drawBar x =  do
 let svg = Just "http://www.w3.org/2000/svg"
 let svgAttrs = [("width", "100px")
                ,("height", "200px")
                ,("viewBox", "0 0 300 200")]
 --elDynAttr "200px" svgAttrs $ do el "height" $ x
 elWith "svg" (ElConfig svg (fromList svgAttrs)) $ do
   elWith "rect" (ElConfig svg (fromList [("width", "100"), ("height", "100"), ("fill", "red")])) (return ())

--elDynAttr :: (...) => Text -> Dynamic t (Map Text Text) -> m a -> m a

-- this was our original version from Friday (4 more versions follow)
-- after some discussion we should delete all but the final version below
dynButton' :: MonadWidget t m => Dynamic t String -> m (Event t ())
dynButton' label = do
  let initialButton = return never -- m (Event t ())
  postBuildEvent <- getPostBuild -- m (Event t ())
  let postBuildLabel = tagDyn label postBuildEvent -- Event t String
  let postBuildButton = fmap button postBuildLabel
  let newButtons = fmap button $ updated label
  let newButtons' = leftmost [postBuildButton,newButtons]
  switchPromptlyDyn <$> widgetHold initialButton newButtons'

-- this second version uses "switchPromptly never" to flatten the result of "dyn"
dynButton'' :: MonadWidget t m => Dynamic t String -> m (Event t ())
dynButton'' label = do
  x <- mapDyn button label
  y <- dyn x
  switchPromptly never y

-- this third version is the same as the second but without the do notation
dynButton''' :: MonadWidget t m => Dynamic t String -> m (Event t ())
dynButton''' label = mapDyn button label >>= dyn >>= switchPromptly never

-- this fourth version uses a more generic function "dynE" added to InnerEar.Widgets.Utility
dynButton'''' :: MonadWidget t m => Dynamic t String -> m (Event t ())
dynButton'''' label = mapDyn button label >>= dynE

-- a final version that uses >=> from Control.Monad to compose together two a -> m b functions
dynButton :: MonadWidget t m => Dynamic t String -> m (Event t ())
dynButton = (mapDyn button) >=> dynE

drawBar' :: MonadWidget t m =>  Dynamic t Float -> m ()
drawBar' x  = do
    let m = fromList [("width","200px"),("height","200px"), ("viewBox", "0 0 300 200")]
    svgAttr "svg" m $ do
       let posX = constDyn $ negate 100
       let posY = constDyn $ negate 200
       let w = constDyn 50
       h <- mapDyn (*5) x
       let t = constDyn "rotate(180)"
       let s = constDyn "fill:green;stroke-width:5"
       rect posX posY w h s t

{--drawBarCSS :: MonadWidget t m => Dynamic t Float -> m ()
drawBarCSS x = do
   svgClass "svg" "svgS" $ do
    let posX = constDyn $ negate 100
    let posY = constDyn $ negate 200
    h <- mapDyn (*10) x
    --let t = constDyn "rotate(180)"
    --let s = constDyn "fill:green;"
    rectDynCSS posX posY h
--}

drawBarwScale :: MonadWidget t m => Dynamic t Float -> m ()
drawBarwScale x  = do
   let m = fromList [("width", "100px"),("height","200px"), ("viewBox", "0 0 300 200")]
   svgAttr "svg" m $ do
     let posX = constDyn 20
     let posY = constDyn 20
     let w = constDyn 30
     h <- mapDyn (*32) x
     let t = constDyn "rotate(-90)"
     let s = constDyn "fill:yellow"
     rect posX posY w h s t

labelBarButton :: MonadWidget t m => String ->  Dynamic t String -> Dynamic t Float -> m (Event t ())
labelBarButton label buttonString barHeight = do
    --el "div" $ text (show label)
    buttonLabels label
    drawBar' barHeight
    --drawBarCSS barHeight
    question <- dynButton buttonString -- m (Event t ())
    return (question)

test :: MonadWidget t m => m ()
test = do
   elClass "div" "test" $ text "this is a test"
   return ()


drawBar'' :: MonadWidget t m => Dynamic t Float -> m()
drawBar'' x = do
  let attr = fromList[("width", "100px"),("height", "200px"), ("viewBox", "0 0 300 200")]
  svgAttr "svg" attr $ do
     let posX = constDyn 50
     let posY = constDyn 20
     let w = constDyn 25
     h <- mapDyn(*32) x
     let t = constDyn "rotate(-90)"
     let s = constDyn "fill:blue"
     rect posX posY w h s t





--Datam.map
--let x = constDyn value
--holDyn
--mapDyn from Reflex.Dynamic
--combineDyn
