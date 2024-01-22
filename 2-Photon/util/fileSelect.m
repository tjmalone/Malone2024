function [fileNames,filePaths] = fileSelect(fileForm, selects, setSize)
%% fileSelect.m
% allows user to select a set of files with a given format
%
% Inputs:
%       fileForm = path and file format used to select files
%           current folder is used if only format is input
%
%       selects = desired file after enumeration. If 0, user is asked to
%           select file. If greater than 0, file is selected
%           automatically. Prevents repeatedly typing file number, when
%           already known. (default = 0).
%
%       setSize = number of files linked together. Used if files come in
%           defined sets. Only the first file of a given set is displayed.
%           Warning: errors may occur if file format includes extra files
%
% Output:
%       fileNames = names of selected files. X by Y cell array, where X is
%           number of files/sets chosen and Y is number of files within a
%           set 
%
%       filePaths = paths of selected files. X by Y cell array, where X is
%           number of files/sets chosen and Y is number of files within a
%           set
%


%% Process inputs

% defaults to maually selection
if nargin==1
    selects = 0;
end

% set size is determined
if nargin<3
    setSize = 1;
end

% identifies all files matching file format
files = dir(fileForm);


%% Maunally select files
if selects==0
    % enumerate files
    num = numel(files);
    fprintf('\n')
    disp(['files in pathway: ' num2str(num)])
    
    % display file names
    for a = 1:setSize:num
        readout = {['[' num2str(a) ']   ' files(a).name]};
        disp(readout)
    end
    
    % user selects file
    selects = input('Select files for analysis: ');
end


%% Save selected files

% number of selected files/sets
selNum = length(selects);

% initialize output variables
fileNames = cell(selNum,setSize);
filePaths = cell(selNum,setSize);

% generate output variables
for ii=1:selNum
    fileNames(ii,1:setSize) =...
        {files(selects(ii):selects(ii)+setSize-1).name};
    filePaths(ii,1:setSize) =...
        {files(selects(ii):selects(ii)+setSize-1).folder};
end

end