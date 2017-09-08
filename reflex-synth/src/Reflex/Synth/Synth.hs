module Reflex.Synth.Synth where

import Reflex.Synth.Types
--import InnerEar.Types.Sound
import qualified Reflex.Synth.Foreign as F
import qualified Data.Map as M
import Reflex
import Reflex.Dom
import Control.Monad (liftM)
import GHCJS.DOM.JSFFI.Generated.HTMLElement

--import GHCJS.DOM.JSFFI.Generated.File (getName)
import GHCJS.DOM.File (getName)
import GHCJS.DOM.FileReader (newFileReader,getResult, readAsDataURL,load)
import GHCJS.DOM.EventM
import GHCJS.DOM.Types(toJSString,HTMLCanvasElement,unHTMLCanvasElement)
import Control.Monad.IO.Class (liftIO)
import GHCJS.Marshal(fromJSVal)


class WebAudio a where
  createGraph :: a -> IO WebAudioGraph

instance WebAudio Filter where
  createGraph (NoFilter) = createGain 0 >>= return . WebAudioGraph
  createGraph filt = createBiquadFilter filt >>= return . WebAudioGraph

instance WebAudio Buffer where
  createGraph (File path) = createBufferNode (File path) >>= return . WebAudioGraph

instance WebAudio Node where
  createGraph n = do
    node <- createNode n
    return $ WebAudioGraph $ WebAudioNode n (getJSVal node)

instance WebAudio Source where
  createGraph (NodeSource node dur) =
    case node of
      (MediaNode a) ->do
        v <- createMediaNode a
        let graph = WebAudioGraph v
        createGraph graph
      (Destination) -> error "Destination cannot be a source node"
      (GainNode _) -> error "GainNode cannot be a source node"
      (FilterNode _) -> error "FilterNode cannot be a source node"
      (ScriptProcessorNode _) -> error "ScriptProcessorNode cannot be a source node"
      (BufferNode (LoadedFile soundID _)) -> do
        stopNodeByID soundID
        x <- createNode node
        createGraph (WebAudioGraph x)
      otherwise -> do
        let dur' = maybe 2 id dur
        x <- createNode node
        y <- createAsrEnvelope 0.005 dur' 0.005
        let graph = WebAudioGraph' x (WebAudioGraph y)
        createGraph graph

instance WebAudio WebAudioGraph where
  createGraph = connectGraph

instance WebAudio Sound where
  createGraph (Sound s) = do
    graph <- createGraph s
    connectGraph graph
    return graph
  createGraph (FilteredSound s f) = do
    source <- createGraph s
    filt <- createGraph f
    let graph = WebAudioGraph'' source filt
    connectGraph graph
  createGraph (NoSound) = do
    x <- createSilentNode
    y <- createGain 0
    setAmp 0 y
    let graph = WebAudioGraph' x $ WebAudioGraph y
    connectGraph graph
  createGraph (GainSound s db) = do
    source <- createGraph s
    gain <- createGain db
    let graph = WebAudioGraph'' source (WebAudioGraph gain)
    connectGraph graph
  createGraph (ProcessedSound s effect) = do
    g <- createGraph s
    sp <- createScriptProcessorNode effect
    let graph = WebAudioGraph'' g $ WebAudioGraph sp
    connectGraph graph



createSilentNode::IO WebAudioNode
createSilentNode = F.createSilentNode >>= return . WebAudioNode (SilentNode)

createAudioContext::IO ()
createAudioContext = F.createAudioContext

createSound :: Sound -> IO (WebAudioGraph)
createSound (FilteredSound s f) = do
  sourceNode <- createGraph s
  filterNode <- createGraph f
  dest <- getDestination
  let graph = WebAudioGraph'' sourceNode (WebAudioGraph'' filterNode (WebAudioGraph dest))
  connectGraph graph



getSource:: Sound -> Source
getSource (Sound s) = s
getSource (GainSound s _) = getSource s
getSource (FilteredSound s _) = s
getSource (ProcessedSound s _) = getSource s
getSource (NoSound) = NodeSource SilentNode $ Just 2

