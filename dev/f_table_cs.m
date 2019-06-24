function f_table = init_cs_table()
 
%6s->6P ( D2) single photon transtions cesium ~852nm 
%solsTIS filter at 852.3 %pmt voltage 1250
%REF https://steck.us/alkalidata/cesiumnumbers.1.6.pdf
% https://www.sacher-laser.com/applications/overview/absorption_spectroscopy/caesium_d2.html line
% identification
% other reading https://doi.org/10.1364/OL.19.001474
%https://doi.org/10.1143/JPSJ.74.2487 %883nm transtion
%6^{2}S_{1/2} F=3-> 6^{2}S_{3/2} F=[2,3,4,5]
f_table.cs_6SF3_6PF2=351725718.50+5170.855370625-339.64; %MHZ
f_table.cs_6SF3_6PF3=351725718.50+5170.855370625-188.44; %MHZ
f_table.cs_6SF3_6PF4=351725718.50+5170.855370625+12.815; %MHZ
f_table.cs_6SF3_6PF5=351725718.50+5170.855370625+263.81; %MHZ
f_table.cs_6SF3_6PF2co3=(f_table.cs_6SF3_6PF2+f_table.cs_6SF3_6PF3)/2;
f_table.cs_6SF3_6PF3co4=(f_table.cs_6SF3_6PF3+f_table.cs_6SF3_6PF4)/2;
f_table.cs_6SF3_6PF4co5=(f_table.cs_6SF3_6PF4+f_table.cs_6SF3_6PF5)/2;
%f_table.cs_6SF3_6PF2co3 seems like the best option here (stronger than f_table.cs_6SF4_6PF4co5)

%6^{2}S_{1/2} F=4->6^{2}S_{1/2} F=[2,3,4,5]
f_table.cs_6SF4_6PF2=351725718.50-4021.776399375-339.64; %MHZ
f_table.cs_6SF4_6PF3=351725718.50-4021.776399375-188.44; %MHZ
f_table.cs_6SF4_6PF4=351725718.50-4021.776399375+12.815; %MHZ
f_table.cs_6SF4_6PF5=351725718.50-4021.776399375+263.81; %MHZ
f_table.cs_6SF4_6PF3co4=(f_table.cs_6SF4_6PF3+f_table.cs_6SF4_6PF4)/2;
f_table.cs_6SF4_6PF4co5=(f_table.cs_6SF4_6PF4+f_table.cs_6SF4_6PF5)/2;
%f_table.cs_6SF4_6PF4co5 is the best option, the rest are very weak and the F=3co5 is vclose to F=4



%6S–8S two photon cesium ~822.4nm 2photon 
%pmt voltage 1160 %filter at 822.5
%Ref https://doi.org/10.1088/1674-1056/21/11/113701  
% older works
% https://doi.org/10.1016/S0030-4018(98)00662-2 (1999)
% https://doi.org/10.1364/OL.32.000701 (2007)
%6^{2}S_{1/2} F=[3,4] -> 8^{2}S_{1/2} F=[3,4]
f_table.cs_2p_6SF3_8SF3=364507238.363;
f_table.cs_2p_6SF4_8SF4=364503080.297;
%forbidden 2 photon transtions, have not found any references, just a guess
%have not been able to observe these
f_table.cs_2p_6SF3_8SF4=f_table.cs_2p_6SF4_8SF4+4021.776399375+5170.85537062;
f_table.cs_2p_6SF4_8SF3=f_table.cs_2p_6SF4_8SF4-4021.776399375-5170.85537062;


%6S–6D_{3/2} two photon cesium ~885.4nm 2photon 
% problem is that fluro is at 919 & 852nm and may be very hard to see with this pmt
% filter at 885.4
% ref https://doi.org/10.1364/OL.43.001954
%6^{2}S_{1/2} F=[4,3] -> 6^{2}D_{3/2} F=5
f_table.cs_2p_6SF4_6DF5=338595897.205;
f_table.cs_2p_6SF3_6DF5=338600493.509;
%using the measured hyperfine intervals, unsure why there is a diagreement between the table 2 and
%the values below it
f_table.cs_2p_6SF4_6DF4=f_table.cs_2p_6SF4_6DF5-81.661/2;
f_table.cs_2p_6SF4_6DF3=f_table.cs_2p_6SF4_6DF4-65.336/2;
f_table.cs_2p_6SF4_6DF3=f_table.cs_2p_6SF4_6DF3-48.859/2;

f_table.cs_2p_6SF3_6DF4=f_table.cs_2p_6SF3_6DF5-81.661/2;
f_table.cs_2p_6SF3_6DF3=f_table.cs_2p_6SF3_6DF4-65.336/2;
f_table.cs_2p_6SF3_6DF3=f_table.cs_2p_6SF3_6DF3-48.859/2;
end