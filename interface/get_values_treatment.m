function objects = get_values(objects,table_name,scenario_name)

% get values from table_name.
% 
% Agostini - 14.12.2018

for i=1:length(objects)
    objname = objects(i).name;
    variables = objects(i).variables;
    for j = 1:length(variables)
        id = variables(j).id;
        varname = variables(j).name;
        value = read_value(id,objname,varname,table_name,scenario_name);
        variables(j).value = value;
        time = read_time(id,objname,varname,table_name,scenario_name);
        variables(j).time = time;
    end
    objects(i).variables = variables;
end


function val = read_value(id,objname,varname,table_name,scenario_name)
request = ['select val from ' scenario_name '_' table_name ' where id=' num2str(id) ' and obj=''' objname ''' and var=''' varname ''''];  
val = mexSqlRequestRWScalar_uniphyed(request);
request = ['update ' scenario_name '_' table_name ' set flag = 1 where obj=''' objname ''' and var=''' varname ''''];
mexSqlRequestRWScalar_uniphyed(request);

function time = read_time(id,objname,varname,table_name,scenario_name)
request = ['select time from ' scenario_name '_' table_name ' where id=' num2str(id) ' and obj=''' objname ''' and var=''' varname ''''];  
time = mexSqlRequestRWScalar_uniphyed(request);
request = ['update ' scenario_name '_' table_name ' set flag = 1 where obj=''' objname ''' and var=''' varname ''''];
mexSqlRequestRWScalar_uniphyed(request);


%select DATE_FORMAT(time, "%M") from uniphyed.alaive_plantar_lm_actions where var="action_W01"