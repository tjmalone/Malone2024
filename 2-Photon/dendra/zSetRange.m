function [start,stop,flag] = zSetRange(fParam)
%% zSetRange.m
% Automatically determines z-range for a given field of view. Performs two
% "spirals". The probe spiral ensures that the original z-range contains
% cells. The edge spiral finds the both edges of the FoV. For use with
% autoFRAP and related programs, but could be adapted to alternate
% programs, as long as input struct contains the correct parameters
%
% Inputs:
%       fParam = parameter struct
%
% Output:
%       start = start of z-range for FoV
%       stop = end of z-range for FoV
%       flag = outcome state (1 = successful,-1 = unsuccessful)
%

hSI = evalin('base','hSI'); % get the handle to the ScanImage model


%% Parameters

% store previous resolution
resCur = hSI.hRoiManager.pixelsPerLine;
hSI.hRoiManager.pixelsPerLine = fParam.rng.res;

channel = fParam.acq.channel;          % channel to analyze

probeThr = fParam.rng.probeThr;       % threshold for probe spiral
probeStep = fParam.rng.probeStep;     % step size for probe spiral
probeDist = fParam.rng.probeDist;     % max distance for probe spiral

edgeThr = fParam.rng.edgeThr;         % threshold for edge spiral
edgeStep = fParam.rng.edgeStep;       % step size for edge spiral
edgeScale = fParam.rng.edgeScale;     % step size reduction factor
frNum = fParam.rng.frNum;              % number of frames to average

phsMax = fParam.rng.phsMax;           % max edge spiral phase
edgePhs = 1;                          % initial edge spiral phase

% current step size for edge spiral
edgeStepC = edgeStep;                 

zCent = hSI.hMotors.motorPosition(3); % initial z position
zDist = 0;                            % distance from z_center

% set spiral state
% 0=initial, 1=probe, 2=edge, +=start(z-pos), -=stop(z-neg)
spState = 0;

% set outcome state
% 1=successfull z-range, -1=unable to find z-range
flag = 0;

% create listener
l_fAcq = dendra.listener_fAcq(1,channel);


%% Acquisition Loop

% ensure scanimage is in an idle state
assert(strcmpi(hSI.acqState,'idle'));

% begin focusing
hSI.startFocus();

while true
    %% Acquire grab
    
    % update motor height
    hSI.hMotors.motorPosition(3) = zCent+zDist;
    
    % activate listener
    l_fAcq.frCount = 0;
    
    % wait for listener
    F = figure;
    uiwait(F)
    close(F)
    clear F
    
    % extract acqusition
    frMean = l_fAcq.frMean;
    
    % calculate intensity value
    spRange = max(frMean(:))-min(frMean(:));
    
    
    %% Evaluate against threshold
    
    if spState==0  % evaluate initial image aquisition
        if spRange<probeThr
            % if below probe threshold, initiate probe spiral
            spState = 1;
            zDist = probeStep;          % initialize z
        else
            % if above probe threshold, initiate edge spiral
            spState = 2;
            zDist = edgeStepC;          % initialize z
            l_fAcq.frNum = frNum;       % set listener frames
        end
        
    elseif abs(spState)==1              % resolve probe spiral
        if spRange<probeThr
            if sign(spState)==1         % set next probe location
                zDist = -zDist;         % flip sign of z
            else
                % flag as invalid if z is beyond max range
                if abs(zDist)>=probeDist
                    flag = -1;
                    start = 0;
                    stop = 0;
                    break
                end
                
                % increase z by step size
                zDist = abs(zDist)+probeStep;
            end
            
            spState = -spState;         % switch spiral arms
            
        else
            spState = 2;                % initiate edge spiral
            zCent = zCent+zDist;        % set new center
            zDist = edgeStepC;          % reset step size
            l_fAcq.frNum = frNum;       % set listener frames
        end
        
    elseif abs(spState)==2              % resolve edge spiral
        if spRange>edgeThr              % if above threshold
            zDist = zDist+edgeStepC;    % take next step
        else                            % if below threshold
            if edgePhs<phsMax           % initiate next step phase
                edgePhs = edgePhs+1;
                zDist = zDist+edgeStepC*(1/edgeScale-1);    % reset z
                edgeStepC = edgeStepC/edgeScale;            % reduce step
            else
                if sign(spState)==1     % switch spiral arms
                    % save z-start
                    stop = zCent+zDist-edgeStepC; 
                    
                    % reset spiral
                    spState = -2;
                    edgePhs = 1;
                    edgeStepC = -edgeStep;
                    zDist = edgeStepC;
                else                    % exit loop
                    % save z-stop
                    start = zCent+zDist-edgeStepC;  
                    flag = 1;
                    break
                end
            end
        end
    end
end

% stop focusing
hSI.abort();

% clean up listener
delete(l_fAcq)
clear l_fAcq

% check validity
if start==stop
    flag = -1;
end

% reset resolution
hSI.hRoiManager.pixelsPerLine = resCur;

end