%% autoFRAP.m
% Used to perform automated fluorescence recovery after photobleaching
% experiments on the Scientifica Hyperscope multi-photon system. For use
% with dendra2 (or other fluorophore) photobleaching experiments to measure
% real time translation. The +dendra and +util folders contain all required
% functions.
%   fParamFRAP: Used to create or modify parameter struct
%   fDataSet: Creates an empty data struct
%   zSetRange: Identifies optimal zStack range for a given FoV
%   zMax: Identifies z-level with peak fluorescence for bleaching
%   zGrab: Takes a zStack image based on input parmaters and outputs a mean
%       and/or max projection image
%   imSeg: Segments image to identify cells
%   imRegions: Calculates bounding box of regions of interest
%   imFluor: Calculates fluorescence levels of regions of interest
%   roiDraw: Converts segmented cells into mRois
%   roiBleach: Performs bleaching of rois using mRoi imaging
%   roiPBox: Calculates powerboxes to remove rois with bright points
%   listener_fAcq: Listener used to determine when a frame is acquired by
%       scanimage software
%   dataFilter: Normalizes data to desired time point. Automatically and
%       manually filters undesirable cells 
%   dataTime: Generates a .csv file with recovery time course data
%
% Utility files include:
%   bkgSeg1024: used to test image segmentation
%   setFoV: allows the user to select fields of view
%   cell2csv: saves information from a cell array to a csv file
%   fileSelect: allows user to select a range of files of specificed type
%   svNotif: saves .mat file to dropbox as a notification of progress
%
% Companion files include:
%   autoBase: used to measure baseline fluorescence at various fields of
%       view in a non-biased manner
%   autoBleach: used to optimized bleach number and laser power without
%       looking at fluorescence recovery 
%   fParamBase: parameter file for autoBaseline
%   fParamBleach: parameter file for autoBleach
%   dataBase: data analysis of autoBase
%   dataBleach: data analysis of autoBleach
%
% Creator: Taylor J. Malone, 2021
% Lab: Leonard K. Kaczmarek
%


%% Load/create settings file

% turn off warnings to reduce messages
warning('off')

% Warning:
% Errors may occur if new parameters have been added since creation of
% param file. Remake param file in this scenario.

while true
    
    % ask user to select stored or default settings
    fLoad = input('Use stored settings? (y/n) ','s');
    
    if fLoad=='y'
        % set pathway where param files are located
        pth = '**/+params/';
        
        % set param file format
        form = '*.mat';
        
        % user selects param file to use (only first file selected is used)
        [pName,pPath] = util.fileSelect([pth form]);
        
        load([pPath{1} '/' pName{1}])
        break
        
    elseif fLoad=='n'
        % use new parameter settings
        fParam = dendra.fParamFRAP();
        break
    end
    
end

clear fLoad form pth pName pPath


%% Check roiSeg
% Segmentation error sometimes occurs. Restart Matlab to correct error.

load('+util/bkgSeg1024.mat')
dendra.imSeg(fParam,roiSeg);

clear roiSeg


%% Create data storage

fData = dendra.fDataSet(fParam);


%% Set general acquisition settings

% Force user to abort current aquisition
while true
    flag = 1;
    if(~strcmpi(hSI.acqState,'idle'))
        fprintf('Abort current acquisition \n')
        pause
        flag = 0;
    end
    if flag; break; end
end

% Repeatedly setting imaging system may cause errors, so this should be set
% manually before starting program or as part of user configuration.
% Uncomment to automatically set:
% hSI.imagingSystem = fParam.acq.system;              % set imaging system

hSI.hBeams.powers = fParam.acq.powers;              % set beam powers
hSI.hPmts.powersOn = [1,1];                         % turn on Pmts
hSI.hPmts.gains = fParam.acq.gains;                 % set PMT gains

hSI.hChannels.channelDisplay = fParam.acq.channel;  % set display channel
hSI.hChannels.channelSave = fParam.acq.channel;     % set save channel
hSI.hChannels.loggingEnable = fParam.gen.save;      % turn on data logging

hSI.hRoiManager.scanZoomFactor = fParam.acq.zoom;   % set zoom factor


%% Set save file name

% Confirm that current Matlab folder is the desired save location. If not,
% restart program
if fParam.gen.save
    fprintf('Check save folder \n')
    pause
end

% Input experiment information
while true
    
    expDate = datestr(date,'yymmdd');
    expName = input('Experiment name: ','s');
    expVar = input('Variable name: ','s');
    
    % if file exists, confirm overwrite
    if isfile([expDate '_' expName '_' expVar '.mat'])
        ovwrt = input('Overwrite current file? (y/n) ','s');
        
        if ovwrt=='y'; break; end
        
    else
        break
    end
end

% Store experiment information
for i = 1:fParam.gen.setsMax
    fData(i).saveName = [expDate '_' expName];
    fData(i).expVar = expVar;
end

clear i expDate expName expVar ovwrt


%% Set fields of view

fData = util.setFoV(fParam,fData);


%% Perform first round of imaging

% pause for user to leave dark room
pause(60)

