function set_plants(plants,data,data_sim,models,scenario_name)

% Load data to display history in web interface.
%
% Agostini - 24.04.2023

% indexes
iLsd = getIndex('Lsd',cat(2,{data(1).variables.name}));
iLsa = getIndex('Lsa',cat(2,{data(1).variables.name}));
ifeet = getIndex('feet',cat(2,{plants(1).variables.name}));
ibelly = getIndex('belly',cat(2,{plants(1).variables.name}));
ihead = getIndex('head',cat(2,{plants(1).variables.name}));
iplan = getIndex('plan',cat(2,{models(1).variables.name}));


nplants = length(plants);
for iplant = 1:nplants
    
    datum_real = data(iplant);
    datum_sim = data_sim(iplant);
    plant = plants(iplant); % to store data and deploy in web
    model = models(iplant);
    
    % data
    Lsd_real = datum_real.variables(iLsd).value;
    Lsa_real = datum_real.variables(iLsa).value;
    Lsd_sim = datum_sim.variables(iLsd).value;
    Lsa_sim = datum_sim.variables(iLsa).value;

    % PAST
    dataweb = '';
    ntime = length(Lsd_real);
    nsteppast = 36; % this number should be compatible with trees defined in history panel (web).
    for itime=max(1,ntime-nsteppast):ntime
        % name of treatment
        % ad = Lsd_real(itime).ad;
        % sa_aa        
        sample_sa = Lsa_real(itime);
        sa = sample_sa.sai;
        aa = sample_sa.aa;
        sa_conf = sample_sa.sai_conf;
        aa_conf = sample_sa.aa_conf;
        % date
        t = sample_sa.t;
        month = shared_monthName(t.month);
        % text_date = [month(1:3) num2str(t.year)];
        text_date = [num2str(t.day) month(1:3) num2str(t.year)];
        % get data
        text_var = prepare_plant_data([sa aa],[sa_conf aa_conf],plant);
        % prepare data
        dataweb = [dataweb...
                   text_date ':' ...
                   text_var ';' ...
                  ];
    end
    plant.variables(ifeet).value = dataweb;

    
    % PRESENT (if reset) OR LAST FUTURE
    dataweb = '';
    % name of treatment
    % ad = Lsd_sim(end).ad;
    % sa_aa
    sample_sa = Lsa_sim(end);
    sa = sample_sa.sai;
    aa = sample_sa.aa;
    sa_conf = sample_sa.sai_conf;
    aa_conf = sample_sa.aa_conf;
    % date
    t = sample_sa.t;
    month = shared_monthName(t.month);
    % text_date = [month(1:3) num2str(t.year)];
    text_date = [num2str(t.day) month(1:3) num2str(t.year)];
    % get data
    text_var = prepare_plant_data([sa aa],[sa_conf aa_conf],plant);
    % prepare data
    dataweb = [dataweb...
               text_date ':' ...
               text_var ';' ...
              ];
    plant.variables(ibelly).value = dataweb;
    
    
    % FUTURE
    dataweb = '';
    ixs = length(Lsd_sim) - length(Lsd_real) - 1;
    if ixs > 0
        Lsd = Lsd_sim(end-ixs:end);
        Lsa = Lsa_sim(end-ixs:end);
        ntime = length(Lsd);
        % nstepfuture = 14;
        plan = model.variables(iplan).value;
        nstepfuture = length(plan);
        for itime=max(1,ntime-nstepfuture):ntime
            % name of treatment
            % ad = Lsd(itime).ad;
            % sa_aa
            sample_sa = Lsa(itime);
            sa = sample_sa.sai;
            aa = sample_sa.aa;
            sa_conf = sample_sa.sai_conf;
            aa_conf = sample_sa.aa_conf;
            % date
            t = sample_sa.t;
            month = shared_monthName(t.month);
            % text_date = [month(1:3) num2str(t.year)];
            text_date = [num2str(t.day) month(1:3) num2str(t.year)];
            % get data
            text_var = prepare_plant_data([sa aa],[sa_conf aa_conf],plant);
            % prepare data
            dataweb = [dataweb...
                       text_date ':' ...
                       text_var ';' ...
                      ];
        end
    end
    plant.variables(ihead).value = dataweb;
    
    set_values(plant,'objects',scenario_name,[ifeet ihead ibelly])
    % set_entities_state(plant);

