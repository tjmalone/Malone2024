function dataBase(fileName,nmAon,mnFLon,mxFLon)
%% dataBase.m
% Performs automated data analysis for autoBase experiments. First, net
% fluorescence values are calculated based on image background and can be
% normalized by cell area. Next, cells are filtered automatically to select
% cells for final analysis. Can filter cells by cell fluorescence
% intensity. Filtering and normalization can be turned on or off by
% commenting or through input variables. Default analysis and automated
% analysis at the end of autoBase is to normalize to area, but use no
% filtering. After filtering, performs final data analysis to collate and
% organize data, outputing data as a formated .csv file. Combines the
% function of dataFilter and dataTime.
%
% Note: Rerunning dataBase will overwrite previous analysis, allowing
% user to easily change normalization and filtering parameters.
%
% Inputs:
%       fileName = name of file to analyze (string). To ask user to select
%           one or more files in current directly set to 0 or use no
%           inputs. Must set in order to use additional variables
%       nmAon = whether to normalize to area (1=on,0=off)
%       mnFLon = whether to filter minimum cell fluorescence (1=on,0=off)
%       mxFLon = whether to filter maximum cell fluorescence (1=on,0=off)
%
% Output:
%       saves updated file with normalized fluorescence and list of
%           filtered cells
%       generates .csv file with baseline fluorescence data
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

% initialize input varibales
if nargin<=1
    nmAon = 1;
    mnFLon = 0;
    mxFLon = 0;
    
elseif nargin~=4
    fprintf('\nError: incorrect number of inputs\n')
    return
end


%% Analyze each selected file

for exp = 1:fileNum
    %% Set Parameters
    
    load(files{exp},'fParam','fData');
    
    setsN = length(fData);
    
    maxFluor = fParam.dat.maxFluor;     % Max net fluorescence to analyze
    minFluor = fParam.dat.minFluor;     % Min net fluorescence to analyze
    
    
    %% Automated analysis
    
    % cycle through all datasets
    for imSet = 1:setsN
        %% Initialize dataset
        
        % save current set as temporary variable
        cur = fData(imSet);
        
        % check if dataset is valid (deleted or unfinished)
        if isempty(cur.stacks{1}) || size(cur.roiRaw)~=size(cur.bkg)
            fprintf('\nInvalid data set detected\n')
            continue
        end
        
        
        %% Calculate normalized fluorescence
        
        % extract roi areas
        imFinal = cur.roiSeg;
        [imLabel,~] = bwlabel(imFinal);
        rProps = regionprops(imLabel,cur.stacks{1},'Area');
        
        % save roi areas
        areas = zeros(length(rProps),1);
        for k = 1:length(rProps)
            areas(k) = rProps(k).Area;
        end
        
        % subtract background
        cur.roiNet = bsxfun(@minus,cur.roiRaw,cur.bkg);
        
        % normalize rois
        if nmAon
            cur.roiNorm = bsxfun(@rdivide,cur.roiNorm,areas);
        else
            cur.roiNorm = cur.roiNet;
        end


        %% Automated cell filtering
        
        % initialize filtered cell list
        roiDel = zeros(size(cur.roiNet,1),1);
        
        % filter for minimum cell fluorescence
        if mnFLon
            roiDel = max(roiDel,cur.roiNet(:,1)<minFluor);
        end
        
        % filter for maximum cell fluorescence
        if mxFLon
            roiDel = max(roiDel,cur.roiNet(:,1)>maxFluor);
        end

        % saved filtered cell list
        cur.roiDel = roiDel;
        
        
        %% Save dataset
        
        fData(imSet) = cur;
        
    end
    
    
    %% Save analysis
    
    % save parameters and updated data struct
    save([fData(1).saveName '_' fData(1).expVar '.mat'],'fData','fParam')
    
    
    %% Initialize data collation
    
    if nmAon
        nFilt = 'A';
    else
        nFilt = '0';
    end
    
    if mnFLon && mxFLon
        sFilt = 'bi';
    elseif mnFLon
        sFilt = 'mn';
    elseif mxFLon
        sFilt = 'mx';
    else
        sFilt = 'no';
    end
 
    % create save name
    sName = [fData(1).saveName '_' fData(1).expVar '_base_'...
        nFilt 'Nm_' sFilt 'Lm.csv'];
    
        
    % cell array for combined data (increase value if too many rois)
    comb = cell(1000,setsN);
    
    % mean of individual datasets
    mu = zeros(1,setsN);
    
    % filtered cells from individua; datasets
    del = zeros(1,setsN);
    
    % maximum dataset size
    mx = 0;
    
    
    %% Collate data
    
    %  cycle through all datasets
    for imSet = 1:length(fData)
        
        % nonfiltered data from dataset
        dat = fData(imSet).roiNorm(~fData(imSet).roiDel,:);
        
        % size of dataset
        sz = size(dat,1);
        
        % add current dataset to collated data
        comb(1:sz,imSet) = num2cell(dat);
        
        % calculate mean, filtered cell number, and new max size 
        mu(imSet) = mean(dat);
        del(imSet) = del(imSet) + sum(fData(imSet).roiDel);
        mx = max(mx,sz);
    end
    
    % empty extra cells
    comb(mx+1:end,:) = [];
    
    
    %% Create cell array for output
    
    % create header column with dataset numbering
    COMB = ['sets', num2cell(1:setsN)];
    
    % add variable name
    COMB{end+1,1} = fData(1).expVar;
    
    % add data
    COMB(end+1:end+mx,2:setsN+1) = comb;
    
    % add means and filtered cell number
    COMB(end+2,:) = ['Means:', num2cell(mu)];
    COMB(end+2,:) = ['Excluded:', num2cell(del)];
    
    % save data as a .csv file
    util.cell2csv(sName,COMB,',',0)
    
end

end