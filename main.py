#!/usr/bin/env python3
"""
Calving Stage Probability Estimation Server (Python Port)

Monitors uniphyed.alaive_vicow_zed_objects database table for rows with flag = 3.
For each detected cow:
  1. Retrieves full observation history in chronological order.
  2. Unifies multi-camera observations per timestamp (mode/majority vote).
  3. Estimates stage probabilities via continuous-time Bayesian filtering.
  4. Transforms object structures into string format using shared_obj2str.
  5. Updates the val field in the database.
  6. Resets flag = 0 for processed entries.

Agostini - 2026
"""

import sys
import os
import time
from datetime import datetime

# Add python folder to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))
python_dir = os.path.join(script_dir, 'python')
if os.path.exists(python_dir) and python_dir not in sys.path:
    sys.path.insert(0, python_dir)

from db import execute_scalar, execute_query, execute_update, DB_CONFIG
from shared import shared_str2obj, shared_obj2str
from bayesian_filter import get_most_likely, estimate_cow_stage_history, STATES


def get_cows_with_flag3():
    """Gets list of unique cow IDs (var field) where flag = 3."""
    query = "SELECT DISTINCT var FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;"
    rows = execute_query(query)
    return [r[0] for r in rows if r[0]]


def get_cow_full_history(cow_id):
    """Retrieves and unifies full observation history for a cow across all flags."""
    query = f"SELECT time, obj, val FROM uniphyed.alaive_vicow_zed_objects WHERE var = '{cow_id}' ORDER BY time ASC;"
    rows = execute_query(query)
    
    raw_recs = []
    for r in rows:
        time_str, obj_str, val_str = str(r[0]), str(r[1]), str(r[2])
        objects = shared_str2obj(val_str)
        
        standing_val = None
        arched_val = None
        
        for obj in objects:
            if obj.get('name') == 'pos':
                for var in obj.get('variables', []):
                    if var.get('name') == 'standing':
                        standing_val = var.get('value')
                    elif var.get('name') == 'arched':
                        arched_val = var.get('value')
                break
                
        raw_recs.append({
            'time': time_str,
            'obj': obj_str,
            'standing': standing_val,
            'arched': arched_val
        })
        
    if not raw_recs:
        return {'cow_id': cow_id, 'pos_list': []}
        
    unique_times = []
    for rec in raw_recs:
        if rec['time'] not in unique_times:
            unique_times.append(rec['time'])
            
    pos_list = []
    for t_str in unique_times:
        time_recs = [rec for rec in raw_recs if rec['time'] == t_str]
        cams = [rec['obj'] for rec in time_recs]
        standing_vals = [rec['standing'] for rec in time_recs]
        arched_vals = [rec['arched'] for rec in time_recs]
        
        standing_unified = get_most_likely(standing_vals)
        arched_unified = get_most_likely(arched_vals)
        
        pos_list.append({
            'time': t_str,
            'cams': cams,
            'standing': standing_unified,
            'arched': arched_unified
        })
        
    return {'cow_id': cow_id, 'pos_list': pos_list}


def update_cow_stage_db_verbose(results):
    """Updates the stage object in DB val field using shared_obj2str."""
    cow_id = results['cow_id']
    timestamps = results['timestamps']
    belief = results['belief']
    states = results['state_names']
    n_time = len(timestamps)
    
    for t in range(n_time):
        time_str = timestamps[t]
        belief_t = belief[:, t]
        
        query = f"SELECT val FROM uniphyed.alaive_vicow_zed_objects WHERE var = '{cow_id}' AND time = '{time_str}' LIMIT 1;"
        rows = execute_query(query)
        val_str = rows[0][0] if rows else ""
        
        objects = shared_str2obj(val_str)
        
        stage_variables = []
        for s, s_name in enumerate(states):
            stage_variables.append({
                'name': s_name,
                'id': 0,
                'type': 1,
                'role': [''],
                'value': float(belief_t[s])
            })
            
        stage_obj = {
            'name': 'stage',
            'id': len(objects) + 1,
            'type': 'object',
            'variables': stage_variables
        }
        
        found = False
        for obj in objects:
            if obj.get('name') == 'stage':
                obj['variables'] = stage_variables
                found = True
                break
                
        if not found:
            objects.append(stage_obj)
            
        new_val_str = shared_obj2str(objects)
        
        update_query = f"UPDATE uniphyed.alaive_vicow_zed_objects SET val = '{new_val_str}' WHERE var = '{cow_id}' AND time = '{time_str}';"
        execute_update(update_query)
        
        print(f"    [Time: {time_str}] Updated DB val string: {new_val_str}")


