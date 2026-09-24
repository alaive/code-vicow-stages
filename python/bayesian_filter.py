"""
Continuous-Time Bayesian Filter for Calving Stage Estimation
"""

from datetime import datetime
from collections import Counter
import numpy as np
from scipy.linalg import logm, expm

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
            
    most_likely_stage = np.argmax(belief, axis=0) + 1  # 1-indexed
    
    return {
        'cow_id': cow_data['cow_id'],
        'timestamps': timestamps,
        'days': preg_days,
        'observations': observations + 1,  # 1-indexed
        'belief': belief,
        'most_likely_stage': most_likely_stage,
        'state_names': STATES
    }
