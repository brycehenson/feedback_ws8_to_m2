import socket,sys,os
import ctypes as ct #ctypes is cool!
import time



wlmLib=ct.windll.wlmData

adouble=ct.c_double(5.0)
zerolong=ct.c_long(0)
onelong=ct.c_long(1)
threelong=ct.c_long(3)
cMax2=threelong
cMin2=onelong
GetWavelength=wlmLib.GetWavelength
GetWavelength.restype=ct.c_double; 
GetWavelength.argtypes=[ct.c_double]; #not strictly neccessary, 
                    #just gets python to check function arguments to 
                    #avoid erros
GetTemperature=wlmLib.GetTemperature
GetTemperature.restype=ct.c_double; 
GetTemperature.argtypes=[ct.c_double];

GetAmplitude=wlmLib.GetAmplitudeNum
GetAmplitude.restype=ct.c_long; 
GetAmplitude.argtypes=[ct.c_long, ct.c_long, ct.c_long];

def main():

    ls = socket.socket(socket.AF_INET,socket.SOCK_STREAM);
    port = 49990 #int(sys.argv[1])
    ls.bind(('', port))

    while (1):
        ls.listen(1)
        print "listening on port ", port;
        (conn, addr) = ls.accept()
        print 'connection from client at', addr
        # get w or ps command from client
        flo = conn.makefile('rw',0) # read-write, unbuffered
        #rc = conn.recv(3)
        rc=flo.readline()
        rc=rc[:-1]
        print 'received: ', rc
        
        if rc=='Wavelength?':
            waveLength=GetWavelength(adouble)
            timeStamp = time.clock()
            minPeak=GetAmplitude(onelong,cMin2,zerolong)
            maxPeak=GetAmplitude(onelong,cMax2,zerolong)
            print "sending: ", waveLength
            flo.writelines(str(waveLength)+' '+str(timeStamp)+' '+str(minPeak)+' '+str(maxPeak))
        else:
            try:
                retval=eval(rc+'(adouble)')
                print "sending: ", retval
                flo.writelines(str(retval))
            except:
                reply="You sent: "+rc+" when I expected: 'Wavelength?'\n Also, don't forget the \\n"
                flo.writelines(reply+'\n')
        # write the lines to the network
        
        # clean up
        # must close both the socket and the wrapper
        flo.close()
        conn.close()

if __name__ == '__main__':
    main()