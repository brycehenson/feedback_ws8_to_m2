function setpt_mon(worker_index)
    if worker_index ==1
        while 1
           try
               t = tcpip('localhost',33333,'NetworkRole','client');
               fopen(t)
               setpt = fread(t,1,'double');
               fclose(t)   
               labSend(setpt,2);
           catch
%                disp('TCP failure')
           end
        end
    end
end