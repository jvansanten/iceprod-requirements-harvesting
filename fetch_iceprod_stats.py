#!/usr/bin/env python

"""
Fetch IceProd2 task stats via REST API and dump them to an HDF5 table
"""

import os
import asyncio
import aiohttp
import backoff
from functools import partial
from itertools import islice
import pandas as pd
import json
import logging

log = logging.getLogger(__name__)
def on_backoff(details):
    log.warn("Backing off {wait:0.1f} seconds afters {tries} tries "
           "calling function {target} with args {args} and kwargs "
           "{kwargs}".format(**details))

_cache = {}
@backoff.on_exception(backoff.expo,
    (
    TimeoutError,
    aiohttp.client_exceptions.ClientConnectionError,
    aiohttp.client_exceptions.ServerDisconnectedError,
    ),
    on_backoff=on_backoff)
async def limited_req(path, session, semaphore):
    """
    Acquire semaphore and issue a GET request
    """
    if not path in _cache:
        async with semaphore:
            response = await session.get('https://iceprod2-api.icecube.wisc.edu'+path)
            _cache[path] = await response.json()
    return _cache[path]

async def process_task_stats(req, dataset, task):
    stats = await req('/datasets/{}/tasks/{}/task_stats'.format(task['dataset_id'], task['task_id']))
    job = await req('/datasets/{}/jobs/{}'.format(task['dataset_id'], task['job_id']))

    item = {k+'_req':v for k,v in task['requirements'].items()}
    try:
        final_stat = next((stat for stat in stats.values() if 'resources' in stat['stats']))
        item['time_finished'] = final_stat['stats']['time']
        item.update(**{k+'_used':v for k,v in final_stat['stats']['resources'].items()})
    except StopIteration:
        # no final stat, whuffor?
        pass
    for s in stats.values():
        # early task stats were stored as strings. skip them.
        if 'error_summary' in s['stats'] or not isinstance(s['stats']['task_stats'], dict):
            continue
        if len(s['stats']['task_stats'].get('download', [])):
            item['input_size'] = sum(f['size'] for f in s['stats']['task_stats']['download'])/(2**30)
            item['input_duration'] = sum(f['duration'] for f in s['stats']['task_stats']['download'])/3600.
        if len(s['stats']['task_stats'].get('upload', [])):
            item['output_size'] = sum(f['size'] for f in s['stats']['task_stats']['upload'])/(2**30)
            item['output_duration'] = sum(f['duration'] for f in s['stats']['task_stats']['upload'])/3600.
    index = (dataset['dataset'], task['task_index'], job['job_index'])
    return index, item

async def process_tasks(req, dataset):
    tasks = await req('/datasets/{}/tasks'.format(dataset['dataset_id']))
    finished_tasks = []
    for i,(k, v) in enumerate(tasks.items()):
        # if v['status'] == 'complete' and v['status_changed'] > '2019-01-30T00:00:00':
        if v['status'] == 'complete':
            finished_tasks.append(v)
    return [process_task_stats(req, dataset, task) for task in finished_tasks]

async def get_task_stats(token, num_datasets=None, parallel_requests=100):
    data, index = [], []
    semaphore = asyncio.Semaphore(parallel_requests)
    async with aiohttp.ClientSession(headers={'Authorization': 'bearer '+token}, raise_for_status=True) as session:
        req = partial(limited_req, session=session, semaphore=semaphore)
        datasets = await req('/datasets')
        if num_datasets is None:
            num_datasets = len(datasets)
        datasets = list(islice(reversed(list(datasets.values())),num_datasets))
        for i,tasks in enumerate(asyncio.as_completed([process_tasks(req, dataset) for dataset in datasets])):
            for row in asyncio.as_completed(await tasks):
                k, v = await row
                index.append(k)
                data.append(v)
            log.info('{} complete ({} of {})'.format(datasets[i]['dataset'], i+1, num_datasets))
        tasks = pd.DataFrame(data, index=pd.MultiIndex.from_tuples(index, names=('dataset', 'task', 'job')))
        configs = {}
        for dataset, config in zip(datasets, asyncio.as_completed([req('/config/{}'.format(dataset['dataset_id'])) for dataset in datasets])):
            config = await config
            configs[dataset['dataset']] = config
        return tasks, configs

if __name__ == "__main__":
    from argparse import ArgumentParser
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--limit-datasets", help="number of datasets to fetch", type=int, default=None)
    parser.add_argument("-p", "--max-parallel-requests", help="number of requests to issue in parallel", type=int, default=100)
    parser.add_argument('--token', help="IceProd2 API token", default=None)
    parser.add_argument("outfile", help="output file name")
    args = parser.parse_args()

    if args.token is None:
        args.token = os.environ.get('ICEPROD_TOKEN', None)
    if args.token is None:
        parser.error("You must specify an API token, either on the command line or in the environment variable ICEPROD_TOKEN. Get one from https://iceprod2.icecube.wisc.edu/profile daily.")

    FORMAT = '[%(asctime)-15s] %(message)s'
    logging.basicConfig(format=FORMAT,level='INFO')

    df, configs = asyncio.get_event_loop().run_until_complete(
        get_task_stats(args.token, num_datasets=args.limit_datasets, parallel_requests=args.max_parallel_requests)
    )
    if 'os_req' in df.columns:
        df = df.drop(columns=['os_req'])
    df.to_hdf(args.outfile+".hdf5", '/tasks')
    with open(args.outfile+".configs.json", "w") as f:
        json.dump(configs, f, indent=1)
