%% USER PARAM
format longg
current_gain=2e7; %V/A

wavemeter_offset=0.6;%-150.4;%-145.2;
% wavemeter_offset = 0;
%the total range to scan over (from -ve freq_range/2 to +ve freq_range/2)
freq_range=7;%60 for SAS;%10 for 2photon 
delt_freq=0.1;% 0.2 %MHz for 2p
settle_time=0.05;%0.3;
volt_aq_time=0.05; %0.5
extra_pause_end=1;
extra_pause_start=3;
plot_interval=1;
fit_noise=0;
num_loops = 3; %set to inf for endless loop
update_cen_pos=false;
log_dir='Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\';
new_log_interval=60*60*1;

[f_struct,wl_table] = init_cs_transition_struct(); %Wavelength table is sorted
transition_name='cs_2p_6SF3_8SF3';% %cs_2p_6SF3_8SF3  cs_2p_6SF4_8SF4 % cs_6SF4_6PF4co5 
transition_freq = f_struct.(transition_name);

%cs_2p_6SF4_8SF3 forbidden

% Transitions by wavelength for quick reference
%     TRANSITION NAME   WAVE  LENGTH (nm)  FREQUENCY (MHz)
%     cs_2p_6SF3_8SF4: [822.448186973894 364512272.92877]
%     cs_2p_6SF3_8SF3: [822.459546609736 364507238.363]
%     cs_2p_6SF4_8SF4: [822.468928810497 364503080.297]
%     cs_2p_6SF4_8SF3: [822.489671693329 364493887.66523]
%        cs_6SF3_6PF5: [852.334106041068 351731153.165371]
%     cs_6SF3_6PF4co5: [852.33441015356  351731027.667871]
%        cs_6SF3_6PF4: [852.334714266269 351730902.170371]
%     cs_6SF3_6PF3co4: [852.334958112731 351730801.542871]
%        cs_6SF3_6PF3: [852.335201959332 351730700.915371]
%     cs_6SF3_6PF2co3: [852.335385157884 351730625.315371]
%        cs_6SF3_6PF2: [852.335568356515 351730549.715371]
%        cs_6SF4_6PF5: [852.356382709746 351721960.533601]
%     cs_6SF4_6PF4co5: [852.356686838136 351721835.036101]
%        cs_6SF4_6PF4: [852.356990966742 351721709.538601]
%     cs_6SF4_6PF3co4: [852.35723482595  351721608.911101]
%        cs_6SF4_6PF3: [852.357478685298 351721508.283601]
%        cs_6SF4_6PF2: [852.357845101634 351721357.083601]
%     cs_2p_6SF3_6DF5: [885.386949360815 338600493.509]
%     cs_2p_6SF3_6DF4: [885.387056126153 338600452.6785]
%     cs_2p_6SF3_6DF3: [885.387205427182 338600395.581]
%     cs_2p_6SF4_6DF5: [885.398968134848 338595897.205]
%     cs_2p_6SF4_6DF4: [885.399074903085 338595856.3745]
%     cs_2p_6SF4_6DF3: [885.399224208167 338595799.277]



fclose('all')
clear('flog')

folder = fileparts(which(mfilename));
folder=strsplit(folder,filesep); %go up a directory
folder=strjoin(folder(1:end-1),filesep);
% Add that folder plus all subfolders to the path.
addpath(genpath(folder));

hebec_constants

nowt=posixtime(datetime('now'));


%  %852.3 red single photon 

freq_cen=transition_freq;
freq_cen=freq_cen+wavemeter_offset; 

fprintf('probe beam set freq %f MHz \n',freq_cen)
t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
fopen(t)
fwrite(t,freq_cen,'double')
fclose(t)

%%
connected_dev=daq.getDevices;
dev_idx=contains({connected_dev.Description},'USB-6251')
%dev_idx=cellfun(@(x) isequal(x,'National Instruments USB-6251'),{connected_dev.Description});
if sum(dev_idx)~=1
    error('somethings broken couldnt find USB-6251')
