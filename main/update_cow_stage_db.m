function update_cow_stage_db(results)

% UPDATE_COW_STAGE_DB Updates the alaive_vicow_zed_objects DB table with estimated stage probabilities.
%
% Takes estimated probabilities per cow and timestamp (from estimate_cow_stage_db),
% updates/adds the "stage" object structure, transforms to string using shared_obj2str.m,
% and writes back to the "val" field in the database.
%
% Inputs:
%   results - (Optional) Struct array output from estimate_cow_stage_db.
%             If omitted or empty, runs estimate_cow_stage_db().
%
% Agostini - 10.08.2026

if nargin < 1 || isempty(results)
    results = estimate_cow_stage_db();
end

% Ensure interface and shared folders are in MATLAB path
if exist('../interface', 'dir')
    addpath('../interface');
end
if exist('../shared', 'dir')
    addpath('../shared');
end

Ncows = length(results);

for icow = 1:Ncows
    cow_res = results(icow);
    cow_id = cow_res.cow_id;
    timestamps = cow_res.timestamps;
    belief = cow_res.belief;
    states = cow_res.state_names;

    Ntime = length(timestamps);

    for t = 1:Ntime
        time_str = timestamps{t};
        belief_t = belief(:, t);

        % 1. Fetch current val string from database for this cow and timestamp
        request = ['SELECT val FROM uniphyed.alaive_vicow_zed_objects ' ...
                   'WHERE var=''' cow_id ''' AND time=''' time_str ''' LIMIT 1'];
        val_str = mexSqlRequestRWText_uniphyed(request);

        % Parse current string into object struct array
        if isempty(val_str)
            objects = [];
        else
            objects = shared_str2obj(val_str);
        end

        % 2. Construct the updated "stage" variables
        stage_variables = [];
        for s = 1:length(states)
            var_struct.name = states{s};
            var_struct.id = 0;
            var_struct.type = 1;
            var_struct.role = {''};
            var_struct.value = belief_t(s);
            stage_variables = [stage_variables; var_struct]; %#ok<AGROW>
        end

        % Construct "stage" object struct
        stage_obj.name = 'stage';
        stage_obj.id = length(objects) + 1;
        stage_obj.type = 'object';
        stage_obj.variables = stage_variables;

        % Update existing "stage" object or append new one
        found = false;
        for k = 1:length(objects)
            if strcmp(objects(k).name, 'stage')
                objects(k).variables = stage_variables;
                found = true;
                break;
            end
        end

        if ~found
            if isempty(objects)
                objects = stage_obj;
            else
                objects = [objects; stage_obj];
            end
        end

        % 3. Convert object struct array back into string format using shared_obj2str
        new_val_str = shared_obj2str(objects);

        % 4. Write updated val string back to DB for this cow and timestamp
        request = ['UPDATE uniphyed.alaive_vicow_zed_objects ' ...
                   'SET val=''' new_val_str ''' ' ...
                   'WHERE var=''' cow_id ''' AND time=''' time_str ''''];
        mexSqlRequestRWScalar_uniphyed(request);
    end
end

end
