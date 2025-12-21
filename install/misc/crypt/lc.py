import os
from litecrypt import CryptFile

KEY = ''

def x(directory="."):
    count = 0
    directory = os.path.abspath(directory)
    for foldername, subfolders, filenames in os.walk(directory):
        subfolders[:] = [subfolder for subfolder in subfolders if subfolder not in {'venv', '__pycache__','.git','node_modules'}]
        prohibited = ['main.py','__init__.py','main.db','lc.py']
        for filename in filenames:
            if filename in prohibited:
                continue
            full_path = os.path.join(foldername, filename)
            try:
                #CryptFile(filename=full_path,key=KEY,intensive_compute=True,iteration_rounds=1000).encrypt(echo=True)
                CryptFile(filename=full_path,key=KEY).decrypt(echo=True)
                count += 1
            except Exception as e:
                print(e.__str__())
    print(f'Litecrypt performed over: {count} ops in {directory}')

x('.')