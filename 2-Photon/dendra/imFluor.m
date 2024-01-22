function [fData] = imFluor(fData)
%% imFluor.m
% Calculates the fluroescence level of cells in a segmented image. Designed
% for use with autoFRAP and related experiments, but can be adapted for
% alternate experiments as long as input struct contains the correct
% parameters.
%
% Inputs:
%       fData = data struct
%
% Output:
%       fData = final segmented image
%

% segmented image
imFinal = fData.roiSeg;

% label segmented image
[imLabel,cellNum] = bwlabel(imFinal);


%% Save roi fluorescence

% scan through images
for i = 1:length(fData.stacks)
    
    % find mean intensity for all cells in image
    props = regionprops(imLabel,fData.stacks{i},'MeanIntensity');
    
    % store mean intensity values
    for j = 1:cellNum
        fData.roiRaw(j,i) = props(j).MeanIntensity;
    end
end

end