import sys

def audit(event, args):
    print(f'audit: {event} with args={args}')

sys.addaudithook(audit)
del audit

import os

# Reorder sys,path so we can import the real logging module.
mydir = os.path.dirname(__file__)
sys.path.remove(mydir)
sys.path.append(mydir)
del mydir

# Import everything from the real logging module.
sys.modules.pop("logging")
from logging import *
