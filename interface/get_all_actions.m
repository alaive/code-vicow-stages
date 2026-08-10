function actions = get_all_actions


addpath ../interface

% nrows
request = 'SELECT COUNT(*) FROM alaive_plantar_lm_actions;';
nrows = mexSqlRequestRWScalar_uniphyed(request);
actions = [];
action_name_ant = '';
for irow = 0:nrows
    request = ['SELECT obj FROM uniphyed.alaive_plantar_lm_actions LIMIT 1 OFFSET ' num2str(irow)];
    action_name = mexSqlRequestRWText_uniphyed(request);
    if not(strcmp(action_name,action_name_ant))
        % store previous action
        if not(isempty(action_name_ant))
            action.variables = variables;
            actions = [actions;action];
        end
        % creat new action
        action.name = action_name;
        action.type = 1;
        variables = [];
        action_name_ant = action_name;
    end
    % add variable
    request = ['SELECT var FROM uniphyed.alaive_plantar_lm_actions LIMIT 1 OFFSET ' num2str(irow)];
    var_name = mexSqlRequestRWText_uniphyed(request);
    variable.name = var_name;
    request = ['SELECT val FROM uniphyed.alaive_plantar_lm_actions LIMIT 1 OFFSET ' num2str(irow)];
    var_val = mexSqlRequestRWScalar_uniphyed(request);
    variable.value = var_val;
    variable.type = 1;
    variable.id = 0;
    request = ['SELECT time FROM uniphyed.alaive_plantar_lm_actions LIMIT 1 OFFSET ' num2str(irow)];
    day = mexSqlRequestRWText_uniphyed(request);
    variable.time = day;
    variables = [variables;variable]; 
end

