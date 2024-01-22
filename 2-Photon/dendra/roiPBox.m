function fData = roiPBox(fParam,fData)
%% roiPBox.m
% Identifies over-bright points and creates a mask over these points. Takes
% multiple z-stacks at low laser power. Identifies indiviual points that
% have high fluorescence. This occurs if cells lyse as a result of
% bleaching. This can cause indiviual points to be very bright and overload
% PMT. Draws a box around these points and does not further image in this
% region. Also turns off imaging of any cells that intersect this box.
% Designed for use with autoFRAP and autoBleach, but can be adapted for
% alternate experiments as long as input structs contain the correct
% parameters (see Parameters section).
%
% Note: Points can also be identified if original cells are particularly
% bright. If this is undesired, increase powerbox threshold or turn off
% powerbox filter.
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       fData = updated data struct
%

hSI = evalin('base','hSI');         % get the handle to the ScanImage model


%% Powerbox Parameters

% store original values
resCur = hSI.hRoiManager.pixelsPerLine;
powCur = hSI.hBeams.powers;

pbRes = fParam.pb.res;              % resolution for powerbox imaging
testPows = fParam.pb.testPows;      % laser powers for powerbox imaging
brLim = fParam.pb.brLim;            % cutoff value for bright points
buff = fParam.pb.buff;              % border around bright points
baseBox = fParam.pb.baseBox;        % empy powerbox

acqRes = fParam.acq.res;            % image resolution

roiLoc = fData.roiLoc;              % input roiLoc regions
roiBr = fData.roiBr;                % roi that contain bright points
pBox = fData.pBox;                  % powerboxes for dataset


%% Calculate roi corners

% initialize corners
roiCor = cell(1,size(roiLoc,1));

% calculate corners
for roi=1:size(roiLoc,1)
    loc = roiLoc(roi,:);
    roiCor{roi} = {[loc(2),loc(1)],[loc(2)+loc(4),loc(1)+loc(3)]};
end


%% Imaging Parameters

% ensure scanimage is in an idle state
assert(strcmpi(hSI.acqState,'idle'));

% stack settings
hSI.hMotors.motorPosition = fData.loc;              % set stage position
hSI.hStackManager.stackZStartPos = fData.start;     % set z start position
hSI.hStackManager.stackZEndPos = fData.stop;        % set z end position

hSI.hStackManager.numSlices = fParam.acq.slNum;     % number of slices
hSI.hStackManager.framesPerSlice = fParam.pb.frNum; % frames per slice
hSI.hScan2D.logAverageFactor = fParam.pb.frNum;     % frames averaged

% Set resolution
hSI.hRoiManager.pixelsPerLine = pbRes;

% create listener
frames  = hSI.hStackManager.numSlices*fParam.pb.frNum;
l_fAcq = dendra.listener_fAcq(frames,fParam.acq.channel);


%% Acquisition Loop

for pow = 1:length(testPows)
    %% Take z-stack image
    
    % set laser power
    hSI.hBeams.powers = testPows(pow);
    
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
    frMax = l_fAcq.frMax;
    
    
    %% Calculate powerboxes
    
    % find bright points
    [p1,p2] = find(frMax>brLim);
    brPts = [p1,p2];
    
    % skip analysis if no bright points found
    if size(brPts,1)==0; continue; end
    
    % cycle through bright points
    for pt = 1:size(brPts,1)
        flag = 1;
        
        % cycle through rois
        for roi=1:size(roiLoc,1)
            % determine if point is inside roi
            if and(all(brPts(pt,:)>=roiCor{roi}{1}),...
                    all(brPts(pt,:)<=roiCor{roi}{2}))
                
                % create powerbox from roi
                if ~ismember(roi,roiBr)
                    roiBr(end+1) = roi;
                    
                    len = size(pBox,2)+1;
                    
                    % add empty powerbox
                    pBox(len) = baseBox;
                    
                    % set powerbox rectangle with buffer
                    pBox(len).rect = roiLoc(roi,[2,1,4,3])/acqRes +...
                        [-buff,-buff,2*buff,2*buff];
                    pBox(len).name = ['roi ' num2str(roi)];
                end
                
                % turn off flag (point is already blocked within roi)
                flag = 0;
                break
            end
        end
        
        % create powerbox from point if not within roi
        if flag
         
            len = size(pBox,2)+1;
            
            % add empty powerbox
            pBox(len) = baseBox;
            
            % set powerbox rectangle with buffer
            pBox(len).rect(1:2) = brPts(pt,:)/pbRes;
            pBox(len).rect = pBox(len).rect + [-buff,-buff,2*buff,2*buff];
            
            pBox(len).name = ['pt ' num2str(pt)];
            

        end
    end
    
    
    %% Prep next cycle
  
    % activate powerbox for next cycle
    if size(pBox,1)>0
        hSI.hBeams.enablePowerBox = 1;
        hSI.hBeams.powerBoxes = pBox;
    end
    
end


%% Resolve function

% clean up listener
delete(l_fAcq)
clear l_fAcq

% turn off PowerBox
hSI.hBeams.enablePowerBox = 0;

% return to original settings
hSI.hRoiManager.pixelsPerLine = resCur;
hSI.hBeams.powers = powCur;

% save fData variables
fData.roiBr = roiBr;
fData.pBox = pBox;

end