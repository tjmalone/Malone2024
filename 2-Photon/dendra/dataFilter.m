function dataFilter(fileName,manCheck,mnFLon,mxFLon,mnBLon,mxBLon,mnRCon)
%% dataFilter.m
% Performs initial round of data analysis for autoFRAP experiments. First,
% net fluorescence values are calculated based on image background. Then
% cells are normalized to desired time point.
%
% Next, cells are filtered automatically and/or manually to select cells
% for further analysis. Can filter cells by cell fluorescence intensity,
% bleach level, and fluorescence recovery. These can be turned on and off
% by commenting or through input variables. Default analysis and automated
% analysis at the end of autoFRAP run will filter for criteria.
%
% Manual filtering is also possible, allowing the user to cycle through all
% unfiltered cells to determine suitability. Manual analysis can be useful
% for difficut to clasiify cell types such as neurons or for optimizing
% automated analysis.
%
% Note: Rerunning dataFilter will overwrite previous analysis, allowing
% user to easily change filtering parameters.
%
% Inputs:
%       fileName = name of file to analyze (string). To ask user to select
%           one or more files in current directly set to 0 or use no
%           inputs. Must set in order to use additional variables
%       manCheck = whether to manually filter cells (Default: 0=off). To
%           turn on, set to 0. Must set in order to set specific filtering
%           inputs
%       mnFLon = whether to filter minimum cell fluorescence (1=on,0=off)
%       mxFLon = whether to filter maximum cell fluorescence (1=on,0=off)
%       mnBLon = whether to filter minimum bleach level (1=on,0=off)
%       mxBLon = whether to filter maximum bleach level (1=on,0=off)
%       mnRCon = whether to filter min fluorescence recovery (1=on,0=off)
%
% Output:
%       saves updated file with normalized fluorescence and list of
%           filtered cells
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

% initialize input varibales
if nargin<=2
    mnFLon = 1;
    mxFLon = 1;
    mnBLon = 1;
    mxBLon = 1;
    mnRCon = 1;
    
    if nargin<=1
        manCheck = 0;
    end
elseif nargin~=7
    fprintf('\nError: incorrect number of inputs\n')
    return
end


%% Analyze each selected file

