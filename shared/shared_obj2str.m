function string = shared_obj2str(objects)
 
% Agostini - 10.08.2026


string = [];
for i=1:length(objects)
    objname = objects(i).name;
    variables = objects(i).variables;
    if not(isempty(variables))
        nvar = length(variables);
        text_var = [];
        for j = 1:nvar-1
            varname = variables(j).name;
            varvalue = variables(j).value;
            % text_var = [text_var varname ',' num2str(varvalue)];
            bcell = iscell(varvalue);
            if bcell
                nval = length(varvalue);
                for ival = 1:nval
                    text_var = [text_var varname ',' num2str(varvalue{ival}) ':'];
                end
            else
                text_var = [text_var varname ',' num2str(varvalue) ':'];
            end
        end
        varname = variables(end).name;
        varvalue = variables(end).value;
        % text_var = [text_var varname ',' num2str(varvalue)];
        bcell = iscell(varvalue);    
        if bcell
            nval = length(varvalue);
            for ival = 1:nval-1
                text_var = [text_var varname ',' num2str(varvalue{ival}) ':'];
            end
            text_var = [text_var varname ',' num2str(varvalue{ival})];
        else
            text_var = [text_var varname ',' num2str(varvalue)];
        end
            
    else
        text_var = 'null,null';
    end
    
    % prepare data
    string = [string...
               objname ':' ...
               text_var ';' ...
              ];
end