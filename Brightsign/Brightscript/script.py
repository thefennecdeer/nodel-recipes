'''
**Brightsign Node** <sup>v2.1</sup> 

Requires the [Nodel Brightsign Plugin](https://github.com/museumsvictoria/nodel-recipes/tree/master/Brightsign)

---

Monitors state of Brightsign, and allows remote control of Playback, Muting, and Sleep.

Sleep is the Brightsign's native 'Powersaving' mode, which disables all video and audio outputs and pauses playbacks, allowing screens to enter powersaving mode.

'''
### -------------------- SETUP -------------------- ###
import socket
import org.nodel.discovery.TopologyWatcher
from inputHandler import *
### -------------------- PARAMETERS AND VARIABLES -------------------- ###

param_playerIP = Parameter({'title': 'Brightsign IP Address', 'order': next_seq(), 'schema': {'type': 'string', 'hint': '192.168.1.10'}})

param_overrides = Parameter({'title': 'Overrides', 'order': next_seq(), 'schema': {'type': 'object', 'properties': {
           'playerOverride': {'title': 'Brightsign Overrides', 'type': 'object', 'order': 1, 'properties': {
              'scriptPort': {'title': 'Script Port', 'type': 'string', 'hint': '8081', 'order': 1},
              'udpPort': {'title': 'UDP Port', 'type': 'integer', 'hint': '5000', 'order': 2}
            }},
           'nodeOverride': {'title': 'Node Overrides', 'type': 'object', 'order': 2, 'properties': {
              'ipAddress': {'title': "Node's UDP Listen Port", 'type': 'string', 'hint': '192.168.1.10', 'order': 1},
              'udpPort': {'title': "Node's UDP Listen Port", 'type': 'integer', 'hint': '5000', 'order': 3}
            }}
        }}})


scriptPort = "8081"
udpPort = 5000
ipAddress = ""
fullAddress = ""
status_check_interval = 15

udpListenPort = ""
udpListenAddress = ""
udpListenReady = False

### -------------------- EVENTS -------------------- ###

local_event_Power = LocalEvent({'group': 'Power', 'schema': {'type': 'string', 'enum': ['On', 'Off']},
                                'desc': 'Power State'})
local_event_DesiredPower = LocalEvent({'group': 'Power', 'schema': {'type': 'string', 'enum': ['On', 'Off']},
                                'desc': 'Desired Power State'})
# <Brightsign

local_event_CurrentClip = LocalEvent({'title':'Current Clip', 'order': next_seq(), 'schema': { 'type': 'string' }})

local_event_Serial = LocalEvent({'order': next_seq(), 'schema': { 'type': 'string' }})
                                
local_event_Volume = LocalEvent({'order': next_seq(), 'schema': { 'type': 'string' }})
                                
local_event_Model = LocalEvent({'order': next_seq(), 'schema': { 'type': 'string' }})
                                
local_event_VideoMode = LocalEvent({'group': 'Playback', 'order': next_seq(), 'schema': { 'type': 'string' }})
                                
local_event_Mute = LocalEvent({'group': 'Volume', 'order': next_seq(),'schema': {'type': 'string', 'enum': ['On', 'Off']},
                                'desc': 'Mute State'})

local_event_Playback = LocalEvent({'group': 'Playback', 'order': next_seq(),'schema': {'type': 'string'},
                                'desc': 'Playback State'})

local_event_DesiredPlayback = LocalEvent({'group': 'Playback', 'order': next_seq(),'schema': {'type': 'string'},
                                'desc': 'Desired Playback State'})

local_event_Playlist = LocalEvent({'group': 'Playlist', 'order': next_seq(),'schema': {'type': 'object', 'properties': {
                                      'name': {'type': 'string', 'order': 1}}}})

local_event_DesiredMute = LocalEvent({'group': 'Volume', 'order': next_seq(),'schema': {'type': 'string', 'enum': ['On', 'Off']},
                                'desc': 'Desired Mute State'})  
# Brightsign/>

# <Networking
local_event_UDPListenPort = LocalEvent({'group': 'Networking','order': next_seq(), 'schema': { 'type': 'string' }})
# Networking/>

### -------------------- ACTIONS -------------------- ###

