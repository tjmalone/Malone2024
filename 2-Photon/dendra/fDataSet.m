function fData = fDataSet(fParam)
%% fDataSet.m
% Create an empty dataset for autoFRAP, autoBase, and autoBleach
% experiments. 
%
% Warning: If additional fields are added, compatibility issues may
% occur with older data files.
%
% Inputs:
%       fParam = a parameter file containing the number of sets (FoV) and
%       time points for the experiment.
%
% Output:
%       fData = empty 1 by N struct for storing all imaging and analysis
%       data, where N is the number of FoV. Contains all fields necessary
%       for listed experiments types.
%

fData = struct();

for i = 1:fParam.gen.setsMax
    fData(i).saveName = [];                     % file save name
    fData(i).expVar = [];                       % experiment variable
    fData(i).loc = zeros(1,3);                  % xyz coordinates
    fData(i).start = [];                        % start of focus range
    fData(i).stop = [];                         % end of focus range
    fData(i).zMax = [];                         % max fluor focal plane
    fData(i).stacks = cell(1,fParam.gen.timesN); % storage for z-stacks
    fData(i).clock = zeros(1,fParam.gen.timesN); % clock time of image
    fData(i).roiSeg = {};                       % roi storage
    fData(i).roiLoc = [];                       % bounding box
    fData(i).roiBr = [];                        % roi with bright points
    fData(i).pBox = fParam.pb.emptyBox;         % powerbox locations
    fData(i).roiRaw = [];                       % roi intensity values
    fData(i).roiNet = [];                       % background subtracted
    fData(i).roiNorm = [];                      % normalized to post-bleach
    fData(i).roiDel = [];                       % excluded cells list
    fData(i).bkg = zeros(1,fParam.gen.timesN);  % background intensity
end

end
