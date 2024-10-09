from nodetoolkit import *

@before_main
def initGPIOButtons():
    def init(i):
        create_local_event('GPIO%s' % i, {'group': 'GPIO', 'order': next_seq(), 'schema': {'type': 'boolean'}}) 
    [init(i) for i in [1, 2, 3, 4, 5, 6, 7]]

def handlePress(json):
    lookup_local_event('GPIO%s' % json["gpio"]).emit(str2bool(json["event"]))

def str2bool(value):
    if ("down") in str(value).lower():
        return True
    if ("up") in str(value).lower(): return False
