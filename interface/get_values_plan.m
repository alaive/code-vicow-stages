function plan = get_values_plan(scenario_name,actiongeneric)

% get values of plans from _actions table.
% 
% Agostini - 20.04.2026

global SCENARIO_ID

% set status in corresponding scenario to 1 (getting actions)
request = ['UPDATE scenarios SET status = 2 WHERE id=' num2str(SCENARIO_ID) ''];
mexSqlRequestRWScalar_uniphyed(request);

% get number of actions in plan from db. Instantiated by the user
% (frontend).
request = ['SELECT time FROM ' scenario_name '_actions WHERE obj LIKE ''%treatment_for_simulator%'''];
vtime = mexSqlRequestReadVector_uniphyed(request);
nactions = max(vtime);


% generate template
plan = [];
for iaction = 1:nactions
    action = actiongeneric;
    action.name = ['treatment_for_simulator_' num2str(iaction)];
    plan = [plan;action];
end

% get ALL actions from db
plan = get_values(plan,'actions',scenario_name);


% set status in corresponding scenario to 1 (getting actions)
request = ['UPDATE scenarios SET status = 0 WHERE id=' num2str(SCENARIO_ID) ''];
mexSqlRequestRWScalar_uniphyed(request);

% % load treament from web. So far, same treatment for all plants.
% plan = [];
% ndays = length(days_of_application);
% for iday = 1:ndays
%     name = ['treatment_for_simulator_' num2str(iday)];
%     iaction = getIndex(name,cat(2,{actions.name})); % selected treatment
%     action = actions(iaction);
%     plan = [plan; action];
% end