#cat schema.postgres.sql| singularity exec instance://postgres psql postgres --user postgres
psql() {
	singularity exec instance://postgres psql postgres --user postgres
}
migrate() {
	# use sed to wrap statements in a transaction, disabling foreign key triggers
	echo "$1" | sqlite3 iceprod2.sqlite -cmd ".mode insert $2" | sed -e '1iBEGIN;SET session_replication_role = '"'"replica"'"';' -e '$aCOMMIT;' -e '2,$s/;$/ ON CONFLICT DO NOTHING;/'| psql
}

## testing dataset had "name" 20000, which fits in varbinary but not bytea
#migrate 'select * from dataset where name != 20000;' dataset
## early testing tasks had integer names
#migrate 'select * from task_rel where name>3 and dataset_id in (select dataset_id from dataset where name != 20000);' task_rel
## sub-select tasks with at least one resource report
#migrate 'select * from task where task_rel_id in (select task_rel_id from task_rel where name>4 and dataset_id in (select dataset_id from dataset where name != 20000)) and task_id in (select task_id from task_stat task_stat where length(stat)>8 and stat like '"'"'%resources%'"'"');' task
#migrate 'select * from task_stat where length(stat)>8 and stat like '"'"'%resources%'"'"' and task_id in (select task.task_id from task inner join task_rel on task.task_rel_id=task_rel.task_rel_id where task_rel.name>4 and task_rel.dataset_id in (select dataset_id from dataset where name != 20000));' task_stat

migrate 'select * from job;' job
# exclude integer-named tasks again
migrate 'select * from search where name>1;' search
