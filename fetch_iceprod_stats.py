#!/usr/bin/env python

"""
Fetch IceProd2 task stats via REST API and dump them to an HDF5 table
"""

import time
import os
import asyncio
import aiohttp
import backoff
from clint.textui import progress
from functools import partial
from itertools import islice
import tables
import pandas as pd
import json
import logging
import warnings

log = logging.getLogger("fetch_iceprod_stats")
def on_backoff(details):
    log.warn("Backing off {wait:0.1f} seconds afters {tries} tries "
           "calling function {target} with args {args} and kwargs "
           "{kwargs}".format(**details))

def giveup(exc):
    """
    Give up on 403 Unauthorized
    """
    return isinstance(exc, aiohttp.client_exceptions.ClientResponseError) and exc.code in (403, 404)

@backoff.on_exception(backoff.expo,
    (
    TimeoutError,
    aiohttp.client_exceptions.ClientResponseError,
    aiohttp.client_exceptions.ClientConnectionError,
    aiohttp.client_exceptions.ServerDisconnectedError,
    ),
    logger=None,
    giveup=giveup,
    on_backoff=on_backoff)
async def limited_req(path, session, semaphore, **kwargs):
    """
    Acquire semaphore and issue a GET request
    """
    async with semaphore:
        async with session.get('https://iceprod2-api.icecube.wisc.edu'+path, params=kwargs) as response:
            return await response.json()

async def process_task_stats(req, dataset, job, task):
    stats = await req('/datasets/{}/tasks/{}/task_stats'.format(task['dataset_id'], task['task_id']))

    item = {k+'_req':v for k,v in task['requirements'].items()}
    final_stat = max([stat for stat in stats.values() if 'resources' in stat['stats']], default=None, key=lambda stat: stat['stats']['time'])
    if final_stat:
        # final_stat = next((stat for stat in stats.values() if not stat['stats'].get('error', False)))
        item['time_finished'] = pd.Timestamp(final_stat['stats']['time'])
        item.update(**{k+'_used':v for k,v in final_stat['stats']['resources'].items()})
    item['mem_wastage'] = 0.
    for s in stats.values():
        if s['stats'].get('error_summary','').startswith('Resource overusage for memory'):
            item['mem_wastage'] += s['stats']['resources']['memory']*s['stats']['resources']['time']
            continue
        elif 'error_summary' in s['stats']:
            # miscellaneous error unrelated to resource usage
            continue
        elif 'task_stats' in s['stats'] and isinstance(s['stats']['task_stats'], str):
            # early task stats were stored as strings
            s['stats']['task_stats'] = json.loads(s['stats']['task_stats'])
        try:
            downloads = [f for f in s['stats']['task_stats'].get('download', []) if not f.get('error', False)]
            if downloads:
                item['input_size'] = sum(f['size'] for f in downloads)/(2**30)
                item['input_duration'] = sum(f['duration'] for f in downloads)/3600.
            uploads = [f for f in s['stats']['task_stats'].get('upload', []) if not f.get('error', False)]
            if uploads:
                item['output_size'] = sum(f['size'] for f in uploads)/(2**30)
                item['output_duration'] = sum(f['duration'] for f in uploads)/3600.
        except KeyError:
            print(s['stats'])
            raise
    index = (dataset['dataset'], task['task_index'], job['job_index'])
    return index, item

async def process_tasks(req, dataset):
    tasks = await req('/datasets/{}/tasks'.format(dataset['dataset_id']), status='complete', keys='dataset_id|job_id|task_id|task_index|requirements')
    jobs = await req('/datasets/{}/jobs'.format(dataset['dataset_id']), keys='job_index')
    log.info('{}: {} tasks in {} jobs'.format(dataset['dataset'], len(tasks), len(jobs)))
    return [process_task_stats(req, dataset, jobs[task['job_id']], task) for task in tasks.values()]

async def get_task_stats(req, datasets):
    for dataset in datasets:
        data, index = [], []
        tasks = await process_tasks(req, dataset)
        for row in progress.bar(asyncio.as_completed(tasks), label=dataset['dataset'], expected_size=len(tasks)):
            k,v = await row
            index.append(k)
            data.append(v)
        yield dataset['dataset'], pd.DataFrame(data, index=pd.MultiIndex.from_tuples(index, names=('dataset', 'task', 'job')))

async def aenumerate(asequence, start=0):
    """Asynchronously enumerate an async iterator from a given start value"""
    n = start
    async for elem in asequence:
        yield n, elem
        n += 1

async def fetch_logs(token, outfile, max_parallel_requests=100):
    semaphore = asyncio.Semaphore(max_parallel_requests)
    async with aiohttp.ClientSession(headers={'Authorization': 'bearer '+token}, raise_for_status=True) as session:
        req = partial(limited_req, session=session, semaphore=semaphore)
        datasets = await req('/datasets', keys='dataset|dataset_id')
        try:
            with tables.open_file(outfile, 'r') as hdf:
                existing = set(hdf.root._v_children.keys())
        except OSError:
            existing = set()
        
        datasets = list(reversed([v for v in datasets.values() if not str(v['dataset']) in existing]))
        async for i, (key, df) in aenumerate(get_task_stats(req, datasets)):
            if 'os_req' in df.columns:
                df = df.drop(columns=['os_req'])
            df = df.sort_index()
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', tables.NaturalNameWarning)
                df.to_hdf(outfile, mode='a', key="/{}".format(key))
            log.info('{} complete ({} of {}) {} tasks'.format(key, i+1, len(datasets), len(df)))

async def fetch_configs(token, outfile, max_parallel_requests=100):
    semaphore = asyncio.Semaphore(max_parallel_requests)
    async with aiohttp.ClientSession(headers={'Authorization': 'bearer '+token}, raise_for_status=True) as session:
        req = partial(limited_req, session=session, semaphore=semaphore)
        datasets = await req('/datasets', keys='dataset|dataset_id')
        tasks = [req('/config/{dataset_id}'.format(**ds)) for ds in datasets.values()]
        with open(outfile, 'w') as f:
            for config in progress.bar(asyncio.as_completed(tasks), label='configs', expected_size=len(tasks)):
                try:
                    config = await config
                except aiohttp.client_exceptions.ClientResponseError as e:
                    log.warn("{.request_info.url} not found".format(e))
                    continue
                json.dump(config, f)
                f.write('\n')

if __name__ == "__main__":
    from argparse import ArgumentParser
    parser = ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(help='command help', dest='command')
    subparsers.required = True

    p = subparsers.add_parser('logs')
    p.set_defaults(func=fetch_logs)

    p = subparsers.add_parser('configs')
    p.set_defaults(func=fetch_configs)

    for p in subparsers._name_parser_map.values():
        p.add_argument("-p", "--max-parallel-requests", help="number of requests to issue in parallel", type=int, default=100)
        p.add_argument('--token', help="IceProd2 API token", default=None)
        p.add_argument("outfile", help="output file name")

    args = parser.parse_args()

    if args.token is None:
        args.token = os.environ.get('ICEPROD_TOKEN', None)
    if args.token is None:
        parser.error("You must specify an API token, either on the command line or in the environment variable ICEPROD_TOKEN. Get one from https://iceprod2.icecube.wisc.edu/profile daily.")

    FORMAT = '[%(asctime)-15s %(name)s] %(message)s'
    logging.basicConfig(format=FORMAT,level='INFO')

    kwargs = vars(args)
    kwargs.pop('command')
    func = kwargs.pop('func')
    asyncio.get_event_loop().run_until_complete(
        func(**kwargs)
    )
