function actions = update_all_actions(actions)

% NOTE: This function is ad-hoc to add months July and August for a
% 14-months simulation.
%
% Agostini - 29.12.2024

addpath ../interface

nactions = length(actions);
for iaction = 1:nactions
    action = actions(iaction);
    action_name = action.name;
    c = split(action_name,'_');
    action_name = join(c(1:end-1),'_');
    if not(strcmp(action_name,'treatment_for_simulator'))
        
        variables = action.variables;
        % get last time
        last_time = variables(end).time;
        % get actions with last time
        times = cat(1,{variables.time});
        ixs = getIndex(last_time,times);
        naction_var = length(ixs);
        % add one months
        c = split(last_time,'-');
        c{2} = ['0' num2str(str2double(c{2}) + 1)];
        last_time = join(c,'-'); 
        for iaction_var = 1:naction_var
            var_name = variables(ixs(iaction_var)).name;
            var_value = variables(ixs(iaction_var)).value;
            variable.name = var_name;
            variable.value = var_value;
            variable.type = 1;
            variable.id = 0;
            variable.time = last_time{:};
            variables = [variables;variable]; 
        end
        % add one months
        c = split(last_time,'-');
        c{2} = ['0' num2str(str2double(c{2}) + 1)];
        last_time = join(c,'-'); 
        for iaction_var = 1:naction_var
            var_name = variables(ixs(iaction_var)).name;
            var_value = variables(ixs(iaction_var)).value;
            variable.name = var_name;
            variable.value = var_value;
            variable.type = 1;
            variable.id = 0;
            variable.time = last_time{:};
            variables = [variables;variable]; 
        end
        action.variables = variables;
        actions(iaction) = action;
        
    elseif strcmp(c{end},'12')
        
        action.name = [action_name{:} '_13'];
        variablesx = action.variables;
        % get last time
        last_time = variablesx(end).time;
        % get actions with last time
        times = cat(1,{variablesx.time});
        ixs = getIndex(last_time,times);
        naction_var = length(ixs);
        % add one months
        c = split(last_time,'-');
        c{2} = ['0' num2str(str2double(c{2}) + 1)];
        last_time = join(c,'-'); 
        variables = [];
        for iaction_var = 1:naction_var
            var_name = variablesx(ixs(iaction_var)).name;
            var_value = variablesx(ixs(iaction_var)).value;
            variable.name = var_name;
            variable.value = var_value;
            variable.type = 1;
            variable.id = 0;
            variable.time = last_time{:};
            variables = [variables;variable]; 
        end
        
        action.variables = variables;
        actions = [actions;action];
        
        % last action for simulator
        action.name = [action_name{:} '_14'];
        % add one months
        c = split(last_time,'-');
        c{2} = ['0' num2str(str2double(c{2}) + 1)];
        last_time = join(c,'-'); 
        variables = [];
        for iaction_var = 1:naction_var
            var_name = variablesx(ixs(iaction_var)).name;
            var_value = variablesx(ixs(iaction_var)).value;
            variable.name = var_name;
            variable.value = var_value;
            variable.type = 1;
            variable.id = 0;
            variable.time = last_time{:};
            variables = [variables;variable]; 
        end
        action.variables = variables;
        actions = [actions;action];
        
    end
end