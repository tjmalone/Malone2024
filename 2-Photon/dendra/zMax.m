function fData = zMax(fParam,fData)
%% zMax.m
% Automatically detects tha z-plane with maximum fluorescence. For use with
% autoFRAP and similar programs to identify the optimal plane for
% bleaching. Takes a series of images at a set z-step. Then takes a series
% of images around the peak of the previous series with a smaller z-step.
% Repeats based on the maximum phase.
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       fData = updated data struct
%

hSI = evalin('base','hSI'); % get the handle to the ScanImage model


%% Parameters

% store previous resolution
resCur = hSI.hRoiManager.pixelsPerLine;
hSI.hRoiManager.pixelsPerLine = fParam.rng.res;

channel = fParam.acq.channel;               % channel to analyze

edgeStep = fParam.rng.edgeStep;             % step size for edge spiral
edgeScale = fParam.rng.edgeScale;           % step size reduction factor
frNum = fParam.rng.frNum;                   % number of frames to average

phsMax = fParam.rng.phsMax;                 % max edge spiral phase
mxThr = fParam.gen.mxThr;                   % threshold for intensity value

zCent = mean([fData.start fData.stop]);     % initial z position

% create listener
l_fAcq = dendra.listener_fAcq(frNum,channel);


%% Acquisition Loop

% ensure scanimage is in an idle state
assert(strcmpi(hSI.acqState,'idle'));

% begin focusing
hSI.startFocus();

for edgePhs = 1:phsMax
    %% Calculate z-values
    
    % current step size for edge spiral
    edgeStepC = edgeStep/edgeScale^edgePhs;
    
    % z values for current imaging set
    zCur = zCent-(edgeScale-1)*edgeStepC:edgeStepC:...
        zCent+(edgeScale-1)*edgeStepC;
    
    % fluorescence of current imaging set
    mxCur = zeros(1,length(zCur));
    
    
    %% Acquire grab
    
    % take image for all z values in current set
    for i = 1:length(zCur)
        
        % update motor height
        hSI.hMotors.motorPosition(3) = zCur(i);
        
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
        STK = frMean(:);
        mxCur(i) = sum(STK(STK>mxThr));
    end
    
    % calculate z value of maximum fluorescence
    [~,indMax] = max(mxCur);
    zCent = zCur(indMax);
    
end


% stop focusing
hSI.abort();

% clean up listener
delete(l_fAcq)
clear l_fAcq

% set zMax
fData.zMax = zCent;

% reset resolution
hSI.hRoiManager.pixelsPerLine = resCur;

end