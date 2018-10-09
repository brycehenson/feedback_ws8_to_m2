function pidstate=pid_loop(pidstate)

%FUNCTION_NAME - A software PID loop with good integerator windup protection
%%ctr output is between 0 and 1
%Optional file header info (to give more details about the function than in the H1 line)
%Optional file header info (to give more details about the function than in the H1 line)
%
% Syntax:  [output1,output2] = function_name(input1,input2,input3)
%
% Inputs:
%   pidstate.integrator     - double used to initalize integerator;
%   pidstate.setpt          - desired setpoint
%   pidstate.k_int=         -integerator gain in [out]/(sec*[pidstate.erroror])
%   pidstate.k_prop=        -proportional gain with unity output scaling
%   pidstate.outlims        -output limits
%   pidstate.aw_thresh_range -how far away from the edge aw starts (full range 0-1)
%   pidstate.int_lim        -integerator limit in multiples of output range
%   pidstate.slew_lim       -output slew limit in multiples of output range/sec

%
% Outputs:
%    pidstate.ctr_output - float,actuator control  between pidstate.outlims
% 
% Example: 
% pidstate.integrator=(gain-min(gain_lim))/range(gain_lim);
% pidstate.setpt=0.65; %max val set pt
% pidstate.k_int=-2e-6;
% pidstate.k_prop=1e-8;
% pidstate.outlims=[12/100 1];
% pidstate.aw_thresh_range=0.05; %how far away from the edge aw starts (full range 0-1)
% pidstate.int_lim=3;
% pidstate.slew_lim=1e-5;


% Bugs,Improvements,Ideas
% initalization option
% scale pidstate.aw_thresh_range
% output is not continious with proportional control gain change
% Derivative term not implemented
% this would probably be better written as a class
% slew lim always activates on first loop

% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
% See also: none

% Author: Bryce Henson
% Work address
% email: bryce.henson@live.com
% Last revision: 2018-08-23


%------------- BEGIN CODE --------------




if ~isfield(pidstate,'integrator')
    if ~isfield(pidstate,'outlims')
        pidstate.erroror('requires more information')
    else
        pidstate.ctr_output=mean(pidstate.outlims);
    end
end


if ~isfield(pidstate,'loop_time')
    pidstate.loop_time=0;
    pidstate.time=posixtime(datetime('now'));
end

if ~isfield(pidstate,'ctr_output')
    pidstate.ctr_output=pidstate.integrator;
end

pidstate.ctr_prev=pidstate.ctr_output;

logist=@(x) 1./(1+exp(-x));
aw_fun_range=@(x,y) (logist((x-pidstate.aw_thresh_range)*10/pidstate.aw_thresh_range))*(y<0)...
    +(1-logist((x-1+pidstate.aw_thresh_range)*10/pidstate.aw_thresh_range))*(y>0);


pidstate.error=pidstate.meas-pidstate.setpt;
di=pidstate.k_int*pidstate.loop_time*pidstate.error;
pidstate.aw=aw_fun_range((pidstate.ctr_prev-pidstate.outlims(1))/range(pidstate.outlims),di);
di=di*pidstate.aw; %actuator range anti windup
pidstate.integrator=pidstate.integrator+di;%+aw_slew*k_aw_rate;
pidstate.integrator=min(max(-pidstate.int_lim,pidstate.integrator),pidstate.int_lim);
pidstate.ctr_output=pidstate.integrator+pidstate.k_prop*pidstate.error;%-aw_rate*k_aw_rate);

pidstate.slew=(pidstate.ctr_prev-pidstate.ctr_output)/(pidstate.loop_time);
%fprintf('slew before corr %f\n',pidstate.slew)
if abs(pidstate.slew/pidstate.slew_lim)>1
    %fprintf('pre mod int %f\n',pidstate.integrator)
    pidstate.integrator=pidstate.ctr_prev-pidstate.slew_lim*sign(pidstate.slew)*pidstate.loop_time-pidstate.k_prop*pidstate.error;
    %fprintf('slew mod int %f\n',pidstate.integrator)
    pidstate.aw_slew=1;
else
    pidstate.aw_slew=0;
end

%recalc output
%integrator=integrator+aw_slew;
%pidstate.integrator=min(max(-pidstate.int_lim,pidstate.integrator),pidstate.int_lim);
pidstate.ctr_output=pidstate.integrator+pidstate.k_prop*pidstate.error;%-aw_rate*k_aw_rate);
pidstate.ctr_output=min(max(pidstate.outlims(1),pidstate.ctr_output),pidstate.outlims(2));
pidstate.slew=(pidstate.ctr_prev-pidstate.ctr_output)/(pidstate.loop_time);
%fprintf('slew after corr %f\n',pidstate.slew)


old_time=pidstate.time;
pidstate.time=posixtime(datetime('now'));
pidstate.loop_time=(pidstate.time-old_time);
end