def main():
    """Main server loop monitoring database for flag = 3."""
    print("=======================================================")
    print("  Calving Stage Probability Estimation Server Active  ")
    print("  Monitoring uniphyed.alaive_vicow_zed_objects (flag = 3)")
    print(f"  Target DB Host: {DB_CONFIG['host']}:{DB_CONFIG['port']} | User: {DB_CONFIG['user']}")
    print("=======================================================\n")
    
    pause_interval = 5  # Polling interval in seconds
    
    while True:
        try:
            now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            print(f"[{now_str}] Step 1: Checking database for entries with flag = 3...")
            
            query_count = "SELECT COUNT(*) FROM uniphyed.alaive_vicow_zed_objects WHERE flag = 3;"
            nrows = execute_scalar(query_count)
            
            if nrows > 0:
                print(f"[{now_str}] Step 1 Complete: Found {nrows} row(s) with flag = 3.")
                
                print(f"[{now_str}] Step 2: Identifying cows associated with flag = 3...")
                cows_to_process = get_cows_with_flag3()
                print(f"[{now_str}] Step 2 Complete: Found {len(cows_to_process)} unique cow(s) to process: [{', '.join(cows_to_process)}]")
                
                for icow, cow_id in enumerate(cows_to_process, start=1):
                    print("\n-------------------------------------------------------")
                    print(f"  Processing Cow {icow}/{len(cows_to_process)}: ID = {cow_id}")
                    print("-------------------------------------------------------")
                    
                    print(f"[{now_str}] Step 3: Retrieving observation history for Cow ID: {cow_id}...")
                    cow_data = get_cow_full_history(cow_id)
                    print(f"[{now_str}] Step 3 Complete: Retrieved {len(cow_data['pos_list'])} time step(s) of history.")
                    
                    if cow_data and cow_data['pos_list']:
                        print(f"[{now_str}] Step 4: Estimating stage probabilities via Bayesian filter...")
                        results = estimate_cow_stage_history(cow_data)
                        print(f"[{now_str}] Step 4 Complete: Probabilities estimated for {results['belief'].shape[1]} time steps.")
                        
                        print(f"[{now_str}] Step 5 & 6: Transforming objects with shared_obj2str and writing to DB...")
                        update_cow_stage_db_verbose(results)
                        print(f"[{now_str}] Step 5 & 6 Complete: DB val field updated successfully.")
                        
                        print(f"[{now_str}] Step 7: Resetting flag = 0 for Cow ID: {cow_id}...")
                        update_flag_query = f"UPDATE uniphyed.alaive_vicow_zed_objects SET flag = 0 WHERE var = '{cow_id}' AND flag = 3;"
                        execute_update(update_flag_query)
                        print(f"[{now_str}] Step 7 Complete: Flag set to 0 for Cow ID: {cow_id}.")
                        
                print(f"\n[{now_str}] Finished processing batch. Standing by...\n")
            else:
                print(f"[{now_str}] Step 1: No entries with flag = 3. Waiting...\n")
                
        except Exception as e:
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] ERROR during processing: {e}")
            
        time.sleep(pause_interval)


if __name__ == '__main__':
    main()
