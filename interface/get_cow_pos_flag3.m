function cows = get_cow_pos_flag3()

% Reads all rows from uniphyed.alaive_vicow_zed_objects where flag = 3.
% Uses shared_str2obj to convert val_str into object structs.
% Extracts "standing" and "arched" variables from the "pos" object.
% Unifies values from multiple cameras for each cow at each time step to assign
% the most likely (mode/majority vote) value of standing and arched.
%
% Returns a struct array `cows` with fields:
%   cows(i).cow_id   - String ID of the cow (from "var" field)
%   cows(i).pos_list - Cell array of struct records in chronological order:
%                        record.time     : Timestamp string (unique per time step)
%                        record.standing : Single unified most likely value
%                        record.arched   : Single unified most likely value
%                        record.cams     : Cell array of camera names (from "obj" field)
%
% Agostini - 10.08.2026

% Ensure shared folder is in path
if exist('../shared', 'dir')
    addpath('../shared');
elseif exist('shared', 'dir')
    addpath('shared');
end

% Query number of matching rows
request = 'SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;';
nrows = mexSqlRequestRWScalar_uniphyed(request);

% 1. Gather all raw records
raw_records = struct('time', {}, 'obj', {}, 'cow_id', {}, 'standing', {}, 'arched', {});

for irow = 0:nrows-1

    % Time field
    request = ['SELECT time FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    time_str = mexSqlRequestRWText_uniphyed(request);

    % Obj field (Camera name)
    request = ['SELECT obj FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    obj_str = mexSqlRequestRWText_uniphyed(request);

    % Var field (Cow ID)
    request = ['SELECT var FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    cow_id = mexSqlRequestRWText_uniphyed(request);

    % Val field
    request = ['SELECT val FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    val_str = mexSqlRequestRWText_uniphyed(request);

    % Convert val string to object struct
    objects = shared_str2obj(val_str);

    % Extract "standing" and "arched" variables from "pos" object
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

    raw_records(end+1).time = time_str; %#ok<AGROW>
    raw_records(end).obj = obj_str;
    raw_records(end).cow_id = cow_id;
    raw_records(end).standing = standing_val;
    raw_records(end).arched = arched_val;
end

% 2. Group by cow_id and unify per time step
cows = struct('cow_id', {}, 'pos_list', {});
all_cow_ids = unique({raw_records.cow_id}, 'stable');

for icow = 1:length(all_cow_ids)
    current_cow_id = all_cow_ids{icow};
    cows(icow).cow_id = current_cow_id;
    cows(icow).pos_list = {};

    % Filter records for current cow
    idx_cow = strcmp({raw_records.cow_id}, current_cow_id);
    cow_recs = raw_records(idx_cow);

    % Get unique timestamps in chronological order
    unique_times = unique({cow_recs.time}, 'stable');

    for itime = 1:length(unique_times)
        current_time = unique_times{itime};

        % Find all camera observations at this time step
        idx_time = strcmp({cow_recs.time}, current_time);
        time_recs = cow_recs(idx_time);

        % Collect values across cameras
        cams = {time_recs.obj};
        standing_vals = [time_recs.standing];
        arched_vals = [time_recs.arched];

        % Determine most likely values (mode / majority vote)
        standing_unified = get_most_likely(standing_vals);
        arched_unified = get_most_likely(arched_vals);

        % Save unified record
        record.time = current_time;
        record.cams = cams;
        record.standing = standing_unified;
        record.arched = arched_unified;

        cows(icow).pos_list{end+1} = record;
    end
end

end

% Helper function: compute most likely value (mode / majority vote)
function most_likely = get_most_likely(vals)
    if isempty(vals)
        most_likely = [];
        return;
    end

    if iscell(vals)
        % Filter empty cells
        valid_mask = ~cellfun(@isempty, vals);
        vals = vals(valid_mask);
        if isempty(vals)
            most_likely = [];
            return;
        end
        if all(cellfun(@isnumeric, vals))
            vals = cell2mat(vals);
        end
    end

    if isnumeric(vals) || islogical(vals)
        vals = vals(~isnan(vals));
        if isempty(vals)
            most_likely = [];
        else
            most_likely = mode(vals);
        end
    elseif iscell(vals)
        [uvals, ~, idx] = unique(vals);
        counts = accumarray(idx, 1);
        [~, max_idx] = max(counts);
        most_likely = uvals{max_idx};
    else
        most_likely = vals(1);
    end
end
