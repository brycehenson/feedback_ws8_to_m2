transition_name='cs_2p_6SF4_8SF4';

f_table = init_cs_table();
transition_freq = f_table.(transition_name)
N = numel(fields(f_table));
f_all = zeros(N,1);
for i=1:N
    fnames = fields(f_table);
    f_all(i) = f_table.(fnames{i});
end
sort(f_all)-min(f_all)
