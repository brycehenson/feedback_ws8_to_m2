
addpath(genpath('lib'))
mypool=gcp('nocreate');
createpool=true;
if isprop(mypool,'NumWorkers')
    if mypool.NumWorkers==2 
        createpool=false;
end
end
% parpool(1); delete(gcp);
% myCluster = parcluster('local')
% delete(myCluster.Jobs);
% myCluster.NumWorkers=2;
% myCluster.NumThreads=2;

if createpool
parpool('local',2)
end

warning off instrument:fscanf:unsuccessfulRead
%Note that the parallel pooling within WLM has been disabled.
%This prevent channel-switching in the WLM, but this isn't necessary unless we need Cs ref.

%WM_control creates two jobs: TCP monitor for set point updates, and resonator feedback.
%TCP monitor creates a TCP client and tries to connect to TCP host in LabView Interface.
%When LVI runs, the TCP mon stores the new setpoint and LabSends it to the resonator loop.
%At every loop, the WM feedback probes the other worker for new data and updates setpt.
%Running locally, the WM feedback loop runs for 62+-11 ms (16Hz)

spmd
    r = WM_control(labindex);
end