# <Power
@local_action({'group': 'Power', 'order': next_seq(), 'schema': {'type': 'string', 'enum': ['On', 'Off']}})           
def Power(arg):
  if arg == "On":
    lookup_local_event('DesiredPower').emit("On")
    sendGet("/playback?sleep=false")
  elif arg == "Off":
    lookup_local_event('DesiredPower').emit("Off")
    sendGet("/playback?sleep=true")

@local_action({'group': 'Power', 'title': 'On', 'order': next_seq()})  
def Wake(arg = None):
  lookup_local_action("Power").call("On")

@local_action({'group': 'Power', 'title': 'Off', 'order': next_seq()})  
def Sleep(arg = None):
  lookup_local_action("Power").call("Off")
# Power/>

# <Playback
@local_action({'group': 'Playback', 'title': 'Play', 'order': 1})  
def Play(arg = None):
  lookup_local_event('DesiredPlayback').emit("Playing")
  sendGet("/playback?playback=play")

@local_action({'group': 'Playback', 'title': 'Pause', 'order': 2})  
def Pause(arg = None):
  lookup_local_event('DesiredPlayback').emit("Paused")
  sendGet("/playback?playback=pause")
# Playback/>

# <Volume
@local_action({ 'title': 'Volume', 'order': next_seq(), 'schema': { 'type': 'integer', 'hint': '(0 - 100%)' }})
def Volume(arg):
    if arg == None or arg < 0 or arg > 100:
      console.warn('Volume: no arg or outside 0 - 100')
      return
    sendGet("/volume?%s" % arg)

@local_action({'group': 'Power', 'title': 'Reboot', 'order': next_seq()})  
def Reboot(arg = None):
  console.log("Sending Reboot")
  sendGet("/reboot?reboot=true")

@local_action({'group': 'Volume', 'title': 'Mute', 'order': next_seq(), 'schema': {'type': 'string', 'enum': ['On', 'Off']}})  
def Mute(arg):
  if arg == "On":
    local_event_DesiredMute.emit("On")
    sendGet("/mute?mute")

  elif arg == "Off":
    local_event_DesiredMute.emit("Off")
    sendGet("/mute?unmute")

@local_action({'group': 'Volume', 'title': 'Mute On', 'order': next_seq()})
def MuteOn():
  Mute.call('On')
  
@local_action({'group': 'Volume', 'title': 'Mute Off', 'order': next_seq()})
def MuteOff():
  Mute.call('Off')  
# Volume/>

@local_action({'group': 'Status', 'title': 'Get Status', 'order': next_seq()})
def GetStatus():
  playerStatusGet()

### -------------------- MAIN FUNCTIONS -------------------- ###
  
def recv_handler(source, data):
  json = json_decode(data)
  #console.log(json)
  if "customaction" in json["event"]:
    emit_custom_event(json)
  if "button" in json["event"]:
    handlePress(json)
  if "media start" in json["event"]:
    local_event_CurrentClip.emit(json["file"])

def emit_custom_event(json):
  event = lookup_local_event("Show %s" % json["name"])
  if event == None:
    create_local_event('Show %s' % json["name"], {'group': 'Show Events', 'order': next_seq(), 'schema': {'type': 'string'}}) 

  if json["arg"]:
    event.emit(json["arg"])
  else:
    event.emit()
  

def send_udp_string(msg):
  console.info('Sent: %s' % msg)
  transmit.emit(msg)

def sendGet(value):
  global fullAddress
  try: 
    resp = get_url(fullAddress + value, fullResponse=True)
    playerStatusGet()
  except: 
    console.error("Failed to Connect")
  else:
    global _lastReceive
    _lastReceive = system_clock()
    if resp.statusCode != 200:
      console.error("Failed to send.")

def send_udp_string(msg):
  #open socket
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  try:
    sock.sendto(msg, (ipAddress, udpPort))
  except socket.error, msg:
    print "error: %s\n" % msg
    local_event_Error.emit(msg)
  finally:
    if sock:
      sock.close()
      
