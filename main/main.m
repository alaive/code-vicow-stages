function main()

% MAIN Continuous server loop to monitor uniphyed.alaive_vicow_zed_objects for flag = 3.
%
% Displays progress messages on screen for every processing step:
%   Step 1: Check database for flag = 3
%   Step 2: Identify unique cow IDs with flag = 3
%   Step 3: Retrieve full observation history per cow
%   Step 4: Unify camera observations per timestamp
%   Step 5: Estimate calving stage probabilities using Bayesian filtering
%   Step 6: Convert object structures to string using shared_obj2str.m
%   Step 7: Write updated stage probabilities into DB val field
%   Step 8: Reset flag = 0 for processed entries
%
% Agostini - 10.08.2026

% Add interface and shared directories to path
if exist('../interface', 'dir')
    addpath('../interface');
    fprintf('[SETUP] Added ../interface to path.\n');
end
if exist('../shared', 'dir')
    addpath('../shared');
    fprintf('[SETUP] Added ../shared to path.\n');
end

fprintf('=======================================================\n');
fprintf('  Calving Stage Probability Estimation Server Active  \n');
fprintf('  Monitoring uniphyed.alaive_vicow_zed_objects (flag = 3)\n');
fprintf('=======================================================\n\n');

pause_interval = 5; % Polling interval in seconds

