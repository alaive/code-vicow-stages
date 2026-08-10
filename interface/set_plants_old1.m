function set_plants(plants,data,data_sim,scenario_name)

% Load data to display history in web interface.
%
% Agostini - 24.04.2023

% indexes
iLsd = getIndex('Lsd',cat(2,{data(1).variables.name}));
iLsa = getIndex('Lsa',cat(2,{data(1).variables.name}));
ifeet = getIndex('feet',cat(2,{plants(1).variables.name}));
ibelly = getIndex('belly',cat(2,{plants(1).variables.name}));
ihead = getIndex('head',cat(2,{plants(1).variables.name}));
% iplantation_frame = getIndex('plantation_frame',cat(2,{plants(1).variables.name}));
% inumber_of_plants = getIndex('number_of_plants',cat(2,{plants(1).variables.name}));
% itotal_surface = getIndex('total_surface',cat(2,{plants(1).variables.name}));


nplants = length(plants);
for iplant = 1:nplants
    
    datum_real = data(iplant);
    datum_sim = data_sim(iplant);
    plant = plants(iplant); % to store data and deploy in web
    
    % data
    Lsd_real = datum_real.variables(iLsd).value;
    Lsa_real = datum_real.variables(iLsa).value;
    Lsd_sim = datum_sim.variables(iLsd).value;
    Lsa_sim = datum_sim.variables(iLsa).value;
    
%     % plants parameters (will be shown in plant evaolution)
%     plantation_frame = plant.variables(iplantation_frame).value; 
%     number_of_plants = plant.variables(inumber_of_plants).value;
%     total_surface = plant.variables(itotal_surface).value;

    % PAST
    dataweb = [];
    ntime = length(Lsd_real);
    for itime=max(1,ntime-36):ntime
        % name of treatment
        % ad = Lsd_real(itime).ad;
        % sa_aa        
        sample_sa = Lsa_real(itime);
        sa = sample_sa.sai;
        aa = sample_sa.aa;
        % date
        t = sample_sa.t;
        month = shared_monthName(t.month);
        text_date = [month(1:3) num2str(t.year)];
        % get data
        text_var = prepare_plant_data([sa aa]);
        % prepare data
        dataweb = [dataweb...
                   text_date ':' ...
                   text_var ';' ...
                  ];
    end
    plant.variables(ifeet).value = dataweb;

    
    % PRESENT (if reset) OR LAST FUTURE
    dataweb = [];
    % name of treatment
    % ad = Lsd_sim(end).ad;
    % sa_aa
    sample_sa = Lsa_sim(end);
    sa = sample_sa.sai;
    aa = sample_sa.aa;
    % date
    t = sample_sa.t;
    month = shared_monthName(t.month);
    text_date = [month(1:3) num2str(t.year)];
    % get data
    text_var = prepare_plant_data([sa aa]);
    % prepare data
    dataweb = [dataweb...
               text_date ':' ...
               text_var ';' ...
              ];
    plant.variables(ibelly).value = dataweb;
    
    % FUTURE
    dataweb = [];
    ixs = length(Lsd_sim) - length(Lsd_real);
    Lsd = Lsd_sim(end-ixs:end);
    Lsa = Lsa_sim(end-ixs:end);
    ntime = length(Lsd);
    nstepfuture = 12;
    for itime=max(1,ntime-nstepfuture):ntime
        % name of treatment
        % ad = Lsd(itime).ad;
        % sa_aa
        sample_sa = Lsa(itime);
        sa = sample_sa.sai;
        aa = sample_sa.aa;
        % date
        t = sample_sa.t;
        month = shared_monthName(t.month);
        text_date = [month(1:3) num2str(t.year)];
        % get data
        text_var = prepare_plant_data([sa aa]);
        % prepare data
        dataweb = [dataweb...
                   text_date ':' ...
                   text_var ';' ...
                  ];
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
function text_var = prepare_plant_data(sa_aa)
% function [plant_size,...
%           plant_colorrgb,...
%           fruit_size,...
%           fruit_colorrgb,...
%           soil_W,...
%           soil_N,...
%           soil_P,...
%           soil_K,...
%           action_W,...
%           action_N,...
%           action_P,...
%           action_K,...
%           env_temperature,...
%           env_rain] = prepare_plant_data(sa_aa)


global sa_aa_variable_names
global sa_aa_variable_ranges
% global iplant_canopy_height...
%        iplant_canopy_width...
%        iplant_canopy_depth...
%        iplant_canopy_color...
%        ifruit_fall...
%        ifruit_production...
%        ifruit_brix...
%        isoil_W...
%        isoil_N...
%        isoil_P...
%        isoil_K...
%        iaction_W...
%        iaction_N...
%        iaction_P...
%        iaction_K...
%        ienv_temperature...
%        ienv_rain
%        % idep_fruit_volume

            
% global THR_YELLOW

