import shutil
import sys
from pathlib import Path

src_path = Path(sys.argv[1])
dst_path = Path(sys.argv[2])  
shutil.copytree(src_path, dst_path)