while true
    try
        % Step 1: Query database for entries requiring processing (flag = 3)
        fprintf('[%s] Step 1: Checking database for entries with flag = 3...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        request = 'SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;';
        nrows = mexSqlRequestRWScalar_uniphyed(request);

        if nrows > 0
            fprintf('[%s] Step 1 Complete: Found %d row(s) with flag = 3.\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), nrows);

            % Step 2: Identify distinct cow IDs matching flag = 3
            fprintf('[%s] Step 2: Identifying cows associated with flag = 3...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            cows_to_process = get_cows_with_flag3();
            fprintf('[%s] Step 2 Complete: Found %d unique cow(s) to process: [%s]\n', ...
                datestr(now, 'yyyy-mm-dd HH:MM:SS'), length(cows_to_process), strjoin(cows_to_process, ', '));

            for icow = 1:length(cows_to_process)
                cow_id = cows_to_process{icow};
                fprintf('\n-------------------------------------------------------\n');
                fprintf('  Processing Cow %d/%d: ID = %s\n', icow, length(cows_to_process), cow_id);
                fprintf('-------------------------------------------------------\n');

                % Step 3: Fetch full observation history for this cow across all flags
                fprintf('[%s] Step 3: Retrieving observation history for Cow ID: %s...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), cow_id);
                cow_data = get_cow_full_history(cow_id);
                fprintf('[%s] Step 3 Complete: Retrieved %d time step(s) of history.\n', ...
                    datestr(now, 'yyyy-mm-dd HH:MM:SS'), length(cow_data.pos_list));

                if ~isempty(cow_data) && ~isempty(cow_data.pos_list)
                    % Step 4: Estimate calving stage probabilities
                    fprintf('[%s] Step 4: Estimating stage probabilities via Bayesian filter...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                    results = estimate_cow_stage_history(cow_data);
                    fprintf('[%s] Step 4 Complete: Probabilities estimated for %d time steps.\n', ...
                        datestr(now, 'yyyy-mm-dd HH:MM:SS'), size(results.belief, 2));

                    % Step 5 & 6: Update stage object, transform using shared_obj2str, write to DB
                    fprintf('[%s] Step 5 & 6: Transforming objects with shared_obj2str.m and writing to DB...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                    update_cow_stage_db_verbose(results);
                    fprintf('[%s] Step 5 & 6 Complete: DB val field updated successfully.\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

                    % Step 7: Reset flag to 0 for processed entries of this cow
                    fprintf('[%s] Step 7: Resetting flag = 0 for Cow ID: %s...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), cow_id);
                    request = ['UPDATE uniphyed.alaive_vicow_zed_objects SET flag = 0 ' ...
                               'WHERE var=''' cow_id ''' AND flag = 3;'];
                    mexSqlRequestRWScalar_uniphyed(request);
                    fprintf('[%s] Step 7 Complete: Flag set to 0 for Cow ID: %s.\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), cow_id);
                end
            end
            fprintf('\n[%s] Finished processing batch. Standing by...\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        else
            fprintf('[%s] Step 1: No entries with flag = 3. Waiting...\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        end

    catch ME
        fprintf('[%s] ERROR during processing: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ME.message);
    end

    pause(pause_interval);
end

end


%% Helper Function: Get list of unique cow IDs with flag = 3
function cows_list = get_cows_with_flag3()
request = 'SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;';
nrows = mexSqlRequestRWScalar_uniphyed(request);

cows_list = {};
for irow = 0:nrows-1
    request = ['SELECT var FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 LIMIT 1 OFFSET ' num2str(irow)];
    cow_id = mexSqlRequestRWText_uniphyed(request);

    if ~isempty(cow_id) && ~any(strcmp(cows_list, cow_id))
        cows_list{end+1} = cow_id; %#ok<AGROW>
    end
end
end


%% Helper Function: Get full observation history for a single cow across all flags
function cow_data = get_cow_full_history(cow_id)

request = ['SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE var=''' cow_id ''';'];
nrows = mexSqlRequestRWScalar_uniphyed(request);

raw_recs = struct('time', {}, 'obj', {}, 'standing', {}, 'arched', {});

for irow = 0:nrows-1
    request = ['SELECT time FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE var=''' cow_id ''' ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    time_str = mexSqlRequestRWText_uniphyed(request);

    request = ['SELECT obj FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE var=''' cow_id ''' ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    obj_str = mexSqlRequestRWText_uniphyed(request);

    request = ['SELECT val FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE var=''' cow_id ''' ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    val_str = mexSqlRequestRWText_uniphyed(request);

    objects = shared_str2obj(val_str);

    standing_val = [];
    arched_val = [];
    for iobj = 1:length(objects)
        if strcmp(objects(iobj).name, 'pos')
            vars = objects(iobj).variables;
            for ivar = 1:length(vars)
                if strcmp(vars(ivar).name, 'standing')
                    standing_val = vars(ivar).value;
                elseif strcmp(vars(ivar).name, 'arched')
                    arched_val = vars(ivar).value;
                end
            end
            break;
        end
    end

    raw_recs(end+1).time = time_str; %#ok<AGROW>
    raw_recs(end).obj = obj_str;
    raw_recs(end).standing = standing_val;
    raw_recs(end).arched = arched_val;
end

% Unify camera observations per timestamp
cow_data.cow_id = cow_id;
cow_data.pos_list = {};

if isempty(raw_recs)
    return;
end

unique_times = unique({raw_recs.time}, 'stable');
for itime = 1:length(unique_times)
    current_time = unique_times{itime};
    idx_time = strcmp({raw_recs.time}, current_time);
    time_recs = raw_recs(idx_time);

    cams = {time_recs.obj};
    standing_vals = {time_recs.standing};
    arched_vals = {time_recs.arched};

    standing_unified = get_most_likely(standing_vals);
    arched_unified = get_most_likely(arched_vals);

    record.time = current_time;
    record.cams = cams;
    record.standing = standing_unified;
    record.arched = arched_unified;

    cow_data.pos_list{end+1} = record;
end

end


%% Helper Function: Estimate stage probabilities for a single cow history
function results = estimate_cow_stage_history(cow_data, start_day)

if nargin < 2 || isempty(start_day)
    start_day = 270;
end

states = {'Normal', 'Preparatory', 'Labour', 'Transition', 'Calving'};
Nstates = length(states);

A_1day = [
    0.94  0.06  0     0     0;
    0     0.75  0.25  0     0;
    0     0     0.60  0.40  0;
    0     0     0     0.30  0.70;
    0     0     0     0     1
];
Q = real(logm(A_1day));

ObservationModel = [
    0.90 0.08 0.01 0.01;
    0.50 0.40 0.08 0.02;
    0.10 0.35 0.50 0.05;
    0.05 0.15 0.75 0.05;
    0.01 0.05 0.90 0.04
];

pos_list = cow_data.pos_list;
Ntime = length(pos_list);

timestamps = cell(1, Ntime);
time_num = zeros(1, Ntime);
observations = zeros(1, Ntime);

for t = 1:Ntime
    rec = pos_list{t};
    timestamps{t} = rec.time;

    try
        time_num(t) = datenum(rec.time);
    catch
        time_num(t) = str2double(rec.time) / 86400;
    end

    st_val = to_scalar_num(rec.standing);
    ar_val = to_scalar_num(rec.arched);

    if st_val == 1 && ar_val == 0
        obs = 1;
    elseif st_val == 1 && ar_val == 1
        obs = 2;
    elseif st_val == 0 && ar_val == 1
        obs = 3;
    else
        obs = 4;
    end
    observations(t) = obs;
end

days_elapsed = time_num - time_num(1);
preg_days = start_day + days_elapsed;

belief = zeros(Nstates, Ntime);
belief(:, 1) = [1; 0; 0; 0; 0];

obs1 = observations(1);
preg1 = pregnancyLikelihood_local(preg_days(1));
init_num = belief(:, 1) .* ObservationModel(:, obs1) .* preg1;
belief(:, 1) = init_num / sum(init_num);

for t = 2:Ntime
    dt = time_num(t) - time_num(t-1);

    if dt > 0
        A_dt = real(expm(Q * dt));
        A_dt = max(A_dt, 0);
        A_dt = A_dt ./ sum(A_dt, 2);
    else
        A_dt = eye(Nstates);
    end

    prediction = A_dt' * belief(:, t-1);
    pregnancy = pregnancyLikelihood_local(preg_days(t));
    obs = observations(t);
    observationLikelihood = ObservationModel(:, obs);

    numerator = prediction .* observationLikelihood .* pregnancy;

    if sum(numerator) > 0
        belief(:, t) = numerator / sum(numerator);
    else
        belief(:, t) = prediction / sum(prediction);
    end
end

[~, most_likely_stage] = max(belief, [], 1);

results.cow_id = cow_data.cow_id;
results.timestamps = timestamps;
results.days = preg_days;
results.observations = observations;
results.belief = belief;
results.most_likely_stage = most_likely_stage;
results.state_names = states;

end


%% Helper Function: Verbose DB stage probability update
function update_cow_stage_db_verbose(results)

cow_id = results.cow_id;
timestamps = results.timestamps;
belief = results.belief;
states = results.state_names;
Ntime = length(timestamps);

for t = 1:Ntime
    time_str = timestamps{t};
    belief_t = belief(:, t);

    request = ['SELECT val FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE var=''' cow_id ''' AND time=''' time_str ''' LIMIT 1'];
    val_str = mexSqlRequestRWText_uniphyed(request);

    if isempty(val_str)
        objects = [];
    else
        objects = shared_str2obj(val_str);
    end

    stage_variables = [];
    for s = 1:length(states)
        var_struct.name = states{s};
        var_struct.id = 0;
        var_struct.type = 1;
        var_struct.role = {''};
        var_struct.value = belief_t(s);
        stage_variables = [stage_variables; var_struct]; %#ok<AGROW>
    end

    stage_obj.name = 'stage';
    stage_obj.id = length(objects) + 1;
    stage_obj.type = 'object';
    stage_obj.variables = stage_variables;

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

    new_val_str = shared_obj2str(objects);

    request = ['UPDATE uniphyed.alaive_vicow_zed_objects ' ...
               'SET val=''' new_val_str ''' ' ...
               'WHERE var=''' cow_id ''' AND time=''' time_str ''''];
    mexSqlRequestRWScalar_uniphyed(request);

    fprintf('    [Time: %s] Updated DB val string: %s\n', time_str, new_val_str);
end

end


%% Helper Function: Safely convert input value to a scalar double
function num = to_scalar_num(x)
if isempty(x)
    num = 0;
    return;
end
if iscell(x)
    x = x{1};
end
if ischar(x) || isstring(x)
    num = str2double(x);
    if isnan(num), num = 0; end
elseif isnumeric(x) || islogical(x)
    if isempty(x)
        num = 0;
    else
        num = double(x(1));
        if isnan(num), num = 0; end
    end
else
    num = 0;
end
end


%% Helper Function: Compute pregnancy likelihood
function Pg = pregnancyLikelihood_local(day)
Pg = zeros(5, 1);
Pg(1) = 1 / (1 + exp((day - 255) / 8));
Pg(2) = exp(-(day - 270)^2 / (2 * 10^2));
Pg(3) = exp(-(day - 280)^2 / (2 * 4^2));
Pg(4) = exp(-(day - 284)^2 / (2 * 2^2));
Pg(5) = exp(-(day - 285)^2 / (2 * 0.7^2));

sumPg = sum(Pg);
if sumPg > 0
    Pg = Pg / sumPg;
else
    Pg = ones(5, 1) / 5;
end
end


%% Helper Function: Mode / Majority vote (guaranteed scalar output)
function most_likely = get_most_likely(vals)
if isempty(vals)
    most_likely = 0;
    return;
end

if iscell(vals)
    valid_vals = {};
    for k = 1:length(vals)
        if ~isempty(vals{k})
            valid_vals{end+1} = vals{k}; %#ok<AGROW>
        end
    end
    vals = valid_vals;
    if isempty(vals)
        most_likely = 0;
        return;
    end
    
    % Check if all elements are numeric
    all_num = true;
    for k = 1:length(vals)
        if ~isnumeric(vals{k}) && ~islogical(vals{k})
            all_num = false;
            break;
        end
    end
    if all_num
        num_arr = zeros(1, length(vals));
        for k = 1:length(vals)
            num_arr(k) = double(vals{k}(1));
        end
        vals = num_arr;
    end
end

if isnumeric(vals) || islogical(vals)
    vals = vals(~isnan(vals));
    if isempty(vals)
        most_likely = 0;
    else
        most_likely = mode(vals);
    end
elseif iscell(vals)
    [uvals, ~, idx] = unique(vals);
    counts = accumarray(idx, 1);
    [~, max_idx] = max(counts);
    most_likely = uvals{max_idx};
else
    most_likely = 0;
end

if isempty(most_likely)
    most_likely = 0;
end
end