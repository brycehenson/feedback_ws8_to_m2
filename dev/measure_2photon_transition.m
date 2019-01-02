%% USER PARAM
hyperfine_transision=4; %F=3 or 4
current_gain=2e7; %V/A

wavemeter_offset=-145.2;
freq_range=8; %the total range to scan over (from -ve freq_range/2 to +ve freq_range/2)
delt_freq=0.09; %MHz
settle_time=0.3;
volt_aq_time=0.5;
extra_pause_end=1;
extra_pause_start=1;
plot_interval=1;

log_dir='Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\';
new_log_interval=60*60*1;


%%
fclose('all')
clear('flog')
hebec_constants

nowt=posixtime(datetime('now'));
%6S–8S  http://dx.doi.org/10.1364/OL.38.003186 %822.4nm
%for other transtion see
%https://doi.org/10.1088/1674-1056/21/11/113701  
%https://doi.org/10.1364/OL.19.001474 %852.3,883
%https://doi.org/10.1143/JPSJ.74.2487 885.4
if hyperfine_transision==3
    transition_freq=364507238.417;
elseif hyperfine_transision==4
    transition_freq=364503080.351;
else
    error('wrong option')
end

freq_cen=transition_freq;
freq_cen=freq_cen+wavemeter_offset; 

fprintf('probe beam set freq %f MHz \n',freq_cen)
t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
fopen(t)
fwrite(t,freq_cen,'double')
fclose(t)

%%
connected_dev=daq.getDevices;
dev_idx=cellfun(@(x) isequal(x,'National Instruments USB-6251'),{connected_dev.Description});
if sum(dev_idx)~=1
    error('somethings broken couldnt find USB-6251')
end
dev_idx=find(dev_idx,1);
connected_dev(dev_idx)
s = daq.createSession('ni');
ch=addAnalogInputChannel(s,connected_dev(dev_idx).ID,4,'Voltage');
% the sampling rate should be set so that it is much slower than the 200us of the transimpedance
% amplifier % 3.7khz low pass filter, 0.5khz is ok
s.Rate = 500;
s.DurationInSeconds=volt_aq_time;
ch.TerminalConfig='SingleEnded';
s.inputSingleScan;

%% Initalize plots
figure(1)
set(gcf,'color','w')
clf
subplot(2,2,1)
[voltage,time] = s.startForeground;
plot_volt_aq=plot(time,voltage,'k.-','LineWidth',1.5,'MarkerSize',20);
title('measuring pmt current')
xlabel('time (s)')
ylabel('PMT Current (nA)')

