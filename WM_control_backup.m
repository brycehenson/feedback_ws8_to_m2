function ret = WM_control(method_key)
    if method_key ==1 %Simulates the run counter
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
       ret = 0;
    elseif method_key==2 %feedback loop!
        
        %START USER OPTIONS
        %%control params
        ecd_relock_thresh=0.5;
        res_lims_dscaled=[5,95]; %limits as dac output range 0-100
        res_slow=0.5;
        k_int=-3e-4;
        k_prop=-2e-5;
        k_aw_rate=0.5;
        int_lim=5;
        slew_lim_dscaled=4; %dac/s max slew rate
        setpt=362875400; %min freq in scan 
        %END USER OPTIONS
        

        %intialize connection
        handle=WLM.getInstance();
        solstis_clearBuffer()
        solstis=solstis_findInstrument;
        %~,solstis]=solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50))
        solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}',[])
        reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
        reply=jsondecode(reply);
        status=reply.message.parameters;
        res_voltage=status.resonator_voltage;
        %rescale the reading in volts to the control voltage in %
        res_slow_dac=polyval([0.00000006007743282452 -0.00002630543053390512 0.00404787545023589396 0.27097607207749069280 3.44975464072533588578 ],res_voltage);
        query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%3.10f]}}}',res_slow_dac);
        solstis_query(query,[]);

       
        %intialize feedback
        integrator=res_slow_dac/100;
        %%initalization
        slew_lim_uscaled=slew_lim_dscaled/100;
        res_lims_uscaled=res_lims_dscaled/100;
        err=0;
        di=0;
        ctr_hist=res_slow_dac/100; %given in dac output 0-100
        n=1;
        aw_slew=0;
        %initalize timer
        
        tic;
        t1=toc;
        pause(1e-3)
        t2=toc;
        loop_time=t2-t1;
        %open the log file
        fclose('all')
        flog=fopen('wmlog.txt','a');
        %intialize aw function
        logist=@(x) 1./(1+exp(-x));
        aw_thresh_range=0.01; %how far away from the edge aw starts (full range 0-1)
        aw_fun_range=@(x,y) (logist((x-aw_thresh_range)*10/aw_thresh_range))*(y>0)+(1-logist((x-1+aw_thresh_range)*10/aw_thresh_range))*(y<0);
        n=1;
        while true
            %Check for new set point
            try
                switch labProbe(1)
                    case 1
                        data = labReceive(1);
                        if data ~=setpt
                            disp(['Data received, ',num2str(data)])
                            setpt = data;
                        else
                            disp('Data received, no change')
                        end
                    otherwise
%                        disp('No signal')
                end
            catch
                %disp('Transmission error')
            end
            %get set point from server
            freq=handle.GetFreq(1);
            err=freq-setpt;
            di=k_int*loop_time*err;
            di=di*aw_fun_range((res_slow-res_lims_uscaled(1))/range(res_lims_uscaled),err); %slew anti windup * actuator range anti windup
            integrator=integrator+di;%+aw_slew*k_aw_rate;
            integrator=min(max(-int_lim,integrator),int_lim);
            res_slow=integrator+k_prop*err;%-aw_rate*k_aw_rate);

            %slew limit
            slew=(ctr_hist-res_slow)/(loop_time);
            if abs(slew/slew_lim_uscaled)>1
                integrator=ctr_hist-slew_lim_uscaled*sign(slew)*loop_time-k_prop*err;
                aw_slew=1;
            else
                aw_slew=0;
            end
            %recalc output
            %integrator=integrator+aw_slew;
            integrator=min(max(-int_lim,integrator),int_lim);
            res_slow=integrator+k_prop*err;%-aw_rate*k_aw_rate);
            slew=(ctr_hist-res_slow)/(loop_time);
            ctr_hist=res_slow;
            res_slow_dscaled=res_slow*100;
            res_slow_dscaled=min(max(res_lims_dscaled(1),res_slow_dscaled),res_lims_dscaled(2));
            logstring=sprintf('set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %03.1f Int %+01.2f Dint %+01.3f slew %+02.2f slewlim %1i\n',...
                [setpt,err,res_slow_dscaled,1/loop_time,integrator,di,slew*100,aw_slew]);
            fprintf(logstring)
            fprintf(flog,logstring);
            %Send the resonator tune comand               
            query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',res_slow_dscaled);
            solstis_query(query,solstis);

            if true
                unlock=true;
                while unlock
                    response=jsondecode(solstis_query('{"message":{"transmission_id":[2],"op":"read_all_adc"}}',solstis));
                    ecd_voltage=response.message.parameters.value10;
                    if ecd_voltage<ecd_relock_thresh
                        fprintf('\n need relock... unlocking...\n')
                        query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"off","report":"finished"}}}');
                        solstis_query(query,solstis)
                        pause(0.1)
                        solstis_getResponse(solstis)

                        query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"on","report":"finished"}}}');
                        solstis_query(query,solstis)
                         pause(1)
                        solstis_getResponse(solstis)
                        fprintf('\nlocking...\n') 
                        pause(5)
                    else
                        unlock=false;
                    end
                end
            end
            n=n+1;
            t2=toc;
            loop_time=t2-t1;
            pause(10e-3-loop_time) %have to slow down or the controller will crash
            t2=toc;
            loop_time=t2-t1;
            t1=t2;
%              toc;
        end%feedback loop

        solstis = instrfind('tag','solstis');
        delete(solstis)
        ret=0;

    else
        ret = 0;
    end
end


 %%
        %solstis_query('{"message":{"transmission_id":[2],"op":"ping","parameters":{"text_in":"LetsDoThis"}}}')
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[0]}}}');
        %pause(0.5)
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[100]}}}');
        %pause(0.5)
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[50]}}}')

