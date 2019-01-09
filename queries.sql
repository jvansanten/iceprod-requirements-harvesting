
-- defaults:
-- '{"disk":10, "memory":2, "cpu": 1, "gpu": 0, "time":1}'

WITH tasks AS (
  SELECT
    job.dataset_id,
    job.job_index,
    task_rel.task_index,
    task.task_id,
    task_rel.name,
    task.failures,
    task_rel.task_rel_id,
    CASE
      WHEN length(task.requirements) > 0 AND (json(task.requirements) #> '{memory}' IS NOT NULL) THEN
        (json(task.requirements) #>> '{memory}')::float
      WHEN length(task_rel.requirements) > 0 AND (json(task_rel.requirements) #> '{memory}' IS NOT NULL) THEN
        (json(task_rel.requirements) #>> '{memory}')::float
    ELSE
        2.0
    END as final_requirements,
    CASE
      WHEN length(task_rel.requirements) > 0 AND (json(task_rel.requirements) #> '{memory}' IS NOT NULL) THEN
        (json(task_rel.requirements) #>> '{memory}')::float
    ELSE
        2.0
    END as initial_requirements,
    (json(task_stat.stat) #>> '{resources,memory}')::float as actual
  FROM
    task
      INNER JOIN task_rel ON task.task_rel_id=task_rel.task_rel_id
      INNER JOIN task_stat ON task.task_id=task_stat.task_id
      INNER JOIN search ON task.task_id=search.task_id
      INNER JOIN job ON search.job_id=job.job_id
  WHERE
    (json(task_rel.requirements) #>> '{memory}') NOT LIKE '$eval%' -- skip parameterized tasks
    AND (json(task_stat.stat) #>> '{error}') IS NULL -- skip failed task reports
    AND search.task_status='\x636f6d706c657465' -- 'complete'
  -- ORDER BY
  --   task_stat.task_stat_id DESC
  -- LIMIT
  --   1000
  ),
useage AS (
  SELECT
    encode(dataset_id, 'escape') as dataset_id,
    job_index,
    task_index,
    task_id,
    encode(name, 'escape') as task_name,
    min(initial_requirements) as initial_request,
    max(final_requirements) as final_request,
    max(actual) as actual
  FROM
    tasks
  WHERE
    actual >= initial_requirements -- only count retries for resource overusage
  GROUP BY
    tasks.dataset_id, tasks.job_index, tasks.task_index, name, task_id
  -- ORDER BY final_request DESC LIMIT 10
),
evictions AS (
  SELECT
    task_id,
    count(task_id) as evictions,
    sum((json(stat) #>> '{time_used}')::float) as retry_hours
  FROM
    task_stat
  WHERE
    (json(stat) #>> '{error_summary}') LIKE 'Resource overusage for memory%'
  GROUP BY
    task_id
  -- ORDER BY
  --   task_id DESC
  -- LIMIT
  --   100000
)
SELECT
  dataset_id,
  job_index,
  task_index,
  task_name,
  initial_request,
  evictions,
  retry_hours,
  final_request,
  actual
FROM
  useage
    LEFT JOIN evictions ON useage.task_id=evictions.task_id
;