% set zero time
tic;
setDel = [];

for imSet = 1:fParam.gen.setsMax
    %% Initialize dataset
    
    % save current set as temporary variable
    cur = fData(imSet);
    
    % check time
    if toc>fParam.gen.times(3)-fParam.gen.timesLim+fData(1).clock(2)
        fData = fData(1:imSet-1);
        break
    end
    
    
    %% Detect z-range
    
    % move to current FoV
    hSI.hMotors.motorPosition = cur.loc;
    
    % automatically determine z-range for FoV
    [start,stop,flag] = dendra.zSetRange(fParam);
    
    if flag==1          % if z-range is valid save mean, start, and stop
        cur.loc(3) = mean([start stop]);
        
        start = fParam.rng.fac*(start-cur.loc(3))+cur.loc(3);
        stop = fParam.rng.fac*(stop-cur.loc(3))+cur.loc(3);
        
        cur.start = start;
        cur.stop = stop;
    elseif flag==-1     % else mark set as invalid
        setDel = [setDel imSet];
        fData(imSet) = cur;
        continue
    end
    
    % calculate plane of maximum fluorescence for bleaching
    cur = dendra.zMax(fParam,cur);
    
    %% Take initial z-stack
    
    hSI.hScan2D.logFileStem = [fData(1).saveName '_' fData(1).expVar...
        '_' num2str(imSet)];
    
    cur.clock(1) = toc;
    cur.stacks{1} = dendra.zGrab(fParam,cur);
    
    
    %% Perform image segmentation
    
    % segment image
    cur.roiSeg = dendra.imSeg(fParam,cur.stacks{1});
    
    % calculate roi location
    cur = dendra.imRegions(fParam,cur);
    
    % check that cells were found
    if isempty(cur.roiLoc)
        setDel(end+1) = imSet;
        fData(imSet) = cur;
        continue
    end
    
    
    %% Perform photobleaching
    
    % turn off save
    hSI.hChannels.loggingEnable = 0;
    
    % create mROI group
    hRoiGroup = dendra.roiDraw(fParam,cur);
    
    % bleach cells
    dendra.roiBleach(fParam,cur,hRoiGroup)
    
    % perfrom powerbox filter
    if fParam.pb.on==1
        cur = dendra.roiPBox(fParam,cur);
    end
    
    
    %% Take post-bleach z-stack
    
    % set image save
    hSI.hChannels.loggingEnable = fParam.gen.save;
    
    cur.clock(2) = toc;
    cur.stacks{2} = dendra.zGrab(fParam,cur);
    
    
    %% Save dataset
    
    fData(imSet) = cur;
    util.svNotif(fParam,fData)
    
    
end

clear imSet cur start stop zAd flag hRoiGroup % setDel


%% Perform successive rounds of imaging

for t = 3:length(fParam.gen.times)
    for imSet = 1:length(fData)
        %% Initialize dataset
        
        % save current set as temporary variable
        cur = fData(imSet);
        
        % skip deleted sets
        if ismember(imSet,setDel)
            continue
        end
        
        % calculate wait time
        clockDif = cur.clock(2)+fParam.gen.times(t)-toc;
        
        % skip set if past next image time
        if clockDif<0
            setDel = [setDel imSet];
            continue
        end
        
        % pause until next image time
        pause(clockDif)
        
        
        %% Take recovery image
        
        % set tif save name
        hSI.hScan2D.logFileStem = [fData(1).saveName '_' fData(1).expVar...
            '_' num2str(imSet)];
        
        % take recovery image
        cur.clock(t) = toc;
        cur.stacks{t} = dendra.zGrab(fParam,cur);
        
        
        %% Save dataset
        
        fData(imSet) = cur;
        util.svNotif(fParam,fData)
        
    end
end

clear t imSet cur clockDif % setDel


%% Segment combined image

for imSet = 1:length(fData)
    
    % save current set as temporary variable
    cur = fData(imSet);
    
    % skip deleted set
    if ismember(imSet,setDel)
        continue
    end
    
    % store pre-bleach image
    imRaw = cur.stacks{1};
    
    % add all images
    for i=2:fParam.gen.timesN
        imRaw = imadd(imRaw,cur.stacks{i});
    end
    
    % segment image
    cur.roiSeg = dendra.imSeg(fParam,imRaw)+cur.roiSeg;
    
    % calculate background
    for i = 1:length(cur.stacks)
        cur.bkg(i) = mean(cur.stacks{i}(cur.roiSeg==0));
    end
    
    % calculate roi fluoresnce and location
    cur = dendra.imRegions(fParam,cur);
    cur = dendra.imFluor(cur);
    
    % save dataset
    fData(imSet) = cur;
end

% send save notification
util.svNotif(fParam,fData)

clear i cur imSet imRaw normBase setDel


%% Save data

% set save name
fileName = [fData(1).saveName '_' fData(1).expVar '.mat'];

% save parameters and data
save(fileName,'fParam','fData')

% perform automated data analysis
dendra.dataFilter(fileName)
dendra.dataTime(fileName)

