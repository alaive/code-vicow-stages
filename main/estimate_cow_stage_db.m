function results = estimate_cow_stage_db(start_day)

% ESTIMATE_COW_STAGE_DB Estimates calving stage probabilities for each cow using DB observations.
%
% Based on test_example.m (Bayesian Filter for Cow Calving Stage Estimation).
%
% Adaptation for Continuous Timestamps:
%   - Reads unified observations from uniphyed.alaive_vicow_zed_objects via get_cow_pos_flag3.
%   - Converts string timestamps into fractional days elapsed (datenum/datetime).
%   - Adapts the 1-day state transition matrix A to arbitrary time steps delta_t (in days)
%     using the matrix exponential of the transition rate matrix Q = logm(A):
%         A(delta_t) = expm(Q * delta_t)
%   - Evaluates pregnancy likelihood at exact continuous pregnancy day:
%         day_k = start_day + (t_k - t_1)
%
% Inputs:
%   start_day - (Optional) Initial pregnancy day for the first observation (default: 270)
%
% Outputs:
%   results - Struct array per cow containing:
%               results(i).cow_id            : String ID of cow
%               results(i).timestamps        : Cell array of timestamp strings
%               results(i).days              : Array of continuous pregnancy days
%               results(i).observations      : Array of observation codes (1..4)
%               results(i).belief            : 5 x N matrix of stage probabilities over time
%               results(i).most_likely_stage : 1 x N array of estimated stage indices (1..5)
%               results(i).state_names       : Cell array of state names
%
% Agostini - 10.08.2026

if nargin < 1 || isempty(start_day)
    start_day = 270; % Default initial pregnancy day
end

% Ensure interface and shared folders are in path
if exist('../interface', 'dir')
    addpath('../interface');
end
if exist('../shared', 'dir')
    addpath('../shared');
end

%% State Definitions
states = {'Normal', 'Preparatory', 'Labour', 'Transition', 'Calving'};
Nstates = length(states);

%% Base 1-day Transition Matrix (from test_example.m)
% P(x_t | x_{t-1}) for delta_t = 1 day
A_1day = [
    0.94  0.06  0     0     0;
    0     0.75  0.25  0     0;
    0     0     0.60  0.40  0;
    0     0     0     0.30  0.70;
    0     0     0     0     1
];

% Transition rate matrix Q (infinitesimal generator: logm(A))
Q = real(logm(A_1day));

%% Observation Model P(o_t | x_t)
ObservationModel = [
    0.90 0.08 0.01 0.01;   % Normal
    0.50 0.40 0.08 0.02;   % Preparatory
    0.10 0.35 0.50 0.05;   % Labour
    0.05 0.15 0.75 0.05;   % Transition
    0.01 0.05 0.90 0.04    % Calving
];

%% Read Cow Data from DB
cows = get_cow_pos_flag3();

Ncows = length(cows);
results = struct('cow_id', {}, 'timestamps', {}, 'days', {}, ...
                 'observations', {}, 'belief', {}, ...
                 'most_likely_stage', {}, 'state_names', {});

for icow = 1:Ncows
    cow = cows(icow);
    pos_list = cow.pos_list;
    Ntime = length(pos_list);

    if Ntime == 0
        continue;
    end

    timestamps = cell(1, Ntime);
    time_num = zeros(1, Ntime);
    observations = zeros(1, Ntime);

    % Extract timestamps and convert standing/arched to observation code (1..4)
    for t = 1:Ntime
        rec = pos_list{t};
        timestamps{t} = rec.time;

        % Parse string timestamp to datenum (fractional days)
        try
            time_num(t) = datenum(rec.time);
        catch
            % Fallback if numeric string or timestamp format differs
            time_num(t) = str2double(rec.time) / 86400; % unix timestamp to days
        end

        st_val = to_scalar_num(rec.standing);
        ar_val = to_scalar_num(rec.arched);

        % Encode observation:
        % 1 = Standing + not arched
        % 2 = Standing + arched
        % 3 = Lying + arched
        % 4 = Lying + not arched
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

    % Calculate continuous pregnancy days relative to initial observation
    days_elapsed = time_num - time_num(1);
    preg_days = start_day + days_elapsed;

    %% Bayesian Filtering Loop with Continuous-Time Adaptation
    belief = zeros(Nstates, Ntime);
    
    % Initial belief: Cow assumed Normal at start
    belief(:, 1) = [1; 0; 0; 0; 0];
    
    % Initial observation update for t = 1
    obs1 = observations(1);
    preg1 = pregnancyLikelihood(preg_days(1));
    init_num = belief(:, 1) .* ObservationModel(:, obs1) .* preg1;
    belief(:, 1) = init_num / sum(init_num);

    for t = 2:Ntime
        dt = time_num(t) - time_num(t-1); % elapsed time in days

        if dt > 0
            % Adapt transition matrix to time step dt using matrix exponential
            A_dt = real(expm(Q * dt));
            % Normalize rows and ensure non-negative probabilities
            A_dt = max(A_dt, 0);
            A_dt = A_dt ./ sum(A_dt, 2);
        else
            A_dt = eye(Nstates);
        end

        % Prediction step
        prediction = A_dt' * belief(:, t-1);

        % Pregnancy prior at exact continuous day
        pregnancy = pregnancyLikelihood(preg_days(t));

        % Observation likelihood
        obs = observations(t);
        observationLikelihood = ObservationModel(:, obs);

        % Bayesian update
        numerator = prediction .* observationLikelihood .* pregnancy;
        
        if sum(numerator) > 0
            belief(:, t) = numerator / sum(numerator);
        else
            belief(:, t) = prediction / sum(prediction);
        end
    end

    % Determine most likely stage at each timestamp
    [~, most_likely_stage] = max(belief, [], 1);

    % Store results for current cow
    results(icow).cow_id = cow.cow_id;
    results(icow).timestamps = timestamps;
    results(icow).days = preg_days;
    results(icow).observations = observations;
    results(icow).belief = belief;
    results(icow).most_likely_stage = most_likely_stage;
    results(icow).state_names = states;
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

%% Pregnancy Likelihood Model (from test_example.m)
function Pg = pregnancyLikelihood(day)
% Evaluates stage prior probabilities based on continuous pregnancy day
Pg = zeros(5, 1);

% 1. Normal
Pg(1) = 1 / (1 + exp((day - 255) / 8));

% 2. Preparatory
Pg(2) = exp(-(day - 270)^2 / (2 * 10^2));

% 3. Labour
Pg(3) = exp(-(day - 280)^2 / (2 * 4^2));

% 4. Transition
Pg(4) = exp(-(day - 284)^2 / (2 * 2^2));

% 5. Calving
Pg(5) = exp(-(day - 285)^2 / (2 * 0.7^2));

% Normalize
sumPg = sum(Pg);
if sumPg > 0
    Pg = Pg / sumPg;
else
    Pg = ones(5, 1) / 5;
end
end
