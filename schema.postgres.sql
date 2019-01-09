BEGIN;
-- CREATE TABLE categorydef (
--   categorydef_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  description bytea NOT NULL
-- ,  PRIMARY KEY (categorydef_id)
-- );
-- CREATE TABLE categoryvalue (
--   categoryvalue_id bytea NOT NULL
-- ,  categorydef_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  description text NOT NULL
-- ,  PRIMARY KEY (categoryvalue_id)
-- );
-- CREATE TABLE config (
--   dataset_id bytea NOT NULL
-- ,  config_data text NOT NULL
-- ,  difplus_data text NOT NULL
-- ,  PRIMARY KEY (dataset_id)
-- );
-- CREATE TABLE data (
--   data_id bytea NOT NULL
-- ,  task_id bytea NOT NULL
-- ,  url text NOT NULL
-- ,  compression bytea NOT NULL
-- ,  type bytea NOT NULL
-- ,  PRIMARY KEY (data_id)
-- );
CREATE TABLE dataset (
  dataset_id bytea NOT NULL
,  name bytea NOT NULL
,  description bytea NOT NULL
,  gridspec text NOT NULL
,  status bytea NOT NULL
,  username bytea NOT NULL
,  institution bytea NOT NULL
,  submit_host bytea NOT NULL
,  priority integer NOT NULL DEFAULT '0'
,  jobs_submitted integer NOT NULL DEFAULT '0'
,  tasks_submitted integer NOT NULL DEFAULT '0'
,  start_date bytea NOT NULL
,  end_date bytea NOT NULL
,  temporary_storage text NOT NULL
,  global_storage text NOT NULL
,  stat_keys text NOT NULL
,  categoryvalue_ids text NOT NULL
,  debug integer NOT NULL DEFAULT '0'
,  groups_id bytea NOT NULL
,  PRIMARY KEY (dataset_id)
);
-- CREATE TABLE dataset_notes (
--   dataset_nodes_id bytea NOT NULL
-- ,  dataset_id bytea NOT NULL
-- ,  username bytea NOT NULL
-- ,  date bytea NOT NULL
-- ,  comment text NOT NULL
-- ,  PRIMARY KEY (dataset_nodes_id)
-- );
-- CREATE TABLE dataset_stat (
--   dataset_stat_id bytea NOT NULL
-- ,  dataset_id bytea NOT NULL
-- ,  stat text NOT NULL
-- ,  PRIMARY KEY (dataset_stat_id)
-- );
-- CREATE TABLE graph (
--   graph_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  value text NOT NULL
-- ,  timestamp bytea NOT NULL
-- ,  PRIMARY KEY (graph_id)
-- );
-- CREATE TABLE groups (
--   groups_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  description text NOT NULL
-- ,  priority double precision NOT NULL DEFAULT '0'
-- ,  PRIMARY KEY (groups_id)
-- );
-- CREATE TABLE history (
--   history_id bytea NOT NULL
-- ,  username bytea NOT NULL
-- ,  cmd text NOT NULL
-- ,  timestamp bytea NOT NULL
-- ,  PRIMARY KEY (history_id)
-- );
CREATE TABLE job (
  job_id bytea NOT NULL
,  dataset_id bytea NOT NULL
,  status bytea NOT NULL
,  job_index integer NOT NULL DEFAULT '0'
,  status_changed bytea NOT NULL
,  PRIMARY KEY (job_id)
);
-- CREATE TABLE job_stat (
--   job_stat_id bytea NOT NULL
-- ,  job_id bytea NOT NULL
-- ,  stat text NOT NULL
-- ,  PRIMARY KEY (job_stat_id)
-- );
-- CREATE TABLE master_update_history (
--   master_update_history_id bytea NOT NULL
-- ,  table_name bytea NOT NULL
-- ,  update_index bytea NOT NULL
-- ,  timestamp bytea NOT NULL
-- ,  PRIMARY KEY (master_update_history_id)
-- );
-- CREATE TABLE node (
--   node_id bytea NOT NULL
-- ,  hostname bytea NOT NULL
-- ,  domain bytea NOT NULL
-- ,  last_update bytea NOT NULL
-- ,  stats text NOT NULL
-- ,  PRIMARY KEY (node_id)
-- );
-- CREATE TABLE passkey (
--   passkey_id bytea NOT NULL
-- ,  auth_key bytea NOT NULL
-- ,  expire bytea NOT NULL
-- ,  user_id bytea NOT NULL
-- ,  PRIMARY KEY (passkey_id)
-- );
-- CREATE TABLE pilot (
--   pilot_id bytea NOT NULL
-- ,  grid_queue_id bytea NOT NULL
-- ,  submit_time bytea NOT NULL
-- ,  submit_dir text NOT NULL
-- ,  tasks text NOT NULL
-- ,  requirements text NOT NULL
-- ,  avail_cpu integer NOT NULL DEFAULT '0'
-- ,  avail_gpu integer NOT NULL DEFAULT '0'
-- ,  avail_memory double precision NOT NULL DEFAULT '0'
-- ,  avail_disk double precision NOT NULL DEFAULT '0'
-- ,  avail_time double precision NOT NULL DEFAULT '0'
-- ,  claim_cpu integer NOT NULL DEFAULT '0'
-- ,  claim_gpu integer NOT NULL DEFAULT '0'
-- ,  claim_memory double precision NOT NULL DEFAULT '0'
-- ,  claim_disk double precision NOT NULL DEFAULT '0'
-- ,  claim_time double precision NOT NULL DEFAULT '0'
-- ,  PRIMARY KEY (pilot_id)
-- );
-- CREATE TABLE resource (
--   resource_id bytea NOT NULL
-- ,  url text NOT NULL
-- ,  compression bytea NOT NULL
-- ,  arch bytea NOT NULL
-- ,  PRIMARY KEY (resource_id)
-- );
-- CREATE TABLE roles (
--   roles_id bytea NOT NULL
-- ,  role_name bytea NOT NULL
-- ,  groups_prefix bytea NOT NULL
-- ,  PRIMARY KEY (roles_id)
-- );
CREATE TABLE search (
  task_id bytea NOT NULL REFERENCES task(task_id)
,  job_id bytea NOT NULL REFERENCES job(job_id)
,  dataset_id bytea NOT NULL REFERENCES dataset(dataset_id)
,  gridspec bytea NOT NULL
,  name bytea NOT NULL
,  task_status bytea NOT NULL
,  PRIMARY KEY (task_id)
);
-- CREATE TABLE session (
--   session_id bytea NOT NULL
-- ,  session_key bytea NOT NULL
-- ,  pass_key bytea NOT NULL
-- ,  last_time bytea NOT NULL
-- ,  PRIMARY KEY (session_id)
-- );
-- CREATE TABLE setting (
--   setting_id bytea NOT NULL
-- ,  node_offset bytea NOT NULL
-- ,  dataset_offset bytea NOT NULL
-- ,  dataset_notes_offset bytea NOT NULL
-- ,  dataset_stat_offset bytea NOT NULL
-- ,  job_offset bytea NOT NULL
-- ,  job_stat_offset bytea NOT NULL
-- ,  task_rel_offset bytea NOT NULL
-- ,  task_offset bytea NOT NULL
-- ,  task_stat_offset bytea NOT NULL
-- ,  task_log_offset bytea NOT NULL
-- ,  data_offset bytea NOT NULL
-- ,  resource_offset bytea NOT NULL
-- ,  categorydef_offset bytea NOT NULL
-- ,  categoryvalue_offset bytea NOT NULL
-- ,  history_offset bytea NOT NULL
-- ,  passkey_last bytea NOT NULL
-- ,  pilot_last bytea NOT NULL
-- ,  user_offset bytea NOT NULL
-- ,  session_last bytea NOT NULL
-- ,  webstat_last bytea NOT NULL
-- ,  webnote_last bytea NOT NULL
-- ,  graph_last bytea NOT NULL
-- ,  master_update_history_last bytea NOT NULL
-- ,  groups_offset bytea NOT NULL
-- ,  roles_offset bytea NOT NULL
-- ,  PRIMARY KEY (setting_id)
-- );
-- CREATE TABLE site (
--   site_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  institution bytea NOT NULL
-- ,  queues text NOT NULL
-- ,  auth_key bytea NOT NULL
-- ,  website_url bytea NOT NULL
-- ,  version bytea NOT NULL
-- ,  last_update bytea NOT NULL
-- ,  admin_name bytea NOT NULL
-- ,  admin_email bytea NOT NULL
-- ,  PRIMARY KEY (site_id)
-- );
CREATE TABLE task_rel (
  task_rel_id bytea NOT NULL
,  dataset_id bytea NOT NULL REFERENCES dataset(dataset_id)
,  task_index integer NOT NULL DEFAULT '0'
,  name bytea NOT NULL
,  depends text NOT NULL
,  requirements text NOT NULL
,  PRIMARY KEY (task_rel_id)
);
CREATE TABLE task (
  task_id bytea NOT NULL
,  status bytea NOT NULL
,  prev_status bytea NOT NULL
,  status_changed bytea NOT NULL
,  submit_dir text NOT NULL
,  grid_queue_id bytea NOT NULL
,  failures integer NOT NULL DEFAULT '0'
,  evictions integer NOT NULL DEFAULT '0'
,  walltime double precision NOT NULL DEFAULT '0'
,  walltime_err double precision NOT NULL DEFAULT '0'
,  walltime_err_n integer NOT NULL DEFAULT '0'
,  depends text NOT NULL
,  requirements text NOT NULL
,  task_rel_id bytea NOT NULL REFERENCES task_rel(task_rel_id)
,  PRIMARY KEY (task_id)
);
-- CREATE TABLE task_log (
--   task_log_id bytea NOT NULL
-- ,  task_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  data text NOT NULL
-- ,  PRIMARY KEY (task_log_id)
-- );
-- CREATE TABLE task_lookup (
--   task_id bytea NOT NULL
-- ,  queue bytea NOT NULL
-- ,  insert_time double precision NOT NULL DEFAULT '0'
-- ,  req_cpu integer NOT NULL DEFAULT '0'
-- ,  req_gpu integer NOT NULL DEFAULT '0'
-- ,  req_memory double precision NOT NULL DEFAULT '0'
-- ,  req_disk double precision NOT NULL DEFAULT '0'
-- ,  req_time double precision NOT NULL DEFAULT '0'
-- ,  req_os bytea NOT NULL
-- ,  PRIMARY KEY (task_id)
-- );
CREATE TABLE task_stat (
  task_stat_id bytea NOT NULL
,  task_id bytea NOT NULL REFERENCES task(task_id)
,  stat text NOT NULL
,  PRIMARY KEY (task_stat_id)
);
-- CREATE TABLE user (
--   user_id bytea NOT NULL
-- ,  username bytea NOT NULL
-- ,  email bytea NOT NULL
-- ,  admin integer NOT NULL DEFAULT '0'
-- ,  last_login_time bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  salt bytea NOT NULL
-- ,  hash bytea NOT NULL
-- ,  roles text NOT NULL
-- ,  PRIMARY KEY (user_id)
-- );
-- CREATE TABLE webnote (
--   webnote_id bytea NOT NULL
-- ,  page bytea NOT NULL
-- ,  username bytea NOT NULL
-- ,  timestamp bytea NOT NULL
-- ,  note text NOT NULL
-- ,  PRIMARY KEY (webnote_id)
-- );
-- CREATE TABLE webstat (
--   webstat_id bytea NOT NULL
-- ,  name bytea NOT NULL
-- ,  value text NOT NULL
-- ,  last_update_time bytea NOT NULL
-- ,  PRIMARY KEY (webstat_id)
-- );
CREATE INDEX "idx_task_rel_dataset_id_index" ON "task_rel" (dataset_id);
-- CREATE INDEX "idx_task_lookup_queue_index" ON "task_lookup" (queue);
-- CREATE INDEX "idx_job_dataset_id_index" ON "job" (dataset_id);
-- CREATE INDEX "idx_job_status_dataset_id_index" ON "job" (status,dataset_id);
CREATE INDEX "idx_task_task_rel_id_index" ON "task" (task_rel_id);
-- CREATE INDEX "idx_search_dataset_id_index" ON "search" (dataset_id);
-- CREATE INDEX "idx_search_task_status_index" ON "search" (task_status);
-- CREATE INDEX "idx_search_search_job_id_index" ON "search" (job_id);
-- CREATE INDEX "idx_task_log_task_id_index" ON "task_log" (task_id);
-- CREATE INDEX "idx_master_update_history_master_update_history_table_name_update_index" ON "master_update_history" (table_name,update_index);
COMMIT;
