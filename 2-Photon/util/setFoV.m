function fData = setFoV(fParam,fData)
%% setFoV.m
% Allows the user to manually define fields of view for 2-photon
% experiments. Is designed for use with autoFRAP and autoBleach, but can be
% easily adapted for alternate experiments as long as input structs contain
% the correct parameters (see Parameters section). First, user defines
% initial focus. A grid of FoV at a defined distance is generated. Program
% then sweeps through each FoV. User can manually change XYZ coordinates
% to determine exact center of FoV. Finally, user selects which FoV to use.
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       fData = updated data struct
%
% User inputs options:
%       n - move to next potential FoV
%       b - move to previous FoV
%       r - remove most recently selected FoV from fData
%       s - select current FoV for fData and jump to next FoV
%

hSI = evalin('base','hSI'); % get the handle to the ScanImage model

% ensure scanimage is in an idle state
assert(strcmpi(hSI.acqState,'idle'));


%% Parameters

setsMax = fParam.gen.setsMax;
setsDist = fParam.gen.setsDist;
offset = fParam.gen.offset;

% store previous resolution
resCur = hSI.hRoiManager.pixelsPerLine;
hSI.hRoiManager.pixelsPerLine = fParam.rng.res;


%% Set initial focus
% User manually sets initial focus to ensure this is correct

% begin focusing
hSI.startFocus();

% adjust initial focus to account for difference between overhead and 2P
hSI.hMotors.motorPosition(3) = hSI.hMotors.motorPosition(3) + offset;

% pause for use to set focus
fprintf('Set initial focus \n')
pause

% zero XYZ
hSI.hMotors.motorZeroXYZ


%% Define dataset centers

% generate n by n grid of centers
len = ceil(sqrt(setsMax+3));
edge = (-1:len-2)*setsDist;
[A,B] = meshgrid(edge,edge);
C = cat(2,A',B');
cents = reshape(C,[],2);
cents(:,3) = 0;


%% Acquisition Loop

% initialize sweep
curCent = 1;        % which FoV is currently being viewed
cnt = 0;            % number of FoV selected

% display options
fprintf('\n')
fprintf('Options:\n')
fprintf('\tn = next\n')
fprintf('\tp = previous\n')
fprintf('\tr = remove last selected\n')
fprintf('\ts = select\n\n')

% continues until all FoV are selected
while cnt<setsMax
    
    % move to next FoV in sweep
    hSI.hMotors.motorPosition(:) = cents(curCent,:);
    
    % sweeps through FoV
    while true
        % user selects action
        act = input('Select Center (n/p/r/s): ','s');
        if act=='n' % sweep to next FoV
            curCent = mod(curCent+1,size(cents,1));
        elseif act=='p' % sweep to previous FoV
            curCent = mod(curCent-1,size(cents,1));
        elseif act=='r' % remove previous selection by overwriting
            cnt = max(cnt-1,0);
            continue
        elseif act=='s' % save current FoV and sweep to next
            curCent = mod(curCent+1,size(cents,1));
            cnt = cnt+1;
            fData(cnt).loc(:) = hSI.hMotors.motorPosition(:);
        else % repeat if selection is invalid
            continue;
        end
        
        % correct for modular center number
        if curCent==0; curCent=size(cents,1); end
        
        break
    end
end


%% Terminate function

% stop focusing
hSI.abort();

% reset resolution
hSI.hRoiManager.pixelsPerLine = resCur;


end