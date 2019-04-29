%% MATLAB initialization
clc
clear
close all

% System properties
ncars       = 50;
nlane       = 7;
path        = [0, 40];

% Simulation integrator time step
tol         = 2;
dt_sim      = 5*10^-tol;

% Lane choice
lane_selection = 'greedy'; % 'v1', 'greedy'

%% Car initialization
% Create car queue

% Specified conditions
%{
collSOI     = {3,3,3,3,3};
commSOI     = {20,20,20,20,20};
vLim        = {5,5,5,5,5};
aLim        = {10,10,10,10,10};
accel       = {10,10,10,10,10};
state       = {[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]};
leader      = 0;
know        = cell(ncars,1);
election    = 0;
c           = cell(ncars,1);
for i = 1:ncars
    c{i}    = carV2( i, collSOI{i}, commSOI{i}, vLim{i}, ...
        aLim{i}, accel{i}, state{i}, path, leader, know, election );
end
%}

% Random conditions
%
c = cell(ncars,1);
for i = 1:ncars
    collSOI = 5;
    commSOI = 30;
    vLim    = 5*randi(5);
    aLim    = 10;
    accel   = 10*randi(aLim);
    state   = [0,0,0,0];
    leader	= 0;
    know    = cell(ncars,1);
    election= 0;
    c{i}    = carV2( i, collSOI, commSOI, vLim, aLim, accel, ...
        state, path, leader, know, election );
end
%}


%% Simulation
figure
hold on
grid on
% axis equal
axis([path(1)-1 path(2)+1 0 nlane+1])

% Demarcate the lanes
x = linspace(0,path(2));
for i = 1:nlane+1
    plot(x,(i-0.5)*ones(size(x)),'r-','LineWidth',3)
end

% Initialize all car objects
car = cell(ncars,1);
for i = 1:ncars
    car{i}  = plot(c{i}.state(1),c{i}.state(2),'ko','MarkerSize',20,...
        'MarkerFaceColor',[0 0 0]);
end

% Initialize all communication visualization
for i = 1:ncars
    for j = 1:ncars
        lin(i,j) = plot(0,0,'g-','LineWidth',2);
        hidem(lin(i,j))
    end
end

% Initialize lane_queue
lane_queue      = cell(nlane,1);
cur_time        = 0;
queue_pos       = 1;
min_pos         = 0;

% Car 1 initialization
lane_queue{1}   = c{1};
c{1}.state(2)   = 1;

% Initialize latest car in lanes
latest          = zeros(nlane,2);   % [ID, time]
latest(1,1)     = c{1}.ID;          % First car
latest(1,2)     = (c{1}.path(2) - c{1}.state(1)) / c{1}.vLim;

