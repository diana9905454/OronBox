/* Uses the version-matched sherpa_onnx_web assets bundled by Flutter. */
let runtime;
let recognizer;
let stream;
let previous = '';
let tail = Promise.resolve();
self.onmessage = (event) => {
  tail = tail.then(() => handle(event.data)).catch(() => {});
};
async function handle(message) {
  const {id, method, argument} = message;
  try {
    if (method === 'load') {
      const base = argument.assets;
      importScripts(base + '/sherpa-onnx-wasm-web.js');
      runtime = await SherpaOnnx({locateFile: name => base + '/' + name,
        print: () => {}, printErr: () => {}});
      importScripts(base + '/sherpa-onnx-asr.js');
      runtime.FS.mkdir('/model');
      for (const [name, bytes] of Object.entries(argument.files)) {
        runtime.FS.writeFile('/model/' + name, bytes);
      }
      recognizer = createOnlineRecognizer(runtime, {
        featConfig: {sampleRate: 16000, featureDim: 80},
        modelConfig: {
          transducer: {encoder: '/model/encoder-epoch-99-avg-1.int8.onnx',
            decoder: '/model/decoder-epoch-99-avg-1.onnx',
            joiner: '/model/joiner-epoch-99-avg-1.int8.onnx'},
          paraformer: {encoder: '', decoder: ''}, zipformer2Ctc: {model: ''},
          nemoCtc: {model: ''}, toneCtc: {model: ''}, tokens: '/model/tokens.txt',
          numThreads: 2, provider: 'cpu', debug: 0, modelType: '',
          modelingUnit: '', bpeVocab: ''
        },
        decodingMethod: 'greedy_search', maxActivePaths: 4, enableEndpoint: 0,
        rule1MinTrailingSilence: 2.4, rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20, hotwordsFile: '', hotwordsScore: 1.5,
        ctcFstDecoderConfig: {graph: '', maxActive: 3000}, ruleFsts: '', ruleFars: ''
      });
      if (!recognizer.handle) throw Error('Model initialization failed');
    } else if (method === 'start') {
      if (stream) stream.free();
      stream = recognizer.createStream(); previous = '';
    } else if (method === 'audio' || method === 'finish') {
      stream.acceptWaveform(16000, method === 'finish' ? new Float32Array(12800) : argument);
      if (method === 'finish') stream.inputFinished();
      while (recognizer.isReady(stream)) recognizer.decode(stream);
      const text = recognizer.getResult(stream).text;
      if (text !== previous || method === 'finish') {
        previous = text;
        postMessage({kind: 'result', text, final: method === 'finish'});
      }
      if (method === 'finish') {stream.free(); stream = null;}
    } else if (method === 'cancel') {
      if (stream) stream.free(); stream = null;
    } else if (method === 'close') {
      if (stream) stream.free(); stream = null;
      if (recognizer) recognizer.free(); recognizer = null;
    }
    postMessage({kind: 'ok', id});
  } catch (_) {postMessage({kind: 'error', id});}
}