for exp = 1:fileNum
    %% Set Parameters
    
    load(files{exp},'fParam','fData');
    
    timesN = fParam.gen.timesN;         % number of time points
    nrmBase = fParam.dat.nrmBase;       % time to normalize to
    
    minFluor = fParam.dat.minFluor;     % Min net fluorescence to analyze
    maxFluor = fParam.dat.maxFluor;     % Max net fluorescence to analyze
    minBleach = fParam.dat.minBleach;   % Min bleaching requirement
    maxBleach = fParam.dat.maxBleach;   % Max bleaching requirement
    minRec = fParam.dat.minRec;         % Min recovery requirement
    
    
    %% Automated analysis
    
    % cycle through all datasets
    for imSet = 1:length(fData)
        %% Initialize dataset
        
        % save current set as temporary variable
        cur = fData(imSet);
        
        % check if dataset is valid (deleted or unfinished)
        if size(cur.roiRaw)~=size(cur.bkg)
            fprintf('\nInvalid data set detected\n')
            continue
        end
        
        
        %% Calculate normalized fluorescence
        
        cur.roiNet = bsxfun(@minus,cur.roiRaw,cur.bkg);
        cur.roiNorm = bsxfun(@minus,cur.roiNet,cur.roiNet(:,nrmBase));
        cur.roiNorm = bsxfun(@rdivide,cur.roiNorm,cur.roiNet(:,nrmBase));
        
        
        %% Automated cell filtering
        
        % initialize filtered cell list
        roiDel = zeros(size(cur.roiNet));
        
        % filter for minimum cell fluorescence
        if mnFLon
            roiDel = max(roiDel,cur.roiNet(:,1)<minFluor);
        end
        
        % filter for maximum cell fluorescence
        if mxFLon
            roiDel = max(roiDel,cur.roiNet(:,1)>maxFluor);
        end
        
        % filter for minimum bleach level
        if mnBLon
            roiDel = max(roiDel,cur.roiNorm(:,1)<minBleach);
        end
        
        % filter for maximum bleach level
        if mxBLon
            roiDel = max(roiDel,cur.roiNorm(:,1)>maxBleach);
        end
        
        % filter for minimum fluorescence recovery
        if mnRCon
            roiDel = max(roiDel,cur.roiNorm(:,end)<minRec);
        end
        
        % saved filtered cell list
        cur.roiDel = roiDel;
        
        
        %% Save dataset
        
        fData(imSet) = cur;
        
    end
    
    
    %% Manual analysis
    
    if manCheck
        
        F = figure;
        
        fprintf('\nManual cell filtering:\n')
        fprintf('\ty = accept cell\n')
        fprintf('\tn = reject cell\n')
        fprintf('\tskip = accept all further cells\n')
        
        for imSet = 1:length(fData)
            %% Initialize dataset
            
            % save current set as temporary variable
            cur = fData(imSet);
            
            % check if dataset is valid (deleted or unfinished)
            if size(cur.roiRaw)~=size(cur.bkg)
                continue
            end
            
            bord = fParam.dat.bord;             % cell border scaling
            
            flag = 0;
            
            
            %% Manual cell filtering
            
            % cycle through all cells
            for roi = 1:size(cur.roiLoc,1)
                
                % skip pre-filtered cells
                if cur.roiDel(roi)==1
                    continue
                end
                
                
                %% Define cell area
                
                % define roi border rectangle
                y = cur.roiLoc(roi,1);
                x = cur.roiLoc(roi,2);
                yW = cur.roiLoc(roi,3);
                xW = cur.roiLoc(roi,4);
                
                % add buffer to border rectangle
                X1 = max(1,round(x-bord*xW));
                X2 = min(1024,round(x+(1+bord)*xW));
                Y1 = max(1,round(y-bord*yW));
                Y2 = min(1024,round(y+(1+bord)*yW));
                
                % get image segmentation within border
                BWoutline = bwperim(cur.roiSeg(X1:X2,Y1:Y2));
                
                % calculate pre-bleach intensity range
                mx = max(cur.stacks{1}(X1:X2,Y1:Y2),[],'all')-cur.bkg(1);
                
                
                %% Generate time course image
                
                % cycle through all times
                for t=1:timesN
                    
                    % current background
                    mn = cur.bkg(t);
                    
                    % normalize current image to pre-bleach intensity
                    imNorm =...
                        mat2gray(cur.stacks{t}(X1:X2,Y1:Y2),[mn,mx+mn]);
                    
                    % outline segmentation on normalized image
                    imBound = imNorm;
                    imBound(BWoutline) = 1;
                    
                    % display normalized image
                    subplot(2,timesN,t)
                    imshow(imBound);
                    
                    % dispay image with scaled colors
                    subplot(2,timesN,t+timesN)
                    imagesc(imNorm);
                    
                    axis equal off
                end
                
                % set plot background to improve contrast
                set(gcf,'color','black');
                
                
                %% Get user input
                
                while true
                    
                    fprintf('\nNormalized fluorescence: ')
                    disp(cur.roiNorm(roi,:))
                    
                    % get user input
                    inp = input('Keep cell: ','s');
                    
                    % process user input
                    if strcmp(inp,'y')
                        break
                    elseif strcmp(inp,'n')
                        cur.roiDel(roi) = 1;
                        break
                    elseif strcmp(inp,'skip')
                        flag = 1;
                        break
                    end
                end
                
                % skip all further cells
                if flag
                    break
                end
            end
            
            % Save dataset
            fData(imSet) = cur;
            
        end
        
        close(F)
    end
    
    
    %% Save analysis
    
    % save parameters and updated data struct
    save([fData(1).saveName '_' fData(1).expVar '.mat'],'fParam','fData')
    
end


end