text_var = [];
for ivar = 1:length(sa_aa_variable_names)-1
    var_norm = min(1,(sa_aa(ivar)-sa_aa_variable_ranges(ivar,1))/(sa_aa_variable_ranges(ivar,2)-sa_aa_variable_ranges(ivar,1)));
    text_var = [text_var num2str(var_norm) ':'];
end
var_norm = min(1,(sa_aa(end)-sa_aa_variable_ranges(end,1))/(sa_aa_variable_ranges(end,2)-sa_aa_variable_ranges(end,1)));
text_var = [text_var num2str(var_norm)];

% % plant size
% plant_size = (sa_aa(iplant_canopy_height)-sa_aa_variable_ranges(iplant_canopy_height,1))/(sa_aa_variable_ranges(iplant_canopy_height,2)-sa_aa_variable_ranges(iplant_canopy_height,1)) *...
%              (sa_aa(iplant_canopy_width)-sa_aa_variable_ranges(iplant_canopy_width,1))/(sa_aa_variable_ranges(iplant_canopy_width,2)-sa_aa_variable_ranges(iplant_canopy_width,1));
%              % (sa(iplant_canopy_depth)-sa_variable_ranges(iplant_canopy_depth,1))/(sa_variable_ranges(iplant_canopy_depth,2)-sa_variable_ranges(iplant_canopy_depth,1));
% % plant color
% plant_color = sa_aa(iplant_canopy_color);
% % plant_color = max(0,1/(0.2*plant_color + (1 - 1/0.2));
% plant_color_redscale = max(0,1/(1-THR_YELLOW)*plant_color + (1 - 1/(1-THR_YELLOW)));
% plant_colorrgbred = round(255*(1 - plant_color_redscale));
% plant_colorrgb = ['rgb(' num2str(plant_colorrgbred) ',255,0)'];   
% 
% 
% % fruit size
% fruit_size = min(1,(sa_aa(ifruit_production)-sa_aa_variable_ranges(ifruit_production,1))/...
%                    (sa_aa_variable_ranges(ifruit_production,2)-sa_aa_variable_ranges(ifruit_production,1)));
% % fruit color
% fruit_color = 1 - min(1,(sa_aa(ifruit_brix)-sa_aa_variable_ranges(ifruit_brix,1))/(sa_aa_variable_ranges(ifruit_brix,2)-sa_aa_variable_ranges(ifruit_brix,1)));
% fruit_color_redscale = fruit_color;
% fruit_colorrgbred = round(255*(1 - fruit_color_redscale));
% fruit_colorrgb = ['rgb(' num2str(fruit_colorrgbred) ',255,0)'];  
% 
% % soil
% soil_W = min(1,(sa_aa(isoil_W)-sa_aa_variable_ranges(isoil_W,1))/(sa_aa_variable_ranges(isoil_W,2)-sa_aa_variable_ranges(isoil_W,1)));
% soil_N = min(1,(sa_aa(isoil_N)-sa_aa_variable_ranges(isoil_N,1))/(sa_aa_variable_ranges(isoil_N,2)-sa_aa_variable_ranges(isoil_N,1)));
% soil_P = min(1,(sa_aa(isoil_P)-sa_aa_variable_ranges(isoil_P,1))/(sa_aa_variable_ranges(isoil_P,2)-sa_aa_variable_ranges(isoil_P,1)));
% soil_K = min(1,(sa_aa(isoil_K)-sa_aa_variable_ranges(isoil_K,1))/(sa_aa_variable_ranges(isoil_K,2)-sa_aa_variable_ranges(isoil_K,1)));
% 
% % action
% action_W = min(1,(sa_aa(iaction_W)-sa_aa_variable_ranges(iaction_W,1))/(sa_aa_variable_ranges(iaction_W,2)-sa_aa_variable_ranges(iaction_W,1)));
% action_N = min(1,(sa_aa(iaction_N)-sa_aa_variable_ranges(iaction_N,1))/(sa_aa_variable_ranges(iaction_N,2)-sa_aa_variable_ranges(iaction_N,1)));
% action_P = min(1,(sa_aa(iaction_P)-sa_aa_variable_ranges(iaction_P,1))/(sa_aa_variable_ranges(iaction_P,2)-sa_aa_variable_ranges(iaction_P,1)));
% action_K = min(1,(sa_aa(iaction_K)-sa_aa_variable_ranges(iaction_K,1))/(sa_aa_variable_ranges(iaction_K,2)-sa_aa_variable_ranges(iaction_K,1)));
% 
% % env
% env_temperature = min(1,(sa_aa(ienv_temperature)-sa_aa_variable_ranges(ienv_temperature,1))/(sa_aa_variable_ranges(ienv_temperature,2)-sa_aa_variable_ranges(ienv_temperature,1)));
% env_rain = min(1,(sa_aa(ienv_rain)-sa_aa_variable_ranges(ienv_rain,1))/(sa_aa_variable_ranges(ienv_rain,2)-sa_aa_variable_ranges(ienv_rain,1)));