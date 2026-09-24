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
import time
from datetime import datetime
from collections import Counter
import numpy as np
from scipy.linalg import logm, expm
import matplotlib.pyplot as plt

# MySQL Connector Import (falls back to pymysql if mysql.connector is absent)
try:
    import mysql.connector
    HAS_MYSQL = True
except ImportError:
    try:
        import pymysql as mysql
        HAS_MYSQL = True
    except ImportError:
        HAS_MYSQL = False

# Database configuration parameters
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'uniphyed',
    'port': 3306
}

# Calving Stage State Definitions
STATES = ['Normal', 'Preparatory', 'Labour', 'Transition', 'Calving']
N_STATES = len(STATES)

# Base 1-day Transition Matrix (from test_example.m)
A_1DAY = np.array([
    [0.94, 0.06, 0.00, 0.00, 0.00],
    [0.00, 0.75, 0.25, 0.00, 0.00],
    [0.00, 0.00, 0.60, 0.40, 0.00],
    [0.00, 0.00, 0.00, 0.30, 0.70],
    [0.00, 0.00, 0.00, 0.00, 1.00]
])

# Continuous-time transition rate generator Q = logm(A_1day)
Q_RATE = np.real(logm(A_1DAY))

# Observation Likelihood Matrix P(o_t | x_t)
# Cols: 1=Standing+not arched, 2=Standing+arched, 3=Lying+arched, 4=Lying+not arched
OBSERVATION_MODEL = np.array([
    [0.90, 0.08, 0.01, 0.01],  # Normal
    [0.50, 0.40, 0.08, 0.02],  # Preparatory
    [0.10, 0.35, 0.50, 0.05],  # Labour
    [0.05, 0.15, 0.75, 0.05],  # Transition
    [0.01, 0.05, 0.90, 0.04]   # Calving
])


def get_db_connection():
    """Establishes and returns a database connection using DB_CONFIG."""
    if not HAS_MYSQL:
        raise RuntimeError("Neither 'mysql-connector-python' nor 'pymysql' is installed.")
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
    except AttributeError:
        conn = mysql.connect(**DB_CONFIG)
    return conn


def execute_scalar(query):
    """Executes a SQL query returning a scalar result (e.g. COUNT or single value)."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row else 0
    finally:
        conn.close()


def execute_query(query):
    """Executes a SQL query returning all matching rows."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        cursor.close()
        return rows
    finally:
        conn.close()


