from litecrypt.core.filecrypt import CryptFile

with open(".key") as f:
    key = f.read()

CryptFile(key=key,filename="ngrok.yaml").encrypt(echo=True)
