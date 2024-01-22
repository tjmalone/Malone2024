function roiBleach(fParam,fData,hRoiGroup)
%% roiBleach.m
% Performs photobleach based on previously generated hROI group. Displays
% figure showing image segmentation on initial z-stack projection. Utilizes
% scanimage's mROI imaging to create bleaching boxes. An mROI box contains
% location information, a laser power, and an imaging density. Designed for
% use with autoFRAP and autoBleach, but can be adapted for alternate
% experiments as long as input structs contain the correct parameters (see
% Parameters section).
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%       hRoiGroup = scanimage mROI group object containing bleach boxes
%
%
%% Warning:
% If the number or size of individual mROIs or the collective mROI
% is too great, scanimage will produce an error due to lack of memory. If
% this occurs repeatly, reduce cell density or imaging density. This can be
% particularly troublesome with neurons, as dendrites can greatly increase
% area of mROI. Long-term fixes to this issue could include filtering for
% the size of bounding boxes before bleaching, randomly skipping cells, or
% drawing multiple boxes per mROI when there is a large amount of empty
% space. None of these programatic solutions are currently implemented.
%


%% Parameters

% get hSI from the base workspace
hSI = evalin('base','hSI');

% set bleaching z position
hSI.hMotors.motorPosition = [fData.loc(1:2),fData.zMax];

hSI.hStackManager.numSlices = fParam.bl.slNum;      % number of slices
hSI.hStackManager.framesPerSlice = fParam.bl.frNum; % frames per slice


%% Display outlined image

% display histogram edges
dispMin = fParam.seg.dispMin;
dispMax = fParam.seg.dispMax;

imSeg = fData.stacks{1};                    % pre-bleach image
imSeg(imSeg<dispMin) = dispMin;             % remove low pixels
imSeg(imSeg>dispMax) = dispMax;             % remove high pixels
imNorm = mat2gray(imSeg);                   % scale image
BWoutline = bwperim(fData.roiSeg);          % segmentation outline
imNorm(BWoutline) = 1;                      % overlay segmentation

% display image
F = figure;
imshow(imNorm'), title('image segmentation');


%% Bleach cells

% turn on mROI imaing
hSI.hRoiManager.mroiEnable = 1;

% create listener
frames  = hSI.hStackManager.numSlices*fParam.bl.frNum;
l_fAcq = dendra.listener_fAcq(frames,1);

% turn off pmts to prevent overload
hSI.hPmts.gains = [0,0];
hSI.hPmts.powersOn = [0,0];

% select roi group
hSI.hRoiManager.roiGroupMroi = hRoiGroup;

% check idle state
assert(strcmpi(hSI.acqState,'idle'));

% activate listener
l_fAcq.frCount = 1;

% start the grab
hSI.startGrab();

% wait for listener
uiwait(F)
close(F)
clear F

% reset PMT
hSI.hPmts.powersOn = [1 1];
hSI.hPmts.gains = fParam.acq.gains;

% clean up listener
delete(l_fAcq)
clear l_fAcq

% turn off mROI imaging
hSI.hRoiManager.mroiEnable = 0;

end