def execute_update(query):
    """Executes an UPDATE/INSERT SQL query."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        conn.commit()
        cursor.close()
    finally:
        conn.close()


def shared_str2obj(string_val, vartype=1):
    """
    Converts string format 'obj:var,val;' into a list of object dicts.
    Matches MATLAB shared_str2obj.m logic.
    """
    if not string_val:
        return []
    
    cobjects = [obj for obj in string_val.split(';') if obj.strip()]
    objects = []
    
    for iobj, cobj in enumerate(cobjects, start=1):
        cvariables = cobj.split(':')
        obj_name = cvariables[0]
        variables = []
        
        for cvarval_str in cvariables[1:]:
            parts = cvarval_str.split(',')
            if len(parts) >= 2:
                var_name = parts[0]
                raw_val = parts[1]
                try:
                    val_num = float(raw_val)
                    var_value = val_num
                except ValueError:
                    var_value = raw_val
                
                variables.append({
                    'name': var_name,
                    'id': 0,
                    'type': vartype,
                    'role': [''],
                    'value': var_value
                })
        
        objects.append({
            'name': obj_name,
            'id': iobj,
            'type': 'object',
            'variables': variables
        })
        
    return objects


def shared_obj2str(objects):
    """
    Converts object dict list back into string format 'obj:var,val;'.
    Matches MATLAB shared_obj2str.m logic.
    """
    res_str = ""
    for obj in objects:
        objname = obj.get('name', '')
        variables = obj.get('variables', [])
        
        if variables:
            var_parts = []
            for var in variables:
                vname = var.get('name', '')
                vval = var.get('value', '')
                if isinstance(vval, list):
                    vval_str = ":".join([f"{vname},{v}" for v in vval])
                else:
                    vval_str = f"{vname},{vval}"
                var_parts.append(vval_str)
            text_var = ":".join(var_parts)
        else:
            text_var = "null,null"
            
        res_str += f"{objname}:{text_var};"
    return res_str


def parse_timestamp_to_days(ts):
    """Converts string timestamp or numeric timestamp into fractional days elapsed."""
    if isinstance(ts, (int, float)):
        return ts / 86400.0
    if isinstance(ts, datetime):
        return ts.timestamp() / 86400.0
    ts_str = str(ts).strip()
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d'):
        try:
            dt = datetime.strptime(ts_str, fmt)
            return dt.timestamp() / 86400.0
        except ValueError:
            pass
    try:
        val = float(ts_str)
        return val / 86400.0
    except ValueError:
        return 0.0


def get_most_likely(vals):
    """Calculates mode / majority vote for a list of values."""
    clean_vals = []
    for v in vals:
        if v is not None and v != '' and (not isinstance(v, float) or not np.isnan(v)):
            if isinstance(v, (int, float, bool)):
                clean_vals.append(float(v))
            else:
                clean_vals.append(str(v))
                
    if not clean_vals:
        return 0.0
        
    counts = Counter(clean_vals)
    most_common_val, _ = counts.most_common(1)[0]
    return most_common_val


def pregnancy_likelihood(day):
    """Evaluates gestation stage prior probabilities based on pregnancy day."""
    pg = np.zeros(5)
    pg[0] = 1.0 / (1.0 + np.exp((day - 255.0) / 8.0))
    pg[1] = np.exp(-((day - 270.0) ** 2) / (2.0 * (10.0 ** 2)))
    pg[2] = np.exp(-((day - 280.0) ** 2) / (2.0 * (4.0 ** 2)))
    pg[3] = np.exp(-((day - 284.0) ** 2) / (2.0 * (2.0 ** 2)))
    pg[4] = np.exp(-((day - 285.0) ** 2) / (2.0 * (0.7 ** 2)))
    
    total = np.sum(pg)
    if total > 0:
        return pg / total
    return np.ones(5) / 5.0


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


def estimate_cow_stage_history(cow_data, start_day=270.0):
    """Estimates calving stage probabilities using continuous-time Bayesian filtering."""
    pos_list = cow_data['pos_list']
    n_time = len(pos_list)
    if n_time == 0:
        return None
        
    timestamps = []
    time_num = np.zeros(n_time)
    observations = np.zeros(n_time, dtype=int)
    
    for t in range(n_time):
        rec = pos_list[t]
        timestamps.append(rec['time'])
        time_num[t] = parse_timestamp_to_days(rec['time'])
        
        st_val = float(rec.get('standing', 0))
        ar_val = float(rec.get('arched', 0))
        
        if st_val == 1 and ar_val == 0:
            obs = 0
        elif st_val == 1 and ar_val == 1:
            obs = 1
        elif st_val == 0 and ar_val == 1:
            obs = 2
        else:
            obs = 3
        observations[t] = obs
        
    days_elapsed = time_num - time_num[0]
    preg_days = start_day + days_elapsed
    
    belief = np.zeros((N_STATES, n_time))
    belief[:, 0] = np.array([1.0, 0.0, 0.0, 0.0, 0.0])
    
    obs0 = observations[0]
    preg0 = pregnancy_likelihood(preg_days[0])
    init_num = belief[:, 0] * OBSERVATION_MODEL[:, obs0] * preg0
    belief[:, 0] = init_num / np.sum(init_num)
    
    for t in range(1, n_time):
        dt = time_num[t] - time_num[t - 1]
        if dt > 0:
            a_dt = np.real(expm(Q_RATE * dt))
            a_dt = np.maximum(a_dt, 0)
            row_sums = np.sum(a_dt, axis=1, keepdims=True)
            a_dt = a_dt / row_sums
        else:
            a_dt = np.eye(N_STATES)
            
        prediction = a_dt.T @ belief[:, t - 1]
        preg = pregnancy_likelihood(preg_days[t])
        obs = observations[t]
        obs_like = OBSERVATION_MODEL[:, obs]
        
        numerator = prediction * obs_like * preg
        total = np.sum(numerator)
        if total > 0:
            belief[:, t] = numerator / total
        else:
            belief[:, t] = prediction / np.sum(prediction)
            
    most_likely_stage = np.argmax(belief, axis=0) + 1  # 1-indexed to match MATLAB
    
    return {
        'cow_id': cow_data['cow_id'],
        'timestamps': timestamps,
        'days': preg_days,
        'observations': observations + 1,  # 1-indexed
        'belief': belief,
        'most_likely_stage': most_likely_stage,
        'state_names': STATES
    }


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


def plot_cow_stage_results(results):
    """Plots stage probability evolution and most likely stage per cow."""
    cow_id = results['cow_id']
    days = results['days']
    belief = results['belief']
    most_likely_stage = results['most_likely_stage']
    states = results['state_names']
    
    # 1. Plot probabilities evolution
    plt.figure(figsize=(10, 5))
    for s in range(len(states)):
        plt.plot(days, belief[s, :], linewidth=2, label=states[s])
    plt.xlabel('Pregnancy day')
    plt.ylabel('Probability')
    plt.title(f'Bayesian Filtering of Calving Stages (Cow ID: {cow_id})')
    plt.legend(loc='eastoutside' if hasattr(plt, 'eastoutside') else 'upper right')
    plt.grid(True)
    plt.ylim([0, 1])
    plt.tight_layout()
    plt.show()
    
    # 2. Plot most likely stage
    plt.figure(figsize=(10, 4))
    plt.plot(days, most_likely_stage, linewidth=2, color='#3366cc')
    plt.yticks(range(1, len(states) + 1), states)
    plt.ylim([0.5, len(states) + 0.5])
    plt.xlabel('Pregnancy day')
    plt.ylabel('Estimated stage')
    plt.title(f'Most Probable Calving Stage (Cow ID: {cow_id})')
    plt.grid(True)
    plt.tight_layout()
    plt.show()


def main():
    """Main server loop monitoring database for flag = 3."""
    print("=======================================================")
    print("  Calving Stage Probability Estimation Server Active  ")
    print("  Monitoring uniphyed.alaive_vicow_zed_objects (flag = 3)")
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
