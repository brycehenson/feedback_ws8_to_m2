%this is the wavemeter feedback program, it will poll the input every few ms
% it must be non blocking

wait_time=0.1;

while true
    time_a=tic;
    try
    %%
    %t=tcpclient('localhost',33333, 'ConnectTimeout', 1,'Timeout',0.1);
    t = tcpip('localhost',33333,'NetworkRole','client');
    fopen(t)
    setpt = fread(t,0.1,'double');
    fclose(t)  
    fprintf('output %.6f\n',setpt)
    catch
    end
    pause(wait_time)
    fprintf('delay time %f\n',toc(time_a)-wait_time)
end

%%

wait_time=0.1;


t = tcpip('localhost',33333,'NetworkRole','client');
fopen(t)
t.ReadAsyncMode = 'continuous';
while true
    time_a=tic;
    try
    %%
    %t=tcpclient('localhost',33333, 'ConnectTimeout', 1,'Timeout',0.1);
    
    setpt = fread(t,0.1,'double');
    fclose(t)  
    fprintf('output %.6f\n',setpt)
    catch
    end
    pause(wait_time)
    fprintf('delay time %f\n',toc(time_a)-wait_time)
end


%ARRGG it will only work if the server/client constantly exists
%%
fclose('all')

