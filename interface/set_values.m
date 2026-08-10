function set_values(objects,table_name,scenario_name,vivar_to_update)

% set values in table_name.
% 
% Agostini - 14.12.2018

% Agostini - 03.08.2023 - set per variable_name

nobj = length(objects);
nvar = length(vivar_to_update);
for ivar = 1:nvar
    ivar_to_update = vivar_to_update(ivar);
    for iobj = 1:nobj
        object = objects(iobj);
        variable = object.variables(ivar_to_update);
        objname = object.name;
        varname = variable.name;
        varvalue = variable.value;
        time = variable.time;
        write_value(time,objname,varname,varvalue,table_name,scenario_name);
    end
end

% for i=1:length(objects)
%     objname = objects(i).name;
%     variables = objects(i).variables;
%     for j = 1:length(variables)
%         varname = variables(j).name;
%         varvalue = variables(j).value;
%         time = variables(j).time;
%         write_value(time,objname,varname,varvalue,table_name,scenario_name);
%     end
% end

function write_value(time,objname,varname,varvalue,table_name,scenario_name)
if not(ischar(varvalue))
    request = ['update ' scenario_name '_' table_name ' set val=' num2str(varvalue) ', flag=0 where obj=''' objname ''' and var=''' varname ''' and time = ''' num2str(time) ''''];  
else
    request = ['update ' scenario_name '_' table_name ' set val=''' varvalue ''', flag=0 where obj=''' objname ''' and var=''' varname ''' and time = ''' num2str(time) ''''];
end
mexSqlRequestRWScalar_uniphyed(request);