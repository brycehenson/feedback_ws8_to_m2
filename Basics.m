%basic feedback implementation
%only to fast resonator pzt 
%feedback speed limited to 25hz to prevent crashing the soltis
%good anit-windup using condition integeration which works greattt


handle=WLM.getInstance();
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}')
solstis_query('{"message":{"transmission_id":[2],"op":"ping","parameters":{"text_in":"LetsDoThis"}}}')
solstis_query('{"message":{"transmission_id":[2],"op":"etalon_lock_status"}}')
solstis_query('{"message":{"transmission_id":[2],"op":"read_all_adc"}}')
solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[0]}}}');
pause(0.5)
solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[100]}}}');
pause(0.5)
solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[50]}}}')

%%control params
res_fine=0.5;
k_int=-5e-2;
k_prop=-1e-2;
int_lim=5;

%%initalization
integrator=0.5;
pause(0.5)
freq=handle.GetFreq(1);
setpt=round(freq/10)*10;
err=0;
di=0;


%setpt=373897815;%handle.GetFreq(1)
%initalize timer
tic;
t1=toc;
pause(1e-3)
t2=toc;
loop_time=t2-t1;

logist=@(x) 1./(1+exp(-x));
aw_thresh=0.01; %how far away from the edge aw starts (full range 0-1)
aw_fun=@(x,y) (logist((x-aw_thresh)*10/aw_thresh))*(y>0)+(1-logist((x-1+aw_thresh)*10/aw_thresh))*(y<0);

solstis = solstis_findInstrument();
while true
    freq=handle.GetFreq(1);
    err=freq-setpt;
    di=k_int*loop_time*err;
    di=di*aw_fun(res_fine,err);
    integrator=integrator+di;
    integrator=min(max(-int_lim,integrator),int_lim);
    res_fine=integrator+k_prop*err;
    res_fine_scaled=res_fine*100;
    res_fine_scaled=min(max(0,res_fine_scaled),100);
    fprintf('err %+05.3f MHz Res %02.4f Feedback Freq %03.1f Int %02.4f Dint %02.4f Aw \n',[err,res_fine_scaled,1/loop_time,integrator,di])

    query=sprintf('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[%2.4f]}}}',res_fine_scaled);
        
    t2=toc;
    loop_time=t2-t1;
    pause(10e-3-loop_time) %have to slow down or the controller will crash
    
    t2=toc;
    loop_time=t2-t1;
    t1=t2;
      
    fprintf(solstis,query)
    ret = [];
    while 1
        ret = [ret fscanf(solstis)];
        numOpenBracket = sum(ret=='{');
        numClosedBracket = sum(ret=='}');

        if numOpenBracket>0 && numOpenBracket==numClosedBracket
            break
        end
    end

%     if mod(n,100)==0
%         if mod(n,200)==0
%             setpt=setpt+5;
%         else
%             setpt=setpt-5;
%         end
%     end




end





solstis = instrfind('tag','solstis');
delete(solstis)