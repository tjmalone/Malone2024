function [frMean, frMax] = zGrab(fParam,fData)
%% zGrab.m
% Automatically takes and records a z-stack in scanimage for 2-photon. Is
% designed for use with autoFRAP and related experiments, but can be
% adapted for alternate experiments as long as input structs contain the
% correct parameters (see Parameters section). Uses a scanimage listener to
% moniter and record grab.
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       frMean = mean fluorescence value of z-stack
%       frMax = max fluorescence value of z-stack
%

% get hSI from the base workspace
hSI = evalin('base','hSI');

% ensure scanimage is in an idle state
assert(strcmpi(hSI.acqState,'idle'));


%% Parameters

% store previous resolution
resCur = hSI.hRoiManager.pixelsPerLine;
hSI.hRoiManager.pixelsPerLine = fParam.acq.res;     % set image resolution

% stack settings
hSI.hMotors.motorPosition = fData.loc;              % set stage position
hSI.hStackManager.stackZStartPos = fData.start;     % set z start position
hSI.hStackManager.stackZEndPos = fData.stop;        % set z end position

% imaging settings
hSI.hStackManager.numSlices = fParam.acq.slNum;     % number of slices
hSI.hStackManager.framesPerSlice = fParam.acq.frNum;% frames per slice
hSI.hScan2D.logAverageFactor = fParam.acq.frNum;    % frames averaged


%% Initialize imaging

% update power box
pBox = fData.pBox;

% activate powerbox if present
if size(pBox,1)>0
    hSI.hBeams.enablePowerBox = 1;
    hSI.hBeams.powerBoxes = pBox;
end

% create listener
frames  = hSI.hStackManager.numSlices*fParam.acq.frNum;% total frame number
l_fAcq = dendra.listener_fAcq(frames,fParam.acq.channel);


%% Take z-stack

% activate listener
l_fAcq.frCount = 1;

% start the grab
hSI.startGrab();

% wait for listener
F = figure;
uiwait(F)
close(F)
clear F

% extract acquisition
frMean = l_fAcq.frMean;
frMax = l_fAcq.frMax;


%% Terminate program

% clean up listener
delete(l_fAcq)
clear l_fAcq

% turn off powerbox
hSI.hBeams.enablePowerBox = 0;

% return to original settings
hSI.hRoiManager.pixelsPerLine = resCur;

% clear z-stack settings
hSI.hStackManager.clearStackStartEnd
hSI.hStackManager.numSlices = 1;

% pause program to prevent errors
pause(1)

end