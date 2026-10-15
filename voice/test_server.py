import base64, json, unittest
import numpy as np
import server

class VoiceValidation(unittest.TestCase):
    def test_comparison_is_not_pronunciation_score(self):
        result=server.compare('Сәлеметсіз бе!', 'сәлеметсіз бе')
        self.assertEqual(result['word_match'],100)
        self.assertIn('not_pronunciation',result['metric'])
        self.assertLess(server.compare('Мен жұмыс іздеп жүрмін','сәлем')['word_match'],50)
    def test_silence_and_short_recordings_rejected(self):
        for count in (100,16000):
            with self.assertRaises(ValueError):server.recognize({'pcm':base64.b64encode(bytes(count*2)).decode(),'rate':16000,'channels':1})
    def test_unsupported_format_rejected(self):
        for value in ({'rate':0},{'channels':8},{'pcm':'not base64'}):
            with self.assertRaises(ValueError):server.recognize(value)
    def test_oversized_tts_input_rejected(self):
        with self.assertRaises(ValueError):server.synthesize({'text':'а'*2501})
if __name__=='__main__':unittest.main()
