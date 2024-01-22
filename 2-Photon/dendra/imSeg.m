function [imFinal] = imSeg(fParam,imRaw,th)
%% imSeg.m
% Automatically segments input image. Designed for use with autoFRAP and
% related experiments, but can be adapted for alternate experiments as long
% as input struct contains the correct parameters (see Parameters section).
% Contains several points where intmediate figures can be viewed by
% uncommenting. Uncomment final segment to view final segmentation on
% outline of original image.
%
% Inputs:
%       fParam = parameter struct
%       imRaw = image to segment
%       th = quantile threshold (if used do not include fParam)
%
% Output:
%       imFinal = final segmented image
%


%% Parameters

% set quantile threshold
if nargin==2
    thQ = fParam.seg.thQ;
elseif nargin==3
    thQ = th;
else
    fprintf('Error: incorrect number of input\n')
end


%% Segment image

% scale image 0 to 1
imNorm = mat2gray(imRaw);

% calculate threshold
imVec = reshape(imNorm,1,[]);
Q = quantile(imVec,thQ);

% create binary mask
imBW = im2bw(imNorm,Q);

% figure
% imshow(imBW);

% create dilation strel
se90 = strel('line', 2, 90);
se0 = strel('line', 2, 0);

% dilate image
imDil = imdilate(imBW, [se90 se0]);

% figure
% imshow(imDil);

% fill holes
imFill = imfill(imDil, 'holes');

% figure
% imshow(imFill);

% create erosion strel
seD = strel('diamond',1);

% erode image
imErode = imerode(imFill,seD);
imFinal = imerode(imErode,seD);

% figure
% imshow(imFinal);


%% Outlined image segmentation

% BW = imNorm;
% BWoutline = bwperim(imFinal);
% BW(BWoutline) = 1;
% figure
% imshow(BW), title('image segmentation');

end