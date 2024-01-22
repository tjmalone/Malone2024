function [fData] = imRegions(fParam,fData)
%% imRegions.m
% Converts segmented image into regions. Specifically, draws a bounding box
% around identified cells. Filters cells based on size. Designed for use
% with autoFRAP and related experiments, but can be adapted for alternate
% experiments as long as input structs contain the correct parameters (see
% Parameters section). Uncomment final lines to view final segmented image
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%
% Output:
%       fData = updated data struct
%


%% Parameters

thSzLow = fParam.seg.thSzLow;       % cell size threshold
thSzHi = fParam.seg.thSzHi;         % cell size threshold

imFinal = fData.roiSeg;             % segmented image


%% Process segmented image

% initialize cell locations
fData.roiLoc = [];

% remove cells on border
imFinal = imclearborder(imFinal, 4);

% identify regions
[imLabel,~] = bwlabel(imFinal);
props = regionprops(imLabel,'Area','BoundingBox');

% save bounding box for identified cells
for i=1:length(props)
    % remove small and large cells
    if or(props(i).Area<thSzLow,props(i).Area>thSzHi)
        imFinal(imLabel==i) = 0;
    else
        fData.roiLoc(end+1,:) = props(i).BoundingBox;
    end
end

% update segmented image
fData.roiSeg = imFinal;

% figure
% imshow(imFinal);

end