end



% ------------
% ------------
% aux function
% ------------
% ------------
function text_var = prepare_plant_data(sa_aa,sa_aa_conf,plant)

global sa_aa_variable_names
global sa_aa_variable_ranges_web
global sa_aa_variable_sim2web_units
           
text_var = [];
nvar = length(sa_aa_variable_names);
for ivar = 1:nvar %-1
    
    varname = sa_aa_variable_names{ivar};
    varval = sa_aa(ivar);
    varconf = sa_aa_conf(ivar);
    valmin = sa_aa_variable_ranges_web(ivar,1);
    valmax = sa_aa_variable_ranges_web(ivar,2);
    sim2web_units = sa_aa_variable_sim2web_units(ivar);
    
    % adjust units to proper scale
    varval = varval * sim2web_units;
    
    switch varname
    
        case 'soil_W'
            
            iplantation_frame = getIndex('plantation_frame',cat(2,{plant.variables.name}));
            plantation_frame = plant.variables(iplantation_frame).value; 
            
            % Percentage of water saturation in soil per plant assuming
            % varval is in liters per plant.
            %
            % Units LM
            % plantation_frame -> m2 (per plant)
            % depth -> m
            % varval in -> lt
            % varval out -> saturation
            %
            % Units Horti
            % plantation_frame -> m2 (per plant)
            % depth -> m
            % varval in -> ml
            % varval out -> saturation
            % 
            depth = 0.3;
            varval = varval / (plantation_frame * depth * 1000) * 100; 
            
        case {'fruit_production','soil_N','soil_P','soil_K','action_N','action_P','action_K'}
            
            inumber_of_plants = getIndex('number_of_plants',cat(2,{plant.variables.name}));
            number_of_plants = plant.variables(inumber_of_plants).value;
            itotal_surface = getIndex('total_surface',cat(2,{plant.variables.name}));
            total_surface = plant.variables(itotal_surface).value;
               
            % Amount (weight) per unit area
            %
            % Units LM
            % total_surface -> Ha
            % varval in -> kg/plant
            % varval out -> kg/Ha
            %
            % Units Horti
            % total_surface -> m2
            % varval in -> mg/plant
            % varval out -> mg/m2
            varval = varval * number_of_plants / total_surface; 
            
            
    
        case {'action_W','env_rain'}
            
            iplantation_frame = getIndex('plantation_frame',cat(2,{plant.variables.name}));
            plantation_frame = plant.variables(iplantation_frame).value;
            
            % mm
            %
            % Units LM
            % plantation_frame -> m2
            % varval in -> lt/plant
            % varval out -> mm
            %
            % Units Horti
            % plantation_frame -> m2
            % varval in -> ml/plant
            % varval out -> mm
            
            dm3_to_m3 = 1/1000;
            m_to_mm = 1000;
            varval = varval * dm3_to_m3/m_to_mm / plantation_frame;
            
    end    
    varnorm = min(1,(varval - valmin) / (valmax - valmin));
    
    if ivar < nvar
        text_var = [text_var num2str(varnorm) ',' num2str(varconf) ':'];
    else
        text_var = [text_var num2str(varnorm) ',' num2str(varconf)];
    end
end

% var_norm = min(1,(sa_aa(end)-sa_aa_variable_ranges(end,1))/(sa_aa_variable_ranges(end,2)-sa_aa_variable_ranges(end,1)));
% var_conf = sa_aa_conf(end);
% text_var = [text_var num2str(var_norm) ',' num2str(var_conf)];