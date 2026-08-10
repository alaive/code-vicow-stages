function objects = shared_str2obj(string, vartype)

% Convert string format obj:var,val; into object struct
% 
% Agostini - 10.08.2026

if nargin < 2
    vartype = 1;
end

% get objects from string
cobjects = split(string,';');
cobjects = cobjects(1:end-1); % last one is empty.
nobj = length(cobjects);
objects = [];
for iobj = 1:nobj
    % get variables
    cvariables = split(cobjects{iobj},':');
    object.name = cvariables{1};
    object.id = iobj;
    object.type = 'object';
    variables = [];
    cvariables = cvariables(2:end);
    nvar = length(cvariables);
    for ivar = 1:nvar
        cvarval = split(cvariables{ivar},',');
        variable.name = cvarval{1};
        variable.id = 0;
        variable.type = vartype;
        variable.role = {''};
        val_num = str2double(cvarval{2});
        if ~isnan(val_num) || strcmp(cvarval{2}, 'NaN')
            variable.value = val_num; 
        else
            variable.value = cvarval{2};
        end
        variables = [variables;variable];
    end
    object.variables = variables;
    objects = [objects;object];
end