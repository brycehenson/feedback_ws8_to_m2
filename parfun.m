function ret = parfun()
%     if method_key ==1 %Simulates the run counter
       while 1
           try
               t = tcpip('localhost',33333,'NetworkRole','client');
               fopen(t)
               setpt = fread(t,1,'double');
               fclose(t)   
%                labSend(setpt,2);
               send(setpt)
           catch
%                disp('TCP failure')
           end
       end
       ret = 0;
%     else %Simulates the feedback loop!
%         tic
%         try
%             switch labProbe(1)
%                 case 1
%                     data = labReceive(1);
%                     if data ~=setpt
%                         disp(['Data received, ',num2str(data)])
%                         setpt = data;
%                         send(setpt);
%                     else
%                         disp('Data received, no change')
%                     end
%                     toc
%                     tic
%                 otherwise
% %                        disp('No signal')
%             end
%         catch
%             disp('Transmission error')
%         end
%     end
%     ret=0;
end

