"""
Plotting module for calving stage probability evolution and estimated stage
"""

import matplotlib.pyplot as plt


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
    plt.legend(loc='upper right')
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
