solstis=solstis_findInstrument;
solstis_clearBuffer();
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}',solstis)
pause(1)
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50),solstis)

fprintf('unlock res')
query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"off","report":"finished"}}}');
solstis_query(query,solstis);
pause(0.1)
solstis_getResponse(solstis);

query=sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"off","report":"finished"}}}');
solstis_query(query,solstis);
pause(0.1)
solstis_getResponse(solstis);


%% Get etalon dac pos
reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
reply=jsondecode(reply);
status=reply.message.parameters;
etalon_dac=polyval([0.0000000380,-0.0000179883,0.5115165165,-0.0782913954],status.etalon_voltage);
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_dac),solstis);
pause(0.01)
solstis_getResponse(solstis);



%% now scan over some region
wmhandle=WLM.getInstance();

dac_vals=linspace(25,27,100);
freq=NaN*dac_vals;

for n=1:numel(dac_vals)
fprintf('%02i\n',n)
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',dac_vals(n)),solstis);
pause(0.01)
solstis_getResponse(solstis);
pause(0.01)
freq(n)=wmhandle.GetFreq(1);

sfigure(1);
plot(dac_vals,freq,'k-')
end
%we see that the laser freq looks like steps that change in ~Ghz increments

%% simple optimizer to try and find the right etalon mode

% Get etalon dac pos
reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
reply=jsondecode(reply);
status=reply.message.parameters;
etalon_dac=polyval([0.0000000380,-0.0000179883,0.5115165165,-0.0782913954],status.etalon_voltage);
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_dac),solstis);
pause(0.01)
solstis_getResponse(solstis);



%will try a simple integerator 
int=etalon_dac;
setpt=362788925;
thresh=500;%MHZ tolerance
search_etalon=true;
while search_etalon
freq=wmhandle.GetFreq(1);   
error=freq-setpt;
int=int+error*1e-5;
etalon_ctr=min(max(1,int),99);

fprintf('%02i\n',n)
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_ctr),solstis);
pause(0.01)
solstis_getResponse(solstis);
pause(0.05)

if abs(error)<thresh 
    search_etalon=false;
    fprintf('sucess')
elseif int>98 || int<2
    fprintf('failure')
    search_etalon=false;
end

end
