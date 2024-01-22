%% autoBase.m
% Used to perform automated imaging of baseline fluorescence intensity on
% Scientifica Hyperscope multi-photon system. For use with dendra2 (or
% other fluorophore) experiments to measure changes in protein steady
% state. Program, including selection of fields of view is completely
% automated to minimize bias. The +dendra and +util folders contain all
% required functions.
%   fParamBase: Used to create or modify parameter struct
%   fDataSet: Creates an empty data struct
%   zSetRange: Identifies optimal zStack range for a given FoV
%   zGrab: Takes a zStack image based on input parmaters and outputs a mean
%       and/or max projection image
%   imSeg: Segments image to identify cells
%   imRegions: Calculates bounding box of regions of interest
%   imFluor: Calculates fluorescence levels of regions of interest
%   listener_fAcq: Listener used to determine when a frame is acquired by
%       scanimage software
%   dataBase: Performs automated data analysis of baseline images
%
% Utility files include:
%   setFoV: allows the user to select fields of view
%   cell2csv: saves information from a cell array to a csv file
%   fileSelect: allows user to select a range of files of specificed type
%   svNotif: saves .mat file to dropbox as a notification of progress
%
% Companion files include:
%   autoFRAP: used perform automated fluorescence recovery after
%       photobleaching experiments
%   autoBleach: used to optimized bleach number and laser power without
%       looking at fluorescence recovery 
%   fParamFRAP: parameter file for autoFRAP
%   fParamBleach: parameter file for autoBleach
%   dataFilter: data analysis of autoFRAP
%   dataTime: data analysis of autoFRAP
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
        fParam = dendra.fParamBase();
        break
    end
    
end

clear fLoad form pth pName pPath


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


%% Define dataset centers

setsMax = fParam.gen.setsMax;
setsDist = fParam.gen.setsDist;
offset = fParam.gen.offset;

% generate n by n grid of centers
len = ceil(sqrt(setsMax));
edge = (-1:len-2)*setsDist;
[A,B] = meshgrid(edge,edge);
C = cat(2,A',B');
cents = reshape(C,[],2);
cents(:,3) = offset;

for imSet = 1:setsMax
    fData(imSet).loc(:) = hSI.hMotors.motorPosition + cents(imSet,:);
end

clear len edge A B C cents


%% Perform first round of imaging

% pause for user to leave dark room
pause(60)

% set zero time
tic;
setDel = [];

for imSet = 1:fParam.gen.setsMax
    %% Initialize dataset
    
    cur = fData(imSet);
    
    
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
    
    
    %% Take z-stack
    
    hSI.hScan2D.logFileStem = [fData(1).saveName '_' fData(1).expVar...
        '_' num2str(imSet)];
    
    cur.clock(1) = toc;
    cur.stacks{1} = dendra.zGrab(fParam,cur);
    
    
    %% Save dataset
    
    fData(imSet) = cur;
    util.svNotif(fParam,fData)
    
end


%% Perform image segmentation

for imSet = 1:fParam.gen.setsMax
    
    % save current set as temporary variable
    cur = fData(imSet);
    
    % skip deleted set
    if ismember(imSet,setDel)
        continue
    end
    
    % segment image
    cur.roiSeg = dendra.imSeg(fParam,cur.stacks{1});
    
    % calculate background
    for i = 1:length(cur.stacks)
        cur.bkg(i) = mean(cur.stacks{i}(cur.roiSeg==0));
    end
    
    % calculate roi fluoresnce and location
    cur = dendra.imRegions(fParam,cur);
    cur = dendra.imFluor(cur);
    
    % if empty delete set
    if isempty(cur.roiLoc)
        setDel(end+1) = imSet;
    end
    
    % save dataset
    fData(imSet) = cur;
end

clear imSet cur start stop flag


%% Save data

% set save name
fileName = [fData(1).saveName '_' fData(1).expVar '.mat'];

% save parameters and data
save(fileName,'fData','fParam')

% perform automated data analysis
dendra.database(fileName)

