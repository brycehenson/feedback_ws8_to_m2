#~ 1 # wps.py
#~ 2
#~ 3 # client for the server for remote versions of the w and ps commands
#~ 4
#~ 5 # user can check load on machine without logging in (or even without
#~ 6 # having an account on the remote machine)
#~ 7
#~ 8 # usage:
#~ 9
#~ 10 # python wps.py remotehostname port_num {w,ps}
#~ 11
#~ 12 # e.g. python wps.py nimbus.org 8888 w would cause the server at
#~ 13 # nimbus.org on port 8888 to run the UNIX w command there, and send the
#~ 14 # output of the command back to the client here

import socket,sys

portNum=49990

def getWavelength():

    s = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    host = '150.203.186.119'#sys.argv[1]
    port = portNum #int(sys.argv[2])
    s.connect((host,port))

    # send w or ps command to server
    #s.send(sys.argv[3])
    s.send('Wavelength?\n')
    # create "file-like object" flo
    flo = s.makefile('r',0) # read-only, unbuffered
    # now can call readlines() on flo, and also use the fact that
    # that stdout is a file-like object too
    #print "received: "
    data=''
    data=flo.readline()
    print 'string data gotten was: ', data
    waveLength=float(data.split(' ')[0]);# wavemeter sends a bunch of values, only want wavelength
    return waveLength

def getTemperature():

    s = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    host = '192.168.0.161'#sys.argv[1]
    port = portNum#int(sys.argv[2])
    s.connect((host,port))

    # send w or ps command to server
    #s.send(sys.argv[3])
    s.send('GetTemperature\n')
    # create "file-like object" flo
    flo = s.makefile('r',0) # read-only, unbuffered
    # now can call readlines() on flo, and also use the fact that
    # that stdout is a file-like object too
    #print "received: "
    data=''
    data=flo.readline()
    print 'string data gotten was: ', data
    d
    waveLength=float(data);
    return waveLength


if __name__ == '__main__':
    print "received wavelength of ", getWavelength()