disconnectGraphAtTimeMaybe:: WebAudioGraph -> Maybe Double -> IO ()
disconnectGraphAtTimeMaybe a (Just b) = disconnectGraphAtTime a b
disconnectGraphAtTimeMaybe _ Nothing = return ()

disconnectGraphAtTime :: WebAudioGraph -> Double -> IO ()
disconnectGraphAtTime (WebAudioGraph w) t = disconnectAllAtTime w t
disconnectGraphAtTime (WebAudioGraph' n g) t = do
  disconnectAllAtTime n t
  disconnectGraphAtTime g t
disconnectGraphAtTime (WebAudioGraph'' g1 g2) t = do
  disconnectGraphAtTime g1 t
  disconnectGraphAtTime g2 t

performSound:: MonadWidget t m => Event t Sound -> m ()
performSound event = do
  let n = fmap (\e-> do
                      let source = getSource e
                      let t = getT source
                      graph <- createGraph e
                      startGraph graph
                      disconnectGraphAtTimeMaybe graph  t
                      ) event          -- Event t (IO ())
  performEvent_ $ fmap liftIO n
  where getT (NodeSource _ t) = t


audioElement::MonadWidget t m => m ()
audioElement = elDynAttr "audio" attrs (return())
  where attrs = constDyn $ M.fromList $ zip ["id","controls"] ["userAudio","controls"]



bufferInput::MonadWidget t m => String -> m (Event t ())
bufferInput s = elClass "div" "bufferInput" $ do
  let attrs = FileInputConfig $ constDyn $ M.fromList $ zip ["accept","id"] ["audio/*",s]
  input <- fileInput attrs
  --let element = _fileInput_element input
  --ev <- liftM (() <$) $ wrapDomEvent (onEventName Load) element
  let ev = (() <$) $ updated $ _fileInput_value input
  performEvent_ $ fmap (liftIO . const (F.loadBuffer $ toJSString s)) ev
  return ev

bufferInput'::MonadWidget t m => String -> m (Event t ())
bufferInput' s = do
  let attrs = FileInputConfig $ constDyn $ M.fromList $ zip ["accept","id"] ["audio/*",s++"Input"]
  input <- fileInput attrs
  let ev = (() <$) $ updated $ _fileInput_value input
  performEvent_ $ fmap (liftIO . const (F.setAudioSrc $ toJSString s)) ev
  return ev

loadAndDrawBuffer:: String -> HTMLCanvasElement -> IO()
loadAndDrawBuffer inputId canvas = do
  let el' = unHTMLCanvasElement canvas
  F.loadAndDrawBuffer (toJSString inputId) el'



createAudioElement::MonadWidget t m => String -> Dynamic t (M.Map String String) -> m (String)
createAudioElement s m = elDynAttr "audio" m (return s)



-- creates graph and connects it to dest for initial source.
-- when event fires, disconnects source from everything and connects source to
-- the Node contained in the event. connects the node to the dest.
-- useful for swapping 'effects' on MediaNodes
holdAndConnectSound:: MonadWidget t m => Source -> Event t Node -> m ()
holdAndConnectSound s ev = do
  g <- liftIO (createGraph s)
  liftIO (connectGraphToDest g)
  performEvent $ fmap liftIO $ fmap (\n -> do
    let gLast = getLastNode g
    disconnectAll gLast
    newNode <- createNode n
    newGraph <- connect gLast newNode
    connectGraphToDest newGraph
    ) ev
  return ()



-- @Might want this again at some point..
--updatableSound::MonadWidget t m => Dynamic t WebAudioGraph -> Dynamic t WebAudioGraph -> m (Dynamic t  WebAudioGraph)
--updatableSound first next = do
--  x<-combineDyn (,) first next
--  e <- performEvent $ fmap liftIO $ fmap (\_->do
--    let y = fmap (\(a,b)->(getLastNode a,getFirstNode b)) $ current
--    return $ fmap (\(a,b)->disconnect a b) y
--    ) $ tagDyn x $ leftmost [updated first, updated next]
--  graph <- combineDyn (WebAudioGraph'') first next
--  performEvent $ fmap (liftIO . connectGraph) $ tagDyn graph e
--  return graph
--updatableSound::MonadWidget t m => Dynamic t Node -> Dynamic t Node -> m (Dynamic t  WebAudioGraph)
--updatableSound first next = do
--  x<-combineDyn (,) first next
--  e <- performEvent $ fmap liftIO $ fmap (\(a,b)->do
--    disconnect a b
--    a' <- createNode a
--    b' <- createNode b
--    return (WebAudioGraph' a' $ WebAudioGraph b')
--    ) $ updated x
--  performEvent $ fmap (liftIO . connectGraph) e
--  combineDyn (\a b -> WebAudioGraph' a $ WebAudioGraph b) first next




-- Connects nodes to eachother and last node to destination
connectGraphOnEv :: MonadWidget t m => Event t Sound -> m ()
connectGraphOnEv sound = do
  performEvent $ fmap liftIO $ fmap (\x->do
    g <- createGraph x
    connectGraphToDest g
    ) sound
  return ()

createNode:: Node -> IO WebAudioNode
createNode (FilterNode x) = createBiquadFilter x
createNode (GainNode d) = createGain d
createNode (Destination) = error "cannot create destination node"
createNode (AdditiveNode xs) = createAdditiveNode xs
createNode (OscillatorNode x) = createOscillator x
createNode (BufferNode x) = createBufferNode x
createNode (MediaNode s) = createMediaNode s


createMediaNode:: String -> IO WebAudioNode
createMediaNode s = F.createMediaNode (toJSString s) >>= return . (WebAudioNode (MediaNode s))

createAdditiveNode:: [Node] -> IO WebAudioNode
createAdditiveNode xs = do
  nodes <- sequence $ fmap createNode xs -- IO [WebAudioNode]
  g <- F.createGain
  F.setAmp 0 g
  sequence (fmap startNode nodes)
  mapM (((flip F.connect) g) . getJSVal) nodes
  return (WebAudioNode (AdditiveNode xs) g) -- returning the gain node's


--renderAudioWaveform:: G.HTMLCanvasElement -> G.HTMLCanvasElement -> IO()
--renderAudioWaveform l r= do
--  let l' = G.unHTMLCanvasElement l
--  let r' = G.unHTMLCanvasElement  r
--  F.renderAudioWaveform l' r'


renderAudioWaveform:: String -> HTMLCanvasElement -> IO ()
renderAudioWaveform inputId el = do
  let el' = unHTMLCanvasElement el
  F.renderAudioWaveform (toJSString inputId) el'




-- returns Event with file's url as a string
-- @ I think this is causing weird runtime errors, do not use until understanding, but may be useful at some point
--fileToURL :: (MonadWidget t m) => Event t G.File -> m (Event t String)
--fileToURL file = do
--  fileReader <- liftIO newFileReader
--  performEvent_ (fmap (\f -> readAsDataURL fileReader (Just f)) file)
--  liftM (fmapMaybe id) $ wrapDomEvent fileReader (`on` load) . liftIO $ do
--      v <- getResult fileReader
--      fromJSVal v
--mediaElement::MonadWidget t m => String -> m Source
--mediaElement audioId = elClass "div" "userAudio" $ do
--  let attrs = FileInputConfig $ constDyn $ M.singleton "accept" "audio/*"
--  input <- fileInput attrs
--  fileUrlEv <- fileToURL $ fmap (!!0) $ updated $ _fileInput_value input
--  audioSrc <- holdDyn "" fileUrlEv
--  audioAttrs <- mapDyn (M.fromList . zip ["src","class","id"] . (:["audioElement",audioId])) audioSrc
--  return $ NodeSource (MediaNode audioId) 0  -- @ '0' is temporary, this should be a more meaningful duration derrived perhaps from the soundfile
--  elDynAttr "audio" audioAttrs (return())
--  --liftIO $ createMediaNode audioId'
