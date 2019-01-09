
-- defaults:
-- '{"disk":10, "memory":2, "cpu": 1, "gpu": 0, "time":1}'

CREATE OR REPLACE FUNCTION id2num(val text) RETURNS int AS $$
DECLARE
  id int = -1;
  CHARS_LEN decimal = 62;
  cc char;
  i int;
BEGIN
    SELECT INTO id
      mod(sum((CASE
        WHEN code >= 97 THEN code-96
        WHEN code >= 65 THEN code-38
        ELSE code+5
      END)*power(62,idx)::decimal
      )-1,power(10,15)::decimal)::int
    FROM (
      SELECT
        ascii(char)::decimal as code,
        (length(val)-num)::decimal as idx
      FROM
        unnest(regexp_split_to_array(val, '')) WITH ORDINALITY AS t(char, num)
      ORDER BY num DESC
    ) q;

  RETURN id;
END;
$$ LANGUAGE plpgsql;

SELECT
  id2num(dataset_id) as dataset_id,
  task_index,
  task_name,
  job_index,
  initial_rss_request,
  final_rss_request,
  input_size,
  rss,
  evictions,
  retry_hours
  -- task_id,
  -- task_status
FROM
  (
    SELECT
      task_id,
      requirements,
      task_rel_id
    FROM
      task
  ) task INNER JOIN LATERAL (
    SELECT
      encode(dataset_id, 'escape') as dataset_id,
      task_index,
      encode(name, 'escape') as task_name,
      requirements
    FROM
      task_rel
    WHERE
      task_rel_id=task.task_rel_id AND
      (json(task_rel.requirements) #>> '{memory}') NOT LIKE '$eval%' -- skip parameterized tasks
  ) task_rel ON true INNER JOIN LATERAL (
    SELECT
      job_id,
      encode(task_status, 'escape') as task_status,
      CASE
        WHEN length(task_rel.requirements) > 0 AND (json(task_rel.requirements) #> '{memory}' IS NOT NULL) THEN
          (json(task_rel.requirements) #>> '{memory}')::float
      ELSE
          2.0
      END as initial_rss_request,
      CASE
        WHEN length(task.requirements) > 0 AND (json(task.requirements) #> '{memory}' IS NOT NULL) THEN
          (json(task.requirements) #>> '{memory}')::float
        WHEN length(task_rel.requirements) > 0 AND (json(task_rel.requirements) #> '{memory}' IS NOT NULL) THEN
          (json(task_rel.requirements) #>> '{memory}')::float
      ELSE
          2.0
      END as final_rss_request
    FROM
      search
    WHERE
      task_id=task.task_id AND
      encode(task_status, 'escape')='complete'
  ) search ON true INNER JOIN LATERAL (
    SELECT
      job_index
    FROM
      job
    WHERE
      job_id=search.job_id
  ) job ON true LEFT JOIN LATERAL ( -- left join here, because some tasks don't have inputs
    SELECT
      sum((record #>> '{size}')::int) as input_size
    FROM
      (
        SELECT
          task_stat_id,
          json_array_elements(json(stat) #> '{task_stats,download}') as record
        FROM
          task_stat
        WHERE
          task_id=task.task_id
      ) unnested
    WHERE
      (record #>> '{error}')::bool is false
    GROUP BY
      task_stat_id
    LIMIT 1
  ) input_size ON true INNER JOIN LATERAL (
    SELECT
      max((json(stat) #>> '{resources,memory}')::float) as rss
    FROM
      task_stat
    WHERE
      task_id=task.task_id AND
      (json(stat) #>> '{error}') IS NULL -- skip failed task reports
    GROUP BY
      task_id
  ) rss ON true LEFT JOIN LATERAL (
    SELECT
      count(task_id) as evictions,
      sum((json(stat) #>> '{time_used}')::float) as retry_hours
    FROM
      task_stat
    WHERE
      task_id=task.task_id AND
      (json(stat) #>> '{error_summary}') LIKE 'Resource overusage for memory%'
    GROUP BY
      task_id
  ) evictions ON true
-- WHERE evictions > 0
;