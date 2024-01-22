function dataTime(fileName)
%% dataTime.m
% Performs final data analysis to generate a recovery time course in
% autoFRAP experiments. Reads filtered data from selected file. After
% collating and organizing data, outputs data as a formated .csv file.
%
%
% Inputs:
%       file = name of file to analyze (string). To ask user to select one
%           or more files in current directly set to 0 or use no inputs.
%
% Output:
%       generates a .csv file with recovery time course
%


%% Select files

% Select which files to analyze
if nargin==0 || fileName==0
    % ask user to select
    files = util.fileSelect('*.mat');
else
    % select based on input
    files = {fileName};
end

fileNum = length(files);


%% Analyze each selected file

for exp = 1:fileNum
    %% Collate data
    
    % load data
    load(files{exp},'fParam','fData');
    
    % create save name
    sName = [fData(1).saveName '_' fData(1).expVar '.csv'];
    
    % create cell array of image times
    times = num2cell(fParam.gen.times/60);
    timesN = fParam.gen.timesN;
    
    % initialize collation data array
    comb = zeros(0,timesN);
    del = 0;
    
    % collate data
    for imSet = 1:length(fData)
        % add unfiltered rois to data array
        comb = [comb; fData(imSet).roiNorm(~fData(imSet).roiDel,:)];
        
        % sum filtered cells
        del = del + sum(fData(imSet).roiDel);
    end
    
    % calculate means for all time points
    mu = mean(comb,1);
    
    
    %% Create cell array for output
    
    % size of data array
    sz = size(comb,1);
    
    % create header column with time points 
    COMB = ['times', times];
    
    % add variable name
    COMB{end+1,1} = fData(1).expVar;
    
    % add data
    COMB(end+1:end+sz,2:timesN+1) = num2cell(comb);
    
    % add means and filtered cell number
    COMB(end+2,:) = ['Means:', num2cell(mu)];
    COMB(end+2,1:2) = {'Excluded:', num2str(del)};
    
    % save data as a .csv file
    util.cell2csv(sName,COMB,',',0)
    
end

end