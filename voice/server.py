"""Loopback-only Kazakh STT/TTS. No microphone capture here and no cloud calls."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse, base64, io, json, threading, time, wave, re
import numpy as np
import vosk, sherpa_onnx

ROOT = Path(__file__).resolve().parent
LOCK = threading.Lock()
ASR = None
TTS = None
LAST_USE = time.monotonic()

def load_models():
    global ASR, TTS
    vosk.SetLogLevel(-1)
    ASR = vosk.Model(str(ROOT / 'models/vosk-model-small-kz-0.42'))
    folder = ROOT / 'models/vits-piper-kk_KZ-issai-high'
    config = sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
        vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(folder/'kk_KZ-issai-high.onnx'),
        tokens=str(folder/'tokens.txt'), data_dir=str(folder/'espeak-ng-data')), num_threads=2), max_num_sentences=2)
    if not config.validate():
        raise RuntimeError('TTS configuration is invalid')
    TTS = sherpa_onnx.OfflineTts(config)

def normalize(text):
    return re.findall(r"[а-яәғқңөұүһіё]+", text.lower())

def compare(expected, actual):
    a, b = normalize(expected), normalize(actual)
    row = list(range(len(b)+1))
    for i, word in enumerate(a, 1):
        following = [i]
        for j, other in enumerate(b, 1):
            following.append(min(following[-1]+1, row[j]+1, row[j-1]+(word!=other)))
        row = following
    return {'word_match': round(max(0, 1-row[-1]/max(len(a),len(b),1))*100),
            'expected': expected, 'recognized': actual, 'metric': 'transcript_word_match_not_pronunciation'}

def recognize(data):
    rate, channels = int(data.get('rate',16000)), int(data.get('channels',1))
    if not 8000 <= rate <= 96000 or channels not in (1,2):
        raise ValueError('audio_format')
    raw = base64.b64decode(data.get('pcm',''), validate=True)
    samples = np.frombuffer(raw, dtype='<i2')
    if len(samples)%channels: raise ValueError('audio_format')
    samples = samples.reshape(-1,channels).astype(np.float32).mean(axis=1)
    if not .3 <= len(samples)/rate <= 31: raise ValueError('audio_length')
    if np.sqrt(np.mean(samples**2)) < 65: raise ValueError('silence')
    if rate!=16000:
        samples=np.interp(np.arange(int(len(samples)*16000/rate))*rate/16000, np.arange(len(samples)),samples)
    rec = vosk.KaldiRecognizer(ASR,16000);rec.SetWords(True)
    pcm = np.clip(samples,-32768,32767).astype('<i2').tobytes()
    words=[]
    for offset in range(0,len(pcm),8000):
        if rec.AcceptWaveform(pcm[offset:offset+8000]):words.extend(json.loads(rec.Result()).get('result',[]))
    words.extend(json.loads(rec.FinalResult()).get('result',[]))
    text=' '.join(w['word'] for w in words).strip()
    if not text: raise ValueError('not_recognized')
    result={'text':text,'confidence':sum(w['conf'] for w in words)/len(words),'model_language':'kk'}
    expected=str(data.get('expected',''))[:250]
    if expected: result['practice']=compare(expected,text)
    return result

def synthesize(data):
    text=str(data.get('text','')).strip()
    if not text or len(text)>2500: raise ValueError('text_length')
    sid=max(0,min(int(data.get('speaker',0)),TTS.num_speakers-1))
    output=TTS.generate(text,sid=sid,speed=.95)
    pcm=np.clip(np.asarray(output.samples)*32767,-32768,32767).astype('<i2').tobytes()
    return {'pcm':base64.b64encode(pcm).decode(),'rate':output.sample_rate,'channels':1}

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass  # Never log transcripts or bodies.
    def send_json(self, code, value):
        encoded=json.dumps(value,ensure_ascii=False).encode()
        self.send_response(code);self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Content-Length',str(len(encoded)));self.end_headers()
        try:self.wfile.write(encoded)
        except (BrokenPipeError,ConnectionResetError):pass
    def do_GET(self):
        global LAST_USE
        LAST_USE=time.monotonic()
        if self.path!='/health':return self.send_json(404,{'error':'not_found'})
        self.send_json(200,{'service':'nazerke-kazakh-voice','ready':TTS is not None and ASR is not None})
    def do_POST(self):
        global LAST_USE
        LAST_USE=time.monotonic()
        if self.headers.get('Origin'):return self.send_json(403,{'error':'origin'})
        if self.path not in ('/stt','/tts'):return self.send_json(404,{'error':'not_found'})
        if TTS is None or ASR is None:return self.send_json(503,{'error':'loading'})
        if not LOCK.acquire(False):return self.send_json(503,{'error':'busy'})
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<=9000000:raise ValueError('size')
            data=json.loads(self.rfile.read(size))
            self.send_json(200,recognize(data) if self.path=='/stt' else synthesize(data))
        except (ValueError,TypeError,KeyError):self.send_json(400,{'error':'invalid_or_silent_audio'})
        except Exception as exc:
            print(type(exc).__name__,flush=True);self.send_json(500,{'error':'voice_failed'})
        finally: LOCK.release()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=18765);args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler);server.timeout=2
    worker=threading.Thread(target=load_models,daemon=True);worker.start()
    print('NAZERKE_VOICE_READY_PORT',args.port,flush=True)
    # Exit after 10 minutes without a game/client; launching the next chat restarts us.
    while time.monotonic()-LAST_USE<600:server.handle_request()
    server.server_close()
if __name__=='__main__':main()
