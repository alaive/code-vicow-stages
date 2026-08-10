function data = get_plants(iplant,plants,data,scenario_name)

% Get data from display history in web interface.
%
% Agostini - 07.08.2023

global sa_variable_names aa_variable_names sa_aa_variable_ranges
nvar_sa = length(sa_variable_names);
nvar_aa = length(aa_variable_names);
iLsd = getIndex('Lsd',cat(2,{data(1).variables.name}));
iLsa = getIndex('Lsa',cat(2,{data(1).variables.name}));
plant_id = plants(iplant).name;
% update data
request = ['select val from ' scenario_name '_objects where obj=''' plant_id ''' and var=''feet'''];
history_all = mexSqlRequestRWText_uniphyed(request);
history_per_month = strsplit(history_all,';');
nmonths = length(history_per_month(1:end-1)); % last one is blank due to strsplit
% get data from plants
Lsa = data(iplant).variables(iLsa).value;
Lsd = data(iplant).variables(iLsd).value;
data_date = cat(1,Lsa.t);
vy = cat(1,data_date.year);
vm = cat(1,data_date.month);
mdate = [vm vy];
% update
for imonth = 1:nmonths
    text_month = history_per_month{imonth};
    text_month_val_conf = strsplit(text_month,':');
    % nvar = length(text_month_val_conf);
    date = text_month_val_conf{1}; % first var is date
    [dd,mm,yyyy] = shared_date2vector(date);
    % searh for month in Lsa and Lsd
    im = find(ismember(mdate,[mm yyyy],'rows'));
    sample_sa = Lsa(im);
    sample_sd = Lsd(im);
    % check if first sample
    bant = 0;
    if im > 1
        bant = 1;
        sample_sa_ant = Lsa(im-1);
        sample_sd_ant = Lsd(im-1);
    end
    % update state variables
    for ivar = 1:nvar_sa
        text_val_conf = strsplit(text_month_val_conf{ivar + 1},','); % first var is date
        val_norm = str2num(text_val_conf{1});
        conf = str2num(text_val_conf{2});
        % norm2reg value
        val_min = sa_aa_variable_ranges(ivar,1);
        val_max = sa_aa_variable_ranges(ivar,2);
        val = val_norm * (val_max - val_min) + val_min;
        % input new
        sample_sa.sai(ivar) = val;
        sample_sa.sai_conf(ivar) = conf;
        sample_sd.sai(ivar) = val;
        sample_sd.sai_conf(ivar) = conf;
        % output ant
        if bant
            sample_sa_ant.sao(ivar) = val;
            sample_sa_ant.sao_conf(ivar) = conf;
            sample_sd_ant.sao(ivar) = val;
            sample_sd_ant.sao_conf(ivar) = conf;
        end
    end
    % update action variables
    % for ivar = nvar_sa + 1 : nvar_sa + nvar_aa
    for ivar = nvar_sa + 1 : nvar_sa + nvar_aa
        text_val_conf = strsplit(text_month_val_conf{ivar + 1},','); % first var is date
        val_norm = str2num(text_val_conf{1});
        conf = str2num(text_val_conf{2});
        % norm2reg value
        val_min = sa_aa_variable_ranges(ivar,1);
        val_max = sa_aa_variable_ranges(ivar,2);
        val = val_norm * (val_max - val_min) + val_min;
        % input new
        ivar_aa = ivar - nvar_sa;
        sample_sa.aa(ivar_aa) = val;
        sample_sa.aa_conf(ivar_aa) = conf;
    end
    % store values
    Lsa(im) = sample_sa;
    Lsd(im) = sample_sd;
    if bant
        Lsa(im-1) = sample_sa_ant;
        Lsd(im-1) = sample_sd_ant;
    end
end % months
data(iplant).variables(iLsa).value = Lsa;
data(iplant).variables(iLsd).value = Lsd;