while min_pos <= path(2)
    
    % Generate a random number to tell the next car to go
    go_car      = rand >= 0.5;
    
    % Display results
    clc
    fprintf('Current queue position: %1.0f\n\n',queue_pos)
    
    % Latest car and time of car in each lane
    fprintf('Lane\tCar\tTime\n')
    for i = 1:nlane
        if isempty(lane_queue{i}) || ~isvalid(lane_queue{i})
            latest(i,1) = 0;
            latest(i,2) = 0;
        elseif ~isempty(lane_queue{i})
            latest(i,1) = lane_queue{i}.ID;
            latest(i,2) = (lane_queue{i}.path(2) - ...
                lane_queue{i}.state(1)) / lane_queue{i}.vLim;
        end
        fprintf('%1.0f\t%1.0f\t%f\n',i,latest(i,1),latest(i,2))
    end
    
    % Lane selection
    if queue_pos < ncars
        
        if c{queue_pos}.state(1) > c{queue_pos}.collSOI + c{queue_pos+1}.collSOI
            
            % Add car to queue
            queue_pos   = queue_pos + 1;
            
            % Current car time
            tc          = (c{queue_pos}.path(2) - c{queue_pos}.state(1)) / ...
                c{queue_pos}.vLim;
            
            % Get the proper lane from min time lane
            time        = abs(latest(:,2) - tc);
            if strcmp(lane_selection,'v1')
                [~, t_idx]  = min(time);
            elseif strcmp(lane_selection,'greedy')
                [~, t_idx]  = min(latest(:,2));
            end
            
            % Set the y-position to be the lane
            c{queue_pos}.state(2) = t_idx(1);
            
            % Add to the lane_queue
            for i = 1:2
                lane_queue{t_idx(1)} = c{queue_pos};
            end
            
        end
        
    end
    
    % Iterate for every car in the current queue
    for i = 1:queue_pos
        
        if isvalid(c{i})
            
            % Propagate the state
            c{i}.state = c{i}.state + [c{i}.state(3:4), c{i}.accel, 0]*dt_sim;
            
            % Check if velocity limits are crossed
            if c{i}.state(3) >= c{i}.vLim
                c{i}.accel  = 0;
            else
                c{i}.accel  = c{i}.aLim;
            end
            
            % Collision and communication
            for j = queue_pos:-1:2
                
                for k = j-1:-1:1
                    
                    if (isvalid(c{j}) && isvalid(c{k}))
                        
                        % Check for collision
                        if (abs(c{k}.state(1)-c{j}.state(1)) <= c{j}.collSOI+c{k}.collSOI) && ...
                                (c{j}.state(2) == c{k}.state(2))
                            c{j}.state(3) = c{k}.state(3);
                            c{j}.accel = 0;
                        else
                            % c{j}.accel = c{j}.aLim;
                        end
                        
                        % Check for communication (only in same lane)
                        if abs(c{j}.state(1)-c{k}.state(1)) <= max([c{j}.commSOI,c{k}.commSOI])% && ...
                            %(c{j}.state(2) == c{k}.state(2))
                            for l = 1:2
                                c{j}.know{k} = c{k};
                                c{k}.know{j} = c{j};
                                X = [c{j}.state(1), c{k}.state(1)];
                                Y = [c{j}.state(2), c{k}.state(2)];
                                showm(lin(j,k))
                                set(lin(j,k), 'Xdata', X)
                                set(lin(j,k), 'Ydata', Y)
                                % drawnow
                                % set(car{j}, 'MarkerFaceColor', [0 1 0])
                                % set(car{k}, 'MarkerFaceColor', [0 1 0])
                            end
                        else
                            for l = 1:2
                                c{j}.know{k} = {};
                                c{k}.know{j} = {};
                                hidem(lin(j,k))
                                % set(car{j}, 'MarkerFaceColor', [0 0 0])
                                % set(car{k}, 'MarkerFaceColor', [0 0 0])
                            end
                        end
                        
                    end
                    
                end
                
            end
            
            % Plot the cars
            set(car{i}, 'Xdata', c{i}.state(1))
            set(car{i}, 'Ydata', c{i}.state(2))
            drawnow
            
            % Delete the car from queue if it isn't in the path
            if c{i}.state(1) > c{i}.path(2)
                delete(c{i})
                delete(car{i})
                delete(lin(i,:))
                delete(lin(:,i))
            end
            
        end
        
        % M(iter) = getframe;
        
    end
    
    % Find the minimium x-position of the set of cars
    car_pos = [];
    for i = 1:ncars
        if isvalid(c{i})
            car_pos = [car_pos, c{i}.state(1)];
        end
    end
    min_pos = min(car_pos);
    
    % Increment timestep
    cur_time = cur_time + dt_sim;
    
end

fprintf('\nTotal time taken for system: %f\n', cur_time)

% Make movie
%{
movie(M,1)
myVideo = VideoWriter('multi.avi');
uncompressedVideo = VideoWriter('multi.avi', 'Uncompressed AVI');
open(myVideo);
writeVideo(myVideo, M);
close(myVideo);
%}