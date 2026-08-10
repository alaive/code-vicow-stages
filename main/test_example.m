% Generate probabilies for calving stages based on observations of cow
% activity (e.g. sitting/standing) and expected stage based on pregnancy time.
%
% Agostini - 17.07.2026

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Bayesian Filter for Cow Calving Stage Estimation
%
% States:
%   1 - Normal (N)
%   2 - Preparatory (P)
%   3 - Active Labour (L)
%   4 - Transition (T)
%   5 - Calving (C)
%
% Observations:
%   1 - Standing + not arched
%   2 - Standing + arched
%   3 - Lying + arched
%   4 - Lying + not arched
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;
clc;
close all;


%% Time definition

gestation_length = 285;

time = 0:gestation_length;

Ntime = length(time);


%% States

states = {'Normal',...
          'Preparatory',...
          'Labour',...
          'Transition',...
          'Calving'};

Nstates = length(states);



%% Initial probability distribution

% At the beginning of pregnancy:
% cow is assumed normal

belief = zeros(Nstates,Ntime);

belief(:,1) = [
    1;
    0;
    0;
    0;
    0
];


%% Transition matrix
%
% Rows = previous state
% Columns = current state
%
% P(x_t | x_(t-1))

A = [

0.94  0.06  0     0     0;
0     0.75  0.25  0     0;
0     0     0.60  0.40  0;
0     0     0     0.30  0.70;
0     0     0     0     1

];


%% Generate synthetic behavioural observations

% Observation coding:
%
% 1 = Standing + not arched
% 2 = Standing + arched
% 3 = Lying + arched
% 4 = Lying + not arched


observation = zeros(1,Ntime);


for t = 1:Ntime

    day = time(t);

    if day < 250
        
        % Normal pregnancy
        observation(t)=1;


    elseif day < 270
        
        % Some preparatory behaviour
        observation(t)=1;


    elseif day < 280
        
        % Increased arching
        observation(t)=2;


    elseif day < 284
        
        % Active labour
        observation(t)=3;


    else
        
        % Transition / calving
        observation(t)=3;

    end

end



%% Observation model

%
% Rows = hidden stage
% Columns = observations
%
% P(o_t | x_t)

ObservationModel = [

0.90 0.08 0.01 0.01;   % Normal

0.50 0.40 0.08 0.02;   % Preparatory

0.10 0.35 0.50 0.05;   % Labour

0.05 0.15 0.75 0.05;   % Transition

0.01 0.05 0.90 0.04    % Calving

];



%% Bayesian filtering loop


for t = 2:Ntime


    day = time(t);


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Prediction step
    %
    % P(x_t|history)
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    prediction = A' * belief(:,t-1);



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Pregnancy prior
    %
    % P(g_t|x_t)
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    pregnancy = pregnancyLikelihood(day);



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Current observation likelihood
    %
    % P(o_t|x_t)
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    obs = observation(t);

    observationLikelihood = ObservationModel(:,obs);



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Bayesian update
    %
    % numerator:
    %
    % P(o_t|x_t)
    % P(g_t|x_t)
    % P(x_t|history)
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    numerator = prediction ...
                .* observationLikelihood ...
                .* pregnancy;



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Normalization
    %
    % denominator:
    %
    % P(o_t,g_t|history)
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    belief(:,t)=numerator/sum(numerator);


end



%% Plot probabilities

figure;
hold on;

plot(time,belief(1,:), 'LineWidth',2)
plot(time,belief(2,:), 'LineWidth',2)
plot(time,belief(3,:), 'LineWidth',2)
plot(time,belief(4,:), 'LineWidth',2)
plot(time,belief(5,:), 'LineWidth',2)

xlabel('Pregnancy day')
ylabel('Probability')

title('Bayesian Filtering of Calving Stages')

legend(states,...
       'Location','eastoutside')

grid on

ylim([0 1])



%% Most likely stage

[maxProb,index]=max(belief);

figure;

plot(time,index,'LineWidth',2)

yticks(1:5)
yticklabels(states)

xlabel('Pregnancy day')
ylabel('Estimated stage')

title('Most probable calving stage')

grid on



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pregnancy likelihood model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Pg = pregnancyLikelihood(day)


% States:
% 1 Normal
% 2 Preparatory
% 3 Labour
% 4 Transition
% 5 Calving


Pg=zeros(5,1);



%% Normal

Pg(1)=1/(1+exp((day-255)/8));



%% Preparatory

Pg(2)=exp(-(day-270)^2/(2*10^2));



%% Labour

Pg(3)=exp(-(day-280)^2/(2*4^2));



%% Transition

Pg(4)=exp(-(day-284)^2/(2*2^2));



%% Calving

Pg(5)=exp(-(day-285)^2/(2*0.7^2));



% Normalize

Pg=Pg/sum(Pg);


end