def playerStatusGet():
  global fullAddress
  try:
    resp = get_url(fullAddress + "/status", method='GET', contentType='application/json', fullResponse=True)
  except:
    pass
  else:
    if resp.statusCode != 200:
      console.error("Failed to connect")
    else:
      global _lastReceive
      _lastReceive = system_clock()
      status_decode = json_decode(resp.content)
      lookup_local_event('Model').emit(status_decode['model'])
      lookup_local_event('Volume').emit(status_decode['volume'])
      lookup_local_event('Serial').emit(status_decode['serialNumber'])
      lookup_local_event('VideoMode').emit(status_decode['videomode'])
      lookup_local_event('volume').emit(status_decode['volume'])

      if status_decode['playlist'] == "true":
        playlist = list()
        for item in status_decode['playlist']:
          playlist.append({'name': item})
        lookup_local_event('Playlist').emit(playlist)

      if status_decode['sleep'] == "true":
        lookup_local_event('Power').emit('Off')
        if lookup_local_event('DesiredPower').getArg() == "On":
          lookup_local_action("Sleep").call()
      elif status_decode['sleep'] == "false":
        lookup_local_event('Power').emit('On')
        if lookup_local_event('DesiredPower').getArg() == "Off":
          lookup_local_action("Wake").call()

      if status_decode['playing'] == "true" :
        lookup_local_event('Playback').emit('Playing')
        if lookup_local_event('DesiredPlayback').getArg() == "Paused":
          lookup_local_action("Pause").call()
      elif status_decode['playing'] == "false":
        lookup_local_event('Playback').emit('Paused')
        if lookup_local_event('DesiredPlayback').getArg() == "Playing":
          lookup_local_action("Play").call()

      if status_decode['muted'] == "true":
        lookup_local_event('Mute').emit('On')
        if lookup_local_event('DesiredMute').getArg() == "Off":
          lookup_local_action("Mute").call("Off")
      elif status_decode['muted'] == "false":
        lookup_local_event('Mute').emit('Off')
        if lookup_local_event('DesiredMute').getArg() == "On":
          lookup_local_action("Mute").call("On")

def subscribe():
  global udpListenPort, udpListenAddress, udpListenReady
  if udpListenReady:
    sendGet("/subscribe?address=%s&port=%s" % (udpListenAddress, udpListenPort))

def udp_ready():
  global udpListenReady
  udpListenReady = True
  grabUDPListenDetails()
  subscribe()

def grabUDPListenDetails():
  global udpListenPort
  udpListenPort = str(udp.getListeningPort())
  lookup_local_event("UDPListenPort").emit(udpListenPort)
  console.info('UDP Ready, listening on port %s!' % udpListenPort)

udp = UDP(source = None,
          dest = None,
          ready=udp_ready,
          received=recv_handler,
          sent=lambda message: console.info('Sent: %s' % message) )

# Script Entrypoint
def main(arg = None):
  global ipAddress, scriptPort, udpPort, fullAddress, udpListenAddress, udpListenPort
  if is_blank(param_playerIP):
    console.error('No Address has been specified, nothing to do!')
    return
  else:
    ipAddress = param_playerIP

  playerOverrides = (param_overrides or {}).get('playerOverride')
  nodeOverrides = (param_overrides or {}).get('nodeOverride')
  scriptPort = (playerOverrides or {}).get('scriptPort') or scriptPort
  udpPort = (playerOverrides or {}).get('udpPort') or udpPort

  udpListenAddress = (playerOverrides or {}).get('ipAddress') or udpListenAddress
  udpListenPort = (playerOverrides or {}).get('udpPort') or udpListenPort

  fullAddress = "http://%s:%s" % (ipAddress, scriptPort)

  old_port = local_event_UDPListenPort.getArg()
  if len(old_port or '') == 0:
    if len(udpListenPort or '') != 0:
      old_port = udpListenPort
    else:
      console.info("Grabbing new available port!")
      old_port = '0'

  if len(udpListenAddress or '') == 0:
    udpListenAddress = org.nodel.discovery.TopologyWatcher.shared().getIPAddresses()[0]
    
  udp.source = udpListenAddress + ':' + old_port

  console.log("Brightsign script started.")


### -------------------- STATUS AND MONITORING -------------------- ###

# <status and error reporting ---

# for comms drop-out
_lastReceive = 0

