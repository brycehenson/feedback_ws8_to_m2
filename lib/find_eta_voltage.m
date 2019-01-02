%fucking m2 does not give the dac value [0-100] for the reonator voltage
%only the actual voltage
%to prevent moving the resonator every time at startup i need to know what this conversion is
solstis=solstis_findInstrument;
 solstis_clearBuffer();
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}',solstis)

%%
dac_vals=linspace(1,99,1000);
dac_vals=dac_vals(randperm(numel(dac_vals)));
voltage=NaN*dac_vals;

figure(1)
clf

for n=1:numel(dac_vals)
fprintf('%02i\n',n)
solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',dac_vals(n)),solstis);
pause(0.01)
solstis_getResponse(solstis);
pause(1)
reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
reply=jsondecode(reply);
status=reply.message.parameters;

voltage(n)=status.etalon_voltage;

figure(1);
p=polyfit(voltage(~isnan(voltage)),dac_vals(~isnan(voltage)),4);
plot(voltage,dac_vals,'k+')
hold on
xplot = linspace(min(voltage(~isnan(voltage))),max(voltage(~isnan(voltage))),1e3);
fit = polyval(p,xplot);
plot(xplot,fit,'-')
hold off
end
%%
p=polyfit(voltage(~isnan(voltage)),dac_vals(~isnan(voltage)),2)
plot(voltage,dac_vals,'k+')
hold on
xplot = linspace(min(voltage(~isnan(voltage))),max(voltage(~isnan(voltage))),1e3);
fit = polyval(p,xplot);
plot(xplot,fit,'-')
hold off

%%
p=polyfit(voltage(~isnan(voltage)),dac_vals(~isnan(voltage)),3);
xplot = linspace(min(voltage(~isnan(voltage))),max(voltage(~isnan(voltage))),1e3);
fit = polyval(p,voltage(~isnan(voltage)));
plot(voltage(~isnan(voltage)),fit-dac_vals(~isnan(voltage)),'x')


%%
solstis_query('{"message":{"transmission_id":[2],"op":"beam_alignment","parameters":{"mode":[4]}}}',solstis)
pause(0.01)

