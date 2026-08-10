function clear_tables(scenario_name)

request = ['delete from ' scenario_name '_objects'];
mexSqlRequestRWScalar_uniphyed(request);

request = ['delete from ' scenario_name '_actions'];
mexSqlRequestRWScalar_uniphyed(request);

% request = ['delete from ' scenario_name '_demos'];
% mexSqlRequestRWScalar_uniphyed(request);

% request = ['delete from ' scenario_name '_goal'];
% mexSqlRequestRWScalar_uniphyed(request);