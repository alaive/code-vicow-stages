function [cows, raw_records] = get_zed_objects_flag3()

% Reads all rows from uniphyed.alaive_vicow_zed_objects where flag = 3 in chronological order.
% Uses shared_str2obj to convert val_str into an object struct.
% Unifies readings from multiple cameras (obj) for each cow (var) in a single time step
% and assigns the most likely (mode/majority vote) value of standing and arched.
%
% Outputs:
%   cows - Struct array where each element contains data for one cow:
%            cows(i).cow_id   : Cow ID (from field "var")
%            cows(i).pos_list : Cell array of records sorted chronologically:
%                                 record.time     (time field string)
%                                 record.cams     (cell array of camera obj strings)
%                                 record.standing (most likely standing value)
%                                 record.arched   (most likely arched value)
%
%   raw_records - (Optional) Cell array of raw database entries per camera before unification
%
% Agostini - 10.08.2026

% Ensure shared folder is in MATLAB path
if exist('../shared', 'dir')
    addpath('../shared');
elseif exist('shared', 'dir')
    addpath('shared');
end

% Count matching rows
request = 'SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;';
nrows = mexSqlRequestRWScalar_uniphyed(request);

raw_list = struct('time', {}, 'obj', {}, 'cow_id', {}, 'standing', {}, 'arched', {});
raw_records = {};

for irow = 0:nrows-1

    % Fetch fields in chronological order (ORDER BY time ASC)
    request = ['SELECT time FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    time_str = mexSqlRequestRWText_uniphyed(request);

    request = ['SELECT obj FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    obj_str = mexSqlRequestRWText_uniphyed(request);

    request = ['SELECT var FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    cow_id = mexSqlRequestRWText_uniphyed(request);

    request = ['SELECT val FROM uniphyed.alaive_vicow_zed_objects ' ...
               'WHERE flag = 3 ORDER BY time ASC LIMIT 1 OFFSET ' num2str(irow)];
    val_str = mexSqlRequestRWText_uniphyed(request);

    % Convert string into object struct array using shared_str2obj
    objects = shared_str2obj(val_str);

    % Extract standing and arched values from "pos" object
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

    raw_list(end+1).time = time_str; %#ok<AGROW>
    raw_list(end).obj = obj_str;
    raw_list(end).cow_id = cow_id;
    raw_list(end).standing = standing_val;
    raw_list(end).arched = arched_val;

    if nargout > 1
        raw_records{end+1} = {time_str, obj_str, cow_id, val_str, objects}; %#ok<AGROW>
    end
end

% Group by cow_id and unify multiple camera observations per time step
cows = struct('cow_id', {}, 'pos_list', {});
all_cow_ids = unique({raw_list.cow_id}, 'stable');

for icow = 1:length(all_cow_ids)
    current_cow_id = all_cow_ids{icow};
    cows(icow).cow_id = current_cow_id;
    cows(icow).pos_list = {};

    % Filter records for current cow
    idx_cow = strcmp({raw_list.cow_id}, current_cow_id);
    cow_recs = raw_list(idx_cow);

    % Unique time steps in chronological order
    unique_times = unique({cow_recs.time}, 'stable');

    for itime = 1:length(unique_times)
        current_time = unique_times{itime};

        % Observations across cameras at current time step
        idx_time = strcmp({cow_recs.time}, current_time);
        time_recs = cow_recs(idx_time);

        cams = {time_recs.obj};
        standing_vals = [time_recs.standing];
        arched_vals = [time_recs.arched];

        % Determine single most likely value (mode/majority vote)
        standing_unified = get_most_likely(standing_vals);
        arched_unified = get_most_likely(arched_vals);

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
