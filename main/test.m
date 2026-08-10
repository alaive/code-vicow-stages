function cows = test

cows = get_cow_pos_flag3();

% Example accessing unified records for cow 1:
cow1 = cows(1);
fprintf('Cow ID: %s\n', cow1.cow_id);

for t = 1:length(cow1.pos_list)
    rec = cow1.pos_list{t};
    fprintf('[Time: %s] standing: %v, arched: %v (Observed by cams: %s)\n', ...
        rec.time, rec.standing, rec.arched, strjoin(rec.cams, ', '));
end