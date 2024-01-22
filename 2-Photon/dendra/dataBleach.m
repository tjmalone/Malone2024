function dataBleach(fileName)
%% dataBleach.m
% Performs automated data analysis for autoBleach experiments to find
% bleach level per cycle. First, net fluorescence values are calculated
% based on image background and are normalize to the desried data point.
% After normalizing, performs final data analysis to collate and organize
% data, outputing data in a .mat file. Because program is only for
% optimization formal data output is not generated.
%
% Inputs:
%       fileName = name of file to analyze (string). To ask user to select
%           one or more files in current directly set to 0 or use no
%           inputs.
%
% Output:
%       generates .mat file containing:
%           bleachSet = bleach levels of individual cells
%           bleachAvg = average bleach levels for each laser power
%

%% Select Files

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
    %% Set Parameters
    
    load(files{exp},'fParam','fData');
    
    nrmBase = fParam.dat.nrmBase;       % time to normalize to
    
    
    %% Automated analysis
    
    % cycle through all datasets
    for imSet = 1:length(fData)
        %% Initialize dataset
        
        % save current set as temporary variable
        cur = fData(imSet);
        
        % check if dataset is valid (deleted or unfinished)
        if isempty(cur.roiRaw) || size(cur.roiRaw)~=size(cur.bkg)
            fprintf('\nInvalid data set detected\n')
            continue
        end
        
        
        %% Calculate normalized fluorescence
        
        cur.roiNet = bsxfun(@minus,cur.roiRaw,cur.bkg);
        cur.roiNorm = bsxfun(@rdivide,cur.roiNet,cur.roiNet(:,nrmBase));
        
        
        %% Save dataset
        
        fData(imSet) = cur;
        
    end
    
    
    %% Save analysis
    
    % save parameters and updated data struct
    save([fData(1).saveName '_' fData(1).expVar '.mat'],'fParam','fData')
    
    
    %% Collate data
    
    % create save name
    sName = [fData(1).saveName '_' fData(1).expVar '_blAvg.mat'];
    
    powersN = fParam.bl.powersN;
    
    % initialize cell array for individual cells
    bleachSet = cell(powersN,1);
    
    % cycles through datasets
    for imSet = 1:length(fData)
        
        % find size of current dataset
        sz = size(fData(imSet).roiNorm,1);
        
        % add each cell data to appropriate cell column by bleach power
        for i = 1:sz
            bleachSet{mod(i-1,powersN)+1}(end+1,:) =...
                fData(imSet).roiNorm(i,:);
        end
    end
    
    % initialize bleach average array
    bleachAvg = zeros(powersN,fParam.gen.timesN);
    
    % find average for each bleach power
    for i = 1:powersN
        bleachAvg(i,:) = mean(bleachSet{i},1);
    end
    
    % save results in .mat file
    save(sName,'bleachSet','bleachAvg')
    
end

end