# roughly, the last contact  
local_event_LastContactDetect = LocalEvent({'group': 'Status', 'order': 99999+next_seq(), 'title': 'Last contact detect', 'schema': {'type': 'string'}})

# node status
local_event_Status = LocalEvent({'group': 'Status', 'order': 99999+next_seq(), 'schema': {'type': 'object', 'properties': {
        'level': {'type': 'integer', 'order': 1},
        'message': {'type': 'string', 'order': 2}}}})
  
def nodeStatusCheck():
  diff = (system_clock() - _lastReceive)/1000.0 # (in secs)
  now = date_now()
  
  if diff > status_check_interval+15:
    previousContactValue = local_event_LastContactDetect.getArg()
    
    if previousContactValue == None:
      message = 'Always been missing.'
      
    else:
      previousContact = date_parse(previousContactValue)
      roughDiff = (now.getMillis() - previousContact.getMillis())/1000/60
      if roughDiff < 60:
        message = 'Missing for approx. %s mins' % roughDiff
      elif roughDiff < (60*24):
        message = 'Missing since %s' % previousContact.toString('h:mm a')
      else:
        message = 'Missing since %s' % previousContact.toString('h:mm a, E d-MMM')
      
    local_event_Status.emit({'level': 2, 'message': message})
    
  else:
    # update contact info
    local_event_LastContactDetect.emit(str(now))
    
    # TODO: check internal device status if possible

    local_event_LastContactDetect.emit(str(now))
    local_event_Status.emit({'level': 0, 'message': 'OK'})

# --->

playerStatus_timer = Timer(playerStatusGet, status_check_interval)
nodeStatus_timer = Timer(nodeStatusCheck, status_check_interval)

# <!-- logging

local_event_LogLevel = LocalEvent({'group': 'Debug', 'order': 10000, 'desc': 'Use this to ramp up the logging (with indentation)',  
                                   'schema': {'type': 'integer'}})

def warn(level, msg):
  if (local_event_LogLevel.getArg() or 0) >= level:
    console.warn(('  ' * level) + msg)

def log(level, msg):
  if (local_event_LogLevel.getArg() or 0) >= level:
    console.log(('  ' * level) + msg)

# --!>

# <--- convenience functions

# Converts into a brief time relative to now
def toBriefTime(dateTime):
  now = date_now()
  nowMillis = now.getMillis()

  diff = (nowMillis - dateTime.getMillis()) / 60000 # in minutes
  
  if diff == 0:
    return '<1 min ago'
  
  elif diff < 60:
    return '%s mins ago' % diff

  elif diff < 24*60:
    return dateTime.toString('h:mm:ss a')

  elif diff < 365 * 24*60:
    return dateTime.toString('h:mm:ss a, E d-MMM')

  elif diff > 10 * 365*24*60:
    return 'never'
    
  else:
    return '>1 year'

# Decodes a typical process arg list string into an array of strings allowing for
# limited escaping or quoting or both.
#
# For example, turns:
#    --name "Peter Parker" --character Spider\ Man

# into:
#    ['--name', '"Peter Parker"', '--character', 'Spider Man']   (Python list)
#
def decodeArgList(argsString):
  argsList = list()
  
  escaping = False
  quoting = False
  
  currentArg = list()
  
  for c in argsString:
    if escaping:
      escaping = False

      if c == ' ' or c == '"': # put these away immediately (space-delimiter or quote)
        currentArg.append(c)
        continue      
      
    if c == '\\':
      escaping = True
      continue
      
    # not escaping or dealt with special characters, can deal with any char now
    
    if c == ' ': # delimeter?
      if not quoting: 
        # hit the space delimeter (outside of quotes)
        if len(currentArg) > 0:
          argsList.append(''.join(currentArg))
          del currentArg[:]
          continue

    if c == ' ' and len(currentArg) == 0: # don't fill up with spaces
      pass
    else:
      currentArg.append(c)
    
    if c == '"': # quoting?
      if quoting: # close quote
        quoting = False
        argsList.append(''.join(currentArg))
        del currentArg[:]
        continue
        
      else:
        quoting = True # open quote
  
  if len(currentArg) > 0:
      argsList.append(''.join(currentArg))

  return argsList

# convenience --->
