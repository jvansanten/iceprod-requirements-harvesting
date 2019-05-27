#!/usr/bin/env python

"""
Fetch IceProd2 task stats via REST API and dump them to an HDF5 table
"""

import time
import os
import asyncio
import aiohttp
import backoff
from functools import partial
from itertools import islice
import tables
import pandas as pd
import json
import logging

log = logging.getLogger("fetch_iceprod_stats")
def on_backoff(details):
    log.warn("Backing off {wait:0.1f} seconds afters {tries} tries "
           "calling function {target} with args {args} and kwargs "
           "{kwargs}".format(**details))

def giveup(exc):
    """
    Give up on 403 Unauthorized
    """
    isinstance(exc, aiohttp.client_exceptions.ClientResponseError) and exc.code == 403

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
    try:
        final_stat = next((stat for stat in stats.values() if not stat['stats'].get('error', True)))
        item['time_finished'] = pd.Timestamp(final_stat['stats']['time'])
        item.update(**{k+'_used':v for k,v in final_stat['stats']['resources'].items()})
    except StopIteration:
        # no final stat, whuffor?
        pass
    item['mem_wastage'] = 0.
    for s in stats.values():
        if s['stats'].get('error_summary','').startswith('Resource overusage for memory'):
            item['mem_wastage'] += s['stats']['resources']['memory']*s['stats']['resources']['time']
            continue
        elif isinstance (s['stats'].get('task_stats', ''), str):
            # early task stats were stored as strings. skip them.
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
    tasks = await req('/datasets/{}/tasks'.format(dataset['dataset_id']), status='complete', keys='dataset_id|job_id|task_id|task_index|requirements')
    jobs = await req('/datasets/{}/jobs'.format(dataset['dataset_id']), keys='job_index')
    log.info('{}: {} tasks in {} jobs'.format(dataset['dataset'], len(tasks), len(jobs)))
    return [process_task_stats(req, dataset, jobs[task['job_id']], task) for task in tasks.values()]

async def get_task_stats(req, datasets):
    for dataset in datasets:
        data, index = [], []
        t0 = time.time()
        for j, row in enumerate(asyncio.as_completed(await process_tasks(req, dataset))):
            k,v = await row
            index.append(k)
            data.append(v)
            if (j+1) % 10000 == 0:
                dt = time.time() - t0
                log.info("...{} tasks done ({:.1f}/s)".format(j+1,10000/dt))
                t0 = time.time()
        yield dataset['dataset'], pd.DataFrame(data, index=pd.MultiIndex.from_tuples(index, names=('dataset', 'task', 'job')))

async def aenumerate(asequence, start=0):
    """Asynchronously enumerate an async iterator from a given start value"""
    n = start
    async for elem in asequence:
        yield n, elem
        n += 1

async def run(token, outfile, parallel_requests=100):
    semaphore = asyncio.Semaphore(parallel_requests)
    async with aiohttp.ClientSession(headers={'Authorization': 'bearer '+token}, raise_for_status=True) as session:
        req = partial(limited_req, session=session, semaphore=semaphore)
        datasets = await req('/datasets')
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
            df.to_hdf(outfile, mode='a', key="/{}".format(key))
            log.info('{} complete ({} of {}) {} tasks'.format(key, i+1, len(datasets), len(df)))

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

    FORMAT = '[%(asctime)-15s %(name)s] %(message)s'
    logging.basicConfig(format=FORMAT,level='INFO')

    asyncio.get_event_loop().run_until_complete(
        run(args.token, args.outfile, args.max_parallel_requests)
    )
