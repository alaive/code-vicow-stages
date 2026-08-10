function clear_table(table_name,scenario_name)

request = ['delete from ' scenario_name '_' table_name];
mexSqlRequestRWScalar_uniphyed(request);