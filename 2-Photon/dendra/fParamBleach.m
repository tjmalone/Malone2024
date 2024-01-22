function fParam = fParamBleach(saveOn)
%% fParamBleach.m
% Contains parameters for autoBleach experiments. Can create new parameter
% files or can be used for ad hoc parameter generation. Use fParamBase or
% fParamFRAP for their respective experiments.
%
% Warning: If additional parameters are added, compatibility issues may
% occur with older data files.
%
% Inputs:
%       saveOn = a boolean to select whether parameter file is created.
%           Will create file if any input is present (value has no effect).
%           Paramater struct will always be output.
%
% Output:
%       fParam = struct containg all parameters
%

% initialize struct
fParam = struct();


%% Acquisition settings

fParam.acq.powers = [45,1];         % beam powers [green,red]

fParam.acq.system = 'ImagingGalvo'; % imaging system
fParam.acq.gains = [600,0];         % PMT gains [green,red]
fParam.acq.channel = 1;             % channel to analyze (1=green,2=red)
fParam.acq.zoom = 1;                % image zoom
fParam.acq.res = 1024;              % image resolution
fParam.acq.frNum = 4;               % number of frames per slice
fParam.acq.slNum = 5;               % number of slices


%% General imaging settings

fParam.gen.times = [0 1:5];                     % bleaching iterations
fParam.gen.setsMax = 1;                         % maximum number of sets

fParam.gen.timesN = length(fParam.gen.times);   % number of time points
fParam.gen.setsDist = 1000/fParam.acq.zoom;     % distance between sets
fParam.gen.save = 1;                            % whether to save stacks
% save path for save notifications
fParam.gen.svNotifPath = 'C:\Users\scientifica\Dropbox\tm_scripts\+sv\';
fParam.gen.mxThr = 250;                 % threshold for svNotif calc
fParam.gen.offset = -40;                % initial z-axis offset


%% Z-range settings
% see zSetRange for detailed explanation of variables

fParam.rng.res = 512;               % resolution during edge detection
fParam.rng.probeThr = 800;          % threshold for probe spiral
fParam.rng.probeStep = 3;           % step size for probe spiral
fParam.rng.probeDist = 30;          % max distance for probe spiral
fParam.rng.edgeThr = 600;           % threshold for edge spiral
fParam.rng.edgeStep = 10;       	% step size for edge spiral
fParam.rng.edgeScale = 3;           % step size reduction factor
fParam.rng.frNum = 4;               % number of frames to average
fParam.rng.phsMax = 3;              % max edge spiral phase
fParam.rng.fac = .75;               % fraction of range used


%% Image segmentation settings

fParam.seg.thQ = 0.96;              % quantile threshold
% cell size conversion factor based on resolution and zoom
thSzFac = ((fParam.acq.res/1024)*fParam.acq.zoom)^2;
fParam.seg.thSzLow = 200*thSzFac;   % minimum cell size threshold
fParam.seg.thSzHi = 5000*thSzFac;   % maximum cell size threshold
fParam.seg.dispMin = -200;          % histogram minimum (for visualizaiton)
fParam.seg.dispMax = 250;           % histogram maximum (for visualization)


%% Bleach settings

fParam.bl.powers = [90,80,70];      % laser power during bleach
fParam.bl.frNum = 5;                % number of frames for bleach

fParam.bl.powersN = length(fParam.bl.powers);   % number of bleach powers
fParam.bl.slNum = 1;                % number of slices for bleach
fParam.bl.name = 'autoFRAP';        % roi group name
fParam.bl.scEdge = 1;               % edge scaling factor
fParam.bl.pixRatio = [512 512];     % pixel ratio of mRoi


%% Powerbox settings

fParam.pb.on = 0;                   % turns on/off (1/0) powerbox filter
lp = fParam.acq.powers(1);          % baseline laser powers for powerbox
fParam.pb.testPows = [-3,-1]+lp;    % laser power adjustment for powerbox
fParam.pb.brLim = 5000;             % cutoff value for bright points

% empty powerbox parameters
fParam.pb.emptyBox = struct('rect',{},'powers',{},'name',{},...
    'oddLines',{},'evenLines',{});
fParam.pb.baseBox = struct('rect',[0 0 0 0],'powers',[0,0],...
    'name','','oddLines',1,'evenLines',1);
fParam.pb.res = 1024;               % resolution for powerbox imaging
fParam.pb.frNum = 1;                % number of frames per slice
fParam.pb.buff = 0.025;             % border around bright points


%% Data analysis settings
% individual parameters can be turned on and off when calling dataFilter

fParam.dat.nrmBase = 1;             % time to normalize to
fParam.dat.nrmName = '_norm';       % suffix for normalization
fParam.dat.maxFluor = 2000;         % Max net fluorescence to analyze
fParam.dat.minFluor = 25;           % Min net fluorescence to analyze
fParam.dat.minBleach = 1/0.8-1;     % Min bleaching requirement
fParam.dat.maxBleach = 1/.25-1;     % Max bleaching requirement
fParam.dat.minRec = 0;              % Min recovery requirement
fParam.dat.bord = 0.5;              % Cell border scaling


%% Save paramater file

if nargin==1
    if saveOn
        % Save modified parameter set
        fName = input('Save as: ','s');
        save([fName '.mat'],'fParam')
    end
end

end