end
dev_idx=find(dev_idx,1);
connected_dev(dev_idx)
daq_pmt = daq.createSession('ni');
ch=addAnalogInputChannel(daq_pmt,connected_dev(dev_idx).ID,4,'Voltage');
% the sampling rate should be set so that it is much slower than the 200us of the transimpedance
% amplifier % 3.7khz low pass filter, 0.5khz is ok
daq_pmt.Rate = 500;
daq_pmt.DurationInSeconds=volt_aq_time;
ch.TerminalConfig='SingleEnded';
daq_pmt.inputSingleScan;

%% Initalize plots
figure(1)
set(gcf,'color','w')
clf
subplot(2,2,1)
[voltage,time] = daq_pmt.startForeground;
plot_volt_aq=plot(time,voltage,'k.-','LineWidth',1.5,'MarkerSize',20);
title('measuring pmt current')
xlabel('time (s)')
%ylabel('PMT Current (nA)')
ylabel('PMT Voltage (V)')

subplot(2,2,2)
plot_scan_res_mean=plot([nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20);
title('scan response')
xlabel('Probe Set Point-Transition Freq-WM Offset (MHz)')
ylabel('Mean PMT Current (nA)')
xlim([-1,1]*freq_range/2)

subplot(2,2,4)
plot_scan_res_std=plot([nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20);
title('scan response')
xlabel('Probe Set Point-Transition Freq-WM Offset (MHz)')
ylabel('STD PMT Current (nA)')
xlim([-1,1]*freq_range/2)
plot_scan_res_fit_mean=plot([],[],'r');
plot_scan_res_fit_std=plot([],[],'r');

subplot(2,2,3)
% plot_freq_trend_single=errorbar([nan],[nan],[nan],'r.-','LineWidth',1.5,'MarkerSize',20,'CapSize',0);
plot_freq_trend_mean=errorbar([nan],[nan],[nan],'k.-','LineWidth',1.5,'MarkerSize',20,'CapSize',0);
hold on
plot_freq_trend_std=errorbar([nan],[nan],[nan],'b.-','LineWidth',1.5,'MarkerSize',20,'CapSize',0);
legend('Centre','Width')
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
daq_pmt.inputSingleScan; %initalize
[voltage_aq,time] = daq_pmt.startForeground;

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
while ii<=num_loops
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
            
    end
    flog=fopen(log_file_str,'a'); 
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

        [voltage_aq,time] = daq_pmt.startForeground;
        time_freq_response(jj,1)=posixtime(datetime('now')); 
        if jj~=1
             time_freq_response(jj,1)= time_freq_response(jj,1)- time_freq_response(1,1); %differential encoding of the scan time
        end
        %voltage_now=s.inputSingleScan/current_gain;
        time_freq_response(jj,3)=mean(voltage_aq); 
        time_freq_response(jj,4)=std(voltage_aq); 
        if mod(jj,plot_interval)==0
            %set(plot_volt_aq,'xdata', time,'ydata', voltage_aq/current_gain_disp);
            set(plot_volt_aq,'xdata', time,'ydata', voltage_aq);
            set(plot_scan_res_mean,'xdata', freq_delta,'ydata', time_freq_response(:,3)/current_gain_disp);
            set(plot_scan_res_std,'xdata', freq_delta,'ydata', time_freq_response(:,4)/current_gain_disp);
            drawnow    
        end
        fprintf('\b\b\b\b%04u',jj);
    end
    fprintf('...Done\n');
%%
    drawnow
    opts = statset('MaxIter',1e3);
    %opts.RobustWgtFun = 'welsch' ; %a bit of robust fitting
    %opts.Tune = 1;
    set_freq_offset=time_freq_response(:,2)-freq_cen;
    
    cen_est=wmean(set_freq_offset,abs(time_freq_response(:,3)));
    std_est=std(set_freq_offset,abs(time_freq_response(:,3)));
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

    if fit_noise
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
        % from shot noise sigma Probe =sqrt (Probe)/ sqrt(k) (gain in photons/(volt�s)
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
    else
        fit_std=[];
        fit_std.Coefficients.Estimate=[nan,nan,nan];
        fit_std.Coefficients.SE=[nan,nan,nan];
    end

    freq_fits=[freq_fits;[posixtime(datetime('now')),freq_cen+fit_mean.Coefficients.Estimate(3)-transition_freq,...
        fit_mean.Coefficients.SE(3),freq_cen+fit_std.Coefficients.Estimate(2)-transition_freq,fit_std.Coefficients.SE(2)]];
    fprintf('Scan found estimated wavemeter shift as %f�%f\n',freq_fits(end,2),freq_fits(end,3));
    photon_rate=abs(fit_mean.Coefficients.Estimate(1)*fit_std.Coefficients.Estimate(3));
    fprintf('Probe Current Peak Amp %.4g A \n',fit_mean.Coefficients.Estimate(1)/current_gain);
    fprintf('Peak Width %.4g MHZ\n', fit_mean.Coefficients.Estimate(2))
    fprintf('Estimated Peak Probe Photons %.1f s^-1 \n',photon_rate);
    fprintf('Estimated PMT Multipication %.1g\n e-�(photon)^-1\n',1/(current_gain*fit_std.Coefficients.Estimate(3)*const.electron));
    fprintf('Running mean %f�%f (se), sd %f\n',mean(freq_fits(:,2)),std(freq_fits(:,3))/length(freq_fits(:,3)),std(freq_fits(:,3)))

    set(plot_freq_trend_mean,'xdata', freq_fits(:,1)-freq_fits(1,1),'ydata', freq_fits(:,2));
    set(plot_freq_trend_mean,'YNegativeDelta', freq_fits(:,3),'YPositiveDelta', freq_fits(:,3))
    set(plot_freq_trend_std,'xdata', freq_fits(:,1)-freq_fits(1,1),'ydata', freq_fits(:,4));
    set(plot_freq_trend_std,'YNegativeDelta', freq_fits(:,5),'YPositiveDelta', freq_fits(:,5))
%     set(plot_freq_trend_single,'xdata', freq_fits(:,1)-freq_fits(1,1),'ydata', freq_fits(:,2));
%     set(plot_freq_trend_single,'YNegativeDelta', freq_fits(:,3),'YPositiveDelta', freq_fits(:,3))
%     
    nowdt=datetime('now');
    log=[];
    log.posix_time=posixtime(nowdt);
    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    log.op='scan transition';
%     log.parameters.hyperfine=hyperfine_transision;
    log.parameters.sample_time_posix=time_freq_response(:,1);
    log.parameters.set_freq=time_freq_response(:,2);
    log.parameters.pmt_voltage_mean=time_freq_response(:,3);
    log.parameters.pmt_voltage_std=time_freq_response(:,4);
    
    log.parameters.current_gain=current_gain;
    log.parameters.transition_name=transition_name;
    log.parameters.transition_freq=transition_freq;
    log.parameters.freq_center=freq_cen;
    log.parameters.est_wm_offset=freq_cen+fit_mean.Coefficients.Estimate(3)-transition_freq;

    log.parameters.fit_to_mean.coeff_est=fit_mean.Coefficients.Estimate;
    log.parameters.fit_to_mean.coeff_err=fit_mean.Coefficients.SE;
    log.parameters.fit_to_mean.coeff_names=fit_mean.Coefficients.Properties.RowNames;
    
    if fit_noise
        log.parameters.fit_to_std.coeff_est=fit_std.Coefficients.Estimate;
        log.parameters.fit_to_std.coeff_err=fit_std.Coefficients.SE;
        log.parameters.fit_to_std.coeff_names=fit_std.Coefficients.Properties.RowNames;
    end
    
    log_str=sprintf('%s\n',jsonencode(log)); %so that can print to standard out
    fprintf(flog,log_str);
    pause(extra_pause_end)
    
    %set the center of the next scan to the fit from the previous
    if update_cen_pos && fit_mean.Coefficients.Estimate(3)<freq_range/2
        fprintf('updating next scan center to fit cen \n')
        freq_cen=freq_cen+fit_mean.Coefficients.Estimate(3);
    end
    time_freq_response=nan(size(freq_delta,1),3);
    ii=ii+1;
    
    fclose(flog); 
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