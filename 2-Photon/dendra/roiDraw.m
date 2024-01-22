function hRoiGroup = roiDraw(fParam,fData)
%% roiDraw.m
% Creates photobleaching rois based on segmented z-stack image. Utilizes
% scanimage's mROI imaging to create bleaching boxes. An mROI box contains
% location information, a laser power, and an imaging density. Designed for
% use with autoFRAP and autoBleach, but can be adapted for alternate
% experiments as long as input structs contain the correct parameters (see
% Parameters section).
%
% Warning: If global scanimage settings change, scaling of segmented boxes
% to mROIs may be incorrect. This can likely be fixed by adjusting maxAngle
% coefficient (MaxAngCo by a factor of 2).
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       hRoiGroup = scanimage mROI group object containing bleach boxes
%


%% Parameters

% max angle coefficient (see Warning)
mxAngCo = 36;                           

roiLoc = fData.roiLoc;                  % segmented cell box info
roiNum = size(roiLoc,1);                % number of rois to create

zoom = fParam.acq.zoom;                 % acquisition zoom
res = fParam.acq.res;                   % acquisition resolution

scEdge = fParam.bl.scEdge;              % edge scaling factor
powers = fParam.bl.powers;              % bleach laser powers
powersN = fParam.bl.powersN;            % number of laser powers
pixRatio = fParam.bl.pixRatio;          % pixel density of mROI objects

% create new mROI group
hRoiGroup = scanimage.mroi.RoiGroup(fParam.bl.name);


%% Convert Roi Centers

% adjust angle to correctly scale mROIs
mxAng = mxAngCo/zoom;
cnvFac = mxAng/res;

% flip x-y and scale centers
roiLoc = roiLoc(:,[2,1,4,3])*cnvFac;

% offset centers
roiLoc(:,1:2) = roiLoc(:,1:2)+roiLoc(:,3:4)/2-mxAng/2;

% scale edges
roiLoc(:,3:4) = scEdge*roiLoc(:,3:4);


%% Create Template Roi

% create stimulus field
sf = scanimage.mroi.scanfield.fields.RotatedRectangle();

% create roi
roiDef = scanimage.mroi.Roi;

% add stimulus field to roi
roiDef.add(0,sf);


%% Add mROIs to group

for i = 1:roiNum
    % copy default roi
    roi = roiDef.copy();
    
    % set location and size
    roi.scanfields(1).centerXY = roiLoc(i,1:2);
    roi.scanfields(1).sizeXY = roiLoc(i,3:4);
    roi.scanfields(1).rotationDegrees = 0;
    roi.scanfields(1).pixelRatio = pixRatio;
    
    % set laser power (cycles through multiple powers)
    roi.powers = powers(mod(i-1,powersN)+1);
    
    % add roi to group
    hRoiGroup.add(roi);
end

end