# Credits

## Local Kazakh speech

- Vosk small Kazakh 0.42, Alpha Cephei — Apache 2.0. Model: https://alphacephei.com/vosk/models/vosk-model-small-kz-0.42.zip ; engine: https://github.com/alphacep/vosk-api
- Piper kk_KZ-issai-high — trained on ISSAI KazakhTTS / KazakhTTS2 (CC BY 4.0); authors/dataset: https://github.com/IS2AI/Kazakh_TTS ; voice model card: https://huggingface.co/rhasspy/piper-voices/blob/main/kk/kk_KZ/issai/high/MODEL_CARD . Six existing synthetic speaker voices; no custom voice cloning. Card copied to `voice/ISSAI_MODEL_CARD`.
- ONNX package/conversion and runtime: sherpa-onnx (Apache 2.0), https://github.com/k2-fsa/sherpa-onnx ; model package: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-kk_KZ-issai-high.tar.bz2 . Packaged espeak-ng-data carries the upstream eSpeak NG GPL licensing; retain its upstream notices when redistributing.
