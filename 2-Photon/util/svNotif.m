function svNotif(fParam,fData)
%% svNotif.m
% Saves a .mat file as a notification of progress. Designed for use with
% autoFRAP and related programs, but can be adapted for alternate
% experiments as long as input structs contain the correct parameters
%
% Inputs:
%       fParam = parameter struct
%       fData = data struct
%

% initialize save array
svFile = cell(fParam.gen.timesN,fParam.gen.setsMax);

%% Determine progress of experiment

% cycle through sets
for imSet = 1:length(fData)
    
    % save current set as temporary variable
    cur = fData(imSet);
    
    % cycle through stacks
    for stk = 1:length(cur.stacks)
        
        % skip empty stacks
        if any(cur.stacks{stk})
            
            % store current stack 
            STK = cur.stacks{stk}(:);
            
            % find the sum of all points above threshold
            ncur = sum(STK(STK>fParam.gen.mxThr));
            
            % store value in save file
            svFile{stk,imSet} = sprintf('%.2e',ncur);
        end
    end
end

% write save notification to set location
save([fParam.gen.svNotifPath fData(1).saveName '_' fData(1).expVar...
    '_sv.mat'],'svFile')

end