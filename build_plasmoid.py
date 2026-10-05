import json
import os
import subprocess
import zipfile
from pathlib import Path

def main():
    root_dir = Path(__file__).resolve().parent
    os.chdir(root_dir)

    # 1. Execute translate/build.sh
    subprocess.run(["bash", "translate/build.sh"], check=True)

    # Read version
    with open('package/metadata.json', 'r') as f:
        meta = json.load(f)
        version = meta['KPlugin']['Version']

    dist_dir = root_dir / 'dist'
    dist_dir.mkdir(exist_ok=True)
    plasmoid_path = dist_dir / f"aiusage-{version}.plasmoid"

    # 2 & 3. Zip package/ contents
    package_dir = root_dir / 'package'
    
    with zipfile.ZipFile(plasmoid_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for foldername, subfolders, filenames in os.walk(package_dir):
            # Exclude __pycache__
            if '__pycache__' in subfolders:
                subfolders.remove('__pycache__')
            
            for filename in filenames:
                if filename.endswith('.pyc') or filename.endswith('.tmp') or filename.endswith('.lock'):
                    continue
                    
                file_path = Path(foldername) / filename
                arcname = file_path.relative_to(package_dir)
                zipf.write(file_path, arcname)

    print(f"Created {plasmoid_path}")

if __name__ == '__main__':
    main()