subplot(2,2,2)
plot_scan_res_mean=plot([nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20);
title('scan response')
xlabel('Probe Set Point-Transition Freq-WM Offset (MHz)')
ylabel('Mean PMT Current (nA)')
xlim([-1,1]*freq_range)

subplot(2,2,4)
plot_scan_res_std=plot([nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20);
title('scan response')
xlabel('Probe Set Point-Transition Freq-WM Offset (MHz)')
ylabel('STD PMT Current (nA)')
xlim([-1,1]*freq_range)
plot_scan_res_fit_mean=plot([],[],'r');
plot_scan_res_fit_std=plot([],[],'r');

subplot(2,2,3)
plot_freq_trend_mean=errorbar([nan],[nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20,'CapSize',0);
hold on
plot_freq_trend_std=errorbar([nan],[nan],[nan],'b.-','LineWidth',1.5,'MarkerSize',20,'CapSize',0);
legend('mean','std')
hold off
title('Trend')
xlabel('Time (s)')
ylabel('Wavemeter Offset(MHz)')
%%

freq_delta=linspace(-freq_range/2,freq_range/2,freq_range/delt_freq)';
time_freq_response=nan(size(freq_delta,1),4);
set(plot_scan_res_mean,'xdata', freq_delta,'ydata', time_freq_response(:,3));
%set(plot_scan_res_mean,'xlim', freq_delta([end,1]));
 set(plot_scan_res_std,'xdata', freq_delta,'ydata', time_freq_response(:,4));
%set(plot_scan_res_std,'xlim', freq_delta([end,1]));



current_gain_disp=current_gain/1e9;
s.inputSingleScan; %initalize
[voltage_aq,time] = s.startForeground;

loz3fun_offset = @(b,x) b(1).*((b(2)/2)^2)./((x-b(3)).^2+(b(2)/2)^2) + b(4); %lorentzian
loz3fun_offset_grad = @(b,x) b(1).*((b(2)/2)^2)./((x-b(3)).^2+(b(2)/2)^2) + b(4)+b(5).*x; %lorentzian
%amp,FWHM,cen,offset,grad
loz3_deriv_fun = @(b,x) b(1).*(16.*(x-b(3))*(b(2)/2))./(pi*(4*(x-b(3)).^2+b(2)^2).^2) + b(4); %derivative of lorentzian
loz3_deriv_abs_fun = @(b,x) b(1).*abs((16.*(x-b(3))*(b(2)/2))./(pi*(4*(x-b(3)).^2+b(2)^2).^2)) + b(4);
loz3_squared_fun = @(b,x) b(1).*(b(2)./((x-b(3)).^2+b(2)^2)).^2 + b(4); %lorentzian squared

jj=1;
freq_fits=[];
log_open_time=-inf;


% main loop
ii=1;
while true
    %try
    time_freq_response=nan(size(freq_delta,1),4);
    %log_open_time
    %log_open_time+new_log_interval-posixtime(datetime('now'))
    %if log_open_time+new_log_interval<posixtime(datetime('now')) %make a new log file
    if ii==1
        log_open_time=posixtime(datetime('now'));
        log_file_str=fullfile(log_dir,sprintf('2p_cs_log_%s.txt',datestr(datetime('now'),'yyyymmddTHHMMSS')));
        if exist('flog','var')
            log=[];
            nowdt=datetime('now');
            log.posix_time=posixtime(nowdt);
            log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
            log.op='new log';
            log.parameters.new_path=log_file_str;
            log_str=sprintf('%s\n',jsonencode(log)); %so that can print to standard out
            fprintf(flog,log_str);
            fclose(flog);
        end
        flog=fopen(log_file_str,'A');      
    end
    fprintf('probe freq scan %04u:%04u',numel(freq_delta),0);
    for jj=1: numel(freq_delta)
        set_freq=freq_cen+freq_delta(jj);
        time_freq_response(jj,2)=set_freq;
        %fprintf('probe beam set freq %f MHz \n',freq)
        %fprintf('probe beam set freq %f MHz \n',freq_delta(jj))
        t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
        fopen(t)
        fwrite(t,set_freq,'double')
        fclose(t)
        pause(settle_time)
        if jj==1
            pause(extra_pause_start)
        end

        [voltage_aq,time] = s.startForeground;
        time_freq_response(jj,1)=posixtime(datetime('now')); 
        if jj~=1
             time_freq_response(jj,1)= time_freq_response(jj,1)- time_freq_response(1,1); %differential encoding of the scan time
        end
        %voltage_now=s.inputSingleScan/current_gain;
        time_freq_response(jj,3)=mean(voltage_aq); 
        time_freq_response(jj,4)=std(voltage_aq); 
        if mod(jj,plot_interval)==0
            set(plot_volt_aq,'xdata', time,'ydata', voltage_aq/current_gain_disp);
            set(plot_scan_res_mean,'xdata', freq_delta,'ydata', time_freq_response(:,3)/current_gain_disp);
            set(plot_scan_res_std,'xdata', freq_delta,'ydata', time_freq_response(:,4)/current_gain_disp);
            drawnow    
        end
        fprintf('\b\b\b\b%04u',jj);
    end
    fprintf('...Done\n');

    drawnow
    opts = statset('MaxIter',1e3);
    %opts.RobustWgtFun = 'welsch' ; %a bit of robust fitting
    %opts.Tune = 1;
    set_freq_offset=time_freq_response(:,2)-freq_cen;
    
    cen_est=wmean(set_freq_offset,-time_freq_response(:,3));
    std_est=std(set_freq_offset,-time_freq_response(:,3));
    amp_est=-range(time_freq_response(:,3));
    offset_est=mean(time_freq_response(:,3))-amp_est/2;
    beta0 = [amp_est,std_est,cen_est,offset_est,0]; %intial guesses
    fit_mean = fitnlm(set_freq_offset,time_freq_response(:,3),loz3fun_offset_grad,beta0,'Options',opts,...
        'CoefficientNames',{'amp','FWHM','center','offset','grad'});
    xplot=linspace(min(set_freq_offset),max(set_freq_offset),1e3)';
    %xplot=linspace(-50,50,1e3)';
    yplot=predict(fit_mean,xplot);
    subplot(2,2,2)
    delete(plot_scan_res_fit_mean)
    hold on
    plot_scan_res_fit_mean=plot(xplot,yplot/current_gain_disp,'r');
    hold off

    %% Fitting the noise
    % I use a fit to the noise to procude another measurment of the offset & the noise in the
    % laser
    %deriv(@(x) loz3fun_offset_grad(
    syms x
    syms x_cen
    % use all the previously fitted params(such as the width) except for the offset
    amp_fit_sym=symfun(-loz3fun_offset_grad(fit_mean.Coefficients.Estimate.*[1,1,0,1,1]'+[0,0,x_cen,0,0]',x),[x,x_cen]);
    amp_fit_fun=matlabFunction(amp_fit_sym);
    %then use the derivative of this as the laser frequency noise componet of the PMT noise
    deriv_amp_fit_fun=matlabFunction(symfun(abs(diff(amp_fit_sym,x)),[x,x_cen]));
    % The noise model we use is laser_freq_noise*d signal/d freq + gain(volts/photon) * sqrt(signal)+
    % offset
    % this is really usefull because it gives an estimate of the system gain and the laser noise
    % in CCD this is called the photon transfer technique
    %http://hosting.astro.cornell.edu/academics/courses/astro3310/Books/Janesick_PhotonTransfer_SPIE1987.pdf
    %http://spiff.rit.edu/classes/phys445/lectures/gain/gain.html
    % sigma Signal = sqrt(sigma Background^2 + sigma Probe^2 )
    % Signal =Background + Probe
    % Probe= Signal - Background
    % sigma Signal^2 = sigma Background^2 + sigma Probe^2
    % from shot noise sigma Probe =sqrt (Probe)/ sqrt(k) (gain in photons/(volt·s)
    % sigma Signal^2 = sigma Background^2 + (sqrt (Probe)/ k )^2
    % sigma Signal = sqrt((sqrt (Signal-Background)/ k )^2 + sigma Background^2)
    % sigma Signal = sqrt(( (Signal-Background)/ k ) + sigma Background^2)
    %noise_fit_fun=@(b,x) b(1).*deriv_amp_fit_fun(x,b(2))+sqrt( (amp_fit_fun(x,b(2))+fit_mean.Coefficients.Estimate(4))./sqrt(abs(b(3))) +b(4)^2);
    noise_fit_fun=@(b,x) b(1).*deriv_amp_fit_fun(x,b(2))+ sqrt(amp_fit_fun(x,b(2)))./sqrt(abs(b(3))) +b(4);
    %0.000441
    %%
    opts = statset('MaxIter',1e4);
    %opts.RobustWgtFun = 'welsch' ; %a bit of robust fitting
    %opts.Tune = 1;
     cen_est=wmean(freq_delta,time_freq_response(:,4));
%     std_est=std(freq_delta,time_freq_response(:,4));
%     amp_est=range(time_freq_response(:,4));
    offset_est=mean(time_freq_response(:,4));
    %fit_mean.Coefficients.Estimate(3),
    beta0 = [1,cen_est,1,offset_est*1e-3]; %intial guesses
    %loz3fun_offset
    
    fit_std = fitnlm(freq_delta,time_freq_response(:,4),noise_fit_fun,beta0,'Options',opts...
         ,'CoefficientNames',{'freq_noise(MHz)','center','gain(photons/v)','offset'});%
    xplot=linspace(min(freq_delta),max(freq_delta),1e3)';
    %xplot=linspace(-50,50,1e3)';
    yplot=predict(fit_std,xplot); 
    subplot(2,2,4)
    delete(plot_scan_res_fit_std)
    hold on
    plot_scan_res_fit_std=plot(xplot,yplot/current_gain_disp,'r');
    hold off
    %%

    freq_fits=[freq_fits;[posixtime(datetime('now')),freq_cen+fit_mean.Coefficients.Estimate(3)-transition_freq,...
        fit_mean.Coefficients.SE(3),freq_cen+fit_std.Coefficients.Estimate(2)-transition_freq,fit_std.Coefficients.SE(2)]];
    fprintf('Scan found estimated wavemeter shift as %f±%f\n',freq_fits(end,2),freq_fits(end,3));
    photon_rate=abs(fit_mean.Coefficients.Estimate(1)*fit_std.Coefficients.Estimate(3));
    fprintf('Estimated Peak Probe Photons %.1f s^-1 \n',photon_rate);
    fprintf('Estimated PMT Multipication %.1g\n e-·(photon)^-1\n',1/(current_gain*fit_std.Coefficients.Estimate(3)*const.electron));
    

    set(plot_freq_trend_mean,'xdata', freq_fits(:,1)-freq_fits(1,1),'ydata', freq_fits(:,2));
    set(plot_freq_trend_mean,'YNegativeDelta', freq_fits(:,3),'YPositiveDelta', freq_fits(:,3))
    set(plot_freq_trend_std,'xdata', freq_fits(:,1)-freq_fits(1,1),'ydata', freq_fits(:,4));
    set(plot_freq_trend_std,'YNegativeDelta', freq_fits(:,5),'YPositiveDelta', freq_fits(:,5))

    nowdt=datetime('now');
    log=[];
    log.posix_time=posixtime(nowdt);
    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    log.op='scan transition';
    log.parameters.hyperfine=hyperfine_transision;
    log.parameters.sample_time_posix=time_freq_response(:,1);
    log.parameters.set_freq=time_freq_response(:,2);
    log.parameters.pmt_voltage_mean=time_freq_response(:,3);
    log.parameters.pmt_voltage_std=time_freq_response(:,4);
    
    log.parameters.current_gain=current_gain;
    log.parameters.freq_offset=freq_cen;
    log.parameters.est_wm_offset=freq_cen+fit_mean.Coefficients.Estimate(3)-transition_freq;

    log.parameters.fit_to_mean.coeff_est=fit_mean.Coefficients.Estimate;
    log.parameters.fit_to_mean.coeff_err=fit_mean.Coefficients.SE;
    log.parameters.fit_to_mean.coeff_names=fit_mean.Coefficients.Properties.RowNames;
    
    log.parameters.fit_to_std.coeff_est=fit_std.Coefficients.Estimate;
    log.parameters.fit_to_std.coeff_err=fit_std.Coefficients.SE;
    log.parameters.fit_to_std.coeff_names=fit_std.Coefficients.Properties.RowNames;
    
    log_str=sprintf('%s\n',jsonencode(log)); %so that can print to standard out
    fprintf(flog,log_str);
    pause(extra_pause_end)
    
    %set the center of the next scan to the fit from the previous
    freq_cen=freq_cen+fit_mean.Coefficients.Estimate(3);
    time_freq_response=nan(size(freq_delta,1),3);
    ii=ii+1;
%     catch e %e is an MException struct
%         
%         log=[];
%         log.posix_time=posixtime(nowdt);
%         log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
%         log.op='error';
%         log.parameters.identifier=e.identifier;
%         log.parameters.message=e.message;
%         log_str=sprintf('%s\n',jsonencode(log)); %so that can print to standard out
%         fprintf(flog,log_str);
%     
%         fprintf(1,'The identifier was:\n%s',e.identifier);
%         fprintf(1,'There was an error! The message was:\n%s',e.message);
%         
%         log_open_time=-inf;
%     end
end   


% 
%     opts = statset('MaxIter',1e4);
%     %opts.RobustWgtFun = 'welsch' ; %a bit of robust fitting
%     %opts.Tune = 1;
%     cen_est=wmean(freq_delta,time_freq_response(:,4));
%     std_est=std(freq_delta,time_freq_response(:,4));
%     amp_est=range(time_freq_response(:,4));
%     offset_est=mean(time_freq_response(:,4));
%     beta0 = [amp_est,std_est,cen_est,offset_est]; %intial guesses
%     %loz3fun_offset
%     
%     fit_std = fitnlm(freq_delta,time_freq_response(:,4),loz3_deriv_abs_fun,beta0,'Options',opts,...
%          'CoefficientNames',{'amp','FWHM','center','offset'});
%     xplot=linspace(min(freq_delta),max(freq_delta),1e3)';
%     %xplot=linspace(-50,50,1e3)';
%     yplot=predict(fit_std,xplot); 
%     subplot(2,2,4)
%     delete(plot_scan_res_fit_std)
%     hold on
%     plot_scan_res_fit_std=plot(xplot,yplot/current_gain_disp,'r');
%     hold off