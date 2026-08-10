function plot_cow_stage_results(results, cow_idx)

% PLOT_COW_STAGE_RESULTS Plots calving stage probabilities and most likely stage per cow.
%
% Based on plotting logic in test_example.m.
%
% Inputs:
%   results - Struct array output from estimate_cow_stage_db
%   cow_idx - (Optional) Index or array of indices of cows to plot.
%             If omitted or empty, plots all cows in results.
%
% Agostini - 10.08.2026

if nargin < 1 || isempty(results)
    error('Results struct array must be provided.');
end

if nargin < 2 || isempty(cow_idx)
    cow_idx = 1:length(results);
end

for i = cow_idx
    if i < 1 || i > length(results)
        warning('Cow index %d out of bounds (1..%d). Skipping.', i, length(results));
        continue;
    end

    cow_res = results(i);
    cow_id = cow_res.cow_id;
    days = cow_res.days;
    belief = cow_res.belief;
    most_likely_stage = cow_res.most_likely_stage;
    states = cow_res.state_names;

    %% 1. Plot probabilities evolution
    figure('Name', sprintf('Stage Probabilities - Cow %s', cow_id), 'NumberTitle', 'off');
    hold on;

    colors = lines(length(states));
    for s = 1:length(states)
        plot(days, belief(s, :), 'LineWidth', 2, 'Color', colors(s, :));
    end

    xlabel('Pregnancy day');
    ylabel('Probability');
    title(sprintf('Bayesian Filtering of Calving Stages (Cow ID: %s)', cow_id));
    legend(states, 'Location', 'eastoutside');
    grid on;
    ylim([0 1]);
    hold off;

    %% 2. Plot most likely stage
    figure('Name', sprintf('Most Likely Stage - Cow %s', cow_id), 'NumberTitle', 'off');
    
    plot(days, most_likely_stage, 'LineWidth', 2, 'Color', [0.2 0.4 0.8]);

    yticks(1:length(states));
    yticklabels(states);
    ylim([0.5, length(states) + 0.5]);

    xlabel('Pregnancy day');
    ylabel('Estimated stage');
    title(sprintf('Most Probable Calving Stage (Cow ID: %s)', cow_id));
    grid on;
end

end
